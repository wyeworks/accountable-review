#!/bin/sh
# ledger-rows.sh — emit the coverage-ledger rows for a diff.
#
#   Usage: ledger-rows.sh <BASE> [HEAD]        (run from inside the repository)
#
# The ledger has to list every changed path exactly, and coverage-gate.sh compares
# it as a set. Typing a hundred paths by hand fails that check for boring reasons —
# a truncation, a stale row after a rebase — so generate the rows and fill in the
# three judgements: which part covers the file, how much attention it needs, and
# which group it belongs to.
#
# Each row is preceded by a hint comment carrying the git status letter and the
# line counts, which is usually enough to decide `attention` without opening the
# file. Delete the hints when you paste, or leave them: HTML comments do not render.
#
# Placeholders left in the output are deliberate. A row that still says {{SECTION}}
# is a row nobody classified, and it is meant to be obvious.

set -eu

BASE=${1:-}
HEAD_REF=${2:-HEAD}

if [ -z "$BASE" ]; then
  echo "usage: ledger-rows.sh <BASE> [HEAD]" >&2
  exit 2
fi

esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }

git diff --numstat "$BASE...$HEAD_REF" | sort -k3 | while IFS='	' read -r add del path; do
  status=$(git diff --name-status "$BASE...$HEAD_REF" -- "$path" | cut -f1 | head -1)
  safe=$(printf '%s' "$path" | esc)
  printf '<!-- %s +%s/-%s -->\n' "${status:-?}" "$add" "$del"
  printf '<tr><td data-path="%s"><code>%s</code></td><td>{{SECTION}}</td>' "$safe" "$safe"
  printf '<td><span class="chip">{{read|skim|mechanical}}</span></td>'
  printf '<td><span class="chip">{{primary|supporting|secondary}}</span></td></tr>\n'
done

count=$(git diff --name-only "$BASE...$HEAD_REF" | wc -l | tr -d ' ')
printf '<!-- %s rows, generated from git diff --numstat %s...%s -->\n' "$count" "$BASE" "$HEAD_REF"
