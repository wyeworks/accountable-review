#!/bin/sh
# searches.sh — "record what was searched", checked against the repository.
#
# The rule this owns is not "is a search written down" — that is cheap and a page can satisfy
# it with a search that finds nothing it claims. It is: DOES THE RECORDED SEARCH REPRODUCE THE
# ENTRY IT IS OFFERED FOR.
#
# The failure that produced this script: a run recorded `rg -n 'account_type' app test db config`
# and said it returned every reader of the column, having just cited two guards that read that
# column through the enum predicate `steward?` — which the pattern does not match. Real search,
# right entries, false provenance, and nothing mechanical noticed. The judge did, at the cost of
# a model call.
#
# So this check RE-RUNS the recorded searches inside --repo and asks whether each cited entry is
# in their combined output. Re-running rather than matching the cited line against the pattern is
# deliberate: a search carries a PATH SCOPE, and ignoring it is how a check vouches wrongly. That
# same run recorded `rg -n 'steward|account_type|plan' app/views`, whose pattern does match
# `current_user.steward?` — so pattern-only matching would have passed the very entry the search
# could not have found, because the search never looked in app/controllers.
#
# Two things it deliberately does not do. It does not require a flow to record searches inline:
# § 2 has no such rule, so a fragment with affected entries and no recorded search WARNs rather
# than fails. And it skips entries that POINT at a flow — their provenance lives in the flow that
# explains them, which a fragment cannot see.
#
# What needs a reader: whether a search was the RIGHT one to run. This only settles whether the
# ones on offer reach what they are offered for.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_input

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

if [ -z "$REPO" ]; then
  skip "search provenance: needs --repo to re-run the searches the page recorded"
  finish
  exit
fi
if [ ! -d "$REPO" ]; then
  bad "search provenance: --repo is not a directory: $REPO"
  finish
  exit
fi

# ---------------------------------------------------------------- the recorded searches
#
# Every element-delimited text node, then the ones that look like a search invocation.
#
# Not just <code>: nothing in the format says a recorded search has to be one, and a run put its
# whole search table in <td><span class="cite">grep -rn ...</span></td>, which a <code>-only
# extractor read as ONE recorded search out of ten — and then failed the nine entries the other
# nine would have found. Text nodes are element-delimited by construction, so requiring the node
# to BEGIN with the tool keeps prose like "one grep is not enough" out.
awk '{
  line = $0
  while (match(line, />[^<]*</)) {
    seg = substr(line, RSTART + 1, RLENGTH - 2)
    if (seg ~ /^[[:space:]]*(rg|grep|egrep|ag)[[:space:]]/) print seg
    line = substr(line, RSTART + RLENGTH - 1)
  }
}' "$IN" > "$TMP/code-blocks"

sed -e 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;/'"'"'/g' \
    "$TMP/code-blocks" | grep -E '^[[:space:]]*(rg|grep|ag)[[:space:]]' > "$TMP/commands" || true

