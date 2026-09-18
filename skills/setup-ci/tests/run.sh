#!/bin/sh
# run.sh — the deterministic tests for the CI setup.
#
#   Usage: tests/run.sh
#
# Everything about generating a Review Map is a model run and cannot be asserted
# on. Everything about *arranging* for one is ordinary software, and this is where
# that half is held to account: what the generated workflow contains, that setup
# leaves other people's CI alone, that running it twice is safe, that a config
# file is actually respected, and that the delivery seam returns what its contract
# says it does.
#
# No network, no model, no API key, about a second. It runs in CI on every push,
# because a check that is not run is not a check.
#
# One line per expectation, PASS or FAIL, in the same idiom as
# skills/review-map/evals/checks — a test that prints nothing when it passes is a
# test nobody can tell apart from one that never ran.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_DIR=$(dirname "$HERE")
PLUGIN_ROOT=$(dirname "$(dirname "$SKILL_DIR")")

RENDER=$SKILL_DIR/scripts/render-workflow.sh
INSTALL=$SKILL_DIR/scripts/install-workflow.sh
READ_CONFIG=$SKILL_DIR/scripts/read-config.sh
INSPECT=$SKILL_DIR/scripts/inspect-repo.sh
GENERATE=$PLUGIN_ROOT/ci/generate-review-map.sh
DELIVER=$PLUGIN_ROOT/ci/delivery/deliver.sh

pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "PASS  $1"; }
bad() { fail=$((fail + 1)); echo "FAIL  $1"; }

# assert_in <file> <string> <what>
assert_in() { if grep -Fq -e "$2" "$1"; then ok "$3"; else bad "$3"; fi; }
assert_not_in() { if grep -Fq -e "$2" "$1"; then bad "$3"; else ok "$3"; fi; }
assert_eq() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (got '$1', wanted '$2')"; fi; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# A repository that has CI already, and none of it ours. Everything about
# preservation is measured against this.
fixture_repo() {
  d=$1
  mkdir -p "$d/.github/workflows"
  cat > "$d/.github/workflows/tests.yml" <<'Y'
name: tests
on: [push, pull_request]
jobs:
  rspec:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bundle exec rspec
Y
  cat > "$d/.github/workflows/lint.yml" <<'Y'
name: lint
on: pull_request
jobs:
  rubocop:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bundle exec rubocop
Y
  ( cd "$d" && git init -q . && git config user.email t@example.com && git config user.name t \
      && git add -A && git commit -qm init )
}

echo "== the generated workflow =="

W=$TMP/workflow.yml
"$RENDER" > "$W"

# The negative assertions run against a comment-stripped copy. The workflow
# explains, in comments, why it does not use pull_request_target and does not
# boot the application — and a test that could not tell an explanation from an
# instruction would forbid the file from documenting its own reasoning.
W_CODE=$TMP/workflow.code.yml
grep -v '^[[:space:]]*#' "$W" > "$W_CODE"

assert_in "$W" "name: Accountable Review"              "it is a workflow named for the plugin"
assert_in "$W" "  pull_request:"                       "it triggers on pull_request"
assert_in "$W" "      - opened"                        "trigger: opened"
assert_in "$W" "      - ready_for_review"              "trigger: ready_for_review"
assert_in "$W" "      - reopened"                      "trigger: reopened"
# Not by default: one Review Map per pull request is the shipped answer, and a
# push regenerating it is the thing a person turns on knowing what it costs.
assert_not_in "$W_CODE" "      - synchronize"               "pushes do not regenerate the map by default"
assert_not_in "$W_CODE" "      - labeled"                   "no trigger on labels"
assert_not_in "$W_CODE" "      - edited"                    "no trigger on edits to the description"
assert_not_in "$W_CODE" "pull_request_target"               "never pull_request_target"

assert_in "$W" "github.event.pull_request.draft == false"                          "draft pull requests are skipped"
assert_in "$W" "github.event.pull_request.head.repo.full_name == github.repository" "fork pull requests are skipped"
assert_in "$W" "github.event.pull_request.user.login != 'dependabot[bot]'"          "a bot's pull requests are skipped"
# How big a change has to be is decided after the checkout, by a script reading
# the real diff — not here. These three fields count the WHOLE diff and come with
# no file list, so a threshold written against them can only ever measure the
# wrong thing: a three-line model change beside a five-thousand-line lockfile
# reads as enormous. Their absence is the assertion.
assert_not_in "$W_CODE" "changed_files"                     "the job condition counts no files"
assert_not_in "$W_CODE" "pull_request.additions"            "nor added lines"
assert_not_in "$W_CODE" "pull_request.deletions"            "nor deleted ones"

# The two ways to write an `if:` GitHub rejects outright — no job created, and an
# error naming neither the line nor the reason. Both shipped once.
#
# Expressions have no arithmetic operators, so `additions + deletions` is an
# invalid-file error rather than a sum.
expr=$(awk '/^    if: >-/{f=1;next} f && /^      /{print} f && !/^      /{exit}' "$W")
case $expr in
  *' + '*|*' - '*|*' * '*) bad "the guard expression uses no arithmetic" ;;
  *) ok "the guard expression uses no arithmetic" ;;
esac

# And in a folded scalar a more-indented line keeps its newline, which lands
# inside the expression string. Every line has to sit at the same indentation, so
# the temptation to align a parenthesis is the defect.
if [ -n "$expr" ] && [ "$(printf '%s\n' "$expr" | grep -c '^      [^ ]')" = "$(printf '%s\n' "$expr" | wc -l | tr -d ' ')" ]; then
  ok "every line of the guard expression is at the same indentation"
else
  bad "every line of the guard expression is at the same indentation"
fi

assert_in "$W" "group: accountable-review-\${{ github.event.pull_request.number }}" "concurrency is scoped to the pull request"
assert_in "$W" "cancel-in-progress: true"              "superseded runs are cancelled"

assert_in "$W" "permissions:"                          "permissions are declared"
assert_in "$W" "  contents: read"                      "the repository is read, never written"
assert_not_in "$W_CODE" "contents: write"                   "nothing asks to write the repository's contents"
assert_not_in "$W_CODE" "issues: write"                     "nothing asks to write issues"
assert_not_in "$W_CODE" "checks: write"                     "nothing asks to set a check"
assert_not_in "$W_CODE" "statuses: write"                   "nothing asks to set a status"
# `pull-requests: write` is asserted in the comment section below, where it is
# paired with the step that uses it — the two are only ever right together.

assert_in "$W" "fetch-depth: 0"                        "the checkout has the history the diff needs"
assert_in "$W" "ref: \${{ github.event.pull_request.head.sha }}" "it checks out the pull request head, not a merge commit"
assert_in "$W" "persist-credentials: false"            "no git credentials are left beside the checkout"

assert_in "$W" "ci/application-code.sh"                "the run is scoped by the application-code gate"
assert_in "$W" "id: scope"                             "the scope check is a step later steps can read"
assert_in "$W" "if: steps.scope.outputs.verdict == 'generate'" "generation is guarded by the scope check"
assert_in "$W" "steps.scope.outputs.verdict == 'skip'" "a skipped run says why, rather than just not happening"
# The size thresholds are real, and they are NOT here. Two reasons, and both
# would be undone by the same edit. The payload's counts are over the whole diff,
# and what decides this is application paths only — a three-line model change
# beside a five-thousand-line lockfile is a three-line change. And a number in
# the rendered workflow is a number a team can only change by regenerating the
# file, which is what .accountable-review.yml exists to avoid.
assert_not_in "$W_CODE" "changed_files"                     "the job condition counts no files — the payload counts the whole diff"
assert_not_in "$W_CODE" "pull_request.additions"            "and no lines, for the same reason"
assert_not_in "$W_CODE" "trivial-files"                     "no threshold is baked into the rendered workflow"
assert_not_in "$W_CODE" "trivial-lines"                     "nor the line one — both are read from the config at run time"
assert_in "$W" "ci/generate-review-map.sh"             "there is a Review Map generation step"
assert_in "$W" "ci/delivery/deliver.sh"                "delivery is resolved through the provider seam"
assert_in "$W" "uses: actions/upload-artifact@v4"      "the map is uploaded as an artifact"
assert_in "$W" "retention-days: \${{ steps.delivery.outputs.retention_days }}" "retention comes from the delivery result"
assert_in "$W" "if-no-files-found: error"              "an empty upload fails rather than passing quietly"
assert_in "$W" "accountable-review--v"                 "the plugin is pinned to a release tag"

