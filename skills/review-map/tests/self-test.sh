#!/bin/sh
# self-test.sh — breaks things run.sh claims to check, and asserts it notices each one.
#
#   Usage: tests/self-test.sh
#
# Same argument as evals/checks/self-test.rb and setup-ci/tests/self-test.sh: a check that passes
# because it never looked is worse than no check, and the only way to tell the two apart is to
# introduce the defect and watch the suite go red.
#
# Two kinds of mutation, and the split matters. Mutating the TEMPLATE proves the assertions about
# what each half must contain. Mutating the SCRIPT is what proves the partition assertion, because
# a template mutation alone cannot: the script extracts from the same file the test compares
# against, so both sides move together and the suite would stay green. That is the oracle problem
# in the one place it could still hide, so the first two cases here are script mutations.
#
# Nothing here touches the real template or the real script — every case works on a copy under a
# temp directory, pointed at with --template / REVIEW_MAP_SKELETON.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_DIR=$(dirname "$HERE")
RUN=$HERE/run.sh
TEMPLATE=$SKILL_DIR/references/page-template.html
SKELETON=$SKILL_DIR/scripts/page-skeleton.sh
DIFF_RENDER=$SKILL_DIR/scripts/diff-render.sh

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT HUP TERM

ok=0; bad=0

# case <what> <template> <script>
case_runs_red() {
  what=$1; tpl=$2; scr=$3
  if REVIEW_MAP_TEMPLATE="$tpl" REVIEW_MAP_SKELETON="$scr" "$RUN" >/dev/null 2>&1; then
    bad=$((bad + 1)); echo "BAD   run.sh stayed green when: $what"
  else
    ok=$((ok + 1));  echo "ok    run.sh fails when: $what"
  fi
}

# The same, for the other script under test. Its rows are all script mutations: there is no
# fixture to break, because the repository the rows run against is built by run.sh itself.
case_render_red() {
  what=$1; scr=$2
  chmod 755 "$scr"
  if REVIEW_MAP_DIFF_RENDER="$scr" "$RUN" >/dev/null 2>&1; then
    bad=$((bad + 1)); echo "BAD   run.sh stayed green when: $what"
  else
    ok=$((ok + 1));  echo "ok    run.sh fails when: $what"
  fi
}

# A sanity row first. If the unmutated pair does not pass, every row below is meaningless.
if REVIEW_MAP_TEMPLATE="$TEMPLATE" REVIEW_MAP_SKELETON="$SKELETON" "$RUN" >/dev/null 2>&1; then
  ok=$((ok + 1)); echo "ok    run.sh passes on the real template and the real script"
else
  bad=$((bad + 1)); echo "BAD   run.sh FAILS unmutated — fix that before reading anything below"
fi

# ---- script mutations: the partition assertion, which no template mutation can exercise ----

# 1. The regression this whole design exists to prevent: someone decides it is simpler to hold the
#    style block in the script than to extract it, and the two copies drift from that day on.
sed 's|^extract "\$HEAD_S" "\$HEAD_E" "\$TEMPLATE" | { echo "<style>.injected{color:red}</style>"; extract "$HEAD_S" "$HEAD_E" "$TEMPLATE"; } |' \
  "$SKELETON" > "$WORK/inline-css.sh"
chmod 755 "$WORK/inline-css.sh"
case_runs_red "the script emits a line of its own instead of only the template's bytes" "$TEMPLATE" "$WORK/inline-css.sh"

# 2. Without the placeholder there is nothing for stage 1 to Edit, and nothing for the clobber
#    refusal to key on — so a re-invocation would silently wipe a published page.
sed 's|^printf .%s\\n. "\$PLACEHOLDER" >> "\$tmp"$|true|' "$SKELETON" > "$WORK/no-body.sh"
chmod 755 "$WORK/no-body.sh"
case_runs_red "the script writes no body placeholder for the run to replace" "$TEMPLATE" "$WORK/no-body.sh"

# ---- template mutations: what each half must contain ----

# 3. A duplicated marker makes the awk range wrong while every other assertion still passes.
awk '/SKELETON:HEAD:END/ { print; print } !/SKELETON:HEAD:END/ { print }' "$TEMPLATE" > "$WORK/dup-marker.html"
case_runs_red "a marker appears twice in the template" "$WORK/dup-marker.html" "$SKELETON"

