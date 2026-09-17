#!/bin/sh
# application-code.sh — does this pull request change any application code?
#
#   Usage: application-code.sh --base SHA --head SHA [--repo-dir DIR]
#                              [--plugin-dir DIR] [--config FILE]
#                              [--trivial-files N] [--trivial-lines N]
#
# A Review Map explains application code: what a change means, what it reaches
# that it did not touch, and what a reviewer therefore has to judge. Two ways a
# pull request can fail to be worth one, and they are asked in this order.
#
# 1. IT CHANGES NO APPLICATION CODE. A lockfile bump, a README fix, a workflow
#    tweak, a batch of new specs — there is nothing for a map to explain.
#
# 2. WHAT IT CHANGES IS TRIVIAL. A couple of application files and a handful of
#    lines: a renamed local, a log line, a bumped constant. Skipped when the
#    application files are at or under --trivial-files AND the application lines
#    are at or under --trivial-lines. Both, never either.
#
# AND, NOT OR, AND THE POLARITY IS THE THING TO HOLD ON TO. A skip needs both
# measurements to be small, so ONE FILE OF NINE HUNDRED LINES IS GENERATED AND SO
# IS A NINE-LINE CHANGE ACROSS SIX FILES. Read from the other side that means the
# generate condition is an OR, which looks wrong to anyone who checks only that
# half — it is the same rule seen from the other end. An OR on the skip would
# discard a change that is large by either measurement, which is the wrong
# direction for a threshold whose failure is invisible: nobody notices the map
# they did not get.
#
# THE COUNTS ARE OVER APPLICATION PATHS ONLY, which is what makes them mean
# anything. A three-line model change beside a five-thousand-line lockfile is a
# three-line change here, and the whole-diff counts that the pull_request event
# payload offers would call it enormous. That is also why this cannot live in the
# workflow's `if:` — the payload has counts but not paths, so it can only count
# the wrong thing.
#
# WHAT THE THRESHOLD COSTS, stated plainly because the default is a judgement
# call and the numbers are a first calibration rather than a measurement: a map's
# value tracks what a change REACHES more closely than how big it is, and a
# three-line edit to a constructor default or a serializer reaches further than
# most large diffs. Those are the changes this discards first. Set trivial_lines
# to 0 in .accountable-review.yml to switch the threshold off and keep rule 1.
#
# FAIL OPEN. A path is application code unless it matches something below that is
# recognisably not — so a path nobody anticipated counts as code and earns a map.
# The exclusion list is kept narrow for that reason, and being narrow is cheap
# here in a way it would not be under a threshold: the verdict is a skip only
# when EVERY path is excluded, so one path misfiled as a test changes nothing
# unless the whole diff is misfiled. The expensive direction is the other one.
#
# WHAT IT DOES NOT KNOW. Whether a file is application code is a question about a
# repository, and this script reads only paths plus what diff-render.sh can tell
# it. Two known limits, neither worth machinery today: a repository whose product
# IS prose (this plugin, for one) has application changes under *.md that this
# calls documentation, and a team with an unusual layout can have code under a
# directory named here. Both fail towards skipping a map that was wanted, and
# both are visible — the job summary prints every path it discounted and why, so
# an unwanted skip is a thing someone can see and report rather than an absence
# they have to notice.
#
# Output is one line per changed path, tab-separated, plus comment lines. The
# fourth column is that path's changed lines, added plus deleted:
#
#   code<TAB>-<TAB>app/models/order.rb<TAB>12
#   skip<TAB>test<TAB>spec/models/order_spec.rb<TAB>40
#   skip<TAB>lockfile<TAB>yarn.lock<TAB>5183
#
# Exit 0 generate, 3 skip — 3 rather than 1 because a skip is a decision and not
# a failure, the same distinction install-workflow.sh draws for drift. 2 is being
# called wrongly and 4 is a ref this repository cannot resolve.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=$(dirname "$HERE")

# The defaults. A first calibration rather than a measured optimum: two files and
# twenty changed lines is about the size at which a change stops being a rename
# or a log line. They are the DEFAULT and not the rule — a team sets its own in
# .accountable-review.yml, and either at 0 turns the threshold off, since no
# change with application code in it has zero application files or lines.
TRIVIAL_FILES_DEFAULT=2
TRIVIAL_LINES_DEFAULT=20

BASE=; HEAD_REF=; REPO_DIR=.; PLUGIN_DIR=; CONFIG=
TRIVIAL_FILES=; TRIVIAL_LINES=

while [ $# -gt 0 ]; do
  case $1 in
    --base)           BASE=$2;          shift 2 ;;
    --head)           HEAD_REF=$2;      shift 2 ;;
    --repo-dir)       REPO_DIR=$2;      shift 2 ;;
    --plugin-dir)     PLUGIN_DIR=$2;    shift 2 ;;
    --config)         CONFIG=$2;        shift 2 ;;
    --trivial-files)  TRIVIAL_FILES=$2; shift 2 ;;
    --trivial-lines)  TRIVIAL_LINES=$2; shift 2 ;;
    -h|--help) sed -n '2,63p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "application-code.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$BASE" ] || { echo "application-code.sh: --base is required" >&2; exit 2; }