assert_not_in "$W_CODE" "bundle exec"                       "it never runs the application under review"
assert_not_in "$W_CODE" "services:"                         "it starts no database or service"
assert_not_in "$W_CODE" "db:migrate"                        "it runs no migrations"

# The generated file has to be stable, or "already set up" is undecidable.
"$RENDER" > "$TMP/workflow2.yml"
if cmp -s "$W" "$TMP/workflow2.yml"; then ok "rendering twice produces identical bytes"; else bad "rendering twice produces identical bytes"; fi
# Against the whole file, comments included: a date in a comment still makes the
# workflow different tomorrow, which is exactly what idempotency cannot survive.
assert_not_in "$W" "$(date -u +%Y-%m-%d)"              "the rendered file carries no timestamp"

# A real parse, which is the only thing that sees what the folded scalar actually
# folded to. Ruby first: this repository already pins one for evals/checks, and a
# rule that can only ever SKIP is worse than no rule — a SKIP reads as verified.
#
# It still cannot validate GitHub's expression grammar, which no offline tool has.
# That is what the two structural assertions above stand in for, and why both of
# them exist as well as this.
yaml_check='
require "yaml"
d = YAML.safe_load(File.read(ARGV[0]), aliases: true)
job = d.fetch("jobs").fetch("review-map")
abort "no if:"            unless job["if"].is_a?(String)
abort "newline in if:"    if job["if"].include?("\n")
abort "no types"          unless d[true]["pull_request"]["types"].is_a?(Array)
'
if command -v ruby >/dev/null 2>&1; then
  if ruby -e "$yaml_check" "$W" 2>"$TMP/yamlerr"; then
    ok "it parses as YAML, defines the review-map job, and its guard folds to one line"
  else
    bad "it parses as YAML, defines the review-map job, and its guard folds to one line ($(cat "$TMP/yamlerr"))"
  fi
elif command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
  if python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); j=d["jobs"]["review-map"]; sys.exit(0 if "\n" not in j["if"] else 1)' "$W"; then
    ok "it parses as YAML, defines the review-map job, and its guard folds to one line"
  else
    bad "it parses as YAML, defines the review-map job, and its guard folds to one line"
  fi
else
  bad "no YAML parser available — install ruby or pyyaml; this check must not silently pass"
fi

echo
echo "== the decisions about when it runs =="

# Each of these is a default someone confirms during setup, so each has to be
# both what ships and actually changeable. A knob that renders the same bytes
# either way is a confirmation that means nothing.
"$RENDER" --regenerate-on-push > "$TMP/w-push.yml"
assert_in "$TMP/w-push.yml" "      - synchronize"      "--regenerate-on-push adds the push trigger"
assert_in "$TMP/w-push.yml" "Review Map, regenerated"  "and the file explains that it regenerates"
assert_not_in "$TMP/w-push.yml" "is NOT regenerated"   "without the one-map-per-PR trade beside it"
assert_in "$W" "is NOT regenerated"                    "the default file explains that it does not regenerate"

# The 0.28.0 size flags are taken and ignored: a workflow generated then carries
# them in its `# Decisions:` line, and install-workflow.sh feeds that line back on
# the next upgrade. An unknown-argument exit there would turn "move the version
# pin" into a hard failure on every repository that set a threshold.
"$RENDER" --no-size-gate > "$TMP/w-nosize.yml" 2>/dev/null
# Comment-stripped, like every other negative assertion here: the template
# explains in a comment why the payload's counts are the wrong measurement, and a
# test that could not tell an explanation from a clause would forbid it.
grep -v '^[[:space:]]*#' "$TMP/w-nosize.yml" > "$TMP/w-nosize.code.yml"
assert_not_in "$TMP/w-nosize.code.yml" "changed_files" "--no-size-gate is accepted and renders no clause"
"$RENDER" --min-files 7 --min-lines 300 > "$TMP/w-legacy.yml" 2>/dev/null
if cmp -s "$TMP/w-legacy.yml" "$W"; then
  ok "the old thresholds render the same bytes as no thresholds at all"
else
  bad "the old thresholds render the same bytes as no thresholds at all"
fi
assert_not_in "$TMP/w-nosize.yml" "a lockfile churn sails" "and drops the comment explaining it"
assert_in "$TMP/w-nosize.yml" "!= 'dependabot[bot]'"   "leaving the author clause as the last one"

"$RENDER" --no-skip-authors > "$TMP/w-bare.yml"
assert_not_in "$TMP/w-bare.yml" "user.login"           "--no-skip-authors drops the author clauses"
assert_in "$TMP/w-bare.yml" "full_name == github.repository" "leaving the fork guard as the last one"

"$RENDER" --skip-authors 'dependabot[bot],renovate[bot]' > "$TMP/w-two.yml"
assert_in "$TMP/w-two.yml" "!= 'renovate[bot]'"        "a second bot gets its own clause"
assert_eq "$(grep -c "user.login !=" "$TMP/w-two.yml")" "2" "one clause per author, not a merged one"

# Every combination has to end the expression on a clause rather than a dangling
# operator, which is the way an optional clause breaks the two beside it.
combos_ok=1
if command -v ruby >/dev/null 2>&1; then
  for f in "$W" "$TMP/w-push.yml" "$TMP/w-nosize.yml" "$TMP/w-bare.yml" "$TMP/w-two.yml"; do
    ruby -e "$yaml_check" "$f" >/dev/null 2>&1 || combos_ok=0
  done
  if [ "$combos_ok" = 1 ]; then
    ok "every combination of the when-decisions parses and folds to one line"
  else
    bad "every combination of the when-decisions parses and folds to one line"
  fi
else
  bad "no ruby to parse the combinations with — this check must not silently pass"
fi

rc=0; printf 'review_map:\n  trivial_files: 3.5\n' > "$TMP/frac.yml"
"$READ_CONFIG" "$TMP/frac.yml" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1"                                    "a threshold that is not a whole number is refused"
rc=0; "$RENDER" --skip-authors "bad'login" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1"                                    "an author login carrying a quote is refused"

# The recorded line is what makes the knobs safe to re-run, so it has to say
# everything rather than only what differs from the defaults.
assert_in "$W" "# Decisions: --no-regenerate-on-push --skip-authors dependabot[bot] --pr-comment" \
  "the file records every decision in the form setup takes them"
# How big a change has to be is not one of them: it is not a when-decision, it is
# a number a team changes in .accountable-review.yml without regenerating this.
assert_not_in "$W" "--min-files"                       "the recorded decisions carry no size threshold"

echo
echo "== the comment on the pull request =="

# The one thing this job does to the repository, and the only reason it asks for
# a write scope. Off, BOTH have to go: a repository must not carry
# `pull-requests: write` for a step that is not there.
assert_in "$W" "  pull-requests: write"                "commenting brings the write scope it needs"
assert_in "$W" "Link the Review Map on the pull request" "and the step that uses it"
assert_in "$W" "GH_TOKEN: \${{ secrets.GITHUB_TOKEN }}" "the token is named by the comment step"
# Against the comment-stripped copy: the permissions block explains in prose why
# GITHUB_TOKEN reaches only this step, and a test that could not tell the
# explanation from a second use would forbid the file from explaining itself.
assert_eq "$(grep -c 'GH_TOKEN\|GITHUB_TOKEN' "$W_CODE")" "1" \
  "and by no other step, so the model step never sees a write-capable credential"

