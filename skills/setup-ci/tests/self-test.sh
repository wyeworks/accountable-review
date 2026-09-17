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

  # A sed that errors leaves the copy unmodified or corrupt, and run.sh then
  # fails for a reason that has nothing to do with the defect — which this
  # script would have reported as "ok", the exact shape of check it exists to
  # catch. So the break has to be applied AND has to change something.
  if ! sed -i.bak "$program" "$work/$file" 2>"$work/sederr"; then
    bad=$((bad + 1))
    echo "bad   the break itself failed to apply: $desc ($(cat "$work/sederr"))"
    return
  fi
  if cmp -s "$work/$file" "$work/$file.bak"; then
    bad=$((bad + 1))
    echo "bad   the break changed nothing: $desc"
    return
  fi
  rm -f "$work/$file.bak"

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

# Deleted rather than emptied: the operators lead their lines now, so there is no
# trailing `&&` left on the draft clause for a substitution to strip.
break_and_run "the draft guard is dropped" \
  skills/setup-ci/templates/workflow.yml '/^      github.event.pull_request.draft == false$/d'

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

# The two below are the defects that actually shipped, in a repository, and cost
# a merged pull request each. Both produce a workflow file GitHub rejects
# outright — no job, no run — and neither is visible to a YAML parse, which is
# what made them survive review. A suite that does not fail on them is a suite
# that would have let them through again.

# The plausible edit is now someone putting a size condition back on the job,
# where it cannot count the right thing anyway — and writing it with a `+`.
break_and_run "the guard expression adds two counts together" \
  skills/setup-ci/templates/workflow.yml \
  's#^      && github.event.pull_request.head.repo.full_name#      \&\& github.event.pull_request.additions + github.event.pull_request.deletions > 50\
      \&\& github.event.pull_request.head.repo.full_name#'

break_and_run "one line of the folded guard is indented to align it" \
  skills/setup-ci/templates/workflow.yml \
  's#^      && github.event.pull_request.head.repo.full_name#       \&\& github.event.pull_request.head.repo.full_name#'

# The decisions someone confirms at setup have to be both real and durable. A
# knob that renders the same bytes whichever way it is set makes the confirmation
# theatre; a re-run that does not recover them reverts a team's answer while
# claiming to upgrade their pin.

break_and_run "the template's conditional blocks are flattened, so every default is on" \
  skills/setup-ci/templates/workflow.yml '/# SETUP:/d'

break_and_run "--regenerate-on-push is accepted and changes nothing" \
  skills/setup-ci/scripts/render-workflow.sh 's/--regenerate-on-push)    PUSH=1;/--regenerate-on-push)    PUSH=0;/'

# The 0.28.0 size flags have to stay inert AND stay accepted: a workflow written
# then carries them in its `# Decisions:` line, and install-workflow.sh feeds that
# back on the next upgrade. Rejecting them turns "move the version pin" into a
# hard failure on every repository that set a threshold.
break_and_run "the superseded size flags are rejected rather than ignored" \
  skills/setup-ci/scripts/render-workflow.sh \
  's|^    --min-files\|--min-lines).*$|    --min-files\|--min-lines) echo bad >\&2; exit 2 ;;|'

break_and_run "the workflow no longer records the decisions it was rendered with" \
  skills/setup-ci/templates/workflow.yml '/^# Decisions: /d'

break_and_run "a re-run stops recovering the decisions already in the file" \
  skills/setup-ci/scripts/install-workflow.sh \
  's/^if \[ "\$RECOVER" = 1 \] \&\& \[ -f "\$TARGET" \]; then$/if false; then/'

break_and_run "a threshold that is not a whole number is accepted by the config parser" \
  skills/setup-ci/scripts/read-config.sh \
  's|if (val !~ /\^\[0-9\]+\$/) fail("`" key "` must be a whole number, got `" val "`")||'

# The comment is the only thing this job does to someone's repository, and the
# only reason it holds a write token. Three ways that goes wrong, all of which
# look like tidying.

