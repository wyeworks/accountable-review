#!/bin/sh
# command.sh — hand the Review Map directory to a command the team owns.
#
#   review_map:
#     delivery:
#       provider: command
#       command: ./bin/publish-review-map
#
# The command is run with the Review Map directory as its first argument and the
# AR_* variables in its environment, and its last line matching http(s):// is
# taken as the URL the map now lives at. A command that prints no URL still
# delivers — it is simply not browsable, and the location is the command itself.
#
# This is the escape hatch that keeps the other providers from having to exist
# in this repository: a team with an S3 bucket, an R2 bucket, a static host or
# an internal pastebin writes four lines of their own shell instead of waiting
# for an adapter.
#
# IT IS NOT ENABLED IN CI BY DEFAULT, and the reason is a real one. The generated
# workflow checks out the pull request, so .accountable-review.yml at that point
# is a file the PR author can edit — and a provider that runs a command named in
# it would turn "open a PR" into "run this on our runner". So this provider
# refuses to run unless ACCOUNTABLE_REVIEW_ALLOW_COMMAND=1 is set, which the
# generated workflow does not set. Locally, and in a workflow a team edits
# deliberately, it costs one environment variable.

set -eu

: "${AR_COMMAND:=}"
: "${AR_DIR:=}"

if [ -z "$AR_COMMAND" ]; then
  echo "command: no command configured — set review_map.delivery.command." >&2
  exit 1
fi

if [ "${ACCOUNTABLE_REVIEW_ALLOW_COMMAND:-}" != 1 ]; then
  echo "command: refusing to run '$AR_COMMAND'." >&2
  echo "The delivery command comes from configuration that a pull request can edit, so" >&2
  echo "running it needs a deliberate opt-in: set ACCOUNTABLE_REVIEW_ALLOW_COMMAND=1 in" >&2
  echo "an environment where that is what you meant." >&2
  exit 1
fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Word-split deliberately: the configured value is a command line, not a path.
# shellcheck disable=SC2086
sh -c "$AR_COMMAND \"\$1\"" sh "$AR_DIR" > "$TMP/out" 2>&1 || {
  echo "command: '$AR_COMMAND' exited non-zero." >&2
  cat "$TMP/out" >&2
  exit 1
}
cat "$TMP/out" >&2

url=$(grep -o 'https\{0,1\}://[^[:space:]]*' "$TMP/out" | tail -n 1 || true)

if [ -n "$url" ]; then
  echo "location=$url"
  echo "browsable=true"
  echo "stable_url=$url"
else
  echo "location=$AR_COMMAND"
  echo "browsable=false"
fi
