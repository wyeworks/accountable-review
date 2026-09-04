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

# A comment is not markup, and the prose rules below must not read one. Two of them would
# otherwise fail a correct page for its own documentation: page-template.html's header comments
# discuss verdicts and revision history in the exact words those rules grep for, and a published
# page carries them verbatim. Found the hard way — a fixture planted a defect and ALSO described
# it in its own comment, so deleting the rule it tested left the fixture failing on the
# description and the mutation test reported a bypass as caught.
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
strip_comments "$IN" "$TMP/nocom"

# 1 · The severity vocabulary is gone from the design system. If these class names are
#     back, the page is grading again, whatever its prose says.
if grep -Eq 'chip-(block|watch|good)' "$IN"; then
  bad "severity chips reintroduced (chip-block/chip-watch/chip-good)"
else
  ok "no severity chips"
fi

# 2 · Verdict language, in two families, because one of them is legitimate as a DENIAL.
#
#     Deliberately high-precision patterns: 'blocking' alone is a false positive ('blocks the
#     request', 'locks the table'), so it is a WARN below rather than a failure here.
#
#     The split was forced by a correct page failing. § 7's ledger wrote "Attention is a reading
#     estimate, not a risk score" — the page telling the reader that read/skim/mechanical is not
#     severity, which is the no-grading invariant defending itself in the one place a reader is
#     most likely to misread a column as a grade. The check failed it for containing the words.
#     A rule that punishes a page for refusing a verdict teaches the run to stop refusing it out
#     loud, which is the opposite of what rule 2 is for.
#
#     So: HARD is never right in any form. A GRADED NOUN fails only where nothing refuses it —
#     the same shape as 2b's 'clean bill of health', which is legitimate only as a denial, except
#     that this one is common enough in a correct page to be worth deciding mechanically rather
#     than handing to a reader as a WARN.
VERDICT_HARD='LGTM|looks good to me|recommend (approv|merg)[a-z]*|approve this|ready to merge'
if grep -Eiq "$VERDICT_HARD" "$IN"; then
  bad "verdict language found: $(grep -Eio "$VERDICT_HARD" "$IN" | sort -u | tr '\n' ' ')"
else
  ok "no verdict or approval language"
fi
#     Per occurrence, not per document: one refused mention does not license an asserted one
#     elsewhere on the page. The window is the 48 characters before the noun, and a negation
#     counts only if nothing but short filler ("not a ", "rather than an ") stands between it
#     and the noun — so "not X, this is an overall risk of 4" is still caught. Sentence-ending
#     punctuation bounds the window, because the previous sentence's "not" is not this one's.
bare=$(awk '
  { l = tolower($0)
    while (match(l, /risk score|overall risk|severity score|severity rating/)) {
      s = RSTART; n = RLENGTH
      lo = s - 48; if (lo < 1) lo = 1
      pre = substr(l, lo, s - lo)
      # The negation must be a WHOLE WORD, bounded on both sides. POSIX awk has no \b, and
      # each missing boundary loses a real defect: without the leading one "no" matches inside
      # "another" and "denote", so "another way to read the overall risk" excuses itself;
      # without the trailing one "not" matches inside "notice" and "notify", so "notice the
      # overall risk" does too. Both were caught by testing the rule rather than reading it.
      if (pre !~ /(^|[^[:alpha:]])(not|nothing|never|no|rather than|instead of|without)([^[:alpha:]][^.!?;]{0,23})?$/) print substr(l, s, n)
      l = substr(l, s + n)
    } }' "$TMP/nocom" | sort -u | tr '\n' ' ')
if [ -n "$bare" ]; then
  bad "a graded noun asserted rather than refused: $bare"
else
  ok "no asserted risk or severity score"
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
# 2c · The page narrating its own drafting. A separate rule from 2b because it is a separate
#      failure with a separate fix: 2b is the page claiming it was checked, this is the page
#      telling the reader what an earlier draft of it said. Both leak the run's process, and
#      this one leaks it while reading as candour, which is why a run writes it without
#      noticing — one --effort high page carried ten, among them "the mistake the first
#      version of this section made" and "the first pass ran this over app/views alone and
#      found six". A falsification pass does not have to be named to be on the page.
#
#      The fix is never to delete the fact. A recorded search that needs -P to reproduce still
#      owes the reader that caveat; what it does not owe them is the autobiography. SKILL.md
#      step 8 owns the rule.
#
#      Comments are stripped first. page-template.html's own header comments are written in
#      exactly this register — "A previous version of this template showed the composition as
#      three detached siblings" — and ship verbatim inside every published page, so a check
#      reading them would fail every page for its template's documentation.
NARRATE='(first|earlier|previous|initial|original) (version|draft) of (this|the) (section|page|flow|paragraph|entry|list|row|claim|map|file)'
NARRATE=$NARRATE'|(a|the|this) (first|earlier|previous|initial) (pass|draft|version) (got|had|reported|missed|claimed|said|read|ran|rested|came)'
NARRATE=$NARRATE'|on (a|the) (first|earlier|previous) (pass|draft)'
NARRATE=$NARRATE'|(this|the) (section|page|paragraph|entry|claim|row) (originally|initially) (said|read|claimed|reported|had)'
if grep -Eiq "$NARRATE" "$TMP/nocom"; then
  bad "the page narrates its own drafting — a correction replaces a claim, it never annotates it: $(grep -Eio "$NARRATE" "$TMP/nocom" | sort -u | tr '\n' ' ')"
else
  ok "no draft narration — corrections are written as claims, not as revisions"
fi
if grep -Eiq 'got it wrong|came to rest on|invalidated (several|some) of these' "$TMP/nocom"; then
  maybe "a phrase that usually introduces draft history — read the sentence, and check it is about the code rather than about this page"
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
# An empty answer and NO answer are different, and only one of them means unpushed. Written
# with `|| true`, an unreadable repo or an unresolvable head produced empty output and this rule
# read it as "on no remote" — a false PASS on a page with no permalinks, and a false FAIL on one
# that has them. The verdict came from an answer git never gave, so the two are separated here
# and the rule refuses rather than guesses. A flat chain rather than a nested one because there
# are now three distinct states and nesting them hid that there were only two.
if [ -z "$REPO" ]; then
  skip "link reachability: needs --repo to ask git what is pushed"
elif ! remotes=$(git -C "$REPO" branch -r --contains "$HEAD_REF" 2>/dev/null); then
  skip "link reachability: git cannot say whether $HEAD_REF is pushed in $REPO — with no answer this rule has nothing to check the citation form against"
elif [ -z "$remotes" ]; then
  if grep -Eq 'https://github\.com/[^"]*/(blob|pull|compare)/' "$IN"; then
    bad "emits GitHub permalinks, but the head commit is on no remote — those 404"
  else
    ok "unpushed head: citations are plain text, no dead permalinks"
  fi
else
  ok "head is on a remote: permalinks are legitimate (link form not checked here)"
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
