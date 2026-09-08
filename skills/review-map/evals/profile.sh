#!/bin/sh
# profile.sh — where one run's wall clock went, and what it cost.
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
# On that run: 6% tool, 36% streaming, 58% before a request produced its first block. Most of that
# last part is thinking, not prefill — requests over 2000 thinking tokens averaged 56.9s to first
# block, requests under 200 averaged 2.8s. Context barely enters it: at near-zero thinking, 77k of
# context cost 2.3s and 274k cost 3.1s. So ~2.5s per request is FIXED, thinking is the product, and
# the only lever is fewer requests — 95 of them paid ~240s of that fixed cost for nothing.
#
# AND WHERE THE MONEY WENT, which is a different ranking of the same requests. Context is billed
# once per request, so a 141-request run carrying 265k pays that 265k 141 times: cache reads were
# 37.3M against 191k of output on the run above. That is why the sentence directly above — "the
# only lever is fewer requests" — is true of WALL CLOCK and false of cost, where context size is
# the lever precisely because it is re-read. Both tables print; read them side by side, because a
# change can help one and be neutral for the other.
#
# The falsifiers of step 8 are the case in point. They cost 23s of blocked parent (0.9% of a run)
# and 17-23% of all cache reads, measured on three real runs — the first number is why the pass
# looks free and the second is what it actually spends. They live in their own transcripts under
# <session>/subagents/, which nothing here used to read, so the report now charges them to the run.
#
# What it will NOT do is reconstruct the ten steps, because the transcript does not carry a
# position in a procedure. See `bucket()` below and evals/README.md § "Where the time goes".
#
# Two runs in one session are split on a long gap, and the threshold is 45 minutes rather than the
# 15 it started at: a single run was measured holding a 997s (16.6 min) gap while a blocking subagent
# ran, which the smaller threshold reported as two runs — and a consumer reading --json without the
# diagnostics then silently compared one half against a whole baseline.
# Needs jq. Reads only; writes nothing outside stdout.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECTS=${CLAUDE_PROJECTS:-$HOME/.claude/projects}
SKILL_ATTR=accountable-review:review-map

TRANSCRIPT=; SESSION=; RUNDIR=; CWD=; WANT_CWD=
LIST=; JSON=; TIMELINE=; ALL=; TOP=10; RUN=; ALL_RUNS=
GAP_MIN=45

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

# ---- subagent cost, which the parent transcript does not carry ----
# The falsifiers of step 8 read in their own transcripts under <session>/subagents/, and their
# tokens are the run's tokens. A pass measured only by the parent's blocked time reads as free and
# is not: on three real runs the falsifiers were 17-23% of all cache reads. They belong to the
# SESSION rather than to a run, so a multi-run session is told the number covers the session.
SUBDIR="${TRANSCRIPT%.jsonl}/subagents"
SUB=null
if [ -d "$SUBDIR" ] && ls "$SUBDIR"/*.jsonl >/dev/null 2>&1; then
  nag=$(ls "$SUBDIR"/*.jsonl | wc -l | tr -d ' ')
  SUB=$(cat "$SUBDIR"/*.jsonl | jq -s --argjson n "$nag" '
    [ .[] | select(.type == "assistant" and .timestamp and .message.usage) ]
    | group_by(.requestId // .uuid) | map(.[0])
    | ([ .[].message.model ] | map(select(. != null)) | unique | join(",")) as $models
    | map(.message.usage)
    | { agents: $n, requests: length, models: $models,
        cache_read:   ([ .[].cache_read_input_tokens ] | add // 0),
        cache_write:  ([ .[].cache_creation_input_tokens ] | add // 0),
        out_tokens:   ([ .[].output_tokens ] | add // 0),
        think_tokens: ([ .[].output_tokens_details.thinking_tokens // 0 ] | add // 0) }') || SUB=null
fi
DATA=$(printf '%s' "$DATA" | jq --argjson s "$SUB" '. + {subagents: $s}')

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
