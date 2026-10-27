#!/bin/sh
# page-lint.sh — the mechanical reading of a finished page that a run acts on before it publishes.
#
#   Usage: page-lint.sh <page.html> [--repo DIR --base BASE [--head HEAD]]
#
# Prints one line per finding, in the idiom of every check here — PASS, WARN, FAIL, SKIP — and
# exits 1 only on a FAIL. Shell and awk, nothing else: this runs inside a user's run of the skill,
# on whatever machine that is, so it may depend on nothing the evals need. (evals/checks relay its
# lines rather than re-implementing the rules, so each rule has one implementation.)
#
# Two rules.
#
# PLACEHOLDERS. `{{ANYTHING}}` left on the page is the template copied and not filled in; a FAIL,
# because it is a shape the page must not ship in.
#
# TIERS AGAINST THE CHANGED SET. report-format.md § Evidence tiers: a claim resting on a file the
# diff does not touch carries `from unchanged code` and cites that file; a file the diff touches is
# changed code, untouched lines included, and never carries that label. Three shapes, each a WARN
# naming the sentence, never a FAIL — a hard failure on a label teaches a run to label everything:
#
#   unlabelled   a sentence cites a file outside the diff and carries no tier
#   uncited      a `from unchanged code` with nothing cited in its sentence
#   on-changed   a `from unchanged code` whose only citations are files in the diff
#
# Read per sentence inside the prose fields — a <p>, a <li> — on the comment-stripped page with the
# regions that carry no claim or are labelled by their heading removed: <style>, <script>, <pre>,
# the chain nodes (ol.ip-path), the Affected lists (ul.ev-list), the search record, Context, the
# evidence foot. A list entry is one unit, because its clause and its citation are separate
# elements. A card's why (p.ip-why) may not carry a citation — its nodes' locators are its
# citations — so it is never held to `uncited`. A citation's path comes from its blob href when
# the link text is short (`oauth.rb:35`); a diff-form href names no path and is a changed file by
# definition; plain text is matched on its suffix. A citation woven into the prose — `a.ref`, whose
# text is the claim rather than a path (report-format.md § Deep links) — is read from its href
# alone, because its text names no file.
#
# The changed set is `git diff --name-only BASE...HEAD` when --repo and --base are given, else the
# page's own ledger (the data-path cells). With neither there is nothing to hold a label against,
# and the tier rule says SKIP rather than passing on evidence it does not have. Whether a tier is
# EARNED is a judged question; this reads only what each sentence cites.

set -eu

PAGE=${1:-}
REPO=
BASE=
HEAD=HEAD
[ $# -gt 0 ] && shift
while [ $# -gt 0 ]; do
  case $1 in
    --repo) REPO=${2:-}; shift 2 ;;
    --base) BASE=${2:-}; shift 2 ;;
    --head) HEAD=${2:-HEAD}; shift 2 ;;
    *) echo "usage: page-lint.sh <page.html> [--repo DIR --base BASE [--head HEAD]]" >&2; exit 2 ;;
  esac
done
if [ -z "$PAGE" ]; then
  echo "usage: page-lint.sh <page.html> [--repo DIR --base BASE [--head HEAD]]" >&2
  exit 2
fi
if [ ! -r "$PAGE" ]; then
  echo "lint: cannot read page at $PAGE" >&2
  exit 2
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT HUP TERM
status=0

# ---------------------------------------------------------------- comments off
# The template's own comments carry every placeholder and every rule name, so nothing below reads
# through one. A state machine, because a comment may open on one line and close on another.
awk '
{
  rest = $0; out = ""
  while (1) {
    if (inside) {
      c = index(rest, "-->")
      if (c == 0) break
      inside = 0; rest = substr(rest, c + 3); continue
    }
    o = index(rest, "<!--")
    if (o == 0) { out = out rest; break }
    out = out substr(rest, 1, o - 1); rest = substr(rest, o + 4); inside = 1
  }
  print out
}' "$PAGE" > "$TMP/prose"

# ---------------------------------------------------------------- placeholders
found=$(grep -o '{{[A-Z][A-Z0-9_|]*}}' "$TMP/prose" | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ -n "$found" ]; then
  echo "FAIL  placeholders left on the page — the template was copied and not filled in: $found"
  status=1
