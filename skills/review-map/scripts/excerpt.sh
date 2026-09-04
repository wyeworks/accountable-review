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
#           reason the component exists. It needs --base as well, for the state tag.
#   --diff  emits one <details> per hunk, so you delete the ones you do not want.
#           --hunk N emits only the Nth.
#
# STATE. The tag in the summary is derived from the diff, never assumed. --at used to
# hard-code "Unchanged", which is a claim about the diff the script had not looked at:
# a run published db/structure.sql:304-313 labelled Unchanged on a page whose own
# ledger listed that file as changed. Quoting a changed file at head is legitimate, and
# sometimes the only way to show what the committed code now permits -- a hunk of an
# 18k-line structure.sql cannot show that a table has no CHECK constraint -- but saying
# it never moved is not. So --at needs --base, and the tag it computes is one of
# Unchanged (the path is outside the diff), Added, Removed, At head, or Before the
# change. Only two revs may be quoted, which is the deep-link ladder's rule as well:
# the head side for code as it stands, the base side for code as it was.
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
# SYNTAX. In --at mode the <pre> also carries data-lang, guessed from the path and
# overridable with --lang (--lang none suppresses it). It is a *label*, not colour:
# the page's script tints the excerpt from it at runtime, so the bytes this script
# writes stay the bytes git gave it, and a page read with no script — or with the
# CDN blocked — shows exactly what it shows today. --diff hunks are deliberately
# left untagged: a hunk is not one lexical stream (a '-' line and the '+' line
# replacing it are alternate realities, and a lexer fed both mis-reads everything
# after the first unbalanced quote), and their rows already carry colour that means
# added and removed. Two colour systems in one block make both harder to read.
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
SYNLANG=
SOFT_MAX=24

usage() {
  echo "usage: excerpt.sh --at PATH:START-END --base BASE [--rev REV] [--head REF] [--why TEXT] [--lang L] [--blob URL|--link URL]" >&2
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
    --lang) SYNLANG=${2:-}; shift 2 ;;
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
open_block() {  # $1 variant, $2 path, $3 loc label, $4 counter seed, $5 state tag, $6 lang
  printf '<details class="excerpt excerpt--%s">\n' "$1"
  printf '  <summary>\n'
  printf '    <span class="chev">&#9656;</span>\n'
  printf '    <span class="ex-loc">%s</span>\n' "$(esc1 "$3")"
  printf '    <span class="tag">%s</span>\n' "$(esc1 "$5")"
  printf '    <span class="ex-why">%s</span>\n' "$WHY_HTML"
  printf '  </summary>\n'
  printf '  <div class="ex-body">\n'
  printf '<pre data-src="%s"%s style="counter-reset: exl %s">' \
    "$(escattr "$2")" "$( [ -n "${6:-}" ] && printf ' data-lang="%s"' "$(escattr "$6")" )" "$4"
}

close_block() {  # $1 kind word, $2 loc label
  printf '</pre>\n'
  printf '    <p class="ex-src">%s %s</p>\n' "$1" "$(cite "$2")"
  printf '  </div>\n</details>\n'
}

