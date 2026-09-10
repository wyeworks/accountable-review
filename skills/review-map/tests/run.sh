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
if grep -q 'class="mech"' "$WORK/markup" && grep -q 'id="flow-a"' "$WORK/markup"; then
  ok "the markup half still carries the assembled flow a run reads"
else
  bad "the markup half still carries the assembled flow a run reads"
fi

# ---------------------------------------------------------------- the level filter
# Sections 4 to 7 and the merged brief section are two renderings of the same tail, and so is
# the rail below 03. --level hands a run one of each instead of both. Bare --markup is still
# every byte -- the partition above is that assertion, and it is why these rows can be about
# the filter alone.
"$SKELETON" --template "$TEMPLATE" --markup --level brief > "$WORK/brief"
"$SKELETON" --template "$TEMPLATE" --markup --level full  > "$WORK/full"

# SUBTRACTIVE BY CONSTRUCTION, stated as "no line was added". Comparing against a second
# extraction would test the script against its own awk, which is the oracle problem this file
# opens with; "the filter cannot invent a line" needs no oracle.
for lvl in brief full; do
  added=$(diff "$WORK/markup" "$WORK/$lvl" | grep -c '^>' || true)
  assert_eq "$added" "0" "--level $lvl removes lines and never adds one"
done

# The carriers, one per level. THE COMPLETENESS INVARIANT HAS NO LEVEL -- every path in the diff
# appears in the page at both -- so what a level changes is only which carrier holds them, and a
# level that dropped both would produce a page that may have lost a file.
assert_eq "$(count "$WORK/brief" 'class="coverage-foot"')" "1" "--level brief keeps the collapsed coverage foot"
assert_eq "$(count "$WORK/brief" 'class="gt gt-paths"')"   "1" "--level brief keeps the foot's data-path carrier"
assert_eq "$(count "$WORK/full"  'class="coverage-foot"')" "0" "--level full drops the coverage foot"
assert_eq "$(count "$WORK/full"  'gt-paths')"              "0" "--level full drops the foot's carrier"
assert_eq "$(count "$WORK/full"  'class="gt gt-ledger"')"  "1" "--level full keeps section 7's classified ledger"
assert_eq "$(count "$WORK/brief" 'gt-ledger')"             "0" "--level brief drops the classified ledger"

# The four --full section shells, and their absence at --brief. ANCHORED AT LINE START on
# purpose: the brief tail's own comment names the sections it must not contain, so a rule that
# matched anywhere on the line would read that disclaimer as the defect it warns about.
for sec in crosscutting approving coverage; do
  assert_eq "$(grep -c "^ *<section id=\"$sec\"" "$WORK/full"  || true)" "1" "--level full keeps <section id=\"$sec\">"
  assert_eq "$(grep -c "^ *<section id=\"$sec\"" "$WORK/brief" || true)" "0" "--level brief has no <section id=\"$sec\">"
done
assert_eq "$(count "$WORK/full" 'class="checkpoint"')" "1" "--level full keeps the comprehension checkpoint"
assert_eq "$(count "$WORK/brief" 'class="checkpoint"')" "0" "--level brief drops the checkpoint"

# The two components inside a FLOW that the brief level drops, per report-format.md § The brief
# budget. They are gated for the reason the rail is: a comment telling a run to delete a block at
# one level is a deletion done from prose with nothing checking it.
#
# Section 1 keeps its own pair at both levels, which is what makes the brief count 1 rather than 0
# -- the level moves the page's transition block into one place, it does not remove it. A rule
# asserting 0 here would pass on a page that had lost the before/after entirely.
assert_eq "$(count "$WORK/full"  'class="ba"')" "3" "--level full keeps section 1's before/after pair and both flows' own"
assert_eq "$(count "$WORK/brief" 'class="ba"')" "1" "--level brief keeps section 1's before/after pair and neither flow's"
assert_eq "$(count "$WORK/full"  'class="primer')" "2" "--level full keeps both primer variants"
assert_eq "$(count "$WORK/brief" 'class="primer')" "0" "--level brief drops the primer callout"

# AND THE FLOW ITSELF IS UNTOUCHED BY EITHER, which is the half worth asserting: the budget caps
# prose and removes no figure, so both assembled flows keep their .mech, their unit grid and every
# .pipe spine at both levels. A filter that took a flow's drawing with the primer would satisfy
# every rule above.
for lvl in brief full; do
  assert_eq "$(count "$WORK/$lvl" 'class="mech"')" "2" "--level $lvl keeps both assembled flows' .mech"
  assert_eq "$(count "$WORK/$lvl" 'class="pipe"')" "3" "--level $lvl keeps every .pipe spine"
  assert_eq "$(count "$WORK/$lvl" '<figure class="inflow">')" "2" "--level $lvl keeps both flow drawings"
done

# THE MERGED SECTION KEEPS THE ANCHORS. This is markup, so it breaks by accident and reads as
# verified when broken -- before-approving.rb prints a SKIP with the anchor gone.
assert_eq "$(grep -c '^ *<section id="reach"' "$WORK/brief" || true)" "1" "--level brief keeps exactly one <section id=\"reach\">"
assert_eq "$(grep -c '^ *<section id="reach"' "$WORK/full"  || true)" "1" "--level full keeps exactly one <section id=\"reach\">"
assert_eq "$(count "$WORK/brief" 'class="cc-h" id="crosscutting"')" "1" "--level brief keeps the crosscutting part as an h3"
assert_eq "$(count "$WORK/brief" 'class="cc-h" id="approving"')"    "1" "--level brief keeps the approving part as an h3"

