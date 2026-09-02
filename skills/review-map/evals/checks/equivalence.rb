#!/usr/bin/env ruby
# frozen_string_literal: true

# equivalence.rb — every ported check against the shell one it shadows, byte for byte.
#
# This is scaffolding with a known end: it exists so the port can be judged on evidence
# rather than on taste, and it is deleted along with the .sh files it compares against.
# Until then it is the strongest oracle available — stronger than the rows in self-test.sh,
# which pin one substring of one line each, where this pins every line, the exit code and
# stderr, over the whole corpus.
#
# The contract it enforces is byte-identical output, and that is deliberate rather than
# fussy: the PASS / FAIL / WARN / SKIP strings ARE this directory's product — they are what
# a maintainer reads when a wording change in the skill moves a number — so a port that
# reworded them would be a rewrite of the thing under measurement, dressed as a refactor.
#
#   checks/equivalence.rb                  # every pair, both case sources
#   checks/equivalence.rb blast-radius     # just this check
#   checks/equivalence.rb -v               # name every case, not just the differing ones
#   checks/equivalence.rb -j 1             # serially, when a failure needs isolating
#
# It runs the cases concurrently, for the same reason run.sh takes -j: a thousand cases
# means two thousand processes, and serially that is two minutes, which is long enough that
# the oracle stops being run. Every case is independent and read-only, so the only thing
# concurrency costs is that results must be re-ordered before printing — which they are,
# because a diff report that arrives in a different order each run is not a diff report.
#
# TWO case sources, because one is not enough. The corpus sweep runs both kinds over every
# fragment in golden/ and catches shape divergence. It never passes --repo, --base or
# --level, so it would compare two SKIPs for searches.sh — whose entire rule is a relation
# between the page and a repository — and would miss the brief level altogether. So the
# rows of self-test.sh are replayed as well, with their own arguments.

require "etc"
require "open3"

HERE  = __dir__
EVALS = File.dirname(HERE)
GOLD  = File.join(EVALS, "golden")

# diagram-shot.sh is not in the port: it renders PNGs through Playwright, which makes it a
# driver rather than a rule check. Naming it here rather than letting it fall out of pair
# discovery is the difference between a decision and an oversight.
NOT_PORTED = ["diagram-shot.sh"].freeze
NOT_CHECKS = ["lib.sh", "self-test.sh"].freeze

Pair = Struct.new(:name, :shell, :ruby)

def pairs
  Dir[File.join(HERE, "*.sh")].sort.filter_map do |shell|
    base = File.basename(shell)
    next if NOT_CHECKS.include?(base)

    name = base.delete_suffix(".sh")
    ruby = File.join(HERE, "#{name.tr("-", "_")}.rb")
    Pair.new(name, shell, File.exist?(ruby) ? ruby : nil)
  end
end

# Every case is an argument list, so a case source is just a list of those.
def sweep_cases
  inputs = Dir[File.join(GOLD, "*.html")].sort +
           [File.expand_path(File.join(EVALS, "..", "references", "page-template.html"))]
  inputs.select { |i| File.file?(i) }.flat_map do |input|
    # Both kinds on every input, not only the kind the file was authored as: the narrowing
    # branches behave differently for a page and a fragment, so grading each input as what
    # it looks like would leave those branches uncompared on most of the corpus.
    [["--fragment", input], ["--page", input]]
  end
end

# The rows of self-test.sh, which are where --repo, --level and the page-only invocations
# live. Parsed rather than duplicated: a row added there is a case here, automatically.
def self_test_cases(check)
  rows = File.readlines(File.join(HERE, "self-test.sh"), encoding: "UTF-8")
  rows.filter_map do |line|
    script, fragment, _exit, _text, extra = line.split("|").map { |c| c.to_s.strip }
    next unless script == "#{check}.sh"

    args = ["--fragment", File.join(GOLD, fragment)]
    args + extra.to_s.gsub("@GOLD@", GOLD).split
  end
end

def run(script, args)
  interpreter = script.end_with?(".rb") ? ["ruby"] : []
  out, err, status = Open3.capture3({ "CHECK_TALLY" => "0" }, *interpreter, script, *args)
  [out + err, status.exitstatus]
end

def report_difference(label, shell_out, ruby_out)
  shell_lines = shell_out.lines
  ruby_lines = ruby_out.lines
  (shell_lines | ruby_lines).each do |line|
    next if shell_lines.include?(line) && ruby_lines.include?(line)

    puts "        #{shell_lines.include?(line) ? "sh only" : "rb only"}: #{line.chomp}"
  end
  puts "        (#{label})"
end

verbose = ARGV.delete("-v")
jobs = (i = ARGV.index("-j")) ? ARGV.slice!(i, 2).last.to_i : [Etc.nprocessors, 8].min
wanted = ARGV
selected = pairs.select { |p| wanted.empty? || wanted.include?(p.name) }
abort "no check matching: #{wanted.join(", ")}" if selected.empty?

unported = selected.reject(&:ruby).map(&:name) - NOT_PORTED.map { |f| f.delete_suffix(".sh") }

work = selected.select(&:ruby).flat_map do |pair|
  (sweep_cases + self_test_cases(pair.name)).map { |args| [pair, args] }
end

results = Array.new(work.size)
queue = Queue.new
work.each_index { |i| queue << i }
jobs = 1 if jobs < 1

Array.new([jobs, work.size].min.clamp(1, nil)) do
  Thread.new do
    while (index = queue.pop(true) rescue nil)
      pair, args = work[index]
      shell_out, shell_rc = run(pair.shell, args)
      ruby_out, ruby_rc = run(pair.ruby, args)
      results[index] = [pair, args, shell_out, shell_rc, ruby_out, ruby_rc]
    end
  end
end.each(&:join)

ok = 0
bad = 0
results.each do |pair, args, shell_out, shell_rc, ruby_out, ruby_rc|
  label = "#{pair.name} #{args.map { |a| a.start_with?("/") ? File.basename(a) : a }.join(" ")}"
  if shell_out == ruby_out && shell_rc == ruby_rc
    ok += 1
    puts "same  #{label}" if verbose
    next
  end

  bad += 1
  puts "BAD   #{label} — sh exit #{shell_rc}, rb exit #{ruby_rc}"
  report_difference(label, shell_out, ruby_out)
end

puts
# Naming what is still shell is the whole reason this reports a denominator. A partial
# migration that printed only "0 differing" would read as a finished one.
puts "still shell: #{unported.join(", ")}" if unported.any?
ported = selected.count(&:ruby)
scope = selected.size > 1 ? " across #{ported} of #{selected.size} checks" : ""
puts "equivalence: #{ok} identical, #{bad} differing#{scope}"
exit(bad.zero? ? 0 : 1)
