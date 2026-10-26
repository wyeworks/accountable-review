#!/usr/bin/env ruby
# frozen_string_literal: true

# Every skill's SKILL.md and every Markdown reference under its references/ is held to a size
# ceiling, and every reference is reachable from its SKILL.md.
#
# The size is guidance nobody reads at the moment a sentence is added: SKILL.md is loaded whole on
# every run, so it grows one reasonable paragraph at a time and no single diff looks like the
# problem. The ceilings in budgets.yml are a ratchet — lowered when a file shrinks, raised only on
# purpose, in the same commit as the growth, so the growth is in the diff a reviewer reads.
#
# Rules, each named in its failure line:
#   ceiling      a governed file is over its line or byte ceiling                       FAIL
#   unbudgeted   a governed file has no row, so it could grow without anyone deciding   FAIL
#   stale-row    a row names a file that does not exist                                  FAIL
#   orphan       a reference SKILL.md never names, so no run is told when to read it     FAIL
#   dangling     a references/ path SKILL.md names that does not exist                   FAIL
#   spec-size    a SKILL.md over the Agent Skills guidance of 500 lines                  WARN
#   history      a SKILL.md with more run-history markers than its ceiling              WARN
#
# The last two warn rather than fail. The 500 lines is the specification's recommendation, not a
# limit a host enforces, and skill prose is allowed the observation behind a rule
# (.claude/CLAUDE.md § Editing style); the point of both is that growth is visible.
#
# A reference SKILL.md names in a list — `references/discover/rails.md`, `phoenix.md` — is named:
# its directory path appears in SKILL.md and its file name appears in backticks.
# themes/ and page-template.html are not governed and need no name: page-skeleton.sh emits them,
# and no run reads them.
#
# Usage: ruby skills/review-map/tests/skill-budget.rb   (exit 0 clean, 1 on any failure)

require "yaml"

ROOT = File.expand_path("../../..", __dir__)
BUDGETS = File.join(__dir__, "budgets.yml")
SPEC_LINES = 500
HISTORY = /used to|no longer|earlier version|back when|measured|one run/i
UNREAD = %r{\Askills/[^/]+/references/(themes/|page-template\.html\z)}
REF_PATH = %r{references/[A-Za-z0-9_./-]*[A-Za-z0-9_/]}

def governed?(rel)
  rel.match?(%r{\Askills/[^/]+/SKILL\.md\z}) ||
    (rel.match?(%r{\Askills/[^/]+/references/.+\.md\z}) && !rel.match?(UNREAD))
end

# files: { "skills/x/SKILL.md" => text, ... } — every file under skills/*/references/ plus each
# SKILL.md. budgets: the parsed budgets.yml. Returns [failures, warnings], each a list of lines.
def check(files, budgets)
  fails = []
  warns = []
  ceilings = budgets.fetch("files", {})
  history = budgets.fetch("history", {})

  files.each_key.select { governed?(_1) }.sort.each do |rel|
    text = files[rel]
    row = ceilings[rel]
    unless row
      fails << "unbudgeted #{rel} has no row in budgets.yml"
      next
    end
    lines = text.lines.size
    bytes = text.bytesize
    fails << "ceiling    #{rel} is #{lines} lines, over its #{row['lines']}" if lines > row["lines"]
    fails << "ceiling    #{rel} is #{bytes} bytes, over its #{row['bytes']}" if bytes > row["bytes"]
  end

  ceilings.each_key.reject { files.key?(_1) }.sort.each do |rel|
    fails << "stale-row  budgets.yml names #{rel}, which does not exist"
  end

  files.each_key.select { _1.match?(%r{\Askills/[^/]+/SKILL\.md\z}) }.sort.each do |skill_md|
    skill = File.dirname(skill_md)
    text = files[skill_md]
    lines = text.lines.size
    warns << "spec-size  #{skill_md} is #{lines} lines, #{lines - SPEC_LINES} over the spec's #{SPEC_LINES}" if lines > SPEC_LINES

    marks = text.scan(HISTORY).size
    cap = history[skill_md]
    warns << "history    #{skill_md} has #{marks} history markers, over its #{cap}" if cap && marks > cap

    files.each_key.select { _1.start_with?("#{skill}/references/") && !_1.match?(UNREAD) }.sort.each do |ref|
      local = ref.delete_prefix("#{skill}/")
      dir = "#{File.dirname(local)}/"
      named = text.include?(local) ||
              (dir != "references/" && text.include?(dir) && text.include?("`#{File.basename(local)}`"))
      fails << "orphan     #{ref} is never named in #{skill_md}" unless named
    end

    text.scan(REF_PATH).uniq.sort.each do |path|
      full = "#{skill}/#{path}"
      exists = files.key?(full) || files.each_key.any? { _1.start_with?("#{full.chomp('/')}/") }
      fails << "dangling   #{skill_md} names #{path}, which does not exist" unless exists
    end
  end

  [fails, warns]
