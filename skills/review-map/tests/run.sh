#!/bin/sh
# run.sh — the deterministic tests for review-map's scripts.
#
#   Usage: tests/run.sh
#
# Whether a Review Map is any good is a model run and cannot be asserted on. The scripts underneath
# it are ordinary software with right answers, and this is where that half is held to account.
# Today that is page-skeleton.sh — that what it emits is the template's own bytes and not a copy, and
# that it refuses to overwrite a page somebody is already reading — plus diff-render.sh, whose
# verdict decides which URL form a citation gets and is therefore the one script here whose output
# a reader of the page can be misled by.
#
# It is NOT under evals/checks/ for the reason verify-catalogue.sh is not: check.rb dispatches
# offline rules over a page, and this takes no page — it is a relation between two files in the
# repository. Unlike that one it needs no network, so it runs in CI on every push.
#
# THE ORACLE PROBLEM, and how this avoids it. Extracting the head with awk on the markers and
# comparing it against the script's own awk on the markers would test the script against itself and
# pass for any consistent pair of bugs. So the assertion here is a PARTITION: strip the four marker
# lines and the maintainer preamble from the template, and what remains must be exactly
# head + markup + tail, concatenated, byte for byte. Move a marker and it fails. Inline a line of
# CSS into the script and it fails. Edit the CSS in the template and it passes, which is correct —
# that is the one source of truth doing its job.
#
# One line per expectation, PASS or FAIL, in the same idiom as evals/checks — a test that prints
# nothing when it passes is a test nobody can tell apart from one that never ran.
#
# RUN IT UNDER dash BEFORE PUSHING: `dash tests/run.sh`. CI's /bin/sh is dash, macOS's is bash in
# POSIX mode, and they disagree about `$((cd dir && cmd) | filter)` — dash reads `$((` as
# arithmetic expansion and dies with "Missing '))'", which is a syntax error the whole file dies
# on rather than one row going red. This file shipped that once. The space in `$( (cd` is load
# bearing.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_DIR=$(dirname "$HERE")
SKELETON=${REVIEW_MAP_SKELETON:-$SKILL_DIR/scripts/page-skeleton.sh}
TEMPLATE=${REVIEW_MAP_TEMPLATE:-$SKILL_DIR/references/page-template.html}
DIFF_RENDER=${REVIEW_MAP_DIFF_RENDER:-$SKILL_DIR/scripts/diff-render.sh}

pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "PASS  $1"; }
bad() { fail=$((fail + 1)); echo "FAIL  $1"; }
assert_eq() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (got '$1', wanted '$2')"; fi; }
count() { c=$(grep -c -F -e "$2" "$1" 2>/dev/null) || c=0; printf %s "$c"; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT HUP TERM

echo "template  $TEMPLATE"
echo ""

# ---------------------------------------------------------------- the partition
# The title is passed as the placeholder itself, so the emitted head comes back with the template's
# own bytes on that line and the comparison needs no un-substitution step.
"$SKELETON" --template "$TEMPLATE" --out "$WORK/page.html" --title '{{PR_TITLE_OR_BRANCH}}' >/dev/null
"$SKELETON" --template "$TEMPLATE" --markup > "$WORK/markup"

# head and tail, taken off the emitted page by splitting on the body placeholder — one operation,
# and not the one the script used to build it.
awk '/SKELETON:BODY/ { exit } { print }' "$WORK/page.html" > "$WORK/head"
awk 'f { print } /SKELETON:BODY/ { f = 1 }' "$WORK/page.html" > "$WORK/tail"

# The template as one stream: drop everything through HEAD:START, then drop the marker lines.
sed '1,/SKELETON:HEAD:START/d' "$TEMPLATE" | grep -v 'SKELETON:' > "$WORK/expected"
cat "$WORK/head" "$WORK/markup" "$WORK/tail" > "$WORK/actual"

if cmp -s "$WORK/actual" "$WORK/expected"; then
  ok "head + markup + tail is the template, byte for byte"
else
  bad "head + markup + tail is the template, byte for byte ($(cmp "$WORK/actual" "$WORK/expected" 2>&1 | head -1))"
fi

# Stated separately because the prefix is the assertion that fails the moment someone inlines CSS
# into the script, and a reader should see that named.
if head -c "$(wc -c < "$WORK/head")" "$WORK/expected" | cmp -s - "$WORK/head"; then
  ok "the emitted head is an exact byte prefix of the template"
else
  bad "the emitted head is an exact byte prefix of the template"
fi
if tail -c "$(wc -c < "$WORK/tail")" "$WORK/expected" | cmp -s - "$WORK/tail"; then
  ok "the emitted tail is an exact byte suffix of the template"
else
  bad "the emitted tail is an exact byte suffix of the template"
fi

# ---------------------------------------------------------------- the halves are the right halves
assert_eq "$(count "$WORK/markup" '<style')"  "0" "the markup half carries no style block for a run to copy"
assert_eq "$(count "$WORK/markup" '<script')" "0" "the markup half carries no script for a run to copy"
assert_eq "$(count "$WORK/markup" '<svg')"    "0" "the markup half carries no svg — this page has no drawings"
assert_eq "$(count "$WORK/markup" 'hljs-')"   "0" "the markup half carries no tint class — the tint is applied at read time"

# ---------------------------------------------------------------- the page has one shape
# There is one page now: --full and --review stop the run before step 9, and --brief and --light
# are accepted aliases that change nothing. So the markup half is the whole page, and what these
# rows assert is that every section a run has to write is assembled in front of it.
for sec in changed attention start impact; do
  assert_eq "$(grep -c "^ *<section id=\"$sec\"" "$WORK/markup" || true)" "1" "the markup half carries <section id=\"$sec\">"
