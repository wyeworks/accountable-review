#!/bin/sh
# behaviour-flows.sh — section 2, the bulk of the page, and the canonical home for
# everything one behaviour owns.
#
# The failure this section is most prone to is grouping by directory: Services / Models /
# Hooks / Components is the repository's structure, not the change's, and a reviewer who
# reads it still has to assemble the behaviour themselves. That failure is visible in the
# headings, so it is checkable.
#
# Then the SHAPE, which a script can settle outright: a flow body is a .mech block followed
# by one dl.rows carrying the seven fields, and .decisions sits after that dl. That is a
# check rather than a convention because a run flattened all three flows into loose field
# blocks and the page still rendered.
#
# The shape is MORE fragile in this design than in the one before it, not less. The unit used
# to be article.unit — a bordered card, so a flattened flow visibly lost its box. Now the unit
# is borderless by design: a .mech block and a hairline-separated grid. A flow that loses its
# .mech and spills its rows straight into the <section> looks very nearly correct. So the
# pairing is what gets checked, one .mech per dl.rows, and orphaned rows are a FAIL.
#
# One complication that used to live here is gone: .ep-row was SHARED with article.endpoint,
# so the old extractor had to pull endpoint cards alongside units or it reported three correct
# runs as flattened. This design has no endpoint card — an endpoint is covered by the .pipe
# chain inside the flow that owns it — and the field labels are now counted verbatim against
# report-format.md's list, so there is nothing to share and nothing to special-case.
#
# The rest is per-unit. Two guards keep the review unit from becoming ceremony: it needs a
# non-obvious "things to understand", and every claim in it carries a file:line. Both are
# countable. Whether the split is DEFENSIBLE is the insight of the section and needs a
# reader — that is in the case, not here.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_input

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# On a page, narrow to the flow sections. The template gives them id="flow-a" and so on, and the
# narrowing is not tidiness: section 5 legitimately carries subheadings called "Jobs" or "Test
# infrastructure", and the layer-name check below would read those as grouping by directory.
# Section 4 also uses dl.rows, for Changed / Affected-not-changed, and must stay out of the
# unit census. Gate on what the extractor actually matches, not on a looser grep: the template
# mentions id="flow-a" inside a comment, which a loose grep accepts and this awk does not — and
# an empty region then reads as a section with no units in it.
awk '/<section [^>]*id="flow-/{f=1} f{print} /<\/section>/{f=0}' "$IN" > "$TMP/region"
if [ -s "$TMP/region" ]; then
  IN=$TMP/region
  # STAGE 3 JUST OPENED: every flow exists as a stub and none is written yet. The region is not
  # empty — a stub is a <section id="flow-b"> — so the pending branch below cannot fire, and the
  # checks would instead report "no .mech block found" and "no .pipe", which describe a wording
  # problem when the truth is "not written yet".
  #
  # Narrow on purpose, and the pending marker is the precondition rather than a detail: a SKIP
  # reads as verified, so this must be unreachable on a finished page. No .mech AND a pending
  # marker is the only shape that means what it says. One written flow beside a stub falls
  # through to the real checks, which is correct — the stub carries no .mech and no dl.rows, so
  # it adds nothing to either census.
  if ! grep -q 'class="mech"' "$TMP/region" && grep -q 'class="pending"' "$TMP/region"; then
    skip "every flow is still a stub — section 2's shape cannot be checked until one is written"
    finish
    exit
  fi
elif [ "$IN_KIND" = page ]; then
  # A PAGE with no flow sections at all. Falling back to the whole page here is what produced a
  # false positive on a real staged run: section 4 renders Changed / Affected-not-changed with the
  # same dl.rows and legitimately has no .mech, so an un-narrowed census read it as a flattened
  # flow. This is the same shape as the bug where article.cohort satisfied the old unit check —
  # section 1 always supplies one, so the substitute was always there no matter what section 2 did.
  # A fragment still falls through to the whole input, because a fragment need not carry the
  # <section id="flow-a"> wrapper at all.
  if grep -q 'class="pending"' "$IN"; then
    skip "no flow sections yet — section 2 is still pending, so its shape cannot be checked"
  else
    bad "no <section id=\"flow-...\"> on the page — section 2 is the bulk of the report and it is absent"
  fi
  finish
  exit
fi

# The canonical field labels, verbatim from report-format.md § The review unit. Counting these
# rather than every <dt> is what keeps dl.ba's Before/After out of the field census.
FIELD_RE='<dt>[[:space:]]*(Implementation|Tests|Affected, unchanged|Understand|Validate|Questions)[[:space:]]*</dt>'