[ -n "$HEAD_REF" ] || { echo "application-code.sh: --head is required" >&2; exit 2; }
[ -n "$PLUGIN_DIR" ] || PLUGIN_DIR=$PLUGIN_ROOT

cd "$REPO_DIR"

# Flags beat the repository's config file, which beats the defaults — the same
# order as everything else here, and read at RUN time so changing a threshold
# never means regenerating the workflow. read-config.sh is the one thing that
# knows the file's shape.
READ_CONFIG=$PLUGIN_DIR/skills/setup-ci/scripts/read-config.sh
if [ -z "$CONFIG" ] && [ -f .accountable-review.yml ]; then CONFIG=.accountable-review.yml; fi
if [ -n "$CONFIG" ] && [ -f "$CONFIG" ] && [ -x "$READ_CONFIG" ]; then
  eval "$("$READ_CONFIG" "$CONFIG" --prefix CFG_)"
fi
[ -n "$TRIVIAL_FILES" ] || TRIVIAL_FILES=${CFG_trivial_files:-$TRIVIAL_FILES_DEFAULT}
[ -n "$TRIVIAL_LINES" ] || TRIVIAL_LINES=${CFG_trivial_lines:-$TRIVIAL_LINES_DEFAULT}

for n in "$TRIVIAL_FILES" "$TRIVIAL_LINES"; do
  case $n in
    ''|*[!0-9]*) echo "application-code.sh: trivial thresholds must be whole numbers, got '$n'" >&2
                 exit 2 ;;
  esac
done

# ASKED AND UNABLE TO ANSWER IS NOT AN EMPTY DIFF. Every failure mode below ends
# in zero application paths, which is the skip verdict — the most reassuring
# thing this script can say and the one with the least behind it. A shallow
# clone, a base that was never fetched, a git that broke: each produces no rows
# and exit 0 through a pipeline, and each would silently suppress the Review Map
# for every pull request in the repository. So the refs are resolved first and an
# unresolvable one is fatal, never a verdict. This repository has paid for this
# shape twice already — diff-render.sh carries the same guard for the same
# reason, and page-invariants.rb § 5 for its sibling.
for ref in "$BASE" "$HEAD_REF"; do
  if ! git rev-parse --verify --quiet "$ref^{commit}" >/dev/null 2>&1; then
    echo "application-code.sh: cannot resolve $ref in this repository." >&2
    echo "The diff decides whether there is anything to explain, so a diff that cannot be" >&2
    echo "read is an error rather than an empty one. Check out with fetch-depth: 0." >&2
    exit 4
  fi
done

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# --numstat rather than --name-only, because the line counts and the path list
# have to come from ONE command: two reads of the same diff can disagree about a
# rename, and then a path is classified with another path's line count.
# --no-renames for the same reason — it makes a rename a delete plus an add, so
# every row is one path rather than `old => new`, which nothing downstream parses.
git diff --numstat --no-renames "$BASE...$HEAD_REF" > "$TMP/numstat" || {
  echo "application-code.sh: git diff $BASE...$HEAD_REF failed" >&2
  exit 1
}
cut -f3- "$TMP/numstat" > "$TMP/paths"

# Generated files, binaries and lockfiles are not judged from the path at all —
# diff-render.sh already decides that question, from .gitattributes, from the
# bytes and from a dated list of lockfile names, and it is maintained because the
# page's link forms depend on it. Borrowing it is what keeps this script from
# growing a second copy of that list to drift against the first.
#
# ONLY THREE OF ITS REASONS ARE READ HERE. It also collapses a file for being
# big — `over-autoload`, `over-hard-cap` — and those are verdicts about GitHub's
# rendering, not about whether a person wrote the lines. Treating them as
# not-application would smuggle a size threshold back in through the one part of
# this script that looks like it is about file types, and it would discard
# exactly the large, hand-written change a reviewer most needs the map for.
DIFF_RENDER=$PLUGIN_DIR/skills/review-map/scripts/diff-render.sh
: > "$TMP/generated"
if [ -x "$DIFF_RENDER" ]; then
  "$DIFF_RENDER" "$BASE" "$HEAD_REF" > "$TMP/render" || {
    echo "application-code.sh: diff-render.sh failed — refusing to guess at generated files" >&2
    exit 1
  }
  awk -F'\t' '$1 == "collapse" && ($2 == "generated" || $2 == "binary" || $2 == "lockfile") \
    { print $3 "\t" $2 }' "$TMP/render" > "$TMP/generated"
fi

generated_reason() {
  awk -F'\t' -v p="$1" '$1 == p { print $2; exit }' "$TMP/generated"
}

