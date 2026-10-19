#!/bin/sh
# usage.sh — what a review-map run spent, read off the host's own session log, for a host with no
# status line the plugin can draw on. Today that host is Codex; Claude Code's status line
# (hooks/progress.ts) counts the same thing live, so a Claude run never calls this.
#
#   Usage: usage.sh mark <W>      at step 1, once $W exists: record where the session stands
#          usage.sh report <W>    at step 10, after the gate: one line saying what the run spent
#
# Prints one line in the idiom of every script here — USAGE or SKIP — and exits 0 either way, 2 on
# a usage error: a count that could not be read is never a reason to stop a run. Shell, sed and awk,
# nothing else, because it runs on the user's machine like page-lint.sh. Nothing it prints goes on
# the page: what the run cost is a fact about the run, said in chat, and the page carries no
# account of how it was produced.
#
# WHAT IT READS. Codex puts CODEX_THREAD_ID in every shell command's environment and writes the
# thread's rollout to $CODEX_HOME/sessions/YYYY/MM/DD/rollout-<time>-<thread>.jsonl. Every
# `token_count` event in it carries the thread's running `total_token_usage` and, when the backend
# sent one, a `rate_limits` snapshot whose `primary` and `secondary` windows each have
# `used_percent`, `window_minutes` and `resets_at`. `mark` writes the running totals and windows to
# $W/usage.start; `report` subtracts them from the latest, so tokens spent before the run are not
# its own. A falsifier is a subagent thread with a rollout of its own whose session meta names this
# thread as its parent: every such rollout begun after the mark is the run's, whole. One that already
# existed at the mark is an earlier task's, even while it keeps writing, so `mark` lists them and
# `report` leaves them out. A thread reverted since the mark has a new rollout whose totals start
# over, so the mark names its rollout and `report` refuses a different one rather than subtract
# across the two.
#
# WHAT IT DOES NOT CLAIM. The window percentages are the account's, so anything else the account
# runs meanwhile moves them too, and the line says account-wide. A window that reset between the
# two readings has no readable share, so it is reported where it stands rather than as a delta.
# The answer after the report is not in the count, since it has not been written yet.

set -eu

say() { echo "$*"; exit 0; }

[ $# -eq 2 ] || { echo "usage: usage.sh mark|report <W>" >&2; exit 2; }
mode=$1 W=$2
case $mode in mark|report) ;; *) echo "usage.sh: unknown mode: $mode (mark | report)" >&2; exit 2 ;; esac
[ -d "$W" ] || { echo "usage.sh: no such directory: $W" >&2; exit 2; }

tid=${CODEX_THREAD_ID:-}
[ -n "$tid" ] || say "SKIP usage: not a Codex session (no CODEX_THREAD_ID), and Claude Code's status line counts its own"
sessions=${CODEX_HOME:-$HOME/.codex}/sessions
[ -d "$sessions" ] || say "SKIP usage: no Codex session logs under $sessions"

# The thread's own rollout: a revert writes rollout-<time>-<thread>_<id>.jsonl, so the newest wins.
rollout=$(find "$sessions" -type f -name "rollout-*-$tid*.jsonl" 2>/dev/null | {
  best=; while read -r f; do [ -z "$best" ] || [ "$f" -nt "$best" ] && best=$f; done; printf '%s' "$best"; })
[ -n "$rollout" ] || say "SKIP usage: no Codex session log for thread $tid"

# The last token_count line with totals, and the last with a rate-limit snapshot — the Codex quota
# when the backend names one, since a snapshot per model quota can interleave with it.
totals_of() {
  grep '"type":"token_count"' "$1" 2>/dev/null | grep '"total_token_usage":{' | tail -1 |
    sed 's/.*"total_token_usage":{\([^}]*\)}.*/\1/'
}
limits_of() {
  lines=$(grep '"type":"token_count"' "$1" 2>/dev/null | grep '"rate_limits":{' || true)
  codex=$(printf '%s\n' "$lines" | grep '"limit_id":"codex"' || true)
  [ -n "$codex" ] && lines=$codex
  printf '%s\n' "$lines" | tail -1
}
field() { printf '%s' "$1" | sed -n "s/.*\"$2\":\(-\{0,1\}[0-9.]*\).*/\1/p" | head -1; }
window() { printf '%s' "$1" | sed -n "s/.*\"$2\":{\([^}]*\)}.*/\1/p" | head -1; }

