#!/usr/bin/env ruby
# frozen_string_literal: true

# completeness.rb — every path in the diff appears in the ledger.
#
# Delegated to scripts/coverage-gate.sh so the rule has exactly one implementation, and
# that delegation survives the port deliberately: coverage-gate.sh is runtime code, run by
# SKILL.md step 10 inside the user's own project, so reimplementing the comparison here
# would give the invariant two implementations that could disagree — which is the failure
# the delegation exists to prevent.
#
# This wrapper only decides when running it is legitimate. That decision is the whole
# content of the script: a draft ships before the ledger is complete, and a gate that went
# red on every draft would teach people to ignore a red line.

require_relative "lib/review_map/check"

check = ReviewMap::Check.new(ARGV, name: "completeness.sh")
check.require_kind(:page)

case check.mode
when "draft"
  check.skip("completeness: a draft ships before the ledger is complete")
when "stopped"
  check.skip("completeness: the gate does not run on a stopped run, and the page must say so")
else
  gate = File.join(ReviewMap::Check::SKILL_DIR, "scripts", "coverage-gate.sh")
  if check.repo.to_s.empty? || check.base.to_s.empty?
    check.bad("completeness: needs --repo and --base to compare the ledger against the diff")
  else
    # The page path is passed through exactly as given, from inside --repo, because that is
    # what the shell did and the gate resolves it itself.
    _out, passed = check.shell(gate, check.input, check.base, check.head_ref, chdir: check.repo)
    if passed
      check.ok("coverage gate: every changed path is in the ledger")
    else
      check.bad("coverage gate failed — run scripts/coverage-gate.sh directly to see which paths")
    end
  end
end

check.finish