break_and_run "the write scope is granted outside the block that uses it" \
  skills/setup-ci/templates/workflow.yml 's|^  contents: read$|  contents: read\
  pull-requests: write|'

break_and_run "the write token is handed to the step that runs the model" \
  skills/setup-ci/templates/workflow.yml \
  's|^          CLAUDE_CODE_OAUTH_TOKEN: \${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}$|          CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}\
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}|'

break_and_run "the comment is appended rather than upserted" \
  skills/setup-ci/templates/workflow.yml 's/^          if \[ -n "\$existing" \]; then$/          if [ -z "$existing" ]; then/'

break_and_run "the comment stops naming the revision it describes" \
  skills/setup-ci/templates/workflow.yml 's/for \\`\$short\\` —/—/'

break_and_run "the comment reaches past delivery for the artifact URL" \
  skills/setup-ci/templates/workflow.yml \
  's/^          if \[ "\$BROWSABLE" = true \] \&\& \[ -n "\$STABLE_URL" \]; then$/          if false; then/'

break_and_run "--no-pr-comment is accepted and changes nothing" \
  skills/setup-ci/scripts/render-workflow.sh 's/--no-pr-comment)        PR_COMMENT=0;/--no-pr-comment)        PR_COMMENT=1;/'

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

# The application-code gate. Two rules, and the cases below break each of them in
# the way a plausible edit would — every one of these arrives looking like a
# tidy-up or a generosity.

# Fail open is the whole safety property of rule 1: a path nobody anticipated is
# application code, so an unusual layout costs a map that was not needed rather
# than losing one that was. Closing it turns every unrecognised path into a
# reason to publish nothing.
break_and_run "the gate treats an unrecognised path as not being application code" \
  ci/application-code.sh 's|^      printf .code.*|      printf "skip\\tunknown\\t%s\\t%s\\n" "$_path" "$_lines" ;;|'

# diff-render.sh also collapses a file for being BIG. Reading those reasons here
# would discard the large hand-written change a reviewer most needs the map for,
# by calling it generated.
break_and_run "a big application file counts as generated" \
  ci/application-code.sh 's/\$2 == "lockfile"/$2 == "lockfile" || $2 == "over-autoload"/'

# ASKED AND UNABLE TO ANSWER IS NOT AN EMPTY DIFF. Every failure mode of the gate
# ends in zero application paths, and zero is the skip verdict — so a base that
# is not in the checkout, downgraded from fatal to a skip, silently suppresses
# the Review Map for every pull request in the repository.
break_and_run "an unresolvable base is reported as a skip rather than an error" \
  ci/application-code.sh 's/^    exit 4$/    exit 3/'

# RULE 2, AND THE ONE THAT MATTERS MOST. A skip needs BOTH measurements small.
# Joined by OR it discards a change that is large by either — 900 lines in one
# file, or nine lines across six — and both of those are changes worth a map.
# This is the edit someone makes while "simplifying a condition".
break_and_run "the trivial skip joins its two thresholds with OR instead of AND" \
  ci/application-code.sh 's/\[ "\$application" -le "\$TRIVIAL_FILES" \] \&\& \[ "\$lines" -le "\$TRIVIAL_LINES" \]/[ "$application" -le "$TRIVIAL_FILES" ] || [ "$lines" -le "$TRIVIAL_LINES" ]/'

# The counts are over APPLICATION paths only, which is what makes them mean
# anything: summing the whole diff lets one lockfile call every pull request
# substantial, and the trivial rule then never fires.
break_and_run "the line count sums the whole diff rather than the application paths" \
  ci/application-code.sh "s|\\\$1 == \"code\" { n += \\\$4 }|{ n += \$4 }|"

# A threshold nobody can change without regenerating the workflow is a threshold
# a team is stuck with. The config file is the only place these live.
break_and_run "the gate ignores the thresholds in .accountable-review.yml" \
  ci/application-code.sh 's|^\[ -n "\$TRIVIAL_LINES" \] .*|TRIVIAL_LINES=$TRIVIAL_LINES_DEFAULT|'