# The rail is ASSEMBLED at both shapes, never derived. It used to ship in the seven-entry --full
# form with a comment telling a --brief run to cut it to four and renumber, which is a
# transformation performed from prose that nothing ever checked.
assert_eq "$(count "$WORK/brief" 'class="rail-links"')" "1" "--level brief has exactly one rail"
assert_eq "$(count "$WORK/full"  'class="rail-links"')" "1" "--level full has exactly one rail"
assert_eq "$(count "$WORK/brief" 'data-rail=')" "6" "the brief rail is four entries and two flow sub-entries"
assert_eq "$(count "$WORK/full"  'data-rail=')" "9" "the full rail is seven entries and two flow sub-entries"
assert_eq "$(count "$WORK/brief" '07</span>')"  "0" "the brief rail stops at 04"

# LEVEL-INDEPENDENT MATERIAL SURVIVES BOTH. Sections 1 to 3 are byte-for-byte the same spec at
# either level, and section 4's two standing rules sit above the rail for exactly this reason: a
# rule true at both levels must not live inside a region one of them drops.
for f in markup brief full; do
  case $f in markup) lvl="bare --markup" ;; *) lvl="--level $f" ;; esac
  for frag in 'class="mech"' 'id="flow-a"' 'figure class="impact"' "SECTION 4'S TWO STANDING RULES"; do
    if grep -q -F -e "$frag" "$WORK/$f"; then
      ok "$frag survives $lvl"
    else
      bad "$frag is missing from $lvl"
    fi
  done
done

# A canary for a region that lost its markers: the drop is large, and a silent un-marking would
# show up here long before anyone noticed a section missing from a page.
bare_b=$(wc -c < "$WORK/markup"); brief_b=$(wc -c < "$WORK/brief"); full_b=$(wc -c < "$WORK/full")
if [ "$((bare_b - brief_b))" -ge 14000 ]; then
  ok "--level brief drops at least 14 KB of markup a brief run cannot write"
else
  bad "--level brief drops at least 14 KB (dropped $((bare_b - brief_b)))"
fi
if [ "$((bare_b - full_b))" -ge 9000 ]; then
  ok "--level full drops at least 9 KB of markup a full run cannot write"
else
  bad "--level full drops at least 9 KB (dropped $((bare_b - full_b)))"
fi

# ---------------------------------------------------------------- the level refusals
# Fail closed. Each of these would otherwise be a flag that quietly did nothing.
"$SKELETON" --template "$TEMPLATE" --markup --level bogus >/dev/null 2>&1 || st=$?
assert_eq "${st:-0}" "2" "--level takes brief or full, and refuses anything else"
st=0
"$SKELETON" --template "$TEMPLATE" --out "$WORK/lv.html" --title T --level brief >/dev/null 2>&1 || st=$?
assert_eq "${st:-0}" "2" "--level with --out is refused, because the emitted halves carry no section"
st=0

# ---------------------------------------------------------------- markers
for m in SKELETON:HEAD:START SKELETON:HEAD:END SKELETON:TAIL:START SKELETON:TAIL:END; do
  assert_eq "$(count "$TEMPLATE" "$m")" "1" "template has exactly one $m"
done
for f in markup brief full; do
  assert_eq "$(count "$WORK/$f" 'SKELETON:')" "0" "no marker survives into the markup half ($f)"
done
assert_eq "$(count "$WORK/head" 'SKELETON:')" "0" "no marker survives into the emitted head"
assert_eq "$(count "$WORK/tail" 'SKELETON:')" "0" "no marker survives into the emitted tail"
assert_eq "$(count "$WORK/page.html" 'SKELETON:BODY')" "1" "the emitted page carries one body placeholder for the run to replace"

# ---------------------------------------------------------------- every colour is in the skeleton
# Counted by name, the way page-invariants.rb §6 and excerpts.rb count them: the three theme blocks
# EXISTING is not the same as a colour being declared in all three, and these are the two tokens
# nothing on the page needs in order to be readable, so a missing one is invisible until someone
# opens a primer or an excerpt with the OS in dark mode.
assert_eq "$(count "$WORK/head" '--rails:')"                "3" "--rails is declared in all three theme states, in the skeleton"
assert_eq "$(count "$WORK/head" '--syn-key:')"              "3" "--syn-key is declared in all three theme states, in the skeleton"
assert_eq "$(count "$WORK/head" 'prefers-color-scheme: dark')" "1" "the media dark block is in the skeleton"
assert_eq "$(count "$WORK/head" '[data-theme="dark"]')"     "2" "the explicit dark block is in the skeleton"
assert_eq "$(count "$WORK/head" '[data-theme="light"]')"    "1" "the explicit light block is in the skeleton"
assert_eq "$(count "$WORK/markup" '--rails:')"              "0" "no colour is left in the half a model reads"

# ---------------------------------------------------------------- the tint's three grammars
# template says "carry all three lines"; this is that sentence as a test. A language added to
# excerpt.sh's guess_lang without its grammar here tints nothing, silently.
assert_eq "$(count "$WORK/tail" '<script src=')" "3" "highlight.js and both extra grammars are in the skeleton"
for g in 'highlight.min.js' 'languages/erb.min.js' 'languages/elixir.min.js'; do
  assert_eq "$(count "$WORK/tail" "$g")" "1" "the skeleton loads $g"
done

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
assert_eq "$collapsed" "5" "--collapsed-only lists every collapsed path and no renderable one"
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
