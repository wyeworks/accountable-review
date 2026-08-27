#!/bin/sh
# behaviour-flows.sh — section 2, the bulk of the page, and the canonical home for
# everything one behaviour owns.
#
# The failure this section is most prone to is grouping by directory: Services / Models /
# Hooks / Components is the repository's structure, not the change's, and a reviewer who
# reads it still has to assemble the behaviour themselves. That failure is visible in the
# headings, so it is checkable.
#
# Then the SHAPE, which a script can settle outright: a flow body is article.unit, its seven
# fields live inside, and .decisions sits after it. That is a check rather than a convention
# because a run flattened all three flows into loose .ep-row blocks and the page still rendered.
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
# Gate on what the extractor actually matches, not on a looser grep: the template mentions
# id="flow-a" inside a comment, which a loose grep accepts and this awk does not — and an empty
# region then reads as a section with no units in it.
awk '/<section [^>]*id="flow-/{f=1} f{print} /<\/section>/{f=0}' "$IN" > "$TMP/region"
if [ -s "$TMP/region" ]; then
  IN=$TMP/region
fi

# Grouping by directory, read off the headings. Layer names alone; "Archiving a project"
# passes, "Models" does not, and "Models and serializers" does not either.
if grep -Eqi '<h[234][^>]*>[[:space:]]*(services?|models?|controllers?|serializers?|hooks?|components?|jobs?|helpers?|queries)([[:space:]]*(and|&amp;|,)[[:space:]]*[a-z]+)?[[:space:]]*<' "$IN"; then
  bad "a flow heading is a layer name: $(grep -Eoi '<h[234][^>]*>[[:space:]]*(services?|models?|controllers?|serializers?|hooks?|components?|jobs?|helpers?|queries)[^<]*' "$IN" | sed 's/.*>//' | sort -u | tr '\n' ' ')— that is the repository's structure, not the change's"
else
  ok "no flow is grouped by directory or layer"
fi

# The grouping principle, stated before the flows. The split is the insight; an unstated
# one leaves the reader to reverse-engineer it.
#
# article.unit only. article.cohort used to satisfy this as well, and that is exactly how a page
# with zero units got through: section 1 always supplies a cohort, so the substitute was always
# present no matter what section 2 did.
first_flow=$(grep -n '<article class="unit' "$IN" | head -1 | cut -d: -f1 || true)
if [ -z "${first_flow:-}" ]; then
  maybe "no article.unit found — a flow's body is one, so there is nothing for the grouping principle to precede"
# Truncate at the opening tag rather than taking whole lines: generated HTML is not always one
# element per line, and a first flow on line 1 is not the same thing as a missing one.
elif head -n "$first_flow" "$IN" | sed 's/<article class="unit.*//' | grep -q '<p'; then
  ok "prose precedes the first flow, where the grouping principle belongs"
else
  maybe "the first flow opens with no prose before it — say why the split is what it is"
fi

# The path, as steps. A chain the reader can follow beats a paragraph describing one.
if grep -q 'class="steps"' "$IN"; then
  ok "at least one flow renders its path as ol.steps"
else
  maybe "no ol.steps — the end-to-end path is what makes a flow a flow"
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
# A flow's body is article.unit, and the seven fields live in its dl.unit-body and nowhere else.
# That is checked rather than trusted because a run flattened all three of its flows into loose
# .ep-row blocks parented straight to the <section>, and nothing broke loudly: the fields still
# rendered, having quietly lost the card, their own spacing and every `.unit ...` rule. The guards
# below it could not see that at all — with no unit to extract, there was nothing to guard.
#
# article.endpoint is extracted alongside, and not because it is a flow body. .ep-row is SHARED:
# the endpoint card's Params / Success / Errors / Side effects rows use the same class, so an
# endpoint card is a second legitimate home for a field row. Counting only units reported three
# correct runs as flattened, which is the false positive this extraction exists to prevent.
awk -v d="$TMP" '
  /<article class="unit/     { u++; fu=1 }
  fu                         { print > (d "/unit-" u) }
  /<article class="endpoint/ { e++; fe=1 }
  fe                         { print > (d "/endpoint-" e) }
  /<\/article>/              { fu=0; fe=0 }
' "$IN"

units=0
for u in "$TMP"/unit-*; do
  [ -e "$u" ] || break
  units=$((units + 1))
done

# Fields outside a component that may hold them. Counted, not grepped, because the defect is a
# RATIO: a page can hold one correct unit and still spill fields beside it, which is the half that
# is hard to see by eye.
rows_total=$(grep -c 'class="ep-row"' "$IN" || true)
rows_in_units=0
rows_housed=0
for f in "$TMP"/unit-* "$TMP"/endpoint-*; do
  [ -e "$f" ] || continue
  n=$(grep -c 'class="ep-row"' "$f" || true)
  rows_housed=$((rows_housed + n))
  case $f in *"/unit-"*) rows_in_units=$((rows_in_units + n)) ;; esac
done
if [ "$rows_total" -gt "$rows_housed" ]; then
  bad "$((rows_total - rows_housed)) of $rows_total field rows are outside article.unit — loose .ep-row blocks lose the card, the unit's own spacing and every .unit-scoped rule"
elif [ "$rows_total" -gt 0 ]; then
  ok "every field row is inside a unit or an endpoint card"
fi

# Decisions are pinned after the unit. .decision has no card of its own — a border-top and a number
# in a 44px gutter — so interleaved with the fields it reads as a new section starting mid-flow.
if grep -q 'class="decisions"' "$IN"; then
  if [ "$units" -eq 0 ]; then
    # Do not report a placement as correct when there is no unit to place it against: the flow
    # this landed on had exactly that shape, and a PASS here would have read as absolution.
    skip "cannot check where the decisions block sits — there is no unit for it to sit after"
  elif grep -q 'class="decisions"' "$TMP"/unit-*; then
    bad "a .decisions block sits inside a unit — it belongs after the closing </article>, where .decision's border-top has the card's edge to read against"
  else
    ok "decisions sit outside the unit, where .decision reads correctly"
  fi
fi

# Label drift. WARN, not FAIL: fields may be legitimately omitted, and a wrong label costs the
# reader a moment wondering whether two fields mean the same thing — it is not a false claim.
if [ "$rows_in_units" -gt 0 ]; then
  stray=$(grep -ho '<dt>[^<]*' "$TMP"/unit-* | sed 's/.*<dt>//' \
    | grep -vixE 'implementation|tests|affected, unchanged|understand|validate|questions' \
    | sort -u | tr '\n' ' ')
  if [ -n "$stray" ]; then
    maybe "field labels outside the canonical set: $stray— report-format.md § The review unit names them verbatim"
  else
    ok "field labels match the canonical set"
  fi
fi

# ---- Per unit, the two guards ----
n=0
for u in "$TMP"/unit-*; do
  [ -e "$u" ] || break
  n=$((n + 1))
  label=$(grep -o '<h3[^>]*>[^<]*' "$u" | head -1 | sed 's/.*>//' | cut -c1-48)
  [ -n "$label" ] || label="unit $n"

  if grep -Eqi '<dt>[^<]*understand' "$u"; then
    ok "unit \"$label\" fills things-to-understand"
  else
    bad "unit \"$label\" has no things-to-understand — without one it is a ledger row, not a unit"
  fi

  if grep -q 'class="cite"' "$u"; then
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
    skip "no article.unit yet — the flows here are still pending, so their shape cannot be checked"
  else
    bad "no article.unit — a behaviour flow's body IS a unit, and fields rendered without one lose the card that boxes them"
  fi
else
  ok "$units review unit(s) inspected"
fi

finish
