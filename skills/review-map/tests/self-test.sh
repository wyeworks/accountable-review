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
CARRY_PLAN=$SKILL_DIR/scripts/carry-plan.sh

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT HUP TERM

ok=0; bad=0

# case <what> <template> <script>
case_runs_red() {
  what=$1; tpl=$2; scr=$3
  if REVIEW_MAP_TEMPLATE="$tpl" REVIEW_MAP_SKELETON="$scr" "$RUN" >/dev/null 2>&1 </dev/null; then
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
  if REVIEW_MAP_DIFF_RENDER="$scr" "$RUN" >/dev/null 2>&1 </dev/null; then
    bad=$((bad + 1)); echo "BAD   run.sh stayed green when: $what"
  else
    ok=$((ok + 1));  echo "ok    run.sh fails when: $what"
  fi
}

case_carry_red() {
  what=$1; scr=$2
  chmod 755 "$scr"
  if REVIEW_MAP_CARRY_PLAN="$scr" "$RUN" >/dev/null 2>&1 </dev/null; then
    bad=$((bad + 1)); echo "BAD   run.sh stayed green when: $what"
  else
    ok=$((ok + 1));  echo "ok    run.sh fails when: $what"
  fi
}

# A sanity row first. If the unmutated pair does not pass, every row below is meaningless.
if REVIEW_MAP_TEMPLATE="$TEMPLATE" REVIEW_MAP_SKELETON="$SKELETON" "$RUN" >/dev/null 2>&1 </dev/null; then
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

# 23. The search row's hanging indent, unscoped — the rule as it shipped. -16px on every code in
#     the row reaches one inside the clause and drags it over the words before it; measured on a
#     published page, a 16px overlap. Mutating it back into the descendant rule is the regression
#     itself, not an approximation of it.
sed 's|^\.searched \.sr-list code { min-width: 0;|.searched .sr-list code { min-width: 0; margin-left: -16px;|' \
  "$TEMPLATE" > "$WORK/sr-indent.html"
case_runs_red "the search row's indent pulls every code left, not only the leading command" "$WORK/sr-indent.html" "$SKELETON"

# 24. And the example that makes rule 23 reachable. With no code inside a clause the template can
#     carry the unscoped rule and look completely correct — which is how it did ship.
sed 's|, naming <code>{{THE_SYMBOL_IT_FOUND}}</code> where the clause needs one||' \
  "$TEMPLATE" > "$WORK/sr-nocode.html"
case_runs_red "no search row's clause carries an inline code, so nothing exercises the indent's scope" "$WORK/sr-nocode.html" "$SKELETON"

# 25. The inventory's odd last cell. .gt shows --rule through a 1px gap, so a half-empty last row
#     paints the container's rule colour as a filled slab where a cell would be — a box that reads
#     as a path with nothing in it. An odd number of paths is the common case.
sed '/^\.gt-paths > \.c:last-child:nth-child(odd) {/d' "$TEMPLATE" > "$WORK/gt-odd.html"
case_runs_red "an odd final inventory cell leaves a rule-coloured slab instead of spanning" "$WORK/gt-odd.html" "$SKELETON"

# 26. And its example. Two cells is an even grid, where the rule above never fires and its absence
#     is invisible — which is what the template had while the defect shipped.
awk '/<div class="c" data-path="{{PATH}}">/ && !d { d = 1; next } { print }' "$TEMPLATE" > "$WORK/gt-even.html"
case_runs_red "the assembled inventory has an even number of cells, so nothing exercises the odd-cell rule" "$WORK/gt-even.html" "$SKELETON"

# ---- links leaving the page open in a new tab ----
#
# Every row here leaves a page that renders identically and reads identically. The defect is only
# felt by a reader who followed a citation and came back — which is nobody, during development.

# 27. The rule gone. Links still work, so nothing looks broken; what is lost is the reader's place
#     in an agenda they had not finished, and they lose it on the first citation they open.
grep -v "a.setAttribute('target', '_blank');" "$TEMPLATE" > "$WORK/no-newtab.html"
case_runs_red "the tail script stops opening off-page links in a new tab" "$WORK/no-newtab.html" "$SKELETON"

