#!/bin/sh
# completeness.sh — every path in the diff appears in the ledger.
#
# Delegated to scripts/coverage-gate.sh so the rule has exactly one implementation;
# this wrapper only decides when running it is legitimate. That decision is the whole
# content of the script: a draft ships before the ledger is complete, and a gate that
# went red on every draft would teach people to ignore a red line.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_kind page

case $MODE in
  draft)
    skip "completeness: a draft ships before the ledger is complete" ;;
  stopped)
    skip "completeness: the gate does not run on a stopped run, and the page must say so" ;;
  *)
    if [ -z "$REPO" ] || [ -z "$BASE" ]; then
      bad "completeness: needs --repo and --base to compare the ledger against the diff"
    elif (cd "$REPO" && "$SKILL_DIR/scripts/coverage-gate.sh" "$IN" "$BASE" "$HEAD_REF" >/dev/null 2>&1); then
      ok "coverage gate: every changed path is in the ledger"
    else
      bad "coverage gate failed — run scripts/coverage-gate.sh directly to see which paths"
    fi ;;
esac

finish