"$RENDER" --no-pr-comment > "$TMP/w-nocomment.yml"
assert_not_in "$TMP/w-nocomment.yml" "pull-requests: write" "--no-pr-comment drops the write scope"
assert_not_in "$TMP/w-nocomment.yml" "GITHUB_TOKEN"     "and the token with it"
assert_not_in "$TMP/w-nocomment.yml" "issues/comments"  "and the step that would have posted"
assert_in "$TMP/w-nocomment.yml" "never comments"       "and says the job is read-only, because now it is"
assert_in "$TMP/w-nocomment.yml" "  contents: read"     "leaving the read scope it still needs"

# Nothing anywhere in the job may set a check or a status. A link is not a
# verdict, and the distance between them is one step someone adds later.
assert_not_in "$W_CODE" "check-run"                    "it sets no check run"
assert_not_in "$W_CODE" "statuses: write"              "it asks for no status scope"
assert_not_in "$W_CODE" "createCommitStatus"           "it sets no commit status"

# The step is the only shell in this repository that writes to someone's
# repository, so it is run rather than read: both paths, against a stub.
if command -v ruby >/dev/null 2>&1; then
  ruby -ryaml -e '
    d = YAML.safe_load(File.read(ARGV[0]), aliases: true)
    s = d["jobs"]["review-map"]["steps"].find { |x| x["name"].to_s.include?("Link the") }
    abort "no comment step" unless s
    print s["run"]
  ' "$W" > "$TMP/comment-step.sh"

  mkdir -p "$TMP/stub"
  cat > "$TMP/stub/gh" <<'STUB'
#!/bin/sh
# Records the call, and answers the listing from $GH_EXISTING.
printf '%s\n' "$*" >> "$GH_CALLS"
case $* in
  *"issues/$PR_NUMBER/comments"*--jq*) printf '%s' "$GH_EXISTING" ;;
  *) : ;;
esac
STUB
  chmod +x "$TMP/stub/gh"

  run_step() {
    GH_CALLS=$1 GH_EXISTING=$2 \
    ARTIFACT_URL=https://github.test/artifact/1 BROWSABLE=false STABLE_URL= \
    HEAD_SHA=a93bd21deadbeefcafe PR_NUMBER=412 REPOSITORY=acme/app \
    PATH="$TMP/stub:$PATH" sh "$TMP/comment-step.sh"
  }

  : > "$TMP/calls-new"
  if run_step "$TMP/calls-new" "" 2>"$TMP/step-err"; then
    ok "the comment step runs clean when there is no comment yet"
  else
    bad "the comment step runs clean when there is no comment yet ($(cat "$TMP/step-err"))"
  fi
  assert_in "$TMP/calls-new" "-X POST"                 "with no existing comment it posts one"
  assert_not_in "$TMP/calls-new" "-X PATCH"            "and patches nothing"
  assert_in "$TMP/calls-new" "accountable-review -->"  "the body carries the marker it will search for"
  assert_in "$TMP/calls-new" "a93bd21"                 "and the short head SHA, which is how staleness is seen"
  assert_in "$TMP/calls-new" "Download the Review Map" "an artifact is offered as a download, not as a page"
  assert_in "$TMP/calls-new" "no verdict, no score and no approval" \
    "and says on the pull request itself that it is not a review"

  : > "$TMP/calls-upsert"
  if run_step "$TMP/calls-upsert" "998877
998899" 2>"$TMP/step-err2"; then
    ok "the comment step runs clean when one is already there"
  else
    bad "the comment step runs clean when one is already there ($(cat "$TMP/step-err2"))"
  fi
  assert_in "$TMP/calls-upsert" "issues/comments/998877" "an existing comment is patched, not duplicated"
  assert_not_in "$TMP/calls-upsert" "-X POST"          "and no second comment is posted"
  assert_not_in "$TMP/calls-upsert" "issues/comments/998899" "only the first match is touched"

  # A browsable provider gets its own URL, through the delivery seam rather than
  # around it — the comment must not be a second thing that knows about artifacts.
  : > "$TMP/calls-browsable"
  GH_CALLS=$TMP/calls-browsable GH_EXISTING= \
  ARTIFACT_URL= BROWSABLE=true STABLE_URL=https://maps.test/pr/412 \
  HEAD_SHA=a93bd21deadbeefcafe PR_NUMBER=412 REPOSITORY=acme/app \
  PATH="$TMP/stub:$PATH" sh "$TMP/comment-step.sh" 2>/dev/null || true
  assert_in "$TMP/calls-browsable" "https://maps.test/pr/412" "a browsable provider's URL is what gets linked"
  assert_in "$TMP/calls-browsable" "Open the Review Map"      "and it is offered as a page rather than a download"
else
  bad "no ruby to extract the comment step with — this check must not silently pass"
fi

echo
echo "== existing CI is preserved =="

R=$TMP/repo-preserve
fixture_repo "$R"
before=$(cd "$R" && git rev-parse HEAD)
sum_before=$(cat "$R/.github/workflows/tests.yml" "$R/.github/workflows/lint.yml" | cksum)

"$INSTALL" --repo-dir "$R" > "$TMP/install1" 2>&1 || true
assert_in "$TMP/install1" "status=created"             "a first run creates the workflow"

sum_after=$(cat "$R/.github/workflows/tests.yml" "$R/.github/workflows/lint.yml" | cksum)
assert_eq "$sum_after" "$sum_before"                   "the repository's own workflows are byte-identical afterwards"
assert_eq "$(cd "$R" && git rev-parse HEAD)" "$before" "nothing was committed"
assert_eq "$(ls "$R/.github/workflows" | wc -l | tr -d ' ')" "3" "exactly one workflow was added"
if [ -f "$R/.github/workflows/accountable-review.yml" ]; then
  ok "it landed at .github/workflows/accountable-review.yml"
else
  bad "it landed at .github/workflows/accountable-review.yml"
fi
if [ -f "$R/.accountable-review.yml" ]; then
  bad "no config file is written when nothing differs from the defaults"
else
  ok "no config file is written when nothing differs from the defaults"
fi

echo
echo "== running it twice =="

"$INSTALL" --repo-dir "$R" > "$TMP/install2" 2>&1 || true
assert_in "$TMP/install2" "status=unchanged"           "a second run reports unchanged"
assert_eq "$(ls "$R/.github/workflows" | wc -l | tr -d ' ')" "3" "a second run adds no second workflow"
if cmp -s "$R/.github/workflows/accountable-review.yml" "$W"; then
  ok "the file is still exactly what setup renders"
else
  bad "the file is still exactly what setup renders"
fi
assert_eq "$(grep -c '^name: Accountable Review' "$R/.github/workflows/accountable-review.yml")" "1" \
  "no duplicated job or workflow body"

printf '\n# a team edit\n' >> "$R/.github/workflows/accountable-review.yml"
edited=$(cksum < "$R/.github/workflows/accountable-review.yml")
rc=0; "$INSTALL" --repo-dir "$R" > "$TMP/install3" 2>&1 || rc=$?
assert_in "$TMP/install3" "status=drift"               "a hand-edited workflow is reported as drift"
assert_eq "$rc" "3"                                    "drift exits 3 so a caller can tell"
assert_eq "$(cksum < "$R/.github/workflows/accountable-review.yml")" "$edited" \
  "drift changes nothing on disk"
"$INSTALL" --repo-dir "$R" --update > "$TMP/install4" 2>&1 || true
assert_in "$TMP/install4" "status=updated"             "--update rewrites it, when asked"

echo
echo "== a re-run does not revert what someone confirmed =="

