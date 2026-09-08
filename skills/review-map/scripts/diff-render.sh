#!/bin/sh
# diff-render.sh — say, per path, whether GitHub will render that file's diff inline.
#
#   Usage: diff-render.sh <BASE> [HEAD] [--path <p>] [--collapsed-only]
#          (run from inside the repository)
#
# A citation into a file GitHub renders can be a diff anchor, which lands the reviewer on the
# line with its before and after either side. A citation into a file GitHub does NOT render
# cannot: the anchor arrives at a stub reading "Load diff", the line is not in the page, and
# nothing tells the reader that the link half-worked. So the link form has to know which kind of
# file it is pointing at, and report-format.md § When the diff will not render is the rule this
# script feeds. Rungs 3 and 4 have nothing to decide — there are no links at all.
#
# WHY A SCRIPT. Same reason ledger-rows.sh exists: a run asked to judge this per citation judges
# it by eye, and by eye every path looks renderable. The verdict is a function of the diff and
# the repository, so it is computed once and held.
#
# WHAT IT CANNOT KNOW. GitHub's own generated-file detection is Linguist's, which lives in
# GitHub's repository and not in this one. This script sees three things Linguist also sees —
# the repo's .gitattributes, the file's bytes, the size of its diff — plus a short list of
# lockfile names, and it is a heuristic in exactly one direction: the name list is dated
# (verified against a real pull request 2026-09-08, where pnpm-lock.yaml was collapsed as
# generated on a page whose .gitattributes never mentions it) and additions to it need the same
# treatment. Two things make that uncertainty cheap. The size rule catches nearly everything a
# name rule would, because a generated file is almost always a big one; and being wrong the
# common way is mild — a blob link where a diff anchor would have worked still lands on the
# line, it only loses the red and the green.
#
# The thresholds are DOCUMENTED, not tuned, and the source is
# docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits:
#
#   400 lines or 20 KB     a single file's diff is auto-loaded up to here; past it GitHub
#                          keeps the file behind "Load diff", which is the common case
#   20,000 lines or 500 KB no single file's diff may exceed this — past it the diff is not
#                          shown at all, and Load diff does not fully help either
#   20,000 lines or 1 MB   the whole pull request's cap
#   300 files              the maximum in a single diff; beyond it a path has no anchor at all
#
# The first pair decides the verdict. The last two are properties of the whole diff rather than
# of one path, so they are reported in the trailing summary instead of turned into per-path
# verdicts nobody could act on.
#
# Output is one line per path, tab-separated, plus comment lines a run can read or ignore:
#
#   collapse<TAB>generated<TAB>db/structure.sql
#   render<TAB>-<TAB>app/models/order.rb
#
# `collapse` is the verdict that changes the link form. Everything else about the citation —
# the rung, whether the line is in a hunk at all — is decided where it already was.

set -eu

BASE=
HEAD_REF=HEAD
ONE=
COLLAPSED_ONLY=0

# Documented, above. Named so a reader can find them; not flags, because they are GitHub's
# numbers rather than this repository's preferences, and a knob on each invites a run to tune
# its way out of a true verdict.
AUTOLOAD_LINES=400
AUTOLOAD_BYTES=20480
HARD_LINES=20000
HARD_BYTES=512000
DIFF_FILES_MAX=300
DIFF_BYTES_MAX=1048576

while [ $# -gt 0 ]; do
  case $1 in
    --path)           ONE=${2:-}; shift 2 ;;
    --collapsed-only) COLLAPSED_ONLY=1; shift ;;
    -*) echo "diff-render.sh: unknown option $1" >&2; exit 2 ;;
    *)
      if [ -z "$BASE" ]; then BASE=$1; else HEAD_REF=$1; fi
      shift ;;
  esac
done

if [ -z "$BASE" ]; then
  echo "usage: diff-render.sh <BASE> [HEAD] [--path <p>] [--collapsed-only]" >&2
  exit 2
fi

# ASKED AND UNABLE TO ANSWER IS NOT AN EMPTY DIFF, and nothing below can tell the difference on
# its own: every `git diff` here feeds a pipeline, so a failing git leaves the pipeline's exit
# status at 0 and produces no rows — which reads as "no file is withheld", the most reassuring
# thing this script can say and the one it has the least evidence for. This repository has paid
# for that once already, in the state-tag rule in evals/checks/excerpts.rb. So the refs are
# resolved up front, once, and an unresolvable one exits 4 with nothing on stdout.
for ref in "$BASE" "$HEAD_REF"; do
  if ! git rev-parse --verify --quiet "$ref^{commit}" >/dev/null 2>&1; then
    echo "diff-render.sh: cannot resolve $ref in this repository" >&2
    exit 4
  fi
done

