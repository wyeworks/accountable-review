#!/bin/sh
# excerpts.sh — the mechanical half of the source excerpts.
#
# The half that matters is not here: does the prose still read completely with every
# excerpt CLOSED, judged field by field. That needs a reader and lives in the cases.
# What a script can settle is shape — collapsed by default, a summary that says what is
# inside, tints that exist in all three theme blocks, no range quoted twice, a quotation
# nobody coloured by hand, and a state tag that agrees with the diff it describes.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_input

ex=$(grep -o 'class="excerpt' "$IN" | wc -l | tr -d ' ')
if [ "$ex" -eq 0 ]; then
  skip "no excerpts in this input"
  finish
  exit
fi

det=$(grep -o '<details' "$IN" | wc -l | tr -d ' ')
sum=$(grep -o '<summary' "$IN" | wc -l | tr -d ' ')
if [ "$det" -eq "$sum" ]; then
  ok "$ex source excerpt(s), each with a summary"
else
  bad "$det <details> but $sum <summary> — a disclosure with no summary is an unlabelled black box"
fi

# Collapsed by default. An excerpt that ships open is just a code dump, and it is the
# reader who decides when they are ready to check the claim.
if grep -Eq '<details[^>]*[[:space:]]open([[:space:]>]|=)' "$IN"; then
  bad "an excerpt is open by default — excerpts are revealed by the reader, not shipped expanded"
else
  ok "every excerpt is collapsed by default"
fi

# A closed excerpt is the state most readers see, so its summary has to say what is
# inside. "View diff" is not a summary.
if grep -Eiq '<summary>[[:space:]]*(view|show|see) (diff|code|source)' "$IN"; then
  bad "a summary reads 'view diff'/'show code' — say the location and why to open it"
else
  ok "no placeholder summaries"
fi

# --- The state tag is a claim about the diff, so it is checked against one ---
#
# excerpt.sh derives the tag (see its STATE comment): Unchanged means the path is outside
# the diff, and Added / Removed / At head / Before the change mean it is inside. It used to
# hard-code "Unchanged" on every --source block, and a run duly published
# db/structure.sql:304-313 tagged Unchanged on a page whose own ledger listed that file as
# changed — the page contradicting itself about the one thing a reader cannot check from the
# page. That defect is invisible by construction: the block is real, the bytes are verbatim,
# and only the label is false. Hence two rules, one relational and one lexical.
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
strip_comments "$IN" "$TMP/src"
TAB=$(printf '\t')