# The knobs are only safe because of this. Upgrading the pin is the ordinary
# reason to run setup twice, and without recovery it would report every confirmed
# decision as drift and then revert them all under --update.
K=$TMP/repo-knobs
mkdir -p "$K"
"$INSTALL" --repo-dir "$K" -- --plugin-ref v1 --regenerate-on-push --skip-authors 'renovate[bot]' \
  > "$TMP/k1" 2>&1 || true
assert_in "$TMP/k1" "status=created"                   "a first run installs the confirmed decisions"
assert_in "$TMP/k1" "decisions=--regenerate-on-push --skip-authors renovate[bot] --pr-comment" \
  "and reports back what it wrote rather than what it was asked"

"$INSTALL" --repo-dir "$K" -- --plugin-ref v1 > "$TMP/k2" 2>&1 || true
assert_in "$TMP/k2" "status=unchanged"                 "a re-run passing no decisions recovers them and finds nothing to do"

"$INSTALL" --repo-dir "$K" --print-diff -- --plugin-ref v2 > "$TMP/k3" 2>&1 || true
assert_in "$TMP/k3" "status=drift"                     "upgrading the pin is drift, as any change is"
assert_not_in "$TMP/k3" "-      - synchronize"         "but the diff does not propose reverting the push trigger"
assert_not_in "$TMP/k3" "-      && github.event.pull_request.user.login != 'renovate[bot]'" \
  "nor the author list someone chose"

"$INSTALL" --repo-dir "$K" --update -- --plugin-ref v2 > "$TMP/k4" 2>&1 || true
assert_in "$K/.github/workflows/accountable-review.yml" "      - synchronize" \
  "an upgrade keeps the push trigger"
assert_in "$K/.github/workflows/accountable-review.yml" "user.login != 'renovate[bot]'" \
  "an upgrade keeps the author list"
assert_in "$K/.github/workflows/accountable-review.yml" "PLUGIN_REF: v2" \
  "and does move the pin, which is what it was run for"

# An explicit flag still wins over a recovered one, or the decisions could never
# be changed again.
"$INSTALL" --repo-dir "$K" --update -- --plugin-ref v2 --no-regenerate-on-push > "$TMP/k5" 2>&1 || true
assert_not_in "$K/.github/workflows/accountable-review.yml" "      - synchronize" \
  "an explicit decision overrides the recovered one"
assert_in "$K/.github/workflows/accountable-review.yml" "user.login != 'renovate[bot]'" \
  "and leaves the decisions it said nothing about alone"

# The comment decision is the one where a silent revert is worst in both
# directions: re-adding a step a team removed, or dropping a scope they agreed to.
C2=$TMP/repo-nocomment
mkdir -p "$C2"
"$INSTALL" --repo-dir "$C2" -- --plugin-ref v1 --no-pr-comment > /dev/null 2>&1 || true
"$INSTALL" --repo-dir "$C2" --update -- --plugin-ref v2 > /dev/null 2>&1 || true
assert_not_in "$C2/.github/workflows/accountable-review.yml" "pull-requests: write" \
  "an upgrade does not re-grant a write scope the team declined"
assert_not_in "$C2/.github/workflows/accountable-review.yml" "GITHUB_TOKEN" \
  "nor hand back the token that goes with it"

# A file with nothing recorded is compared against the defaults, which is the
# honest answer rather than a guess at what someone meant.
sed '/^# Decisions: /d' "$K/.github/workflows/accountable-review.yml" > "$TMP/stripped"
cp "$TMP/stripped" "$K/.github/workflows/accountable-review.yml"
"$INSTALL" --repo-dir "$K" -- --plugin-ref v2 > "$TMP/k6" 2>&1 || true
assert_in "$TMP/k6" "status=drift"                     "a workflow recording no decisions is drift against the defaults"

echo
echo "== configuration =="

C=$TMP/config
mkdir -p "$C"
cat > "$C/.accountable-review.yml" <<'Y'
review_map:
  delivery:
    provider: github-artifact
    retention_days: 14
Y
"$READ_CONFIG" "$C/.accountable-review.yml" > "$TMP/cfg"
assert_in "$TMP/cfg" "CFG_retention_days='14'"         "retention_days is read"
assert_not_in "$TMP/cfg" "CFG_effort"                  "a key the file omits produces no line"

mkdir -p "$TMP/out-cfg" && echo '<html>x</html>' > "$TMP/out-cfg/index.html"
( cd "$C" && "$DELIVER" --dir "$TMP/out-cfg" --repository acme/app --pr 412 --head-sha a93bd21deadbeef ) > "$TMP/deliver-cfg"
assert_in "$TMP/deliver-cfg" '"retention_days": "14"'  "the workflow honours retention_days from the config file"

# THE PAGE HAS ONE SHAPE, and nothing names one any more — not a flag on this script and not a
# key in the config file. A page-shape argument is an unknown argument, which is the state this
# asserts: an adapter that quietly swallowed one would be the first half of a second product.
rc=0; "$GENERATE" --print-invocation --output "$TMP/out-cfg" --pr 412 \
  --head-sha a93bd21deadbeef --repo-dir "$TMP" --mode brief >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "2"                                    "a page-shape flag is an unknown argument, not a no-op"

"$GENERATE" --print-invocation --output "$TMP/out-cfg" --pr 412 --head-sha a93bd21deadbeef \
  --repo-dir "$TMP" > "$TMP/inv-def"
assert_in "$TMP/inv-def" "--effort high"               "the default effort is high, as the skill's is"

# --mentor is OFF unless asked for, and off is the ABSENCE of the flag rather than a value: the
# skill parses no `--mentor off`, and a flag whose off state is spelled out is one more thing for
# it to get wrong. It is also the one setting that changes what is on the page, which is why its
# default is the one that matters most here.
assert_not_in "$TMP/inv-def" "--mentor"                "no mentor flag is passed by default"
"$GENERATE" --print-invocation --output "$TMP/out-cfg" --pr 412 --head-sha a93bd21deadbeef \
  --repo-dir "$TMP" --mentor > "$TMP/inv-mentor"
assert_in "$TMP/inv-mentor" "--mentor"                 "a bare --mentor reaches the run"
"$GENERATE" --print-invocation --output "$TMP/out-cfg" --pr 412 --head-sha a93bd21deadbeef \
  --repo-dir "$TMP" --mentor rails > "$TMP/inv-mentor-stack"
assert_in "$TMP/inv-mentor-stack" "--mentor rails"     "and a stack name travels with it"
# The optional value must not swallow the flag after it. A peek that consumed any next argument
# would turn `--mentor --effort low` into a mentor run at the default effort, silently.
"$GENERATE" --print-invocation --output "$TMP/out-cfg" --pr 412 --head-sha a93bd21deadbeef \
  --repo-dir "$TMP" --mentor --effort low > "$TMP/inv-mentor-then"
assert_in "$TMP/inv-mentor-then" "--effort low"        "a bare --mentor does not swallow the flag after it"

# And it is configurable, at run time, like everything else a team legitimately sets.
printf 'review_map:\n  mentor: rails\n' > "$C/mentor.yml"
( cd "$C" && "$GENERATE" --print-invocation --output "$TMP/out-cfg" --pr 412 \
    --head-sha a93bd21deadbeef --repo-dir "$C" --config "$C/mentor.yml" ) > "$TMP/inv-mentor-cfg"
assert_in "$TMP/inv-mentor-cfg" "--mentor rails"       "mentor is read from the config file"
rc=0; printf 'review_map:\n  mentor: nope\n' > "$C/mentor-bad.yml"
"$READ_CONFIG" "$C/mentor-bad.yml" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1"                                    "a mentor value that is not a stack is an error"