# A lockfile's diff is usually over the size rule anyway; these are the ones whose ONE-LINE
# change would otherwise read as renderable while GitHub collapses it as generated. Keep the
# list short and defensible rather than long and guessed — an entry nobody has opened a real
# pull request against is the catalogue defect this repository already knows by name.
is_lockfile() {
  case ${1##*/} in
    package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|bun.lockb) return 0 ;;
    *) return 1 ;;
  esac
}

# .gitattributes, asked the way git resolves it — nested files and precedence included, which
# is why this is check-attr and not a grep for the pattern. `linguist-generated` marks a file
# GitHub collapses whatever its size; `-diff` marks one git itself treats as binary, which
# GitHub renders as "Binary file not shown".
# check-attr prints "<path>: <attr>: <value>", so the value is what is left after the last ": ".
# An empty answer falls through to `render` rather than to a verdict, which is the safe direction
# and is only reachable if git broke between the ref guard above and here.
attr_says() {
  _p=$1
  case $(git check-attr linguist-generated -- "$_p" 2>/dev/null | sed 's/.*: //') in
    true|set) printf generated; return 0 ;;
  esac
  case $(git check-attr diff -- "$_p" 2>/dev/null | sed 's/.*: //') in
    unset) printf 'no-diff'; return 0 ;;
  esac
  return 1
}

classify() {
  _path=$1
  _add=$2
  _del=$3

  # The attributes come first so the REASON is the informative one. A `-diff` path makes git
  # print a dash for both counts, so asking about the bytes first would report every one of them
  # as `binary` and lose the fact that a line in .gitattributes put it there — same verdict,
  # worse to act on.
  if _why=$(attr_says "$_path"); then
    printf 'collapse\t%s\t%s\n' "$_why" "$_path"
    return
  fi

  # git prints - for both counts on a binary file, and a binary diff has no lines to anchor to
  # at all. Checked before the arithmetic below, which cannot run on a dash.
  if [ "$_add" = "-" ] || [ "$_del" = "-" ]; then
    printf 'collapse\tbinary\t%s\n' "$_path"
    return
  fi

  if is_lockfile "$_path"; then
    printf 'collapse\tlockfile\t%s\n' "$_path"
    return
  fi

  _lines=$((_add + _del))
  _bytes=$(git diff "$BASE...$HEAD_REF" -- "$_path" | wc -c | tr -d ' ')

  if [ "$_lines" -gt "$HARD_LINES" ] || [ "$_bytes" -gt "$HARD_BYTES" ]; then
    printf 'collapse\tover-hard-cap\t%s\n' "$_path"
  elif [ "$_lines" -gt "$AUTOLOAD_LINES" ] || [ "$_bytes" -gt "$AUTOLOAD_BYTES" ]; then
    printf 'collapse\tover-autoload\t%s\n' "$_path"
  else
    printf 'render\t-\t%s\n' "$_path"
  fi
}

# One path, asked about directly. It does not have to be in the diff: a citation into unchanged
# code is a blob link already, and answering anyway costs nothing and saves the caller a branch.
if [ -n "$ONE" ]; then
  numstat=$(git diff --numstat "$BASE...$HEAD_REF" -- "$ONE" | head -1)
  if [ -z "$numstat" ]; then
    printf 'render\tnot-in-diff\t%s\n' "$ONE"
    exit 0
  fi
  add=$(printf '%s' "$numstat" | cut -f1)
  del=$(printf '%s' "$numstat" | cut -f2)
  classify "$ONE" "$add" "$del"
  exit 0
fi

git diff --numstat "$BASE...$HEAD_REF" | sort -k3 | while IFS='	' read -r add del path; do
  line=$(classify "$path" "$add" "$del")
  if [ "$COLLAPSED_ONLY" = 1 ]; then
    case $line in collapse*) printf '%s\n' "$line" ;; esac
  else
    printf '%s\n' "$line"
  fi
done

# The two whole-diff caps. Neither is a verdict about one path — which of 400 files GitHub drops
# past the 300th is not something to guess at per citation — so they are said once, here, where
# a run reads them and can state the limit on the page instead of publishing links it has not
# reasoned about.
files=$(git diff --name-only "$BASE...$HEAD_REF" | wc -l | tr -d ' ')
bytes=$(git diff "$BASE...$HEAD_REF" | wc -c | tr -d ' ')
printf '<!-- %s file(s), %s bytes of diff -->\n' "$files" "$bytes"
if [ "$files" -gt "$DIFF_FILES_MAX" ]; then
  printf '<!-- over the %s-file diff cap: some paths have no diff anchor at all, whatever their own size -->\n' "$DIFF_FILES_MAX"
fi
if [ "$bytes" -gt "$DIFF_BYTES_MAX" ]; then
  printf '<!-- over the %s-byte whole-diff cap: expect files to be withheld that are individually small -->\n' "$DIFF_BYTES_MAX"
fi
