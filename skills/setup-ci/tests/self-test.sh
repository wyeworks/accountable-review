#!/bin/sh
# self-test.sh — prove the tests in run.sh actually fire.
#
#   Usage: tests/self-test.sh
#
# A test suite that passes because it never looked is worse than no suite: it
# converts an unchecked property into a checked-looking one. So each case here
# copies the plugin, breaks exactly one thing run.sh claims to check, and asserts
# that run.sh now fails. A case that still passes after the break names an
# assertion that was decorative.
#
# The breaks are chosen to be the ones a plausible edit would make — dropping
# concurrency while reformatting the template, widening permissions to fix an
# unrelated step, letting the config parser shrug at a key it does not know.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=$(dirname "$(dirname "$(dirname "$HERE")")")

ok=0; bad=0
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

n=0
# break <description> <file, relative to the plugin root> <sed program>
break_and_run() {
  desc=$1; file=$2; program=$3
  n=$((n + 1))
  work=$TMP/case-$n
  mkdir -p "$work"
  ( cd "$PLUGIN_ROOT" && tar cf - --exclude=.git . ) | ( cd "$work" && tar xf - )
  sed -i.bak "$program" "$work/$file" && rm -f "$work/$file.bak"
  if "$work/skills/setup-ci/tests/run.sh" > "$work/out" 2>&1; then
    bad=$((bad + 1))
    echo "bad   run.sh still passed with: $desc"
  else
    ok=$((ok + 1))
    echo "ok    run.sh fails when: $desc"
  fi
}

break_and_run "concurrency no longer cancels superseded runs" \
  skills/setup-ci/templates/workflow.yml 's/cancel-in-progress: true/cancel-in-progress: false/'

break_and_run "the workflow asks for write access" \
  skills/setup-ci/templates/workflow.yml 's/^  contents: read$/  contents: write/'

break_and_run "the draft guard is dropped" \
  skills/setup-ci/templates/workflow.yml 's/github.event.pull_request.draft == false \&\&//'

break_and_run "it triggers on every pull request activity" \
  skills/setup-ci/templates/workflow.yml 's/^      - reopened$/      - labeled/'

break_and_run "the artifact upload loses its retention" \
  skills/setup-ci/templates/workflow.yml '/retention-days:/d'

break_and_run "the rendered workflow carries a timestamp" \
  skills/setup-ci/scripts/render-workflow.sh 's|^sed \\|echo "# generated $(date -u +%Y-%m-%d)"\nsed \\|'

break_and_run "install overwrites a hand-edited workflow" \
  skills/setup-ci/scripts/install-workflow.sh 's/^if \[ "\$UPDATE" = 1 \]; then$/if true; then/'

break_and_run "the config parser ignores a key it does not know" \
  skills/setup-ci/scripts/read-config.sh 's/else fail("unknown key `" key "` under `review_map:`")/else next/'

break_and_run "the artifact is not named for the revision" \
  ci/delivery/github-artifact.sh 's|name="accountable-review-pr-\$AR_PR-\$short"|name="accountable-review-pr-$AR_PR"|'

break_and_run "a page that still says it is being written is delivered anyway" \
  ci/generate-review-map.sh "s|if grep -q 'class=\"buildstate\"' \"\$PAGE\" |if false \&\& grep -q 'class=\"buildstate\"' \"\$PAGE\" |"

echo
echo "self-test: $ok ok, $bad bad"
[ "$bad" -eq 0 ]