rc=0; printf 'review_map:\n  retention_day: 14\n' > "$C/bad.yml"
"$READ_CONFIG" "$C/bad.yml" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1"                                    "a misspelled key is an error, not a shrug"
# There is no page-shape key either. `mode` is not read, not validated and not tolerated — it
# falls through to the unknown-key rule, which is what stops it coming back as a silent no-op.
rc=0; printf 'review_map:\n  mode: brief\n' > "$C/mode.yml"
"$READ_CONFIG" "$C/mode.yml" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1"                                    "a page-shape key is an unknown key, not a shrug"

echo
echo "== delivery =="

D=$TMP/deliver-dir
mkdir -p "$D" && echo '<html>x</html>' > "$D/index.html"
"$DELIVER" --dir "$D" --repository acme/app --pr 412 --base-sha 7bd312f0 --head-sha a93bd21deadbeef > "$TMP/dr"
assert_in "$TMP/dr" '"provider": "github-artifact"'    "the default provider is github-artifact"
assert_in "$TMP/dr" '"location": "accountable-review-pr-412-a93bd21"' "the artifact is named for the PR and the revision"
assert_in "$TMP/dr" '"browsable": false'               "an artifact is not browsable in place, and says so"
assert_in "$TMP/dr" '"stable_url": null'               "an artifact has no stable URL"
assert_in "$TMP/dr" '"retention_days": "30"'           "the default retention is 30 days"

rc=0; "$DELIVER" --dir "$D" --provider s3 --repository acme/app --pr 1 --head-sha abc1234 >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "2"                                    "an unimplemented provider fails with a usable message"

rc=0; "$DELIVER" --dir "$D" --provider command --command 'echo https://x.example/1' \
  --repository acme/app --pr 1 --head-sha abc1234 >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1"                                    "the command provider refuses without an explicit opt-in"

ACCOUNTABLE_REVIEW_ALLOW_COMMAND=1 "$DELIVER" --dir "$D" --provider command \
  --command 'echo published to https://x.example/pr/412' \
  --repository acme/app --pr 412 --head-sha abc1234 > "$TMP/dr-cmd" 2>/dev/null
assert_in "$TMP/dr-cmd" '"provider": "command"'        "the command provider runs when opted in"
assert_in "$TMP/dr-cmd" '"browsable": true'            "a provider that returns a URL is browsable"
assert_in "$TMP/dr-cmd" '"stable_url": "https://x.example/pr/412"' "the URL it printed becomes the stable URL"

rc=0; "$DELIVER" --dir "$TMP/empty-dir" --repository acme/app --pr 1 --head-sha abc1234 >/dev/null 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then ok "delivering a directory with no page fails"; else bad "delivering a directory with no page fails"; fi

echo
echo "== the generation adapter =="

G=$TMP/gen-repo
mkdir -p "$G"
( cd "$G" && git init -q . && git config user.email t@example.com && git config user.name t \
    && echo one > a.txt && git add -A && git commit -qm one )
BASE=$(cd "$G" && git rev-parse HEAD)
( cd "$G" && echo two > b.txt && git add -A && git commit -qm two )
HEAD_SHA=$(cd "$G" && git rev-parse HEAD)
SHORT=$(printf '%.7s' "$HEAD_SHA")

rc=0; "$GENERATE" --print-invocation --output "$G/review-map" --repo-dir "$G" \
  --head-sha "$HEAD_SHA" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1"                                    "an output directory inside the repository is refused"

rc=0; "$GENERATE" --output "$TMP/nocred" --repo-dir "$G" --base-sha "$BASE" --head-sha "$HEAD_SHA" \
  >"$TMP/nocred.log" 2>&1 || rc=$?
if [ "$rc" -ne 0 ] && grep -q 'credential' "$TMP/nocred.log"; then
  ok "a missing model credential is reported as a missing credential"
else
  bad "a missing model credential is reported as a missing credential"
fi

page() {
  cat > "$1" <<HTML
<!doctype html><html><body>
<header><div class="path">feature/x → main</div><div class="path">$SHORT → $(printf '%.7s' "$BASE")</div></header>
$2
<div class="gt gt-paths"><div class="c" data-path="b.txt">b.txt</div></div>
</body></html>
HTML
}

O=$TMP/out-good
mkdir -p "$O"; page "$O/index.html" "<p>A page about the change.</p>$(printf '%*s' 2100 '' | tr ' ' '.')"
"$GENERATE" --verify-only --output "$O" --repo-dir "$G" --repository acme/app --pr 412 \
  --base-sha "$BASE" --head-sha "$HEAD_SHA" > "$TMP/verify.log" 2>&1 \
  && ok "a finished page passes verification" || { bad "a finished page passes verification"; cat "$TMP/verify.log"; }
assert_in "$O/manifest.json" "\"head_sha\": \"$HEAD_SHA\"" "the manifest records the head revision"
assert_in "$O/manifest.json" "\"base_sha\": \"$BASE\""     "the manifest records the base revision"
assert_in "$O/manifest.json" '"pull_request": 412'         "the manifest records the pull request"
assert_in "$O/manifest.json" '"coverage_gate": "pass"'     "the coverage gate runs and its result is recorded"
assert_not_in "$O/manifest.json" 'severity'                "the manifest carries no verdict vocabulary"

O2=$TMP/out-pending
mkdir -p "$O2"; page "$O2/index.html" "<div class=\"buildstate\">Still being written</div>$(printf '%*s' 2100 '' | tr ' ' '.')"
rc=0; "$GENERATE" --verify-only --output "$O2" --repo-dir "$G" --base-sha "$BASE" --head-sha "$HEAD_SHA" \
  > "$TMP/pending.log" 2>&1 || rc=$?
if [ "$rc" -ne 0 ] && grep -q 'pending marker\|build banner' "$TMP/pending.log"; then
  ok "a page still promising pending sections is refused"
else
  bad "a page still promising pending sections is refused"
fi

O3=$TMP/out-norev
mkdir -p "$O3"
printf '<!doctype html><html><body><p>no revision here</p>%s</body></html>\n' "$(printf '%*s' 2100 '' | tr ' ' '.')" > "$O3/index.html"
rc=0; "$GENERATE" --verify-only --output "$O3" --repo-dir "$G" --base-sha "$BASE" --head-sha "$HEAD_SHA" \
  > "$TMP/norev.log" 2>&1 || rc=$?
if [ "$rc" -ne 0 ] && grep -q 'revision' "$TMP/norev.log"; then
  ok "a page that never names its revision is refused"
else
  bad "a page that never names its revision is refused"
fi

echo
echo "== the application-code gate =="

# Two rules, asked in order: is any of this application code, and is what it
# changes more than trivial. Both halves are measured over application paths
# ONLY, which is the thing the whole-diff counts of the pull_request payload
# cannot do.

A=$PLUGIN_ROOT/ci/application-code.sh
P=$TMP/gate-repo
mkdir -p "$P"
( cd "$P" && git init -q . && git config user.email t@example.com && git config user.name t )
mkdir -p "$P/app/models" "$P/app/services" "$P/spec/models" "$P/docs" "$P/.github/workflows" "$P/config"
( cd "$P" && echo base > app/models/order.rb && echo base > app/models/line.rb \
    && echo base > app/models/cart.rb && echo base > app/services/pricer.rb \
    && echo base > spec/models/order_spec.rb \
    && echo base > README.md && echo base > yarn.lock && echo base > config/routes.rb \
    && git add -A && git commit -qm base )
GATE_BASE=$(cd "$P" && git rev-parse HEAD)

# gate <branch> <expected verdict> <what> <edits> [extra flags]
gate() {
  branch=$1; want=$2; what=$3
  ( cd "$P" && git checkout -q -B "$branch" "$GATE_BASE" )
  sh -c "cd '$P' && $4"
  ( cd "$P" && git add -A && git commit -qm "$branch" )
  rc=0
  # shellcheck disable=SC2086
  ( cd "$P" && "$A" --base "$GATE_BASE" --head HEAD ${5:-} ) > "$TMP/gate-$branch" 2>&1 || rc=$?
  case $rc in
    0) got=generate ;;
    3) got=skip ;;
    *) got="error($rc)" ;;
  esac
  assert_eq "$got" "$want" "$what"
}

