#!/usr/bin/env ruby
# frozen_string_literal: true

# hooks/activity.json is the one table naming what a review-map run is doing, and it has two
# readers in two languages: the e2e board (evals/e2e/progress.rb, Ruby) and the status line an
# interactive session draws (hooks/progress.ts, JavaScript). One file stops the two copies drifting;
# this check stops the one file saying different things to its two readers, which is how a shared
# table drifts once there is only one of it.
#
# Four rules. Every row is a [pattern, label] pair of strings. Every pattern compiles in Ruby and
# uses no construct that JavaScript reads differently or not at all — `\A`, `\z`, `\h`, an inline
# flag, a possessive quantifier — since `claude plugin test` runs with no file system and cannot
# read the shipped table for itself. No label is a step counter, because steps cannot be read off a
# run (evals/README.md § Profiling one run) and the line says activity by purpose or says nothing.
# And both readers name this file: progress.rb by path, progress.ts by `$.plugin.root`.
#
# Then it breaks each rule on a copy and asserts the check fails, because a check that passes
# because it never looked is worse than no check.
#
# Usage: ruby skills/review-map/tests/activity.rb   (exit 0 clean, 1 on any failure)

require "json"

ROOT = File.expand_path("../../..", __dir__)
TABLE = "hooks/activity.json"
MOD = "hooks/progress.ts"
BOARD = "skills/review-map/evals/e2e/progress.rb"

# What Ruby accepts and JavaScript does not, or reads as something else.
RUBY_ONLY = {
  /\\[AzZGhHKRX]/ => "an anchor or class JavaScript lacks",
  /\(\?[imx-]+[):]/ => "an inline flag",
  /[*+?}]\+/ => "a possessive quantifier",
  /\(\?#/ => "a comment group",
  /\\p\{\^/ => "a negated property in Ruby's spelling",
}.freeze

STEP = /\bsteps?\b|\bstage\b|\d+\s*(\/|of)\s*\d+/i

def problems(json, mod_src, board_src)
  rows = begin
    JSON.parse(json)
  rescue JSON::ParserError => e
    return ["#{TABLE} is not valid JSON: #{e.message.lines.first.strip}"]
  end
  return ["#{TABLE} must be a non-empty array"] unless rows.is_a?(Array) && !rows.empty?

  out = []
  rows.each_with_index do |row, i|
    unless row.is_a?(Array) && row.size == 2 && row.all?(String)
      out << "row #{i} is not a [pattern, label] pair of strings"
      next
    end
    pattern, label = row
    begin
      Regexp.new(pattern)
    rescue RegexpError => e
      out << "row #{i} does not compile in Ruby: #{e.message}"
    end
    RUBY_ONLY.each { |re, what| out << "row #{i} uses #{what}: #{pattern}" if pattern.match?(re) }
    out << "row #{i}'s label reads as a step counter: #{label}" if label.match?(STEP)
  end
  out << "#{MOD} does not read #{TABLE}" unless mod_src.include?("${$.plugin.root}/#{TABLE}")
  out << "#{BOARD} does not read #{TABLE}" unless board_src.include?("hooks/activity.json")
  out
end

def read(rel) = File.read(File.join(ROOT, rel), encoding: "UTF-8")

json = read(TABLE)
mod = read(MOD)
board = read(BOARD)

failures = problems(json, mod, board)

# progress.rb really reads it: the interactive page, which only the shared table names, maps.
require_relative "../evals/e2e/progress"
got = Progress::ACTIVITY.find { |re, _| "Edit   /tmp/review-map/app-pr-7/page.html ".match?(re) }&.last
failures << "progress.rb does not map an Edit of $W/page.html to writing the page (got #{got.inspect})" unless got&.include?("writing the page")
# And reading it is not writing it: --update greps an index out of the page and Reads by offset.
["Read   /tmp/review-map/app-pr-7/page.html ", "Bash  rg -n 'id=\"cp-' /tmp/review-map/app-pr-7/page.html  "].each do |s|
  got = Progress::ACTIVITY.find { |re, _| s.match?(re) }&.last
  failures << "progress.rb labels a read of the page as writing it: #{s.strip}" if got&.include?("writing the page")
end

rows = JSON.parse(json)
MUTATIONS = {
  "a malformed row" => [JSON.generate(rows + [["only a pattern"]]), mod, board],
  "a pattern Ruby cannot compile" => [JSON.generate(rows + [["(unclosed", "x"]]), mod, board],
  "a Ruby-only anchor" => [JSON.generate(rows + [["\\Agit diff", "x"]]), mod, board],
  "an inline flag" => [JSON.generate(rows + [["(?i)grep", "x"]]), mod, board],
  "a possessive quantifier" => [JSON.generate(rows + [["a++", "x"]]), mod, board],
  "a step counter" => [JSON.generate(rows + [["x", "🧭 step 3 of 10"]]), mod, board],
  "a fraction of steps" => [JSON.generate(rows + [["x", "🧭 3/10"]]), mod, board],
  "the mod reading another file" => [json, mod.gsub(TABLE, "hooks/other.json"), board],
  "the board reading another file" => [json, mod, board.gsub("hooks/activity.json", "hooks/other.json")],
  "not JSON" => ["[", mod, board],
}.freeze

missed = MUTATIONS.filter_map { |name, args| name if problems(*args).empty? }

failures.each { |f| puts "FAIL #{f}" }
missed.each { |m| puts "FAIL self-test: breaking it with #{m} went unnoticed" }
if failures.empty? && missed.empty?
  puts "activity: #{rows.size} rows clean, #{MUTATIONS.size} breaks caught"
  exit 0
end
exit 1
