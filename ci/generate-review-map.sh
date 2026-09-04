#!/bin/sh
# generate-review-map.sh — run the review-map skill non-interactively and leave a
# portable static directory behind.
#
#   Usage: generate-review-map.sh --output DIR --repository owner/repo
#                                 --pr N --base-sha SHA --head-sha SHA
#                                 [--mode brief|full] [--effort high|low]
#                                 [--config FILE] [--repo-dir DIR]
#                                 [--plugin-dir DIR] [--claude-bin claude]
#                                 [--strict-gate] [--print-invocation]
#                                 [--verify-only]
#
# This is the whole CI adapter, and it is deliberately thin. It does not know how
# to explain a diff — it reuses the review-map skill exactly as an interactive
# session does, through the same SKILL.md and the same scripts, and the only
# thing it adds is the contract for running with nobody watching:
#
#   * the target and the revision are passed in, so the run needs no `gh`;
#   * --output makes the page a file in a directory instead of a published
#     artifact, which is what makes the result portable;
#   * what a human would have noticed by looking at the page — that it still says
#     "still being written", or describes a revision that is not the one asked
#     for — is checked here instead.
#
# There is no second Review Map implementation, and there must never be one. If
# this script ever starts deciding what goes on the page, the interactive and CI
# products have forked and the page a team reads in CI is not the page anyone
# develops against.
#
# --print-invocation and --verify-only exist so both halves of this script are
# testable without a model: the first prints the argv it would run, the second
# runs only the checks against a directory that already exists.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=$(dirname "$HERE")

OUTPUT=; REPOSITORY=; PR=; BASE_SHA=; HEAD_SHA=; MODE=; EFFORT=; CONFIG=
REPO_DIR=.; PLUGIN_DIR=; CLAUDE_BIN=${CLAUDE_BIN:-claude}
STRICT_GATE=0; PRINT_INVOCATION=0; VERIFY_ONLY=0

while [ $# -gt 0 ]; do
  case $1 in
    --output)      OUTPUT=$2;     shift 2 ;;
    --repository)  REPOSITORY=$2; shift 2 ;;
    --pr)          PR=$2;         shift 2 ;;
    --base-sha)    BASE_SHA=$2;   shift 2 ;;
    --head-sha)    HEAD_SHA=$2;   shift 2 ;;
    --mode)        MODE=$2;       shift 2 ;;
    --effort)      EFFORT=$2;     shift 2 ;;
    --config)      CONFIG=$2;     shift 2 ;;
    --repo-dir)    REPO_DIR=$2;   shift 2 ;;
    --plugin-dir)  PLUGIN_DIR=$2; shift 2 ;;
    --claude-bin)  CLAUDE_BIN=$2; shift 2 ;;
    --strict-gate)       STRICT_GATE=1;      shift ;;
    --print-invocation)  PRINT_INVOCATION=1; shift ;;
    --verify-only)       VERIFY_ONLY=1;      shift ;;
    -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "generate-review-map.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

die() { echo "generate-review-map.sh: $*" >&2; exit 1; }

[ -n "$OUTPUT" ] || die "--output is required"
[ -n "$HEAD_SHA" ] || die "--head-sha is required — a Review Map that cannot name its revision is worse than none"
[ -n "$PLUGIN_DIR" ] || PLUGIN_DIR=$PLUGIN_ROOT

# Configuration: flags beat the repository's config file, which beats defaults.
if [ -z "$CONFIG" ] && [ -f "$REPO_DIR/.accountable-review.yml" ]; then
  CONFIG=$REPO_DIR/.accountable-review.yml
fi
if [ -n "$CONFIG" ] && [ -f "$CONFIG" ]; then
  eval "$("$PLUGIN_ROOT/skills/setup-ci/scripts/read-config.sh" "$CONFIG" --prefix CFG_)"
fi
[ -n "$MODE" ]   || MODE=${CFG_mode:-brief}
[ -n "$EFFORT" ] || EFFORT=${CFG_effort:-high}

case $MODE in brief|full) ;; *) die "--mode must be brief or full, got '$MODE'" ;; esac
# `normal` was this value's name while it was the default; the skill still takes it and
# means `low`, so a config file written before the rename keeps working here too.
case $EFFORT in normal) EFFORT=low ;; esac
case $EFFORT in high|low) ;; *) die "--effort must be high or low, got '$EFFORT'" ;; esac