done
assert_eq "$(count "$WORK/markup" '<details class="evidence">')" "1" "the evidence foot is assembled"
assert_eq "$(count "$WORK/markup" 'class="gt gt-paths"')"        "1" "the foot carries the data-path inventory"
if grep -q 'data-path=' "$WORK/markup"; then
  ok "the inventory cells carry data-path, which is the whole interface to the coverage gate"
else
  bad "the inventory cells carry data-path, which is the whole interface to the coverage gate"
fi
assert_eq "$(grep -c 'class="eyebrow"[^>]*>Affected, not changed' "$WORK/markup" || true)" "2" "the affected label is verbatim, beside the panel and in the foot"

# THE CHECKPOINT, ASSEMBLED. Two written and one pending stub: a run copies the composition, and a
# composition described but never shown assembled does not survive a weaker reader. The pending one
# is counted too, because a half-written section 02 has to be distinguishable from a flattened one.
assert_eq "$(count "$WORK/markup" 'class="cp"')"    "3" "two checkpoints assembled whole and one pending stub"
assert_eq "$(count "$WORK/markup" 'id="cp-a"')"     "1" "the first checkpoint is anchored for the rail and the reading path"
assert_eq "$(count "$WORK/markup" 'class="lookat"')" "2" "each written checkpoint carries its own where-to-look list"
assert_eq "$(count "$WORK/markup" 'class="open"')"   "1" "the open-question line is assembled once"

# THE CHAIN, AND THE RULE THAT KEEPS IT OUT OF SECTION 04. A chain inside a checkpoint shows
# mechanism inside the change, so it holds .ip-step and never .ip-aff: a hop into unchanged code is
# an impact path and belongs in the panel, drawn once. This is the assertion that fails when the
# two figures blur into each other.
assert_eq "$(count "$WORK/markup" '<figure class="chain">')" "1" "one chain is assembled inside a checkpoint"
assert_eq "$(count "$WORK/markup" '<figure class="impact">')" "1" "one impact panel is assembled, in section 04"
if [ "$(count "$WORK/markup" 'class="ip-n ip-step"')" -ge 1 ]; then
  ok "the chain uses .ip-step, the neutral hop that exists only there"
else
  bad "the chain uses .ip-step, the neutral hop that exists only there"
fi
chain_aff=$(awk '/<figure class="chain">/ { f = 1 } f { print } /<\/figure>/ { f = 0 }' "$WORK/markup" | grep -c 'ip-aff' || true)
assert_eq "$chain_aff" "0" "no .ip-aff node inside the chain — that hop is an impact path"

