#!/bin/sh
# diagram-shot.sh — render each diagram on its own, in both themes, to a PNG.
#
# diagram.sh catches what is countable. Crowding, overlap and a label that collides with
# an edge are none of those things: they need eyes. This produces the images those eyes
# need, one pair per diagram, using the same styles the published page uses — the whole
# style block is lifted from page-template.html rather than reproduced, so a token that
# only exists in one theme shows up here as it would for a reader.
#
# Chrome is the renderer because it is the engine the artifact is read in. No Chrome, no
# images: it skips rather than failing, since CI has no browser and this is a check for a
# person, not a gate.
#
#   diagram-shot.sh --page page.html [--out dir]
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_input

CHROME=${CHROME:-}
if [ -z "$CHROME" ]; then
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
           "/Applications/Chromium.app/Contents/MacOS/Chromium" \
           "$(command -v google-chrome || true)" \
           "$(command -v chromium || true)"; do
    if [ -n "$c" ] && [ -x "$c" ]; then CHROME=$c; break; fi
  done
fi
if [ -z "$CHROME" ]; then
  skip "no Chrome found — set \$CHROME to render the diagrams"
  finish
  exit
fi

OUT=${OUTDIR:-$(dirname "$IN")/shots}
mkdir -p "$OUT"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# The real style block, not a copy of it. A diagram that only works against a
# hand-maintained subset of the tokens is not the diagram the reader gets.
awk '/<style/,/<\/style>/' "$SKILL_DIR/references/page-template.html" > "$TMP/style.html"

starts=$(grep -n '<svg' "$IN" | cut -d: -f1 || true)
if [ -z "$starts" ]; then
  skip "no diagrams to render"
  finish
  exit
fi

n=0
for ln in $starts; do
  n=$((n + 1))
  awk -v s="$ln" 'NR>=s{print} /<\/svg>/{if(NR>=s)exit}' "$IN" > "$TMP/svg-$n"

  for theme in light dark; do
    {
      printf '<!doctype html><html data-theme="%s"><head><meta charset="utf-8">\n' "$theme"
      cat "$TMP/style.html"
      printf '</head><body style="background:var(--bg);padding:24px">\n'
      printf '<figure class="wide"><div class="scroller">\n'
      cat "$TMP/svg-$n"
      printf '\n</div></figure></body></html>\n'
    } > "$TMP/harness-$n-$theme.html"

    shot="$OUT/$(basename "$IN" .html)-diagram$n-$theme.png"
    if "$CHROME" --headless --disable-gpu --hide-scrollbars --window-size=1000,760 \
                 --screenshot="$shot" "file://$TMP/harness-$n-$theme.html" >/dev/null 2>&1 \
       && [ -s "$shot" ]; then
      ok "rendered $shot"
    else
      bad "Chrome produced no image for diagram $n in $theme"
    fi
  done
done

echo
echo "Look at these. A script cannot tell you that two boxes overlap, that an edge label"
echo "sits on top of a line, or that the dashed nodes are the ones that should be dashed."

finish