# Grouping by directory, read off the headings. Layer names alone; "Archiving a project"
# passes, "Models" does not, and "Models and serializers" does not either.
if grep -Eqi '<h[234][^>]*>[[:space:]]*(services?|models?|controllers?|serializers?|hooks?|components?|jobs?|helpers?|queries)([[:space:]]*(and|&amp;|,)[[:space:]]*[a-z]+)?[[:space:]]*<' "$IN"; then
  bad "a flow heading is a layer name: $(grep -Eoi '<h[234][^>]*>[[:space:]]*(services?|models?|controllers?|serializers?|hooks?|components?|jobs?|helpers?|queries)[^<]*' "$IN" | sed 's/.*>//' | sort -u | tr '\n' ' ')— that is the repository's structure, not the change's"
else
  ok "no flow is grouped by directory or layer"
fi

# The grouping principle, stated before the flows. The split is the insight; an unstated
# one leaves the reader to reverse-engineer it.
first_flow=$(grep -n 'class="mech"' "$IN" | head -1 | cut -d: -f1 || true)
if [ -z "${first_flow:-}" ]; then
  maybe "no .mech block found — a flow's body opens with one, so there is nothing for the grouping principle to precede"
# Truncate at the opening tag rather than taking whole lines: generated HTML is not always one
# element per line, and a first flow on line 1 is not the same thing as a missing one.
elif head -n "$first_flow" "$IN" | sed 's/<div class="mech".*//' | grep -q '<p'; then
  ok "prose precedes the first flow, where the grouping principle belongs"
else
  maybe "the first flow opens with no prose before it — say why the split is what it is"
fi

# The path, as a pipeline. A chain the reader can follow beats a paragraph describing one.
# ol.steps is accepted so a page built before .pipe still gets checked rather than warned at.
if grep -Eq 'class="pipe"|class="steps"' "$IN"; then
  ok "at least one flow renders its path as a pipeline"
else
  maybe "no .pipe — the end-to-end path is what makes a flow a flow"
fi

# The flows have to show the change, not only the unchanged code around it. A section whose
# only excerpts are --source has explained everything except the diff, and that is the failure
# this check exists to catch: the budget used to be read as rationing changed-code hunks too.
# WARN and not FAIL, because a fragment can legitimately hold a flow built entirely from
# unchanged code — and because "which flow lacks one" needs a reader, not a grep.
if grep -q 'class="excerpt' "$IN"; then
  if grep -q 'excerpt--diff' "$IN"; then
    ok "the flows quote changed lines, not only unchanged ones"
  else
    maybe "every excerpt here is --source — no flow shows the hunk its behaviour turns on"
  fi
fi

