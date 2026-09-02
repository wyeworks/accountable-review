#!/bin/sh
# rails-anchors.sh — the three framework anchors: documentation links, runtime probes,
# and the primer callout a link escalates into.
#
# All three exist to make a claim about Rails followable. All three fail in ways that look
# like diligence, which is why they are checked mechanically rather than trusted:
#
#   a URL nobody opened            reads as a citation, resolves to a 404
#   a doc link with no file:line   reads as evidence, says nothing about this repo
#   a probe with output beneath it reads as the most concrete thing on the page,
#                                 and is the one part of it that is fiction
#   a probe naming a missing scope reads as pasteable, fails on first paste
#   a demo naming an app class     reads as a quotation of the manual and is a claim
#                                 about this application that nobody ran
#   a primer on every mechanism    reads as thoroughness and is a Rails manual with a
#                                 diff attached
#
# The catalogue is the allowlist, and this script derives it from the file rather than
# hard-coding hosts: references/rails-docs.md is the single home for what may be cited,
# so a row added there is immediately legal here and a URL invented in a run is not.
#
# What needs a reader, and lives in the case: whether the link is the RIGHT concept for
# the claim, and whether the probe is the one worth proposing. This settles only whether
# what is on offer is real.
#
# --repo is what makes rule 7 possible, the way it makes searches.sh possible. Without it
# the identifier check SKIPs rather than passing on evidence it does not have.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_input

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

CATALOGUE=$SKILL_DIR/references/rails-docs.md