# 28. target without rel. This is the version that looks complete: the new tab opens, the citation
#     lands, and the only thing wrong is a window.opener handle back into this page from a host it
#     does not control. It is also the likelier mutation, because deleting the rel line is the
#     obvious way to make the block shorter.
grep -v "a.setAttribute('rel', 'noopener noreferrer');" "$TEMPLATE" > "$WORK/no-rel.html"
case_runs_red "the new-tab pass sets target without rel" "$WORK/no-rel.html" "$SKELETON"

# 29. The guard that keeps the page's own links in this tab. Without it the rail, the Checkpoint
#     pointers and the impact cards' back-references all open a second copy of the page — the
#     reader's place lost with a window on top of it, which is worse than the defect the pass
#     exists to fix and arrives looking like the same feature.
grep -v 'if (there === here) { return; }' "$TEMPLATE" > "$WORK/newtab-all.html"
case_runs_red "the new-tab pass stops exempting this page's own links" "$WORK/newtab-all.html" "$SKELETON"

# 30. And the other direction: a target typed at a citation. One page's markup is then correct and
#     every later run copies an attribute it has to remember at every citation, which is how one
#     of them ends up without it. The script is the rule; the markup half stays clean.
sed 's|<a class="path" href="{{BLOB}}#L{{LINE}}">|<a class="path" target="_blank" href="{{BLOB}}#L{{LINE}}">|' \
  "$TEMPLATE" > "$WORK/typed-target.html"
case_runs_red "a citation in the markup half types a target for a run to copy" "$WORK/typed-target.html" "$SKELETON"

# ---- the primer callout, which is the only component a flag admits ----
#
# Six rows, because a primer has more ways to be quietly wrong than any other component here: it is
# two paragraphs of framework prose, which read as self-justifying, and every one of its guards is a
# thing that can be dropped while the callout still renders beautifully.

# 31. Gone entirely. A --mentor run then has no markup to copy and writes the callout from memory,
#     which is where the mark, the demo-with-an-app-class and the unpinned link all come back from.
awk '/<aside class="primer">/ { f = 1 } f { if ($0 ~ /<\/aside>/) f = 0; next } { print }' \
  "$TEMPLATE" > "$WORK/no-primer.html"
case_runs_red "the assembled primer is gone, so a mentor run has nothing to copy" "$WORK/no-primer.html" "$SKELETON"

# 32. The logotype returns. This is the specific shape the svg ban comes back in, because the mark
#     is the one drawing on this page that had a reason: it was an attribution. Asserted through
#     .pr-mark rather than through the svg count, so the row goes red on the class alone — a mark
#     smuggled in as a web font or a background image is the same defect and the same disclosure
#     obligation, and neither one carries an opening svg tag.
awk '/<span class="pr-title">/ && !d { print "            <span class=\"pr-mark\"></span>"; d = 1 } { print }' \
  "$TEMPLATE" > "$WORK/pr-mark.html"
case_runs_red "the primer's logotype comes back, bringing the trademark obligation with it" "$WORK/pr-mark.html" "$SKELETON"

# 33. A demo outside a primer. pre.demo is the one block on this page allowed to show a result line,
#     and the only thing that makes that honest is the receiver: a class this repository does not
#     have, so the line quotes the manual. Outside a primer it is a general-purpose hole for output
#     nobody observed, with the probe rule switched off.
awk '/<figcaption>{{WHAT_THE_CHAIN_SHOWS_IN_ONE_LINE}}<\/figcaption>/ && !d { print "<pre class=\"demo\">x # =&gt; 1</pre>"; d = 1 } { print }' \
  "$TEMPLATE" > "$WORK/loose-demo.html"
case_runs_red "a pre.demo sits outside a primer, where nothing constrains its receiver" "$WORK/loose-demo.html" "$SKELETON"

# 34. The gate itself. A primer is what a doc link escalates INTO, so one with no link is two
#     paragraphs of framework assertion the reader cannot check — and it is also what makes a closed
#     catalogue mean no primers for that stack, which is the whole reason Phoenix is narrow today
#     rather than confidently wrong.
grep -v 'classes/ActiveRecord/AttributeMethods/Dirty.html' "$TEMPLATE" > "$WORK/primer-no-doc.html"
case_runs_red "the primer loses the doc link it is gated on" "$WORK/primer-no-doc.html" "$SKELETON"

