#!/bin/sh
# run.sh — produce one section N times and check each one.
#
#   ./run.sh behaviour-flows -n 3
#   ./run.sh behaviour-flows -n 3 --judge --fast
#   ./run.sh behaviour-flows -n 3 --judge -j 3
#   ./run.sh diagrams --fixture monorepo-contract --visual
#   ./run.sh behaviour-flows -n 3 --judge --skill-effort high
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
# A run costs minutes and every second of it is the model: the fixtures rebuild in under a
# second, check.rb in under two tenths, the tally is awk. So there are exactly two ways to
# make the loop faster and this script offers both. --model / --effort (--fast for the pair)
# buy a cheaper reader per run; -j runs the repetitions at once and buys nothing but wall
# clock. The first has a consequence and it is recorded rather than argued about: model and
# effort go on every line beside the sha, and report.sh groups by them, so a fast row can
# never be averaged into a row measured on the shipping model. That grouping is the whole
# safety property — the fast loop tells you which wording to keep, and the last pass before
# believing a number runs on the model the skill actually ships against.
#
# --fast leaves the judge alone on purpose. The judge is the measurement; downgrading the
# measurement to iterate faster on the thing being measured is backwards. --judge-model and
# --judge-effort are there for when you mean it.
#
# --skill-effort is a DIFFERENT KNOB FROM --effort and the long name is the whole reason it is
# spelled out: --effort is the CLI reasoning effort the reader runs at, --skill-effort is the flag
# the skill is invoked with, and at `high` the run sends an adversarial pass at its own behaviour
# flows. Two things called effort in one script is a bug waiting for a hurried reader, so they are
# never abbreviated to the same thing and both go on the results line under their own key.
#
# Needs jq, and a `claude` on PATH. Fragments and logs go under $TMPDIR, never into the repo.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_DIR=$(dirname "$HERE")
PLUGIN_ROOT=$(dirname "$(dirname "$SKILL_DIR")")

CASE=; N=1; ONLY_FIXTURE=; VISUAL=; BASE=HEAD~1; JUDGE=; JOBS=1
LEVEL=; SKILL_EFFORT=
MODEL=${EVAL_MODEL:-}; EFFORT=${EVAL_EFFORT:-}
JUDGE_MODEL=${EVAL_JUDGE_MODEL:-}; JUDGE_EFFORT=${EVAL_JUDGE_EFFORT:-}
while [ $# -gt 0 ]; do
  case $1 in
    -n)             N=$2; shift 2 ;;
    -j|--jobs)      JOBS=$2; shift 2 ;;
    --fixture)      ONLY_FIXTURE=$2; shift 2 ;;
    --level)        LEVEL=$2; shift 2 ;;
    --skill-effort) SKILL_EFFORT=$2; shift 2 ;;
    --base)         BASE=$2; shift 2 ;;
    --model)        MODEL=$2; shift 2 ;;
    --effort)       EFFORT=$2; shift 2 ;;
    --judge-model)  JUDGE_MODEL=$2; shift 2 ;;
    --judge-effort) JUDGE_EFFORT=$2; shift 2 ;;
    # Sugar, and order-independent: an explicit --model or --effort wins wherever it appears.
    --fast)         MODEL=${MODEL:-sonnet}; EFFORT=${EFFORT:-low}; shift ;;
    --visual)       VISUAL=--visual; shift ;;
    --judge)        JUDGE=1; shift ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *)  CASE=$1; shift ;;
  esac
done

if [ -z "$CASE" ]; then
  echo "usage: run.sh <case> [-n N] [-j N] [--fixture NAME] [--base REF] [--level brief|full]" >&2
  echo "                     [--skill-effort high|low] [--visual] [--judge]" >&2
  echo "                     [--fast] [--model M] [--effort L] [--judge-model M] [--judge-effort L]" >&2
  echo "cases:  $(ls "$HERE/cases" | sed 's/\.json$//' | tr '\n' ' ')" >&2
  exit 2
fi
CASEFILE=$HERE/cases/$CASE.json
[ -r "$CASEFILE" ] || { echo "no such case: $CASEFILE" >&2; exit 2; }
command -v jq >/dev/null || { echo "run.sh needs jq to read the case file" >&2; exit 2; }
command -v claude >/dev/null || { echo "run.sh needs claude on PATH" >&2; exit 2; }

DRIVER=$HERE/$(jq -r .produced_by "$CASEFILE")
SCOPE=$(jq -r .scope "$CASEFILE")
# The detail level a case is written for. A case file that declares none means `full`, which is
# what every case written before levels existed meant — and the reason this defaults rather than
# being required is that a silent reinterpretation of the existing corpus would make old result
# lines incomparable with new ones. --level on the command line overrides the case.
[ -n "$LEVEL" ] || LEVEL=$(jq -r '.level // "full"' "$CASEFILE")
case $LEVEL in
  brief|full) ;;
  *) echo "unknown level: $LEVEL (brief | full)" >&2; exit 2 ;;