# THE PARAGRAPH AND THE LOCATOR, which are the two things a node and a card carry that a diagram
# on its own does not. One p.ip-why per card and none in the chain: a checkpoint's own sentences
# already are that paragraph, and a second copy beside them is the restatement the agenda exists
# to end. The locator is in both figures, and NEVER on an outcome — a behaviour is not in a file,
# and an address on that node is the locator defect that reads as more thorough than the correct
# markup.
assert_eq "$(count "$WORK/markup" '<p class="ip-why">')" "2" "each impact card opens with its own paragraph"
why_chain=$(awk '/<figure class="chain">/ { f = 1 } f { print } /<\/figure>/ { f = 0 }' "$WORK/markup" | grep -c 'ip-why' || true)
assert_eq "$why_chain" "0" "no p.ip-why inside a checkpoint chain — the checkpoint's own sentences are that"
if [ "$(count "$WORK/markup" 'class="path ip-loc"')" -ge 6 ]; then
  ok "nodes carry their locator in both figure vocabularies"
else
  bad "nodes carry their locator in both figure vocabularies"
fi
out_loc=$(grep '<li class="ip-n ip-out"' "$WORK/markup" | grep -c 'ip-loc' || true)
assert_eq "$out_loc" "0" "no locator on an .ip-out node — a behaviour is not in a file"

# data-path IS RESERVED TO THE INVENTORY. coverage-gate.sh greps it page-wide and compares the
# result to git diff --name-only as whole strings, so a locator carrying one would register as a
# surplus path and fail the page's one mechanical gate — most reliably when quoting unchanged
# code, which is the page's best content.
panel_dp=$(awk '/<figure class="impact">/ { f = 1 } f { print } /<\/figure>/ { f = 0 }' "$WORK/markup" | grep -c 'data-path' || true)
assert_eq "$panel_dp" "0" "no data-path inside the impact panel — that attribute belongs to the inventory alone"

# THE PRIMER CALLOUT, which is the only component on this page a flag admits and therefore the
# only one whose assembled example has to say what it is gated on. It came back from the shape the
# agenda replaced, and it came back WITHOUT its artwork: the mark was an inlined logotype, this page
# has no drawings, and the trademark line went with the mark because a notice disclaims something on
# display. Both are asserted at zero, because "the primer is back" is exactly the edit that would
# bring the svg back with it.
assert_eq "$(count "$WORK/markup" '<aside class="primer">')" "1" "one primer callout is assembled"
assert_eq "$(count "$WORK/markup" 'pr-mark')" "0" "the primer carries no logotype — this page has no drawings"
assert_eq "$(count "$WORK/markup" 'pr-tm')"   "0" "and no trademark line, because there is no mark to disclaim"
assert_eq "$(count "$WORK/markup" 'primer--lib')" "0" "and no branded/unbranded variant split, which only the mark needed"

# A primer is gated on its doc link and earned by a repo citation, and BOTH live inside the aside:
# rails-anchors.rb judges it as one block, so a primer borrowing the citation of the paragraph above
# it is the rule working backwards. The link is pinned with the placeholder, never a literal series —
# a template carrying one app's version teaches it to every other, which is the defect § Pinning
# already paid for once at the citation anchor.
PRIMER=$WORK/primer
awk '/<aside class="primer">/ { f = 1 } f { print } /<\/aside>/ { f = 0 }' "$WORK/markup" > "$PRIMER"
assert_eq "$(count "$PRIMER" 'class="doc"')"  "1" "the primer carries exactly one documentation link"
assert_eq "$(count "$PRIMER" 'v{{RAILS_SERIES}}')" "1" "and it is pinned with the placeholder, not a literal series"
assert_eq "$(count "$PRIMER" 'class="path"')" "1" "the primer cites the line in this repository that earned it"
assert_eq "$(count "$PRIMER" 'class="probe"')" "0" "no probe inside a primer — the two anchors are adjacent, never nested"