# The page must never land inside the repository it describes — it would become
# part of the next diff, and on a PR branch it would be a file the change itself
# introduced. The skill has this as a hard rule; here it is a check, because a
# workflow makes it very easy to write "review-map/" and mean the workspace.
mkdir -p "$OUTPUT"
# -P, because the comparison below is against `git rev-parse --show-toplevel`, which is
# always physical. Plain `pwd` reports the logical path, so on a machine where the
# workspace sits under a symlink — /tmp on macOS is /private/tmp — the prefix test
# silently fails to match and the guard waves through exactly what it exists to stop.
# It is not only a test artefact: an --output symlinked into the checkout bypasses it
# the same way, and then the page lands in the diff it describes.
OUTPUT_ABS=$(cd "$OUTPUT" && pwd -P)
if REPO_TOP=$(cd "$REPO_DIR" && git rev-parse --show-toplevel 2>/dev/null); then
  case "$OUTPUT_ABS/" in
    "$REPO_TOP"/*) die "--output ($OUTPUT_ABS) is inside the repository under review ($REPO_TOP).
The Review Map must never become part of the diff it describes. Point --output at
a directory outside the checkout — \$RUNNER_TEMP in GitHub Actions." ;;
  esac
fi

PAGE=$OUTPUT_ABS/index.html

# ---------------------------------------------------------------- invocation --

PROMPT="/accountable-review:review-map${PR:+ $PR} --$MODE --effort $EFFORT --output $OUTPUT_ABS"
if [ -n "$REPOSITORY" ]; then PROMPT="$PROMPT --repository $REPOSITORY"; fi
if [ -n "$BASE_SHA" ];   then PROMPT="$PROMPT --base-sha $BASE_SHA"; fi
PROMPT="$PROMPT --head-sha $HEAD_SHA"

set -- "$CLAUDE_BIN" -p "$PROMPT" \
  --plugin-dir "$PLUGIN_DIR" \
  --add-dir "$OUTPUT_ABS" \
  --permission-mode bypassPermissions \
  --disallowed-tools "WebFetch,WebSearch"

if [ "$PRINT_INVOCATION" = 1 ]; then
  for a in "$@"; do printf '%s\n' "$a"; done
  exit 0
fi

if [ "$VERIFY_ONLY" = 0 ]; then
  if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] \
     && [ -z "${CLAUDE_CODE_USE_BEDROCK:-}" ] && [ -z "${CLAUDE_CODE_USE_VERTEX:-}" ]; then
    die "no model credential in the environment.
Set ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN as a repository secret and pass it
into this step. Nothing was generated — this is a missing credential, not a failed run."
  fi

  # The skill reads the diff. A shallow clone makes that quietly wrong rather
  # than loudly broken, so check before spending a model on it.
  ( cd "$REPO_DIR" && git cat-file -e "$HEAD_SHA^{commit}" ) 2>/dev/null \
    || die "$HEAD_SHA is not in the checkout. Check out the PR head."
  if [ -n "$BASE_SHA" ]; then
    ( cd "$REPO_DIR" && git cat-file -e "$BASE_SHA^{commit}" ) 2>/dev/null \
      || die "$BASE_SHA is not in the checkout.
The Review Map is built from BASE...HEAD, so the base commit has to be present:
check out with fetch-depth: 0 rather than the default shallow clone."
  fi

  echo "accountable-review: generating a $MODE review map at effort $EFFORT"
  echo "accountable-review: ${REPOSITORY:-this repository}${PR:+ PR #$PR} ${BASE_SHA:+$(printf '%.7s' "$BASE_SHA")..}$(printf '%.7s' "$HEAD_SHA")"
  ( cd "$REPO_DIR" && exec "$@" ) || die "the review-map run failed. No Review Map was produced."
fi

# --------------------------------------------------------------- verification --
#
# Three things a person would have caught by looking at the page, and nobody is
# looking. Each is fatal on purpose: an artifact that says the wrong thing about
# itself is worse than a missing one, because a team acts on it.

[ -f "$PAGE" ] || die "the run finished but wrote no $PAGE.
The --output contract is that the page lands at <dir>/index.html."

size=$(wc -c < "$PAGE" | tr -d ' ')
[ "$size" -gt 2000 ] || die "$PAGE is only $size bytes — that is not a review map."

if grep -q 'class="buildstate"' "$PAGE" || grep -q 'class="pending"' "$PAGE"; then
  die "the page still carries the build banner or a pending marker.
A pending marker is a promise that something is still being written, and in CI
nothing is: the run is over. Refusing to deliver a page that says otherwise."
fi

short=$(printf '%.7s' "$HEAD_SHA")
grep -q "$short" "$PAGE" || die "the page never names the revision it describes ($short).
Every Review Map has to correspond to a specific base and head, visibly, or a
reviewer cannot tell whether it describes the version in front of them."

gate=$PLUGIN_ROOT/skills/review-map/scripts/coverage-gate.sh
gate_result="not run"
if [ -x "$gate" ] && [ -n "$BASE_SHA" ]; then
  if ( cd "$REPO_DIR" && "$gate" "$PAGE" "$BASE_SHA" "$HEAD_SHA" ); then
    gate_result=pass
  else
    gate_result=fail
    echo "accountable-review: the coverage gate did not pass — the page does not account" >&2
    echo "for every changed path. It is still delivered; the manifest records the result." >&2
    if [ "$STRICT_GATE" = 1 ]; then die "coverage gate failed and --strict-gate was given."; fi
  fi
fi

# ------------------------------------------------------------------- manifest --
#
# Provenance, not a verdict. It says which revision this page describes and which
# version of the plugin produced it — the two things a reader cannot recover from
# the HTML — and nothing about whether the change is any good.

version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -n 1)

cat > "$OUTPUT_ABS/manifest.json" <<JSON
{
  "schema": "accountable-review/review-map-manifest@1",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "plugin": {
    "name": "accountable-review",
    "version": "${version:-unknown}"
  },
  "review_map": {
    "entry": "index.html",
    "mode": "$MODE",
    "effort": "$EFFORT"
  },
  "revision": {
    "repository": "$REPOSITORY",
    "pull_request": ${PR:-null},
    "base_sha": "$BASE_SHA",
    "head_sha": "$HEAD_SHA"
  },
  "coverage_gate": "$gate_result"
}
JSON

echo "accountable-review: review map ready at $PAGE ($(( size / 1024 )) KB, coverage gate: $gate_result)"
