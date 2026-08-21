#!/bin/sh
# coverage-gate.sh — assert the coverage ledger accounts for every path in the diff.
#
#   Usage: coverage-gate.sh <page.html> <BASE> [HEAD]
#
# Run it from inside the repository under review. Exits 0 and prints "gate: pass"
# only when the set of ledger paths equals the set of diff paths, compared as whole
# strings.
#
# Why this is a script and not three lines of shell improvised per run: the
# comparison is the one part of the page that is checkable mechanically, and the
# tempting shortcut — grepping the rendered page for each path — silently passes on
# truncated paths, because "api/Gemfile" matches inside "api/Gemfile.lock". Set
# comparison is the only version that catches that, and set comparison needs the
# ledger's paths extracted exactly, which needs the markup to cooperate.
#
# It does, by contract: every ledger row carries the path in a data-path attribute
#
#     <td data-path="app/models/project.rb">…</td>
#
# so extraction is one grep regardless of whether the cell renders as a permalink,
# a diff anchor, or plain text. If you are looking at this because the gate says it
# found no paths, that attribute is what is missing.
#
# data-path is RESERVED to ledger rows. The grep below is not scoped to the ledger
# table — it reads the whole page — so any other component emitting the attribute
# injects surplus paths and fails this check. Source excerpts carry data-src for
# exactly that reason, and they are the case that would bite: an excerpt of
# unchanged code is not in the diff, so it would fail the gate on the page's most
# valuable content. If you are adding a component that needs to name a path, pick
# another attribute.
#
# Renames: git reports the post-rename path, so that is what the ledger row must
# carry. Name the old path in prose, not in the ledger cell.

set -eu

PAGE=${1:-}
BASE=${2:-}
HEAD=${3:-HEAD}

if [ -z "$PAGE" ] || [ -z "$BASE" ]; then
  echo "usage: coverage-gate.sh <page.html> <BASE> [HEAD]" >&2
  exit 2
fi
if [ ! -r "$PAGE" ]; then
  echo "gate: FAIL — cannot read page at $PAGE" >&2
  exit 2
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git diff --name-only "$BASE...$HEAD" | sort -u > "$TMP/diff"

grep -o 'data-path="[^"]*"' "$PAGE" \
  | sed 's/^data-path="//; s/"$//' \
  | sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;/'"'"'/g' \
  | sort -u > "$TMP/ledger"

diff_n=$(wc -l < "$TMP/diff" | tr -d ' ')
ledger_n=$(wc -l < "$TMP/ledger" | tr -d ' ')

if [ "$ledger_n" -eq 0 ]; then
  echo "gate: FAIL — no data-path attributes in the page."
  echo "  The ledger rows must carry the path as <td data-path=\"...\">, or this"
  echo "  check cannot run. It does not fall back to searching the page text:"
  echo "  that check passes on wrong paths, which is worse than no check."
  exit 1
fi

missing=$(comm -23 "$TMP/diff" "$TMP/ledger")
extra=$(comm -13 "$TMP/diff" "$TMP/ledger")

if [ -z "$missing" ] && [ -z "$extra" ]; then
  echo "gate: pass — $diff_n changed paths, all accounted for in the ledger."
  exit 0
fi

echo "gate: FAIL — diff has $diff_n paths, ledger has $ledger_n."
if [ -n "$missing" ]; then
  echo
  echo "In the diff, missing from the ledger — add a row for each:"
  echo "$missing" | sed 's/^/  + /'
fi
if [ -n "$extra" ]; then
  echo
  echo "In the ledger, not in the diff — usually a typo, a stale row, or the"
  echo "pre-rename path of a renamed file:"
  echo "$extra" | sed 's/^/  - /'
fi
exit 1