# One row per excerpt: variant, state tag, quoted path, location. The tag is read only
# between a <details> and its </details>, because .tag is shared with the decisions block's
# Tradeoff chip and a page-wide grep would collect that as an excerpt's state.
awk '
  /class="excerpt excerpt--/ {
    v = $0; sub(/.*excerpt--/, "", v); sub(/[" ].*/, "", v)
    variant = v; inb = 1; tag = ""; src = ""; loc = ""; next
  }
  inb && /class="tag"/    { t = $0; sub(/.*class="tag">/, "", t);    sub(/<.*/, "", t); tag = t }
  inb && /class="ex-loc"/ { l = $0; sub(/.*class="ex-loc">/, "", l); sub(/<.*/, "", l); loc = l }
  inb && /data-src="/     { s = $0; sub(/.*data-src="/, "", s);      sub(/".*/, "", s); src = s }
  inb && /<\/details>/    { printf "%s\t%s\t%s\t%s\n", variant, tag, src, loc; inb = 0 }
' "$TMP/src" > "$TMP/blocks"

# The vocabulary is closed, and it is closed because the generator computes it. A tag
# outside it — "Modified", "New", a bare "Changed" on a listing with no +/- gutters — is a
# tag somebody typed, which is the same defect one step earlier. A block with no tag at all
# is left to the summary rule in report-format.md; this one only reads what is there.
typed=$(awk -F"$TAB" '
  $2 == "" || $2 ~ /{{/ { next }
  $1 == "source" && $2 !~ /^(Unchanged|Added|Removed|At head|Before the change)$/ { print $2 " on " $4 }
  $1 == "diff"   && $2 != "Changed" { print $2 " on " $4 }
' "$TMP/blocks")
if [ -z "$typed" ]; then
  ok "every state tag is one excerpt.sh emits"
else
  bad "a state tag is outside the generator's vocabulary, so it was typed: $(echo "$typed" | tr '\n' ';')"
fi

# The relational half. Two ways to learn what the diff touched, and the page carries one of
# them itself: the ledger accounts for every changed path by invariant, so a page can be
# held against its own account of the change with no repository at hand.
set_from=
git_unreadable=
if [ -n "$REPO" ] && [ -n "$BASE" ]; then
  mb=$(git -C "$REPO" merge-base "$BASE" "$HEAD_REF" 2>/dev/null) || mb=$BASE
  # git's OWN status, not the pipeline's. Written as `git … | awk | sort > file`, the `if`
  # tested `sort`, which succeeds whatever git did — so an unresolvable --base produced an
  # empty changed set, matched nothing, and reported a PASS. On this rule, of all of them:
  # the defect it exists to catch is a label the diff contradicts, and a stale base SHA turned
  # catching it into a clean bill of health. A check that invents a pass is worse than none.
  if git -C "$REPO" diff --name-status -M "$mb" "$HEAD_REF" > "$TMP/raw" 2>/dev/null; then
    awk -F"$TAB" '{ print $2; if (NF > 2) print $3 }' "$TMP/raw" | sort -u > "$TMP/changed"
    set_from="the diff"
  else
    git_unreadable=1
  fi
fi
if [ -z "$set_from" ] && grep -q 'data-path=' "$TMP/src"; then
  grep -o 'data-path="[^"]*"' "$TMP/src" | sed 's/^data-path="//; s/"$//' | sort -u > "$TMP/changed"
  set_from="the page's own ledger"
fi

# Said out loud, because run.sh passes --repo and --base on every page run: without this, a
# wrong base silently downgrades every run to ledger-only and the operator never learns.
if [ -n "$git_unreadable" ]; then
  maybe "the changed set could not be read from $REPO: git cannot resolve $BASE..$HEAD_REF — a page carrying a ledger is still checked against that, and one without is not checked at all"
fi

if [ -z "$set_from" ]; then
  skip "state tags against the diff: nothing to compare with — needs --repo and --base, or an input carrying the ledger"
else
  mis=
  while IFS="$TAB" read -r variant tag src loc; do
    [ "$variant" = source ] || continue
    [ "$tag" = Unchanged ] || continue
    [ -n "$src" ] || continue
    # Whole lines, never substrings: api/Gemfile sits inside api/Gemfile.lock.
    grep -Fxq "$src" "$TMP/changed" || continue
    mis="${mis:+$mis; }$loc"
  done < "$TMP/blocks"
  if [ -z "$mis" ]; then
    ok "no excerpt labels a changed file Unchanged, against $set_from"
  else
    bad "labelled Unchanged, but the change touches the file: $mis — quote it and let excerpt.sh --base tag the state"
  fi
fi

# The excerpt tints are the newest colours in the system, which makes them the most
# likely to be declared in one theme block and forgotten in the other two.
if [ "$IN_KIND" != page ]; then
  skip "excerpt tints: a fragment carries no token block"
else
  exadd=$(grep -o '\-\-ex-add' "$IN" | wc -l | tr -d ' ')
  if [ "$exadd" -ge 3 ]; then
    ok "excerpt tints defined in all three theme blocks"
  else
    bad "--ex-add appears $exadd time(s), needs 3 — bare :root plus both dark blocks"
  fi
fi

# The tint is applied at read time, so an hljs- class in the markup means someone
# coloured the quotation by hand — which is to say edited it. This is the one defect
# here that changes what the reader believes the file says.
if grep -q 'class="hljs-\|class="l hljs-' "$IN"; then
  bad "hljs- classes are written into the markup — the tint is the page script's job, and a hand-coloured quotation is an edited one"
else
  ok "no hand-written syntax colouring inside a quotation"
fi

# data-lang belongs to --source only. A diff hunk is not one lexical stream, so a
# tinted one is mis-lexed from the first unbalanced quote onward.
if awk '
  /class="excerpt excerpt--diff"/ { in_diff = 1 }
  /<\/details>/                   { in_diff = 0 }
  in_diff && /data-lang=/         { found = 1 }
  END { exit(found ? 0 : 1) }' "$IN"; then
  bad "a --diff excerpt carries data-lang — only unchanged code is tinted, a hunk is two realities interleaved"
else
  ok "data-lang is on unchanged excerpts only"
fi

# The syntax tints, like the add/del tints above: three theme states or none.
if [ "$IN_KIND" != page ]; then
  skip "syntax tints: a fragment carries no token block"
else
  syn=$(grep -o '\-\-syn-key' "$IN" | wc -l | tr -d ' ')
  if [ "$syn" -eq 0 ]; then
    skip "no syntax tokens on this page"
  elif [ "$syn" -ge 3 ]; then
    ok "syntax tints defined in all three theme blocks"
  else
    bad "--syn-key appears $syn time(s), needs 3 — bare :root plus both dark blocks"
  fi
fi

# Exact-duplicate excerpts. The budget forbids quoting the same lines twice — if a
# start-here entry and its cohort field rest on one citation, the excerpt goes in one of
# them. Near-duplicates (structurally identical code a few lines apart) are the more
# common waste and need a reader; this catches only the literal case. Placeholders are
# excluded: an unfilled template legitimately repeats {{PATH}}:{{LINES}}.
dup=$(grep -o 'class="ex-loc">[^<]*' "$IN" | grep -v '{{' | sort | uniq -d | head -3)
if [ -z "$dup" ]; then
  ok "no excerpt quotes the same lines twice"
else
  bad "the same range is excerpted more than once: $(echo "$dup" | sed 's/class="ex-loc">//' | tr '\n' ' ')"
fi

finish
