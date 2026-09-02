#!/bin/sh
# verify-catalogue.sh — opens every URL in references/rails-docs.md, in the pinned form a run
# actually emits, for every Rails series the catalogue claims to serve.
#
# WHY THIS EXISTS, AND WHY IT IS NOT A CHECK UNDER checks/
#
# The catalogue is an allowlist, and a run cannot re-verify it: there is no fetch step in the
# procedure and the sandboxes this skill runs in block egress to these hosts. That is the
# right runtime rule and it is not what this script changes. What it changes is the
# maintenance side of the same fact — "verified once" has no date on it, and the first
# re-check found 8 defects in 88 URLs, in three classes:
#
#   insert_all         asserted on Persistence/ClassMethods, which does not document it.
#                      Returns 200 and lands the reader on a real Rails page with no
#                      mention of the method — worse than a 404, because nothing looks wrong.
#   #filters           the controller guide renamed that section twice (7.1 -> 7.2 -> 8.0).
#   nested_attributes  a guide page that has never existed in any series. Not rot: a
#                      plausible URL constructed once and then admitted to the allowlist.
#   #readme            an anchor GitHub stopped emitting, on three gem rows.
#
# Only the third is caught by reading carefully. So this runs on a schedule or by hand, never
# inside a skill run, and it lives beside evals/ rather than under checks/ because check.sh
# dispatches offline rules over a page and this needs the network.
#
# THE ALLOWLIST IS THE TABLE ROWS, not the file. The prose quotes URLs it is warning about,
# and a whole-file sweep would verify the warnings. Same rule as checks/rails-anchors.sh.
#
# WHAT IT CHECKS, AND WHY THE UNPINNED FORM IS NOT IT
#
# The catalogue stores paths without a version; the run pins each one to the app's series
# before it reaches the page (rails-docs.md § Pinning). So the URL a reader clicks is always
# pinned, and checking the unpinned form would be checking a string nothing emits. Every path
# is therefore checked at v<series> for each series in the floor, with per-series overrides
# honoured — which means a clean run proves something stronger than it used to: every row
# resolves for every app the catalogue admits.
#
# Gem rows carry {version} and are pinned to a gem version rather than a Rails one, so they
# are checked once, at the gem's newest release. A per-gem floor (Pundit's verify_authorized
# section starts at 2.0) is prose in the catalogue, not something this can enumerate.
#
# Usage:
#   ./verify-catalogue.sh                          # the whole floor
#   ./verify-catalogue.sh --series "8.1 8.0"       # just these
#   ./verify-catalogue.sh -j 16 --cache /tmp/cat   # reuse a warm cache between runs
#   ./verify-catalogue.sh --catalogue <path>       # for testing this script
#
# Exit status: 1 if anything fails to resolve.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_DIR=$(CDPATH= cd -- "$HERE/.." && pwd)

# The floor. 7.1 (Oct 2023) is the oldest series plausibly running in a repo this skill
# targets; below it the catalogue's fail-closed rule applies and no link is emitted at all.
# Widening this is one string — and then re-running this script is what makes it true.
ALL_SERIES="8.1 8.0 7.2 7.1"

CATALOGUE=$SKILL_DIR/references/rails-docs.md
SERIES=$ALL_SERIES
JOBS=12
CACHE=""
QUIET=0

while [ $# -gt 0 ]; do
  case $1 in
    --series) SERIES=$2; shift 2 ;;
    --catalogue) CATALOGUE=$2; shift 2 ;;
    -j|--jobs) JOBS=$2; shift 2 ;;
    --cache) CACHE=$2; shift 2 ;;
    -q|--quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,47p' "$0"; exit 0 ;;
    *) echo "verify-catalogue.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ "$SERIES" = "all" ] && SERIES=$ALL_SERIES

[ -r "$CATALOGUE" ] || { echo "verify-catalogue.sh: no catalogue at $CATALOGUE" >&2; exit 2; }
command -v curl >/dev/null 2>&1 || { echo "verify-catalogue.sh: needs curl" >&2; exit 2; }

TMP=$(mktemp -d)
if [ -n "$CACHE" ]; then mkdir -p "$CACHE"; PAGES=$CACHE; else PAGES=$TMP/pages; mkdir -p "$PAGES"; fi
trap 'rm -rf "$TMP"' EXIT

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
cachename() { printf '%s' "$1" | tr '/:?&#={}' '________'; }
CAT_NAME=$(basename "$CATALOGUE")