: > "$TMP/hits"
: > "$TMP/unparsed"
ncmd=0
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  # Split into pattern and paths without eval. A quoted pattern first; failing that, the first
  # token that is not a flag.
  pat=; paths=; prefix=
  case $cmd in
    *\'*\'*)
      prefix=${cmd%%\'*}
      pat=${cmd#*\'}; pat=${pat%%\'*}
      paths=${cmd#*\'}; paths=${paths#*\'} ;;
    *\"*\"*)
      prefix=${cmd%%\"*}
      pat=${cmd#*\"}; pat=${pat%%\"*}
      paths=${cmd#*\"}; paths=${paths#*\"} ;;
    *)
      # rg -n foo app lib — walk the tokens, first non-flag after the tool is the pattern.
      set -- $cmd; prefix=$1; shift
      while [ $# -gt 0 ]; do
        case $1 in -*) prefix="$prefix $1"; shift ;; *) pat=$1; shift; break ;; esac
      done
      paths=$* ;;
  esac
  if [ -z "$pat" ]; then
    echo "$cmd" >> "$TMP/unparsed"; continue
  fi
  # Drop any remaining flags from the path list; an empty list means the whole repo.
  cleaned=
  for p in $paths; do
    case $p in -*) : ;; *) cleaned="$cleaned $p" ;; esac
  done
  [ -n "$cleaned" ] || cleaned=.
  ncmd=$((ncmd + 1))

  # RE-RUN IT WITH THE DIALECT IT WAS WRITTEN IN. This is not fussiness: `\|` is alternation
  # in grep's default BRE and a LITERAL PIPE in rg, so running a recorded
  # `grep -rn "recommendable\|general_recommendations_eligible" app` through rg matches
  # nothing — and the check then reports every entry that search found as unreachable. A check
  # that invents failures is worse than no check, and this one invented ten before it was fixed.
  tool=${prefix%%[[:space:]]*}; tool=${tool##*/}
  case $tool in
    rg|ag)  engine=rg ;;
    egrep)  engine=ere ;;
    grep)
      case " $prefix " in
        *\ -*E*\ *|*\ -*P*\ *) engine=ere ;;
        *\ -*F*\ *)            engine=fixed ;;
        *)                     engine=bre ;;
      esac ;;
    *) engine=ere ;;
  esac
  # No rg on this machine and an rg pattern: grep -E is close enough for the alternation and
  # character classes these patterns actually use, and firing approximately beats skipping.
  [ "$engine" != rg ] || command -v rg >/dev/null 2>&1 || engine=ere

  case $engine in
    rg)    ( cd "$REPO" && rg --no-heading --line-number --no-messages --regexp "$pat" -- $cleaned ) ;;
    ere)   ( cd "$REPO" && grep -rEn --no-messages -e "$pat" -- $cleaned ) ;;
    fixed) ( cd "$REPO" && grep -rFn --no-messages -e "$pat" -- $cleaned ) ;;
    *)     ( cd "$REPO" && grep -rn  --no-messages -e "$pat" -- $cleaned ) ;;
  esac 2>/dev/null | cut -d: -f1,2 >> "$TMP/hits" || true
done < "$TMP/commands"

sort -u "$TMP/hits" -o "$TMP/hits" 2>/dev/null || true

# ---------------------------------------------------------------- the affected entries
#
# Scoped by the template's own markers, the way blast-radius.sh scopes by id="blast":
# § 4's card carries <p class="eyebrow">Affected, not changed</p>, § 2's field carries
# <dt>Affected, unchanged</dt>. Sub-eyebrows inside the affected card (one per flow group) do
# not reset it; the Changed column, the end of the field, and <h3> do.
#
# A citation of the form :67, with no path, inherits the file from the entry's first full
# citation — the form report-format.md itself uses ("the guard at :128"). Resolving it is the
# point rather than a guess: it is the narrowest citation in the entry, which is the line the
# prose is actually about, and checking the enclosing range instead is how a guard that reads a
# column at :67 gets vouched for by a match on :70.
awk '
  /class="eyebrow"[^>]*>[^<]*[Cc]hanged[^<]*<\/p>/ && !/[Aa]ffected/ { aff = 0 }
  /class="eyebrow"[^>]*>[^<]*[Aa]ffected/          { aff = 1 }
  /<dt>[^<]*[Aa]ffected/                           { aff = 1 }
  /<\/dd>|<h3|<\/dl>/                              { aff = 0 }
  aff && /<li/ { inli = 1; buf = "" }
  inli { buf = buf " " $0 }
  inli && /<\/li>/ { print buf; inli = 0 }
' "$IN" > "$TMP/entries"

checked=0; missing=0; pointers=0; unresolved=0
: > "$TMP/failures"

while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  case $entry in
    *'href="#flow'*) pointers=$((pointers + 1)); continue ;;
  esac

  cites=$(printf '%s\n' "$entry" | awk '{
    line = $0
    while (match(line, /class="cite"[^>]*>[^<]*</)) {
      seg = substr(line, RSTART, RLENGTH)
      sub(/^[^>]*>/, "", seg); sub(/<$/, "", seg)
      print seg
      line = substr(line, RSTART + RLENGTH)
    }
  }')
  [ -n "$cites" ] || continue

  # The entry's SUBJECT is its first full citation; later ones are supporting. A bare :N binds
  # to the citation immediately before it and no further — the run that prompted this check
  # wrote "...test_helper.rb:7-24 ... (redirect_test.rb:21, :38)", where a rule of "narrowest
  # bare cite in the entry" would have attributed :38 to test_helper.rb.
  subject=; nextcite=; seen=0
  oldifs=$IFS; IFS='
