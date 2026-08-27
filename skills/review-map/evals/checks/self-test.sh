#!/bin/sh
# self-test.sh — the checks, checked.
#
# A check script that always passes is worse than no check script: it turns an unchecked
# rule into one the reader believes is checked. Every fragment in ../golden plants exactly
# one defect, and the table below says what each check is supposed to say about it.
#
# No model, no fixtures, about a second. That is why it belongs in CI next to
# `claude plugin validate`.
#
#   script | golden fragment | expected exit | a substring the output must contain | extra args
#
# Expected exit is 0 or 1. A WARN is not a failure, so a fragment that only warns expects
# 0 and is pinned by its substring instead.
#
# The fifth column is optional and exists for a check that needs more than a fragment. @GOLD@
# expands to the golden directory, so searches.sh can be handed a repository to search: it is
# the one check whose rule is a relation between the page and a repo, and a check that can only
# SKIP here is exactly what this file exists to prevent.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EVALS=$(dirname "$HERE")
GOLD=$EVALS/golden

pass=0; fail=0

run_case() {
  script=$1; fragment=$2; want_exit=$3; want_text=$4; extra=$5
  # Trim the column padding. It used to be harmless, because want_text ran to end of line; with
  # a fifth column it ends at a "|" and carries the spaces before it, so an untrimmed substring
  # matches nothing and every row with extra args fails for a reason that is not about the check.
  want_text=$(printf '%s' "$want_text" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  extra=$(printf '%s' "$extra" | sed "s|@GOLD@|$GOLD|g")
  # Unquoted on purpose: the column is a short argument list, not one argument.
  out=$(CHECK_TALLY=0 "$HERE/$script" --fragment "$GOLD/$fragment" $extra 2>&1) && got=0 || got=$?
  problem=
  [ "$got" = "$want_exit" ] || problem="exit $got, wanted $want_exit"
  case $out in
    *"$want_text"*) : ;;
    *) problem="${problem:+$problem; }no line matching \"$want_text\"" ;;
  esac
  if [ -z "$problem" ]; then
    pass=$((pass + 1)); echo "ok    $script  $fragment"
  else
    fail=$((fail + 1)); echo "BAD   $script  $fragment — $problem"
    echo "$out" | sed 's/^/        /'
  fi
}

while IFS='|' read -r s f e t x; do
  case $s in ''|\#*) continue ;; esac
  run_case "$(echo "$s" | tr -d ' ')" "$(echo "$f" | tr -d ' ')" "$(echo "$e" | tr -d ' ')" "$t" "$x"
