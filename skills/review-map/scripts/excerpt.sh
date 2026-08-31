#!/bin/sh
# excerpt.sh — emit a collapsed source excerpt for the review map.
#
#   Usage:  excerpt.sh --at PATH:START-END  [--rev REV]  [--why TEXT]
#           excerpt.sh --diff PATH --base BASE [--head HEAD] [--hunk N] [--why TEXT]
#           …plus one link option: [--blob URL_WITHOUT_FRAGMENT] or [--link FULL_URL]
#
# Run it from inside the repository under review. --source is an alias for --at,
# because the variant it produces is called .excerpt--source.
#
# LINKS. Prefer --blob: pass the file URL with no #fragment and the script appends
# the range it actually read. That matters most for --diff, where the range is the
# hunk's and you do not know it in advance — a run passed --link with a hand-written
# #L121-L134 against a hunk the script labelled :118-131, and the summary and the
# link disagreed on screen with nothing to warn about it. --link still works for a
# URL form this does not know, but in --diff mode a line anchor inside it is
# replaced with the computed range and you are told. Give neither at rungs 3 and 4,
# where the citation must render as plain text.
#
#   --at    quotes the file as it stands at REV (default HEAD). This is the form
#           for *affected but unchanged* code, which has no diff to show and is the
#           reason the component exists.
#   --diff  emits one <details> per hunk, so you delete the ones you do not want.
#           --hunk N emits only the Nth.
#
# Why this is a script and not markup you type: an excerpt is a *quotation*. A
# mistyped ledger row fails coverage-gate.sh loudly; a paraphrased quotation is a
# false quotation and the reader cannot tell. So the bytes come from git, and the
# HTML escaping — &, <, > — happens here, because ERB and TSX are full of all three
# and hand-escaping them is exactly where a quotation stops being verbatim.
#
# Line numbers are emitted as a CSS counter seeded on the <pre>, never as text, so
# a reader who copies the excerpt gets code and not a column of digits. The +/-
# signs *are* text: they make a copied hunk a valid patch, and they mean the marker
# survives for anyone who cannot distinguish the two row tints.
#
# The path goes in data-src. It must never go in data-path: coverage-gate.sh greps
# that attribute across the whole page and compares it to the diff as a set, so an
# excerpt citing an unchanged file would register as a surplus path and fail the
# gate — on the page's best content, which is the worst place to lose a check.
#
# {{WHY_THIS_MATTERS}} in the output is deliberate, like {{SECTION}} in
# ledger-rows.sh. A closed excerpt whose summary does not say why to open it is
# worse than no excerpt, and it is meant to be obvious that nobody wrote it.

set -eu

MODE=
TARGET=
REV=HEAD
BASE=
HEAD_REF=HEAD
HUNK=
WHY=
LINK=
BLOB=
SOFT_MAX=24

usage() {
  echo "usage: excerpt.sh --at PATH:START-END [--rev REV] [--why TEXT] [--blob URL|--link URL]" >&2
  echo "       excerpt.sh --diff PATH --base BASE [--head HEAD] [--hunk N] [--why TEXT] [--blob URL|--link URL]" >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case $1 in
    --at|--source) MODE=at;   TARGET=${2:-}; shift 2 ;;
    --diff) MODE=diff; TARGET=${2:-}; shift 2 ;;
    --rev)  REV=${2:-}; shift 2 ;;
    --base) BASE=${2:-}; shift 2 ;;
    --head) HEAD_REF=${2:-}; shift 2 ;;
    --hunk) HUNK=${2:-}; shift 2 ;;
    --why)  WHY=${2:-}; shift 2 ;;
    --link) LINK=${2:-}; shift 2 ;;
    --blob) BLOB=${2:-}; shift 2 ;;
    *) usage ;;
  esac
done

[ -n "$MODE" ] && [ -n "$TARGET" ] || usage

esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }
esc1() { printf '%s' "$1" | esc; }
escattr() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }

WHY_HTML=$( [ -n "$WHY" ] && esc1 "$WHY" || printf '{{WHY_THIS_MATTERS}}' )

# The citation under the code. A link when one was given, plain text otherwise —
# which is the rung-3/4 behaviour, and the reason not to default to a URL.
cite() {
  _label=$(esc1 "$1")
  if [ -n "$LINK" ]; then
    printf '<a class="cite" href="%s">%s</a>' "$(escattr "$LINK")" "$_label"
  else
    printf '<span class="cite">%s</span>' "$_label"
  fi
}

# The summary is a three-column grid: chevron, location, state tag — and the why
# wraps onto its own row underneath. The why stays in the SUMMARY, never in the
# body: the page has to read complete with every excerpt closed, and a why the
# reader has to open the block to see defeats the whole point of the component.
open_block() {  # $1 variant, $2 path, $3 loc label, $4 counter seed, $5 state tag
  printf '<details class="excerpt excerpt--%s">\n' "$1"
  printf '  <summary>\n'
  printf '    <span class="chev">&#9656;</span>\n'
  printf '    <span class="ex-loc">%s</span>\n' "$(esc1 "$3")"
  printf '    <span class="tag">%s</span>\n' "$(esc1 "$5")"
  printf '    <span class="ex-why">%s</span>\n' "$WHY_HTML"
  printf '  </summary>\n'
  printf '  <div class="ex-body">\n'
  printf '<pre data-src="%s" style="counter-reset: exl %s">' \
    "$(escattr "$2")" "$4"
}

close_block() {  # $1 kind word, $2 loc label
  printf '</pre>\n'
  printf '    <p class="ex-src">%s %s</p>\n' "$1" "$(cite "$2")"
  printf '  </div>\n</details>\n'
}

warn_long() {
  [ "$1" -gt "$SOFT_MAX" ] || return 0
  echo "excerpt.sh: $1 lines — past the $SOFT_MAX-line budget." >&2
  echo "  An excerpt this long usually means the prose is not pointing precisely" >&2
  echo "  enough. Tighten the range rather than asking the reader to scan it." >&2
}

case $MODE in
at)
  path=${TARGET%:*}
  range=${TARGET##*:}
  case $TARGET in *:*) ;; *) echo "excerpt.sh: --at needs PATH:START-END" >&2; exit 2 ;; esac
  start=${range%-*}
  end=${range#*-}
  [ "$range" = "$start" ] && end=$start
  case $start$end in *[!0-9]*|'') echo "excerpt.sh: bad line range '$range'" >&2; exit 2 ;; esac
  [ "$end" -ge "$start" ] || { echo "excerpt.sh: range ends before it starts" >&2; exit 2; }

  # Guard first: the pipeline below reports sed's status, not git's, so a missing
  # path would otherwise leak git's fatal message and then report it as empty.
  git cat-file -e "$REV:$path" 2>/dev/null || {
    echo "excerpt.sh: $path does not exist at $REV" >&2; exit 1; }

  body=$(git show "$REV:$path" | sed -n "${start},${end}p") || {
    echo "excerpt.sh: cannot read $path at $REV" >&2; exit 1; }
  [ -n "$body" ] || { echo "excerpt.sh: $path:$range is empty at $REV" >&2; exit 1; }

  n=$(printf '%s\n' "$body" | wc -l | tr -d ' ')
  warn_long "$n"

  # Build the href from the range the script just read, so the link and the summary
  # cannot disagree. --link still wins when given, for a URL form this does not know.
  if [ -z "$LINK" ] && [ -n "$BLOB" ]; then
    LINK="${BLOB%%#*}#L$start-L$end"
  fi

  loc="$path:$start-$end"
  open_block source "$path" "$loc" "$((start - 1))" "Unchanged"
  printf '%s\n' "$body" | esc | awk '{ printf "<span class=\"l\">%s</span>\n", $0 }'
  close_block "Unchanged at" "$loc"
  ;;