snapshot() { # prints key=value lines for one rollout's latest reading
  t=$(totals_of "$1")
  echo "in=$(field "$t" input_tokens)"
  echo "cached=$(field "$t" cached_input_tokens)"
  echo "out=$(field "$t" output_tokens)"
  l=$(limits_of "$1")
  for w in primary secondary; do
    o=$(window "$l" "$w")
    echo "${w}_used=$(field "$o" used_percent)"
    echo "${w}_minutes=$(field "$o" window_minutes)"
    echo "${w}_reset=$(field "$o" resets_at)"
  done
}

# Every rollout whose session meta names this thread as its parent.
children_of() {
  find "$sessions" -type f -name 'rollout-*.jsonl' 2>/dev/null | while read -r f; do
    [ "$f" = "$rollout" ] && continue
    if head -n 1 "$f" | grep -q "\"parent_thread_id\":\"$tid\""; then printf '%s\n' "$f"; fi
  done
}

if [ "$mode" = mark ]; then
  { echo "tid=$tid"; echo "rollout=$rollout"; snapshot "$rollout"; } >"$W/usage.start"
  children_of >"$W/usage.before"
  say "USAGE marked: thread $tid"
fi

[ -f "$W/usage.start" ] || say "SKIP usage: no mark at $W/usage.start (step 1 records one)"
start=$W/usage.start
start_tid=$(sed -n 's/^tid=//p' "$start")
[ "$start_tid" = "$tid" ] || say "SKIP usage: the mark is thread $start_tid's, this is $tid"
[ "$(sed -n 's/^rollout=//p' "$start")" = "$rollout" ] ||
  say "SKIP usage: the thread was reverted since the mark, and its new log counts from zero"
now=$W/usage.now
snapshot "$rollout" >"$now"

# Falsifiers: this thread's subagents, less the ones that already existed at the mark.
children=$W/usage.children
: >"$children"
touch "$W/usage.before"
children_of | while read -r f; do
  grep -qxF "$f" "$W/usage.before" && continue
  t=$(totals_of "$f")
  echo "$(field "$t" input_tokens) $(field "$t" cached_input_tokens) $(field "$t" output_tokens)" >>"$children"
done

awk -v startf="$start" -v nowf="$now" -v kidsf="$children" '
  function load(file, into,   line, k) {
    while ((getline line < file) > 0) { k = index(line, "="); into[substr(line, 1, k - 1)] = substr(line, k + 1) }
    close(file)
  }
  function tok(n) {
    if (n >= 9995000) return sprintf("%.1fM", n / 1e6)
    if (n >= 999500) return sprintf("%.2fM", n / 1e6)
    if (n >= 999.5) return sprintf("%dk", int(n / 1e3 + 0.5))
    return sprintf("%d", n)
  }
  function pct(p) { p = sprintf("%.1f", p); sub(/\.0$/, "", p); return p "%" }
  function name(m) {
    if (m == "") return "rate-limit"
    if (m % 1440 == 0) return (m / 1440) "-day"
    if (m % 60 == 0) return (m / 60) "-hour"
    return m "-minute"
  }
  BEGIN {
    load(startf, a); load(nowf, b)
    inp = b["in"] - a["in"]; cached = b["cached"] - a["cached"]; out = b["out"] - a["out"]
    if (inp < 0 || out < 0) { print "SKIP usage: the session log went backwards since the mark"; exit }
    kin = 0; kcached = 0; kout = 0
    while ((getline line < kidsf) > 0) { split(line, f, " "); kin += f[1]; kcached += f[2]; kout += f[3] }
    inp += kin; cached += kcached; out += kout
    s = sprintf("USAGE review map used %s tokens (%s input, %s of it cached · %s output",
      tok(inp + out), tok(inp), tok(cached), tok(out))
    s = s ((kin + kout) > 0 ? sprintf("; falsifiers %s of it)", tok(kin + kout)) : ")")
    split("primary secondary", ws, " "); n = 0
    for (i = 1; i <= 2; i++) {
      w = ws[i]; used = b[w "_used"]
      if (used == "") continue
      label = name(b[w "_minutes"]) " window"
      if (a[w "_used"] != "" && a[w "_reset"] == b[w "_reset"] && a[w "_minutes"] == b[w "_minutes"]) {
        d = used - a[w "_used"]; if (d < 0) d = 0
        part = sprintf("%s %s → %s (+%s)", label, pct(a[w "_used"]), pct(used), pct(d))
      } else {
        part = sprintf("%s at %s", label, pct(used))
      }
      parts = parts (n++ ? ", " : "") part
    }
    if (n) s = s " — " parts ", account-wide"
    print s
  }'
