#!/bin/sh
# verify-catalogue.sh — opens every URL in a catalogue, in the pinned form a run actually
# emits: references/rails-docs.md for every Rails series it claims to serve, and
# references/elixir-docs.md at each package's newest release.
#
# THE ELIXIR CATALOGUE IS CLOSED UNTIL THIS SCRIPT OPENS IT. elixir-docs.md § Version
# withholds every link in the file — a run emits none, and anchors with probes instead —
# because no row in it has been opened. That is the fail-closed rule at file scope rather
# than row scope, and this script is the whole of what lifts it: a clean run prints a dated
# line, and that line replaces the withhold in § Version in the same commit. So this is not
# optional maintenance for that file the way it is for the Rails one; it is the file's
# release gate.
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
# inside a skill run, and it lives beside evals/ rather than under checks/ because check.rb
# dispatches offline rules over a page and this needs the network.
#
# THE ALLOWLIST IS THE TABLE ROWS, not the file. The prose quotes URLs it is warning about,
# and a whole-file sweep would verify the warnings. Same rule as checks/rails-anchors.rb.
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
# HEXDOCS ROWS WORK THE SAME WAY, and for the same reason. An Elixir app pins each package
# independently from mix.lock and hexdocs serves exact versions rather than a series prefix,
# so there is no series axis to expand along — each row is checked once, at its package's
# newest stable release from hex.pm. The per-package floor in elixir-docs.md § Version is
# prose there for the same reason the per-gem floor is: this script cannot enumerate it, and
# checking every package across its own floor would multiply the work list without telling
# you anything the newest release does not.
#
# The package is the FIRST SEGMENT of a stored hexdocs path, which is why the paths carry it:
# `ecto/Ecto.Changeset.html#cast/4`. Ecto.Migration under `ecto` rather than `ecto_sql` is a
# 404 that reads as correct, and keeping the package in the path is what makes it checkable
# here and in checks/rails-anchors.rb.
#
# Usage:
#   ./verify-catalogue.sh                          # the whole floor
#   ./verify-catalogue.sh --series "8.1 8.0"       # just these
#   ./verify-catalogue.sh -j 16 --cache /tmp/cat   # reuse a warm cache between runs
#   ./verify-catalogue.sh --catalogue <path>       # another catalogue, or for testing this
#   ./verify-catalogue.sh --catalogue ../references/elixir-docs.md   # the Elixir one
#   ./verify-catalogue.sh --catalogue ... --elixir-version 1.18.3    # when the GitHub API is blocked
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

# The Elixir standard library ships WITH Elixir, so hex.pm has no package for it and the
# per-package resolution below returns nothing for elixir, eex, ex_unit, iex, logger and mix.
# hexdocs hosts them all the same, at the Elixir release version. That version comes from
# elixir-lang's own releases, with --elixir-version as the override for a network that cannot
# reach the GitHub API — an explicit flag rather than a hard-coded default, because a default
# goes stale silently and stale-and-silent is the failure this whole script exists to catch.
STDLIB_PKGS=" elixir eex ex_unit iex logger mix "
ELIXIR_VERSION=""

JOBS=12
CACHE=""
QUIET=0

while [ $# -gt 0 ]; do
  case $1 in
    --series) SERIES=$2; shift 2 ;;
    --elixir-version) ELIXIR_VERSION=$2; shift 2 ;;
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
  /^\|/ && !/^\|[[:space:]]*-/ && !/^\|[[:space:]]*(Concept|Gem|Anchor|Mark|Row|Concept the reviewer meets)[[:space:]]*\|/ {
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
        # A hexdocs path leads with its PACKAGE, lowercase, then a slash: the one shape that
        # starts lowercase and still contains a separator, so it is unambiguous against the
        # two Rails kinds above (a guide has no slash, an api starts uppercase).
        else if (tok ~ /^[a-z][a-z0-9_]*\/[A-Za-z0-9_.]+\.html(#.*)?$/)    kind = "hex"
        if (kind != "") print NR "|" concept "|" kind "|" applies "|" tok
      }
    }
  }
' "$CATALOGUE" | sort -u > "$TMP/rows"

nrows=$(awk -F'|' '{print $1}' "$TMP/rows" | sort -u | wc -l | tr -d ' ')
npaths=$(wc -l < "$TMP/rows" | tr -d ' ')
novr=$(awk -F'|' '$4 != "*"' "$TMP/rows" | wc -l | tr -d ' ')
say "$CAT_NAME: $npaths path(s) across $nrows row(s), $novr per-series override(s)"