done <<'CASES'
diagram.sh          | diagram-clean.html            | 0 | labels fit their boxes
diagram.sh          | diagram-literal-colour.html   | 1 | is a literal colour
diagram.sh          | diagram-offcanvas.html        | 1 | outside the 880x200 viewBox
diagram.sh          | diagram-invented-class.html   | 1 | is not in the template vocabulary
diagram.sh          | diagram-label-overflow.html   | 0 | likely spills
diagram.sh          | diagram-no-legend.html        | 1 | reads as deleted
diagram.sh          | diagram-placeholder.html      | 1 | survives inside the diagram
diagram.sh          | diagram-unwrapped.html        | 1 | is not inside .scroller
diagram.sh          | diagram-edge-label-collision.html | 0 | runs under a box
behaviour-flows.sh  | flows-clean.html              | 0 | no flow is grouped by directory
behaviour-flows.sh  | flows-layer-grouped.html      | 1 | is a layer name
behaviour-flows.sh  | flows-unit-no-understand.html | 1 | has no things-to-understand
behaviour-flows.sh  | flows-unit-uncited.html       | 1 | makes claims with no file:line
blast-radius.sh     | blast-clean.html              | 0 | point into the flows that explain them
blast-radius.sh     | blast-readorder.html          | 1 | the reading order lives in section 3
blast-radius.sh     | blast-no-pointer.html         | 0 | an in-page anchor works at every link rung
blast-radius.sh     | blast-pointer-restated.html   | 1 | carry more than one citation
searches.sh         | searches-clean.html           | 0 | reachable from a recorded search | --repo @GOLD@/searches-repo
searches.sh         | searches-unreachable.html     | 1 | reachable from no recorded search | --repo @GOLD@/searches-repo
searches.sh         | searches-clean.html           | 0 | needs --repo to re-run
start-here.sh       | start-here-clean.html         | 0 | each with a why
start-here.sh       | start-here-no-why.html        | 1 | is not a reading order
start-here.sh       | start-here-two-lists.html     | 1 | it is one list
before-approving.sh | approving-clean.html          | 0 | within the cap of 5
before-approving.sh | approving-six-questions.html  | 1 | the cap is 5
page-invariants.sh  | invariants-clean.html         | 0 | no severity chips
page-invariants.sh  | invariants-severity-chip.html | 1 | severity chips reintroduced
page-invariants.sh  | invariants-verdict.html       | 1 | verdict language found
page-invariants.sh  | invariants-no-tier.html       | 1 | no evidence tier labels
page-invariants.sh  | invariants-loose-data-path.html | 1 | outside a <td>
excerpts.sh         | excerpt-clean.html            | 0 | collapsed by default
excerpts.sh         | excerpt-open.html             | 1 | open by default
excerpts.sh         | excerpt-duplicate.html        | 1 | same range is excerpted more than once
CASES

# The judged half has one piece a script can test: reading a verdict file. A tally that reads a
# truncated or fenced file as "no fails" is the same defect as a check that always passes, and it is
# worse here because the number it produces looks like a measurement.
tally() {
  fragment=$1; want_exit=$2; want_text=$3; shift 3
  out=$(CHECK_TALLY=0 "$EVALS/verdict-tally.sh" "$GOLD/$fragment" "$@" 2>&1) && got=0 || got=$?
  problem=
  [ "$got" = "$want_exit" ] || problem="exit $got, wanted $want_exit"
  case $out in
    *"$want_text"*) : ;;
    *) problem="${problem:+$problem; }no line matching \"$want_text\"" ;;
  esac
  if [ -z "$problem" ]; then
    pass=$((pass + 1)); echo "ok    verdict-tally.sh  $fragment"
  else
    fail=$((fail + 1)); echo "BAD   verdict-tally.sh  $fragment — $problem"
    echo "$out" | sed 's/^/        /'
  fi
}

tally verdicts-clean.json     0 "judged: 6 pass, 0 fail, 0 unclear" --expected 6
tally verdicts-mixed.json     0 "judged: 4 pass, 1 fail, 1 unclear" --expected 6
tally verdicts-mixed.json     0 "note on the expectations:"         --expected 6
tally verdicts-short.json     0 "3 verdict(s) for 6 expectation(s)" --expected 6
tally verdicts-fenced.json    0 "judged: 1 pass"                    --expected 1
tally verdicts-prose.json     1 "is not JSON"                       --expected 6
tally verdicts-bad-value.json 0 "carry a value that is not"         --expected 2
tally verdicts-clean.json     0 "6 0 0"                             --counts

# The page-only checks refuse a fragment rather than passing on evidence they do not have.
# That refusal is itself a rule worth pinning: exit 3, and a SKIP line saying why.
for s in completeness.sh build-state.sh; do
  out=$(CHECK_TALLY=0 "$HERE/$s" --fragment "$GOLD/flows-clean.html" 2>&1) && got=0 || got=$?
  case "$got:$out" in
    3:*"needs a whole page"*) pass=$((pass + 1)); echo "ok    $s  refuses a fragment" ;;
    *) fail=$((fail + 1)); echo "BAD   $s  should refuse a fragment (exit 3), got exit $got: $out" ;;
  esac
done

echo
echo "self-test: $pass ok, $fail bad"
[ "$fail" -eq 0 ]