# The exclusion list. Narrow on purpose — see FAIL OPEN above — and grouped by
# the reason it prints, because the reason is what the job summary shows someone
# who wanted a map and did not get one.
classify() {
  _path=$1
  _lines=$2

  _why=$(generated_reason "$_path")
  if [ -n "$_why" ]; then
    printf 'skip\t%s\t%s\t%s\n' "$_why" "$_path" "$_lines"
    return
  fi

  case $_path in
    # Tests state intent and the map reads them, but a diff that is only tests
    # changes no behaviour for them to state. Directory names are matched as
    # path segments rather than anchored at the root, so a monorepo's api/spec
    # counts the same as a Rails app's spec.
    spec/*|*/spec/*|test/*|*/test/*|tests/*|*/tests/*|\
    features/*|*/features/*|cypress/*|*/cypress/*|e2e/*|*/e2e/*|*/__tests__/*|\
    *_test.rb|*_spec.rb|*_test.exs|*_test.go|*_test.py|\
    *.test.js|*.test.jsx|*.test.ts|*.test.tsx|\
    *.spec.js|*.spec.jsx|*.spec.ts|*.spec.tsx)
      printf 'skip\ttest\t%s\t%s\n' "$_path" "$_lines" ;;

    *.md|*.mdx|*.rdoc|*.txt|docs/*|*/docs/*|doc/*|*/doc/*|\
    LICENSE|LICENSE.*|CHANGELOG|CHANGELOG.*|AUTHORS|NOTICE)
      printf 'skip\tdocs\t%s\t%s\n' "$_path" "$_lines" ;;

    # Repository tooling: how the project is checked, formatted and built, as
    # distinct from what it does. Note what is NOT here — config/ is where a
    # Rails app keeps its routes and its initializers, a Dockerfile and a compose
    # file describe how the thing runs, and every one of those is application
    # code by this script's reckoning.
    .github/*|.gitignore|.gitattributes|.editorconfig|.dockerignore|\
    .tool-versions|.ruby-version|.node-version|.nvmrc|.rspec|\
    .rubocop.yml|.rubocop_todo.yml|.credo.exs|.formatter.exs|\
    .prettierrc*|.prettierignore|.eslintrc*|.eslintignore|\
    CODEOWNERS|.github/CODEOWNERS|renovate.json|.dependabot/*)
      printf 'skip\ttooling\t%s\t%s\n' "$_path" "$_lines" ;;

    # THE DEFAULT, and the line that makes this fail open. An edit that moves it
    # to a skip verdict turns every unrecognised path into a reason to publish
    # nothing.
    *)
      printf 'code\t-\t%s\t%s\n' "$_path" "$_lines" ;;
  esac
}

: > "$TMP/verdicts"
while IFS='	' read -r add del path; do
  [ -n "$path" ] || continue
  # A binary file's counts are dashes. It is a `binary` path anyway, so the
  # number is never summed — but the arithmetic below cannot run on a dash.
  case $add in *[!0-9]*) add=0 ;; esac
  case $del in *[!0-9]*) del=0 ;; esac
  classify "$path" "$((add + del))" >> "$TMP/verdicts"
done < "$TMP/numstat"

sort -k3 "$TMP/verdicts"

changed=$(wc -l < "$TMP/paths" | tr -d ' ')
application=$(awk -F'\t' '$1 == "code"' "$TMP/verdicts" | wc -l | tr -d ' ')
# Application lines only. Summing the whole diff would make one lockfile enough
# to call any change substantial, which is the measurement this gate replaced.
lines=$(awk -F'\t' '$1 == "code" { n += $4 } END { print n + 0 }' "$TMP/verdicts")

printf '<!-- %s changed path(s); %s application file(s), %s application line(s) -->\n' \
  "$changed" "$application" "$lines"

# Rule 1, then rule 2. The order matters only for the reason it reports, and the
# reason is the whole of what the job summary can tell someone who wanted a map.
if [ "$application" -eq 0 ]; then
  verdict=skip; reason=no-application-code
  printf '<!-- nothing outside tests, documentation, tooling and generated files changed -->\n'
elif [ "$application" -le "$TRIVIAL_FILES" ] && [ "$lines" -le "$TRIVIAL_LINES" ]; then
  # AND, never OR: both measurements have to be small. Either one alone above its
  # threshold earns a map, which is what keeps one big file and many small ones
  # on the generating side.
  verdict=skip; reason=trivial
  printf '<!-- %s application file(s) and %s line(s), at or under the trivial threshold (%s file(s), %s line(s)) -->\n' \
    "$application" "$lines" "$TRIVIAL_FILES" "$TRIVIAL_LINES"
else
  verdict=generate; reason=application-code
fi

# The verdict, on stdout as well as in the step outputs. The workflow reads the
# outputs; a person reads the log, and a skip whose reason is only in a variable
# is a skip they cannot account for.
printf '<!-- verdict: %s (%s) -->\n' "$verdict" "$reason"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "verdict=$verdict"
    echo "reason=$reason"
    echo "changed=$changed"
    echo "application=$application"
    echo "lines=$lines"
    echo "trivial_files=$TRIVIAL_FILES"
    echo "trivial_lines=$TRIVIAL_LINES"
  } >> "$GITHUB_OUTPUT"
fi

[ "$verdict" = generate ] || exit 3
