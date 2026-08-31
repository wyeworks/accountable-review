#!/bin/sh
# profile.sh — where one run's wall clock went.
#
#   ./profile.sh                                  # newest run in this directory's transcript
#   ./profile.sh --session <uuid>                 # the session run.sh pinned
#   ./profile.sh --rundir "$RUNDIR"               # an eval repetition
#   ./profile.sh --transcript <file.jsonl> --all  # any transcript, no attribution filter
#   ./profile.sh --list                           # what transcripts exist, newest first
#
# `seconds` in results/*.jsonl is one number for a whole run, which can say a run got slower but
# never where. This reads the session transcript Claude Code already writes — no instrumentation
# in the skill, and it works on runs that happened before this script existed.
#
# THE REQUEST IS THE UNIT, not the tool call. On the run this was built against the slowest tool
# call was 4.5s (`git fetch`) while the slowest *request* was 264.5s: 35k output tokens streamed
# into one Write of the page. A profile that ranked tool calls would have called the run free.
#
# It splits wall clock four ways, and the split is the finding:
#   tool execution   ts(tool_result) - ts(tool_use block)
#   streaming        per requestId, ts(last block) - ts(first block)
#   before-first-token   ts(first block) - ts(previous event)
#   model            streaming + before-first-token
# On that run: 6% tool, 36% streaming, 58% waiting for a request to start producing, at ~182k
# context per request. So the levers are turn count and context size, not faster scripts.
#
# What it will NOT do is reconstruct the ten steps, because the transcript does not carry a
# position in a procedure. See `bucket()` below and evals/README.md § "Where the time goes".
#
# Needs jq. Reads only; writes nothing outside stdout.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECTS=${CLAUDE_PROJECTS:-$HOME/.claude/projects}
SKILL_ATTR=accountable-review:review-map

TRANSCRIPT=; SESSION=; RUNDIR=; CWD=; WANT_CWD=
LIST=; JSON=; TIMELINE=; ALL=; TOP=10; RUN=; ALL_RUNS=
GAP_MIN=15

usage() {
  # The header block is the help text, so it stops at the first line that is not a comment
  # rather than at a line number that drifts every time the header is edited.
  awk 'NR > 1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
  exit ${1:-0}
}

while [ $# -gt 0 ]; do
  case $1 in
    --transcript|-f) TRANSCRIPT=$2; shift 2 ;;
    --session)       SESSION=$2; shift 2 ;;
    --rundir)        RUNDIR=$2; shift 2 ;;
    --cwd)           WANT_CWD=$2; shift 2 ;;
    --skill)         SKILL_ATTR=$2; shift 2 ;;
    --all)           ALL=1; shift ;;
    --list)          LIST=1; shift ;;
    --json)          JSON=1; shift ;;
    --timeline)      TIMELINE=1; shift ;;
    --top)           TOP=$2; shift 2 ;;
    --run)           RUN=$2; shift 2 ;;
    --all-runs)      ALL_RUNS=1; shift ;;
    --gap)           GAP_MIN=$2; shift 2 ;;
    -h|--help)       usage 0 ;;
    *) echo "profile.sh: unknown argument '$1'" >&2; usage 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "profile.sh: needs jq" >&2; exit 2; }
[ -d "$PROJECTS" ] || { echo "profile.sh: no transcript store at $PROJECTS" >&2; exit 2; }

# ---------------------------------------------------------------- resolving a transcript
# The slug rule (cwd with / turned into -) is not documented anywhere, so it is a first guess
# and a scan of each transcript's own recorded .cwd is the fallback. One `head -1` per file.
slugify() { printf '%s' "$1" | tr '/' '-'; }

newest_for_cwd() {
  _want=$1; _slug=$(slugify "$_want"); _hit=
  if [ -d "$PROJECTS/$_slug" ]; then
    _hit=$(ls -t "$PROJECTS/$_slug"/*.jsonl 2>/dev/null | head -1 || true)
  fi
  if [ -z "$_hit" ]; then
    for _f in $(ls -t "$PROJECTS"/*/*.jsonl 2>/dev/null || true); do
      _c=$(head -1 "$_f" 2>/dev/null | jq -r '.cwd // empty' 2>/dev/null || true)
      [ "$_c" = "$_want" ] || continue
      _hit=$_f; break
    done
  fi
  printf '%s' "$_hit"
}