# pre.demo MAY show a result line, and pre.probe may never. The whole difference is the receiver, so
# a demo outside a primer would be a general-purpose hole for output nobody observed — with the probe
# rule switched off. Counting both totals is what makes "only inside a primer" an assertion rather
# than a sentence in a comment.
assert_eq "$(count "$PRIMER" '<pre class="demo">')" "1" "the primer quotes the manual in one pre.demo"
assert_eq "$(count "$WORK/markup" '<pre class="demo">')" "1" "and no demo sits anywhere else in the markup"

# AND IT IS INSIDE A CHECKPOINT, before that checkpoint's ul.lookat. A primer in section 04 or in the
# evidence foot is a framework lesson with no judgment attached to it; one below the lookat list is a
# lesson arriving after the reader has already been sent to the code.
cp_region=$(awk '/<section class="cp" id="cp-a">/ { f = 1 } f { print } /<ul class="lookat">/ { if (f) exit }' "$WORK/markup" | grep -c 'class="primer"' || true)
assert_eq "$cp_region" "1" "the primer sits inside a checkpoint and above its Look at list"

# AND THE COMPONENTS THE AGENDA PUT DOWN STAY DOWN. Each of these was a required part of the page
# this one replaced, so each is a thing a run with the old shape in mind would reach for. The primer
# left this list when --mentor brought it back; every other one is still down, and the seven-field
# unit is the one that would arrive looking most like thoroughness.
for gone in 'class="mech"' 'class="rows"' 'class="pipe"' 'class="checkpoint"' \
            'class="decisions"' 'class="inflow"' 'class="usecases"' 'gt-ledger' 'coverage-foot'; do
  assert_eq "$(count "$WORK/markup" "$gone")" "0" "the markup half has no $gone"
done

# The rail is assembled, never derived. Four numbered entries and one sub-entry per checkpoint.
assert_eq "$(count "$WORK/markup" 'class="rail-links"')" "1" "exactly one rail"
assert_eq "$(count "$WORK/markup" 'data-rail=')" "7" "the rail is four entries and three checkpoint sub-entries"
assert_eq "$(count "$WORK/markup" '04</span>')"  "1" "the rail numbers up to 04"
assert_eq "$(count "$WORK/markup" '05</span>')"  "0" "and stops there"

# AND THE ENTRY'S HANGING INDENT STOPS AT THE ENTRY. text-indent inherits and an inline-flex box
# lays out its own line, so .rail-links a's -24px reached inside the pending chip and pulled the
# word 24px left of its own border — over the title on one line, off the box on a wrapped one.
# .n carried the reset from the start and .pending did not, and a published page showed it.
# Read out of the rule itself, the way the tints are counted by name: a reset somewhere in the
# head is not the same as THIS rule carrying one.
assert_eq "$(awk '/^\.pending \{/,/^}/' "$WORK/head" | grep -c 'text-indent: 0')" "1" \
  "the pending chip resets the rail entry's hanging indent"

# AND A READING-PATH STOP SPANS ITS EXCERPT. report-format.md § Source excerpts permits an excerpt
# on a § 03 stop, and .begin li is a three-column grid, so a details with no span auto-places into
# the 26px number column — where .ex-loc's overflow-wrap: anywhere renders the path one character
# per line, hundreds of pixels down. A published page did exactly that. Both halves are asserted:
# the rule has to be in the emitted head AND the composition has to be shown assembled, because
# either one alone is what produced the defect.
assert_eq "$(awk '/^\.begin li > \.excerpt \{/,/}/' "$WORK/head" | grep -c 'grid-column: 2 / -1')" "1" \
  "a stop's excerpt is spanned out of the 26px number column"
assert_eq "$(awk '/^\.begin li > \.excerpt \{/,/}/' "$WORK/head" | grep -c 'min-width: 0')" "1" \
  "and shrinks below its pre's width, so the quotation scrolls instead of the page"

