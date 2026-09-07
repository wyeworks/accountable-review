#!/bin/sh
# judge.sh — the judged half of a section eval, in one pass over one fragment.
#
#   ./judge.sh --fragment <file> --case behaviour-flows --fixture monorepo-contract
#   ./judge.sh --fragment <file> --case behaviour-flows --fixture monorepo-contract --model sonnet --effort low
#
# checks/ settles the yes-or-no facts. The expectations in cases/<slug>.json are the other half, and
# until now nothing read them: run.sh printed "read the fragments against them", which made the cheap
# half cheap and left the expensive half exactly as expensive as before.
#
# One pass over all the expectations, deliberately, to start with. It is the cheaper arrangement and
# the one whose failure mode is known: a grader asked to verify many things at once verifies all of
# them less carefully, which is the argument this repository already makes for keeping the mechanical
# checks out of the rubric. Six is small enough to be worth trying before paying for one call each.
#
# What makes the verdicts mean anything is not the rubric, it is the anchoring: the judge runs INSIDE
# the fixture, with the frozen upstream, so "is this claim right" is settled against the code. Take
# that away and it degrades into a second opinion about prose.
#
# The judge never sees the mechanical results. Two independent readings are worth more than one
# reading anchored to another.
#
# --model and --effort exist for symmetry with run.sh, not because they are a good idea here. The
# producer is the thing under test and can be read by a cheaper model while a wording change is
# being shaped; the judge IS the reading, so a cheap judge does not make the loop faster, it makes
# the number softer. Whatever is used lands in results/<case>.jsonl under judge_model, so a run
# graded by a cheaper reader is at least labelled as one.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_DIR=$(dirname "$HERE")

FRAGMENT=; CASE=; FIXTURE=; OUTDIR=
MODEL=${EVAL_JUDGE_MODEL:-}; EFFORT=${EVAL_JUDGE_EFFORT:-}
while [ $# -gt 0 ]; do
  case $1 in
    --fragment) FRAGMENT=$2; shift 2 ;;
    --case)     CASE=$2;     shift 2 ;;
    --fixture)  FIXTURE=$2;  shift 2 ;;
    --out)      OUTDIR=$2;   shift 2 ;;
    --model)    MODEL=$2;    shift 2 ;;
    --effort)   EFFORT=$2;   shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$FRAGMENT" ] || [ -z "$CASE" ] || [ -z "$FIXTURE" ]; then
  echo "usage: judge.sh --fragment <file> --case <slug> --fixture <name> [--out <dir>]" >&2
  echo "                [--model M] [--effort low|medium|high|xhigh|max]" >&2
  exit 2
fi
[ -r "$FRAGMENT" ] || { echo "fragment is not readable: $FRAGMENT" >&2; exit 2; }
CASEFILE=$HERE/cases/$CASE.json
[ -r "$CASEFILE" ] || { echo "no such case: $CASEFILE" >&2; exit 2; }
command -v jq >/dev/null || { echo "judge.sh needs jq" >&2; exit 2; }
command -v claude >/dev/null || { echo "judge.sh needs claude on PATH" >&2; exit 2; }

FIXTURES=${REVIEW_MAP_FIXTURES:-${TMPDIR:-/tmp}/review-map-fixtures}
FIXTURE_DIR=$FIXTURES/$FIXTURE
[ -d "$FIXTURE_DIR" ] || { echo "fixture not built: $FIXTURE_DIR — run fixtures/make-fixtures.sh" >&2; exit 2; }

OUT=${OUTDIR:-$(dirname "$FRAGMENT")}
mkdir -p "$OUT"
VERDICT=$OUT/verdicts.json
PROMPT=$OUT/judge-prompt.md
LOG=$OUT/judge.log

sel=".cases[] | select(.fixture == \"$FIXTURE\")"
EXPECTED=$(jq -r "$sel | .expected_output" "$CASEFILE")
SECTION=$(jq -r '.section + " — " + .of' "$CASEFILE")
if [ -z "$EXPECTED" ] || [ "$EXPECTED" = null ]; then
  echo "no case for fixture \"$FIXTURE\" in $CASEFILE" >&2
  exit 2
fi

# Numbered, so a verdict's n means something and a missing verdict is visible.
jq -r "$sel | .expectations | to_entries[] | \"\(.key + 1). \(.value)\"" "$CASEFILE" > "$OUT/.expectations"
N_EXPECT=$(wc -l < "$OUT/.expectations" | tr -d ' ')

awk -v frag="$FRAGMENT" -v fix="$FIXTURE_DIR" -v frozen="$HERE/frozen/$FIXTURE" \
    -v section="$SECTION" -v verdict="$VERDICT" -v expected="$EXPECTED" -v expf="$OUT/.expectations" '
  {
    gsub(/\{\{FRAGMENT\}\}/, frag); gsub(/\{\{FIXTURE_DIR\}\}/, fix)
    gsub(/\{\{FROZEN\}\}/, frozen); gsub(/\{\{SECTION\}\}/, section)
    gsub(/\{\{VERDICT_OUT\}\}/, verdict); gsub(/\{\{EXPECTED_OUTPUT\}\}/, expected)
    if ($0 ~ /\{\{EXPECTATIONS\}\}/) { while ((getline line < expf) > 0) print line; next }
    print
  }
' "$HERE/judge-prompt.md" > "$PROMPT"
rm -f "$OUT/.expectations"

PERM=${EVAL_PERMISSION_MODE:-bypassPermissions}
TIMEOUT=
for t in timeout gtimeout; do command -v $t >/dev/null && { TIMEOUT=$t; break; }; done
LIMIT=${EVAL_TIMEOUT:-1800}

rm -f "$VERDICT"
set +e
( cd "$FIXTURE_DIR" && ${TIMEOUT:+$TIMEOUT $LIMIT} claude -p \
    --permission-mode "$PERM" \
    ${MODEL:+--model $MODEL} ${EFFORT:+--effort $EFFORT} \
    --add-dir "$OUT" "$HERE" "$(dirname "$FRAGMENT")" \
    < "$PROMPT" ) > "$LOG" 2>&1
judge_exit=$?
set -e

if [ ! -r "$VERDICT" ]; then
  echo "unusable  the judge wrote no verdicts to $VERDICT (exit $judge_exit; see $LOG)"
  exit 1
fi

# Parsing and tallying live in verdict-tally.sh, so run.sh reads the same file the same way and
# self-test.rb can exercise it without a model.
echo "verdicts: $VERDICT  (judge ${MODEL:--}/${EFFORT:--})"
echo
# The tally goes last, and stays last: run.sh reports each run with tail -1, so anything printed
# after it replaces the number in the log.
"$HERE/verdict-tally.sh" "$VERDICT" --expected "$N_EXPECT"
