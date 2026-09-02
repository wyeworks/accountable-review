#!/bin/sh
# lib.sh — shared plumbing for the check scripts in this directory.
#
# Every check script prints one line per expectation and nothing else:
#
#   PASS  what held
#   FAIL  what did not
#   WARN  what needs a human to look
#   SKIP  what could not run on this input, and why
#
# check.sh dispatches several of them and tallies those lines, which is why the
# prefixes are fixed and why a dispatched script prints no summary of its own.
#
# SKIP is not decoration. A check that cannot run here has to say so out loud: a
# fragment has no :root, no ledger and no build banner, and silently dropping those
# checks is how a fragment ends up reading as thoroughly verified as a page.
#
# Callers set CHECKS_DIR before sourcing — POSIX sh cannot find the path of the file
# being sourced.

pass=0; fail=0; warn=0; skipped=0

: "${CHECKS_DIR:?CHECKS_DIR must be set before sourcing lib.sh}"
EVALS_DIR=$(dirname "$CHECKS_DIR")
SKILL_DIR=$(dirname "$EVALS_DIR")

ok()    { pass=$((pass+1));       echo "PASS  $1"; }
bad()   { fail=$((fail+1));       echo "FAIL  $1"; }
maybe() { warn=$((warn+1));       echo "WARN  $1"; }
skip()  { skipped=$((skipped+1)); echo "SKIP  $1"; }

# Two kinds of input. A page is a whole published document; a fragment is one section,
# produced by a driver in ../drivers from the frozen upstream in ../frozen. Checks that
# need the whole document refuse a fragment rather than passing vacuously on it.
#
# LEVEL is the skill's detail level, and it is a THIRD axis: MODE is build state
# (draft/final/stopped) and SCOPE is which section, neither of which says how many
# sections the page was supposed to have. It defaults to `full` so every existing
# golden fragment and page case keeps meaning exactly what it meant — a check that
# quietly reinterpreted its own corpus would be measuring the wrong thing.
IN=; IN_KIND=; REPO=; BASE=; HEAD_REF=HEAD; MODE=final; SCOPE=; VISUAL=0; OUTDIR=
LEVEL=full
EXPECTS=; FORBIDS=

parse_args() {
  while [ $# -gt 0 ]; do
    case $1 in
      --page)     IN=$2; IN_KIND=page;     shift 2 ;;
      --fragment) IN=$2; IN_KIND=fragment; shift 2 ;;
      --repo)     REPO=$2;     shift 2 ;;
      --base)     BASE=$2;     shift 2 ;;
      --head)     HEAD_REF=$2; shift 2 ;;
      --draft)    MODE=draft;   shift ;;
      --final)    MODE=final;   shift ;;
      --stopped)  MODE=stopped; shift ;;
      --scope)    SCOPE=$2;  shift 2 ;;
      --level)    LEVEL=$2;  shift 2 ;;
      --out)      OUTDIR=$2; shift 2 ;;
      --visual)   VISUAL=1;  shift ;;
      --expect)   EXPECTS="$EXPECTS$2
"; shift 2 ;;
      --forbid)   FORBIDS="$FORBIDS$2
"; shift 2 ;;
      *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
  done
}

require_input() {
  if [ -z "$IN" ]; then
    echo "usage: $(basename "$0") --page <file> | --fragment <file> [--repo D --base REF]" >&2
    exit 2
  fi
  [ -r "$IN" ] || { echo "FAIL  input is not readable: $IN"; exit 1; }
}

# Exit 3, not 1: the dispatcher treats it as "this check does not apply here", which is
# a different thing from a failure and must not read as one.
require_kind() {
  require_input
  if [ "$IN_KIND" != "$1" ]; then
    echo "SKIP  $(basename "$0") needs a whole $1, got a $IN_KIND"
    exit 3
  fi
}

finish() {
  if [ "${CHECK_TALLY:-1}" = 1 ]; then
    echo
    echo "$(basename "$0"): $pass passed, $fail failed, $warn warning(s), $skipped skipped"
  fi
  [ "$fail" -eq 0 ]
}

# strip_comments <src> <dest> — write <src> to <dest> with every HTML comment removed, line
# structure preserved.
#
# A comment is not markup, and no check may let one steer it. The case that forced this: a
# golden documents its own anchors in a header comment ("id=\"blast\" on the <section> ... is
# what before-approving.sh reads"), and blast-radius.sh — which bounds section 4 at those
# anchors — ended the region on the sentence describing it, reporting the fixture as having no
# blast panel at all. Real pages are exposed the same way, because a published page carries
# page-template.html's header comments verbatim, and those comments discuss the very class and
# id names the checks grep for.
strip_comments() {
  awk '
    {
      s = $0; out = ""
      while (1) {
        if (incom) {
          i = index(s, "-->")
          if (i == 0) { s = ""; break }
          incom = 0; s = substr(s, i + 3); continue
        }
        i = index(s, "<!--")
        if (i == 0) { out = out s; break }
        out = out substr(s, 1, i - 1); s = substr(s, i + 4); incom = 1
      }
      print out
    }
  ' "$1" > "$2"
}