# THE SEARCH ROW'S HANGING INDENT, which is .pending's defect in another component: a rule about a
# row's FIRST child written as a descendant rule. The -16px then reaches a code inside the clause
# and pulls it over the words before it. Both halves are read out of the rules themselves — the
# scoped rule has to carry the pull, and the rule that styles every code has to NOT carry it,
# because a template with both would render exactly the overlap.
assert_eq "$(awk '/^\.searched \.sr-list > li > code:first-child \{/,/}/' "$WORK/head" | grep -c 'margin-left: -16px')" "1" \
  "only a search row's leading command hangs into the indent"
assert_eq "$(awk '/^\.searched \.sr-list code \{/,/}/' "$WORK/head" | grep -c 'margin-left')" "0" \
  "and the rule that styles every code in a row does not pull any of them left"

# THE INVENTORY'S ODD LAST CELL. .gt paints its gaps by showing --rule through a 1px grid gap,
# which needs every row full; an odd number of paths leaves the container's own rule colour
# rendering as a filled slab where the missing cell would be. The common case, and invisible in
# any example with an even number of paths.
assert_eq "$(awk '/^\.gt-paths > \.c:last-child:nth-child\(odd\) \{/,/}/' "$WORK/head" | grep -c 'grid-column: 1 / -1')" "1" \
  "an odd final inventory cell spans its row instead of leaving a rule-coloured slab"

# AND THE ASSEMBLED FOOT HAS TO EXERCISE BOTH. Neither rule is reachable from an example with an
# even number of cells and no code inside a clause — which is what the template had while both
# defects shipped.
# Counted by data-path rather than by an awk range over the grid: the attribute is RESERVED to
# inventory cells — coverage-gate.sh greps it page-wide — so it selects exactly those and nothing
# else. The masthead's five .c cells carry none, which is why counting .c would have been wrong.
inv_cells=$(count "$WORK/markup" '<div class="c" data-path=')
if [ "$((inv_cells % 2))" -eq 1 ]; then
  ok "the assembled inventory has an odd number of cells, so the odd-cell rule is exercised"
else
  bad "the assembled inventory has an odd number of cells, so the odd-cell rule is exercised"
fi
assert_eq "$(grep -c 'class="sr-r">[^<]*<code>' "$WORK/markup")" "1" \
  "a search row's clause carries an inline code, so the indent's scope is exercised"
begin_ex=$(awk '/<ol class="begin">/ { f = 1 } f { print } /<\/ol>/ { f = 0 }' "$WORK/markup" \
  | grep -c 'details class="excerpt excerpt--source"' || true)
assert_eq "$begin_ex" "1" "a reading-path stop is assembled carrying its excerpt"

# ---------------------------------------------------------------- markers
for m in SKELETON:HEAD:START SKELETON:HEAD:END SKELETON:TAIL:START SKELETON:TAIL:END; do
  assert_eq "$(count "$TEMPLATE" "$m")" "1" "template has exactly one $m"
done
assert_eq "$(count "$WORK/markup" 'SKELETON:')" "0" "no marker survives into the markup half"

assert_eq "$(count "$WORK/head" 'SKELETON:')" "0" "no marker survives into the emitted head"
assert_eq "$(count "$WORK/tail" 'SKELETON:')" "0" "no marker survives into the emitted tail"
assert_eq "$(count "$WORK/page.html" 'SKELETON:BODY')" "1" "the emitted page carries one body placeholder for the run to replace"

# ---------------------------------------------------------------- every colour is in the skeleton
# Counted by name, the way page-invariants.rb §6 and excerpts.rb count them: the three theme blocks
# EXISTING is not the same as a colour being declared in all three, and the tints are the tokens
# nothing on the page needs in order to be readable, so a missing one is invisible until someone
# opens an excerpt with the OS in dark mode.
assert_eq "$(count "$WORK/head" '--syn-key:')"              "3" "--syn-key is declared in all three theme states, in the skeleton"
assert_eq "$(count "$WORK/head" '--ex-add:')"               "3" "--ex-add is declared in all three theme states, in the skeleton"
assert_eq "$(count "$WORK/head" 'prefers-color-scheme: dark')" "1" "the media dark block is in the skeleton"
assert_eq "$(count "$WORK/head" '[data-theme="dark"]')"     "2" "the explicit dark block is in the skeleton"
assert_eq "$(count "$WORK/head" '[data-theme="light"]')"    "1" "the explicit light block is in the skeleton"
assert_eq "$(count "$WORK/markup" '--syn-key:')"            "0" "no colour is left in the half a model reads"

