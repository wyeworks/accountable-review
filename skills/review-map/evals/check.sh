#!/bin/sh
# check.sh — the mechanical half of an eval.
#
#   Usage: check.sh --page <file> --repo <dir> --base <ref> [--head <ref>]
#                   [--draft | --final] [--expect <substring>]... [--forbid <substring>]...
#
# Some expectations in evals.json need a reader: whether the grouping is
# defensible, whether a decision was worth naming. Those belong to a human or a
# grader agent. The ones here do not — they are yes-or-no facts about the page,
# and a script checks them the same way every time, for free, in CI.
#
# The split matters: a grader asked to check thirty things does all of them
# sloppily. Take the mechanical ones away and it can spend its attention on
# judgement.
#
# Three page states, three modes:
#   --draft    published mid-run. It must admit it is unfinished.
#   --final    the last publish of a completed run. The gate runs; no build-state
#              markers may remain.
#   --stopped  a run that ended early on purpose. The banner has to state what was
#              not written, rather than promise stages that are never coming.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PAGE=; REPO=; BASE=; HEAD_REF=HEAD; MODE=final
EXPECTS=; FORBIDS=
pass=0; fail=0; warn=0

while [ $# -gt 0 ]; do
  case $1 in
    --page)   PAGE=$2; shift 2 ;;
    --repo)   REPO=$2; shift 2 ;;
    --base)   BASE=$2; shift 2 ;;
    --head)   HEAD_REF=$2; shift 2 ;;
    --draft)  MODE=draft; shift ;;
    --final)  MODE=final; shift ;;
    --stopped) MODE=stopped; shift ;;
    --expect) EXPECTS="$EXPECTS$2
"; shift 2 ;;
    --forbid) FORBIDS="$FORBIDS$2
"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$PAGE" ] || [ -z "$REPO" ] || [ -z "$BASE" ]; then
  echo "usage: check.sh --page <file> --repo <dir> --base <ref> [--head <ref>]" >&2
  echo "                [--draft | --final] [--expect <substring>]... [--forbid <substring>]..." >&2
  exit 2
fi
[ -r "$PAGE" ] || { echo "FAIL  page is not readable: $PAGE"; exit 1; }

ok()    { pass=$((pass+1)); echo "PASS  $1"; }
bad()   { fail=$((fail+1)); echo "FAIL  $1"; }
maybe() { warn=$((warn+1)); echo "WARN  $1"; }

# 1 · Completeness. Delegated, so there is exactly one implementation of the rule.
#     A draft ships before the ledger is complete, so this is a final-only check —
#     running it on a draft would only teach people to ignore a red line.
if [ "$MODE" = final ]; then
  if (cd "$REPO" && "$HERE/../scripts/coverage-gate.sh" "$PAGE" "$BASE" "$HEAD_REF" >/dev/null 2>&1); then
    ok "coverage gate: every changed path is in the ledger"
  else
    bad "coverage gate failed — run scripts/coverage-gate.sh directly to see which paths"
  fi
fi

# 2 · Build state, which has three legitimate shapes. A draft must admit it is one.
#     A finished page must not still claim to be one — that undersells completed work.
#     A stopped run is the third: it must state what was not written rather than leave
#     a promise of stages that are never coming.
case $MODE in
  draft)
    if grep -q 'class="buildstate"' "$PAGE"; then
      ok "draft carries the build banner"
    else
      bad "draft has no build banner — a half-written page that looks finished"
    fi
    if grep -Fq "absence is not a finding" "$PAGE"; then
      ok "banner says a pending part is not an absent one"
    else
      bad "banner is missing the sentence that stops a pending part reading as nothing to say"
    fi
    if grep -q 'class="pending"' "$PAGE"; then
      ok "pending markers present ($(grep -c 'class="pending"' "$PAGE"))"
    else
      bad "no pending markers — the reader cannot see what is still coming"
    fi
    ;;
  stopped)
    if grep -q 'class="buildstate"' "$PAGE"; then
      ok "stopped run still explains its own state"
    else
      bad "a stopped run with no banner reads as a finished page with parts missing"
    fi
    if grep -Fq "Still being written" "$PAGE"; then
      bad "banner still says 'still being written' — nothing is writing it any more"
    else
      ok "banner does not promise work that is not coming"
    fi
    if grep -Fq "not written" "$PAGE"; then
      ok "the limit is stated in words"
    else
      bad "no statement of what was left unwritten — that is the whole point of this state"
    fi
    if grep -q 'class="pending">pending' "$PAGE"; then
      bad "markers still say 'pending', which is a promise; a stopped run says 'not written'"
    else
      ok "markers state a fact rather than a promise"
    fi
    ;;
  *)
    leftover=$(grep -c 'class="buildstate"\|class="pending"' "$PAGE" || true)
    if [ "${leftover:-0}" -eq 0 ]; then
      ok "no build banner or pending markers left on the finished page"
    else
      bad "finished page still carries $leftover build-state element(s) — they were not removed"
    fi
    ;;
