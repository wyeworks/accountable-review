#!/bin/sh
# map-still-current.sh — does the Review Map we already have still describe this head?
#
#   Usage: map-still-current.sh --dir <restored map dir> --head <sha>
#                               [--repo-dir <dir>] [--config <file>] [--plugin-dir <dir>]
#          (run from anywhere; --repo-dir is the checkout)
#
# With --regenerate-on-push a pull request gets a Review Map per push, and most pushes late in a
# review change nothing the map says: a README line, a changelog entry, a rubocop fix. The scope
# gate cannot see that, because it asks its question over BASE...HEAD — the whole pull request
# contains application code, so it answers `generate` for a push that changed a paragraph. The
# result is a model run whose page says what the last page said.
#
# So the question is asked a second time, over the commits since the map we already have, and this
# is where. It adds NO RULE OF ITS OWN: it composes two scripts that exist, and every answer it
# gives is one of theirs.
#
# WHAT IT DOES NOT DO IS REWRITE THE PAGE. A docs-only push changes the diff's file count and its
# inventory, not just the head SHA, so refreshing the masthead means a script editing model-authored
# HTML — the metric cells, the foot's `all N changed paths`, the inventory block — where a pattern
# that misses leaves a stale number on a page that still looks current. That is the one failure this
# product cannot tolerate, and it would be bought with a cosmetic gain. The map stands at the
# revision it names, which is honest: the application code at that revision is the application code
# now, and the reader can check the two SHAs against each other.
#
# THE TWO HALVES, AND WHY THE SECOND ONE IS NOT BELT AND BRACES:
#
#   1. ci/application-code.sh over <previous head>..<head>. Exit 3 — no application code, or
#      trivially little — is the first half.
#
#   2. carry-plan.sh over the restored page, same range: exit 0 with no `redo` and no `regen` row,
#      which is "the delta touched nothing this page cites and nothing it quotes".
#
# The first half alone has a hole, and it is a live one: application-code.sh classifies tests as not
# application code, so a test-only push satisfies it — while a checkpoint citing
# spec/models/project_spec.rb:12 may now point at a moved line, and a reader following that citation
# lands somewhere else. The second half closes that by composition rather than by a new rule. It
# also catches a case the first half waves through for a different reason: a lock file bump is not
# application code and it re-pins every documentation link on the page, so carry-plan's P7 refuses
# and the run regenerates.
#
# POLARITY, as everywhere in this design: SKIPPING IS THE HARD-TO-SATISFY PREDICATE. Both halves
# must say yes. A needless model run costs minutes nobody watches; a map that has quietly stopped
# describing the head is the failure a reader cannot detect from the inside.
#
# Exits 0 the existing map still describes this head (skip generation), 3 regenerate, 2 called
# wrongly. application-code.sh's convention: a skip is a decision rather than a failure.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=$(dirname "$HERE")

DIR=; HEAD_SHA=; REPO_DIR=.; CONFIG=; PLUGIN_DIR=

while [ $# -gt 0 ]; do
  case $1 in
    --dir)        DIR=$2;        shift 2 ;;
    --head)       HEAD_SHA=$2;   shift 2 ;;
    --repo-dir)   REPO_DIR=$2;   shift 2 ;;
    --config)     CONFIG=$2;     shift 2 ;;
    --plugin-dir) PLUGIN_DIR=$2; shift 2 ;;
    -h|--help)    sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "map-still-current.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$PLUGIN_DIR" ] || PLUGIN_DIR=$PLUGIN_ROOT

if [ -z "$DIR" ] || [ -z "$HEAD_SHA" ]; then
  echo "usage: map-still-current.sh --dir <dir> --head <sha> [--repo-dir <dir>]" >&2
  exit 2
fi

# Every way of not knowing leads to the same answer, and it is the expensive one. A cold cache, a
# first run, a manifest from a plugin version that did not write the field: none of them is
# evidence that the map is current, and treating an absence as one is how a stale page ships.
regenerate() { echo "reason: $1"; echo "verdict: regenerate"; exit 3; }

PAGE=$DIR/index.html
MANIFEST=$DIR/manifest.json

[ -f "$PAGE" ]     || regenerate "no previous Review Map was restored"
[ -f "$MANIFEST" ] || regenerate "the restored map has no manifest, so the revision it describes is unknown"