# ---- The shape of a flow ----
#
# One .mech per dl.rows. The mech flag is cleared at each dl.rows, so a second grid riding on
# the first one's mech is reported rather than absorbed.
set -- $(awk '
  /class="mech"/     { mech = 1 }
  /<dl class="rows"/ { rows++; if (!mech) orphan++; mech = 0 }
  END { print rows + 0, orphan + 0 }
' "$IN")
units=$1
orphans=$2

if [ "$units" -gt 0 ] && [ "$orphans" -gt 0 ]; then
  bad "$orphans of $units dl.rows grid(s) have no .mech before them — a flow body is a mechanism statement plus its fields, and rows alone read as a flow whose point was never stated"
elif [ "$units" -gt 0 ]; then
  ok "every dl.rows is introduced by a .mech block"
fi

# TWO extractions, because the two questions below are different and one region cannot
# answer both.
#
# (1) Unit regions, for the per-unit guards and for naming. These start at the .mech, not at
# the grid: the mechanism statement IS the unit's "why this exists" field, so a unit that
# excluded it would be named after whatever <b> came first inside the grid — which is a .gap
# callout's "GAP" often enough to be useless. The region ends at the </dl> that closes its
# OWN grid; a .mech whose grid never opens ends at the next .mech or </section> instead,
# rather than running on and swallowing the next flow's dl.ba.
# The primer callout is dropped before this runs. It sits between the .mech and the grid, so
# it lands inside a unit region, and it carries a class="path" of its own — which would absolve
# a unit whose GRID cites nothing from the citation guard below. Its own citation is checked by
# rails-anchors.sh, where the rule about it belongs.
awk '/<aside class="primer/{p=1} p&&/<\/aside>/{p=0; next} !p' "$IN" > "$TMP/no-primer"
awk -v d="$TMP" '
  /class="mech"/     { u++; f = 1; ingrid = 0 }
  /<dl class="rows"/ { if (f) ingrid = 1 }
  f                  { print > (d "/unit-" u) }
  /<\/dl>/           { if (f && ingrid) { f = 0; ingrid = 0 } }
  /<\/section>/      { f = 0; ingrid = 0 }
' "$TMP/no-primer"

# (2) The grids themselves, for the housing census. This has to be a separate region: a
# flattened flow keeps its .mech, so a census taken over unit regions counts loose fields as
# housed and reports the defect as something else entirely.
awk -v d="$TMP" '
  /<dl class="rows"/ { g++; fg = 1 }
  fg                 { print > (d "/grid-" g) }
  /<\/dl>/           { fg = 0 }
' "$IN"

# Fields outside a dl.rows. Counted, not grepped, because the defect is a RATIO: a page can
# hold one correct unit and still spill fields beside it, which is the half that is hard to
# see by eye.
rows_total=$(grep -cE "$FIELD_RE" "$IN" || true)
rows_housed=0
for f in "$TMP"/grid-*; do
  [ -e "$f" ] || continue
  n=$(grep -cE "$FIELD_RE" "$f" || true)
  rows_housed=$((rows_housed + n))
done
if [ "$rows_total" -gt "$rows_housed" ]; then
  bad "$((rows_total - rows_housed)) of $rows_total field rows are outside a dl.rows — loose field blocks lose the row hairlines, the label gutter and every .rows-scoped rule"
elif [ "$rows_total" -gt 0 ]; then
  ok "every field row is inside a dl.rows"
fi

# Decisions are pinned after the dl. .decision is a card; interleaved with the fields it reads
# as a new section starting mid-flow, and it breaks the grid.
if grep -q 'class="decisions"' "$IN"; then
  if [ "$units" -eq 0 ]; then
    # Do not report a placement as correct when there is no unit to place it against: the flow
    # this landed on had exactly that shape, and a PASS here would have read as absolution.
    skip "cannot check where the decisions block sits — there is no unit for it to sit after"
  elif grep -q 'class="decisions"' "$TMP"/grid-*; then
    bad "a .decisions block sits inside a dl.rows — it belongs after the closing </dl>, where the card has the grid's edge to read against"
  else
    ok "decisions sit outside the unit, where .decision reads correctly"
  fi
fi

# Label drift. WARN, not FAIL: fields may be legitimately omitted, and a wrong label costs the
# reader a moment wondering whether two fields mean the same thing — it is not a false claim.
if [ "$rows_housed" -gt 0 ]; then
  stray=$(grep -ho '<dt>[^<]*' "$TMP"/grid-* | sed 's/.*<dt>//' \
    | grep -vixE 'implementation|tests|affected, unchanged|understand|validate|questions' \
    | sort -u | tr '\n' ' ')
  if [ -n "$stray" ]; then
    maybe "field labels outside the canonical set: ${stray}— report-format.md § The review unit names them verbatim"
  else
    ok "field labels match the canonical set"
  fi
fi

# ---- Per unit, the two guards ----
n=0
for u in "$TMP"/unit-*; do
  [ -e "$u" ] || break
  n=$((n + 1))
  # The unit's name is the .mech statement, which the extraction above puts first in the file.
  label=$(grep -o '<b>[^<]*' "$u" | head -1 | sed 's/.*>//' | cut -c1-48)
  [ -n "$label" ] || label="unit $n"

  if grep -Eqi '<dt>[^<]*understand' "$u"; then
    ok "unit \"$label\" fills things-to-understand"
  else
    bad "unit \"$label\" has no things-to-understand — without one it is a ledger row, not a unit"
  fi

  # .path is the citation form in this design; .cite is still accepted, both for a rung-4 run
  # that renders the citation as plain text and for a page built before .path existed.
  if grep -Eq 'class="cite"|class="path"' "$u"; then
    ok "unit \"$label\" carries citations"
  else
    bad "unit \"$label\" makes claims with no file:line"
  fi

  if grep -Eqi '<dt>[^<]*validat' "$u"; then
    if awk '/<dt>[^<]*[Vv]alidat/,/<\/dd>/' "$u" | grep -q '<code'; then
      ok "unit \"$label\" validation steps are commands"
    else
      maybe "unit \"$label\" has a validation field with no <code> — a step that is not pasteable is not a step"
    fi
  fi
done

if [ "$units" -eq 0 ]; then
  # A flow still carrying a pending marker has no shape to check yet, and saying so out loud is
  # the difference between "not written" and "written wrong" — the two build states this section
  # most needs to keep apart.
  if grep -q 'class="pending"' "$IN"; then
    skip "no dl.rows yet — the flows here are still pending, so their shape cannot be checked"
  else
    bad "no dl.rows — a behaviour flow's body IS a unit, and fields rendered without one lose the grid that aligns them"
  fi
else
  ok "$units review unit(s) inspected"
fi

finish
