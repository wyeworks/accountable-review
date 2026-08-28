#!/bin/sh
# ledger-rows.sh — emit the coverage-ledger rows for a diff.
#
#   Usage: ledger-rows.sh <BASE> [HEAD] [--pr <owner/repo#N>]
#                                       [--compare <owner/repo@base...head>]
#                                       [--blob <owner/repo@sha>]
#          (run from inside the repository)
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
#
# LINKS. report-format.md § 7 wants a deep link per row, and at link rungs 1 and 2
# that link is a diff-page anchor, whose fragment is the SHA-256 of the path. Pass
# --pr or --compare and the rows come out linked. This exists because a run without
# the flag hand-inserted seven anchors into the very <td> that carries data-path —
# typing inside the one cell the coverage gate reads, which is the thing this script
# was written to stop.
#
#   --pr owner/repo#N                  rung 1: <pull/N/files#diff-{sha256(path)}>
#   --compare owner/repo@base...head   rung 2: <compare/base...head#diff-{sha256(path)}>
#   --blob owner/repo@sha              rung 2 with no reachable base: <blob/{sha}/{path}>
#   neither                            rungs 3 and 4: the path as plain <code>, no href
#
# A ledger row names a file, so both diff-page forms link the file rather than a
# line — a diff page is where the reviewer is working, and the row is their way in.
#
# Give exactly the one your rung calls for. Emitting an href you have not earned is
# the failure mode report-format.md § Choosing a mode is about.

set -eu

BASE=
HEAD_REF=HEAD
PR=
COMPARE=
BLOB=

while [ $# -gt 0 ]; do
  case $1 in
    --pr)      PR=${2:-};      shift 2 ;;
    --compare) COMPARE=${2:-}; shift 2 ;;
    --blob)    BLOB=${2:-};    shift 2 ;;
    -*) echo "ledger-rows.sh: unknown option $1" >&2; exit 2 ;;
    *)
      if [ -z "$BASE" ]; then BASE=$1; else HEAD_REF=$1; fi
      shift ;;
  esac
done

if [ -z "$BASE" ]; then
  echo "usage: ledger-rows.sh <BASE> [HEAD] [--pr owner/repo#N] [--compare owner/repo@base...head] [--blob owner/repo@sha]" >&2
  exit 2
fi
n=0
for v in "$PR" "$COMPARE" "$BLOB"; do [ -n "$v" ] && n=$((n + 1)); done
if [ "$n" -gt 1 ]; then
  echo "ledger-rows.sh: pass one of --pr, --compare, --blob — one rung, one link form." >&2
  exit 2
fi

esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }

# GitHub's Files-tab fragment is sha256 of the path as it appears in the diff.
sha256of() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1
  else
    printf '%s' "$1" | sha256sum | cut -d' ' -f1
  fi
}

# The cell's inner markup: a link when the rung earns one, plain <code> otherwise.
cell() {
  _p=$1
  _safe=$(printf '%s' "$_p" | esc)
  if [ -n "$PR" ]; then
    _repo=${PR%#*}
    _num=${PR##*#}
    printf '<a class="cite" href="https://github.com/%s/pull/%s/files#diff-%s"><code>%s</code></a>' \
      "$_repo" "$_num" "$(sha256of "$_p")" "$_safe"
  elif [ -n "$COMPARE" ]; then
    _repo=${COMPARE%@*}
    _range=${COMPARE##*@}
    printf '<a class="cite" href="https://github.com/%s/compare/%s#diff-%s"><code>%s</code></a>' \
      "$_repo" "$_range" "$(sha256of "$_p")" "$_safe"
  elif [ -n "$BLOB" ]; then
    _repo=${BLOB%@*}
    _sha=${BLOB##*@}
    printf '<a class="cite" href="https://github.com/%s/blob/%s/%s"><code>%s</code></a>' \
      "$_repo" "$_sha" "$_safe" "$_safe"
  else
    printf '<code>%s</code>' "$_safe"
  fi
}

git diff --numstat "$BASE...$HEAD_REF" | sort -k3 | while IFS='	' read -r add del path; do
  status=$(git diff --name-status "$BASE...$HEAD_REF" -- "$path" | cut -f1 | head -1)
  safe=$(printf '%s' "$path" | esc)
  printf '<!-- %s +%s/-%s -->\n' "${status:-?}" "$add" "$del"
  printf '<tr><td data-path="%s">%s</td><td>{{SECTION}}</td>' "$safe" "$(cell "$path")"
  printf '<td><span class="chip">{{read|skim|mechanical}}</span></td>'
  printf '<td><span class="chip">{{primary|supporting|secondary}}</span></td></tr>\n'
done

count=$(git diff --name-only "$BASE...$HEAD_REF" | wc -l | tr -d ' ')
printf '<!-- %s rows, generated from git diff --numstat %s...%s -->\n' "$count" "$BASE" "$HEAD_REF"