break_and_run "generation is no longer guarded by the gate" \
  skills/setup-ci/templates/workflow.yml "/if: steps.scope.outputs.verdict == .generate./d"

# A skipped run and a broken one look identical from outside. The step that
# explains the skip is what makes the difference visible.
break_and_run "a skipped run says nothing about why there is no Review Map" \
  skills/setup-ci/templates/workflow.yml "s/verdict == 'skip'/verdict == 'never'/"

# And the threshold written where it cannot mean the right thing: the job's own
# condition, from an event payload whose counts are over the whole diff.
break_and_run "a whole-diff file count on the job condition decides whether a map is generated" \
  skills/setup-ci/templates/workflow.yml \
  's|^      && github.event.pull_request.head.repo.full_name|      \&\& github.event.pull_request.changed_files > 3\
      \&\& github.event.pull_request.head.repo.full_name|'

# --- the previous map, whose failures are all silent ------------------------
#
# Every break below leaves a workflow that runs, generates and delivers. What
# changes is only whether the next push can reuse anything, or whether what it
# reuses is safe — and neither is visible from a green run.

# The two keys drifting apart is the one that costs money rather than
# correctness: the save fills a cache nobody looks in, every run rebuilds from
# scratch, and the only symptom is the bill.
break_and_run "the cache save writes a key the restore never looks for" \
  skills/setup-ci/templates/workflow.yml \
  '/actions\/cache\/save@v4/,/key:/ s|head\.sha|run_id|'

# A key that varies between two renders of the same request breaks the byte
# comparison install-workflow.sh tells "already set up" from "edited by hand" by.
# A date is exactly what someone reaches for to expire a cache.
break_and_run "the cache key carries a date, so every second setup run reports drift" \
  skills/setup-ci/templates/workflow.yml \
  "s|restore-keys: accountable-review-map-|restore-keys: accountable-review-map-$(date -u +%Y-%m-%d)-|"

# Caching without the push trigger is a cache with nothing to feed it — and it
# is how the carrier ends up rendered for every team rather than the ones who
# asked for a map per push.
break_and_run "the cache steps render whether or not the workflow regenerates on push" \
  skills/setup-ci/templates/workflow.yml \
  '/^# SETUP:IF:push$/{N;/The previous Review Map\|Kept for the next push/s/^# SETUP:IF:push/# SETUP:IF:authors/;}'

# Keeping whatever was in the directory when a step died.
break_and_run "the cache is saved even when the run did not deliver" \
  skills/setup-ci/templates/workflow.yml \
  "s|if: success() && steps.scope.outputs.verdict == 'generate'|if: steps.scope.outputs.verdict == 'generate'|"

# Asking for an update against an empty directory. The skill would have to talk
# its way out of a flag whose premise is false, and the honest place to decide
# that is here, where the file either exists or does not.
break_and_run "--update is passed whether or not a previous page is there" \
  ci/generate-review-map.sh \
  's|^if \[ "$UPDATE" = on \] && \[ -f "$OUTPUT_ABS/index.html" \]; then$|if [ "$UPDATE" = on ]; then|'

# The config key that would let a team turn it off, silently ignored.
break_and_run "review_map.update is parsed and then not read" \
  ci/generate-review-map.sh \
  's@^\[ -n "$UPDATE" \].*CFG_update.*$@UPDATE=true@'

# updated_from asserted rather than read. A manifest that says a page was updated
# from a revision the page itself does not name is provenance that disagrees with
# the thing it is provenance for — and it disagrees in the reassuring direction.
break_and_run "the manifest asserts what it was updated from instead of reading the page" \
  ci/generate-review-map.sh \
  's|^updated_from=$(sed -n .*$|updated_from=$BASE_SHA|'

echo
echo "self-test: $ok ok, $bad bad"
[ "$bad" -eq 0 ]
