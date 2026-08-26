#!/bin/sh
# verdict-tally.sh — read one verdicts.json and say what it contains.
#
#   ./verdict-tally.sh <file> [--expected N] [--counts]
#
# Both judge.sh and run.sh need this, so it lives in one place and self-test.sh can reach it. The
# parsing is the part worth testing without a model: a tally that silently reads a truncated verdict
# file as "no fails" is the same failure as a check script that always passes.
#
# Verdicts print lowercase, so a judged verdict is never mistaken for a mechanical PASS/FAIL in a
# shared log. Exit 1 means the file is unusable, which is different from a fail inside it.
set -eu

FILE=; EXPECTED=; COUNTS=
while [ $# -gt 0 ]; do
  case $1 in
    --expected) EXPECTED=$2; shift 2 ;;
    --counts)   COUNTS=1; shift ;;
    -*) echo "unknown argument: $1" >&2; exit 2 ;;
    *) FILE=$1; shift ;;
  esac
done
[ -n "$FILE" ] || { echo "usage: verdict-tally.sh <verdicts.json> [--expected N] [--counts]" >&2; exit 2; }
command -v jq >/dev/null || { echo "verdict-tally.sh needs jq" >&2; exit 2; }

if [ ! -r "$FILE" ]; then
  [ -n "$COUNTS" ] && { echo "0 0 0"; exit 1; }
  echo "unusable  no verdict file at $FILE"
  exit 1
fi

# A fenced or prose-wrapped answer is a formatting slip, not a failed judgement. Recover it once,
# into a copy — rewriting what the judge wrote would destroy the evidence of how it answered.
SRC=$FILE
if ! jq -e . "$FILE" >/dev/null 2>&1; then
  # Into a temp file, never over the original: what the judge actually wrote is the evidence for how
  # it answered, and a recovery that overwrites it destroys that. It also means this script never
  # writes into the directory it was pointed at.
  RECOVERED=$(mktemp)
  trap 'rm -f "$RECOVERED"' EXIT
  sed -e 's/^[[:space:]]*```json[[:space:]]*$//' -e 's/^[[:space:]]*```[[:space:]]*$//' "$FILE" \
    | sed -n '/[{[]/,$p' > "$RECOVERED"
  if jq -e . "$RECOVERED" >/dev/null 2>&1; then
    SRC=$RECOVERED
  else
    [ -n "$COUNTS" ] && { echo "0 0 0"; exit 1; }
    echo "unusable  $FILE is not JSON, and stripping a code fence did not make it JSON"
    exit 1
  fi
fi

if ! jq -e '.verdicts | type == "array"' "$SRC" >/dev/null 2>&1; then
  [ -n "$COUNTS" ] && { echo "0 0 0"; exit 1; }
  echo "unusable  $FILE has no verdicts array"
  exit 1
fi

p=$(jq '[.verdicts[] | select(.verdict == "pass")]    | length' "$SRC")
f=$(jq '[.verdicts[] | select(.verdict == "fail")]    | length' "$SRC")
u=$(jq '[.verdicts[] | select(.verdict == "unclear")] | length' "$SRC")
n=$(jq '.verdicts | length' "$SRC")

if [ -n "$COUNTS" ]; then
  echo "$p $f $u"
  exit 0
fi

jq -r '.verdicts[] | "\(.verdict)  \(.n) · \(.why)"' "$SRC"

notes=$(jq -r '.notes // ""' "$SRC")
[ -z "$notes" ] || { echo; echo "note on the expectations: $notes"; }

# A verdict count that does not match the expectation count means one was skipped or invented, and
# either way the tally below is answering a different question than the one that was asked.
echo
if [ -n "$EXPECTED" ] && [ "$n" -ne "$EXPECTED" ]; then
  echo "mismatch  $n verdict(s) for $EXPECTED expectation(s) — one was skipped or invented"
fi
other=$((n - p - f - u))
[ "$other" -eq 0 ] || echo "mismatch  $other verdict(s) carry a value that is not pass, fail or unclear"
echo "judged: $p pass, $f fail, $u unclear"