# Extension → highlight.js language. Only names in the library's common bundle,
# plus erb and elixir, which the page loads separately: Rails views and Elixir
# modules are exactly the kind of unchanged code this component quotes, and
# neither grammar is in the common bundle. Anything unlisted emits no
# data-lang at all: no tint is correct, and a wrong tint is a small lie about
# code the reader is being asked to trust.
#
# .heex and .eex are an INTENTIONAL omission, not an oversight. highlight.js
# ships no HEEx grammar, and the two near-misses are both wrong in ways a reader
# cannot see: `elixir` mis-reads the markup around the interpolations, and `erb`
# tints Elixir as Ruby because <%= %> happens to be the same delimiter. A HEEx
# template is quoted untinted, in one ink, on purpose — do not "fix" this.
guess_lang() {
  case $(basename "$1") in
    Gemfile|Rakefile|Brewfile|Podfile|Fastfile|*.rb|*.rake|*.gemspec|*.ru) echo ruby; return ;;
    Makefile|makefile) echo makefile; return ;;
    Dockerfile|*.dockerfile) return ;;
  esac
  case $1 in
    *.erb) echo erb ;;
    *.ex|*.exs) echo elixir ;;
    *.heex|*.eex) : ;;
    *.ts|*.tsx|*.mts|*.cts) echo typescript ;;
    *.js|*.jsx|*.mjs|*.cjs) echo javascript ;;
    *.json) echo json ;;
    *.yml|*.yaml) echo yaml ;;
    *.sql) echo sql ;;
    *.css) echo css ;;
    *.scss|*.sass) echo scss ;;
    *.html|*.xml|*.svg|*.vue|*.haml) echo xml ;;
    *.md|*.markdown) echo markdown ;;
    *.sh|*.bash|*.zsh) echo bash ;;
    *.py) echo python ;;
    *.graphql|*.gql) echo graphql ;;
    *.toml|*.ini|*.env) echo ini ;;
    *) : ;;
  esac
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
  [ -n "$BASE" ] || {
    echo "excerpt.sh: --at needs --base BASE." >&2
    echo "  The state tag is read off the diff between the base and the head, and a" >&2
    echo "  quotation that labels its own state without looking is how a changed file" >&2
    echo "  gets published as Unchanged." >&2
    exit 2; }

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

  # --lang wins over the guess; --lang none is how a run says "leave this plain",
  # for a file whose extension lies about its contents.
  case $SYNLANG in
    none) lang= ;;
    '')   lang=$(guess_lang "$path") ;;
    *)    lang=$SYNLANG ;;
  esac

  # THE STATE TAG. See STATE at the top: this is a fact about the diff, so it is read
  # off the diff. The page's own Changed / Affected-not-changed split is by file, so a
  # path the diff touches is never tagged Unchanged here either -- not even where the
  # quoted lines happen to be untouched, because the two labels would then contradict
  # each other on one page and the reader has no way to tell which sense was meant.
  # Say the range is untouched in the prose instead, where it can be said precisely.
  b=$(git rev-parse --verify --quiet "$BASE^{commit}") || {
    echo "excerpt.sh: cannot resolve --base $BASE" >&2; exit 1; }
  h=$(git rev-parse --verify --quiet "$HEAD_REF^{commit}") || {
    echo "excerpt.sh: cannot resolve --head $HEAD_REF" >&2; exit 1; }
  r=$(git rev-parse --verify --quiet "$REV^{commit}") || {
    echo "excerpt.sh: cannot resolve --rev $REV" >&2; exit 1; }
  mb=$(git merge-base "$b" "$h" 2>/dev/null) || mb=$b

  # Which side is being quoted. Two are sanctioned, and they are the two the deep-link
  # ladder names; a third rev is a state neither this comparison nor the page can name.
  case $r in
    "$h")       side=head ;;
    "$b"|"$mb") side=base ;;
    *)
      echo "excerpt.sh: --rev $REV is neither the base nor the head of $BASE...$HEAD_REF." >&2
      echo "  The state tag comes from that comparison, so quote one side or the other." >&2
      exit 2 ;;
  esac

  # A rename carries two paths on one row: $2 is the pre-image, $3 the name at head.
  status=$(git diff --name-status -M "$mb" "$h" | awk -F'\t' -v p="$path" '
    { s = substr($1, 1, 1)
      if (s == "R") { if ($2 == p) { print "R-old"; exit } else if ($3 == p) { print "M"; exit } }
      else if ($2 == p) { print s; exit } }')

  case $status in
    '')    tag="Unchanged";         kind="Unchanged at" ;;
    A)     tag="Added";             kind="Added at" ;;
    D)     tag="Removed";           kind="Removed at" ;;
    R-old) tag="Before the change"; kind="Before the change," ;;
    *)     if [ "$side" = head ]; then
             tag="At head";           kind="At head,"
           else
             tag="Before the change"; kind="Before the change,"
           fi ;;
  esac

  loc="$path:$start-$end"
  open_block source "$path" "$loc" "$((start - 1))" "$tag" "$lang"
  printf '%s\n' "$body" | esc | awk '{ printf "<span class=\"l\">%s</span>\n", $0 }'
  close_block "$kind" "$loc"
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