# 4. The boundary slipping into the token block: the markup half would then carry colours for a
#    model to copy, which is the defect the split exists to make unreachable.
awk '/SKELETON:HEAD:END/ { next } /^<style>$/ && !d { print "<!-- SKELETON:HEAD:END -->"; d = 1 } { print }' \
  "$TEMPLATE" > "$WORK/early-end.html"
case_runs_red "HEAD:END sits above the token block, leaving every colour in the markup half" "$WORK/early-end.html" "$SKELETON"

# 5. A grammar dropped from the tail tints nothing, silently, and the page still reads in one ink.
grep -v 'languages/elixir.min.js' "$TEMPLATE" > "$WORK/no-elixir.html"
case_runs_red "the Elixir grammar is dropped from the skeleton's scripts" "$WORK/no-elixir.html" "$SKELETON"

# 6. Half-declaring a colour is invisible until someone opens an excerpt with the OS in dark mode.
awk '/--syn-key:/ && !d { d = 1; next } { print }' "$TEMPLATE" > "$WORK/half-syn.html"
case_runs_red "--syn-key is declared in only two of the three theme states" "$WORK/half-syn.html" "$SKELETON"

# 7. The title placeholder gone means every page ships with the same tab name.
sed 's|{{PR_TITLE_OR_BRANCH}} Review|Review|' "$TEMPLATE" > "$WORK/no-title.html"
case_runs_red "the title placeholder is missing, so no page can be named" "$WORK/no-title.html" "$SKELETON"

# ---- the page's one shape ----
#
# Every case below leaves a page that still renders and still looks finished, which is the whole
# reason each needs a rule of its own rather than a reading of the template.

# 8. The figure a run is least likely to type back in if it is not shown assembled. An <svg> was
#    the most expensive thing on the old page to write, and the characteristic failure was never a
#    wrong drawing but no drawing; a chain costs nothing to copy and everything to re-derive.
awk '/<figure class="chain">/ { f = 1 } f && /<\/figure>/ { f = 0; next } !f { print }' \
  "$TEMPLATE" > "$WORK/no-chain.html"
case_runs_red "the assembled chain is gone, so a checkpoint has no figure to copy" "$WORK/no-chain.html" "$SKELETON"

# 9. The rule that replaced the diagram catalogue: this page draws nothing. An <svg> in the half a
#    run reads is one it will copy, and a drawing derived per run spends the run's attention on
#    geometry instead of on whether the edges are true.
awk '/<section class="cp" id="cp-b">/ && !d { print; print "        <svg viewBox=\"0 0 10 10\"></svg>"; d = 1; next } { print }' \
  "$TEMPLATE" > "$WORK/svg-back.html"
case_runs_red "an svg is back in the markup half" "$WORK/svg-back.html" "$SKELETON"

# 10. The rule that keeps the two chain figures apart. An .ip-aff node inside a checkpoint's chain
#     is a hop into unchanged code drawn in the wrong section — the same consequence drawn twice,
#     once here and once in the impact panel, which reads as thoroughness.
sed 's|class="ip-n ip-step"|class="ip-n ip-aff"|' "$TEMPLATE" > "$WORK/chain-aff.html"
case_runs_red "a chain inside a checkpoint carries an affected-unchanged node" "$WORK/chain-aff.html" "$SKELETON"

# 11. The carrier the coverage gate reads. With it gone the page can still be written, still looks
#     complete, and may have dropped a file with nothing saying so.
grep -v 'class="gt gt-paths"' "$TEMPLATE" > "$WORK/no-carrier.html"
case_runs_red "the evidence foot loses its data-path carrier" "$WORK/no-carrier.html" "$SKELETON"

# 12. The rail is assembled rather than derived, and an entry that should not be there is the
#     shape the old seven-entry rail left behind: a run copying a rail with a section the page
#     does not have publishes a link to an anchor that is not on the page.
awk '/<a data-rail="impact"/ && !d { print; print; d = 1; next } { print }' "$TEMPLATE" > "$WORK/extra-rail.html"
case_runs_red "the rail carries an entry the page has no section for" "$WORK/extra-rail.html" "$SKELETON"