else
  echo "PASS  no placeholders"
fi

# ---------------------------------------------------------------- the changed set
set_from=
if [ -n "$REPO" ] && [ -n "$BASE" ]; then
  if git -C "$REPO" diff --name-only "$BASE...$HEAD" > "$TMP/changed" 2>/dev/null; then
    set_from="the diff"
  else
    echo "SKIP  tiers: git cannot resolve $BASE...$HEAD in $REPO" >&2
  fi
fi
if [ -z "$set_from" ] && grep -q 'data-path="' "$TMP/prose"; then
  grep -o 'data-path="[^"]*"' "$TMP/prose" | sed 's/^data-path="//; s/"$//' \
    | sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;/'"'"'/g' | sort -u > "$TMP/changed"
  set_from="the page's own ledger"
fi
if [ -z "$set_from" ]; then
  echo "SKIP  tiers: no --repo/--base and no ledger on the page — nothing to hold a label against"
  exit $status
fi

# ---------------------------------------------------------------- the prose fields
# Drop the regions, line-based: from a line matching the opener to the line matching its closer.
# Then join what is left into one stream and cut it into fields, one <p> or <li> per line.
awk '
BEGIN {
  n = 0
  o[++n] = "<style[ >]";                 c[n] = "</style>"
  o[++n] = "<script[ >]";                c[n] = "</script>"
  o[++n] = "<pre[ >]";                   c[n] = "</pre>"
  o[++n] = "<ol class=\"ip-path\"";      c[n] = "</ol>"
  o[++n] = "<ul class=\"ev-list\"";      c[n] = "</ul>"
  o[++n] = "<details class=\"searched\""; c[n] = "</details>"
  o[++n] = "<dl class=\"ctx\"";          c[n] = "</dl>"
  o[++n] = "<details class=\"evidence\""; c[n] = "</details>"
}
{
  line = $0
  if (inside) {
    k = index(line, c[inside])
    if (k == 0) next
    line = substr(line, k + length(c[inside])); inside = 0
  }
  # A region that opens and closes on one line is cut out of the line, not the line out of the
  # page: an excerpt body on the same line as the </li> that closes its entry would otherwise
  # take the entry with it, and the entry would be read as nothing rather than as cited.
  while (1) {
    best = 0
    for (i = 1; i <= n; i++) if (match(line, o[i]) && (!best || RSTART < bs)) { best = i; bs = RSTART }
    if (!best) break
    rest = substr(line, bs)
    k = index(rest, c[best])
    if (k == 0) { line = substr(line, 1, bs - 1); inside = best; break }
    line = substr(line, 1, bs - 1) substr(rest, k + length(c[best]))
  }
  printf "%s ", line
}' "$TMP/prose" > "$TMP/stream"

awk '
{
  s = $0
  while (match(s, /<(p|li)[ >]/)) {
    s = substr(s, RSTART)
    tag = (substr(s, 2, 1) == "p") ? "p" : "li"
    close_tag = "</" tag ">"
    e = index(s, close_tag)
    if (e == 0) break
    field = substr(s, 1, e - 1)
    s = substr(s, e + length(close_tag))
    gsub(/[ \t]+/, " ", field)
    print field
  }
}' "$TMP/stream" > "$TMP/fields"

