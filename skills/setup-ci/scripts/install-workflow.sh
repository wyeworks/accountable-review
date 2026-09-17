#!/bin/sh
# install-workflow.sh — put the rendered workflow in the repository, idempotently.
#
#   Usage: install-workflow.sh [--repo-dir .] [--path .github/workflows/accountable-review.yml]
#                              [--update] [--print-diff] [--no-recover]
#                              [-- <render-workflow.sh args>]
#
# Prints one status line and exits:
#
#   status=created    the file did not exist; it does now
#   status=unchanged  the file was already byte-for-byte what setup generates
#   status=updated    it was ours and out of date, and --update rewrote it
#   status=drift      it differs from what setup generates; nothing was written
#
# and, on the first three, a `decisions=` line naming the decisions the written
# file makes — when a Review Map is generated, and whether the link is commented
# on the pull request — in the form setup takes them as flags. Report from that
# line rather than from what this call asked for; with recovery below, the two
# are not always the same.
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
#
# WHEN A WORKFLOW IS ALREADY THERE, ITS `# Decisions:` LINE IS READ BACK and
# passed to render-workflow.sh ahead of this call's own flags, so those flags
# still win and everything else is preserved. That line records the decisions a
# person confirmed during setup — whether pushes regenerate the map, which bot
# authors are skipped, and whether the link is commented on the pull request —
# and without the read-back the ordinary reason
# to run setup again, moving the version pin, would report every one of them as
# drift and then revert them under --update. Reverting a team's decision while
# claiming to upgrade them is the exact failure the drift rule above exists to
# prevent, so recovery is not a convenience.
#
# The comment decision is the one where reverting would be worst in both
# directions: silently re-adding a comment step a team turned off, or silently
# dropping the `pull-requests: write` scope they agreed to.
#
# A file with no such line — hand-written, or from a version before the line
# existed — recovers nothing and is compared against the defaults, which is the
# honest answer: nothing recorded what was chosen, so nothing can be preserved.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RENDER=$HERE/render-workflow.sh

REPO_DIR=.
REL_PATH=.github/workflows/accountable-review.yml
UPDATE=0
PRINT_DIFF=0
RECOVER=1

while [ $# -gt 0 ]; do
  case $1 in
    --repo-dir)   REPO_DIR=$2; shift 2 ;;
    --path)       REL_PATH=$2; shift 2 ;;
    --update)     UPDATE=1;    shift ;;
    --print-diff) PRINT_DIFF=1; shift ;;
    --no-recover) RECOVER=0; shift ;;
    --) shift; break ;;
    -h|--help) sed -n '2,44p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install-workflow.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -d "$REPO_DIR" ] || { echo "install-workflow.sh: no such directory: $REPO_DIR" >&2; exit 2; }

TARGET=$REPO_DIR/$REL_PATH
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Recovered flags go FIRST, so anything this call passes explicitly lands later
# and wins — render-workflow.sh takes the last assignment of a flag.
RECOVERED=
if [ "$RECOVER" = 1 ] && [ -f "$TARGET" ]; then
  RECOVERED=$(sed -n 's/^# Decisions: //p' "$TARGET" | head -n 1)
fi

# Globbing off while the recovered line is word-split: a login like
# `dependabot[bot]` is a valid shell pattern, and a file in the working directory
# named `dependabotb` would otherwise rewrite it.
set -f
# shellcheck disable=SC2086
"$RENDER" $RECOVERED "$@" > "$TMP/workflow.yml"
set +f

# What the rendered file actually says, so a caller reports the decisions in
# force rather than the ones it thinks it asked for.
sed -n 's/^# Decisions: /decisions=/p' "$TMP/workflow.yml" | head -n 1 > "$TMP/decisions"

if [ ! -f "$TARGET" ]; then
  mkdir -p "$(dirname "$TARGET")"
  cp "$TMP/workflow.yml" "$TARGET"
  echo "status=created"
  echo "path=$REL_PATH"
  cat "$TMP/decisions"
  exit 0
fi

if cmp -s "$TMP/workflow.yml" "$TARGET"; then
  echo "status=unchanged"
  echo "path=$REL_PATH"
  cat "$TMP/decisions"
  exit 0
fi

if [ "$UPDATE" = 1 ]; then
  cp "$TMP/workflow.yml" "$TARGET"
  echo "status=updated"
  echo "path=$REL_PATH"
  cat "$TMP/decisions"
  exit 0
fi

echo "status=drift"
echo "path=$REL_PATH"
if [ "$PRINT_DIFF" = 1 ]; then
  echo "--- diff: what is there, against what setup would write ---"
  diff -u "$TARGET" "$TMP/workflow.yml" || true
fi
exit 3
