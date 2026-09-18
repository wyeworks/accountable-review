#!/bin/sh
# carry-plan.sh — on a re-run, decide what of the previous page may be carried.
#
#   Usage: carry-plan.sh <page.html> --prev-head <sha> --base <sha> --head <sha> [--repo-dir <dir>]
#          (run from inside the repository under review)
#
# A Review Map describes one revision. When a pull request gains commits, the cheap thing to do
# is re-analyse only what those commits reach and leave the rest of the page alone. The cheap
# thing is also the dangerous one: a carried claim is a claim nobody re-read, sitting on a page
# whose masthead says it describes the current head. So the decision about what may be carried
# is made here, mechanically, rather than by a run judging it by eye — which is the same
# argument ledger-rows.sh and diff-render.sh were written from. By eye, every checkpoint looks
# carryable.
#
# THE POLARITY. Every precondition below is joined by AND and failure means a FULL run, never a
# partial one. This is ci/application-code.sh's asymmetry: a needless full run costs model
# minutes nobody watches, and a wrongly carried claim is a false statement the reader cannot
# detect from the inside. There is no "mostly incremental".
#
# THE CARRY RULE, and it is sound because of a hard rule the page already obeys. Every claim on
# the page carries a file:line, so a checkpoint that turns on a file cites it. Therefore:
#
#   a checkpoint is carried iff no path in the delta appears among the path tokens inside its
#   own <section class="cp">
#
# WHAT THIS CANNOT KNOW, and what therefore stays with the run. Effort and mentor are invisible
# on the page by design, the plugin version is recorded only in CI's manifest, and the deep-link
# rung is a property of a remote rather than of these bytes. None of the four can be recovered
# from a page, so SKILL.md § Re-running over new commits makes them the run's own checks before
# it calls this script. What is checkable here is checked here.
#
# Output is tab-separated rows, plus comment lines a run can read or ignore:
#
#   delta<TAB>app/models/project.rb
#   cp<TAB>cp-a<TAB>carry<TAB>-
#   cp<TAB>cp-b<TAB>redo<TAB>cites app/models/project.rb
#   excerpt<TAB>app/models/project.rb<TAB>regen
#   search<TAB>rg -n 'archived_at' app<TAB>safe<TAB>no delta path among its hits
#   verdict: update
#
# On a full verdict stdout carries the reason and the verdict and nothing else: a half-printed
# plan is worse than none, because the rows that did print would read as a plan.
#
# Exits 0 update, 3 full (a decision, not a failure), 2 called wrongly, 4 an unresolvable ref.

set -eu

PAGE=
PREV=
BASE=
HEAD_REF=
REPO_DIR=

while [ $# -gt 0 ]; do
  case $1 in
    --prev-head) PREV=${2:-}; shift 2 ;;
    --base)      BASE=${2:-}; shift 2 ;;
    --head)      HEAD_REF=${2:-}; shift 2 ;;
    --repo-dir)  REPO_DIR=${2:-}; shift 2 ;;
    -h|--help)   sed -n '2,5p' "$0"; exit 0 ;;
    -*) echo "carry-plan.sh: unknown option $1" >&2; exit 2 ;;
    *)
      if [ -z "$PAGE" ]; then PAGE=$1; else
        echo "carry-plan.sh: unexpected argument $1" >&2; exit 2
      fi
      shift ;;
  esac
done

if [ -z "$PAGE" ] || [ -z "$PREV" ] || [ -z "$BASE" ] || [ -z "$HEAD_REF" ]; then
  echo "usage: carry-plan.sh <page.html> --prev-head <sha> --base <sha> --head <sha> [--repo-dir <dir>]" >&2
  exit 2
fi