# ---------------------------------------------------------------- the three shapes
awk -v changed_file="$TMP/changed" '
BEGIN {
  while ((getline line < changed_file) > 0) if (line != "") changed[line] = 1
  read = 0
}
function quote(s,   t) {
  t = s; gsub(/<[^>]*>/, "", t); gsub(/&mdash;/, "-", t); gsub(/&[a-z#0-9]+;/, " ", t)
  gsub(/[ \t]+/, " ", t); sub(/^ /, "", t); sub(/ $/, "", t)
  return substr(t, 1, 70)
}
# One citation: is the file it names in the diff? The path is in the blob href when the text is
# short; a diff-form href is a changed file by definition; plain text matches on its suffix.
function in_diff(attrs, text,   path, k, p) {
  if (index(attrs, "/files#diff-")) return 1
  path = ""
  if (match(attrs, /\/blob\/[0-9a-f]+\/[^#"]+/)) {
    path = substr(attrs, RSTART, RLENGTH); sub(/^\/blob\/[0-9a-f]+\//, "", path)
  } else {
    path = text; sub(/:.*$/, "", path); gsub(/^ +| +$/, "", path)
  }
  if (path == "") return -1
  if (path in changed) return 1
  for (p in changed) { k = length(p) - length(path); if (k > 0 && substr(p, k) == "/" path) return 1 }
  return 0
}
function sentence(s, cites,   rest, attrs, text, outside, inside, any, v, tier, unc, m, tag_end, pa, la, pe, pr, lr, inner, e) {
  outside = 0; inside = 0; any = 0
  rest = s
  # Three citation forms. An a.path carries its text directly. An a.ref is a phrase of the prose
  # linked, so only its opening tag is read: the href is the citation and the text, which may hold
  # a <code>, names no file. An excerpt summary location is a span.ex-loc whose first child is the
  # link (excerpt.sh: <span class="ex-loc"><a class="cite" href="…">path:line</a></span>), or the
  # plain text on an unlinked rung — so the span is taken whole, its href from the inner <a> and
  # its text with the tags stripped. Reading it as an element with empty text made every entry
  # whose citation is an excerpt read as uncited.
  while (1) {
    pa = match(rest, /<a class="path[^"]*"[^>]*>[^<]*</) ? RSTART : 0; la = RLENGTH
    pr = match(rest, /<a class="ref"[^>]*>/) ? RSTART : 0; lr = RLENGTH
    pe = index(rest, "<span class=\"ex-loc\">")
    if (!pa && !pe && !pr) break
    if (pr && (!pa || pr < pa) && (!pe || pr < pe)) {
      attrs = substr(rest, pr, lr); rest = substr(rest, pr + lr)
      # A linked phrase is a citation even when its href cannot be placed in or out of the diff.
      any = 1
      v = in_diff(attrs, "")
      if (v < 0) continue
      if (v) inside = 1; else outside = 1
      continue
    }
    if (pa && (!pe || pa < pe)) {
      m = substr(rest, pa, la); rest = substr(rest, pa + la)
      tag_end = index(m, ">")
      attrs = substr(m, 1, tag_end); text = substr(m, tag_end + 1); sub(/<$/, "", text)
    } else {
      inner = substr(rest, pe + 21)
      e = index(inner, "</span>")
      if (e == 0) break
      inner = substr(inner, 1, e - 1); rest = substr(rest, pe + 21 + e + 6)
      attrs = ""
      if (match(inner, /<a [^>]*>/)) attrs = substr(inner, RSTART, RLENGTH)
      text = inner; gsub(/<[^>]*>/, "", text)
    }
    if (text ~ /^ *$/) continue
    v = in_diff(attrs, text)
    if (v < 0) continue
    any = 1
    if (v) inside = 1; else outside = 1
  }
  tier = index(s, "class=\"tier") > 0
  unc = index(s, "from unchanged code") > 0
  read++
  if (outside && !tier) { warned = 1; print "WARN  unlabelled — a sentence cites a file outside the diff with no tier; a claim resting on unchanged code says so, or it claims the diff shows it: \"" quote(s) "\"" }
  if (unc && !any && cites) { warned = 1; print "WARN  uncited — from unchanged code with nothing cited in its sentence; the label names a kind of evidence, the citation is the evidence: \"" quote(s) "\"" }
  if (unc && inside && !outside) { warned = 1; print "WARN  on-changed — from unchanged code on a sentence that cites only files in the diff; an untouched line of a changed file is changed code, cited and unlabelled: \"" quote(s) "\"" }
}
{
  f = $0
  if (f ~ /^<li[^>]*class="ip-n/) next
  if (f ~ /^<p[^>]*class="(note|buildstate)/) next
  if (f ~ /^<li/) { sentence(f, 1); next }
  cites = (f !~ /^<p[^>]*class="ip-why/)
  sub(/^<p[^>]*>/, "", f)
  n = split(f, parts, /[.!?][ \t]+/)
  for (i = 1; i <= n; i++) if (parts[i] !~ /^ *$/) sentence(parts[i], cites)
}
END { if (!warned) print "PASS  tiers agree with the changed set (" read " sentences read against " set_from ")" }
' set_from="$set_from" "$TMP/fields"

exit $status
