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

echo ""
echo "self-test: $ok ok, $bad bad"
[ "$bad" -eq 0 ]