esac

# 3 · The severity vocabulary is gone from the design system. If these class names
#     are back, the page is grading again, whatever its prose says.
if grep -Eq 'chip-(block|watch|good)' "$PAGE"; then
  bad "severity chips reintroduced (chip-block/chip-watch/chip-good)"
else
  ok "no severity chips"
fi

# 4 · Verdict language. Deliberately high-precision patterns: 'blocking' alone is a
#     false positive ('blocks the request', 'locks the table'), so it is a WARN below
#     rather than a failure here.
if grep -Eiq 'LGTM|looks good to me|recommend (approv|merg)|approve this|ready to merge|risk score|overall risk' "$PAGE"; then
  bad "verdict language found: $(grep -Eio 'LGTM|looks good to me|recommend (approv|merg)[a-z]*|approve this|ready to merge|risk score|overall risk' "$PAGE" | sort -u | tr '\n' ' ')"
else
  ok "no verdict or approval language"
fi
if grep -Eq '>[[:space:]]*(Blocking|Watch)[[:space:]]*<' "$PAGE"; then
  maybe "a bare 'Blocking' or 'Watch' label is rendered — read it, it may be severity by another name"
fi

# 5 · Evidence tiers. A page with no tier label either had nothing to infer, which is
#     rare, or presented inference as fact, which is the failure this catches.
if grep -q 'class="tier"' "$PAGE"; then
  ok "evidence tiers used ($(grep -c 'class="tier"' "$PAGE") label(s))"
else
  bad "no evidence tier labels — inference is being presented as fact, or none was marked"
fi

# 6 · Dead links. When the head commit is on no remote, every permalink to it 404s.
unpushed=$(git -C "$REPO" branch -r --contains "$HEAD_REF" 2>/dev/null || true)
if [ -z "$unpushed" ]; then
  if grep -Eq 'https://github\.com/[^"]*/(blob|pull)/' "$PAGE"; then
    bad "page emits GitHub permalinks, but the head commit is on no remote — those 404"
  else
    ok "unpushed head: citations are plain text, no dead permalinks"
  fi
else
  ok "head is on a remote: permalinks are legitimate (link form not checked here)"
fi

# 7 · The three theme states. A colour defined only inside a media query is the classic
#     unreadable-artifact bug; this catches the structural version of it.
missing_theme=
grep -q 'prefers-color-scheme: dark' "$PAGE" || missing_theme="$missing_theme prefers-color-scheme"
grep -Eq '\[data-theme="dark"\]' "$PAGE"     || missing_theme="$missing_theme data-theme=dark"
grep -Eq '\[data-theme="light"\]|:root:not\(\[data-theme="light"\]\)|^:root|[^-]:root[[:space:]]*\{' "$PAGE" || missing_theme="$missing_theme bare-:root"
if [ -z "$missing_theme" ]; then
  ok "all three theme states present"
else
  bad "theme states missing:$missing_theme"
fi

# 8 · Case-specific: the planted findings, and whatever this case forbids.
TMPF=$(mktemp)
trap 'rm -f "$TMPF"' EXIT
echo "$EXPECTS" | while IFS= read -r e; do
  [ -z "$e" ] && continue
  if grep -Fq "$e" "$PAGE"; then echo "PASS  mentions: $e"; else echo "FAIL  never mentions: $e"; fi
done > "$TMPF"
echo "$FORBIDS" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  if grep -Fq "$f" "$PAGE"; then echo "FAIL  should not contain: $f"; else echo "PASS  absent, as required: $f"; fi
done >> "$TMPF"
cat "$TMPF"
pass=$((pass + $(grep -c '^PASS' "$TMPF" || true)))
fail=$((fail + $(grep -c '^FAIL' "$TMPF" || true)))

echo
echo "$MODE: $pass passed, $fail failed, $warn warning(s)"
[ "$fail" -eq 0 ]