esac
# The skill effort a case is written for, defaulted for the same reason the level is: every case
# written before the flag existed did what `normal` now names, and reinterpreting the corpus would
# make old result lines incomparable with new ones. --skill-effort on the command line overrides.
# Mirrors the skill's own default. A case that does not declare one measures what a user gets;
# results carry the value and report.sh groups by it, so older rows stay attributable.
[ -n "$SKILL_EFFORT" ] || SKILL_EFFORT=$(jq -r '.skill_effort // "high"' "$CASEFILE")
case $SKILL_EFFORT in
  # `normal` was this value's name while it was the default. Accepted and folded into `low`
  # so an older case file or a shell-history invocation keeps working, and so report.sh groups
  # the two spellings as one thing rather than as two arms of a comparison.
  normal) SKILL_EFFORT=low ;;
  low|high) ;;
  *) echo "unknown skill effort: $SKILL_EFFORT (high | low)" >&2; exit 2 ;;
esac
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

# The falsifier the skill spawns at --skill-effort high. It is registered with --agents rather
# than by loading the plugin, which keeps the property the README defends: the driver names the
# skill files by absolute path, so what is measured is the prose and not the packaging. --agents
# accepts the plugin-scoped identifier verbatim, so the name here is the same one SKILL.md says.
#
# Registered on EVERY run, not only the high ones. An agent nobody spawns costs nothing, and the
# alternative — one arm of the A/B carrying an extra CLI flag — would make the two arms differ by
# something other than the thing under test. Description and tools are read out of the agent file
# so there is one copy of them; a second copy here would drift, which is the failure this
# repository keeps writing down.
AGENT_FILE=$PLUGIN_ROOT/agents/claim-falsifier.md
AGENTS_JSON=
if [ -r "$AGENT_FILE" ]; then
  a_desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); d=$0
                  while ((getline line) > 0 && line ~ /^[[:space:]]/) { sub(/^[[:space:]]+/,"",line); d=d " " line }
                  print d; exit}' "$AGENT_FILE")
  a_tools=$(sed -n 's/^tools:[[:space:]]*//p' "$AGENT_FILE" | head -1)
  a_body=$(awk 'n==2{print} /^---$/{n++}' "$AGENT_FILE")
  AGENTS_JSON=$(jq -n --arg d "$a_desc" --arg p "$a_body" --arg t "$a_tools" \
    '{"accountable-review:claim-falsifier":
        {description:$d, prompt:$p, tools:($t|split(",")|map(gsub("^ +| +$";"")))}}')
else
  echo "warn: $AGENT_FILE not found — --skill-effort high has no falsifier to spawn" >&2
fi

TIMEOUT=
for t in timeout gtimeout; do command -v $t >/dev/null && { TIMEOUT=$t; break; }; done
LIMIT=${EVAL_TIMEOUT:-1800}

# Pinning the session id is the whole reason a finished run can be profiled afterwards: without
# it the transcript is a uuid under a $TMPDIR fixture slug and nothing connects it to a $RUNDIR.
# Probed rather than assumed, so an older CLI records "-" instead of failing every run.
CAN_PIN=; claude --help 2>/dev/null | grep -q -- '--session-id' && CAN_PIN=1
command -v uuidgen >/dev/null 2>&1 || CAN_PIN=

# "-" is what an unset knob records: it means the ambient config decided, which is honest and
# is also why such a row is not comparable to one from another machine or another week.
MODEL_TAG=${MODEL:--}; EFFORT_TAG=${EFFORT:--}
JUDGE_MODEL_TAG=${JUDGE_MODEL:--}; JUDGE_EFFORT_TAG=${JUDGE_EFFORT:--}