# --- rule 1: is any of it application code at all? --------------------------

gate docs     skip     "a documentation-only pull request gets no Review Map" \
  'echo x >> README.md && echo x > docs/guide.md'
gate lock     skip     "a lockfile bump gets none" \
  'echo x >> yarn.lock'
gate specs    skip     "a tests-only pull request gets none" \
  'echo x >> spec/models/order_spec.rb'
gate tooling  skip     "a CI or linter config change gets none" \
  'echo x > .github/workflows/tests.yml && echo x > .rubocop.yml'
assert_in "$TMP/gate-docs" "verdict: skip (no-application-code)" "rule 1 names itself in the log, not only in a step output"

# Fail open: a path this script has never heard of is application code. The
# exclusion list is narrow on purpose, and this is the assertion that keeps it so.
# Deliberately 40 lines: rule 2 would skip a small change whatever rule 1 said,
# so a 3-line fixture here would pass while proving nothing about fail-open.
gate unknown  generate "an unrecognised path counts as application code" \
  'mkdir -p odd && seq 1 40 > odd/thing.xyz'

# config/ is where a Rails app keeps its routes. A blanket exclusion by directory
# name would take it, and take the routing change with it.
gate routes   generate "config/routes.rb is application code, not configuration" \
  'seq 1 40 > config/routes.rb'

# --- rule 2: is what it changes more than trivial? --------------------------

gate tiny     skip     "a one-line application change is trivial, and gets none" \
  'echo x >> app/models/order.rb'
assert_in "$TMP/gate-tiny" "verdict: skip (trivial)" "rule 2 names itself too"
assert_in "$TMP/gate-tiny" "trivial threshold" "and prints the numbers it judged against"

gate bulky    generate "a 900-line change in ONE file earns one" \
  'seq 1 900 > app/models/order.rb'
gate spread   generate "a 4-line change across FOUR files earns one" \
  'echo x >> app/models/order.rb && echo x >> app/models/line.rb
   echo x >> app/models/cart.rb && echo x >> app/services/pricer.rb'

# THE TWO ABOVE ARE THE WHOLE POINT OF THE AND, and each is the case the other
# polarity gets wrong. A skip predicate joined by OR would discard both: one is
# under the file threshold, the other under the line threshold. Only requiring
# BOTH to be small leaves a large change on the generating side whichever way it
# is large.

gate mixed    generate "one substantial application file among documentation earns one" \
  'echo x >> README.md && seq 1 40 > app/models/order.rb'

# The counts are over application paths only. This is the case that separates
# them from the payload's whole-diff numbers: by those, this pull request is five
# thousand lines and obviously worth a map.
gate masked   skip     "a one-line model change beside a 5000-line lockfile is still trivial" \
  'echo x >> app/models/order.rb && seq 1 5000 > yarn.lock'
assert_in "$TMP/gate-masked" "1 application line" "the lockfile's lines are not counted"

# --- the thresholds are configurable, and 0 turns them off ------------------

gate offcfg   generate "trivial_lines: 0 in the config file generates a map for any application change" \
  'echo x >> app/models/order.rb
   printf "review_map:\n  trivial_lines: 0\n" > .accountable-review.yml'
gate upcfg    skip     "a raised threshold makes a larger change trivial" \
  'seq 1 40 > app/models/order.rb
   printf "review_map:\n  trivial_files: 5\n  trivial_lines: 100\n" > .accountable-review.yml'
gate flagwins generate "an explicit flag beats the config file" \
  'seq 1 40 > app/models/order.rb
   printf "review_map:\n  trivial_files: 5\n  trivial_lines: 100\n" > .accountable-review.yml' \
  '--trivial-lines 10'

rc=0; "$READ_CONFIG" /dev/null >/dev/null 2>&1 || true
printf 'review_map:\n  trivial_lines: lots\n' > "$TMP/trivial-bad.yml"
rc=0; "$READ_CONFIG" "$TMP/trivial-bad.yml" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1"                                    "a threshold that is not a number is an error"

assert_in "$TMP/gate-docs" "skip	docs	README.md"  "the gate names each discounted path and why"
assert_in "$TMP/gate-mixed" "code	-	app/models/order.rb" "and names the application paths it found"

# ASKED AND UNABLE TO ANSWER IS NOT AN EMPTY DIFF. Every failure mode of this
# script ends in zero application paths, which is the skip verdict — so a base
# that is not in the checkout has to be fatal rather than reassuring.
rc=0
( cd "$P" && "$A" --base 4b825dc642cb6eb9a060e54bf8d69288fbee4904111 --head HEAD ) >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "4"                                    "a base that cannot be resolved is an error, not a skip"

echo
echo "== inspection =="

"$INSPECT" --repo-dir "$R" > "$TMP/inspect"
assert_in "$TMP/inspect" "git_repo=yes"                "inspection recognises a git repository"
assert_in "$TMP/inspect" "workflows_dir=present"       "inspection finds the workflows directory"
assert_in "$TMP/inspect" "accountable_workflow=.github/workflows/accountable-review.yml" \
  "inspection finds an Accountable Review workflow that is already there"
"$INSPECT" --repo-dir "$TMP/config" > "$TMP/inspect2" 2>/dev/null || true
assert_in "$TMP/inspect2" "git_repo=no"                "inspection says so when there is no repository"

echo
echo "== the previous map, and updating over it =="

# Nothing persisted between runs before this, so a second run on a pull request
# rebuilt the page it already had. The cache is the carrier, and it rides the
# `synchronize` decision because a pull request that gets ONE map has no second
# run to restore anything into.
assert_in "$TMP/w-push.yml" "actions/cache/restore@v4" "--regenerate-on-push restores the previous map"
assert_in "$TMP/w-push.yml" "actions/cache/save@v4"    "and keeps this one for the next push"
assert_not_in "$W" "actions/cache"                     "the default file caches nothing — there is no second run to feed"

# The two keys must be the SAME string. A save under a key the restore never
# looks for is a cache that fills up and is never read: every run then rebuilds
# from scratch, silently, and the only symptom is a bill.
restore_key=$(grep -A3 'actions/cache/restore@v4' "$TMP/w-push.yml" | sed -n 's/^ *key: //p' | head -n 1)
save_key=$(grep -A3 'actions/cache/save@v4' "$TMP/w-push.yml" | sed -n 's/^ *key: //p' | head -n 1)
assert_eq "$restore_key" "$save_key" "the restore and the save name the same key"
case $restore_key in
  *'pull_request.head.sha'*) ok "the key is per head sha, so each push saves its own entry" ;;
  *) bad "the key is per head sha, so each push saves its own entry (got '$restore_key')" ;;
esac
assert_in "$TMP/w-push.yml" "restore-keys: accountable-review-map-" \
  "and a prefix restore-key, so the previous push's entry is what a new sha falls back to"

# Only a page that shipped is worth keeping. Correctness does not depend on it —
# a half-written page restored next run carries a pending marker and carry-plan.sh
# refuses it — but a cache entry nothing can use is still worth not writing.
assert_in "$TMP/w-push.yml" "if: success() && steps.scope.outputs.verdict == 'generate'" \
  "the save runs only when this run actually delivered"

# The fact that makes pull-requests: write acceptable, re-checked here because the
# cache steps are two more places an env: block could appear. Comment-stripped,
# like the assertion above that owns this rule: the permissions block explains in
# prose why the token reaches only one step, and counting that explanation as a
# use would forbid the file from explaining itself.
grep -v '^[[:space:]]*#' "$TMP/w-push.yml" > "$TMP/w-push.code.yml"
assert_eq "$(grep -c 'GH_TOKEN\|GITHUB_TOKEN' "$TMP/w-push.code.yml" || true)" "1" \
  "exactly one step in the file with the cache steps still names GITHUB_TOKEN"