if [ -n "$RUNDIR" ]; then
  [ -d "$RUNDIR" ] || { echo "profile.sh: no such rundir: $RUNDIR" >&2; exit 2; }
  if [ -r "$RUNDIR/session" ]; then SESSION=$(cat "$RUNDIR/session"); fi
  [ -n "$SESSION" ] || { echo "profile.sh: $RUNDIR records no session id (run.sh too old?)" >&2; exit 2; }
  ALL=1   # eval runs inline the driver, so nothing carries attributionSkill
fi

if [ -n "$SESSION" ] && [ -z "$TRANSCRIPT" ]; then
  TRANSCRIPT=$(ls "$PROJECTS"/*/"$SESSION".jsonl 2>/dev/null | head -1 || true)
  [ -n "$TRANSCRIPT" ] || { echo "profile.sh: no transcript for session $SESSION" >&2; exit 2; }
fi

if [ -n "$LIST" ]; then
  printf '%-8s  %-19s  %s\n' 'RUNS' 'MODIFIED' 'TRANSCRIPT'
  for f in $(ls -t "$PROJECTS"/*/*.jsonl 2>/dev/null || true); do
    n=$(jq -r --arg s "$SKILL_ATTR" 'select(.type=="assistant" and .attributionSkill==$s)|.requestId' "$f" 2>/dev/null | sort -u | wc -l | tr -d ' ')
    [ "${n:-0}" -gt 0 ] || continue
    printf '%-8s  %-19s  %s\n' "$n rq" "$(date -r "$f" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo -)" "$f"
  done
  exit 0
fi

if [ -z "$TRANSCRIPT" ]; then
  CWD=${WANT_CWD:-$PWD}
  TRANSCRIPT=$(newest_for_cwd "$CWD")
  [ -n "$TRANSCRIPT" ] || {
    echo "profile.sh: no transcript found for $CWD" >&2
    echo "  try:  ./profile.sh --list        (what exists)" >&2
    echo "        ./profile.sh --cwd <path>  (another project)" >&2
    exit 2; }
fi
[ -r "$TRANSCRIPT" ] || { echo "profile.sh: cannot read $TRANSCRIPT" >&2; exit 2; }
head -1 "$TRANSCRIPT" | jq -e . >/dev/null 2>&1 || {
  echo "FAIL  $TRANSCRIPT is not line-delimited JSON — the transcript format moved" >&2; exit 1; }

FILTER_SKILL=$SKILL_ATTR
[ -z "$ALL" ] || FILTER_SKILL=

# ---------------------------------------------------------------- the measurement
DATA=$(jq -s \
  --arg skill "$FILTER_SKILL" --arg gap "$GAP_MIN" --arg run "${RUN:-}" \
  --argjson top "$TOP" -f "$HERE/profile.jq" "$TRANSCRIPT") || {
  echo "FAIL  profile.jq failed on $TRANSCRIPT" >&2; exit 1; }

fatal=$(printf '%s' "$DATA" | jq -r '[.diagnostics[]|select(.v=="FAIL")]|length')
if [ "$fatal" -gt 0 ]; then
  printf '%s' "$DATA" | jq -r '.diagnostics[]|select(.v=="FAIL")|"FAIL  \(.m)"' >&2
  echo "" >&2
  echo "No tables printed — a number built on a broken assumption is worse than no number." >&2
  exit 1
fi

if [ -n "$JSON" ]; then
  printf '%s' "$DATA" | jq -c --arg t "$TRANSCRIPT" '. + {transcript:$t} | del(.timeline)'
  exit 0
fi

if [ -n "$ALL_RUNS" ]; then
  printf '%s' "$DATA" | jq -r '.runs[]|"run \(.i)  \(.start)  \(.wall_s)s  \(.requests) rq  \(.out) out tok"'
  exit 0
fi

# ---------------------------------------------------------------- the report
printf '%s' "$DATA" | jq -r --arg t "$TRANSCRIPT" --argjson tl "${TIMELINE:-0}" -f "$HERE/profile-fmt.jq"