# ---------------------------------------------------------------- 1 · the rows
#
# One record per (row, kind, applicability): line|concept|kind|applies|path.
#
# `applies` is `*` for the bare path and a series for an override. A cell may carry both:
#
#   `ActiveRecord/Relation.html#method-i-insert_all` · 7.1: `ActiveRecord/Persistence/…`
#
# so cells are split on `·` first and each segment tested for a leading `<series>:`. Doing it
# the other way round — scanning backticks across the whole cell — is what would silently
# check an override against the wrong series and call the row clean.
awk -F'|' '
  function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
  /^\|/ && !/^\|[[:space:]]*-/ && !/^\|[[:space:]]*(Concept|Gem|Concept the reviewer meets)[[:space:]]*\|/ {
    concept = trim($2); gsub(/`/, "", concept); gsub(/ ‡.*$/, "", concept)
    for (i = 3; i <= NF; i++) {
      n = split($i, seg, "·")
      for (s = 1; s <= n; s++) {
        part = seg[s]; applies = "*"
        if (match(part, /^[[:space:]]*[0-9]+\.[0-9]+:/)) {
          applies = trim(substr(part, RSTART, RLENGTH - 1))
          part = substr(part, RSTART + RLENGTH)
        }
        if (!match(part, /`[^`]+`/)) continue
        tok = substr(part, RSTART + 1, RLENGTH - 2)
        kind = ""
        if (tok ~ /^https:\/\//)                                           kind = "gem"
        else if (tok ~ /^[a-z_]+\.html(#.*)?$/)                            kind = "guide"
        else if (tok ~ /^[A-Z][A-Za-z0-9]*(\/[A-Za-z0-9]+)*\.html(#.*)?$/) kind = "api"
        if (kind != "") print NR "|" concept "|" kind "|" applies "|" tok
      }
    }
  }
' "$CATALOGUE" | sort -u > "$TMP/rows"

nrows=$(awk -F'|' '{print $1}' "$TMP/rows" | sort -u | wc -l | tr -d ' ')
npaths=$(wc -l < "$TMP/rows" | tr -d ' ')
novr=$(awk -F'|' '$4 != "*"' "$TMP/rows" | wc -l | tr -d ' ')
say "$CAT_NAME: $npaths path(s) across $nrows row(s), $novr per-series override(s)"
say "series: $SERIES"

# ---------------------------------------------------------------- 2 · gem versions
#
# A gem row pins to the gem, not to Rails, so it is checked once at the newest release.
# The gem name is the last segment of the repository path, which holds for every row here
# (ankane/strong_migrations, varvet/pundit, rspec/rspec-rails …) and is checked below by the
# tag resolving at all: a wrong gem name yields a version that has no tag.
: > "$TMP/gemver"
awk -F'|' '$3=="gem" && $5 ~ /\{version\}/ {print $5}' "$TMP/rows" \
  | sed 's|^https://github\.com/||; s|/tree/.*||' | sort -u > "$TMP/repos"
while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  gem=${repo##*/}
  v=$(curl -sS -m 25 "https://rubygems.org/api/v1/gems/$gem.json" 2>/dev/null \
      | grep -o '"version":"[^"]*"' | head -1 | sed 's/.*:"//; s/"$//')
  if [ -n "$v" ]; then echo "$repo $v" >> "$TMP/gemver"
  else say "  ! rubygems knows no gem named '$gem' (from $repo) — its rows cannot be checked"; fi
done < "$TMP/repos"
[ -s "$TMP/gemver" ] && say "gems: $(awk '{printf "%s@%s ", $1, $2}' "$TMP/gemver")"

# ---------------------------------------------------------------- 3 · the work list
#
# One line per URL a run could actually emit: series|line|concept|kind|url.
: > "$TMP/work"
for s in $SERIES; do
  while IFS='|' read -r line concept kind applies path; do
    case $kind in
      gem)
        # Rails-series-independent: emitted once, under the first series, so it is not
        # counted four times and reported as four defects for one broken tag.
        [ "$s" = "${SERIES%% *}" ] || continue
        repo=$(printf '%s' "$path" | sed 's|^https://github\.com/||; s|/tree/.*||')
        gv=$(awk -v r="$repo" '$1==r{print $2}' "$TMP/gemver")
        if [ -z "$gv" ]; then
          case $path in *\{version\}*) continue ;; esac       # unresolvable, already warned
        fi
        url=$(printf '%s' "$path" | sed "s|{version}|$gv|")
        ;;
      guide)
        # An override wins for its series; the bare path applies where none does.
        if [ "$applies" != "*" ] && [ "$applies" != "$s" ]; then continue; fi
        if [ "$applies" = "*" ] && awk -F'|' -v l="$line" -v k="$kind" -v s="$s" \
             '$1==l && $3==k && $4==s {found=1} END{exit !found}' "$TMP/rows"; then continue; fi
        url="https://guides.rubyonrails.org/v$s/$path"
        ;;
      api)
        if [ "$applies" != "*" ] && [ "$applies" != "$s" ]; then continue; fi
        if [ "$applies" = "*" ] && awk -F'|' -v l="$line" -v k="$kind" -v s="$s" \
             '$1==l && $3==k && $4==s {found=1} END{exit !found}' "$TMP/rows"; then continue; fi
        url="https://api.rubyonrails.org/v$s/classes/$path"
        ;;
    esac
    echo "$s|$line|$concept|$kind|$url" >> "$TMP/work"
  done < "$TMP/rows"
