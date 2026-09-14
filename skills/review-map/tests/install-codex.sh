#!/bin/sh
# Exercise local installation without touching the user's skills or configuration.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd -P)
T=$(mktemp -d "${TMPDIR:-/tmp}/review-map-install.XXXXXX")
trap 'rm -rf "$T"' EXIT HUP INT TERM
INSTALL=$ROOT/bin/install-codex-skill

sh "$INSTALL" --skills-dir "$T/skills with spaces"
DEST="$T/skills with spaces/review-map"
[ -L "$DEST" ]
[ "$(readlink "$DEST")" = "$ROOT/skills/review-map" ]
# A discovered installation includes everything needed at runtime, including the mandate.
for path in SKILL.md references/hosts/codex.md references/claim-falsifier.md scripts/page-skeleton.sh; do
  cmp "$DEST/$path" "$ROOT/skills/review-map/$path"
done
sh "$INSTALL" --skills-dir "$T/skills with spaces" | grep '^unchanged:'

mkdir -p "$T/existing/review-map"
printf 'keep me\n' > "$T/existing/review-map/sentinel"
if sh "$INSTALL" --skills-dir "$T/existing"; then exit 1; fi
[ "$(cat "$T/existing/review-map/sentinel")" = 'keep me' ]
[ ! -e "$T/existing/review-map/review-map" ]

mkdir "$T/dangling"
ln -s "$T/missing" "$T/dangling/review-map"
if sh "$INSTALL" --skills-dir "$T/dangling"; then exit 1; fi
[ "$(readlink "$T/dangling/review-map")" = "$T/missing" ]

mkdir "$T/file"
printf 'keep me\n' > "$T/file/review-map"
if sh "$INSTALL" --skills-dir "$T/file"; then exit 1; fi
[ "$(cat "$T/file/review-map")" = 'keep me' ]
if sh "$INSTALL" --skills-dir; then exit 1; fi
if sh "$INSTALL" --unknown; then exit 1; fi
echo 'PASS: Codex install, repeat install, bundled resources, conflict preservation, and invalid arguments'