# 35. And the other half of the same rule. Without the file:line the callout has no stake in this
#     repository at all: it is a framework lesson attached to a judgment by nothing but adjacency.
sed 's|<div class="item">The callback at <a class="path" href="{{DIFF}}R{{LINE}}">{{PATH}}:{{LINE}}</a>|<div class="item">The callback|' \
  "$TEMPLATE" > "$WORK/primer-no-cite.html"
case_runs_red "the primer stops citing the line in this repository that earned it" "$WORK/primer-no-cite.html" "$SKELETON"

# 36. Position. Below the Look at list the lesson arrives after the reader has already been sent to
#     the code, which is the one ordering that makes a primer worse than no primer: they open four
#     files without the rule that decides what they are looking at.
awk '
  /<aside class="primer">/ { inp = 1 }
  inp { buf = buf $0 "\n"; if ($0 ~ /<\/aside>/) inp = 0; next }
  { print }
  /<\/ul>/ && buf != "" && !done { printf "%s", buf; done = 1 }
' "$TEMPLATE" > "$WORK/primer-late.html"
case_runs_red "the primer is assembled below the Look at list it is meant to precede" "$WORK/primer-late.html" "$SKELETON"

# 37. The header goes back to naming the component. "Rails | Primer" spends the widest line in the
#     block on a fact the reader can see — that this is a callout — and says nothing about what it
#     teaches. The eyebrow is reinstated here together with the separator it needs, because that is
#     how the old shape actually returns: not as one stray span, but as the pair.
sed 's|<span class="pr-title">Understanding Ruby on Rails</span>|<span class="pr-title">Rails</span><i class="pr-sep"></i><span class="lbl">Primer</span>|' \
  "$TEMPLATE" > "$WORK/primer-eyebrow.html"
case_runs_red "the primer header names the component again instead of the stack" "$WORK/primer-eyebrow.html" "$SKELETON"

# 38. And the ramp that frames it, half-declared. --primer-* is the newest colour on this page and
#     the one nothing depends on to be readable, which is exactly the profile of a token that gets
#     forgotten in one of the three theme blocks and is invisible until someone opens a mentor page
#     with the OS in dark mode. Counted by name for the reason --syn-key is.
sed '/^  --primer-ink:        oklch(0.80  0.09  28);$/d' "$TEMPLATE" > "$WORK/primer-ink-dark.html"
case_runs_red "the primer frame's ink is missing from a dark theme block" "$WORK/primer-ink-dark.html" "$SKELETON"

# ---- diff-render.sh: every mutation here publishes a link that lands on nothing ----
#
# All of them are script mutations for the reason the first two cases above are: the repository
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

# 12. The measurement this script shipped with for a year: counting the changed lines instead of
#     the diff GitHub renders. It is the mutation that looks most like the real thing — add+del
#     is the obvious reading of "400 lines", it agrees with the correct measure on every file
#     whose changes are contiguous, and it disagrees exactly where the context is: a scattered
#     diff. Only the scattered row may go red here; big.rb is over by either measure, which is
#     what makes this a test of the quantity rather than of the threshold.
sed 's|^    _lines=$(printf .*|    _lines=$((_add + _del))|' "$DIFF_RENDER" > "$WORK/changed-lines-only.sh"
case_render_red "the changed lines are counted instead of the diff GitHub renders" "$WORK/changed-lines-only.sh"

# ---- carry-plan.sh: every way a carried claim goes quietly false ----
#
# This script's failure mode is the quietest in the repository. Every mutation below leaves it
# printing a confident, well-formed plan — the only difference is that the plan is wrong, and
# the page that follows it says it describes a revision half of it was never read against.

# 13. The polarity. A skip needs EVERY precondition to hold; flipping the delta-size rule to fire
#     only on a small delta inverts the one number standing between a cheap update and a page
#     most of which nobody re-read.
sed 's|if \[ "$N_FULL" -eq 0 \] \|\| \[ $((N_DELTA \* 2)) -gt "$N_FULL" \]; then|if [ $((N_DELTA * 2)) -lt 0 ]; then|' \
  "$CARRY_PLAN" > "$WORK/no-half-rule.sh"
case_carry_red "the delta-size rule never fires, so a rewrite of the branch updates in place" "$WORK/no-half-rule.sh"