done

# ---------------------------------------------------------------- 4 · fetch, once per page
awk -F'|' '{sub(/#.*/, "", $5); print $5}' "$TMP/work" | sort -u > "$TMP/bases"
nbases=$(wc -l < "$TMP/bases" | tr -d ' ')
nwork=$(wc -l < "$TMP/work" | tr -d ' ')
say "checking $nwork URL(s) over $nbases distinct page(s), $JOBS parallel job(s)…"

cat > "$TMP/fetch.sh" <<'EOS'
#!/bin/sh
url=$1; dir=$2
f=$dir/$(printf '%s' "$url" | tr '/:?&#={}' '________')
[ -s "$f" ] && [ -s "$f.code" ] && exit 0
code=$(curl -sSL -m 40 -o "$f" -w '%{http_code}' "$url" 2>/dev/null || echo 000)
printf '%s' "$code" > "$f.code"
EOS
chmod +x "$TMP/fetch.sh"
xargs -P "$JOBS" -I{} "$TMP/fetch.sh" {} "$PAGES" < "$TMP/bases"

# ---------------------------------------------------------------- 5 · evaluate
#
# A dead page needs a new URL. A page that resolves without the fragment is a dead ANCHOR,
# which the catalogue rates as survivable — a browser ignores what it cannot find and the
# reader lands at the top of the right page — so the two are reported apart.
#
# Fragment forms accepted: the id or name itself, GitHub's user-content- prefix on README
# headings, and a self-link, which is how both generators emit their tables of contents.
: > "$TMP/results"
while IFS='|' read -r s line concept kind url; do
  base=$(printf '%s' "$url" | sed 's/#.*//')
  frag=$(printf '%s' "$url" | sed -n 's/^[^#]*#//p')
  f=$PAGES/$(cachename "$base")
  code=$(cat "$f.code" 2>/dev/null || echo 000)
  if [ "$code" != "200" ]; then
    echo "$s|PAGE|$code|$line|$concept|$url" >> "$TMP/results"
  elif [ -z "$frag" ]; then
    echo "$s|OK|-|$line|$concept|$url" >> "$TMP/results"
  elif grep -Fq "id=\"$frag\"" "$f" || grep -Fq "name=\"$frag\"" "$f" \
    || grep -Fq "id=\"user-content-$frag\"" "$f" || grep -Fq "href=\"#$frag\"" "$f"; then
    echo "$s|OK|-|$line|$concept|$url" >> "$TMP/results"
  else
    echo "$s|FRAG|-|$line|$concept|$url" >> "$TMP/results"
  fi
done < "$TMP/work"

# ---------------------------------------------------------------- 6 · report
say ""
fail=0
for kind in PAGE FRAG; do
  n=$(awk -F'|' -v k=$kind '$2==k' "$TMP/results" | wc -l | tr -d ' ')
  [ "$n" -eq 0 ] && continue
  fail=$((fail + n))
  if [ "$kind" = PAGE ]; then say "$n dead page(s) — the row needs a new URL or an override:"
  else say "$n dead anchor(s) — drop the fragment, or add an override for the series that renamed it:"; fi
  awk -F'|' -v k=$kind '$2==k {
    printf "  [%s] %s:%s  %s\n", $1, CAT, $4, $6
    printf "        row: %s%s\n", $5, ($3 != "-" ? "   [HTTP " $3 "]" : "")
  }' CAT="$CAT_NAME" "$TMP/results" | while IFS= read -r l; do say "$l"; done
  say ""
done

nok=$(awk -F'|' '$2=="OK"' "$TMP/results" | wc -l | tr -d ' ')
if [ "$fail" -eq 0 ]; then
  say "$nok/$nwork resolve, fragments included — every row is good for every series in the floor"
  say ""
  say "verify-catalogue.sh: clean ($(date +%Y-%m-%d)) · series: $SERIES"
  say "  Record the date and this series list in $CAT_NAME § Version."
  exit 0
fi
say "verify-catalogue.sh: $fail defect(s) · $nok/$nwork resolve"
exit 1
