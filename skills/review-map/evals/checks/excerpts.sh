#!/bin/sh
# excerpts.sh — the mechanical half of the source excerpts.
#
# The half that matters is not here: does the prose still read completely with every
# excerpt CLOSED, judged field by field. That needs a reader and lives in the cases.
# What a script can settle is shape — collapsed by default, a summary that says what is
# inside, tints that exist in all three theme blocks, no range quoted twice, and a
# quotation nobody coloured by hand.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_input

ex=$(grep -o 'class="excerpt' "$IN" | wc -l | tr -d ' ')
if [ "$ex" -eq 0 ]; then
  skip "no excerpts in this input"
  finish
  exit
fi

det=$(grep -o '<details' "$IN" | wc -l | tr -d ' ')
sum=$(grep -o '<summary' "$IN" | wc -l | tr -d ' ')
if [ "$det" -eq "$sum" ]; then
  ok "$ex source excerpt(s), each with a summary"
else
  bad "$det <details> but $sum <summary> — a disclosure with no summary is an unlabelled black box"
fi

# Collapsed by default. An excerpt that ships open is just a code dump, and it is the
# reader who decides when they are ready to check the claim.
if grep -Eq '<details[^>]*[[:space:]]open([[:space:]>]|=)' "$IN"; then
  bad "an excerpt is open by default — excerpts are revealed by the reader, not shipped expanded"
else
  ok "every excerpt is collapsed by default"
fi

# A closed excerpt is the state most readers see, so its summary has to say what is
# inside. "View diff" is not a summary.
if grep -Eiq '<summary>[[:space:]]*(view|show|see) (diff|code|source)' "$IN"; then
  bad "a summary reads 'view diff'/'show code' — say the location and why to open it"
else
  ok "no placeholder summaries"
fi

# The excerpt tints are the newest colours in the system, which makes them the most
# likely to be declared in one theme block and forgotten in the other two.
if [ "$IN_KIND" != page ]; then
  skip "excerpt tints: a fragment carries no token block"
else
  exadd=$(grep -o '\-\-ex-add' "$IN" | wc -l | tr -d ' ')
  if [ "$exadd" -ge 3 ]; then
    ok "excerpt tints defined in all three theme blocks"
  else
    bad "--ex-add appears $exadd time(s), needs 3 — bare :root plus both dark blocks"
  fi
fi

# The tint is applied at read time, so an hljs- class in the markup means someone
# coloured the quotation by hand — which is to say edited it. This is the one defect
# here that changes what the reader believes the file says.
if grep -q 'class="hljs-\|class="l hljs-' "$IN"; then
  bad "hljs- classes are written into the markup — the tint is the page script's job, and a hand-coloured quotation is an edited one"
else
  ok "no hand-written syntax colouring inside a quotation"
fi

# data-lang belongs to --source only. A diff hunk is not one lexical stream, so a
# tinted one is mis-lexed from the first unbalanced quote onward.
if awk '
  /class="excerpt excerpt--diff"/ { in_diff = 1 }
  /<\/details>/                   { in_diff = 0 }
  in_diff && /data-lang=/         { found = 1 }
  END { exit(found ? 0 : 1) }' "$IN"; then
  bad "a --diff excerpt carries data-lang — only unchanged code is tinted, a hunk is two realities interleaved"
else
  ok "data-lang is on unchanged excerpts only"
fi

# The syntax tints, like the add/del tints above: three theme states or none.
if [ "$IN_KIND" != page ]; then
  skip "syntax tints: a fragment carries no token block"
else
  syn=$(grep -o '\-\-syn-key' "$IN" | wc -l | tr -d ' ')
  if [ "$syn" -eq 0 ]; then
    skip "no syntax tokens on this page"
  elif [ "$syn" -ge 3 ]; then
    ok "syntax tints defined in all three theme blocks"
  else
    bad "--syn-key appears $syn time(s), needs 3 — bare :root plus both dark blocks"
  fi
fi

# Exact-duplicate excerpts. The budget forbids quoting the same lines twice — if a
# start-here entry and its cohort field rest on one citation, the excerpt goes in one of
# them. Near-duplicates (structurally identical code a few lines apart) are the more
# common waste and need a reader; this catches only the literal case. Placeholders are
# excluded: an unfilled template legitimately repeats {{PATH}}:{{LINES}}.
dup=$(grep -o 'class="ex-loc">[^<]*' "$IN" | grep -v '{{' | sort | uniq -d | head -3)
if [ -z "$dup" ]; then
  ok "no excerpt quotes the same lines twice"
else
  bad "the same range is excerpted more than once: $(echo "$dup" | sed 's/class="ex-loc">//' | tr '\n' ' ')"
fi

finish
