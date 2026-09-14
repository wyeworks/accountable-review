#!/usr/bin/env ruby
# frozen_string_literal: true
#
# check.rb — the mechanical half of an eval, dispatched.
#
#   Page, the whole thing:
#     check.rb --page page.html --repo DIR --base REF [--head REF]
#              [--draft | --final | --stopped] [--expect S]... [--forbid S]...
#
#   One section, produced by a driver in drivers/ from the frozen upstream:
#     check.rb --fragment attention.html --scope attention
#
# --level is still accepted and read by nothing. There is one page shape now — SKILL.md
# refuses --full and --review and takes --brief and --light as aliases that change nothing —
# so the flag survives only because evals/run.sh still passes it and an unknown argument
# exits 2. Do not add a check that reads it: a second shape is what this page stopped being.
#
# Three grading scopes, and the difference matters. A PAGE carries invariants no fragment
# can: completeness, one canonical home, the excerpt budget, the build state. A FRAGMENT is
# one section, graded on its own so a wording change in one part of report-format.md can be
# measured without paying for a whole run. A section that passes therefore says nothing
# about whether the page repeats itself — that is the page's job, and README.md says so.
#
# Each check lives in checks/ and prints PASS / FAIL / WARN / SKIP lines. This script only
# decides which ones apply and adds up what they printed. Exit code follows the FAILs.

require_relative "checks/lib/review_map/check"

# Each check lives in checks/ and prints PASS / FAIL / WARN / SKIP lines. This script only
# decides which ones apply and adds up what they printed. Exit code follows the FAILs.
SCOPES = {
  "all"        => %w[completeness build-state page-invariants excerpts start-here
                     impact-paths searches rails-anchors link-form],
  "core"       => %w[completeness build-state page-invariants excerpts rails-anchors link-form],
  "attention"  => %w[page-invariants excerpts rails-anchors link-form],
  "start-here" => %w[page-invariants start-here link-form],
  "impact"     => %w[page-invariants impact-paths searches link-form],
}.freeze

CHECKS_DIR = File.join(__dir__, "checks")

check = ReviewMap::Check.new(ARGV)
check.require_input

scope = check.scope
if scope.to_s.empty?
  if check.kind == "page"
    scope = "all"
  else
    warn "a fragment needs --scope: attention | start-here | impact"
    exit 2
  end
end
unless SCOPES.key?(scope)
  warn "unknown scope: #{scope}"
  exit 2
end

run = SCOPES[scope]

# Rebuild the child argument list from what was parsed, so every child sees the same input
# and nobody re-parses the command line.
args = ["--#{check.kind}", check.input]
args += ["--repo", check.repo] unless check.repo.to_s.empty?
args += ["--base", check.base] unless check.base.to_s.empty?
args += ["--head", check.head_ref, "--#{check.mode}"]
args += ["--out", check.outdir] unless check.outdir.to_s.empty?

lines = []
run.each do |name|
  script = File.join(CHECKS_DIR, "#{name}.rb")
  out, err, status = ReviewMap.capture({ "CHECK_TALLY" => "0" }, "ruby", script, *args)
  lines << out << err
  lines << "FAIL  #{name} was called wrongly — see the usage above\n" if status.exitstatus == 2
end

# Case-specific: the planted findings, and whatever this case forbids. These stay here rather
# than in a check script because they are the one part that differs per case.
page = File.read(check.input, encoding: "UTF-8")
check.expects.each do |wanted|
  lines << (page.include?(wanted) ? "PASS  mentions: #{wanted}\n" : "FAIL  never mentions: #{wanted}\n")
end
check.forbids.each do |unwanted|
  lines << (page.include?(unwanted) ? "FAIL  should not contain: #{unwanted}\n" : "PASS  absent, as required: #{unwanted}\n")
end

report = lines.join
print report

counted = ->(prefix) { report.lines.count { |l| l.start_with?(prefix) } }
passed = counted.call("PASS")
failed = counted.call("FAIL")
warned = counted.call("WARN")
skipped = counted.call("SKIP")

puts
tally = "#{passed} passed, #{failed} failed, #{warned} warning(s), #{skipped} skipped"
if check.kind == "page"
  puts "#{scope} / #{check.mode}: #{tally}"
else
  puts "#{scope} fragment: #{tally}"
end
exit(failed.zero? ? 0 : 1)