# THE PREVIOUS HEAD COMES FROM THE MANIFEST, NEVER FROM THE PAGE. The manifest exists to carry the
# two things a reader cannot recover from the HTML, and which revision this page describes is one of
# them; the page carries a SEVEN-CHARACTER short SHA, which is a prefix rather than a commit and
# would have to be resolved against a repository that may not contain it.
PREV=$(sed -n 's/.*"head_sha"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{7,40\}\)".*/\1/p' "$MANIFEST" | head -n 1)
[ -n "$PREV" ] || regenerate "the restored manifest names no head revision"

# The pull request's OWN base, from the same place, and it is not interchangeable with the previous
# head. carry-plan.sh measures its delta against the whole diff — past half of it an update is worse
# than a fresh run — so handing it the previous head as the base would make the delta and the diff
# the same set and refuse every time. The delta is prev..head; the diff it is a fraction OF is
# base...head.
BASE=$(sed -n 's/.*"base_sha"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{7,40\}\)".*/\1/p' "$MANIFEST" | head -n 1)
[ -n "$BASE" ] || regenerate "the restored manifest names no base revision"

cd "$REPO_DIR" 2>/dev/null || regenerate "cannot enter the repository at $REPO_DIR"
git rev-parse --show-toplevel >/dev/null 2>&1 || regenerate "not inside a git repository"

for ref in "$PREV" "$BASE" "$HEAD_SHA"; do
  git rev-parse --verify --quiet "$ref^{commit}" >/dev/null 2>&1 \
    || regenerate "cannot resolve $ref in this checkout"
done

if [ "$(git rev-parse "$PREV")" = "$(git rev-parse "$HEAD_SHA")" ]; then
  echo "reason: the head has not moved since the existing map was generated"
  echo "verdict: current"
  exit 0
fi

# -- half one: did these commits change application code? ------------------------------------
rc=0
APP=$("$PLUGIN_DIR/ci/application-code.sh" --base "$PREV" --head "$HEAD_SHA" \
        ${CONFIG:+--config "$CONFIG"} 2>/dev/null) || rc=$?
# ONLY `no-application-code` COUNTS, NEVER `trivial`, and the difference is the whole reason this
# reads the reason rather than the exit status. Those two are one answer to the gate's own question
# — is this worth a model run — and two different answers to THIS one. A trivially small
# application change is still a change to the code the map describes: one line in a file a
# checkpoint cites is exactly the case where the existing page has quietly stopped being true, and
# it is small by every measurement the gate has.
reason=$(printf '%s\n' "$APP" | sed -n 's/.*<!-- verdict: [a-z]* (\([a-z-]*\)) -->.*/\1/p' | head -n 1)
case "$rc:$reason" in
  3:no-application-code) ;;   # the only answer that means the map can still be true
  3:trivial)  regenerate "the commits since $(git rev-parse --short=7 "$PREV") change application code, trivially little of it but not none" ;;
  0:*)        regenerate "the commits since $(git rev-parse --short=7 "$PREV") change application code" ;;
  *)          regenerate "the application-code gate could not read the range (exit $rc)" ;;
esac
counts=$(printf '%s\n' "$APP" | sed -n 's/.*<!-- \(.*application file.*\)-->.*/\1/p' | head -n 1)

# -- half two: did they touch anything the page cites? ---------------------------------------
rc=0
PLAN=$("$PLUGIN_DIR/skills/review-map/scripts/carry-plan.sh" "$PAGE" \
        --prev-head "$PREV" --head "$HEAD_SHA" --base "$BASE" 2>/dev/null) || rc=$?
if [ "$rc" != 0 ]; then
  why=$(printf '%s\n' "$PLAN" | sed -n 's/^reason: //p' | head -n 1)
  regenerate "${why:-the previous page cannot be reused over this range}"
fi
if printf '%s\n' "$PLAN" | grep -q '	redo	\|	regen$'; then
  hit=$(printf '%s\n' "$PLAN" | grep -m1 '	redo	\|	regen$')
  regenerate "the commits since $(git rev-parse --short=7 "$PREV") reach something the page cites ($hit)"
fi

echo "reason: the commits since $(git rev-parse --short=7 "$PREV") change no application code${counts:+ and no code the page cites — $counts}"
echo "verdict: current"
exit 0
