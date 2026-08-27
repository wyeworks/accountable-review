#!/bin/sh
# behaviour-flows.sh — section 2, the bulk of the page, and the canonical home for
# everything one behaviour owns.
#
# The failure this section is most prone to is grouping by directory: Services / Models /
# Hooks / Components is the repository's structure, not the change's, and a reviewer who
# reads it still has to assemble the behaviour themselves. That failure is visible in the
# headings, so it is checkable.
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
first_flow=$(grep -n '<article class="\(unit\|cohort\)' "$IN" | head -1 | cut -d: -f1 || true)
if [ -z "${first_flow:-}" ]; then
  maybe "no article.unit or article.cohort found — section 2 is built from them"
# Truncate at the opening tag rather than taking whole lines: generated HTML is not always one
# element per line, and a first flow on line 1 is not the same thing as a missing one.
elif head -n "$first_flow" "$IN" | sed 's/<article class="\(unit\|cohort\).*//' | grep -q '<p'; then
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

# Per unit, the two guards.
awk -v d="$TMP" '
  /<article class="unit/ { n++; f=1 }
  f { print > (d "/unit-" n) }
  /<\/article>/ { f=0 }
' "$IN"

units=0
for u in "$TMP"/unit-*; do
  [ -e "$u" ] || break
  units=$((units + 1))
  label=$(grep -o '<h3[^>]*>[^<]*' "$u" | head -1 | sed 's/.*>//' | cut -c1-48)
  [ -n "$label" ] || label="unit $units"

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
  maybe "no review units in this input"
else
  ok "$units review unit(s) inspected"
fi

finish