# One repetition, start to appended line. A function because -j runs several of these at once,
# and because everything it prints has to name its own run: with jobs in flight, an unlabelled
# tally belongs to nobody.
one_run() {
  rid=$1; rfixture=$2; rnum=$3
  FIXTURE_DIR=$FIXTURES/$rfixture
  stamp=$(date +%Y%m%dT%H%M%S)
  RUNDIR=$RUNS/$CASE/$rfixture/$stamp-$rnum
  mkdir -p "$RUNDIR"
  OUT=$RUNDIR/$CASE.html

  # Generated per repetition, never derived from $stamp-$rnum: -j runs several at once and two
  # fixtures starting inside the same second would collide on an id claude refuses to reuse.
  rsession=-
  if [ -n "$CAN_PIN" ]; then
    rsession=$(uuidgen | tr 'A-Z' 'a-z')
    printf '%s\n' "$rsession" > "$RUNDIR/session"
  fi

  sed -e "s|{{SKILL_DIR}}|$SKILL_DIR|g" \
      -e "s|{{FIXTURE_DIR}}|$FIXTURE_DIR|g" \
      -e "s|{{FROZEN}}|$HERE/frozen/$rfixture|g" \
      -e "s|{{BASE}}|$BASE|g" \
      -e "s|{{LEVEL}}|$LEVEL|g" \
      -e "s|{{SKILL_EFFORT}}|$SKILL_EFFORT|g" \
      -e "s|{{OUT}}|$OUT|g" \
      "$DRIVER" > "$RUNDIR/prompt.md"

  echo "· $rid  run $rnum/$N  $LEVEL  effort=$SKILL_EFFORT  $MODEL_TAG/$EFFORT_TAG  → $RUNDIR"
  started=$(date +%s)
  set +e
  # The prompt goes in on STDIN, not as an argument. --add-dir is variadic, so a trailing
  # positional prompt is swallowed as one more directory and claude exits with "Input must be
  # provided either through stdin or as a prompt argument" — one second, exit 1, no fragment.
  ( cd "$FIXTURE_DIR" && ${TIMEOUT:+$TIMEOUT $LIMIT} claude -p \
      --permission-mode "$PERM" \
      ${MODEL:+--model $MODEL} ${EFFORT:+--effort $EFFORT} \
      ${AGENTS_JSON:+--agents "$AGENTS_JSON"} \
      ${CAN_PIN:+--session-id $rsession} \
      --add-dir "$RUNDIR" "$SKILL_DIR" \
      < "$RUNDIR/prompt.md" ) > "$RUNDIR/agent.log" 2>&1
  agent_exit=$?
  set -e
  seconds=$(( $(date +%s) - started ))

  # Whether a fragment exists is the only trustworthy signal that the run happened: claude -p
  # exits 0 even when it prints nothing but "Execution error", so agent_exit cannot be used to
  # tell a dead run from a bad one — and a dead run averaged in reads as a quality regression.
  if [ -r "$OUT" ]; then
    written=true
    set +e
    # --repo is what lets the checks that need the repository actually run on a fragment:
    # searches.sh re-runs the recorded searches inside it, and page-invariants.sh asks git
    # whether the head is pushed. Without it both skip, and a skip reads as verified.
    ruby "$HERE/check.rb" --fragment "$OUT" --scope "$SCOPE" --repo "$FIXTURE_DIR" --level "$LEVEL" $VISUAL > "$RUNDIR/check.txt" 2>&1
    check_exit=$?
    set -e
  else
    written=false
    echo "FAIL  the driver produced no fragment at $OUT" > "$RUNDIR/check.txt"
    check_exit=1
  fi

  # Profiling is local jq over one file the harness did not write, so it is free and stays
  # unconditional — a knob nobody sets is a knob that rots. It must never fail the run: a
  # transcript that moved is a measurement problem, not a result.
  pmodel=0; ptool=0; pttft=0; pstream=0; pout=0; pthink=0; preq=0
  if [ "$rsession" != "-" ]; then
    set +e
    "$HERE/profile.sh" --rundir "$RUNDIR" --json > "$RUNDIR/profile.json" 2> "$RUNDIR/profile.err"
    pok=$?
    "$HERE/profile.sh" --rundir "$RUNDIR" > "$RUNDIR/profile.txt" 2>&1
    set -e
    if [ "$pok" -eq 0 ] && [ -s "$RUNDIR/profile.json" ]; then
      eval "$(jq -r '"pmodel=\(.model_s) ptool=\(.tool_s) pttft=\(.ttft_s) pstream=\(.stream_s) pout=\(.out_tokens) pthink=\(.think_tokens) preq=\(.requests)"' "$RUNDIR/profile.json")"
    fi
  fi

  p=$(grep -c '^PASS' "$RUNDIR/check.txt" || true)
  f=$(grep -c '^FAIL' "$RUNDIR/check.txt" || true)
  w=$(grep -c '^WARN' "$RUNDIR/check.txt" || true)
  s=$(grep -c '^SKIP' "$RUNDIR/check.txt" || true)

  # The judged half, and only if asked: it costs a second model call per run, and the mechanical
  # half is worth having on its own. It runs after the check and never sees it.
  jp=0; jf=0; ju=0; judged=false
  if [ -n "$JUDGE" ] && [ -r "$OUT" ]; then
    set +e
    "$HERE/judge.sh" --fragment "$OUT" --case "$CASE" --fixture "$rfixture" --out "$RUNDIR" \
      ${JUDGE_MODEL:+--model $JUDGE_MODEL} ${JUDGE_EFFORT:+--effort $JUDGE_EFFORT} \
      > "$RUNDIR/judge.txt" 2>&1
    set -e
    set +e
    counts=$("$HERE/verdict-tally.sh" "$RUNDIR/verdicts.json" --counts)
    tally_ok=$?
    set -e
    if [ "$tally_ok" -eq 0 ]; then
      jp=${counts%% *}; rest=${counts#* }; jf=${rest%% *}; ju=${rest#* }
      judged=true
    fi
  fi

  # judged=false is why the judged counts are a separate flag rather than three zeroes: a run
  # nobody judged and a run that scored zero must not aggregate the same way.
  printf '{"case":"%s","fixture":"%s","run":%d,"ts":"%s","pass":%d,"fail":%d,"warn":%d,"skip":%d,"check_exit":%d,"agent_exit":%d,"seconds":%d,"session":"%s","requests":%d,"model_seconds":%s,"tool_seconds":%s,"ttft_seconds":%s,"stream_seconds":%s,"output_tokens":%d,"thinking_tokens":%d,"fragment_written":%s,"judged":%s,"judge_pass":%d,"judge_fail":%d,"judge_unclear":%d,"level":"%s","skill_effort":"%s","model":"%s","effort":"%s","judge_model":"%s","judge_effort":"%s","skill_sha":"%s","dirty":%s,"driver_sha":"%s","fragment":"%s"}
' \
    "$CASE" "$rfixture" "$rnum" "$stamp" "$p" "$f" "$w" "$s" "$check_exit" "$agent_exit" "$seconds" \
    "$rsession" "$preq" "$pmodel" "$ptool" "$pttft" "$pstream" "$pout" "$pthink" \
    "$written" "$judged" "$jp" "$jf" "$ju" \
    "$LEVEL" "$SKILL_EFFORT" "$MODEL_TAG" "$EFFORT_TAG" "$JUDGE_MODEL_TAG" "$JUDGE_EFFORT_TAG" \
    "$SKILL_SHA" "$DIRTY" "$DRIVER_SHA" "$OUT" >> "$HERE/results/$CASE.jsonl"

  # One printf, so a parallel run's result arrives as one piece instead of interleaved with
  # another's.
  report=$(tail -1 "$RUNDIR/check.txt")
  if [ "$judged" = true ]; then report="$report
  $(tail -1 "$RUNDIR/judge.txt")"; fi
  printf '  %s run %d: %s\n' "$rid" "$rnum" "$report"
  return 0
}

# The case list goes through a file rather than a pipe so the loop runs in this shell: a piped
# `while read` is a subshell, and -j needs to hold job state across iterations.
CASELIST=${TMPDIR:-/tmp}/run-$CASE-$$.tsv
trap 'rm -f "$CASELIST"' EXIT INT TERM
jq -r '.cases[] | [.id, .fixture] | @tsv' "$CASEFILE" > "$CASELIST"

inflight=0
while IFS='	' read -r id fixture; do
  [ -z "$ONLY_FIXTURE" ] || [ "$fixture" = "$ONLY_FIXTURE" ] || continue
  [ -d "$FIXTURES/$fixture" ] || { echo "fixture not built: $FIXTURES/$fixture" >&2; exit 1; }

  i=0
  while [ "$i" -lt "$N" ]; do
    i=$((i + 1))
    if [ "$JOBS" -gt 1 ]; then
      one_run "$id" "$fixture" "$i" &
      inflight=$((inflight + 1))
      # A barrier at every J rather than a proper pool: J is 3, the runs take about the same
      # time, and a scheduler here would be more code than the minutes it saves.
      if [ "$inflight" -ge "$JOBS" ]; then wait || true; inflight=0; fi
    else
      one_run "$id" "$fixture" "$i"
    fi
  done
done < "$CASELIST"
wait || true

echo
echo "results appended to results/$CASE.jsonl — ./report.sh $CASE for the aggregate"
if [ "$MODEL_TAG" != "-" ] || [ "$EFFORT_TAG" != "-" ]; then
  echo "produced on $MODEL_TAG/$EFFORT_TAG — report.sh keeps it in its own group; re-run on the shipping model before believing the number"
fi
if [ -n "$JUDGE" ]; then
  echo "verdicts per run are in verdicts.json beside each fragment; read the fails and the notes"
else
  echo "the judged expectations are in cases/$CASE.json — ./run.sh $CASE --judge grades them too"
fi
