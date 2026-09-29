#!/usr/bin/env ruby
# frozen_string_literal: true

# verdicts.rb — read one verdicts.json and say what it contains.
#
#   e2e/verdicts.rb <file> [--expected N] [--counts]
#
# The port of verdict-tally.sh, with the same arguments, the same lines and the same exit codes,
# so checks/self-test.rb pins it against the same golden/verdicts-*.json it pinned the shell with.
# judge.rb calls Verdicts.read directly rather than shelling out to this file.
#
# The parsing is the part of the judged half worth testing without a model: a tally that silently
# reads a truncated verdict file as "no fails" is the same failure as a check script that always
# passes, and worse, because what it emits looks like a measurement.
#
# Verdicts print lowercase, so a judged verdict is never mistaken for a mechanical PASS/FAIL in a
# shared log. Exit 1 means the file is unusable, which is different from a fail inside it.

require "json"

module Verdicts
  VALUES = %w[pass fail unclear].freeze

  Unusable = Class.new(StandardError)

  # Returns the parsed document. Raises Unusable with the sentence the CLI prints.
  def self.read(path)
    raise Unusable, "no verdict file at #{path}" unless File.readable?(path)

    doc = parse(File.read(path, encoding: "UTF-8"))
    unless doc
      raise Unusable, "#{path} is not JSON, and stripping a code fence did not make it JSON"
    end
    unless doc.is_a?(Hash) && doc["verdicts"].is_a?(Array)
      raise Unusable, "#{path} has no verdicts array"
    end

    doc
  end

  # A fenced or prose-wrapped answer is a formatting slip, not a failed judgement. Recover it once,
  # in memory — what the judge actually wrote stays on disk as the evidence of how it answered.
  def self.parse(text)
    JSON.parse(text)
  rescue JSON::ParserError
    unfenced = text.lines.reject { |l| l.match?(/\A\s*```(json)?\s*\z/) }
    start = unfenced.index { |l| l.match?(/[{\[]/) }
    return nil unless start

    begin
      JSON.parse(unfenced[start..].join)
    rescue JSON::ParserError
      nil
    end
  end

  def self.counts(doc)
    vs = doc["verdicts"]
    VALUES.to_h { |v| [v, vs.count { |x| x.is_a?(Hash) && x["verdict"] == v }] }
  end
end

if $PROGRAM_NAME == __FILE__
  file = nil
  expected = nil
  counts_only = false
  args = ARGV.dup
  until args.empty?
    a = args.shift
    case a
    when "--expected" then expected = Integer(args.shift)
    when "--counts" then counts_only = true
    when /\A-/
      warn "unknown argument: #{a}"
      exit 2
    else file = a
    end
  end
  unless file
    warn "usage: verdicts.rb <verdicts.json> [--expected N] [--counts]"
    exit 2
  end

  begin
    doc = Verdicts.read(file)
  rescue Verdicts::Unusable => e
    puts(counts_only ? "0 0 0" : "unusable  #{e.message}")
    exit 1
  end

  c = Verdicts.counts(doc)
  if counts_only
    puts "#{c['pass']} #{c['fail']} #{c['unclear']}"
    exit 0
  end

  doc["verdicts"].each { |v| puts "#{v['verdict']}  #{v['n']} · #{v['why']}" }

  notes = doc["notes"].to_s
  unless notes.empty?
    puts
    puts "note on the expectations: #{notes}"
  end

  # A verdict count that does not match the criterion count means one was skipped or invented,
  # and either way the tally below answers a different question than the one that was asked.
  n = doc["verdicts"].length
  puts
  puts "mismatch  #{n} verdict(s) for #{expected} expectation(s) — one was skipped or invented" if expected && n != expected
  other = n - c.values.sum
  puts "mismatch  #{other} verdict(s) carry a value that is not pass, fail or unclear" unless other.zero?
  puts "judged: #{c['pass']} pass, #{c['fail']} fail, #{c['unclear']} unclear"
end