case $PAGE in
  /*) ;;
  *)  PAGE=$(pwd)/$PAGE ;;
esac

if [ ! -r "$PAGE" ]; then
  echo "carry-plan.sh: cannot read $PAGE" >&2
  exit 2
fi

if [ -n "$REPO_DIR" ]; then
  cd "$REPO_DIR" || exit 2
fi

# Paths on the page are repository-relative, and so is everything git prints below. Running from
# a subdirectory would make the two disagree silently, which is the shape of defect this whole
# script exists to prevent, so resolve to the top level once.
TOP=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "carry-plan.sh: not inside a git repository" >&2
  exit 2
}
cd "$TOP"

# Asked and unable to answer is not an empty delta. Every git command below feeds a pipeline, so
# a failing ref would leave the status at 0 and produce no rows — which reads as "nothing
# changed", the most reassuring answer this script can give and the one with the least behind
# it. diff-render.sh carries the same guard for the same reason.
for ref in "$PREV" "$BASE" "$HEAD_REF"; do
  if ! git rev-parse --verify --quiet "$ref^{commit}" >/dev/null 2>&1; then
    echo "carry-plan.sh: cannot resolve $ref in this repository" >&2
    exit 4
  fi
done

TMP=${TMPDIR:-/tmp}/carry-plan.$$
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT INT HUP TERM

full() {
  echo "reason: $1"
  echo "verdict: full"
  exit 3
}

short() { git rev-parse --short=7 "$1"; }

# -- P1 · the new head builds on the old one -----------------------------------------------
#
# A force-push or a rebase fails this, and a rebased branch's "delta" is a diff between two
# histories rather than the commits someone added. Under P1 the two-dot and three-dot forms of
# the delta agree, which is why the delta below can use the simpler one without ambiguity.
if ! git merge-base --is-ancestor "$PREV" "$HEAD_REF" >/dev/null 2>&1; then
  full "the previous head $(short "$PREV") is not an ancestor of $(short "$HEAD_REF") — the branch was rebased or force-pushed"
fi

# -- P2 · the page is the page we think it is ------------------------------------------------
#
# Two greps rather than an HTML parse of the masthead, and the idiom is borrowed deliberately:
# ci/generate-review-map.sh already establishes that a page names its revision by grepping the
# seven-character short SHA page-wide. A parse of the Revision cell would be a second reader of
# that markup and would break the first time the cell is restyled.
MB=$(git merge-base "$BASE" "$HEAD_REF")

if ! grep -F -q "$(short "$PREV")" "$PAGE"; then
  full "the page does not name $(short "$PREV") — it does not describe the revision this update claims to start from"
fi

if ! grep -F -q "$(short "$MB")" "$PAGE"; then
  full "the page does not name the merge-base $(short "$MB") — the diff's left side moved under it"
fi

# -- P3 · the previous page is complete ------------------------------------------------------
#
# A draft is mid-run and a stopped page is one someone has to finish deliberately (SKILL.md
# § When a run stops early). Neither is a base to update from: pending is a promise, and an
# update that carried one would be promising work nothing is doing.
if grep -q 'class="buildstate"' "$PAGE" || grep -q 'class="pending"' "$PAGE"; then
  full "the page still carries a build banner or a pending marker — it is a draft, not a finished map"
fi
if grep -F -q 'not written' "$PAGE"; then
  full "the page states a part was not written — a stopped run is finished deliberately, never updated"
fi

# -- the delta, and the diff it sits inside --------------------------------------------------
git diff --name-only --no-renames "$PREV".."$HEAD_REF" | sort -u > "$TMP/delta"
git diff --name-only --no-renames "$BASE"..."$HEAD_REF" | sort -u > "$TMP/full"

N_DELTA=$(wc -l < "$TMP/delta" | tr -d ' ')
N_FULL=$(wc -l < "$TMP/full" | tr -d ' ')

if [ "$N_DELTA" -eq 0 ]; then
  full "no file changed between $(short "$PREV") and $(short "$HEAD_REF") — there is nothing to update"
fi

# -- P4 · the delta is worth it --------------------------------------------------------------
#
# Past half the diff an update costs more than a fresh run and produces a worse page: the run
# pays to read the old page as well, and carries fewer of its claims for it. Stated as a number
# here rather than a flag, because a knob on it is a knob on how much of the page went
# unre-read.
if [ "$N_FULL" -eq 0 ] || [ $((N_DELTA * 2)) -gt "$N_FULL" ]; then
  full "the delta covers $N_DELTA of $N_FULL changed paths — more than half, so a fresh run is the cheaper and better page"
fi

# -- P5 · no lockfile in the delta -----------------------------------------------------------
#
# Gemfile.lock and mix.lock are what every documentation link on the page is pinned from, and a
# Rails series moving re-pins all of them. There is no way to carry a pinned link across that.
if awk -F/ '{ print $NF }' "$TMP/delta" | grep -qxE 'Gemfile\.lock|mix\.lock'; then
  full "a lock file moved in the delta — every pinned documentation link is derived from it"
fi

# -- P6 · the delta did not land where the page searched --------------------------------------
#
# This is the precondition that protects the product. Affected-but-unchanged code is what the
# page is for, so the hazard is a new consumer appearing in a file NO checkpoint cites — which
# the carry rule alone cannot see. The page already records the searches that established those
# claims, so re-run each one at the current head and ask whether any delta path is among its
# hits.
#
# HITS, NOT SCOPE. The recorded scopes are broad (`app lib spec`), so a scope test would trip on
# nearly every application change and leave the feature reaching nothing. A hits test trips only
# when the new code actually matches a pattern the page reasoned about, which is exactly the
# case where step 7's global merge and rank is owed.
#
# A PRECONDITION, NOT A PER-CHECKPOINT RULE. The page does not record which checkpoint a search
# supports, and inventing an attribution heuristic here would be worse than a clean bail-out.
#
# AT HEAD, IN THE WORKTREE. `git grep` takes a tree-ish and `rg` does not, and every search
# recipe in both lens files is written with rg. A two-tree replay is therefore not available,
# and one replay at head answers the question anyway.
#
# The row format is report-format.md § What was searched's, which evals/checks/searches.rb also
# reads; that section owns it and both of us are readers.
awk '
  /<details class="searched"/ { inside = 1 }
  inside { print }
  inside && /<\/details>/     { inside = 0 }
' "$PAGE" > "$TMP/searched" || true

# Element-delimited text nodes, then the ones that begin with a search tool. Beginning with the
# tool is what keeps prose like "one grep is not enough" out, and it is searches.rb's test for
# the same reason.
awk '
  {
    line = $0
    while (match(line, />[^<]*</)) {
      node = substr(line, RSTART + 1, RLENGTH - 2)
      print node
      line = substr(line, RSTART + RLENGTH - 1)
    }
  }
' "$TMP/searched" \
  | sed -e 's/&amp;/\&/g' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' -e "s/&#39;/'/g" \
  | grep -E '^[[:space:]]*(git[[:space:]]+)?(rg|grep|egrep|ag)[[:space:]]' > "$TMP/searches" || true

# A quote-aware tokenizer, because the safety rule has to be quote-aware to be usable: every
# recorded alternation in the lens files lives inside quotes (`'\''include Archivable|< Project'\''`),
# so a blanket refusal of | and < would reject the real searches and send every re-run to a full
# one. Outside quotes those characters are a shell doing something, and this refuses them there.
#
# Nothing here is passed to a shell. The tokens are read into positional parameters and the
# command is executed as argv, because these strings were written by a model that had just read
# a contributor's branch.
#
# The command reaches awk through the environment rather than through -v, and that is not a
# style choice: -v processes escape sequences in the value, so `rg -n '\bProjects::Archive\b'`
# would arrive with two backspaces where its word boundaries were. The pattern would still run
# and would still match things — just not the things the page recorded — which is the quietest
# possible way for this check to vouch wrongly.
tokenize() {
  CARRY_CMD=$1 awk '
    BEGIN {
      s = ENVIRON["CARRY_CMD"]
      n = length(s); i = 1; tok = ""; have = 0; state = "out"
      while (i <= n) {
        c = substr(s, i, 1)
        if (state == "out") {
          if (c == " " || c == "\t") { if (have) { print tok; tok = ""; have = 0 } }
          else if (c == "'\''") { state = "sq"; have = 1 }
          else if (c == "\"")  { state = "dq"; have = 1 }
          else if (index(";|&`$><(){}\\", c) > 0) { exit 1 }
          else { tok = tok c; have = 1 }
        } else if (state == "sq") {
          if (c == "'\''") state = "out"; else tok = tok c
        } else {
          if (c == "\\") {
            d = substr(s, i + 1, 1)
            if (d == "\"" || d == "\\" || d == "$" || d == "`") { tok = tok d; i++ }
            else tok = tok c
          }
          else if (c == "\"") state = "out"
          else if (c == "$" || c == "`") { exit 1 }
          else tok = tok c
        }
        i++
      }
      if (state != "out") exit 1
      if (have) print tok
      exit 0
    }'
}

: > "$TMP/searchrows"
UNSAFE=

while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue

  if ! tokenize "$cmd" > "$TMP/argv" 2>/dev/null; then
    UNSAFE=$cmd
    break
  fi

  set --
  while IFS= read -r tok; do set -- "$@" "$tok"; done < "$TMP/argv"
  [ $# -gt 0 ] || { UNSAFE=$cmd; break; }

  tool=$1
  [ "$tool" = "git" ] && tool="git ${2:-}"
  case $tool in
    rg|grep|egrep|'git grep') ;;
    *) UNSAFE=$cmd; break ;;
  esac
  if ! command -v "$1" >/dev/null 2>&1; then
    UNSAFE=$cmd; break
  fi

  # grep and rg exit 1 on no match, which is a result rather than a failure.
  "$@" > "$TMP/hits" 2>/dev/null || true

  # rg and grep print path:line:text. A non-empty line whose first field is not a file in this
  # repository means the output is a shape this cannot read — one file searched, so no filename
  # column, or a flag that changed the format — and an unreadable result is not an empty one.
  : > "$TMP/hitpaths"
  bad=0
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    p=${hit%%:*}
    if [ -f "$p" ]; then printf '%s\n' "$p" >> "$TMP/hitpaths"; else bad=1; break; fi
  done < "$TMP/hits"
  if [ "$bad" -eq 1 ]; then UNSAFE=$cmd; break; fi

  sort -u "$TMP/hitpaths" > "$TMP/hitpaths.s" && mv "$TMP/hitpaths.s" "$TMP/hitpaths"
  landed=$(comm -12 "$TMP/delta" "$TMP/hitpaths" | head -n 1)
  if [ -n "$landed" ]; then
    full "the delta changed $landed, which the recorded search \`$cmd\` now finds — a consequence of these commits reaches code the page reasoned about"
  fi
  printf 'search\t%s\tsafe\tno delta path among its hits\n' "$cmd" >> "$TMP/searchrows"
done < "$TMP/searches"

if [ -n "$UNSAFE" ]; then
  full "the recorded search \`$UNSAFE\` cannot be replayed safely — an unreplayable search is not a search that found nothing"
fi

# -- the plan --------------------------------------------------------------------------------

sed 's/^/delta\t/' "$TMP/delta"

# One flattened line per checkpoint, so the path test below is a line test. cp sections do not
# nest, so the first closing tag is this one's.
awk '
  /<section class="cp"/ {
    inside = 1; buf = ""; id = ""
    if (match($0, /id="[^"]*"/)) id = substr($0, RSTART + 4, RLENGTH - 5)
  }
  inside { gsub(/\t/, " "); buf = buf " " $0 }
  inside && /<\/section>/ { print id "\t" buf; inside = 0 }
' "$PAGE" \
  | sed -e 's/&amp;/\&/g' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' -e "s/&#39;/'/g" \
  > "$TMP/cps"

# A path token, not a substring: api/Gemfile must never match inside api/Gemfile.lock. That is
# coverage-gate.sh's lesson, and getting it wrong here is worse than getting it wrong there —
# there it fails a page loudly, here it would carry a checkpoint that cites the changed file.
BOUND='[^A-Za-z0-9._/-]'

while IFS="$(printf '\t')" read -r id body; do
  [ -n "$id" ] || continue
  reason=-
  while IFS= read -r p; do
    esc=$(printf '%s' "$p" | sed 's/[][\.*^$+?(){}|]/\\&/g')
    if printf '%s' "$body" | grep -qE "(^|$BOUND)$esc($BOUND|\$)"; then
      reason="cites $p"
      break
    fi
  done < "$TMP/delta"

  if [ "$reason" = "-" ]; then
    printf 'cp\t%s\tcarry\t-\n' "$id"
  else
    printf 'cp\t%s\tredo\t%s\n' "$id" "$reason"
  fi
done < "$TMP/cps"

# An excerpt is a verbatim quotation and its state tag is computed from base...head, so a file
# entering the diff in the delta changes the tag as well as the lines. Both are bounded by the
# delta, which is why this list is exactly the delta intersected with what the page quotes.
grep -o 'data-src="[^"]*"' "$PAGE" 2>/dev/null \
  | sed -e 's/^data-src="//' -e 's/"$//' \
  | sed -e 's/&amp;/\&/g' \
  | sort -u > "$TMP/srcs" || true

while IFS= read -r p; do
  [ -n "$p" ] || continue
  if grep -qxF "$p" "$TMP/delta"; then
    printf 'excerpt\t%s\tregen\n' "$p"
  else
    printf 'excerpt\t%s\tkeep\n' "$p"
  fi
done < "$TMP/srcs"

cat "$TMP/searchrows"

N_CP=$(wc -l < "$TMP/cps" | tr -d ' ')
printf '<!-- %s checkpoint(s) on the page; %s delta path(s) of %s in the diff -->\n' \
  "$N_CP" "$N_DELTA" "$N_FULL"
echo "verdict: update"
