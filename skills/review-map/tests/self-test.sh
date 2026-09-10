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

# 6. Half-declaring a colour is invisible until someone opens a primer with the OS in dark mode.
awk '/--rails:/ && !d { d = 1; next } { print }' "$TEMPLATE" > "$WORK/half-rails.html"
case_runs_red "--rails is declared in only two of the three theme states" "$WORK/half-rails.html" "$SKELETON"

# 7. The title placeholder gone means every page ships with the same tab name.
sed 's|{{PR_TITLE_OR_BRANCH}} Review|Review|' "$TEMPLATE" > "$WORK/no-title.html"
case_runs_red "the title placeholder is missing, so no page can be named" "$WORK/no-title.html" "$SKELETON"

# ---- the level filter ----
#
# The first two are SCRIPT mutations, for the reason the top of this file gives: a template
# mutation cannot prove a filter fires, because the filter and the thing it filters move
# together. Both of these leave a page that still looks finished, which is the whole risk.

# 8. The filter never drops anything, so --level is a flag that quietly does nothing and every
#    run keeps paying for the tail it cannot write. Nothing about the page changes, which is
#    exactly why no other assertion here would notice.
sed 's|else if (keep != "" # ---- diff-render.sh: every mutation here publishes a link that lands on nothing ----# ---- diff-render.sh: every mutation here publishes a link that lands on nothing ---- tag != "level=" keep) drop = 1|else if (0) drop = 1|' \
  "$SKELETON" > "$WORK/filter-inert.sh"
case_runs_red "the level filter drops nothing, so --level does nothing" "$TEMPLATE" "$WORK/filter-inert.sh"

# 9. The opposite, and the one that loses content: --level brief drops the merged tail as well,
#    so a brief run is handed no section 4 carrier at all — and the completeness invariant has
#    no level, so the page it writes may have lost a file with nothing saying so.
sed 's|else if (keep != "" # ---- diff-render.sh: every mutation here publishes a link that lands on nothing ----# ---- diff-render.sh: every mutation here publishes a link that lands on nothing ---- tag != "level=" keep) drop = 1|else if (keep != "") drop = 1|' \
  "$SKELETON" > "$WORK/filter-drops-both.sh"
case_runs_red "--level drops its own level's regions too, leaving no carrier for the diff" "$TEMPLATE" "$WORK/filter-drops-both.sh"

# 10. An unpaired region. The END marker goes and the region runs to the end of the markup half,
#     so --level full takes the brief tail with it and --level brief keeps nothing after it.
grep -v 'SKELETON:ONLY:level=full:END' "$TEMPLATE" > "$WORK/only-unpaired.html"
case_runs_red "an ONLY region is never closed" "$WORK/only-unpaired.html" "$SKELETON"

# 11. A typo in a tag. This is the bypass worth its own rule: level=fulll matches no level, so
#     the region is kept at every level and the filter silently stops filtering that one.
sed 's|SKELETON:ONLY:level=full:START|SKELETON:ONLY:level=fulll:START|' "$TEMPLATE" > "$WORK/only-typo.html"
case_runs_red "an ONLY tag is misspelled, so its region belongs to no level" "$WORK/only-typo.html" "$SKELETON"

# 12. A nested pair. The inner END closes the outer region early, so the rest of the outer one
#     survives at a level that must not have it — and the markers still read as correct.
awk '/<section id="reach" style="padding-top:62px">/ && !d {
       print "    <!-- SKELETON:ONLY:level=brief:START -->"; print; print "    <!-- SKELETON:ONLY:level=brief:END -->"; d = 1; next
     } { print }' "$TEMPLATE" > "$WORK/only-nested.html"
case_runs_red "an ONLY region nests inside another" "$WORK/only-nested.html" "$SKELETON"

# 13. The rail's brief shape goes, so a --brief run is handed the seven-entry rail again and is
#     back to deriving four entries from a comment. The page still renders.
awk '/SKELETON:ONLY:level=brief:START/ { b = 1 }
     b && /<a data-rail="reach" href="#reach"><span class="n">04<\/span>Reach/ { b = 0; next }
     { print }' "$TEMPLATE" > "$WORK/no-brief-rail.html"
case_runs_red "the brief rail entry is gone, so --brief must derive its rail again" "$WORK/no-brief-rail.html" "$SKELETON"

# 14. The primer's gate goes, so a --brief run is handed the callout again and is back to being
#     told in a comment not to write one. The page still renders and every other level rule still
#     passes -- which is the whole reason this case exists rather than a reading of the template.
awk '/SKELETON:ONLY:level=full:START/ && !seen && ++hits == 2 { seen = 1; next }
     { print }' "$TEMPLATE" > "$WORK/ungated-primer.html"
case_runs_red "the primer is no longer gated to --full, so a brief run is handed it" "$WORK/ungated-primer.html" "$SKELETON"

# 15. And the other direction, which is the one that looks like tidying: the gate is widened over
#     the flow's figure, so --brief loses a drawing. The budget caps prose and removes no figure,
#     so a filter that takes one has broken the invariant while making the page shorter -- exactly
#     the compression this level is most likely to be wrong about.
awk '/<figure class="inflow">/ && !done { print "      <!-- SKELETON:ONLY:level=full:START -->"; f = 1 }
     f && /<\/figure>/ && !done { print; print "      <!-- SKELETON:ONLY:level=full:END -->"; f = 0; done = 1; next }
     { print }' "$TEMPLATE" > "$WORK/gated-figure.html"
case_runs_red "a flow's drawing is gated out of --brief, so a shorter page loses a figure" "$WORK/gated-figure.html" "$SKELETON"

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