diff)
  [ -n "$BASE" ] || usage
  raw=$(git diff --unified=3 "$BASE...$HEAD_REF" -- "$TARGET") || {
    echo "excerpt.sh: git diff failed for $TARGET" >&2; exit 1; }
  [ -n "$raw" ] || { echo "excerpt.sh: no diff for $TARGET in $BASE...$HEAD_REF" >&2; exit 1; }

  # One <details> per hunk. The summary's range is the hunk's new-side span, which
  # is what a reviewer looking at the file after the change will see.
  printf '%s\n' "$raw" | awk \
    -v path="$TARGET" -v why="$WHY_HTML" -v link="$LINK" \
    -v want="$HUNK" -v softmax="$SOFT_MAX" -v blob="$BLOB" '
    function esc(s) {
      gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); return s
    }
    function escattr(s) { s = esc(s); gsub(/"/, "\\&quot;", s); return s }
    function flush() {
      if (!open) return
      if (want == "" || want + 0 == idx) {
        loc = path ":" nstart "-" (nstart + nspan - 1)
        printf "<details class=\"excerpt excerpt--diff\">\n"
        printf "  <summary>\n"
        printf "    <span class=\"chev\">&#9656;</span>\n"
        printf "    <span class=\"ex-loc\">%s</span>\n", esc(loc)
        printf "    <span class=\"tag\">Changed</span>\n"
        printf "    <span class=\"ex-why\">%s</span>\n", why
        printf "  </summary>\n"
        printf "  <div class=\"ex-body\">\n"
        printf "<pre data-src=\"%s\" style=\"counter-reset: exl %d\">", escattr(path), nstart - 1
        printf "%s", buf
        printf "</pre>\n"
        # The hunk range belongs to the script, so the href has to come from it too. A --link
        # its own #L fragment is the one way to make the summary and the link contradict
        # each other silently, which a run hit: say so and use the computed range.
        href = ""
        if (blob != "") { sub(/#.*/, "", blob); href = blob "#L" nstart "-L" (nstart + nspan - 1) }
        else if (link != "") {
          href = link
          if (link ~ /#L[0-9]/) {
            sub(/#L[0-9].*/, "", href)
            href = href "#L" nstart "-L" (nstart + nspan - 1)
            printf "excerpt.sh: --link carried its own line anchor; replaced with the hunk range %d-%d.\n", nstart, nstart + nspan - 1 | "cat 1>&2"
          }
        }
        if (href != "")
          printf "    <p class=\"ex-src\">Changed at <a class=\"cite\" href=\"%s\">%s</a></p>\n", escattr(href), esc(loc)
        else
          printf "    <p class=\"ex-src\">Changed at <span class=\"cite\">%s</span></p>\n", esc(loc)
        printf "  </div>\n</details>\n"
        if (rows > softmax)
          printf "excerpt.sh: hunk %d is %d lines — past the %d-line budget; consider --at with a tighter range.\n", idx, rows, softmax | "cat 1>&2"
      }
      open = 0; buf = ""; rows = 0
    }
    /^@@/ {
      flush()
      # @@ -old,oldspan +new,newspan @@
      if (match($0, /\+[0-9]+(,[0-9]+)?/)) {
        spec = substr($0, RSTART + 1, RLENGTH - 1)
        if (index(spec, ",")) { split(spec, a, ","); nstart = a[1] + 0; nspan = a[2] + 0 }
        else { nstart = spec + 0; nspan = 1 }
      }
      idx++; open = 1; next
    }
    !open { next }
    /^\\ No newline at end of file/ { next }
    {
      sign = substr($0, 1, 1); text = substr($0, 2)
      if (sign == "+")      cls = "l add"
      else if (sign == "-") cls = "l del"
      else if (sign == " ") cls = "l"
      else next
      buf = buf sprintf("<span class=\"%s\"><span class=\"sig\">%s</span>%s</span>\n", cls, sign, esc(text))
      rows++
    }
    END { flush(); if (idx == 0) print "excerpt.sh: no hunks found" | "cat 1>&2" }
  '
  ;;
esac