unesc() { sed -e 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;/'"'"'/g'; }

# ---------------------------------------------------------------- doc links
#
# Every href a READER can follow out of the page, which means <a> only. Not <link>: a
# stylesheet or a font is an asset, not a citation, and a whole-page grep for href pulled in
# the template's own fonts.googleapis.com tags and failed every real page for it. The tag has
# to open and carry its href on one line, which is how the template writes them.
#
# github.com is not excluded wholesale: a gem's README anchor is a legitimate doc link and lives in the
# catalogue like any other, while a blob/pull/compare URL is a code permalink and belongs
# to the deep-link ladder, which page-invariants.sh § 5 owns.
#
# `tree/` is NOT excluded, though it once was. A tag-pinned gem README — the only github.com
# shape a doc link may take — is exactly `tree/v2.8.0#section`, so excluding it meant the one
# github doc link the catalogue offers was the one nothing checked. The deep-link ladder does
# not emit `tree/` for the repo under review (blob at a sha, or pull/compare), so nothing
# legitimate is caught by tightening this.
grep -oE '<a [^>]*href="[^"]*"' "$IN" 2>/dev/null | grep -o 'href="[^"]*"' | sed 's/href="//; s/"$//' | unesc \
  | grep -E '^https?://' \
  | grep -Ev '^https://github\.com/[^/]+/[^/]+/(blob|pull|compare|commit)/' \
  | sort -u > "$TMP/external" || true

next=$(grep -c . "$TMP/external" 2>/dev/null || true)
if [ "${next:-0}" -eq 0 ]; then
  skip "doc links: none on this input"
else
  if [ ! -r "$CATALOGUE" ]; then
    bad "doc links: the catalogue is missing at references/rails-docs.md — nothing can be checked against it"
  else
    # The allowlist is the TABLE ROWS, not the file. The file's prose quotes URLs it is
    # warning about — the dead Persistence/ClassMethods anchor is named there precisely so
    # nobody re-adds it — and a whole-file grep would allowlist every one of those. A URL
    # is legal because a row offers it, never because the file mentions it.
    #
    # Rows are parsed into `line|applies|path` the way verify-catalogue.sh does: cells split
    # on `·` first, each segment tested for a leading `<series>:`. That is what makes the
    # series rule below possible — an override is legal for ITS series and no other, and the
    # only way to know which is to keep the two attached while parsing.
    awk -F'|' '
      function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
      /^\|/ && !/^\|[[:space:]]*-/ {
        for (i = 3; i <= NF; i++) {
          n = split($i, seg, "·")
          for (s = 1; s <= n; s++) {
            part = seg[s]; applies = "*"
            if (match(part, /^[[:space:]]*[0-9]+\.[0-9]+:/)) {
              applies = trim(substr(part, RSTART, RLENGTH - 1)); part = substr(part, RSTART + RLENGTH)
            }
            if (!match(part, /`[^`]+`/)) continue
            print NR "|" applies "|" substr(part, RSTART + 1, RLENGTH - 2)
          }
        }
      }
    ' "$CATALOGUE" | sort -u > "$TMP/cat-paths"

    # Rails doc links only, partitioned by whether they carry a version segment. The test is
    # /v<digit>, NOT /v — a guide page whose name merely begins with the letter v
    # (`validations.html`) took the "pinned" branch under a /v* glob, yielded no series, and
    # so was recorded in neither list and checked by neither rule.
    grep -E '^https://(guides|api)\.rubyonrails\.org/' "$TMP/external" > "$TMP/rails-links" || true
    nrails=$(grep -c . "$TMP/rails-links" 2>/dev/null || true)
    grep -E '^https://(guides|api)\.rubyonrails\.org/v[0-9]' "$TMP/rails-links" > "$TMP/pinned" || true
    grep -Ev '^https://(guides|api)\.rubyonrails\.org/v[0-9]' "$TMP/rails-links" > "$TMP/unpinned" || true
    sed -n 's|^https://[a-z.]*rubyonrails\.org/v\([0-9][0-9.]*\)/.*|\1|p' "$TMP/pinned" | sort -u > "$TMP/seen-series"

    # Pinning, rule 1: a Rails doc link must carry a version segment. An unpinned one
    # silently means current stable, which is the defect the pinning rule exists for — a
    # 7.1 app handed 8.1 documentation with nothing on the page to notice it with.
    #
    # Skipped rather than passed when the page has no Rails doc link at all: "every link is
    # pinned" over an empty set is a PASS that reads as verification of something nobody
    # checked, which is the same defect as a SKIP that reads as verified, in reverse.
    if [ "${nrails:-0}" -eq 0 ]; then
      skip "pinning: no Rails documentation links on this input"
    else
      nunp=$(grep -c . "$TMP/unpinned" 2>/dev/null || true)
      if [ "${nunp:-0}" -eq 0 ]; then
        ok "all $nrails Rails doc link(s) carry a version segment"
      else
        bad "$nunp unpinned Rails doc link(s) — an unpinned path silently means current stable: $(tr '\n' ' ' < "$TMP/unpinned")"
      fi

      # Pinning, rule 2: one app, one series. A page mixing /v7.1/ and /v8.0/ has pinned from
      # something other than this repo's Gemfile.lock, and the reader cannot tell which link
      # describes their app.
      nsee=$(grep -c . "$TMP/seen-series" 2>/dev/null || true)
      if [ "${nsee:-0}" -gt 1 ]; then
        bad "doc links pinned to $nsee different Rails series — one app has one version: $(tr '\n' ' ' < "$TMP/seen-series")"
      elif [ "${nsee:-0}" -eq 1 ]; then
        ok "all doc links pinned to one series (v$(cat "$TMP/seen-series"))"
      fi
    fi

    # Pinning, rule 3: an unsubstituted placeholder. `tree/v{version}` is the literal the
    # catalogue stores, so it matches its own row perfectly and is invisible to the allowlist
    # test — while being a guaranteed 404. Forgetting the substitution is the most likely
    # mechanical failure of gem pinning, so it gets a rule of its own rather than relying on
    # a rule about something else to catch it.
    if grep -Fq '{version}' "$TMP/external" || grep -Fq '%7Bversion%7D' "$TMP/external"; then
      bad "a doc link still carries the {version} placeholder — the catalogue's path reached the page unsubstituted: $(grep -E '\{version\}|%7Bversion%7D' "$TMP/external" | head -1)"
    else
      ok "no unsubstituted {version} placeholder"
    fi

    PAGE_SERIES=$(cat "$TMP/seen-series" 2>/dev/null | head -1)
    : > "$TMP/bad-urls"
    : > "$TMP/wrong-series"
    while IFS= read -r url; do
      [ -n "$url" ] || continue
      # The page emits PINNED URLs; the catalogue stores unpinned paths, so the version
      # segment comes off before matching. A gem tag is reduced to the {version} placeholder
      # the row actually carries.
      needle=$(printf '%s' "$url" \
        | sed -e 's|^https://guides\.rubyonrails\.org/v[0-9][0-9.]*/||' \
              -e 's|^https://guides\.rubyonrails\.org/||' \
              -e 's|^https://api\.rubyonrails\.org/v[0-9][0-9.]*/classes/||' \
              -e 's|^https://api\.rubyonrails\.org/classes/||' \
              -e 's|/tree/v[0-9][0-9A-Za-z.-]*|/tree/v{version}|')
      # Matched as a WHOLE backticked token, never as a substring. A bare `grep -F` on the
      # path passed `guides.rubyonrails.org/v8.0/validations.html` — an HTTP 404 — because
      # `validations.html` is a substring of the catalogued `active_record_validations.html`.
      # The one rule whose stated purpose is "a URL nobody opened is a 404 the reader finds"
      # was passing a 404.
      hits=$(awk -F'|' -v n="$needle" '$3 == n {print $2}' "$TMP/cat-paths")
      if [ -z "$hits" ]; then
        # A fragment the catalogue does not carry is still legal if the page it hangs off is
        # catalogued: landing at the top of the right page is an outcome the catalogue
        # explicitly prefers to a guessed anchor.
        base=${needle%%#*}
        if [ "$base" != "$needle" ] && awk -F'|' -v n="$base" '$3 == n {found=1} END{exit !found}' "$TMP/cat-paths"; then
          continue
        fi
        echo "$url" >> "$TMP/bad-urls"
        continue
      fi
      # Rule 4: the path has to be catalogued FOR THIS SERIES. A per-series override is the
      # right URL for one series and the wrong page for every other — pinning
      # `Persistence/ClassMethods.html#method-i-insert_all` at v8.0 returns HTTP 200 on a
      # page that never mentions the method, which § Version calls out as worse than a 404.
      case $hits in
        *'*'*) ;;                                   # a bare path applies unless overridden
        *)
          if [ -n "$PAGE_SERIES" ] && ! printf '%s\n' "$hits" | grep -Fqx "$PAGE_SERIES"; then
            echo "$url  [catalogued only for series $(printf '%s' "$hits" | tr '\n' ' ')— page is pinned at $PAGE_SERIES]" >> "$TMP/wrong-series"
          fi ;;
      esac
    done < "$TMP/external"

    nbad=$(grep -c . "$TMP/bad-urls" 2>/dev/null || true)
    if [ "${nbad:-0}" -eq 0 ]; then
      ok "$next documentation link(s), all from the catalogue"
    else
      bad "$nbad documentation link(s) not in references/rails-docs.md — a URL nobody opened is a 404 the reader finds: $(tr '\n' ' ' < "$TMP/bad-urls")"
    fi

    nws=$(grep -c . "$TMP/wrong-series" 2>/dev/null || true)
    if [ "${nws:-0}" -eq 0 ]; then
      ok "no doc link uses another series' override path"
    else
      bad "$nws doc link(s) pinned to a series the catalogue does not offer that path for: $(head -1 "$TMP/wrong-series")"
    fi
  fi

  # A doc link is provenance. The claim it decorates still has to cite this repository,
  # so the element carrying the link needs a file:line — its own, not one from elsewhere
  # on the page. Scoped to the .item/dd the link sits in, one line at a time, because
  # that is the unit the rule is written about.
  #
  # Blocked, not line-by-line: HTML wraps, and the rule is about the FIELD carrying the
  # link, not about one physical line. A line-based test failed the template's own
  # example, where the citation and the link sit on consecutive lines.
  #
  # A primer is judged as ONE block, so it is flattened to a single line first. Its link
  # and the citation that earned it sit in different children of the aside, and the rule is
  # about the callout having a stake in this repository — not about which child holds the
  # path. Flattening plus the two extra break tokens below also stop it working in the other
  # direction: a primer with no citation of its own cannot borrow the one in the .item that
  # happens to precede it.
  awk '
    /<aside class="primer/ { p = 1; buf2 = "" }
    p { buf2 = buf2 " " $0; if ($0 ~ /<\/aside>/) { print buf2; p = 0 }; next }
    { print }
  ' "$IN" > "$TMP/flat"
  awk '
    /<div class="item"|<dd>|<dt>|<\/dd>|<aside class="primer|<\/aside>/ { if (buf != "") { print buf; buf = "" } }
    { buf = buf " " $0 }
    END { if (buf != "") print buf }
  ' "$TMP/flat" | grep 'class="doc"' | unesc > "$TMP/doc-lines"
  alone=0
  while IFS= read -r ln; do
    [ -n "$ln" ] || continue
    case $ln in
      *class=\"path\"*|*class=\"cite\"*) continue ;;
    esac
    # A bare path:line with no anchor counts too — that is the rung-3 and rung-4 form.
    if printf '%s' "$ln" | grep -Eq '[A-Za-z0-9_./-]+\.(rb|rake|erb|ts|tsx|js|jsx|yml|yaml|sql|json):[0-9]+'; then
      continue
    fi
    alone=$((alone + 1))
  done < "$TMP/doc-lines"
  if [ "$alone" -eq 0 ]; then
    ok "every documentation link sits beside a repository citation"
  else
    bad "$alone documentation link(s) with no file:line beside them — a link to the Rails guides says nothing about this repository"
  fi

  # The page must read complete with every excerpt closed, so a link inside one is a link
  # the reader of the closed page never sees.
  if awk '/<details class="excerpt/{d=1} d&&/class="doc"/{found=1} /<\/details>/{d=0} END{exit !found}' "$IN"; then
    bad "a documentation link is inside a collapsed excerpt — the page has to read complete with every excerpt closed"
  else
    ok "no documentation link hidden inside an excerpt"
  fi

  # The budget's mechanical edge. One per field is the rule; a page where most fields
  # carry one has stopped selecting, and that needs a reader.
  fields=$(grep -c '<dt>' "$IN" 2>/dev/null || true)
  if [ "${fields:-0}" -gt 0 ] && [ "$next" -gt "$fields" ]; then
    maybe "$next doc link(s) across $fields field(s) — at most one per field, and a page near that ratio has stopped selecting"
  fi
fi

# ---------------------------------------------------------------- primer callouts
#
# The primer is the heaviest thing on the page that carries no evidence of its own, which
# makes it the one most able to turn the report into a Rails manual with a diff attached.
# The rules below are the mechanical half of the budget; whether a particular primer was
# earned needs a reader and lives in the case.
#
# LEVEL-INDEPENDENT, deliberately. A primer lives inside a behaviour flow, and §§ 1-3 are
# the same spec at both detail levels, so nothing here reads LEVEL — before-approving.sh
# stays the only check that knows it.
nprimer=$(grep -c '<aside class="primer' "$IN" 2>/dev/null || true)
ndemo=$(grep -c '<pre class="demo"' "$IN" 2>/dev/null || true)
if [ "${nprimer:-0}" -eq 0 ] && [ "${ndemo:-0}" -eq 0 ]; then
  skip "primer callouts: none on this input"
else
  # The budget, and where a primer may live. At most one per behaviour flow, and none
  #     outside one: a primer explains a mechanism some flow is about, and one adrift in
  #     section 4 or 6 is a lesson with no behaviour attached to it. Counted per flow rather
  #     than per page, because the cap scales with the flow count and a page-wide number
  #     would mean nothing.
  set -- $(awk '
    /<section [^>]*id="flow-/            { inflow = 1; here = 0 }
    /<aside class="primer/              { if (inflow) { here++; if (here > 1) over++ } else loose++ }
    /<\/section>/                        { inflow = 0 }
    END { print over + 0, loose + 0 }
  ' "$IN")
  over=$1; loose=$2
  if [ "$over" -gt 0 ]; then
    bad "$over flow(s) carry more than one primer — at most one per flow, and a flow needing two is a flow explaining Rails rather than its own change"
  elif [ "$loose" -gt 0 ]; then
    bad "$loose primer(s) sit outside a <section id=\"flow-...\"> — a primer explains a mechanism a flow is about, and one on its own is a lesson with no behaviour attached"
  elif [ "${nprimer:-0}" -gt 0 ]; then
    ok "$nprimer primer(s), at most one per flow and each inside the flow it explains"
  fi

  # A primer carries a doc link. It is what a link escalates INTO, so one without a link
  #     has kept the teaching and dropped the provenance — the shape that reads most like a
  #     tutorial. Its own citation is checked by the citation rule above, which now sees the whole aside.
  nolink=$(awk '
    /<aside class="primer/ { p = 1; has = 0 }
    p && /class="doc"/      { has = 1 }
    /<\/aside>/             { if (p && !has) miss++; p = 0 }
    END { print miss + 0 }
  ' "$IN")
  if [ "$nolink" -gt 0 ]; then
    bad "$nolink primer(s) carry no documentation link — a primer is what a link escalates into, so one without a link is teaching with no provenance"
  elif [ "${nprimer:-0}" -gt 0 ]; then
    ok "every primer carries the documentation link it escalated from"
  fi

  # pre.demo only ever inside a primer. THE LOAD-BEARING ONE: a demo may show a "# =>"
  #     line because it quotes the manual, so a demo loose on the page is a general-purpose
  #     hole for output nobody observed, straight past rule 5. The two blocks are separate
  #     classes for exactly this reason and must never be merged.
  loosedemo=$(awk '
    /<aside class="primer/ { p = 1 }
    /<pre class="demo"/     { if (!p) n++ }
    /<\/aside>/             { p = 0 }
    END { print n + 0 }
  ' "$IN")
  if [ "$loosedemo" -gt 0 ]; then
    bad "$loosedemo pre.demo block(s) outside a primer — a demo may show a result only because it quotes the manual, so one loose on the page is fabricated output with the rule turned off"
  elif [ "${ndemo:-0}" -gt 0 ]; then
    ok "$ndemo demo block(s), all inside the primer that licenses them"
  fi

  # The Rails mark is only worn by a Rails primer, and never without the notice. The
  # component takes anything the catalogue carries — a gem, a client library — and
  # .primer--lib is that variant: no mark, a neutral rule, no trademark line. The two
  # failures worth catching are both attributions rather than layout. A gem primer wearing
  # the Rails logotype says the Rails Foundation wrote that gem; the logotype with no
  # .pr-tm shows someone's mark without saying whose it is. Neither looks wrong on the
  # page, which is why neither is left to the eye.
  set -- $(awk '
    /<aside class="primer/ { p = 1; mark = 0; tm = 0; rails = 0 }
    p && /class="pr-mark"/                             { mark = 1 }
    p && /class="pr-tm"/                               { tm = 1 }
    p && /rubyonrails\.org/                            { rails = 1 }
    /<\/aside>/ { if (p && mark && !rails) badhost++; if (p && mark && !tm) notm++; p = 0 }
    END { print badhost + 0, notm + 0 }
  ' "$IN")
  badhost=$1; notm=$2
  if [ "$badhost" -gt 0 ]; then
    bad "$badhost primer(s) wear the Rails mark with no rubyonrails.org link — the artwork attributes the explanation to Rails, so a gem or a client library takes .primer--lib instead"
  elif [ "$notm" -gt 0 ]; then
    bad "$notm primer(s) show the Rails mark with no trademark line — the .pr-tm row exists to say whose mark is on display, and dropping it is the one part of this component that is not ours to drop"
  else
    ok "the Rails mark appears only on Rails primers, each carrying its trademark line"
  fi

  # The demo's receiver is NOT from this repository — the inverse of rule 7, and the
  #     whole reason a "# =>" is allowed here. A demo on an application class is a claim
  #     about the app under review that the run never made, which is the fiction rule 5
  #     exists to prevent, wearing a different class name.
  if [ "${ndemo:-0}" -eq 0 ]; then
    :
  elif [ -z "$REPO" ]; then
    skip "demo receivers: needs --repo to ask whether the constants are this app's"
  elif [ ! -d "$REPO" ]; then
    bad "demo receivers: --repo is not a directory: $REPO"
  else
    awk '/<pre class="demo"/{d=1} d{print} /<\/pre>/{d=0}' "$IN" \
      | sed -e 's/<[^>]*>//g' | unesc | grep -v '^[[:space:]]*$' > "$TMP/demo-body" || true
    # `Application*` is exempt, and a real run is what found this: a demo reading
    # `class Post < ApplicationRecord` was reported as naming an application class,
    # because every Rails app really does define one. The scaffold base classes —
    # ApplicationRecord, ApplicationController, ApplicationJob, ApplicationPolicy and
    # their kin — exist in every app of their kind and say nothing about THIS one, so
    # naming one is not the defect this rule is looking for. Flagging them made the
    # idiomatic generic receiver the hardest one to write, which is the shape of a rule
    # that punishes correct work.
    grep -oE '\b[A-Z][A-Za-z0-9]*(::[A-Z][A-Za-z0-9]*)*\b' "$TMP/demo-body" \
      | grep -Ev '^(ActiveRecord|ActiveJob|ActiveSupport|ActionController|ActionDispatch|ActionMailer|Rails|JSON|Base|Time|Date|DateTime|Logger|STDOUT|Hash|Array|String|Integer|Float|Object|Kernel|GC|ENV|PP)' \
      | grep -Ev '^(ActiveRecord|ActiveJob|ActiveSupport)::' \
      | grep -Ev '^Application[A-Z]' \
      | sort -u > "$TMP/demo-consts" || true

    : > "$TMP/demo-real"
    while IFS= read -r const; do
      [ -n "$const" ] || continue
      leaf=${const##*::}
      if grep -rEq "^[[:space:]]*(class|module)[[:space:]]+([A-Za-z0-9_:]*::)?$leaf\b" "$REPO" 2>/dev/null; then
        echo "$const" >> "$TMP/demo-real"
      fi
    done < "$TMP/demo-consts"

    nreal=$(grep -c . "$TMP/demo-real" 2>/dev/null || true)
    if [ "${nreal:-0}" -eq 0 ]; then
      ok "every demo receiver is a generic class, so its result lines quote the manual"
    else
      bad "${nreal} demo receiver(s) are classes from this repository — a result line on an application class is output nobody observed: $(tr '\n' ' ' < "$TMP/demo-real")"
    fi
  fi
fi

# ---------------------------------------------------------------- runtime probes
nprobe=$(grep -c 'class="probe"' "$IN" 2>/dev/null || true)
if [ "${nprobe:-0}" -eq 0 ]; then
  skip "runtime probes: none on this input"
  finish
  exit
fi

# The probe bodies. pre.probe may span lines, so take from the opening tag to </pre>.
awk '/<pre class="probe"/{p=1} p{print} /<\/pre>/{p=0}' "$IN" \
  | sed -e 's/<[^>]*>//g' | unesc | grep -v '^[[:space:]]*$' > "$TMP/probe-body" || true

# 5 · No fabricated output. The skill does not run these, so anything that looks like a
#     result is invented. `=>` is the console's own prompt for a return value; a leading
#     SQL keyword is the other common shape.
if grep -Eq '^[[:space:]]*(=>|#[[:space:]]*=>|\[|\{)' "$TMP/probe-body" \
   || grep -Eqi '^[[:space:]]*(SELECT|INSERT|UPDATE|DELETE)[[:space:]]' "$TMP/probe-body"; then
  bad "a probe carries what looks like its own output — the skill never ran it, so a transcript here is fiction: $(grep -Ei -m1 '^[[:space:]]*(=>|#[[:space:]]*=>|\[|\{|SELECT|INSERT|UPDATE|DELETE)' "$TMP/probe-body")"
else
  ok "$nprobe probe(s), none showing output the run did not observe"
fi

# 6 · Safety. A reviewer who pastes what the page told them to must not thereby mutate a
#     database. Writes belong in `console --sandbox`; production is never a target.
if grep -q 'RAILS_ENV=production' "$TMP/probe-body"; then
  bad "a probe names RAILS_ENV=production — these are for the reviewer's own checkout"
else
  ok "no probe targets production"
fi
mutating='create!?\(|update!?\(|update_all|update_column|destroy|delete_all|save!?\b|insert_all|upsert_all|touch\(|archive!'
if grep -E "$mutating" "$TMP/probe-body" > "$TMP/writes" 2>/dev/null; then
  if grep -q 'console --sandbox' "$TMP/probe-body"; then
    ok "a write-shaped probe is present and a sandboxed console is what runs it"
  else
    bad "a probe writes but no 'console --sandbox' is named — bin/rails runner is not sandboxed and the change persists: $(head -1 "$TMP/writes")"
  fi
else
  ok "every probe is read-only"
fi

# 7 · The identifiers are real. Same rule as "validation steps must exist in this repo",
#     and the same reason searches.sh re-runs its searches: a plausible constant is the
#     failure mode, and it is invisible until someone pastes it.
if [ -z "$REPO" ]; then
  skip "probe identifiers: needs --repo to ask whether the constants exist"
elif [ ! -d "$REPO" ]; then
  bad "probe identifiers: --repo is not a directory: $REPO"
else
  # Constants named in the probes, minus the framework's own and Ruby's.
  grep -oE '\b[A-Z][A-Za-z0-9]*(::[A-Z][A-Za-z0-9]*)*\b' "$TMP/probe-body" \
    | grep -Ev '^(ActiveRecord|ActiveJob|ActiveSupport|ActionController|ActionDispatch|ActionMailer|Rails|JSON|Base|Time|Date|DateTime|Logger|STDOUT|Hash|Array|String|Integer|Float|Object|Kernel|GC|ENV|PP)' \
    | grep -Ev '^(ActiveRecord|ActiveJob|ActiveSupport)::' \
    | sort -u > "$TMP/consts" || true

  : > "$TMP/missing"
  while IFS= read -r const; do
    [ -n "$const" ] || continue
    leaf=${const##*::}
    # Defined anywhere in the repository, as a class or module. Ruby's own file naming is
    # not assumed: a grep for the definition is what a reviewer would do.
    if grep -rEq "^[[:space:]]*(class|module)[[:space:]]+([A-Za-z0-9_:]*::)?$leaf\b" "$REPO" 2>/dev/null; then
      continue
    fi
    echo "$const" >> "$TMP/missing"
  done < "$TMP/consts"

  nconst=$(grep -c . "$TMP/consts" 2>/dev/null || true)
  nmiss=$(grep -c . "$TMP/missing" 2>/dev/null || true)
  if [ "${nconst:-0}" -eq 0 ]; then
    skip "probe identifiers: no project constants named in the probes"
  elif [ "${nmiss:-0}" -eq 0 ]; then
    ok "all $nconst constant(s) named by a probe exist in the repository"
  else
    bad "$nmiss constant(s) named by a probe do not exist in this repository — an invented probe fails on first paste: $(tr '\n' ' ' < "$TMP/missing")"
  fi

  # Scopes and class methods called on a project constant. A probe's whole value is that it
  # names THIS app's scope, so an invented one is the defect this rule exists for — and it is
  # the likeliest fabrication, because a plausible scope name is exactly what a model writes
  # when it has not read far enough. The exclusion list is ActiveRecord's own surface: those
  # are real methods on every model and say nothing about this repository.
  ar_api='to_sql|all|new|first|last|count|where|order|limit|select|pluck|find|find_by|find_each|in_batches|explain|connection|columns_hash|column_names|attribute_names|defined_enums|validators_on|validators|reflect_on_association|reflect_on_all_associations|nested_attributes_options|queue_name|serialize|instance_methods|primary_key|table_name|create!|create|update!|update|destroy|delete_all|update_all|insert_all|upsert_all|save|save!|unscoped|default_scoped|reload|attributes|as_json|to_json'
  grep -oE '\b[A-Z][A-Za-z0-9]*\.[a-z_]+[a-z_0-9]*' "$TMP/probe-body" \
    | sed 's/^[^.]*\.//' | sort -u \
    | grep -Ev "^($ar_api)$" > "$TMP/scopes" || true

  nscope=$(grep -c . "$TMP/scopes" 2>/dev/null || true)
  if [ "${nscope:-0}" -gt 0 ]; then
    : > "$TMP/missing-scopes"
    while IFS= read -r sc; do
      [ -n "$sc" ] || continue
      # A scope, a class method, or an instance method — a probe may reasonably call any.
      grep -rEq "(scope[[:space:]]+:$sc\b|def[[:space:]]+(self\.)?$sc\b|enum[[:space:]]+:?$sc\b)" "$REPO" 2>/dev/null \
        || echo "$sc" >> "$TMP/missing-scopes"
    done < "$TMP/scopes"
    nmsc=$(grep -c . "$TMP/missing-scopes" 2>/dev/null || true)
    if [ "${nmsc:-0}" -eq 0 ]; then
      ok "$nscope scope(s) or method(s) called by a probe are defined in the repository"
    else
      bad "$nmsc scope(s) or method(s) a probe calls are not defined in this repository — a plausible scope name is the likeliest thing an invented probe gets wrong: $(tr '\n' ' ' < "$TMP/missing-scopes")"
    fi
  fi

  # Attribute and association names a probe reflects on, checked the same way.
  grep -oE '\.(reflect_on_association|validators_on)\(:[a-z_]+\)' "$TMP/probe-body" \
    | sed 's/.*(://; s/)//' | sort -u > "$TMP/syms" || true
  nsym=$(grep -c . "$TMP/syms" 2>/dev/null || true)
  if [ "${nsym:-0}" -gt 0 ]; then
    : > "$TMP/missing-syms"
    while IFS= read -r sym; do
      [ -n "$sym" ] || continue
      grep -rEq "([:\"']$sym\b|\b$sym:)" "$REPO" 2>/dev/null || echo "$sym" >> "$TMP/missing-syms"
    done < "$TMP/syms"
    nms=$(grep -c . "$TMP/missing-syms" 2>/dev/null || true)
    if [ "${nms:-0}" -eq 0 ]; then
      ok "$nsym attribute/association name(s) in probes appear in the repository"
    else
      bad "$nms name(s) a probe reflects on are absent from the repository: $(tr '\n' ' ' < "$TMP/missing-syms")"
    fi
  fi
fi

finish