# 13. Where to look is what makes a checkpoint actionable; without it the question is an essay.
awk '/<ul class="lookat">/ { f = 1 } f && /<\/ul>/ { f = 0; next } !f { print }' \
  "$TEMPLATE" > "$WORK/no-lookat.html"
case_runs_red "a checkpoint is assembled with no where-to-look list" "$WORK/no-lookat.html" "$SKELETON"

# 14. A card with no paragraph opens on geometry: the header names a behaviour, the next thing is
#     a chain, and the reader traces four nodes to find out whether it was worth tracing. One of
#     the two, not both, because the assertion is a count and a template losing both would fail a
#     rule that merely checked for presence.
awk '/<p class="ip-why">/ && !d { d = 1; next } { print }' "$TEMPLATE" > "$WORK/no-why.html"
case_runs_red "an impact card is assembled with no paragraph above its chain" "$WORK/no-why.html" "$SKELETON"

# 15. The paragraph belongs to the panel and not to a checkpoint's chain, whose own two to four
#     sentences already are it. A template carrying one in both places teaches a run to write the
#     explanation twice at conversational distance, which is what the agenda exists to end.
awk '/<figure class="chain">/ { print; print "          <p class=\"ip-why\">a second explanation</p>"; next } { print }' \
  "$TEMPLATE" > "$WORK/chain-why.html"
case_runs_red "a checkpoint chain is given a paragraph of its own" "$WORK/chain-why.html" "$SKELETON"

# 16. The locators. A template with none teaches a run to publish a figure of identifiers with no
#     way to open any of them, which is the defect the component was added for and the one a
#     reader feels rather than sees.
sed 's|class="path ip-loc"|class="path"|g' "$TEMPLATE" > "$WORK/no-loc.html"
case_runs_red "the nodes lose the locator class the page links them by" "$WORK/no-loc.html" "$SKELETON"

# 17. And a locator on the outcome, which is the version of this defect that looks MORE thorough
#     than the correct markup: it draws, it links somewhere real, and it puts an address on the
#     one node that is a behaviour rather than a file.
awk '/<li class="ip-n ip-out">/ && !d { d = 1; sub(/<\/span><\/li>/, "<a class=\"path ip-loc\" href=\"#\">app/x.rb:1</a></span></li>"); print; next } { print }' \
  "$TEMPLATE" > "$WORK/out-loc.html"
case_runs_red "an outcome node is given a locator" "$WORK/out-loc.html" "$SKELETON"

# 18. data-path is reserved to the inventory: coverage-gate.sh greps it page-wide and compares
#     against git diff --name-only, so a locator carrying one registers as a surplus path and
#     fails the page's one mechanical gate.
sed 's|class="path ip-loc" href="{{BLOB}}#L{{START}}"|class="path ip-loc" data-path="x" href="{{BLOB}}#L{{START}}"|' \
  "$TEMPLATE" > "$WORK/loc-datapath.html"
case_runs_red "a locator carries the inventory's data-path attribute" "$WORK/loc-datapath.html" "$SKELETON"

# 19. The chip that lost its indent reset. The page still renders, the box still lands in the
#     right place, and only the word inside it moves — 24px left of its own border, over the
#     entry's title. The most visible defect this suite has ever had to be taught to see, and the
#     one a run cannot be blamed for, since the chip's markup is correct at every published page.
sed 's|vertical-align: 1px; text-indent: 0;|vertical-align: 1px;|' "$TEMPLATE" > "$WORK/pending-indent.html"
case_runs_red "the pending chip stops resetting the rail entry's hanging indent" "$WORK/pending-indent.html" "$SKELETON"

# 20. The same family as 19, and it was found the same way — on a published page. .begin li is a
#     three-column grid and a stop's excerpt is its fourth child, so with no span it auto-places
#     into the 26px number column, where .ex-loc's overflow-wrap: anywhere renders the path one
#     character per line down hundreds of pixels. Every other assertion still passes: the markup
#     is correct, the excerpt is generated, the tag is right, and only the layout is unreadable.
sed '/^\.begin li > \.excerpt {/d' "$TEMPLATE" > "$WORK/stop-excerpt-css.html"
case_runs_red "a reading-path stop's excerpt loses the rule that spans it out of the number column" "$WORK/stop-excerpt-css.html" "$SKELETON"

