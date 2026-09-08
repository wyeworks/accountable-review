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
#     check.rb --fragment behaviour-flows.html --scope behaviour-flows
#
#   Just the diagrams, optionally rendered to PNGs for a person to look at:
#     check.rb --page page.html --scope diagram [--visual]
#
#   A page or fragment produced at the skill's brief detail level, where sections 4 to 7
#   are one merged section (report-format.md § Detail levels):
#     check.rb --page page.html --repo DIR --base REF --level brief
#
# --level defaults to `full`. It is a third axis, separate from build state and from the
# section slug, and only one check reads it: before_approving.rb, because a missing
# comprehension checkpoint is correct at brief and a WARN at full. Everything else keeps
# working across the merge because the merged section keeps the section anchors the region
# extractors read — see report-format.md § Section 4 at brief.
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
  "all"              => %w[completeness build-state page-invariants excerpts behaviour-flows
                           start-here reach impact-paths before-approving searches rails-anchors
                           link-form diagram],
  "core"             => %w[completeness build-state page-invariants excerpts before-approving
                           rails-anchors link-form],
  "behaviour-flows"  => %w[page-invariants excerpts behaviour-flows searches rails-anchors
                           link-form diagram],
  "start-here"       => %w[page-invariants start-here link-form],
  "reach"            => %w[page-invariants excerpts reach impact-paths searches rails-anchors
                           link-form diagram],
  "before-approving" => %w[page-invariants before-approving rails-anchors link-form],
  "diagram"          => %w[diagram],
}.freeze

CHECKS_DIR = File.join(__dir__, "checks")

check = ReviewMap::Check.new(ARGV)
check.require_input

scope = check.scope
if scope.to_s.empty?
  if check.kind == "page"
    scope = "all"
  else
    warn "a fragment needs --scope: behaviour-flows | start-here | reach | before-approving | diagram"
    exit 2
  end
end
unless SCOPES.key?(scope)
  warn "unknown scope: #{scope}"
  exit 2
end

run = SCOPES[scope].dup
run << "diagram-shot" if check.visual

# Rebuild the child argument list from what was parsed, so every child sees the same input
# and nobody re-parses the command line.
args = ["--#{check.kind}", check.input]
args += ["--repo", check.repo] unless check.repo.to_s.empty?
args += ["--base", check.base] unless check.base.to_s.empty?
args += ["--head", check.head_ref, "--#{check.mode}", "--level", check.level]
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
  puts "#{scope} / #{check.mode} / #{check.level}: #{tally}"
else
  puts "#{scope} fragment / #{check.level}: #{tally}"
end
exit(failed.zero? ? 0 : 1)
