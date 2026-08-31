#!/bin/sh
# check.sh — the mechanical half of an eval, dispatched.
#
#   Page, the whole thing:
#     check.sh --page page.html --repo DIR --base REF [--head REF]
#              [--draft | --final | --stopped] [--expect S]... [--forbid S]...
#
#   One section, produced by a driver in drivers/ from the frozen upstream:
#     check.sh --fragment behaviour-flows.html --scope behaviour-flows
#
#   Just the diagrams, optionally rendered to PNGs for a person to look at:
#     check.sh --page page.html --scope diagram [--visual]
#
#   A page or fragment produced at the skill's brief detail level, where sections 4 to 7
#   are one merged section (report-format.md § Detail levels):
#     check.sh --page page.html --repo DIR --base REF --level brief
#
# --level defaults to `full`. It is a third axis, separate from build state and from the
# section slug, and only one check reads it: before-approving.sh, because a missing
# comprehension checkpoint is correct at brief and a WARN at full. Everything else keeps
# working across the merge because the merged section keeps the section anchors the region
# extractors read — see report-format.md § Section 4 at brief.
#
# Three grading scopes, and the difference matters. A PAGE carries invariants no fragment
# can: completeness, one canonical home, the excerpt budget, the build state. A FRAGMENT is
# one section, graded on its own so a wording change in one part of report-format.md can be
# measured without paying for a whole run. A section that passes therefore says nothing
# about whether the page repeats itself — that is the page's job, and README.md says so.
#
# Each check lives in checks/ and prints PASS / FAIL / WARN / SKIP lines. This script only
# decides which ones apply and adds up what they printed. Exit code follows the FAILs.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CHECKS_DIR=$HERE/checks
. "$CHECKS_DIR/lib.sh"

parse_args "$@"
require_input

if [ -z "$SCOPE" ]; then
  if [ "$IN_KIND" = page ]; then
    SCOPE=all
  else
    echo "a fragment needs --scope: behaviour-flows | start-here | blast-radius | before-approving | diagram" >&2
    exit 2
  fi
fi

case $SCOPE in
  all)              RUN="completeness build-state page-invariants excerpts behaviour-flows start-here blast-radius before-approving searches rails-anchors diagram" ;;
  core)             RUN="completeness build-state page-invariants excerpts before-approving rails-anchors" ;;
  behaviour-flows)  RUN="page-invariants excerpts behaviour-flows searches rails-anchors diagram" ;;
  start-here)       RUN="page-invariants start-here" ;;
  blast-radius)     RUN="page-invariants excerpts blast-radius searches rails-anchors diagram" ;;
  before-approving) RUN="page-invariants before-approving rails-anchors" ;;
  diagram)          RUN="diagram" ;;
  *) echo "unknown scope: $SCOPE" >&2; exit 2 ;;
esac
[ "$VISUAL" = 1 ] && RUN="$RUN diagram-shot"

# Rebuild the child argument list from what was parsed, so every child sees the same input
# and nobody re-parses the command line.
set -- "--${IN_KIND}" "$IN"
[ -n "$REPO" ] && set -- "$@" --repo "$REPO"
[ -n "$BASE" ] && set -- "$@" --base "$BASE"
set -- "$@" --head "$HEAD_REF" "--$MODE" --level "$LEVEL"
[ -n "$OUTDIR" ] && set -- "$@" --out "$OUTDIR"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

for c in $RUN; do
  CHECK_TALLY=0 "$CHECKS_DIR/$c.sh" "$@" >> "$TMP/out" 2>&1 || rc=$?
  : "${rc:=0}"
  if [ "$rc" -eq 2 ]; then
    echo "FAIL  $c.sh was called wrongly — see the usage above" >> "$TMP/out"
  fi
  rc=0
done

# Case-specific: the planted findings, and whatever this case forbids. These stay here
# rather than in a check script because they are the one part that differs per case.
echo "$EXPECTS" | while IFS= read -r e; do
  [ -z "$e" ] && continue
  if grep -Fq "$e" "$IN"; then echo "PASS  mentions: $e"; else echo "FAIL  never mentions: $e"; fi
done >> "$TMP/out"
echo "$FORBIDS" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  if grep -Fq "$f" "$IN"; then echo "FAIL  should not contain: $f"; else echo "PASS  absent, as required: $f"; fi
done >> "$TMP/out"

cat "$TMP/out"

pass=$(grep -c '^PASS' "$TMP/out" || true)
fail=$(grep -c '^FAIL' "$TMP/out" || true)
warn=$(grep -c '^WARN' "$TMP/out" || true)
skipped=$(grep -c '^SKIP' "$TMP/out" || true)

echo
if [ "$IN_KIND" = page ]; then
  echo "$SCOPE / $MODE / $LEVEL: $pass passed, $fail failed, $warn warning(s), $skipped skipped"
else
  echo "$SCOPE fragment / $LEVEL: $pass passed, $fail failed, $warn warning(s), $skipped skipped"
fi
[ "$fail" -eq 0 ]
