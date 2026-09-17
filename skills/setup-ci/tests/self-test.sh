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

# --mentor is the one setting that changes what is ON the page, so its default is the one that
# matters most: a page built for a reviewer who is new to the stack, handed to a team that did not
# ask for one, is a longer page nobody chose. On by default is the plausible edit — it looks
# generous — and this is the row that catches it.
break_and_run "mentor defaults to on, so every CI page teaches the framework" \
  ci/generate-review-map.sh 's|MENTOR=${CFG_mentor:-off}|MENTOR=${CFG_mentor:-on}|'

# And the peek that reads --mentor's optional value. Consuming ANY next argument turns
# `--mentor --effort low` into a mentor run at the default effort, with nothing saying so.
break_and_run "the optional stack name swallows whatever flag follows --mentor" \
  ci/generate-review-map.sh 's|case ${2:-} in rails\|elixir\|phoenix) MENTOR=$2; shift ;; esac|case ${2:-} in ?*) MENTOR=$2; shift ;; esac|'

# The application-code gate. Every case here is a way of making the gate stop
# deciding on WHICH paths changed, which is the only thing it is supposed to
# decide on — and each of them arrives looking like a tidy-up.

# Fail open is the whole safety property: a path nobody anticipated is
# application code, so an unusual layout costs a map that was not needed rather
# than losing one that was. Closing it turns every unrecognised path into a
# reason to publish nothing.
break_and_run "the gate treats an unrecognised path as not being application code" \
  ci/application-code.sh 's|^      printf .code.*|      printf "skip\\tunknown\\t%s\\n" "$_path" ;;|'

# diff-render.sh also collapses a file for being BIG. Reading those reasons here
# is how a size threshold gets back in through the part of the script that looks
# like it is only about file types — and it would discard the large hand-written
# change a reviewer most needs the map for.
break_and_run "a big application file counts as generated, so size decides after all" \
  ci/application-code.sh 's/\$2 == "lockfile"/$2 == "lockfile" || $2 == "over-autoload"/'

# ASKED AND UNABLE TO ANSWER IS NOT AN EMPTY DIFF. Every failure mode of the gate
# ends in zero application paths, and zero is the skip verdict — so a base that
# is not in the checkout, downgraded from fatal to a skip, silently suppresses
# the Review Map for every pull request in the repository.
break_and_run "an unresolvable base is reported as a skip rather than an error" \
  ci/application-code.sh 's/^    exit 4$/    exit 3/'

break_and_run "generation is no longer guarded by the gate" \
  skills/setup-ci/templates/workflow.yml "/if: steps.scope.outputs.verdict == .generate./d"

# A skipped run and a broken one look identical from outside. The step that
# explains the skip is what makes the difference visible.
break_and_run "a skipped run says nothing about why there is no Review Map" \
  skills/setup-ci/templates/workflow.yml "s/verdict == 'skip'/verdict == 'never'/"

# And the rule this gate replaced, coming back where it is cheapest to write: a
# count on the job's own condition, from the event payload.
break_and_run "a file count on the job condition decides whether a map is generated" \
  skills/setup-ci/templates/workflow.yml 's|      github.event.pull_request.draft == false \&\&|      github.event.pull_request.changed_files > 3 \&\&\n      github.event.pull_request.draft == false \&\&|'

echo
echo "self-test: $ok ok, $bad bad"
[ "$bad" -eq 0 ]
