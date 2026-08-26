#!/bin/sh
# run.sh — produce one section N times and check each one.
#
#   ./run.sh behaviour-flows -n 3
#   ./run.sh diagrams --fixture monorepo-contract --visual
#
# The point is repetition. CLAUDE.md already says a single run is weak evidence, because
# defect discovery is sampling rather than a function of the diff — but until now a second
# opinion cost a second whole page. A section is cheap enough to run three times, and three
# runs of one section is the smallest thing that can tell a wording change from noise.
#
# What lands in results/<case>.jsonl is the MECHANICAL tally only, stamped with the skill's
# git sha. The judged expectations in cases/<slug>.json need a reader and stay out of the
# file: a number that silently mixes the two is worse than two numbers.
#
# Needs jq, and a `claude` on PATH. Fragments and logs go under $TMPDIR, never into the repo.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_DIR=$(dirname "$HERE")
PLUGIN_ROOT=$(dirname "$(dirname "$SKILL_DIR")")

CASE=; N=1; ONLY_FIXTURE=; VISUAL=; BASE=HEAD~1
while [ $# -gt 0 ]; do
  case $1 in
    -n)        N=$2; shift 2 ;;
    --fixture) ONLY_FIXTURE=$2; shift 2 ;;
    --base)    BASE=$2; shift 2 ;;
    --visual)  VISUAL=--visual; shift ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *)  CASE=$1; shift ;;
  esac
done

if [ -z "$CASE" ]; then
  echo "usage: run.sh <case> [-n N] [--fixture NAME] [--base REF] [--visual]" >&2
  echo "cases:  $(ls "$HERE/cases" | sed 's/\.json$//' | tr '\n' ' ')" >&2
  exit 2
fi
CASEFILE=$HERE/cases/$CASE.json
[ -r "$CASEFILE" ] || { echo "no such case: $CASEFILE" >&2; exit 2; }
command -v jq >/dev/null || { echo "run.sh needs jq to read the case file" >&2; exit 2; }
command -v claude >/dev/null || { echo "run.sh needs claude on PATH" >&2; exit 2; }

DRIVER=$HERE/$(jq -r .produced_by "$CASEFILE")
SCOPE=$(jq -r .scope "$CASEFILE")
[ -r "$DRIVER" ] || { echo "driver missing: $DRIVER" >&2; exit 2; }

FIXTURES=${REVIEW_MAP_FIXTURES:-${TMPDIR:-/tmp}/review-map-fixtures}
RUNS=${REVIEW_MAP_RUNS:-${TMPDIR:-/tmp}/review-map-runs}
mkdir -p "$HERE/results" "$RUNS"

# Fixtures are deterministic, so rebuilding costs nothing and a stale one is a silent lie
# about what the model was shown.
"$HERE/fixtures/make-fixtures.sh" "$FIXTURES" >/dev/null

# bypassPermissions by default: the fixtures are disposable repositories under $TMPDIR, and
# the alternative is a runner that hangs overnight on a permission prompt nobody is watching.
PERM=${EVAL_PERMISSION_MODE:-bypassPermissions}

SKILL_SHA=$(git -C "$PLUGIN_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
if [ -n "$(git -C "$PLUGIN_ROOT" status --porcelain -- skills 2>/dev/null)" ]; then DIRTY=true; else DIRTY=false; fi
DRIVER_SHA=$(git -C "$PLUGIN_ROOT" hash-object "$DRIVER" 2>/dev/null | cut -c1-8 || echo unknown)

TIMEOUT=
for t in timeout gtimeout; do command -v $t >/dev/null && { TIMEOUT=$t; break; }; done
LIMIT=${EVAL_TIMEOUT:-1800}

total=0; clean=0
jq -r '.cases[] | [.id, .fixture] | @tsv' "$CASEFILE" | while IFS='	' read -r id fixture; do
  [ -z "$ONLY_FIXTURE" ] || [ "$fixture" = "$ONLY_FIXTURE" ] || continue
  FIXTURE_DIR=$FIXTURES/$fixture
  [ -d "$FIXTURE_DIR" ] || { echo "fixture not built: $FIXTURE_DIR" >&2; exit 1; }

  i=0
  while [ "$i" -lt "$N" ]; do
    i=$((i + 1))
    stamp=$(date +%Y%m%dT%H%M%S)
    RUNDIR=$RUNS/$CASE/$fixture/$stamp-$i
    mkdir -p "$RUNDIR"
    OUT=$RUNDIR/$CASE.html

    sed -e "s|{{SKILL_DIR}}|$SKILL_DIR|g" \
        -e "s|{{FIXTURE_DIR}}|$FIXTURE_DIR|g" \
        -e "s|{{FROZEN}}|$HERE/frozen/$fixture|g" \
        -e "s|{{BASE}}|$BASE|g" \
        -e "s|{{OUT}}|$OUT|g" \
        "$DRIVER" > "$RUNDIR/prompt.md"

    echo "· $id  run $i/$N  → $RUNDIR"
    started=$(date +%s)
    set +e
    # The prompt goes in on STDIN, not as an argument. --add-dir is variadic, so a trailing
    # positional prompt is swallowed as one more directory and claude exits with "Input must be
    # provided either through stdin or as a prompt argument" — one second, exit 1, no fragment.
    ( cd "$FIXTURE_DIR" && ${TIMEOUT:+$TIMEOUT $LIMIT} claude -p \
        --permission-mode "$PERM" \
        --add-dir "$RUNDIR" "$SKILL_DIR" \
        < "$RUNDIR/prompt.md" ) > "$RUNDIR/agent.log" 2>&1
    agent_exit=$?
    set -e
    seconds=$(( $(date +%s) - started ))

    if [ -r "$OUT" ]; then
      set +e
      "$HERE/check.sh" --fragment "$OUT" --scope "$SCOPE" $VISUAL > "$RUNDIR/check.txt" 2>&1
      check_exit=$?
      set -e
    else
      echo "FAIL  the driver produced no fragment at $OUT" > "$RUNDIR/check.txt"
      check_exit=1
    fi

    p=$(grep -c '^PASS' "$RUNDIR/check.txt" || true)
    f=$(grep -c '^FAIL' "$RUNDIR/check.txt" || true)
    w=$(grep -c '^WARN' "$RUNDIR/check.txt" || true)
    s=$(grep -c '^SKIP' "$RUNDIR/check.txt" || true)

    printf '{"case":"%s","fixture":"%s","run":%d,"ts":"%s","pass":%d,"fail":%d,"warn":%d,"skip":%d,"check_exit":%d,"agent_exit":%d,"seconds":%d,"skill_sha":"%s","dirty":%s,"driver_sha":"%s","fragment":"%s"}\n' \
      "$CASE" "$fixture" "$i" "$stamp" "$p" "$f" "$w" "$s" "$check_exit" "$agent_exit" "$seconds" \
      "$SKILL_SHA" "$DIRTY" "$DRIVER_SHA" "$OUT" >> "$HERE/results/$CASE.jsonl"

    tail -1 "$RUNDIR/check.txt"
    total=$((total + 1)); [ "$f" -eq 0 ] && clean=$((clean + 1))
  done
done

echo
echo "results appended to results/$CASE.jsonl — ./report.sh $CASE for the aggregate"
echo "the judged expectations are in cases/$CASE.json; read the fragments against them"
