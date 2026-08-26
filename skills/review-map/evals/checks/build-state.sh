#!/bin/sh
# build-state.sh — the page has three legitimate states, and they must not be
# confusable.
#
#   draft    published mid-run. It must admit it is unfinished.
#   final    the last publish of a completed run. No build-state markers may remain.
#   stopped  a run that ended early on purpose. The banner states what was not
#            written rather than promising stages that are never coming.
#
# The risk this guards is one reader mistake: taking a pending part for "nothing to
# say here".
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_kind page

case $MODE in
  draft)
    if grep -q 'class="buildstate"' "$IN"; then
      ok "draft carries the build banner"
    else
      bad "draft has no build banner — a half-written page that looks finished"
    fi
    if grep -Fq "absence is not a finding" "$IN"; then
      ok "banner says a pending part is not an absent one"
    else
      bad "banner is missing the sentence that stops a pending part reading as nothing to say"
    fi
    if grep -q 'class="pending"' "$IN"; then
      ok "pending markers present ($(grep -c 'class="pending"' "$IN"))"
    else
      bad "no pending markers — the reader cannot see what is still coming"
    fi
    ;;
  stopped)
    if grep -q 'class="buildstate"' "$IN"; then
      ok "stopped run still explains its own state"
    else
      bad "a stopped run with no banner reads as a finished page with parts missing"
    fi
    if grep -Fq "Still being written" "$IN"; then
      bad "banner still says 'still being written' — nothing is writing it any more"
    else
      ok "banner does not promise work that is not coming"
    fi
    if grep -Fq "not written" "$IN"; then
      ok "the limit is stated in words"
    else
      bad "no statement of what was left unwritten — that is the whole point of this state"
    fi
    if grep -q 'class="pending">pending' "$IN"; then
      bad "markers still say 'pending', which is a promise; a stopped run says 'not written'"
    else
      ok "markers state a fact rather than a promise"
    fi
    ;;
  *)
    leftover=$(grep -c 'class="buildstate"\|class="pending"' "$IN" || true)
    if [ "${leftover:-0}" -eq 0 ]; then
      ok "no build banner or pending markers left on the finished page"
    else
      bad "finished page still carries $leftover build-state element(s) — they were not removed"
    fi
    ;;
esac

finish