# Idempotency is decided by comparing bytes, so the key may carry nothing that
# varies between two renders of the same request. Run-time ${{ }} expressions are
# fine; a date is not, and a date is what someone reaches for to expire a cache.
"$RENDER" --regenerate-on-push > "$TMP/w-push2.yml"
if cmp -s "$TMP/w-push.yml" "$TMP/w-push2.yml"; then
  ok "two renders with the cache steps are byte identical"
else
  bad "two renders with the cache steps are byte identical"
fi
assert_not_in "$TMP/w-push.yml" "$(date -u +%Y-%m-%d)" "and the cache key carries no date"

# review_map.update is RUN-TIME configuration: it is about the map, not about when
# a map is generated, so it renders nothing and needs no setup flag.
assert_not_in "$TMP/w-push.yml" "review_map.update" "the workflow holds no update setting of its own"

printf 'review_map:\n  update: false\n' > "$TMP/cfg-update-off.yml"
assert_eq "$("$READ_CONFIG" "$TMP/cfg-update-off.yml" --prefix CFG_ | sed -n "s/^CFG_update=//p")" "'false'" \
  "update: false is read"
printf 'review_map:\n  update: no\n' > "$TMP/cfg-update-no.yml"
assert_eq "$("$READ_CONFIG" "$TMP/cfg-update-no.yml" --prefix CFG_ | sed -n "s/^CFG_update=//p")" "'false'" \
  "and no is the same answer spelled the other way"
printf 'review_map:\n  effort: high\n' > "$TMP/cfg-no-update.yml"
assert_eq "$("$READ_CONFIG" "$TMP/cfg-no-update.yml" --prefix CFG_ | sed -n "s/^CFG_update=//p")" "" \
  "an absent key emits nothing, so the config rung stays distinguishable from the default"
printf 'review_map:\n  update: maybe\n' > "$TMP/cfg-bad-update.yml"
rc=0; "$READ_CONFIG" "$TMP/cfg-bad-update.yml" --prefix CFG_ >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1" "and a value that is neither is an error rather than a guess"

# The adapter asks for an update only when something already put a page where it
# is about to write. Asking against an empty directory would be a flag the skill
# has to talk its way out of.
UREPO=$TMP/urepo; URUN=$TMP/urun
mkdir -p "$UREPO" "$URUN"
(
  cd "$UREPO"
  git init -q .; git config user.email t@e; git config user.name t
  echo a > f.rb; git add -A; git commit -qm base
  echo b >> f.rb; git commit -qam second
) >/dev/null 2>&1
UBASE=$(git -C "$UREPO" rev-parse HEAD~1); UHEAD=$(git -C "$UREPO" rev-parse HEAD)
UHS=$(git -C "$UREPO" rev-parse --short=7 HEAD); UPS=$(git -C "$UREPO" rev-parse --short=7 HEAD~1)
invocation() { "$GENERATE" --output "$URUN" --head-sha "$UHEAD" --base-sha "$UBASE" \
  --repo-dir "$UREPO" --print-invocation "$@" 2>/dev/null | grep -c -- '--update' || true; }

assert_eq "$(invocation)" "0" "no previous page means no --update, whatever the config says"
printf 'x\n' > "$URUN/index.html"
assert_eq "$(invocation)" "1" "a previous page is what turns it on"
printf 'review_map:\n  update: false\n' > "$UREPO/.accountable-review.yml"
assert_eq "$(invocation)" "0" "update: false turns it off with the page still there"
assert_eq "$(invocation --update)" "1" "and an explicit flag beats the config file, like every other setting"
rm -f "$UREPO/.accountable-review.yml"

# WHICH REVISION THE CARRIED PARTS DESCRIBE IS READ OFF THE PAGE, NOT TRACKED.
# The masthead's `updated from <sha>` segment is written only by an update that
# carried something, so the manifest agrees with the page by construction — and a
# run that asked for an update and fell back to a full one, which is what every
# carry-plan.sh refusal does, records null without the adapter learning that it did.
upage() { { printf '<html><div class="path">%s &rarr; %s %s</div>' "$UHS" "$UPS" "$1"
            head -c 2500 /dev/zero | tr '\0' 'x'; printf '</html>\n'; } > "$URUN/index.html"; }
manifest_field() { sed -n 's/.*"updated_from"[[:space:]]*:[[:space:]]*\(.*\)$/\1/p' "$URUN/manifest.json" | tr -d ' ,'; }

upage ""
"$GENERATE" --output "$URUN" --head-sha "$UHEAD" --base-sha "$UBASE" --repo-dir "$UREPO" \
  --verify-only >/dev/null 2>&1 || true
assert_in "$URUN/manifest.json" "review-map-manifest@3" "the manifest says which schema carries updated_from"
assert_eq "$(manifest_field)" "null" "a page with no update segment records null"

upage "&middot; updated from $UPS"
"$GENERATE" --output "$URUN" --head-sha "$UHEAD" --base-sha "$UBASE" --repo-dir "$UREPO" \
  --verify-only >/dev/null 2>&1 || true
assert_eq "$(manifest_field)" "\"$UPS\"" "and a page that names one records exactly that revision"

echo
echo "== a push that reaches nothing the map says =="

# The gate above asks its question over BASE...HEAD, so a README-only push to a branch that changed
# application code earlier still answers `generate`. Asking it again over the commits since the map
# we already have is what makes that push cost nothing.

# The restore has to sit ABOVE the step that decides the verdict, because the second half of that
# decision is about the restored map — and it therefore carries no verdict guard, while every later
# step still does. An ordering assertion rather than a presence one: presence was already pinned.
restore_line=$(grep -n 'actions/cache/restore@v4' "$TMP/w-push.yml" | cut -d: -f1)
scope_line=$(grep -n 'id: scope' "$TMP/w-push.yml" | cut -d: -f1)
if [ "$restore_line" -lt "$scope_line" ]; then
  ok "the previous map is restored before the step that decides whether to generate"
else
  bad "the previous map is restored before the step that decides whether to generate"
fi
guard=$(sed -n "$((restore_line - 6)),${restore_line}p" "$TMP/w-push.yml" | grep -c "verdict == 'generate'" || true)
assert_eq "$guard" "0" "and the restore carries no verdict guard — it is what the verdict is decided from"
# -- ripgrep, installed only when there is a previous map to replay searches against ----------
# Both halves of reusing a map replay the page's own recorded searches, and the lens files write
# those with rg, which a GitHub runner does not have. Without this step every recorded search
# refuses and a re-run rebuilds the page — correct, and the whole saving gone.
rg_line=$(grep -n 'Install ripgrep' "$TMP/w-push.yml" | cut -d: -f1)
if [ -n "$rg_line" ] && [ "$restore_line" -lt "$rg_line" ] && [ "$rg_line" -lt "$scope_line" ]; then
  ok "ripgrep is installed after the restore and before the step that replays the searches"
else
  bad "ripgrep is installed after the restore and before the step that replays the searches"
fi
# ON DEMAND, and the guard is the whole point: a run with nothing restored has nothing to carry,
# so it pays for no install. `cache-matched-key` is empty on a cold cache, where `cache-hit` is
# also false on a restore-key hit — which is the case this step most needs to fire for.
rg_guard=$(sed -n "$((rg_line + 1))p" "$TMP/w-push.yml")
assert_eq "$(printf '%s\n' "$rg_guard" | grep -c "cache-matched-key != ''")" "1" \
  "and only when a previous map was actually restored"
# It is an optimisation, so it must never be the reason a Review Map does not get made. The last
# command in the block has to succeed even when the package cannot be had.
rg_block=$(awk "NR > $rg_line && /^      - /{exit} NR > $rg_line" "$TMP/w-push.yml")
assert_eq "$(printf '%s\n' "$rg_block" | grep -c '|| echo')" "1" \
  "and a failed install leaves the run to rebuild the page rather than failing the job"