end

def tree
  Dir.glob("skills/*/{SKILL.md,references/**/*}", base: ROOT)
     .select { File.file?(File.join(ROOT, _1)) }
     .to_h { [_1, File.read(File.join(ROOT, _1), encoding: "UTF-8")] }
end

failures = 0
budgets = YAML.safe_load_file(BUDGETS)
fails, warns = check(tree, budgets)
warns.each { puts "WARN #{_1}" }
fails.each { puts "FAIL #{_1}" }
failures += fails.size
puts "ok   #{budgets['files'].size} files within their ceilings, every reference named" if fails.empty?

# Each mutation must be caught by the rule it names, or the checks above pass because they never
# looked. The fixture is a two-reference skill that passes clean.
SKILL_MD = "---\nname: s\n---\nRead `references/a.md` at step 1, and `references/d/x.md` or `y.md` at step 2.\n"
GOOD = {
  "skills/s/SKILL.md" => SKILL_MD,
  "skills/s/references/a.md" => "one\ntwo\n",
  "skills/s/references/d/x.md" => "x\n",
  "skills/s/references/d/y.md" => "y\n",
  "skills/s/references/themes/t.css" => "t\n",
  "skills/s/references/page-template.html" => "<p>\n"
}.freeze
ROOM = { "lines" => 10, "bytes" => 1000 }.freeze
GOOD_BUDGETS = {
  "files" => GOOD.keys.select { governed?(_1) }.to_h { [_1, ROOM] },
  "history" => { "skills/s/SKILL.md" => 0 }
}.freeze

def with(files = {}, budgets = {})
  [GOOD.merge(files).compact, GOOD_BUDGETS.merge(budgets)]
end

MUTATIONS = {
  "a reference over its line ceiling" => [*with("skills/s/references/a.md" => "x\n" * 11), :fail, "ceiling"],
  "a reference over its byte ceiling" => [*with("skills/s/references/a.md" => "x" * 1001), :fail, "ceiling"],
  "a new reference with no row" => [*with("skills/s/references/b.md" => "b\n",
                                          "skills/s/SKILL.md" => "#{SKILL_MD}And `references/b.md`.\n"), :fail, "unbudgeted"],
  "a row for a deleted file" => [*with("skills/s/references/d/y.md" => nil,
                                       "skills/s/SKILL.md" => SKILL_MD.sub(" or `y.md`", "")), :fail, "stale-row"],
  "a reference SKILL.md never names" => [*with("skills/s/SKILL.md" => SKILL_MD.sub("`references/a.md`", "the reference")),
                                         :fail, "orphan"],
  "a listed file name without its directory" => [*with("skills/s/SKILL.md" => SKILL_MD.sub("`references/d/x.md` or ", "")),
                                                 :fail, "orphan"],
  "a path SKILL.md names that is gone" => [*with("skills/s/SKILL.md" => "#{SKILL_MD}See `references/gone.md`.\n"),
                                           :fail, "dangling"],
  "a SKILL.md past the spec's 500 lines" => [*with("skills/s/SKILL.md" => SKILL_MD + ("x\n" * 500)),
                                              :warn, "spec-size"],
  "a SKILL.md over its history ceiling" => [*with("skills/s/SKILL.md" => "#{SKILL_MD}It used to.\n"), :warn, "history"]
}.freeze

clean = check(GOOD, GOOD_BUDGETS)
unless clean.all?(&:empty?)
  puts "FAIL self-test: the clean fixture is refused: #{clean.flatten.join('; ')}"
  failures += 1
end
MUTATIONS.each do |label, (files, budgets, kind, rule)|
  fails, warns = check(files, budgets)
  got = kind == :fail ? fails : warns
  next if got.any? { _1.start_with?(rule) }

  puts "FAIL self-test: #{label} was not caught as #{kind} #{rule} (got #{(fails + warns).inspect})"
  failures += 1
end
puts "ok   #{MUTATIONS.size} mutations caught, each by the rule it names" if failures.zero?

exit(failures.zero? ? 0 : 1)
