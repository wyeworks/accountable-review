#!/bin/sh
# before-approving.sh — section 6, the reviewer's action list.
#
# Three of its four parts have a mechanical edge. The checkpoint has a hard cap of
# five, because the old standalone part had none and grew into a quiz that restated the
# page. Author questions have to be questions — an imperative in that list is a task the
# reviewer can do alone, which means it belongs under Run. Run steps have to be real
# commands, and a command is markup, not prose.
#
# What no script can settle: whether a question is answerable by copying one sentence
# from earlier in the page. That is the cap's actual purpose and it lives in the case.
#
# DETAIL LEVEL. At --level brief there is no section 6: its anchor is an <h3> inside the
# merged tail section, and the checkpoint is not there at all — it is a comprehension test
# rather than something to weigh before approving, so it belongs to --full. That inverts
# the cap check rather than relaxing it: at brief, no checkpoint is a PASS and a present
# one is a FAIL. The rest of this script is level-agnostic, because author questions and
# real commands are what the brief level keeps.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_input

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# On a page, section 6 is the region from its anchor onward — which is also true at brief,
# where the anchor is an <h3> and is deliberately the LAST part of the merged section. A
# fragment is already the region.
if grep -q 'id="approving"' "$IN"; then
  awk '/id="approving"/,0' "$IN" > "$TMP/region"
elif [ "$IN_KIND" = fragment ]; then
  cp "$IN" "$TMP/region"
elif [ "$LEVEL" = brief ]; then
  # At brief the anchor is not optional: it is the merged section's last <h3>, and
  # without it this whole script goes quiet on a page that has a before-approving part.
  # A SKIP here would read as verified, which is the failure this branch exists to stop.
  bad "no id=\"approving\" anchor at --brief — the merged tail section carries it on its last <h3>, and without it none of section 6's rules can be checked"
  finish
  exit
else
  skip "no section 6 on this page (id=\"approving\" absent)"
  finish
  exit
fi
REGION=$TMP/region

# The cap. Five forces the questions to be the ones that join things the page
# established separately.
# The checkpoint is a grid of inverted tiles, so its questions are <div>s inside
# .checkpoint rather than <li>s. ol.firstlook is still counted so a page built before
# the tiles keeps being checked rather than silently skipped.
cp_items=$(awk '/class="checkpoint"/{f=1} f&&/<\/div>[[:space:]]*$/&&d==0{exit} f{print}' "$REGION" \
  | grep -c '<div><b>' || true)
if [ "${cp_items:-0}" -eq 0 ]; then
  cp_items=$(awk '/class="checkpoint"/,/<\/section/' "$REGION" | grep -c '<b>' || true)
fi
if [ "${cp_items:-0}" -eq 0 ]; then
  cp_items=$(awk '/<ol class="firstlook"/,/<\/ol>/' "$REGION" | grep -c '<li' || true)
fi
if [ "$LEVEL" = brief ]; then
  if [ "${cp_items:-0}" -eq 0 ]; then
    ok "no comprehension checkpoint, which is right at --brief: it belongs to --full"
  else
    bad "a comprehension checkpoint with $cp_items question(s) at --brief — the checkpoint belongs to --full, and this level's tail carries author questions and validations only"
  fi
elif [ "${cp_items:-0}" -eq 0 ]; then
  maybe "no comprehension checkpoint found inside 'Before approving'"
elif [ "${cp_items:-0}" -le 5 ]; then
  ok "comprehension checkpoint has $cp_items question(s), within the cap of 5"
else
  bad "comprehension checkpoint has $cp_items questions — the cap is 5, and past it they turn into a quiz that restates the page"
fi

# Author questions, phrased as questions. Counting question marks against list items is
# crude on purpose: it is a WARN, and a reader settles it.
if grep -qi 'ask the author' "$REGION"; then
  awk '/[Aa]sk the author/{f=1} f&&/<h3|act-group|<\/section/{if(seen)exit} f{print; seen=1}' "$REGION" > "$TMP/ask"
  a_items=$(grep -c '<li' "$TMP/ask" || true)
  a_marks=$(grep -c '?' "$TMP/ask" || true)
  if [ "${a_items:-0}" -eq 0 ]; then
    maybe "an 'ask the author' heading with no items under it"
  elif [ "${a_marks:-0}" -ge "${a_items:-0}" ]; then
    ok "$a_items author question(s), each apparently phrased as one"
  else
    maybe "$a_items author item(s) but only $a_marks question mark(s) — an imperative here is a task, and tasks belong under Run"
  fi
else
  maybe "no 'ask the author' part — legitimate only if nothing needs the author"
fi

# Validation steps are commands. An invented step is worse than none, because it burns
# the reader's trust on the first paste that fails — but a script can only check that
# something command-shaped is there at all.
if grep -Eq '<code|<pre' "$REGION"; then
  ok "validation steps carry command markup"
else
  bad "no <code> anywhere in section 6 — validations must be pasteable commands, not prose"
fi

finish