# ---------------------------------------------------------------- the tint's three grammars
# template says "carry all three lines"; this is that sentence as a test. A language added to
# excerpt.sh's guess_lang without its grammar here tints nothing, silently.
assert_eq "$(count "$WORK/tail" '<script src=')" "3" "highlight.js and both extra grammars are in the skeleton"
for g in 'highlight.min.js' 'languages/erb.min.js' 'languages/elixir.min.js'; do
  assert_eq "$(count "$WORK/tail" "$g")" "1" "the skeleton loads $g"
done

# ---------------------------------------------------------------- links open in a new tab
# Applied by the tail script, never typed at a citation — so the assertion is a pair: the rule is
# in the half nobody reads, and the half a run copies from carries no target for it to imitate.
# A page has dozens of citations and an attribute typed dozens of times is one missing from a
# citation nobody checks, which is the defect this split exists to make unreachable.
assert_eq "$(count "$WORK/tail" "'target', '_blank'")"           "1" "the skeleton's script opens off-page links in a new tab"
assert_eq "$(count "$WORK/tail" "'rel', 'noopener noreferrer'")" "1" "it sets rel with target, so the opened page gets no window.opener handle"
assert_eq "$(count "$WORK/markup" 'target=')"                    "0" "no citation in the markup half types a target for a run to copy"

# The other half of the same rule, and the one that is silently wrong rather than loudly: the rail
# and the Checkpoint pointers are this page pointing at itself, and a new tab there is the reader's
# place lost with a second window on top of it. The guard is a comparison against the current
# document, so a component added later is covered without anyone editing the block.
assert_eq "$(count "$WORK/tail" 'if (there === here) { return; }')" "1" "a link to this same page is left in this tab"

# ---------------------------------------------------------------- the title
"$SKELETON" --template "$TEMPLATE" --out "$WORK/t.html" --title 'Fix A & B <thing>' >/dev/null
if grep -Fq '<title>Fix A &amp; B &lt;thing&gt; Review</title>' "$WORK/t.html"; then
  ok "the title is HTML-escaped by the script, so an & in a PR title is not a defect"
else
  bad "the title is HTML-escaped by the script, so an & in a PR title is not a defect"
fi
assert_eq "$(count "$WORK/t.html" '{{PR_TITLE_OR_BRANCH}}')" "0" "the title placeholder is substituted"

# ---------------------------------------------------------------- idempotency, and the refusal
cp "$WORK/t.html" "$WORK/t.first"
"$SKELETON" --template "$TEMPLATE" --out "$WORK/t.html" --title 'Fix A & B <thing>' >/dev/null
if cmp -s "$WORK/t.first" "$WORK/t.html"; then
  ok "running it twice over an untouched skeleton is byte-identical"
else
  bad "running it twice over an untouched skeleton is byte-identical"
fi

sed 's|.*SKELETON:BODY.*|  <main>a section somebody is already reading</main>|' "$WORK/t.html" > "$WORK/written.html"
cp "$WORK/written.html" "$WORK/written.before"
rc=0; "$SKELETON" --template "$TEMPLATE" --out "$WORK/written.html" --title 'x' >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "3" "it refuses to overwrite a page that has content in it, and exits 3"
if cmp -s "$WORK/written.before" "$WORK/written.html"; then
  ok "the refused page is left byte-unchanged"
else
  bad "the refused page is left byte-unchanged"
fi
rc=0; "$SKELETON" --template "$TEMPLATE" --out "$WORK/written.html" --title 'x' --force >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "0" "--force is the way past the refusal"

# ---------------------------------------------------------------- required arguments
rc=0; "$SKELETON" --template "$TEMPLATE" --out "$WORK/n.html" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "2" "a missing --title is refused rather than written as a placeholder"
rc=0; "$SKELETON" --template "$TEMPLATE" --title 'x' >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "2" "a missing --out is refused"

