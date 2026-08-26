#!/bin/sh
# blast-radius.sh — section 2, the section a diff cannot produce at all.
#
# Its three structural claims are checkable: there is a diagram, the reading order is an
# order with reasons rather than a file list, and an empty search is recorded as a search
# rather than left as silence. The SVG itself belongs to diagram.sh — one home per check.
#
# What needs a reader: whether the affected entries are RIGHT. Presence is cheap;
# correctness is the product.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_input

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
if grep -q 'id="map"' "$IN"; then
  awk '/id="map"/{f=1} f&&/<section /&&!/id="map"/{exit} f{print}' "$IN" > "$TMP/region"
else
  cp "$IN" "$TMP/region"
fi
REGION=$TMP/region

# The diagram. Almost every PR earns this one, and it is the only place the page shows
# changed and affected in the same frame.
if grep -q '<svg' "$REGION"; then
  ok "blast-radius diagram present"
else
  bad "no diagram in section 2 — the changed/affected split is what a table cannot show"
fi

# Changed beside affected. The second list is the point of the section.
if grep -Eqi 'affected' "$REGION"; then
  ok "an affected-but-unchanged list is present"
else
  bad "no affected-but-unchanged list — section 2 without it is a restatement of the diff"
fi

# Reading order: numbered, and every step says why it comes there. A list of paths in
# some order is not a reading order.
ro_items=$(awk '/<ol class="readorder"/,/<\/ol>/' "$REGION" | grep -c '<li' || true)
ro_why=$(awk '/<ol class="readorder"/,/<\/ol>/' "$REGION" | grep -c 'class="why"' || true)
if [ "${ro_items:-0}" -eq 0 ]; then
  bad "no ol.readorder — the reading order is one of section 2's four parts"
elif [ "${ro_why:-0}" -ge "${ro_items:-0}" ]; then
  ok "reading order: $ro_items step(s), each with a why"
else
  bad "reading order has $ro_items step(s) but $ro_why why-clause(s) — a path list in an order is not a reading order"
fi

# Recorded searches. Unrecorded, absence and omission look identical, and the reviewer
# has to redo the work to tell which it was.
if grep -Eq '\brg |\bgrep |\bag |searched' "$REGION"; then
  ok "searches are recorded, so an empty result reads as evidence"
else
  maybe "no search recorded anywhere in section 2 — an unrecorded absence cannot be told from an omission"
fi

# Citations. Every entry in either list needs one; the hard rule is page-wide.
li=$(grep -c '<li' "$REGION" || true)
cites=$(grep -c 'class="cite"' "$REGION" || true)
if [ "${li:-0}" -gt 0 ] && [ "${cites:-0}" -lt 1 ]; then
  bad "section 2 has $li list item(s) and no citation at all"
else
  ok "citations present alongside the lists ($cites)"
fi

finish
