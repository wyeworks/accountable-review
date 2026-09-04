#!/bin/sh
# install-workflow.sh — put the rendered workflow in the repository, idempotently.
#
#   Usage: install-workflow.sh [--repo-dir .] [--path .github/workflows/accountable-review.yml]
#                              [--update] [--print-diff] [-- <render-workflow.sh args>]
#
# Prints one status line and exits:
#
#   status=created    the file did not exist; it does now
#   status=unchanged  the file was already byte-for-byte what setup generates
#   status=updated    it was ours and out of date, and --update rewrote it
#   status=drift      it differs from what setup generates; nothing was written
#
# Idempotency is the whole job. Running setup twice must not produce a second
# workflow, a duplicated job, or a file that differs only in a timestamp — which
# is why the rendered output carries no date, no run id and no randomness.
# "Already set up" is then decidable by comparing bytes, and needs no marker to
# be trusted.
#
# DRIFT IS NOT AN ERROR, it is the interesting case, and it is why this script
# refuses rather than rewrites. A team that tightened the timeout, added a
# `runs-on`, or pinned an action by sha has done something reasonable to a file
# they own, and setup silently reverting it would be the worst thing this
# command could do. It reports, shows the diff, and leaves the decision where it
# belongs.
#
# It touches exactly one path and never looks at another. Other workflows are not
# read, not parsed, not modified, and not counted.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RENDER=$HERE/render-workflow.sh

REPO_DIR=.
REL_PATH=.github/workflows/accountable-review.yml
UPDATE=0
PRINT_DIFF=0

while [ $# -gt 0 ]; do
  case $1 in
    --repo-dir)   REPO_DIR=$2; shift 2 ;;
    --path)       REL_PATH=$2; shift 2 ;;
    --update)     UPDATE=1;    shift ;;
    --print-diff) PRINT_DIFF=1; shift ;;
    --) shift; break ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install-workflow.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -d "$REPO_DIR" ] || { echo "install-workflow.sh: no such directory: $REPO_DIR" >&2; exit 2; }

TARGET=$REPO_DIR/$REL_PATH
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

"$RENDER" "$@" > "$TMP/workflow.yml"

if [ ! -f "$TARGET" ]; then
  mkdir -p "$(dirname "$TARGET")"
  cp "$TMP/workflow.yml" "$TARGET"
  echo "status=created"
  echo "path=$REL_PATH"
  exit 0
fi

if cmp -s "$TMP/workflow.yml" "$TARGET"; then
  echo "status=unchanged"
  echo "path=$REL_PATH"
  exit 0
fi

if [ "$UPDATE" = 1 ]; then
  cp "$TMP/workflow.yml" "$TARGET"
  echo "status=updated"
  echo "path=$REL_PATH"
  exit 0
fi

echo "status=drift"
echo "path=$REL_PATH"
if [ "$PRINT_DIFF" = 1 ]; then
  echo "--- diff: what is there, against what setup would write ---"
  diff -u "$TARGET" "$TMP/workflow.yml" || true
fi
exit 3