# ================================================================ diff-render.sh
# The verdict here decides whether a citation gets a diff anchor or a blob permalink
# (report-format.md § When the diff will not render), and being wrong is invisible on the page:
# an anchor into a file GitHub keeps behind "Load diff" lands on a stub, and the reader sees a
# link that worked. So every signal gets a row, on a repository built here rather than on a
# fixture, because the answer is a function of git's own attribute resolution and numstat.
echo ""
echo "diff-render  $DIFF_RENDER"
echo ""

REPO=$WORK/repo
mkdir -p "$REPO/app" "$REPO/db" "$REPO/assets"
(
  cd "$REPO"
  git init -q .
  git config user.email test@example.com
  git config user.name test
  # .gitattributes is the signal git resolves for us — nested files and precedence included,
  # which is why the script asks check-attr instead of grepping for the pattern.
  printf 'db/structure.sql linguist-generated=true\nassets/*.min.js -diff\n' > .gitattributes
  echo one > app/order.rb
  seq 1 100 > app/big.rb
  # 700 lines that will be edited every 14th, far enough apart that no two hunks merge.
  seq 1 700 > app/scattered.rb
  # One contiguous block, sized so its rendered diff lands one line under the threshold.
  seq 1 500 > app/boundary.rb
  seq 1 30000 > db/structure.sql
  echo 'v=1' > assets/app.min.js
  printf '\000\001\000' > app/logo.png
  echo '{"lockfileVersion":3}' > package-lock.json
  git add -A
  git commit -qm base
  git rev-parse HEAD > "$WORK/base"
  # One changed line in a generated file, a change over the auto-load threshold, a change over
  # the hard cap, a binary, a -diff path, a one-line lockfile edit, and one ordinary small file.
  echo two >> app/order.rb
  seq 1 700 > app/big.rb
  # 50 isolated one-line edits: 100 changed lines, but 50 hunks each costing a header and six
  # context lines, so the diff GitHub renders is ~450 lines. add+del would call this renderable.
  awk 'NR % 14 == 7 { print "scattered"; next } { print }' app/scattered.rb > app/scattered.new
  mv app/scattered.new app/scattered.rb
  # 196 lines replaced in one hunk: 1 header + 3 context + 196 + 196 + 3 context = 399 rendered.
  awk 'NR >= 100 && NR < 296 { print "boundary"; next } { print }' app/boundary.rb > app/boundary.new
  mv app/boundary.new app/boundary.rb
  seq 1 60000 > db/structure.sql
  echo 'v=2' > assets/app.min.js
  printf '\000\002\000' > app/logo.png
  echo '{"lockfileVersion":4}' > package-lock.json
  git add -A
  git commit -qm head
) >/dev/null 2>&1
BASE=$(cat "$WORK/base")

verdict() { (cd "$REPO" && "$DIFF_RENDER" "$BASE" HEAD) | awk -v p="$1" '$3 == p { print $1 "/" $2 }'; }

assert_eq "$(verdict app/order.rb)"      "render/-"                "an ordinary small change renders, so its citation keeps the diff anchor"
assert_eq "$(verdict app/big.rb)"        "collapse/over-autoload"  "a diff past 400 lines is behind Load diff, whatever the file is"
# The row the changed-line measure could not see. Its add+del is 100; the diff GitHub renders is
# ~450 lines, because context and hunk headers are most of a scattered diff. Measured on real
# pull requests 2026-09-17: discourse#43002 reports.gjs collapsed at 342 changed / 414 rendered,
# while discourse#43772 core_primitives.rb rendered at 349 changed / 394 — 349 rendering while
# 342 collapses is what rules out counting the changed lines.
assert_eq "$(verdict app/scattered.rb)"  "collapse/over-autoload"  "context pushes a diff past 400 rendered lines though its changed lines are far fewer"
# And the other side of the same boundary, because counting more lines can only ever collapse
# more files: a diff of 399 rendered lines must still get its anchor. Without this row the fix
# above could be widened into over-collapsing and nothing would notice — and the anchor is what
# the reviewer wants when it works, which is why the verdict leans towards it.
assert_eq "$(verdict app/boundary.rb)"   "render/-"                "a diff one line under the threshold keeps its anchor"
assert_eq "$(verdict db/structure.sql)"  "collapse/generated"      "linguist-generated collapses on one changed line, where no size rule would fire"
assert_eq "$(verdict assets/app.min.js)" "collapse/no-diff"        "a -diff path is reported as an attribute, not as a coincidence of its bytes"
assert_eq "$(verdict app/logo.png)"      "collapse/binary"         "a binary file has no line to anchor to"
assert_eq "$(verdict package-lock.json)" "collapse/lockfile"       "a lockfile collapses as generated even when its diff is one line"

