#!/bin/sh
# self-test.sh — breaks things run.sh claims to check, and asserts it notices each one.
#
#   Usage: tests/self-test.sh
#
# Same argument as evals/checks/self-test.rb: a check that passes
# because it never looked is worse than no check, and the only way to tell the two apart is to
# introduce the defect and watch the suite go red.
#
# Two kinds of mutation, and the split matters. Mutating the TEMPLATE proves the assertions about
# what each half must contain. Mutating the SCRIPT is what proves the partition assertion, because
# a template mutation alone cannot: the script extracts from the same file the test compares
# against, so both sides move together and the suite would stay green. That is the oracle problem
# in the one place it could still hide, so the first two cases here are script mutations.
#
# WHICH DEFECTS EARN A ROW. A row costs a whole run.sh pass, so it has to prove something the
# sanity row below does not. That row runs run.sh on the real template and requires it green, and
# for an assertion of the form `count == N` with N of one or more, that already proves the pattern
# is spelled right and the assertion looked: a misspelled literal counts 0 and fails unmutated.
# Deleting the literal again only proves assert_eq can tell 0 from 1. So a template row is written
# only where the real template could pass with the check broken:
#   - an assertion expecting ZERO, because a misspelled pattern also counts zero and passes;
#   - a range or an order whose boundary could be wrong and still yield the expected count.
# Script mutations always earn one: they ask whether run.sh's fixtures exercise the script's logic
# at all, and no unmutated run can answer that. This file once carried 53 rows; 25 of them were
# positive literals deleted back out, and the reasoning they held lives beside the assertion in
# run.sh, where the next person to edit it is looking.
#
# Each row runs only the section of run.sh its mutation can reach (REVIEW_MAP_SECTION). The
# sanity row runs all of it.
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
  if REVIEW_MAP_SECTION=skeleton REVIEW_MAP_TEMPLATE="$tpl" REVIEW_MAP_SKELETON="$scr" "$RUN" >/dev/null 2>&1 </dev/null; then
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
  if REVIEW_MAP_SECTION=diff-render REVIEW_MAP_DIFF_RENDER="$scr" "$RUN" >/dev/null 2>&1 </dev/null; then
    bad=$((bad + 1)); echo "BAD   run.sh stayed green when: $what"
  else
    ok=$((ok + 1));  echo "ok    run.sh fails when: $what"
  fi
}

