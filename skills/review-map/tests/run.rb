#!/usr/bin/env ruby
# frozen_string_literal: true

# run.rb — the deterministic tests for review-map's scripts.
#
#   Usage: ruby skills/review-map/tests/run.rb [section...]
#
# Every section of suite.rb against this checkout, or the ones named. No network, no model, no API
# key, a few seconds. It runs in CI on every push, because a check that is not run is not a check;
# self-test.rb is what proves each of its assertions can fail.
#
# Exit 0 clean, 1 on any failure, 2 when called wrongly.

require "tmpdir"
require_relative "suite"

skill = File.expand_path("..", __dir__)
names = ARGV.map { |a| a.tr("-", "_").to_sym }
unknown = names - ReviewMapSuite::SECTIONS.keys
unless unknown.empty?
  warn "run.rb: unknown section #{unknown.join(", ")} (#{ReviewMapSuite::SECTIONS.keys.join(" ")})"
  exit 2
end

suite = Dir.mktmpdir("review-map-tests") do |tmp|
  ReviewMapSuite.new(skill, tmp).run_sections(names.empty? ? ReviewMapSuite::SECTIONS.keys : names)
end

failed = suite.failures.size
puts "", "run.rb: #{suite.results.size - failed} passed, #{failed} failed"
# A run that asserted nothing has not passed.
if suite.results.empty?
  warn "run.rb: no assertion ran"
  exit 1
end
exit(failed.zero? ? 0 : 1)