'
  for c in $cites; do
    if [ "$seen" -eq 1 ]; then nextcite=$c; break; fi
    case $c in
      */*:[0-9]*) subject=$c; seen=1 ;;
    esac
  done
  IFS=$oldifs

  [ -n "$subject" ] || { unresolved=$((unresolved + 1)); continue; }
  path=${subject%%:*}
  [ -f "$REPO/$path" ] || { unresolved=$((unresolved + 1)); continue; }

  case $nextcite in
    :[0-9]*) first=${nextcite#:}; last=$first ;;
    *)
      lines=${subject#*:}
      first=${lines%%-*}; last=${lines##*-} ;;
  esac
  case $first in ''|*[!0-9]*) unresolved=$((unresolved + 1)); continue ;; esac
  case $last  in ''|*[!0-9]*) last=$first ;; esac

  checked=$((checked + 1))
  found=0; n=$first
  while [ "$n" -le "$last" ] 2>/dev/null; do
    if grep -qxF "$path:$n" "$TMP/hits"; then found=1; break; fi
    n=$((n + 1))
  done
  if [ "$found" -eq 0 ]; then
    missing=$((missing + 1))
    if [ "$first" = "$last" ]; then where="$path:$first"; else where="$path:$first-$last"; fi
    echo "$where" >> "$TMP/failures"
  fi
done < "$TMP/entries"

# ---------------------------------------------------------------- verdicts
if [ "$ncmd" -eq 0 ]; then
  if [ "$checked" -gt 0 ] || [ "$pointers" -gt 0 ]; then
    maybe "affected entries are present but no search is recorded anywhere — provenance cannot be checked, and unrecorded, absence and omission look identical"
  else
    skip "no recorded search and no affected entry to check one against"
  fi
else
  ok "$ncmd recorded search(es) re-run inside the repository"
fi

if [ -s "$TMP/unparsed" ]; then
  maybe "$(wc -l < "$TMP/unparsed" | tr -d ' ') recorded command(s) could not be parsed into a pattern and paths — read them by hand"
fi

if [ "$ncmd" -eq 0 ]; then
  # Nothing recorded means provenance is UNVERIFIABLE, not false. The warning above is the
  # whole verdict: failing every entry here would punish § 2, which has no rule requiring a
  # flow to record its searches inline, for a rule only § 4 states.
  [ "$checked" -eq 0 ] || skip "$checked cited entr(ies) left unchecked: with no search recorded there is nothing to check them against"
elif [ "$checked" -eq 0 ]; then
  skip "no affected entry resolved to a file in the repo, so provenance had nothing to check"
elif [ "$missing" -eq 0 ]; then
  ok "every one of $checked cited entr(ies) is reachable from a recorded search"
else
  # One line, because lib.sh's contract is one line per expectation and the expectation is
  # "the recorded searches reproduce the entries" — not one per entry. Naming the first few is
  # what makes it actionable; the count is what says how far it goes.
  head -5 "$TMP/failures" > "$TMP/sample"
  named=$(tr '\n' ' ' < "$TMP/sample" | sed 's/ $//')
  [ "$missing" -le 5 ] || named="$named, and $((missing - 5)) more"
  bad "$missing of $checked cited entr(ies) are reachable from no recorded search: $named"
fi

# Coverage of the check itself, so a small number of FAILs cannot be read as a clean sweep.
[ "$pointers" -eq 0 ]   || skip "$pointers entr(ies) point at a flow: their provenance lives there, not here"
[ "$unresolved" -eq 0 ] || skip "$unresolved entr(ies) carried no citation this check could resolve to a file in the repo"

finish
