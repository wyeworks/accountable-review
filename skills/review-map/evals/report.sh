#!/bin/sh
# report.sh — what the runs add up to, per case, per fixture, per skill sha.
#
#   ./report.sh                  every case
#   ./report.sh behaviour-flows  one
#
# The sha column is the reason this file exists: it makes a pass rate attributable to a
# wording version, which is the thing that could not be done before. A row with dirty=true
# was measured against uncommitted prose and is evidence about a draft, not about a version.
#
# Mechanical only. The judged expectations live in cases/<slug>.json and are settled by a
# reader — this table is the floor, not the score.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WHICH=${1:-}

files=$(ls "$HERE/results"/*.jsonl 2>/dev/null || true)
[ -n "$files" ] || { echo "no results yet — ./run.sh <case> -n 3"; exit 0; }

for f in $files; do
  c=$(basename "$f" .jsonl)
  [ -z "$WHICH" ] || [ "$c" = "$WHICH" ] || continue
  awk -F'[,:]' '
    {
      case_name = ""; fixture = ""; sha = ""; dirty = ""; fail = 0; warn = 0; secs = 0
      if (match($0, /"fixture":"[^"]*"/))   { fixture = substr($0, RSTART + 11, RLENGTH - 12) }
      if (match($0, /"skill_sha":"[^"]*"/)) { sha = substr($0, RSTART + 13, RLENGTH - 14) }
      if (match($0, /"dirty":[a-z]*/))      { dirty = substr($0, RSTART + 8, RLENGTH - 8) }
      if (match($0, /"fail":[0-9]+/))       { fail = substr($0, RSTART + 7, RLENGTH - 7) + 0 }
      if (match($0, /"warn":[0-9]+/))       { warn = substr($0, RSTART + 7, RLENGTH - 7) + 0 }
      if (match($0, /"seconds":[0-9]+/))    { secs = substr($0, RSTART + 10, RLENGTH - 10) + 0 }
      k = sha (dirty == "true" ? "+dirty" : "") "\t" fixture
      runs[k]++; if (fail == 0) green[k]++; fails[k] += fail; warns[k] += warn; time[k] += secs
    }
    END {
      for (k in runs)
        printf "  %-18s %-20s %d run(s)  %d clean  %.1f fail/run  %.1f warn/run  %ds avg\n",
          substr(k, 1, index(k, "\t") - 1), substr(k, index(k, "\t") + 1),
          runs[k], green[k], fails[k] / runs[k], warns[k] / runs[k], time[k] / runs[k]
    }
  ' "$f" | sort > "$HERE/results/.report.tmp"
  echo "$c"
  cat "$HERE/results/.report.tmp"
  rm -f "$HERE/results/.report.tmp"
  echo
done
