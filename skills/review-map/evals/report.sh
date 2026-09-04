#!/bin/sh
# report.sh — what the runs add up to, per case, per fixture, per skill sha, per detail level,
# per skill effort, per model.
#
#   ./report.sh                  every case
#   ./report.sh behaviour-flows  one
#
# The sha column is the reason this file exists: it makes a pass rate attributable to a
# wording version, which is the thing that could not be done before. A row with dirty=true
# was measured against uncommitted prose and is evidence about a draft, not a version.
#
# The model column is the same argument one level down. Once a section could be produced by a
# cheaper model to make iteration affordable, "3 runs, 2 clean" stopped meaning anything on
# its own — a fail on sonnet/low may be the wording or may be the reader. So model and effort
# are part of the group key and nothing averages across them. A row reading `-/-` was produced
# by whatever the ambient config was that day, which is not a fact about anything.
#
# The detail level is the third axis on the same argument. --brief and --full produce different
# pages from the same case, so a pass rate averaged over both describes neither. Lines written
# before levels existed carry none, and are reported as `full`, which is what they were.
#
# The skill's effort is the fourth, and it is a different thing from the `effort` beside `model`:
# that one is the CLI reasoning effort the reader was run at, this one is the flag the skill was
# invoked with, and at `high` the run sends an adversarial pass at its own flows. Two knobs, two
# columns, and the column here is headed by the value so they cannot be read as one. Lines written
# before the flag existed are reported as `normal`, which is what they were.
#
# Two blocks per group, and they never merge. CHECKS are the mechanical verdicts — a script
# says the same thing every time, so a change in that column is a change in the fragment.
# JUDGED are one model's reading of the written expectations, over however many runs were
# actually judged; unclear is reported rather than folded into either side, because the
# rubric offers it precisely so the judge does not have to guess. The judge's own model is
# named on that line rather than in the key: it does not affect the checks, so splitting the
# whole group by it would claim a dependency that is not there.
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
      # Zero means "this line predates profile.sh", which is why the time block is printed only
      # when a group has a run that actually carries model seconds.
      msecs = 0; tsecs = 0; ftsecs = 0; ssecs = 0; otok = 0; ttok = 0; nreq = 0
      # Lines written before the knobs existed carry no model, and "-" is the same thing they
      # meant: the ambient config decided.
      model = "-"; effort = "-"; jmodel = "-"; jeffort = "-"
      # Lines written before detail levels existed were all produced at what is now `full`.
      level = "full"
      # And before the effort flag existed, every run did what `low` now names — no falsifier.
      seffort = "low"
      if (match($0, /"fixture":"[^"]*"/))     fixture = substr($0, RSTART + 11, RLENGTH - 12)
      if (match($0, /"skill_sha":"[^"]*"/))   sha     = substr($0, RSTART + 13, RLENGTH - 14)
      if (match($0, /"dirty":[a-z]*/))        dirty   = substr($0, RSTART + 8, RLENGTH - 8)
      if (match($0, /"fail":[0-9]+/))         fail    = substr($0, RSTART + 7, RLENGTH - 7) + 0
      if (match($0, /"warn":[0-9]+/))         warn    = substr($0, RSTART + 7, RLENGTH - 7) + 0
      if (match($0, /"seconds":[0-9]+/))      secs    = substr($0, RSTART + 10, RLENGTH - 10) + 0
      # These need [0-9.]+ — profile.sh reports tenths. The leading quote in each pattern is what
      # keeps "seconds" above from matching inside "model_seconds".
      if (match($0, /"model_seconds":[0-9.]+/))  msecs  = substr($0, RSTART + 16, RLENGTH - 16) + 0
      if (match($0, /"tool_seconds":[0-9.]+/))   tsecs  = substr($0, RSTART + 15, RLENGTH - 15) + 0
      if (match($0, /"ttft_seconds":[0-9.]+/))   ftsecs = substr($0, RSTART + 15, RLENGTH - 15) + 0
      if (match($0, /"stream_seconds":[0-9.]+/)) ssecs  = substr($0, RSTART + 17, RLENGTH - 17) + 0
      if (match($0, /"output_tokens":[0-9]+/))   otok   = substr($0, RSTART + 16, RLENGTH - 16) + 0
      if (match($0, /"thinking_tokens":[0-9]+/)) ttok   = substr($0, RSTART + 18, RLENGTH - 18) + 0
      if (match($0, /"requests":[0-9]+/))        nreq   = substr($0, RSTART + 11, RLENGTH - 11) + 0
      if (match($0, /"fragment_written":[a-z]*/)) written = substr($0, RSTART + 19, RLENGTH - 19)
      if (match($0, /"judged":[a-z]*/))       judged  = substr($0, RSTART + 9, RLENGTH - 9)
      if (match($0, /"judge_pass":[0-9]+/))   jp      = substr($0, RSTART + 13, RLENGTH - 13) + 0
      if (match($0, /"judge_fail":[0-9]+/))   jf      = substr($0, RSTART + 13, RLENGTH - 13) + 0
      if (match($0, /"judge_unclear":[0-9]+/)) ju     = substr($0, RSTART + 16, RLENGTH - 16) + 0
      if (match($0, /"model":"[^"]*"/))       model   = substr($0, RSTART + 9, RLENGTH - 10)
      if (match($0, /"effort":"[^"]*"/))      effort  = substr($0, RSTART + 10, RLENGTH - 11)
      if (match($0, /"level":"[^"]*"/))       level   = substr($0, RSTART + 9, RLENGTH - 10)
      # "skill_effort" cannot collide with "effort" above: that pattern needs a quote immediately
      # before `effort`, and here the quote sits before `skill_`.
      if (match($0, /"skill_effort":"[^"]*"/)) seffort = substr($0, RSTART + 16, RLENGTH - 17)
      if (match($0, /"judge_model":"[^"]*"/)) jmodel  = substr($0, RSTART + 15, RLENGTH - 16)
      if (match($0, /"judge_effort":"[^"]*"/)) jeffort = substr($0, RSTART + 16, RLENGTH - 17)

      # The detail level is part of the group key for the same reason model and effort are: a
      # brief run and a full run of the same case are two different pages, and a pass rate
      # averaged over both belongs to neither. Skill effort joins it on the same argument:
      # comparing normal against high is the whole point of the flag, so they must not average.
      k = sha (dirty == "true" ? "+dirty" : "") "\t" fixture "\t" level "\t" "effort=" seffort "\t" model "/" effort
      keys[k] = 1

      # A run whose agent died produced nothing to grade, and averaging it in reads as a quality
      # regression when it is an API error. Counted, named, and kept out of the averages.
      if (written == "false") { errs[k]++; time[k] += secs; next }
      runs[k]++; if (fail == 0) green[k]++; fails[k] += fail; warns[k] += warn; time[k] += secs
      # Same denominator as the checks line: a run with no model seconds has nothing to average.
      if (msecs > 0) {
        pruns[k]++; pmodel[k] += msecs; ptool[k] += tsecs; pttft[k] += ftsecs
        pstream[k] += ssecs; pout[k] += otok; pthink[k] += ttok; preq[k] += nreq
      }
      if (judged == "true") {
        jk = k "\t" jmodel "/" jeffort
        if (!(jk in jseen)) { jseen[jk] = 1; jorder[k] = jorder[k] SUBSEP jk }
        jruns[jk]++; jpass[jk] += jp; jfail[jk] += jf; junc[jk] += ju
        if (jf == 0) jclean[jk]++
      }
    }
    END {
      for (k in keys) {
        n = split(k, part, "\t")
        printf "  %-18s %-20s %-6s %-14s %s\n", part[1], part[2], part[3], part[4], part[5]
        if (runs[k] > 0)
          printf "    checks   %d run(s)  %d clean  %.1f fail/run  %.1f warn/run  %ds avg%s\n",
            runs[k], green[k], fails[k] / runs[k], warns[k] / runs[k],
            time[k] / (runs[k] + errs[k]),
            (errs[k] > 0 ? sprintf("  · %d run(s) died before producing anything", errs[k]) : "")
        else
          printf "    checks   no completed run(s); %d died before producing anything\n", errs[k]
        # A third kind of number, so a third labelled line rather than more columns on the first.
        # It says where the wall clock went; it says nothing about whether the page was right.
        # (No apostrophes in here: the whole awk program is inside single quotes.)
        if (pruns[k] > 0)
          printf "    time     %d run(s)  %.0fs model [ttft %.0fs · stream %.0fs]  %.0fs tool  ·  %.1fk out (%.1fk think) over %.0f requests  per run\n",
            pruns[k], pmodel[k] / pruns[k], pttft[k] / pruns[k], pstream[k] / pruns[k],
            ptool[k] / pruns[k], (pout[k] / pruns[k]) / 1000, (pthink[k] / pruns[k]) / 1000,
            preq[k] / pruns[k]
        # One judged line per judge model seen in this group: two graders are two readings, and
        # a mean over both is a number with no reader behind it.
        if (k in jorder) {
          m = split(jorder[k], jks, SUBSEP)
          for (x = 1; x <= m; x++) {
            jk = jks[x]; if (jk == "") continue
            split(jk, jpart, "\t")   # sha, fixture, level, skill effort, model/effort, judge …
            printf "    judged   %d run(s)  %d clean  %.1f pass  %.1f fail  %.1f unclear  per run  · judge %s\n",
              jruns[jk], jclean[jk], jpass[jk] / jruns[jk], jfail[jk] / jruns[jk], junc[jk] / jruns[jk],
              jpart[6]
          }
        } else
          printf "    judged   none — ./run.sh %s --judge\n", FILENAME
      }
    }
  ' "$f" | sed "s|$HERE/results/||; s|\.jsonl||"
  echo
done
