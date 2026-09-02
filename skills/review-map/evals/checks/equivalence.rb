#!/usr/bin/env ruby
# frozen_string_literal: true

# equivalence.rb — the Ruby check against the shell one it shadows, byte for byte.
#
# This is scaffolding with a known end: it exists so the port can be judged on evidence
# rather than on taste, and it gets deleted along with the .sh it compares against. Until
# then it is the strongest oracle available — stronger than the rows in self-test.sh, which
# pin one substring of one line each, where this pins every line, the exit code and stderr,
# over every fragment in golden/ and over the real template.
#
# The contract it enforces is byte-identical output, and that is deliberate rather than
# fussy: the PASS / FAIL / WARN / SKIP strings ARE this directory's product — they are what
# a maintainer reads when a wording change in the skill moves a number — so a port that
# reworded them would be a rewrite of the thing under measurement, dressed as a refactor.
#
#   checks/equivalence.rb              # every fragment in golden/, plus the template
#   checks/equivalence.rb path.html    # just these

require "open3"

HERE  = __dir__
EVALS = File.dirname(HERE)
SHELL = File.join(HERE, "behaviour-flows.sh")
RUBY_ = File.join(HERE, "behaviour_flows.rb")

inputs =
  if ARGV.empty?
    Dir[File.join(EVALS, "golden", "*.html")].sort +
      [File.join(EVALS, "..", "references", "page-template.html")]
  else
    ARGV
  end

# Both kinds on every input, not just the kind the file was authored as. The narrowing
# branch in this check behaves differently for a page and a fragment — a page with no flow
# sections FAILs where a fragment falls through to its whole self — so grading each input
# only as what it looks like would leave that branch uncompared on most of the corpus.
KINDS = %w[--fragment --page].freeze

def run(script, kind, input)
  interpreter = script.end_with?(".rb") ? ["ruby"] : []
  out, err, status = Open3.capture3({ "CHECK_TALLY" => "0" }, *interpreter, script, kind, input)
  [out + err, status.exitstatus]
end

ok = 0
bad = 0

inputs.each do |input|
  next unless File.file?(input)

  KINDS.each do |kind|
    shell_out, shell_rc = run(SHELL, kind, input)
    ruby_out, ruby_rc = run(RUBY_, kind, input)
    name = "#{kind.delete_prefix("--")} #{File.basename(input)}"

    if shell_out == ruby_out && shell_rc == ruby_rc
      ok += 1
      next
    end

    bad += 1
    puts "BAD   #{name} — sh exit #{shell_rc}, rb exit #{ruby_rc}"
    shell_lines = shell_out.lines
    ruby_lines = ruby_out.lines
    (shell_lines | ruby_lines).each do |line|
      next if shell_lines.include?(line) && ruby_lines.include?(line)

      puts "        #{shell_lines.include?(line) ? "sh only" : "rb only"}: #{line}"
    end
  end
end

puts
puts "equivalence: #{ok} identical, #{bad} differing"
exit(bad.zero? ? 0 : 1)
