#!/bin/sh
# start-here.sh — section 3, the route through the code.
#
# The section is ONE list. What most needs judgment and what to read first are the same
# question, and the failure this script exists to catch is answering it twice: a findings
# list followed by a separate reading order, which is how this section used to restate the
# rest of the page.
#
# Three things are checkable. The list is an order with reasons rather than a list of paths.
# Its entries point INTO the flows, because section 2 is where a finding is explained and an
# entry that does not link is one that re-explained instead. And the list is short — a cap
# that is never reached bounds nothing, so the count is reported either way.
#
# What needs a reader: whether an entry names a finding or restates the flow, and whether
# the order is defensible. Neither is countable.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_input

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
if grep -q 'id="start"' "$IN"; then
  awk '/id="start"/{f=1} f&&/<section /&&!/id="start"/{exit} f{print}' "$IN" > "$TMP/region"
else
  cp "$IN" "$TMP/region"
fi
REGION=$TMP/region

# One list, and it is an order with reasons. A path list in some order is not a reading
# order, which is the whole distinction the .why span carries.
ro_items=$(awk '/<ol class="begin"/,/<\/ol>/' "$REGION" | grep -c '<li' || true)
ro_why=$(awk '/<ol class="begin"/,/<\/ol>/' "$REGION" | grep -c 'class="why"' || true)
if [ "${ro_items:-0}" -eq 0 ]; then
  bad "no ol.begin — section 3 is one ordered list, and this fragment has none"
elif [ "${ro_why:-0}" -ge "${ro_items:-0}" ]; then
  ok "start here: $ro_items entr(ies), each with a why"
else
  bad "start here has $ro_items entr(ies) but $ro_why why-clause(s) — a path list in an order is not a reading order"
fi

# ONE list. A second ol in this section is the old shape: findings, then a separate
# reading order over the same files.
lists=$(grep -c '<ol' "$REGION" || true)
if [ "${lists:-0}" -gt 1 ]; then
  bad "section 3 carries $lists lists — it is one list; a second is the findings/reading-order split this format removed"
else
  ok "section 3 is a single list"
fi

# Entries point into the flows. Section 2 explains; section 3 names and routes.
flowlinks=$(grep -c 'href="#flow' "$REGION" || true)
if [ "${ro_items:-0}" -eq 0 ]; then
  skip "no entries to check for flow links"
elif [ "${flowlinks:-0}" -lt 1 ]; then
  bad "no entry links into a flow — an entry that does not point at section 2 has re-explained the finding instead of naming it"
else
  ok "entries link into the flows that explain them ($flowlinks)"
fi

# Citations. Every entry names somewhere to go, and somewhere to go has a file:line.
# A .begin entry leads with <a class="path">; .cite is accepted too, both because a
# tier-4 run renders the citation as plain text in a span.cite and because a page built
# before the .begin list used .cite throughout.
cites=$(grep -Ec 'class="cite"|class="path"' "$REGION" || true)
if [ "${ro_items:-0}" -gt 0 ] && [ "${cites:-0}" -lt 1 ]; then
  bad "section 3 has $ro_items entr(ies) and no citation at all"
elif [ "${ro_items:-0}" -gt 0 ]; then
  ok "citations present alongside the entries ($cites)"
fi

# The budget. Roughly five to eight; never one per changed file. Reported rather than
# enforced at the low end, because a small diff legitimately produces a short list.
if [ "${ro_items:-0}" -gt 12 ]; then
  bad "$ro_items entries — past about eight this is the ledger with reasons attached, not a starting point"
elif [ "${ro_items:-0}" -gt 8 ]; then
  maybe "$ro_items entries — the shape is roughly five to eight; check none of these is a file that merely changed"
elif [ "${ro_items:-0}" -gt 0 ]; then
  ok "$ro_items entries, within the shape of a starting point"
fi

# The sampling caveat lives here, once. Its absence is what lets the page read as an audit.
if grep -Eqi 'not (an|a full) (audit|exhaustive)|pass, not an audit|surfaced|exhaustive' "$REGION"; then
  ok "the sampling caveat is carried here"
else
  maybe "no sampling caveat in section 3 — it lives here, once, and without it the list reads as an audit"
fi

finish
