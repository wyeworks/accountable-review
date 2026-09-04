#!/bin/sh
# github-artifact.sh — the default delivery provider, and the reason the default
# needs no infrastructure at all.
#
# It requires no hosting, no credentials beyond the one the model already needs,
# no external service and no manual step to share the result: every member of
# the repository can already open the workflow run and download what it produced.
# The cost is that the map is not browsable in place — it has to be downloaded
# and extracted first — and that is the trade the zero-configuration default
# accepts deliberately rather than by omission.
#
# Contract: read AR_* from the environment, print key=value lines. See
# deliver.sh. This provider does not move bytes; it names the destination and
# lets the workflow's actions/upload-artifact step do the standard upload with
# the name and retention printed here.

set -eu

: "${AR_HEAD_SHA:=}"
: "${AR_PR:=}"
: "${AR_RETENTION_DAYS:=30}"

short=$(printf '%.7s' "$AR_HEAD_SHA")

# Artifact names may not contain " : < > | * ? \ / or newlines. Nothing below
# can produce one — the PR number is digits and the sha is hex — but a run
# against a branch rather than a PR falls through to the sha alone rather than
# interpolating a branch name that could carry a slash.
if [ -n "$AR_PR" ] && [ -n "$short" ]; then
  name="accountable-review-pr-$AR_PR-$short"
elif [ -n "$short" ]; then
  name="accountable-review-$short"
else
  echo "github-artifact: neither a PR number nor a head sha — cannot name the artifact." >&2
  exit 1
fi

case $AR_RETENTION_DAYS in
  ''|*[!0-9]*)
    echo "github-artifact: retention_days must be a whole number of days, got '$AR_RETENTION_DAYS'." >&2
    exit 1 ;;
esac

echo "location=$name"
echo "browsable=false"
echo "artifact_name=$name"
echo "retention_days=$AR_RETENTION_DAYS"
