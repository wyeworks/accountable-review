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
#
# The region ends at the next <section> — and ALSO at id="crosscutting" or id="approving",
# which at --brief are <h3> sub-parts of this very section rather than sections of their own.
# Without that second bound this check reads the whole merged tail as section 4, and the
# author questions and validation steps under "Before approving" — <li> items that carry
# commands, not citations, and correctly so — are counted as uncited section-4 entries. A real
# --brief page failed exactly that way, on 11 list items that were never section 4's. Both
# anchors are absent at --full, so this stays level-unaware: report-format.md § Section 4 at
# brief makes the merged section keep the anchors precisely so a check can read it unchanged,
# and this is that reading. before-approving.sh remains the only check that takes --level.
strip_comments "$IN" "$TMP/src"
SRC=$TMP/src
if grep -q 'id="blast"' "$SRC"; then
  awk '
    /id="blast"/                            { f = 1 }
    f && /<section /  && !/id="blast"/      { exit }
    f && /id="crosscutting"|id="approving"/ { exit }
    f
  ' "$SRC" > "$TMP/region"
else
  cp "$SRC" "$TMP/region"
fi
REGION=$TMP/region

# One extraction of the section's ENTRIES, shared by the two rules below.
#
# Scoped to the LISTS first. Section 4 holds a good deal that is not an entry — the panel's .bx
# boxes, the .searched blocks, the notes, and, when a page has regressed, an ol.begin reading
# order — and counting any of it is how a correct page gets reported as uncited. dl.rows is the
# current housing for both lists; a region without one is the retired markup, where the whole
# region is the best available scope.
if grep -q 'class="rows"' "$REGION"; then
  awk '/class="rows"/{f=1} f{print} /<\/dl>/{f=0}' "$REGION" > "$TMP/lists"
else
  cp "$REGION" "$TMP/lists"
fi

# An entry is a <div class="item"> — what page-template.html emits today — or an <li> block, the
# shape it emitted before the design system moved section 4 to dl.rows. Both are read, because
# reading only the retired one is how both of these rules came to be dead: they went on passing
# their goldens, which were never migrated, while matching nothing on any page a real run
# produced.
#
# The .item is accumulated to its closing </div> rather than read as one line, even though every
# real page writes it on one. The rule below that catches a pointer which has become a second
# explanation is looking for a LONG entry with several citations, and a long entry is the one a
# run is most likely to wrap — so a first-line-only reader would be blind in exactly the case
# the rule exists for. It was: the migrated golden passed until this accumulated.
#
# Each entry carries the group heading in force when it opened, tab-separated, because the
# heading is context the entry list would otherwise lose.
awk '
  /class="eyebrow"|<h3/ { group = ($0 ~ /Flow [A-Z]/) ? 1 : 0 }
  /class="item"/ && !inli && !initem { initem = 1; ibuf = "" }
  initem { ibuf = ibuf " " $0; if (/<\/div>/) { print group "\t" ibuf; initem = 0 } next }
  /<li/ { inli = 1; buf = "" }
  inli { buf = buf " " $0 }
  inli && /<\/li>/ { print group "\t" buf; inli = 0 }
' "$TMP/lists" > "$TMP/entries"

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
# A citation is a.path today and span.cite in the retired markup; both count, and an entry
# carrying several of either is the defect.
restated=$(awk -F'\t' '{
  group = $1
  buf = substr($0, index($0, "\t") + 1)
  if (buf !~ /href="#flow/ && group != 1) next
  n = 0; rest = buf
  while (match(rest, /class="(cite|path)"/)) { n++; rest = substr(rest, RSTART + RLENGTH) }
  if (n > 1) print n
}' "$TMP/entries" | wc -l | tr -d ' ')
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

# Citations. Every entry in either list needs one; the hard rule is page-wide. Counted over
# the extracted entries, not over the region: grepping the region for class="cite" asked for a
# class section 4's template never emits, so this rule could only ever pass vacuously (li=0 at
# --full) or fire on list items borrowed from another part of a merged page (--brief). It now
# asks the question it always meant to — do the entries carry citations — of the entries.
nent=$(grep -c . "$TMP/entries" 2>/dev/null || true)
cites=$(grep -Ec 'class="(cite|path)"' "$TMP/entries" 2>/dev/null || true)
if [ "${nent:-0}" -gt 0 ] && [ "${cites:-0}" -lt 1 ]; then
  bad "section 4 has $nent entr(ies) and no citation at all"
else
  ok "citations present alongside the lists ($cites of $nent entr(ies))"
fi

finish
