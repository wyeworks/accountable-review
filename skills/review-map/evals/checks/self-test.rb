#!/usr/bin/env ruby
# frozen_string_literal: true

# self_test.rb — the checks, checked.
#
# A check script that always passes is worse than no check script: it turns an unchecked rule
# into one the reader believes is checked. Every fragment in ../golden plants exactly one
# defect, and self_test_cases.txt says what each check is supposed to say about it.
#
# No model, no fixtures, a couple of seconds. That is why it belongs in CI next to
# `claude plugin validate`.
#
# The table is a DATA FILE rather than a heredoc here, and that is not tidiness: frozen.rb reads
# the same rows, so the frozen corpus inherits every case that needs --repo, --base or --level.
# One source of truth for what the corpus is.

require_relative "lib/review_map/page"

HERE = __dir__
EVALS = File.dirname(HERE)
GOLD = File.join(EVALS, "golden")

Row = Struct.new(:check, :fragment, :want_exit, :want_text, :extra)

def rows
  File.readlines(File.join(HERE, "self-test-cases.txt"), encoding: "UTF-8").filter_map do |line|
    next if line.strip.empty? || line.strip.start_with?("#")

    check, fragment, want_exit, want_text, extra = line.split("|").map { |c| c.to_s.strip }
    Row.new(check, fragment, want_exit, want_text, extra.to_s.gsub("@GOLD@", GOLD))
  end
end

def run(row, args)
  script = File.join(HERE, "#{row.check}.rb")
  out, err, status = ReviewMap.capture({ "CHECK_TALLY" => "0" }, "ruby", script, *args)
  [out + err, status.exitstatus]
end

pass = 0
fail = 0

def report(label, problem, output)
  if problem.empty?
    puts "ok    #{label}"
  else
    puts "BAD   #{label} — #{problem.join("; ")}"
    puts output.lines.map { |l| "        #{l}" }.join
  end
end

rows.each do |row|
  args = ["--fragment", File.join(GOLD, row.fragment)] + row.extra.split
  output, got = run(row, args)

  problem = []
  problem << "exit #{got}, wanted #{row.want_exit}" unless got.to_s == row.want_exit
  problem << %(no line matching "#{row.want_text}") unless output.include?(row.want_text)

  problem.empty? ? pass += 1 : fail += 1
  report("#{row.check}  #{row.fragment}", problem, output)
end

# The judged half has one piece a script can test: reading a verdict file. A tally that reads a
# truncated or fenced file as "no fails" is the same defect as a check that always passes, and it
# is worse here because the number it produces looks like a measurement.
TALLIES = [
  ["verdicts-clean.json",     0, "judged: 6 pass, 0 fail, 0 unclear", %w[--expected 6]],
  ["verdicts-mixed.json",     0, "judged: 4 pass, 1 fail, 1 unclear", %w[--expected 6]],
  ["verdicts-mixed.json",     0, "note on the expectations:",         %w[--expected 6]],
  ["verdicts-short.json",     0, "3 verdict(s) for 6 expectation(s)", %w[--expected 6]],
  ["verdicts-fenced.json",    0, "judged: 1 pass",                    %w[--expected 1]],
  ["verdicts-prose.json",     1, "is not JSON",                       %w[--expected 6]],
  ["verdicts-bad-value.json", 0, "carry a value that is not",         %w[--expected 2]],
  ["verdicts-clean.json",     0, "6 0 0",                             %w[--counts]],
].freeze

TALLIES.each do |fragment, want_exit, want_text, extra|
  out, err, status = ReviewMap.capture({ "CHECK_TALLY" => "0" },
                                    File.join(EVALS, "verdict-tally.sh"),
                                    File.join(GOLD, fragment), *extra)
  output = out + err
  problem = []
  problem << "exit #{status.exitstatus}, wanted #{want_exit}" unless status.exitstatus == want_exit
  problem << %(no line matching "#{want_text}") unless output.include?(want_text)

  problem.empty? ? pass += 1 : fail += 1
  report("verdict-tally  #{fragment}", problem, output)
end

# The page-only checks refuse a fragment rather than passing on evidence they do not have.
# That refusal is itself a rule worth pinning: exit 3, and a SKIP line saying why.
%w[completeness build-state].each do |check|
  out, err, status = ReviewMap.capture({ "CHECK_TALLY" => "0" }, "ruby",
                                    File.join(HERE, "#{check}.rb"),
                                    "--fragment", File.join(GOLD, "flows-clean.html"))
  output = out + err
  if status.exitstatus == 3 && output.include?("needs a whole page")
    pass += 1
    puts "ok    #{check}  refuses a fragment"
  else
    fail += 1
    puts "BAD   #{check}  should refuse a fragment (exit 3), got exit #{status.exitstatus}: #{output}"
  end
end

puts
puts "self-test: #{pass} ok, #{fail} bad"
exit(fail.zero? ? 0 : 1)
