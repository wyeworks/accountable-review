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
assert_in "$W" "      - ready_for_review"              "trigger: ready_for_review"
assert_in "$W" "      - synchronize"                   "trigger: synchronize"
assert_in "$W" "      - reopened"                      "trigger: reopened"
assert_not_in "$W_CODE" "      - labeled"                   "no trigger on labels"
assert_not_in "$W_CODE" "      - edited"                    "no trigger on edits to the description"
assert_not_in "$W_CODE" "pull_request_target"               "never pull_request_target"

assert_in "$W" "github.event.pull_request.draft == false"                          "draft pull requests are skipped"
assert_in "$W" "github.event.pull_request.head.repo.full_name == github.repository" "fork pull requests are skipped"

assert_in "$W" "group: accountable-review-\${{ github.event.pull_request.number }}" "concurrency is scoped to the pull request"
assert_in "$W" "cancel-in-progress: true"              "superseded runs are cancelled"

assert_in "$W" "permissions:"                          "permissions are declared"
assert_in "$W" "  contents: read"                      "permissions are read-only"
assert_not_in "$W_CODE" "contents: write"                   "nothing asks for write access"
assert_not_in "$W_CODE" "pull-requests: write"              "nothing asks to write on the pull request"
assert_not_in "$W_CODE" "issues: write"                     "nothing asks to write issues"

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

if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
  if python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); sys.exit(0 if d.get("jobs",{}).get("review-map") else 1)' "$W"; then
    ok "it parses as YAML and defines the review-map job"
  else
    bad "it parses as YAML and defines the review-map job"
  fi
else
  ok "YAML parse skipped — no pyyaml here (the shape is asserted line by line above)"
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
echo "== configuration =="

C=$TMP/config
mkdir -p "$C"
cat > "$C/.accountable-review.yml" <<'Y'
review_map:
  mode: light
  delivery:
    provider: github-artifact
    retention_days: 14
Y
"$READ_CONFIG" "$C/.accountable-review.yml" > "$TMP/cfg"
assert_in "$TMP/cfg" "CFG_mode='light'"                "mode is read, and accepted as an alias"
assert_in "$TMP/cfg" "CFG_retention_days='14'"         "retention_days is read"
assert_not_in "$TMP/cfg" "CFG_effort"                  "a key the file omits produces no line"

mkdir -p "$TMP/out-cfg" && echo '<html>x</html>' > "$TMP/out-cfg/index.html"
( cd "$C" && "$DELIVER" --dir "$TMP/out-cfg" --repository acme/app --pr 412 --head-sha a93bd21deadbeef ) > "$TMP/deliver-cfg"
assert_in "$TMP/deliver-cfg" '"retention_days": "14"'  "the workflow honours retention_days from the config file"

( cd "$C" && "$GENERATE" --print-invocation --output "$TMP/out-cfg" --pr 412 \
    --head-sha a93bd21deadbeef --repo-dir "$C" ) > "$TMP/inv-cfg"
# THE PAGE HAS ONE SHAPE, so no level ever reaches the run. mode is still read and still
# validated — a workflow that has been passing it keeps working — and then goes nowhere.
assert_not_in "$TMP/inv-cfg" "--light"                 "the configured mode does not reach the run"
assert_not_in "$TMP/inv-cfg" "--brief"                 "and neither does its old name"
( cd "$C" && "$GENERATE" --print-invocation --output "$TMP/out-cfg" --pr 412 \
    --head-sha a93bd21deadbeef --repo-dir "$C" --mode brief ) > "$TMP/inv-flag"
assert_not_in "$TMP/inv-flag" "--brief"                "an explicit mode is accepted and passes nothing on"

"$GENERATE" --print-invocation --output "$TMP/out-cfg" --pr 412 --head-sha a93bd21deadbeef \
  --repo-dir "$TMP" > "$TMP/inv-def"
assert_not_in "$TMP/inv-def" "--brief"                 "no detail level is passed by default either"
assert_in "$TMP/inv-def" "--effort high"               "the default effort is high, as the skill's is"

# --mentor is OFF unless asked for, and off is the ABSENCE of the flag rather than a value: the
# skill parses no `--mentor off`, and a flag whose off state is spelled out is one more thing for
# it to get wrong. It is also the one setting that changes what is on the page, which is why the
# default matters more here than mode's does.
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

# `full` is refused rather than mapped: it named a seven-section page, and handing back the
# agenda under that name is a setting that changed meaning without telling anyone.
rc=0; printf 'review_map:\n  mode: full\n' > "$C/full.yml"
"$READ_CONFIG" "$C/full.yml" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1"                                    "mode: full is refused, not silently downgraded"

rc=0; printf 'review_map:\n  retention_day: 14\n' > "$C/bad.yml"
"$READ_CONFIG" "$C/bad.yml" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1"                                    "a misspelled key is an error, not a shrug"
rc=0; printf 'review_map:\n  mode: review\n' > "$C/review.yml"
"$READ_CONFIG" "$C/review.yml" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1"                                    "mode: review is rejected rather than downgraded"

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
echo "run.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