# The hard cap is a different sentence on the page from the auto-load threshold — past it Load
# diff does not fully help either — so the reason has to survive, not just the verdict.
# On its own branch, and checked out BACK afterwards: leaving the repository on that branch
# redefines HEAD for every row below, and the first version of this file did exactly that —
# three rows then ran against a two-file diff, one of them passing by matching only the verdict
# of a `not-in-diff` answer.
(
  cd "$REPO"
  was=$(git rev-parse --abbrev-ref HEAD)
  git checkout -q -b hardcap "$BASE"
  seq 1 30000 > db/big.txt
  git add -A
  git commit -qm hardcap
  git checkout -q "$was"
) >/dev/null 2>&1
assert_eq "$( (cd "$REPO" && "$DIFF_RENDER" "$BASE" hardcap) | awk '$3 == "db/big.txt" { print $2 }')" \
  "over-hard-cap" "a diff past 20,000 lines is reported as over the hard cap, not merely un-auto-loaded"

# --path is what a run asks while writing one citation, and a path outside the diff has to come
# back renderable rather than collapse: an *affected but unchanged* citation is a blob link
# already, and the commonest citation on the page must not be answered with a guess.
assert_eq "$( (cd "$REPO" && "$DIFF_RENDER" "$BASE" HEAD --path app/order.rb) | awk '{ print $1 "/" $2 }')" \
  "render/-" "--path answers about one file"
assert_eq "$( (cd "$REPO" && "$DIFF_RENDER" "$BASE" HEAD --path app/untouched.rb) | awk '{ print $1 "/" $2 }')" \
  "render/not-in-diff" "a path the diff never touched is not reported as collapsed"

collapsed=$( (cd "$REPO" && "$DIFF_RENDER" "$BASE" HEAD --collapsed-only) | grep -c '^collapse' || true)
assert_eq "$collapsed" "6" "--collapsed-only lists every collapsed path and no renderable one"
assert_eq "$( (cd "$REPO" && "$DIFF_RENDER" "$BASE" HEAD --collapsed-only) | grep -c '^render' || true)" \
  "0" "--collapsed-only emits no render rows"

# The whole-diff caps are the two facts no per-path verdict can carry, so they are stated once.
if (cd "$REPO" && "$DIFF_RENDER" "$BASE" HEAD) | grep -q 'file(s),.*bytes of diff'; then
  ok "the trailing summary states the file count and the diff size"
else
  bad "the trailing summary states the file count and the diff size"
fi

rc=0; (cd "$REPO" && "$DIFF_RENDER" >/dev/null 2>&1) || rc=$?
assert_eq "$rc" "2" "a missing BASE is refused rather than diffed against nothing"

# Asked and unable to answer is not an empty diff. Every git call here feeds a pipeline, so a
# failing one leaves the exit status at 0 and prints no rows — which reads as "no file is
# withheld", the most reassuring output this script has and the one with the least behind it.
# evals/checks/excerpts.rb's state-tag rule shipped with exactly this bug.
rc=0; out=$( (cd "$REPO" && "$DIFF_RENDER" 0000000000000000000000000000000000000000 HEAD) 2>/dev/null ) || rc=$?
assert_eq "$rc" "4" "an unresolvable BASE exits 4 rather than reporting an empty diff"
assert_eq "$(printf '%s' "$out" | grep -c . || true)" "0" "and prints nothing that could be read as a verdict"

echo ""
echo "run.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
