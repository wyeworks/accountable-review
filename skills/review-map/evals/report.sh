#!/bin/sh
# report.sh — what the runs add up to, per case, per fixture, per skill sha.
#
#   ./report.sh                  every case
#   ./report.sh behaviour-flows  one
#
# The sha column is the reason this file exists: it makes a pass rate attributable to a
# wording version, which is the thing that could not be done before. A row with dirty=true
# was measured against uncommitted prose and is evidence about a draft, not a version.
#
# Two blocks per group, and they never merge. CHECKS are the mechanical verdicts — a script
# says the same thing every time, so a change in that column is a change in the fragment.
# JUDGED are one model's reading of the written expectations, over however many runs were
# actually judged; unclear is reported rather than folded into either side, because the
# rubric offers it precisely so the judge does not have to guess.
#
# Neither column is page quality. A section eval cannot see whether the page repeats itself.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WHICH=${1:-}

files=$(ls "$HERE/results"/*.jsonl 2>/dev/null || true)
[ -n "$files" ] || { echo "no results yet — ./run.sh <case> -n 3 [--judge]"; exit 0; }

for f in $files; do
  c=$(basename "$f" .jsonl)
  [ -z "$WHICH" ] || [ "$c" = "$WHICH" ] || continue
  echo "$c"
  awk '
    {
      fixture = ""; sha = ""; dirty = ""; fail = 0; warn = 0; secs = 0; written = "true"
      judged = "false"; jp = 0; jf = 0; ju = 0
      if (match($0, /"fixture":"[^"]*"/))     fixture = substr($0, RSTART + 11, RLENGTH - 12)
      if (match($0, /"skill_sha":"[^"]*"/))   sha     = substr($0, RSTART + 13, RLENGTH - 14)
      if (match($0, /"dirty":[a-z]*/))        dirty   = substr($0, RSTART + 8, RLENGTH - 8)
      if (match($0, /"fail":[0-9]+/))         fail    = substr($0, RSTART + 7, RLENGTH - 7) + 0
      if (match($0, /"warn":[0-9]+/))         warn    = substr($0, RSTART + 7, RLENGTH - 7) + 0
      if (match($0, /"seconds":[0-9]+/))      secs    = substr($0, RSTART + 10, RLENGTH - 10) + 0
      if (match($0, /"fragment_written":[a-z]*/)) written = substr($0, RSTART + 19, RLENGTH - 19)
      if (match($0, /"judged":[a-z]*/))       judged  = substr($0, RSTART + 9, RLENGTH - 9)
      if (match($0, /"judge_pass":[0-9]+/))   jp      = substr($0, RSTART + 13, RLENGTH - 13) + 0
      if (match($0, /"judge_fail":[0-9]+/))   jf      = substr($0, RSTART + 13, RLENGTH - 13) + 0
      if (match($0, /"judge_unclear":[0-9]+/)) ju     = substr($0, RSTART + 16, RLENGTH - 16) + 0

      k = sha (dirty == "true" ? "+dirty" : "") "\t" fixture
      keys[k] = 1

      # A run whose agent died produced nothing to grade, and averaging it in reads as a quality
      # regression when it is an API error. Counted, named, and kept out of the averages.
      if (written == "false") { errs[k]++; time[k] += secs; next }
      runs[k]++; if (fail == 0) green[k]++; fails[k] += fail; warns[k] += warn; time[k] += secs
      if (judged == "true") { jruns[k]++; jpass[k] += jp; jfail[k] += jf; junc[k] += ju
                              if (jf == 0) jclean[k]++ }
    }
    END {
      for (k in keys) {
        sha = substr(k, 1, index(k, "\t") - 1); fx = substr(k, index(k, "\t") + 1)
        printf "  %-18s %-20s\n", sha, fx
        if (runs[k] > 0)
          printf "    checks   %d run(s)  %d clean  %.1f fail/run  %.1f warn/run  %ds avg%s\n",
            runs[k], green[k], fails[k] / runs[k], warns[k] / runs[k],
            time[k] / (runs[k] + errs[k]),
            (errs[k] > 0 ? sprintf("  · %d run(s) died before producing anything", errs[k]) : "")
        else
          printf "    checks   no completed run(s); %d died before producing anything\n", errs[k]
        if (jruns[k] > 0)
          printf "    judged   %d run(s)  %d clean  %.1f pass  %.1f fail  %.1f unclear  per run\n",
            jruns[k], jclean[k], jpass[k] / jruns[k], jfail[k] / jruns[k], junc[k] / jruns[k]
        else
          printf "    judged   none — ./run.sh %s --judge\n", FILENAME
      }
    }
  ' "$f" | sed "s|$HERE/results/||; s|\.jsonl||"
  echo
done
