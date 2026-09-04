#!/bin/sh
# deliver.sh — hand a finished Review Map to a delivery provider.
#
#   Usage: deliver.sh --dir <review-map dir> --repository <owner/repo>
#                     [--provider <name>] [--config <file>]
#                     [--pr <N>] [--base-sha <sha>] [--head-sha <sha>]
#                     [--retention-days <n>] [--command <cmd>]
#
# This is the seam the whole CI design turns on: Review Map GENERATION must not
# know where the page ends up. Generation writes a portable static directory;
# this script is the only thing that knows what happens to it afterwards. Adding
# S3, R2, a static host or a Claude Artifact means adding one file next to this
# one — it means changing nothing about how the page is produced.
#
# It prints a DeliveryResult as JSON on stdout:
#
#   { "provider": "github-artifact",
#     "location": "accountable-review-pr-412-a93bd21",
#     "browsable": false,
#     "stable_url": null }
#
# `browsable` is the field that matters to a caller: false means a human has to
# download and extract before they can read anything, which is exactly the
# trade the zero-configuration default makes. A static host returns true and a
# `stable_url` that survives the run.
#
# Providers live in this directory as <name>.sh. A provider is handed the job
# through AR_* environment variables and prints `key=value` lines; `location`
# is required, `browsable` and `stable_url` optional, and anything else it
# prints is carried through to the result and to $GITHUB_OUTPUT. That is the
# whole contract — a provider that needs more than environment in and key=value
# out is a sign the abstraction is being asked to do too much.
#
# WHO MOVES THE BYTES. Some providers do it themselves (`command` runs the
# team's script). `github-artifact` does not: uploading from a step script means
# reimplementing the Actions artifact protocol, so it names the destination and
# the workflow's actions/upload-artifact step performs the standard upload with
# the name and retention this script returns. The seam is unaffected either way
# — generation still does not know which of the two happened.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CI_DIR=$(dirname "$HERE")
PLUGIN_ROOT=$(dirname "$CI_DIR")

DIR=; PROVIDER=; CONFIG=; REPOSITORY=; PR=; BASE_SHA=; HEAD_SHA=
RETENTION=; COMMAND=

while [ $# -gt 0 ]; do
  case $1 in
    --dir)            DIR=$2;        shift 2 ;;
    --provider)       PROVIDER=$2;   shift 2 ;;
    --config)         CONFIG=$2;     shift 2 ;;
    --repository)     REPOSITORY=$2; shift 2 ;;
    --pr)             PR=$2;         shift 2 ;;
    --base-sha)       BASE_SHA=$2;   shift 2 ;;
    --head-sha)       HEAD_SHA=$2;   shift 2 ;;
    --retention-days) RETENTION=$2;  shift 2 ;;
    --command)        COMMAND=$2;    shift 2 ;;
    -h|--help) sed -n '2,44p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "deliver.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$DIR" ] || { echo "deliver.sh: --dir is required" >&2; exit 2; }
[ -d "$DIR" ] || { echo "deliver.sh: not a directory: $DIR" >&2; exit 1; }
[ -f "$DIR/index.html" ] || {
  echo "deliver.sh: $DIR holds no index.html — there is nothing to deliver." >&2
  exit 1
}

# Configuration, in the order the design fixes: explicit flags beat the
# repository's config file, which beats the defaults. read-config.sh is the one
# place that knows the file's shape.
READ_CONFIG=$PLUGIN_ROOT/skills/setup-ci/scripts/read-config.sh
if [ -z "$CONFIG" ] && [ -f .accountable-review.yml ]; then CONFIG=.accountable-review.yml; fi
if [ -n "$CONFIG" ] && [ -f "$CONFIG" ] && [ -x "$READ_CONFIG" ]; then
  eval "$("$READ_CONFIG" "$CONFIG" --prefix CFG_)"
fi
[ -n "$PROVIDER" ]  || PROVIDER=${CFG_provider:-github-artifact}
[ -n "$RETENTION" ] || RETENTION=${CFG_retention_days:-30}
[ -n "$COMMAND" ]   || COMMAND=${CFG_command:-}

PROVIDER_SCRIPT=$HERE/$PROVIDER.sh
if [ ! -x "$PROVIDER_SCRIPT" ]; then
  echo "deliver.sh: no provider named '$PROVIDER'." >&2
  echo "Available:" >&2
  for p in "$HERE"/*.sh; do
    b=$(basename "$p" .sh); [ "$b" = deliver ] || echo "  $b" >&2
  done
  echo "Providers designed for but not implemented: claude-artifact, s3, r2, static-host." >&2
  exit 2
fi

AR_DIR=$DIR
AR_REPOSITORY=$REPOSITORY
AR_PR=$PR
AR_BASE_SHA=$BASE_SHA
AR_HEAD_SHA=$HEAD_SHA
AR_RETENTION_DAYS=$RETENTION
AR_COMMAND=$COMMAND
export AR_DIR AR_REPOSITORY AR_PR AR_BASE_SHA AR_HEAD_SHA AR_RETENTION_DAYS AR_COMMAND

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
"$PROVIDER_SCRIPT" > "$TMP/result" || {
  echo "deliver.sh: provider '$PROVIDER' failed." >&2
  cat "$TMP/result" >&2 || true
  exit 1
}

location=; browsable=false; stable_url=
extras=

while IFS= read -r line; do
  [ -z "$line" ] && continue
  k=${line%%=*}; v=${line#*=}
  case $k in
    location)   location=$v ;;
    browsable)  browsable=$v ;;
    stable_url) stable_url=$v ;;
    *)          extras="$extras$k=$v
" ;;
  esac
done < "$TMP/result"

if [ -z "$location" ]; then
  echo "deliver.sh: provider '$PROVIDER' returned no location." >&2
  exit 1
fi
case $browsable in true|false) ;; *) browsable=false ;; esac

json_str() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

printf '{\n'
printf '  "provider": "%s",\n'  "$(json_str "$PROVIDER")"
printf '  "location": "%s",\n'  "$(json_str "$location")"
printf '  "browsable": %s,\n'   "$browsable"
if [ -n "$stable_url" ]; then
  printf '  "stable_url": "%s"' "$(json_str "$stable_url")"
else
  printf '  "stable_url": null'
fi
printf '%s' "$extras" | while IFS= read -r e; do
  [ -z "$e" ] && continue
  printf ',\n  "%s": "%s"' "$(json_str "${e%%=*}")" "$(json_str "${e#*=}")"
done
printf '\n}\n'

# Step outputs, so the workflow's upload step reads the artifact name and the
# retention this provider decided rather than repeating the decision in YAML.
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "provider=$PROVIDER"
    echo "location=$location"
    echo "browsable=$browsable"
    echo "stable_url=$stable_url"
    printf '%s' "$extras"
  } >> "$GITHUB_OUTPUT"
fi