assert_not_in "$W" "ripgrep" "the default file installs nothing — there is no previous map to replay"

assert_in "$TMP/w-push.yml" "map-still-current.sh" "the scope step asks the second question"
assert_in "$TMP/w-push.yml" "reason=map-still-current" "and downgrades its own verdict rather than adding a second one"
# WHICH verdict it writes, not merely that it writes a reason. A downgrade to anything but `skip`
# computes the cheap answer, prints it, and generates anyway — the shape of check that runs and
# changes nothing, which is the one this repository refuses to ship.
still_block=$(awk '/map-still-current.sh/,/SETUP:END:push/' "$TMP/w-push.yml")
assert_eq "$(printf '%s\n' "$still_block" | grep -c 'echo "verdict=skip"' || true)" "1" \
  "and the verdict it writes is skip — anything else computes the answer and ignores it"
assert_not_in "$W" "map-still-current.sh" "the default file asks it nowhere — there is no second run to ask about"

# No guard below the scope step moved, which is the whole reason this change is small: the steps
# that stand aside and the step that explains a skip are the ones that already existed.
assert_in "$TMP/w-push.yml" "if: steps.scope.outputs.verdict == 'skip'" \
  "the existing skip-reporting step is what explains it"
# One home for the DECISION: a verdict is read from the scope step and from nowhere else.
# Counting guards across the two renders would compare files that legitimately differ by the
# cache save step, and forbidding every `steps.<id>.outputs` reference would forbid the ripgrep
# step's cache-matched-key — which is the cache reporting what it restored, not a second opinion
# about whether to generate.
assert_eq "$(grep -o 'steps\.[a-z_-]*\.outputs\.verdict' "$TMP/w-push.yml" \
  | grep -cv '^steps\.scope\.outputs\.verdict$' || true)" "0" \
  "and no step reads a verdict from anywhere but the scope step — it is still the only one that decides"

# ---- ci/map-still-current.sh, against a real repository -------------------------------------
STILL=$PLUGIN_ROOT/ci/map-still-current.sh
SREPO=$TMP/srepo; SMAP=$TMP/smap
mkdir -p "$SREPO"/app/models "$SREPO"/spec/models "$SMAP"
(
  cd "$SREPO"
  git init -q .; git config user.email t@e; git config user.name t
  echo 'class Project; end'      > app/models/project.rb
  echo 'describe Project do; end' > spec/models/project_spec.rb
  echo '# Timesheet'             > README.md
  git add -A; git commit -qm base
  git checkout -q -b feat
  echo '# archived_at' >> app/models/project.rb; git commit -qam push1
) >/dev/null 2>&1
SBASE=$(git -C "$SREPO" rev-parse feat~1)
SPREV=$(git -C "$SREPO" rev-parse feat)
sps=$(git -C "$SREPO" rev-parse --short=7 "$SPREV"); sbs=$(git -C "$SREPO" rev-parse --short=7 "$SBASE")

# $1 the path the page's one checkpoint cites
smap() {
  cat > "$SMAP/index.html" <<PAGE
<div class="path">$sps &rarr; $sbs</div>
<section class="cp" id="cp-a"><a class="path" href="#">$1</a></section>
<details class="searched"><ul class="sr-list">
<li><code>grep -rn &#39;nothing_matches_this&#39; app</code> <span class="sr-r">no hits</span></li>
</ul></details>
PAGE
  cat > "$SMAP/manifest.json" <<JSON
{ "schema": "accountable-review/review-map-manifest@3",
  "revision": { "base_sha": "$SBASE", "head_sha": "$SPREV" } }
JSON
}

# $1 label, $2 expected exit, $3 substring of the reason, then the branch to run against
still() {
  label=$1; want=$2; want_text=$3; ref=$4
  rc=0
  out=$("$STILL" --dir "$SMAP" --head "$(git -C "$SREPO" rev-parse "$ref")" --repo-dir "$SREPO" 2>&1) || rc=$?
  problem=
  [ "$rc" = "$want" ] || problem="exit $rc, wanted $want"
  case $out in *"$want_text"*) ;; *) problem="${problem:+$problem; }no reason matching '$want_text'" ;; esac
  if [ -z "$problem" ]; then ok "$label"; else bad "$label ($problem)"; fi
}

(cd "$SREPO" && git checkout -q -B docsonly feat && echo 'more' >> README.md && git commit -qam docs) >/dev/null 2>&1
smap 'app/models/project.rb:1'
still "a docs-only push leaves the existing map standing" 0 "change no application code" docsonly

# THE HOLE THIS COMPOSITION EXISTS TO CLOSE, and the row to write first. application-code.sh
# classifies tests as not application code, so the first half says yes on its own — while the line
# the page cites has moved and a reader following that citation lands somewhere else.
(cd "$SREPO" && git checkout -q -B testonly feat && printf 'x\ny\n' >> spec/models/project_spec.rb && git commit -qam spec) >/dev/null 2>&1
smap 'spec/models/project_spec.rb:1'
still "a test-only push that moves a cited line regenerates" 3 "reach something the page cites" testonly

# Trivial is the gate's answer to ITS question and the wrong answer to this one: one line in a file
# a checkpoint cites is exactly where the page has quietly stopped being true.
(cd "$SREPO" && git checkout -q -B tiny feat && echo '# one more' >> app/models/project.rb && git commit -qam tiny) >/dev/null 2>&1
smap 'app/models/project.rb:1'
still "a trivially small application change still regenerates" 3 "trivially little of it but not none" tiny

# LOCK FILES SPLIT TWO WAYS HERE, and the split is right rather than an oversight — the two name
# lists exist for two different questions. diff-render.sh's, which application-code.sh borrows,
# holds the JS ones, because what it answers is "will GitHub render this diff". carry-plan.sh's P7
# holds the Ruby and Elixir ones, because what IT answers is "did the thing every documentation
# link on the page is pinned from move".
#
# So a yarn.lock bump is correctly SKIPPED: no application code, no pinned link derived from it,
# nothing the page cites. And a Gemfile.lock bump correctly regenerates — not through P7, which
# never sees it, but through the fail-open half above, where a path diff-render does not recognise
# counts as code. Both answers are right; pinning them together is what stops someone "fixing" the
# lists into agreement and losing one.
(cd "$SREPO" && git checkout -q -B jslock feat && echo '# yarn' > yarn.lock && git add -A && git commit -qm lock) >/dev/null 2>&1
smap 'app/models/project.rb:1'
still "a JS lock file bump changes nothing the map says, so it is skipped" 0 "change no application code" jslock

(cd "$SREPO" && git checkout -q -B rubylock feat && echo 'GEM' > Gemfile.lock && git add -A && git commit -qm lock) >/dev/null 2>&1
smap 'app/models/project.rb:1'
still "a Gemfile.lock bump regenerates — it re-pins every doc link on the page" 3 "application code" rubylock

still "an unmoved head needs nothing" 0 "has not moved" feat

# Every way of NOT KNOWING leads to the expensive answer. An absence is not evidence that the map
# is current, and treating it as one is how a stale page ships.
smap 'app/models/project.rb:1'
rm -f "$SMAP/manifest.json"
still "a restored map with no manifest regenerates" 3 "no manifest" docsonly
smap 'app/models/project.rb:1'; rm -f "$SMAP/index.html"
still "nothing restored at all regenerates" 3 "no previous Review Map" docsonly
smap 'app/models/project.rb:1'
rc=0; "$STILL" --dir "$SMAP" --head 0000000000000000000000000000000000000000 --repo-dir "$SREPO" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "3" "an unresolvable head regenerates rather than failing the job"
rc=0; "$STILL" --dir "$SMAP" --repo-dir "$SREPO" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "2" "and being called wrongly is a usage error, not a verdict"

echo
echo "run.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
