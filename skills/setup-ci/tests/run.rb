#!/usr/bin/env ruby
# frozen_string_literal: true

# run.rb — the deterministic tests for the CI setup.
#
#   Usage: ruby skills/setup-ci/tests/run.rb [section...]
#
# Every section of suite.rb against this checkout, or the ones named. No network, no model, no API
# key, a few seconds. It runs in CI on every push, because a check that is not run is not a check;
# self-test.rb is what proves each of its assertions can fail.
#
# Exit 0 clean, 1 on any failure, 2 when called wrongly.

require "tmpdir"
require_relative "suite"

root = File.expand_path("../../..", __dir__)
names = ARGV.map(&:to_sym)
unknown = names - SetupCiSuite::SECTIONS.keys
unless unknown.empty?
  warn "run.rb: unknown section #{unknown.join(", ")} (#{SetupCiSuite::SECTIONS.keys.join(" ")})"
  exit 2
end

suite = Dir.mktmpdir("setup-ci-tests") do |tmp|
  SetupCiSuite.new(root, tmp).run_sections(names.empty? ? SetupCiSuite::SECTIONS.keys : names)
end

failed = suite.failures.size
puts "", "run.rb: #{suite.results.size - failed} passed, #{failed} failed"
exit(failed.zero? ? 0 : 1)