# 14. P6, which is the rule that protects the product. Affected-but-unchanged code is what the
#     page is for, and a new consumer landing in a file no checkpoint cites is invisible to the
#     carry rule — the recorded searches are the only thing on the page that can see it. With the
#     intersection stubbed out the script still runs every search and still reports them safe.
sed 's|^  landed=$(comm -12 "$TMP/delta" "$TMP/hitpaths" \| head -n 1)$|  landed=|' \
  "$CARRY_PLAN" > "$WORK/no-p8.sh"
case_carry_red "a delta path among a recorded search's hits no longer refuses" "$WORK/no-p8.sh"

# 15. The reason -v is not used. awk's -v processes escape sequences in the value, so a recorded
#     `rg -n '\bProjects::Archive\b'` arrives with two backspaces where its word boundaries were.
#     The pattern still runs and still matches things — just not the things the page recorded —
#     and every search then reports itself clean. This is the single most deniable line here.
sed "s|  CARRY_CMD=\$1 awk '|  awk -v s=\"\$1\" '|; s|^      s = ENVIRON\[\"CARRY_CMD\"\]$||" \
  "$CARRY_PLAN" > "$WORK/dash-v.sh"
case_carry_red "the recorded pattern reaches awk through -v, which eats its backslash escapes" "$WORK/dash-v.sh"

# 16. An unreplayable search is not a search that found nothing. Skipping the row rather than
#     refusing turns the one honest answer — "I cannot check this" — into the most reassuring one.
sed 's|^    UNSAFE=$cmd$|    continue|' "$CARRY_PLAN" > "$WORK/skip-unsafe.sh"
case_carry_red "a search that cannot be replayed is skipped instead of refusing the update" "$WORK/skip-unsafe.sh"

# 17. The substring trap, which coverage-gate.sh has already paid for once. Without the token
#     boundaries api/Gemfile matches inside api/Gemfile.lock, and a checkpoint that cites the
#     changed file is carried because a different file's name contains it.
sed "s|^BOUND='\[^A-Za-z0-9._/-\]'$|BOUND=''|" "$CARRY_PLAN" > "$WORK/substring.sh"
case_carry_red "the path test is a substring match rather than a whole token" "$WORK/substring.sh"

# 18. P1. A rebased branch's "delta" is a diff between two histories rather than the commits
#     someone pushed, and every carry decision downstream is then made against the wrong set.
awk '/^if ! git merge-base --is-ancestor/ { skip = 3 } skip { skip--; next } { print }' \
  "$CARRY_PLAN" > "$WORK/no-ancestry.sh"
case_carry_red "the ancestry guard is gone, so a force-pushed branch updates in place" "$WORK/no-ancestry.sh"

# 19. P3. Pending is a promise; carrying one promises work that nothing is doing, and the page it
#     produces is a draft wearing a finished page's masthead.
sed 's|^if grep -q .class="buildstate". "$PAGE" .*$|if false; then|' "$CARRY_PLAN" > "$WORK/draft-ok.sh"
case_carry_red "a draft page is accepted as a base to update from" "$WORK/draft-ok.sh"

# 20. The excerpt rule. An excerpt is a verbatim quotation and its state tag is computed from the
#     diff, so a file entering the delta invalidates both. Keeping it is the one way this page
#     lies about bytes while the bytes themselves are real.
sed "s|    printf 'excerpt\\\\t%s\\\\tregen\\\\n' \"\$p\"|    printf 'excerpt\\\\t%s\\\\tkeep\\\\n' \"\$p\"|" \
  "$CARRY_PLAN" > "$WORK/keep-excerpts.sh"
case_carry_red "an excerpt whose file moved in the delta is carried rather than regenerated" "$WORK/keep-excerpts.sh"

# 21. A refusal that prints its plan rows anyway. Half a plan reads as a plan, and the rows that
#     did print are exactly the ones a run would act on.
sed 's|^  echo "verdict: full"$|  sed "s/^/delta\\t/" "$TMP/delta" 2>/dev/null; echo "verdict: full"|' \
  "$CARRY_PLAN" > "$WORK/leaky-refusal.sh"
case_carry_red "a refusal prints plan rows alongside its verdict" "$WORK/leaky-refusal.sh"

echo ""
echo "self-test: $ok ok, $bad bad"
[ "$bad" -eq 0 ]
