#!/usr/bin/env ruby
# frozen_string_literal: true

# frozen.rb — the corpus, frozen, so deleting the shell does not delete the oracle.
#
# While both implementations existed, equivalence.rb graded every check against the .sh it
# shadowed, byte for byte, over ~1900 cases. That is the strongest regression net this
# directory has ever had, and it dies with the shell: after the flip there is nothing left to
# compare against. self-test.sh's rows are not a replacement — they pin ONE substring of one
# line each, where this pins every line, the exit code and stderr.
#
# So the output is frozen. Every case's exact bytes were captured from the Ruby at the moment
# equivalence.rb reported 1935 identical, 0 differing across 12 of 12 — which is what makes
# these files a record of what the SHELL did, transcribed by a port proven equal to it.
#
#   checks/frozen.rb                        # verify; exit 1 on any drift
#   checks/frozen.rb --freeze               # re-record, after a deliberate change
#   checks/frozen.rb behaviour-flows [...]  # one check, or several
#
# RE-FREEZING IS A REVIEWABLE ACT, and that is why this stores whole output rather than a
# digest: the diff of these files in a pull request says exactly which cases moved and how, so
# a reviewer can see that a wording change touched the twelve lines it meant to and not a
# thirteenth. A digest would say only that something changed.
#
# What it cannot do is notice a rule nobody wrote a fixture for. Two real divergences in this
# port were found by constructing inputs from a comment's own claims, after the whole corpus
# was green — so the tests in checks/lib/test/ matter as much as this does, and neither
# replaces the other.

require "etc"

require_relative "lib/review_map/fixture"
require_relative "lib/review_map/page"

HERE = __dir__
EVALS = File.dirname(HERE)
GOLD = File.join(EVALS, "golden")
FROZEN = File.join(HERE, "frozen")
MARK = "## "

def checks
  Dir[File.join(HERE, "*.rb")].sort.filter_map do |path|
    name = File.basename(path, ".rb")
    # equivalence and frozen grade the checks; self_test runs the whole suite. None of the
    # three is a check, and a corpus that ran self_test over every fixture would run the suite
    # once per case.
    #
    # diagram-shot is excluded for a different reason, and it is the one worth reading before
    # adding a check here: a frozen record has to be a function of the INPUT, and its verdict is
    # a function of the machine. It says "no Chrome found" on a container without a browser,
    # "no diagrams to render" on one with a browser and a fragment carrying no <svg>, a PASS per
    # rendered PNG on a runner where Chrome works, and a FAIL per image on one where Chrome
    # starts and cannot write — four different records for one input, and this repository has
    # produced three of the four. Recording any of them freezes an environment while reading as
    # a rule. It also renders as a side effect: a sweep would write six PNGs into
    # references/shots/ per case, into the checkout, which a read-only corpus must not do.
    #
    # The cost is real and stated rather than hidden: nothing pins diagram-shot now that the
    # shell it was graded against is deleted. That is the correct trade — it is the one check
    # whose product is images for a person to look at, and its own header says so.
    next if %w[equivalence frozen self-test diagram-shot].include?(name)

    name
  end
end

# The same two case sources equivalence.rb used, so the frozen corpus is the corpus it graded:
# the whole of golden/ and the real template in both kinds, plus every self-test row replayed
# with its own arguments — which is where --repo, --base and --level live.
def cases_for(check)
  inputs = Dir[File.join(GOLD, "*.html")].sort +
           [File.expand_path(File.join(EVALS, "..", "references", "page-template.html"))]
  sweep = inputs.select { |i| File.file?(i) }.flat_map { |i| [["--fragment", i], ["--page", i]] }

  rows = File.readlines(File.join(HERE, "self-test-cases.txt"), encoding: "UTF-8").filter_map do |line|
    next if line.strip.empty? || line.start_with?("#")

    script, fragment, _exit, _text, extra = line.split("|").map { |c| c.to_s.strip }
    next unless script == check

    ["--fragment", File.join(GOLD, fragment)] +
      ReviewMap.expand_fixtures(extra.to_s.gsub("@GOLD@", GOLD), GOLD).split
  end

  sweep + rows
end

def run(check, args)
  out, err, status = ReviewMap.capture({ "CHECK_TALLY" => "0" },
                                    "ruby", File.join(HERE, "#{check}.rb"), *args)
  # Paths are made relative to the evals directory so a record is the same on every machine.
  "exit=#{status.exitstatus}\n#{out}#{err}".gsub("#{EVALS}/", "")
end

def label(args)
  args.map { |a| a.start_with?("/") ? File.basename(a) : a }.join(" ")
end

def records(text)
  text.split(/^#{Regexp.escape(MARK)}/).reject(&:empty?)
end

freeze = ARGV.delete("--freeze")
wanted = ARGV
selected = wanted.empty? ? checks : checks.select { |c| wanted.include?(c) }
abort "no check matching: #{wanted.join(", ")}" if selected.empty?

Dir.mkdir(FROZEN) unless Dir.exist?(FROZEN)
drift = 0
seen = 0

# Concurrently, for the reason equivalence.rb is: ~1900 cases is ~1900 processes, and serially
# that is minutes, which is long enough that the oracle stops being run. Each case is
# independent and read-only; only the ORDER matters, so results are slotted by index.
def render(check)
  cases = cases_for(check)
  slots = Array.new(cases.size)
  queue = Queue.new
  cases.each_index { |i| queue << i }
  jobs = [Etc.nprocessors, 8, [cases.size, 1].max].min

  Array.new(jobs) do
    Thread.new do
      while (i = begin queue.pop(true) rescue nil end)
        slots[i] = "#{MARK}#{label(cases[i])}\n#{run(check, cases[i])}"
      end
    end
  end.each(&:join)

  slots.join
end

selected.each do |check|
  now = render(check)
  path = File.join(FROZEN, "#{check}.txt")

  if freeze
    File.write(path, now)
    seen += records(now).size
    next
  end

  unless File.exist?(path)
    puts "MISSING  #{check} has no frozen record — run with --freeze"
    drift += 1
    next
  end

  was = records(File.read(path, encoding: "UTF-8"))
  fresh = records(now)
  [was.size, fresh.size].max.times do |i|
    seen += 1
    before = was[i]
    after = fresh[i]
    next if before == after

    drift += 1
    puts "DRIFT    #{check}: #{(after || before).lines.first.to_s.chomp}"
    (before.to_s.lines | after.to_s.lines).each do |line|
      next if before.to_s.lines.include?(line) && after.to_s.lines.include?(line)

      puts "           #{before.to_s.lines.include?(line) ? "frozen" : "now   "}: #{line.chomp}"
    end
  end
end

puts
if freeze
  puts "frozen: #{seen} cases recorded across #{selected.size} checks"
else
  puts "frozen: #{seen - drift} unchanged, #{drift} drifted across #{selected.size} checks"
end
exit(drift.zero? || freeze ? 0 : 1)