# 21. The other half. report-format.md permits an excerpt on a § 03 stop, and the template not
#     showing one assembled is what left the only sanctioned location with no worked example —
#     so a run composed it by analogy with .lookat, where the li is not a grid. The reference
#     permitting what the template never shows is the shape to catch, not the CSS alone.
awk '/<ol class="begin">/ { b = 1 }
     b && /<details class="excerpt/ { f = 1 }
     f { if ($0 ~ /<\/details>/) f = 0; next }
     /<\/ol>/ { b = 0 }
     { print }' "$TEMPLATE" > "$WORK/no-stop-excerpt.html"
case_runs_red "no reading-path stop is assembled carrying an excerpt" "$WORK/no-stop-excerpt.html" "$SKELETON"

# 22. The half of that rule that is not about the number column, and the one the fix for 20 was
#     first written without. A grid item's automatic minimum is its min-content width, and the
#     excerpt's is its pre's longest line, so the span alone widens the whole column past the
#     viewport: measured at a 500px viewport, the document scrolled to 623. .ex-body's own
#     overflow-x cannot contain what the grid has already grown for. .lookat > li carries the
#     same min-width: 0 for the same reason, which is why the .lookat excerpts never showed it.
sed 's|grid-column: 2 / -1; min-width: 0;|grid-column: 2 / -1;|' "$TEMPLATE" > "$WORK/stop-excerpt-minw.html"
case_runs_red "a stop's excerpt cannot shrink below its pre, so the page scrolls sideways" "$WORK/stop-excerpt-minw.html" "$SKELETON"

# ---- diff-render.sh: every mutation here publishes a link that lands on nothing ----
#
# All three are script mutations for the reason the first two cases above are: the repository
# these rows run against is built by run.sh, so there is no fixture to break — and each of them
# leaves a page that looks completely correct, with an anchor that arrives at a "Load diff" stub
# and a reader who cannot tell.

# 8. The signal no size rule can replace. One changed line in a linguist-generated file is a
#    small diff by every measurement there is, and GitHub collapses it anyway.
sed 's|^  if _why=$(attr_says "$_path"); then|  if false; then|' "$DIFF_RENDER" > "$WORK/no-attrs.sh"
case_render_red "the script stops asking .gitattributes, so a generated file reads as renderable" "$WORK/no-attrs.sh"

# 9. Reading GitHub's limits and keeping only the memorable pair. The hard cap is the number
#    that sounds like the limit; 400 lines is the one that decides almost every real citation.
sed 's|^AUTOLOAD_LINES=400$|AUTOLOAD_LINES=20000|' "$DIFF_RENDER" > "$WORK/hard-cap-only.sh"
case_render_red "only the 20,000-line hard cap is enforced, not the 400-line auto-load threshold" "$WORK/hard-cap-only.sh"

# 10. The other direction, and the one that costs the page its product: answering "collapse" for
#     a path the diff never touched pushes every *affected but unchanged* citation off the blob
#     form it requires and onto a diff anchor that cannot address an unchanged line at all.
sed "s|printf 'render\\\\tnot-in-diff|printf 'collapse\\\\tnot-in-diff|" "$DIFF_RENDER" > "$WORK/unchanged-collapsed.sh"
case_render_red "a path outside the diff is reported as collapsed" "$WORK/unchanged-collapsed.sh"

# 11. The guard whose absence is a silent clean bill of health: with the refs unresolved, every
#     git call still feeds a pipeline that exits 0 and prints nothing, so the script reports that
#     no file is withheld. Written without the guard first, and this row is why it has one.
awk '/^for ref in "\$BASE" "\$HEAD_REF"; do$/ { skip = 3 } skip { skip--; next } { print }' \
  "$DIFF_RENDER" > "$WORK/no-ref-guard.sh"
case_render_red "the ref guard is gone, so an unresolvable base reads as a diff with nothing withheld" "$WORK/no-ref-guard.sh"

echo ""
echo "self-test: $ok ok, $bad bad"
[ "$bad" -eq 0 ]