# A catalogue with no Rails rows has no series axis, and expanding one would print a floor
# that means nothing about it while checking every hexdocs row four times over — the hex arm
# emits under the first series only, so the extra passes are pure noise in the log. Collapse
# it and say why, rather than leaving the reader to reconcile "series: 8.1 8.0 7.2 7.1" with
# a file that pins per package.
nrails=$(awk -F'|' '$3=="guide" || $3=="api"' "$TMP/rows" | wc -l | tr -d ' ')
nhex=$(awk -F'|' '$3=="hex"' "$TMP/rows" | wc -l | tr -d ' ')
if [ "$nrails" -eq 0 ] && [ "$nhex" -gt 0 ]; then
  SERIES=${SERIES%% *}
  say "no Rails rows: the series axis does not apply, and each hexdocs row is checked once at"
  say "its package's newest stable release. Per-package floors are prose in the catalogue."
else
  say "series: $SERIES"
fi

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

# ------------------------------------------------------- 2b · hex package versions
#
# One request per package, not per row: a catalogue with fifteen Ecto rows asks hex.pm once.
# latest_stable_version is what a lock file would realistically hold; a package with only
# pre-releases yields nothing and its rows are skipped with a warning rather than checked at
# a version that does not exist.
: > "$TMP/hexver"
awk -F'|' '$3=="hex" {print $5}' "$TMP/rows" | sed 's|/.*||' | sort -u > "$TMP/pkgs"
while IFS= read -r pkg; do
  [ -n "$pkg" ] || continue
  case $STDLIB_PKGS in
    *" $pkg "*)
      # Standard library: one version for all six, and it is Elixir's own.
      if [ -z "$ELIXIR_VERSION" ]; then
        ELIXIR_VERSION=$(curl -sS -m 25 "https://api.github.com/repos/elixir-lang/elixir/releases/latest" 2>/dev/null \
          | grep -o '"tag_name":"[^"]*"' | head -1 | sed 's/.*:"v\{0,1\}//; s/"$//')
      fi
      if [ -n "$ELIXIR_VERSION" ]; then echo "$pkg $ELIXIR_VERSION" >> "$TMP/hexver"
      else say "  ! '$pkg' ships with Elixir and hex.pm has no package for it; could not reach the"
           say "    GitHub API for the Elixir release either — pass --elixir-version X to check its rows"; fi
      continue ;;
  esac
  v=$(curl -sS -m 25 "https://hex.pm/api/packages/$pkg" 2>/dev/null \
      | grep -o '"latest_stable_version":"[^"]*"' | head -1 | sed 's/.*:"//; s/"$//')
  if [ -n "$v" ]; then echo "$pkg $v" >> "$TMP/hexver"
  else say "  ! hex.pm knows no stable release of '$pkg' — its rows cannot be checked"; fi
done < "$TMP/pkgs"
[ -s "$TMP/hexver" ] && say "packages: $(awk '{printf "%s@%s ", $1, $2}' "$TMP/hexver")"

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
      hex)
        # Rails-series-independent, like a gem row: emitted once, under the first series, so
        # one broken path is one defect rather than one per series. The version goes in after
        # the package, which is the first path segment.
        [ "$s" = "${SERIES%% *}" ] || continue
        pkg=${path%%/*}; rest=${path#*/}
        hv=$(awk -v pp="$pkg" '$1==pp{print $2}' "$TMP/hexver")
        [ -n "$hv" ] || continue                              # unresolvable, already warned
        url="https://hexdocs.pm/$pkg/$hv/$rest"
        # The report's first column labels a row with what varies about it. For a Rails row
        # that is the series; for a hexdocs row the series is meaningless and the package
        # version is the thing a reader needs in order to go and look.
        echo "$pkg@$hv|$line|$concept|$kind|$url" >> "$TMP/work"
        continue
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
  if [ "$nrails" -eq 0 ] && [ "$nhex" -gt 0 ]; then
    say "$nok/$nwork resolve, fragments included — every row is good at its package's newest release"
    say ""
    say "verify-catalogue.sh: clean ($(date +%Y-%m-%d)) · packages: $(awk '{printf "%s@%s ", $1, $2}' "$TMP/hexver")"
    say "  Record the date and these versions in $CAT_NAME § Version."
    say "  For elixir-docs.md that record REPLACES the withhold: until it is there, a run emits"
    say "  no link from the file at all. Opening it is the point of this run."
  else
    say "$nok/$nwork resolve, fragments included — every row is good for every series in the floor"
    say ""
    say "verify-catalogue.sh: clean ($(date +%Y-%m-%d)) · series: $SERIES"
    say "  Record the date and this series list in $CAT_NAME § Version."
  fi
  exit 0
fi
say "verify-catalogue.sh: $fail defect(s) · $nok/$nwork resolve"
exit 1
