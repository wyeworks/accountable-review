#!/bin/sh
# page-invariants.sh — the rules that hold everywhere on the page, and therefore in
# every fragment of it too: no grading, no unlabelled inference, no reserved attribute
# out of place, no dead links, no colour that exists in only one theme.
#
# Runs on a page or on a fragment. Three of these need the whole document — themes,
# the data-path census, link reachability — and say SKIP on a fragment rather than
# passing on evidence they do not have.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_input

# 1 · The severity vocabulary is gone from the design system. If these class names are
#     back, the page is grading again, whatever its prose says.
if grep -Eq 'chip-(block|watch|good)' "$IN"; then
  bad "severity chips reintroduced (chip-block/chip-watch/chip-good)"
else
  ok "no severity chips"
fi

# 2 · Verdict language. Deliberately high-precision patterns: 'blocking' alone is a
#     false positive ('blocks the request', 'locks the table'), so it is a WARN below
#     rather than a failure here.
if grep -Eiq 'LGTM|looks good to me|recommend (approv|merg)|approve this|ready to merge|risk score|overall risk' "$IN"; then
  bad "verdict language found: $(grep -Eio 'LGTM|looks good to me|recommend (approv|merg)[a-z]*|approve this|ready to merge|risk score|overall risk' "$IN" | sort -u | tr '\n' ' ')"
else
  ok "no verdict or approval language"
fi
if grep -Eq '>[[:space:]]*(Blocking|Watch)[[:space:]]*<' "$IN"; then
  maybe "a bare 'Blocking' or 'Watch' label is rendered — read it, it may be severity by another name"
fi
# 2b · Assurance language, which is a verdict about the page rather than about the PR and
#      therefore easy to reintroduce while believing rule 2 still holds. A run at --effort
#      high sends an adversarial pass at its own flows; nothing about that is allowed to
#      reach the page (SKILL.md step 8, report-format.md § Detail levels). The patterns are
#      high-precision on purpose: a bare 'verified' is a real column name in real Rails
#      apps, and 'audit' appears inside the sanctioned "a pass, not an audit".
ASSURE='(independently|adversarially|externally) verified|verification pass|falsification pass|(claims|findings) (were|have been|are all) (verified|checked|confirmed)|every claim (was|has been) (verified|checked)|class="(verified|checked)"|chip-verified'
if grep -Eiq "$ASSURE" "$IN"; then
  bad "assurance language — the page is advertising that it was checked: $(grep -Eio "$ASSURE" "$IN" | sort -u | tr '\n' ' ')"
else
  ok "no assurance language — the effort level is invisible on the page"
fi
if grep -Eiq 'clean bill of health' "$IN"; then
  maybe "'clean bill of health' appears — legitimate only as a denial; read the sentence"
fi

# 3 · Evidence tiers. Silence is the first tier, so a document with no label either had
#     nothing to infer, which is rare, or presented inference as fact, which is the
#     failure this catches.
if grep -q 'class="tier"' "$IN"; then
  ok "evidence tiers used ($(grep -c 'class="tier"' "$IN") label(s))"
else
  bad "no evidence tier labels — inference is being presented as fact, or none was marked"
fi

# 4 · Reserved attribute. coverage-gate.sh greps data-path across the whole page, so any
#     component other than a ledger row that emits it injects a surplus path and breaks
#     the gate. Source excerpts carry data-src for that reason. This check is here rather
#     than in the gate because the gate would only report a confusing surplus; this names
#     the cause.
#
#     The ledger is a CSS grid, not a <table>, so the cell that carries the path is
#     <div class="c" data-path="...">. Both forms are accepted: the old <td> so a page
#     built before the grid ledger still passes, and the grid cell for everything since.
dp=$(grep -o 'data-path="' "$IN" | wc -l | tr -d ' ')
dp_cell=$(grep -oE '<(td|div class="c")[[:space:]]+data-path="' "$IN" | wc -l | tr -d ' ')
if [ "$dp" -eq "$dp_cell" ]; then
  ok "data-path is only on ledger rows ($dp)"
else
  bad "$((dp - dp_cell)) data-path attribute(s) outside a ledger cell — the coverage gate reads them as ledger paths; excerpts must use data-src"
fi

# 5 · Dead links. When the head commit is on no remote, every permalink to it 404s, and
#     rung 4 of the ladder says plain text instead.
if [ -z "$REPO" ]; then
  skip "link reachability: needs --repo to ask git what is pushed"
else
  unpushed=$(git -C "$REPO" branch -r --contains "$HEAD_REF" 2>/dev/null || true)
  if [ -z "$unpushed" ]; then
    if grep -Eq 'https://github\.com/[^"]*/(blob|pull|compare)/' "$IN"; then
      bad "emits GitHub permalinks, but the head commit is on no remote — those 404"
    else
      ok "unpushed head: citations are plain text, no dead permalinks"
    fi
  else
    ok "head is on a remote: permalinks are legitimate (link form not checked here)"
  fi
fi

# 6 · The three theme states. A colour defined only inside a media query is the classic
#     unreadable-artifact bug; this catches the structural version of it. A fragment
#     carries no token block at all, so there is nothing here to check.
if [ "$IN_KIND" != page ]; then
  skip "theme states: a fragment carries no token block"
else
  missing_theme=
  grep -q 'prefers-color-scheme: dark' "$IN" || missing_theme="$missing_theme prefers-color-scheme"
  grep -Eq '\[data-theme="dark"\]' "$IN"     || missing_theme="$missing_theme data-theme=dark"
  grep -Eq '\[data-theme="light"\]|:root:not\(\[data-theme="light"\]\)|^:root|[^-]:root[[:space:]]*\{' "$IN" || missing_theme="$missing_theme bare-:root"
  if [ -z "$missing_theme" ]; then
    ok "all three theme states present"
  else
    bad "theme states missing:$missing_theme"
  fi

  # The blocks existing is not the same as a colour being in all three of them. --rails is
  # checked by name because it is the newest colour and the easiest to half-declare: nothing
  # on the page depends on it to be readable, so a set missing from the dark blocks is
  # invisible until someone opens a primer with the OS in dark mode. Same idiom as the
  # --syn-* sweep in excerpts.sh, and for the same reason.
  rails=$(grep -c -- '--rails:' "$IN" 2>/dev/null || true)
  if [ "${rails:-0}" -eq 0 ]; then
    skip "--rails: this page has no primer colour to check"
  elif [ "${rails:-0}" -ge 3 ]; then
    ok "--rails defined in all three theme blocks"
  else
    bad "--rails is declared ${rails} time(s), needs 3 — bare :root plus both dark blocks"
  fi
fi

finish
