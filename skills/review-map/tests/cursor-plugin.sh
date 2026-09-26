#!/bin/sh
# The Cursor plugin: its manifest agrees with the Claude one and names only files that exist,
# and local installation never touches the user's plugins or configuration.
#
# The version check is the reason this file exists. Each host reads only its own manifest, and a
# release that bumps .claude-plugin/plugin.json alone leaves every Cursor install on the old
# version with nothing anywhere saying so.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd -P)
T=$(mktemp -d "${TMPDIR:-/tmp}/review-map-cursor.XXXXXX")
trap 'rm -rf "$T"' EXIT HUP INT TERM
INSTALL=$ROOT/bin/install-cursor-plugin

# ---- manifest
ruby -rjson -e '
  root = ARGV[0]
  cursor = JSON.parse(File.read(File.join(root, ".cursor-plugin/plugin.json")))
  claude = JSON.parse(File.read(File.join(root, ".claude-plugin/plugin.json")))
  fail = ->(m) { warn "cursor-plugin: #{m}"; exit 1 }
  # The top-level keys cursor/plugins schemas/plugin.schema.json allows; it sets additionalProperties false.
  allowed = %w[name displayName description version minClientVersions author publisher homepage
               repository license logo keywords category tags commands agents skills rules hooks
               variables mcpServers]
  extra = cursor.keys - allowed
  fail.("keys the Cursor schema rejects: #{extra.join(", ")}") unless extra.empty?
  %w[name version].each do |k|
    fail.("#{k} differs: cursor #{cursor[k].inspect}, claude #{claude[k].inspect}") unless cursor[k] == claude[k]
  end
  %w[skills agents].each do |k|
    Array(cursor[k]).each do |p|
      fail.("#{k} path must be relative without ..: #{p}") if p.start_with?("/") || p.split("/").include?("..")
      fail.("#{k} path does not exist: #{p}") unless File.exist?(File.join(root, p))
    end
  end
  fail.("skills must name review-map alone") unless Array(cursor["skills"]) == ["./skills/review-map/"]
' "$ROOT"

# The wrapper: Cursor frontmatter, none of the Claude-only keys, and the same mandate pointer.
AGENT=$ROOT/cursor/agents/review-map-falsifier.md
FRONT=$(awk 'NR == 1 && $0 == "---" { on = 1; next } on && $0 == "---" { exit } on' "$AGENT")
printf '%s\n' "$FRONT" | grep -q '^name: review-map-falsifier$'
printf '%s\n' "$FRONT" | grep -q '^description: '
printf '%s\n' "$FRONT" | grep -q '^readonly: true$'
if printf '%s\n' "$FRONT" | grep -Eq '^(tools|disallowedTools):'; then
  echo 'cursor-plugin: the Cursor wrapper carries a Claude-only key' >&2; exit 1
fi
grep -q 'skills/review-map/references/claim-falsifier.md' "$AGENT"
# The host reference names the agent the plugin registers.
grep -q 'review-map-falsifier' "$ROOT/skills/review-map/references/hosts/cursor.md"

# ---- installer
sh "$INSTALL" --plugins-dir "$T/plugins with spaces"
DEST="$T/plugins with spaces/accountable-review"
[ -L "$DEST" ]
[ "$(readlink "$DEST")" = "$ROOT" ]
for path in .cursor-plugin/plugin.json cursor/agents/review-map-falsifier.md \
            skills/review-map/SKILL.md skills/review-map/references/hosts/cursor.md \
            skills/review-map/references/claim-falsifier.md skills/review-map/scripts/page-skeleton.sh; do
  cmp "$DEST/$path" "$ROOT/$path"
done
sh "$INSTALL" --plugins-dir "$T/plugins with spaces" | grep '^unchanged:'

mkdir -p "$T/existing/accountable-review"
printf 'keep me\n' > "$T/existing/accountable-review/sentinel"
if sh "$INSTALL" --plugins-dir "$T/existing"; then exit 1; fi
[ "$(cat "$T/existing/accountable-review/sentinel")" = 'keep me' ]

mkdir "$T/dangling"
ln -s "$T/missing" "$T/dangling/accountable-review"
if sh "$INSTALL" --plugins-dir "$T/dangling"; then exit 1; fi
[ "$(readlink "$T/dangling/accountable-review")" = "$T/missing" ]

if sh "$INSTALL" --plugins-dir; then exit 1; fi
if sh "$INSTALL" --unknown; then exit 1; fi
echo 'PASS: Cursor manifest parity, wrapper frontmatter, install, repeat install, conflict preservation, and invalid arguments'
