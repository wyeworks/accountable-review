#!/bin/sh
# blast-radius.sh — section 4, the section a diff cannot produce at all.
#
# It runs after the behaviour flows, so it is a second pass rather than a first screen.
# Three of its structural claims are checkable: there is a blast panel, there is an affected
# list beside the changed one, and an empty search is recorded as a search rather than left as
# silence.
#
# The panel is a .blast box grid, not an SVG: solid border changed, dashed unchanged-and-
# affected. It replaced the blast-radius SVG because the information here is membership of two
# sets, which adjacency shows as well as geometry did. What adjacency CANNOT show is a directed
# edge, so the legend and the note carry that — both are checked below.
#
# The reading order used to live here and now lives in section 3, so its absence is checked
# too: an ol.begin inside this region is the old shape, and the old shape puts the route
# through the code before the flows that make it readable.
#
# What needs a reader: whether the affected entries are RIGHT, and whether an entry a flow
# already explained has been reduced to a pointer rather than restated. Presence is cheap;
# correctness is the product.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_input

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
if grep -q 'id="blast"' "$IN"; then
  awk '/id="blast"/{f=1} f&&/<section /&&!/id="blast"/{exit} f{print}' "$IN" > "$TMP/region"
else
  cp "$IN" "$TMP/region"
fi
REGION=$TMP/region

# The panel. Almost every PR earns this one, and it is the only place the page shows
# changed and affected in the same frame. An <svg> is accepted so a page built before the
# box grid still passes.
if grep -Eq '<svg|class="blast"' "$REGION"; then
  ok "blast-radius panel present"
else
  bad "no blast panel in section 4 — the changed/affected split is what a list alone cannot show"
fi

# The legend is not decoration. A dashed box with nothing explaining it reads as "deleted",
# which is the opposite of "unchanged, and therefore worth reading".
if grep -q 'class="blast"' "$REGION"; then
  if grep -q 'class="legend"' "$REGION"; then
    ok "the blast panel carries a legend"
  else
    bad "a .blast panel with no .legend — dashed-means-unchanged has to be stated, or it reads as deleted"
  fi
fi

# Changed beside affected. The second list is the point of the section.
if grep -Eqi 'affected' "$REGION"; then
  ok "an affected-but-unchanged list is present"
else
  bad "no affected-but-unchanged list — section 4 without it is a restatement of the diff"
fi

# The reading order moved to section 3. Finding one here means the fragment was written
# against the old ordering, where section 2 was this section.
if grep -q '<ol class="begin"' "$REGION"; then
  bad "an ol.begin inside section 4 — the reading order lives in section 3 now, after the flows"
else
  ok "no reading order here: it belongs to section 3"
fi

# Pointers into the flows. A consequence a flow owns is named here and explained there, and
# the link is an in-page anchor — the deep-link rung governs file:line citations into a
# remote, not #flow-b. A run at rung 3 emitted this section with no <a> at all.
#
# WARN, not FAIL, and the asymmetry with start-here.sh is deliberate: every section-3 entry
# routes somewhere, but a section 4 whose affected code is genuinely owned by no flow is a
# legitimate page — on a one-flow diff it is the expected one.
if grep -q 'href="#flow' "$REGION"; then
  ok "entries point into the flows that explain them"
else
  maybe "no href=\"#flow\" anywhere — a consequence a flow owns is named here and linked there, and an in-page anchor works at every link rung"
fi

# And a pointer has a SHAPE, because "and nothing more" is not self-enforcing: a run wrote a
# 150-word paragraph carrying eight citations under a "— Flow C" heading and read it as a
# pointer. One clause, ONE citation, a link. A second citation means the mechanism is being
# explained again, here, after the flow already explained it.
#
# FAIL rather than WARN, and the asymmetry with the presence check above is the point: there is
# no reading of a linked entry with four citations that is still a pointer.
# An entry is flow-owned if it links to one, OR if it sits under a group heading naming one —
# the run that prompted this grouped by eyebrow text ("... · Flow C") and linked nothing, so a
# link-only rule would have passed the very fragment the judge failed. A heading like "Reaches
# more than one flow · explained here" is the explained-here group and does not match, which is
# what "Flow" followed by a capital discriminates.
# Either kind of heading resets the state — the two list titles are h3 now, and a group that
# ended at one of them must not leak its Flow into the next block's entries.
restated=$(awk '
  /class="eyebrow"|<h3/ { group = ($0 ~ /Flow [A-Z]/) ? 1 : 0 }
  /<li/ { inli = 1; buf = "" }
  inli  { buf = buf " " $0 }
  inli && /<\/li>/ {
    inli = 0
    if (buf !~ /href="#flow/ && group != 1) next
    n = 0; rest = buf
    while (match(rest, /class="cite"/)) { n++; rest = substr(rest, RSTART + RLENGTH) }
    if (n > 1) print n
  }
' "$REGION" | wc -l | tr -d ' ')
if [ "${restated:-0}" -eq 0 ]; then
  ok "entries that point at a flow carry at most one citation each"
else
  bad "$restated entr(ies) belong to a flow (linked, or under its group heading) and carry more than one citation — a pointer is one clause, one citation and the link; more than that is the flow's explanation written twice"
fi

# Recorded searches. Unrecorded, absence and omission look identical, and the reviewer
# has to redo the work to tell which it was.
if grep -Eq '\brg |\bgrep |\bag |searched' "$REGION"; then
  ok "searches are recorded, so an empty result reads as evidence"
else
  maybe "no search recorded anywhere in section 4 — an unrecorded absence cannot be told from an omission"
fi

# Citations. Every entry in either list needs one; the hard rule is page-wide.
li=$(grep -c '<li' "$REGION" || true)
cites=$(grep -c 'class="cite"' "$REGION" || true)
if [ "${li:-0}" -gt 0 ] && [ "${cites:-0}" -lt 1 ]; then
  bad "section 4 has $li list item(s) and no citation at all"
else
  ok "citations present alongside the lists ($cites)"
fi

finish
