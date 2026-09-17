#!/bin/sh
# application-code.sh — does this pull request change any application code?
#
#   Usage: application-code.sh --base SHA --head SHA [--repo-dir DIR] [--plugin-dir DIR]
#
# A Review Map explains application code: what a change means, what it reaches
# that it did not touch, and what a reviewer therefore has to judge. A pull
# request that changes none of it — a lockfile bump, a README fix, a workflow
# tweak, a batch of new specs — has nothing for the map to explain, and
# generating one costs a model run to say so at length.
#
# THE RULE IS PRESENCE, NOT AMOUNT. Any application path in the diff and the
# answer is generate; none and it is skip. There is no file count and no line
# count anywhere in here, deliberately, because this product's value scales with
# what a change REACHES rather than with how big it is — a three-line change to a
# constructor default or a serializer is the change whose blast radius a reviewer
# most reliably misjudges, and it is the one any magnitude threshold discards
# first. A threshold on application lines would be the files-and-lines mistake
# committed one level further in.
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
# Output is one line per changed path, tab-separated, plus comment lines:
#
#   code<TAB>-<TAB>app/models/order.rb
#   skip<TAB>test<TAB>spec/models/order_spec.rb
#   skip<TAB>lockfile<TAB>yarn.lock
#
# Exit 0 generate, 3 skip — 3 rather than 1 because a skip is a decision and not
# a failure, the same distinction install-workflow.sh draws for drift. 2 is being
# called wrongly and 4 is a ref this repository cannot resolve.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=$(dirname "$HERE")

BASE=; HEAD_REF=; REPO_DIR=.; PLUGIN_DIR=

while [ $# -gt 0 ]; do
  case $1 in
    --base)       BASE=$2;       shift 2 ;;
    --head)       HEAD_REF=$2;   shift 2 ;;
    --repo-dir)   REPO_DIR=$2;   shift 2 ;;
    --plugin-dir) PLUGIN_DIR=$2; shift 2 ;;
    -h|--help) sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "application-code.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$BASE" ] || { echo "application-code.sh: --base is required" >&2; exit 2; }
[ -n "$HEAD_REF" ] || { echo "application-code.sh: --head is required" >&2; exit 2; }
[ -n "$PLUGIN_DIR" ] || PLUGIN_DIR=$PLUGIN_ROOT

cd "$REPO_DIR"

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

git diff --name-only "$BASE...$HEAD_REF" > "$TMP/paths" || {
  echo "application-code.sh: git diff $BASE...$HEAD_REF failed" >&2
  exit 1
}

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

  _why=$(generated_reason "$_path")
  if [ -n "$_why" ]; then
    printf 'skip\t%s\t%s\n' "$_why" "$_path"
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
      printf 'skip\ttest\t%s\n' "$_path" ;;

    *.md|*.mdx|*.rdoc|*.txt|docs/*|*/docs/*|doc/*|*/doc/*|\
    LICENSE|LICENSE.*|CHANGELOG|CHANGELOG.*|AUTHORS|NOTICE)
      printf 'skip\tdocs\t%s\n' "$_path" ;;

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
      printf 'skip\ttooling\t%s\n' "$_path" ;;

    # THE DEFAULT, and the line that makes this fail open. An edit that moves it
    # to a skip verdict turns every unrecognised path into a reason to publish
    # nothing.
    *)
      printf 'code\t-\t%s\n' "$_path" ;;
  esac
}

: > "$TMP/verdicts"
while IFS= read -r path; do
  [ -n "$path" ] || continue
  classify "$path" >> "$TMP/verdicts"
done < "$TMP/paths"

sort -k3 "$TMP/verdicts"

changed=$(wc -l < "$TMP/paths" | tr -d ' ')
application=$(awk -F'\t' '$1 == "code"' "$TMP/verdicts" | wc -l | tr -d ' ')

printf '<!-- %s changed path(s), %s of them application code -->\n' "$changed" "$application"

if [ "$application" -gt 0 ]; then
  verdict=generate
else
  verdict=skip
  printf '<!-- nothing outside tests, documentation, tooling and generated files changed -->\n'
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "verdict=$verdict"
    echo "changed=$changed"
    echo "application=$application"
  } >> "$GITHUB_OUTPUT"
fi

[ "$verdict" = generate ] || exit 3