case_carry_red() {
  what=$1; scr=$2
  chmod 755 "$scr"
  if REVIEW_MAP_SECTION=carry-plan REVIEW_MAP_CARRY_PLAN="$scr" "$RUN" >/dev/null 2>&1 </dev/null; then
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
#    Appended rather than prepended: a line ahead of the head's opening <title> is refused by the
#    script's own title guard, and this case has to reach the prefix assertion to prove it.
sed 's|^extract "\$HEAD_S" "\$HEAD_E" "\$TEMPLATE" | { extract "$HEAD_S" "$HEAD_E" "$TEMPLATE"; echo "<style>.injected{color:red}</style>"; } |' \
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

# ---- the page's one shape ----
#
# Every case below leaves a page that still renders and still looks finished, which is the whole
# reason each needs a rule of its own rather than a reading of the template.

# 5. The rule that replaced the diagram catalogue: this page draws nothing. An <svg> in the half a
#    run reads is one it will copy, and a drawing derived per run spends the run's attention on
#    geometry instead of on whether the edges are true.
awk '/<section class="cp" id="cp-b">/ && !d { print; print "        <svg viewBox=\"0 0 10 10\"></svg>"; d = 1; next } { print }' \
  "$TEMPLATE" > "$WORK/svg-back.html"
case_runs_red "an svg is back in the markup half" "$WORK/svg-back.html" "$SKELETON"

# 6. The rule that keeps the two chain figures apart. An .ip-aff node inside a checkpoint's chain
#    is a hop into unchanged code drawn in the wrong section — the same consequence drawn twice,
#    once here and once in the impact panel, which reads as thoroughness.
sed 's|class="ip-n ip-step"|class="ip-n ip-aff"|' "$TEMPLATE" > "$WORK/chain-aff.html"
case_runs_red "a chain inside a checkpoint carries an affected-unchanged node" "$WORK/chain-aff.html" "$SKELETON"

# 7. The paragraph belongs to the panel and not to a checkpoint's chain, whose own two to four
#    sentences already are it. A template carrying one in both places teaches a run to write the
#    explanation twice at conversational distance, which is what the agenda exists to end.
awk '/<figure class="chain">/ { print; print "          <p class=\"ip-why\">a second explanation</p>"; next } { print }' \
  "$TEMPLATE" > "$WORK/chain-why.html"
case_runs_red "a checkpoint chain is given a paragraph of its own" "$WORK/chain-why.html" "$SKELETON"

# 8. A locator on the outcome, which is the locator defect that looks MORE thorough than the
#    correct markup: it draws, it links somewhere real, and it puts an address on the
#    one node that is a behaviour rather than a file.
awk '/<li class="ip-n ip-out">/ && !d { d = 1; sub(/<\/span><\/li>/, "<a class=\"path ip-loc\" href=\"#\">app/x.rb:1</a></span></li>"); print; next } { print }' \
  "$TEMPLATE" > "$WORK/out-loc.html"
case_runs_red "an outcome node is given a locator" "$WORK/out-loc.html" "$SKELETON"

# 9. data-path is reserved to the inventory: coverage-gate.sh greps it page-wide and compares
#    against git diff --name-only, so a locator carrying one registers as a surplus path and
#    fails the page's one mechanical gate.
sed 's|class="path ip-loc" href="{{BLOB}}#L{{START}}"|class="path ip-loc" data-path="x" href="{{BLOB}}#L{{START}}"|' \
  "$TEMPLATE" > "$WORK/loc-datapath.html"
case_runs_red "a locator carries the inventory's data-path attribute" "$WORK/loc-datapath.html" "$SKELETON"

# 10. A connector between a converge's paths. They are siblings, not a sequence, and the impact
#     panel's lane crossing hangs off `.ip-chg + .ip-aff > .ip-rel` — which a converge alternates.
#     The assertion expects zero inside a range, so a misspelled pattern would pass unmutated.
awk '/<ol class="cv-paths">/ { f = 1 } f && /class="ip-n ip-aff"/ && !d { sub(/<span class="ip-box">/, "<span class=\"ip-rel\"><i></i>calls</span><span class=\"ip-box\">"); d = 1 } { print }' \
  "$TEMPLATE" > "$WORK/cv-rel.html"
case_runs_red "a converge's paths are joined by a connector" "$WORK/cv-rel.html" "$SKELETON"

# 11. A locator on the converge's target. An invariant is a property, not a file — the converge's
#     version of #8, and it looks just as thorough.
sed 's|<b>{{THE_INVARIANT}}</b><span class="ip-d">must hold on every path</span>|&<a class="path ip-loc" href="#">app/x.rb:1</a>|' \
  "$TEMPLATE" > "$WORK/cv-target-loc.html"
case_runs_red "a converge's target is given a locator" "$WORK/cv-target-loc.html" "$SKELETON"

# 12. An unchanged node in a lifecycle. A state is not a file, so the teal kind has nothing to mean.
sed 's|<li class="lc-s lc-new">|<li class="lc-s ip-aff">|' "$TEMPLATE" > "$WORK/lc-aff.html"
case_runs_red "a lifecycle state is drawn as unchanged code" "$WORK/lc-aff.html" "$SKELETON"

# 13. The search row's hanging indent, unscoped — the rule as it shipped. -16px on every code in
#     the row reaches one inside the clause and drags it over the words before it; measured on a
#     published page, a 16px overlap. Mutating it back into the descendant rule is the regression
#     itself, not an approximation of it.
sed 's|^\.searched \.sr-list code { min-width: 0;|.searched .sr-list code { min-width: 0; margin-left: -16px;|' \
  "$TEMPLATE" > "$WORK/sr-indent.html"
case_runs_red "the search row's indent pulls every code left, not only the leading command" "$WORK/sr-indent.html" "$SKELETON"

# ---- links leaving the page open in a new tab ----
#
# Every row here leaves a page that renders identically and reads identically. The defect is only
# felt by a reader who followed a citation and came back — which is nobody, during development.

# 14. A target typed at a citation rather than applied by the tail script. One page's markup is
#     then correct and every later run copies an attribute it has to remember at every citation,
#     which is how one of them ends up without it. The script is the rule; the markup half stays clean.
sed 's|<a class="path" href="{{BLOB}}#L{{LINE}}">|<a class="path" target="_blank" href="{{BLOB}}#L{{LINE}}">|' \
  "$TEMPLATE" > "$WORK/typed-target.html"
case_runs_red "a citation in the markup half types a target for a run to copy" "$WORK/typed-target.html" "$SKELETON"

# ---- the primer callout, which is the only component a flag admits ----
#
# A primer has more ways to be quietly wrong than any other component here: it is two paragraphs of
# framework prose, which read as self-justifying, and every one of its guards is a thing that can be
# dropped while the callout still renders beautifully. run.sh asserts each guard; the rows here are
# the ones whose assertion expects zero or reads an order, which the sanity row cannot vouch for.

# 15. The logotype returns. This is the specific shape the svg ban comes back in, because the mark
#     is the one drawing on this page that had a reason: it was an attribution. Asserted through
#     .pr-mark rather than through the svg count, so the row goes red on the class alone — a mark
#     smuggled in as a web font or a background image is the same defect and the same disclosure
#     obligation, and neither one carries an opening svg tag.
awk '/<span class="pr-title">/ && !d { print "            <span class=\"pr-mark\"></span>"; d = 1 } { print }' \
  "$TEMPLATE" > "$WORK/pr-mark.html"
case_runs_red "the primer's logotype comes back, bringing the trademark obligation with it" "$WORK/pr-mark.html" "$SKELETON"

# 16. Position. Below the Look at list the lesson arrives after the reader has already been sent to
#     the code, which is the one ordering that makes a primer worse than no primer: they open four
#     files without the rule that decides what they are looking at.
awk '
  /<aside class="primer">/ { inp = 1 }
  inp { buf = buf $0 "\n"; if ($0 ~ /<\/aside>/) inp = 0; next }
  { print }
  /<\/ul>/ && buf != "" && !done { printf "%s", buf; done = 1 }
' "$TEMPLATE" > "$WORK/primer-late.html"
case_runs_red "the primer is assembled below the Look at list it is meant to precede" "$WORK/primer-late.html" "$SKELETON"

# 17. The header goes back to naming the component. "Rails | Primer" spends the widest line in the
#     block on a fact the reader can see — that this is a callout — and says nothing about what it
#     teaches. The eyebrow is reinstated here together with the separator it needs, because that is
#     how the old shape actually returns: not as one stray span, but as the pair.
sed 's|<span class="pr-title">Understanding Ruby on Rails</span>|<span class="pr-title">Rails</span><i class="pr-sep"></i><span class="lbl">Primer</span>|' \
  "$TEMPLATE" > "$WORK/primer-eyebrow.html"
case_runs_red "the primer header names the component again instead of the stack" "$WORK/primer-eyebrow.html" "$SKELETON"

# ---- Context, section 02 ----
#
# Every row here expects zero or reads an order, which is why each one earns a pass: a misspelled
# pattern also counts zero, and a section in the wrong place still counts one.

# 18. A figure in Context. The before/after flow figure is designed and deferred, and figures.rb
#     grades only checkpoint figures — so a figure that arrived here would be the one on the page
#     nothing looks at. Planted as a kind no other row counts, so only the zero can catch it.
awk '/<dl class="ctx">/ && !d { print "      <figure class=\"flow\"><figcaption>x</figcaption></figure>"; d = 1 } { print }' \
  "$TEMPLATE" > "$WORK/ctx-figure.html"
case_runs_red "a figure is drawn inside Context" "$WORK/ctx-figure.html" "$SKELETON"

# 19. A tier in Context. An entry says what a thing is, not what the change did, so a label on it
#     says the page is grading how it knows a fact about the repository rather than the change.
sed 's|{{WHAT_IT_IS}}|{{WHAT_IT_IS}} <span class="tier tier-unc">from unchanged code</span>|' \
  "$TEMPLATE" > "$WORK/ctx-tier.html"
case_runs_red "an evidence tier is put on a Context entry" "$WORK/ctx-tier.html" "$SKELETON"

# 20. The foot given a number. It is not a section — no number, no rail entry, shut — and the
#     sixth number is how it would come back, one rail line that looks like tidiness. It replaces a
#     sub-entry rather than adding one, so the rail's total cannot be what goes red.
sed 's|<a class="sub" data-rail="cp-x" href="#cp-x">.*|<a data-rail="evidence" href="#evidence"><span class="n">06</span>Evidence</a>|' \
  "$TEMPLATE" > "$WORK/rail-06.html"
case_runs_red "the evidence foot gets a sixth rail number" "$WORK/rail-06.html" "$SKELETON"

# 21. Context after the agenda. Every entry is still there and still points at its checkpoint, so
#     only the order assertion can notice — and after the agenda it orients a reader who has
#     already met the judgments it was meant to make followable.
awk '
  /^ *<section id="context">/ { inp = 1 }
  inp { buf = buf $0 "\n"; if ($0 ~ /^ *<\/section>/) inp = 0; next }
  /^ *<section id="start"/ && buf != "" && !done { printf "%s", buf; done = 1 }
  { print }
' "$TEMPLATE" > "$WORK/ctx-late.html"
case_runs_red "Context is assembled after the agenda" "$WORK/ctx-late.html" "$SKELETON"

# ---- diff-render.sh: every mutation here publishes a link that lands on nothing ----
#
# All of them are script mutations for the reason the first two cases above are: the repository
# these rows run against is built by run.sh, so there is no fixture to break — and each of them
# leaves a page that looks completely correct, with an anchor that arrives at a "Load diff" stub
# and a reader who cannot tell.

# 22. The signal no size rule can replace. One changed line in a linguist-generated file is a
#     small diff by every measurement there is, and GitHub collapses it anyway.
sed 's|^  if _why=$(attr_says "$_path"); then|  if false; then|' "$DIFF_RENDER" > "$WORK/no-attrs.sh"
case_render_red "the script stops asking .gitattributes, so a generated file reads as renderable" "$WORK/no-attrs.sh"

# 23. Reading GitHub's limits and keeping only the memorable pair. The hard cap is the number
#     that sounds like the limit; 400 lines is the one that decides almost every real citation.
sed 's|^AUTOLOAD_LINES=400$|AUTOLOAD_LINES=20000|' "$DIFF_RENDER" > "$WORK/hard-cap-only.sh"
case_render_red "only the 20,000-line hard cap is enforced, not the 400-line auto-load threshold" "$WORK/hard-cap-only.sh"

# 24. The other direction, and the one that costs the page its product: answering "collapse" for
#     a path the diff never touched pushes every *affected but unchanged* citation off the blob
#     form it requires and onto a diff anchor that cannot address an unchanged line at all.
sed "s|printf 'render\\\\tnot-in-diff|printf 'collapse\\\\tnot-in-diff|" "$DIFF_RENDER" > "$WORK/unchanged-collapsed.sh"
case_render_red "a path outside the diff is reported as collapsed" "$WORK/unchanged-collapsed.sh"

# 25. The guard whose absence is a silent clean bill of health: with the refs unresolved, every
#     git call still feeds a pipeline that exits 0 and prints nothing, so the script reports that
#     no file is withheld. Written without the guard first, and this row is why it has one.
awk '/^for ref in "\$BASE" "\$HEAD_REF"; do$/ { skip = 3 } skip { skip--; next } { print }' \
  "$DIFF_RENDER" > "$WORK/no-ref-guard.sh"
case_render_red "the ref guard is gone, so an unresolvable base reads as a diff with nothing withheld" "$WORK/no-ref-guard.sh"

# 26. The measurement this script shipped with for a year: counting the changed lines instead of
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

# 27. The polarity. A skip needs EVERY precondition to hold; flipping the delta-size rule to fire
#     only on a small delta inverts the one number standing between a cheap update and a page
#     most of which nobody re-read.
sed 's|if \[ "$N_FULL" -eq 0 \] \|\| \[ $((N_DELTA \* 2)) -gt "$N_FULL" \]; then|if [ $((N_DELTA * 2)) -lt 0 ]; then|' \
  "$CARRY_PLAN" > "$WORK/no-half-rule.sh"
case_carry_red "the delta-size rule never fires, so a rewrite of the branch updates in place" "$WORK/no-half-rule.sh"

# 28. P6, which is the rule that protects the product. Affected-but-unchanged code is what the
#     page is for, and a new consumer landing in a file no checkpoint cites is invisible to the
#     carry rule — the recorded searches are the only thing on the page that can see it. With the
#     intersection stubbed out the script still runs every search and still reports them safe.
sed 's|^  landed=$(comm -12 "$TMP/delta" "$TMP/hitpaths" \| head -n 1)$|  landed=|' \
  "$CARRY_PLAN" > "$WORK/no-p8.sh"
case_carry_red "a delta path among a recorded search's hits no longer refuses" "$WORK/no-p8.sh"

# 29. The reason -v is not used. awk's -v processes escape sequences in the value, so a recorded
#     `rg -n '\bProjects::Archive\b'` arrives with two backspaces where its word boundaries were.
#     The pattern still runs and still matches things — just not the things the page recorded —
#     and every search then reports itself clean. This is the single most deniable line here.
sed "s|  CARRY_CMD=\$1 awk '|  awk -v s=\"\$1\" '|; s|^      s = ENVIRON\[\"CARRY_CMD\"\]$||" \
  "$CARRY_PLAN" > "$WORK/dash-v.sh"
case_carry_red "the recorded pattern reaches awk through -v, which eats its backslash escapes" "$WORK/dash-v.sh"

# 30. An unreplayable search is not a search that found nothing. Skipping the row rather than
#     refusing turns the one honest answer — "I cannot check this" — into the most reassuring one.
sed 's|^    UNSAFE=$cmd$|    continue|' "$CARRY_PLAN" > "$WORK/skip-unsafe.sh"
case_carry_red "a search that cannot be replayed is skipped instead of refusing the update" "$WORK/skip-unsafe.sh"

# 31. The substring trap, which coverage-gate.sh has already paid for once. Without the token
#     boundaries api/Gemfile matches inside api/Gemfile.lock, and a checkpoint that cites the
#     changed file is carried because a different file's name contains it.
sed "s|^BOUND='\[^A-Za-z0-9._/-\]'$|BOUND=''|" "$CARRY_PLAN" > "$WORK/substring.sh"
case_carry_red "the path test is a substring match rather than a whole token" "$WORK/substring.sh"

# 31a. A Context entry is outside every checkpoint, so the cp rule never reaches it. Carry every
#      entry and the page keeps saying what a file IS after the delta changed that file, while
#      every checkpoint pointing at the entry carries because none of them cites the file.
sed 's|^  plan_row ctx "\$name"$|  reason=-; plan_row ctx "$name"|' "$CARRY_PLAN" > "$WORK/ctx-always-carry.sh"
case_carry_red "a Context entry citing a delta path is carried" "$WORK/ctx-always-carry.sh"

# 32. P1. A rebased branch's "delta" is a diff between two histories rather than the commits
#     someone pushed, and every carry decision downstream is then made against the wrong set.
awk '/^if ! git merge-base --is-ancestor/ { skip = 3 } skip { skip--; next } { print }' \
  "$CARRY_PLAN" > "$WORK/no-ancestry.sh"
case_carry_red "the ancestry guard is gone, so a force-pushed branch updates in place" "$WORK/no-ancestry.sh"

# 33. P3. Pending is a promise; carrying one promises work that nothing is doing, and the page it
#     produces is a draft wearing a finished page's masthead.
sed 's|^if grep -q .class="buildstate". "$PAGE" .*$|if false; then|' "$CARRY_PLAN" > "$WORK/draft-ok.sh"
case_carry_red "a draft page is accepted as a base to update from" "$WORK/draft-ok.sh"

# 34. The excerpt rule. An excerpt is a verbatim quotation and its state tag is computed from the
#     diff, so a file entering the delta invalidates both. Keeping it is the one way this page
#     lies about bytes while the bytes themselves are real.
sed "s|    printf 'excerpt\\\\t%s\\\\tregen\\\\n' \"\$p\"|    printf 'excerpt\\\\t%s\\\\tkeep\\\\n' \"\$p\"|" \
  "$CARRY_PLAN" > "$WORK/keep-excerpts.sh"
case_carry_red "an excerpt whose file moved in the delta is carried rather than regenerated" "$WORK/keep-excerpts.sh"

# 35. A refusal that prints its plan rows anyway. Half a plan reads as a plan, and the rows that
#     did print are exactly the ones a run would act on.
sed 's|^  echo "verdict: full"$|  sed "s/^/delta\\t/" "$TMP/delta" 2>/dev/null; echo "verdict: full"|' \
  "$CARRY_PLAN" > "$WORK/leaky-refusal.sh"
case_carry_red "a refusal prints plan rows alongside its verdict" "$WORK/leaky-refusal.sh"

echo ""
echo "self-test: $ok ok, $bad bad"
[ "$bad" -eq 0 ]
