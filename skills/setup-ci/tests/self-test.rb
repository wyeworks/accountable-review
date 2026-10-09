#!/usr/bin/env ruby
# frozen_string_literal: true

# self-test.rb — prove the assertions in suite.rb actually fire.
#
#   Usage: ruby skills/setup-ci/tests/self-test.rb [--discover] [-j N] [number...]
#
# A test suite that passes because it never looked is worse than no suite: it converts an unchecked
# property into a checked-looking one. So each case here breaks exactly one thing the suite claims
# to check, on a copy of the plugin, and asserts that the NAMED assertion now fails. A case that
# still passes after the break names an assertion that was decorative.
#
# The breaks are chosen to be the ones a plausible edit would make — dropping concurrency while
# reformatting the template, widening permissions to fix an unrelated step, letting the config
# parser shrug at a key it does not know.
#
# WHY THIS IS NOT THE SHELL SELF-TEST IT REPLACES. That one re-ran the whole of run.sh once per
# break, 51 of them, and cost minutes a push until it was deleted — leaving every one of these rules
# checked by nothing. Here a case runs only the section of suite.rb its break can reach, and the
# cases run in parallel, each worker on its own copy. Two things make that honest rather than a
# shortcut. The sanity row runs EVERY section on the clean copy first, so a section that fails for
# its own reasons cannot make a break look caught. And a case names the assertion it must turn red
# rather than accepting any failure, which is stricter than the whole-suite exit code it replaced:
# a break that "fails" because it crashed an unrelated fixture is reported, not counted.
#
# --discover prints every assertion each break turns red, which is how the `expect` column below was
# chosen and how to choose one for a new row.
#
# Exit 0 when every case is caught, 1 otherwise, 2 when called wrongly.

require "etc"
require "fileutils"
require "stringio"
require "tmpdir"
require_relative "suite"

ROOT = File.expand_path("../../..", __dir__)

Case = Struct.new(:desc, :file, :edit, :sections, :expect, keyword_init: true)

# ------------------------------------------------------------------ edits
#
# The shell self-test spelled these as sed programs. They are Ruby here, with sed's semantics kept
# where they matter: an address range opens on the first match and closes on the NEXT match of its
# end, never the opening line.

def sub(pattern, replacement) = ->(s) { s.gsub(pattern) { replacement } }
def drop(pattern) = ->(s) { s.lines.reject { |l| l.match?(pattern) }.join }

def sed_ranges(text, from, to)
  inside = false
  text.lines.map do |l|
    if inside
      inside = false if l.match?(to)
      [l, true]
    elsif l.match?(from)
      inside = true
      [l, true]
    else
      [l, false]
    end
  end
end

def drop_range(from, to) = ->(s) { sed_ranges(s, from, to).reject(&:last).map(&:first).join }

def sub_in_range(from, to, pattern, replacement)
  ->(s) { sed_ranges(s, from, to).map { |l, inside| inside ? l.sub(pattern) { replacement } : l }.join }
end

W = "skills/setup-ci/templates/workflow.yml"
RENDER = "skills/setup-ci/scripts/render-workflow.sh"
INSTALL = "skills/setup-ci/scripts/install-workflow.sh"
READ_CONFIG = "skills/setup-ci/scripts/read-config.sh"
GENERATE = "ci/generate-review-map.sh"
GATE = "ci/application-code.sh"
STILL = "ci/map-still-current.sh"
FORK_GUARD = /^      && github\.event\.pull_request\.head\.repo\.full_name/

CASES = [
  Case.new(desc: "concurrency no longer cancels superseded runs", file: W,
           edit: sub("cancel-in-progress: true", "cancel-in-progress: false"),
           sections: %i[workflow], expect: "superseded runs are cancelled"),

  Case.new(desc: "the workflow asks for write access", file: W,
           edit: sub(/^  contents: read$/, "  contents: write"),
           sections: %i[workflow], expect: "nothing asks to write the repository's contents"),

  # Deleted rather than emptied: the operators lead their lines, so there is no trailing `&&` left
  # on the draft clause for a substitution to strip.
  Case.new(desc: "the draft guard is dropped", file: W,
           edit: drop(/^      github\.event\.pull_request\.draft == false$/),
           sections: %i[workflow], expect: "draft pull requests are skipped"),

  Case.new(desc: "it triggers on every pull request activity", file: W,
           edit: sub(/^      - reopened$/, "      - labeled"),
           sections: %i[workflow], expect: "no trigger on labels"),

  Case.new(desc: "the artifact upload loses its retention", file: W,
           edit: drop(/retention-days:/),
           sections: %i[workflow], expect: "retention comes from the delivery result"),

  # Computed while rendering, ahead of the pipeline. The shell case put the line between `awk |`
  # and `sed`, which cut the pipeline in half and broke every assertion in the section, so it proved
  # only that a broken render is noticed; this one renders a correct file plus one dated comment.
  Case.new(desc: "the rendered workflow carries a timestamp", file: RENDER,
           edit: sub(/^awk -v push=/, "echo \"# generated $(date -u +%Y-%m-%d)\"\nawk -v push="),
           sections: %i[workflow], expect: "the rendered file carries no timestamp"),

  # New with the port, and the reason the timestamp assertion has two halves: a clock read that
  # prints no date is invisible to a search for one, and only two renders on two days can see it.
  Case.new(desc: "the rendered workflow carries a build number read from the clock", file: RENDER,
           edit: sub(/^awk -v push=/, "echo \"# build $(date -u +%s)\"\nawk -v push="),
           sections: %i[workflow], expect: "the rendered file carries no timestamp"),

  Case.new(desc: "install overwrites a hand-edited workflow", file: INSTALL,
           edit: sub(/^if \[ "\$UPDATE" = 1 \]; then$/, "if true; then"),
           sections: %i[twice], expect: "a hand-edited workflow is reported as drift"),

  Case.new(desc: "the config parser ignores a key it does not know", file: READ_CONFIG,
           edit: sub('else fail("unknown key `" key "` under `review_map:`")', "else next"),
           sections: %i[config], expect: "a misspelled key is an error, not a shrug"),

  # New with the themes, which arrived after the port: the parser's list of names and the skill's
  # themes directory are two places for one list, and a theme dropped from the first is a theme a
  # team can pick in the skill and never in CI.
  Case.new(desc: "the config parser stops accepting a theme the skill ships", file: READ_CONFIG,
           edit: sub(' && val != "field-notes")', ")"),
           sections: %i[config], expect: "read-config.sh accepts the theme file field-notes"),

  # And a theme read from a --config file kept outside the checkout, parsed and then dropped: the
  # skill reads the checkout's file by itself, so the environment is the only way that one arrives.
  Case.new(desc: "a theme in a --config file never reaches the run", file: GENERATE,
           edit: sub(/^  set -- env "ACCOUNTABLE_REVIEW_THEME=\$THEME" "\$@"$/, "  :"),
           sections: %i[config], expect: "a theme in the config file reaches the run's environment"),

  # New with Rust, which also arrived after the port: the stack names are listed in the parser and
  # in the adapter, and a stack dropped from the parser is a --mentor a team can pass by hand and
  # never set in CI.
  Case.new(desc: "the config parser stops accepting rust as a mentor stack", file: READ_CONFIG,
           edit: sub(' && val != "rust"', ""),
           sections: %i[config], expect: "rust is a stack name the config file and the adapter both accept"),
  # And React, the same two places: the parser, and the adapter's peek at --mentor's value. A name
  # dropped from the peek leaves `--mentor react` reaching the run as a bare --mentor followed by an
  # unknown argument, which the adapter refuses — so the CI page for a React repository would fail
  # to generate rather than quietly lose its primers.
  Case.new(desc: "the config parser stops accepting nextjs as a mentor stack", file: READ_CONFIG,
           edit: sub(' && val != "nextjs")', ")"),
           sections: %i[config], expect: "nextjs is a stack name the config file and the adapter both accept"),
  Case.new(desc: "the adapter's peek stops taking react as --mentor's value", file: GENERATE,
           edit: sub("case ${2:-} in rails|elixir|phoenix|rust|react|nextjs) MENTOR=$2; shift ;; esac", "case ${2:-} in rails|elixir|phoenix|rust|nextjs) MENTOR=$2; shift ;; esac"),
           sections: %i[config], expect: "react is a stack name the adapter takes as --mentor's value"),

  Case.new(desc: "the artifact is not named for the revision", file: "ci/delivery/github-artifact.sh",
           edit: sub('name="accountable-review-pr-$AR_PR-$short"', 'name="accountable-review-pr-$AR_PR"'),
           sections: %i[delivery], expect: "the artifact is named for the PR and the revision"),

  Case.new(desc: "a page that still says it is being written is delivered anyway", file: GENERATE,
           edit: sub(%(if grep -q 'class="buildstate"' "$PAGE" ), %(if false && grep -q 'class="buildstate"' "$PAGE" )),
           sections: %i[adapter], expect: "a page still promising pending sections is refused"),

  # The two below are the defects that actually shipped, in a repository, and cost a merged pull
  # request each. Both produce a workflow file GitHub rejects outright — no job, no run — and neither
  # is visible to a YAML parse, which is what made them survive review.

  # The plausible edit is someone putting a size condition back on the job, where it cannot count
  # the right thing anyway — and writing it with a `+`.
  Case.new(desc: "the guard expression adds two counts together", file: W,
           edit: sub(FORK_GUARD, "      && github.event.pull_request.additions + github.event.pull_request.deletions > 50\n" \
                                 "      && github.event.pull_request.head.repo.full_name"),
           sections: %i[workflow], expect: "the guard expression uses no arithmetic"),

  Case.new(desc: "one line of the folded guard is indented to align it", file: W,
           edit: sub(FORK_GUARD, "       && github.event.pull_request.head.repo.full_name"),
           sections: %i[workflow], expect: "every line of the guard expression is at the same indentation"),

  # The decisions someone confirms at setup have to be both real and durable. A knob that renders the
  # same bytes whichever way it is set makes the confirmation theatre; a re-run that does not
  # recover them reverts a team's answer while claiming to upgrade their pin.

  Case.new(desc: "the template's conditional blocks are flattened, so every default is on", file: W,
           edit: drop(/# SETUP:/),
           sections: %i[workflow], expect: "pushes do not regenerate the map by default"),

  Case.new(desc: "--regenerate-on-push is accepted and changes nothing", file: RENDER,
           edit: sub("--regenerate-on-push)    PUSH=1;", "--regenerate-on-push)    PUSH=0;"),
           sections: %i[decisions], expect: "--regenerate-on-push adds the push trigger"),

  # The 0.28.0 size flags have to stay inert AND stay accepted: a workflow written then carries them
  # in its `# Decisions:` line, and install-workflow.sh feeds that back on the next upgrade.
  Case.new(desc: "the superseded size flags are rejected rather than ignored", file: RENDER,
           edit: sub(/^    --min-files\|--min-lines\).*$/, "    --min-files|--min-lines) echo bad >&2; exit 2 ;;"),
           sections: %i[decisions], expect: "the old thresholds render the same bytes as no thresholds at all"),

  Case.new(desc: "the workflow no longer records the decisions it was rendered with", file: W,
           edit: drop(/^# Decisions: /),
           sections: %i[decisions], expect: "the file records every decision in the form setup takes them"),

  Case.new(desc: "a re-run stops recovering the decisions already in the file", file: INSTALL,
           edit: sub(/^if \[ "\$RECOVER" = 1 \] && \[ -f "\$TARGET" \]; then$/, "if false; then"),
           sections: %i[recovery], expect: "a re-run passing no decisions recovers them and finds nothing to do"),

  Case.new(desc: "a threshold that is not a whole number is accepted by the config parser", file: READ_CONFIG,
           edit: sub('if (val !~ /^[0-9]+$/) fail("`" key "` must be a whole number, got `" val "`")', ""),
           sections: %i[decisions], expect: "a threshold that is not a whole number is refused"),

  # The comment is the only thing this job does to someone's repository, and the only reason it
  # holds a write token. Three ways that goes wrong, all of which look like tidying.

  Case.new(desc: "the write scope is granted outside the block that uses it", file: W,
           edit: sub(/^  contents: read$/, "  contents: read\n  pull-requests: write"),
           sections: %i[comment], expect: "--no-pr-comment drops the write scope"),

  Case.new(desc: "the write token is handed to the step that runs the model", file: W,
           edit: sub(/^          CLAUDE_CODE_OAUTH_TOKEN: \$\{\{ secrets\.CLAUDE_CODE_OAUTH_TOKEN \}\}$/,
                     "          CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}\n" \
                     "          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}"),
           sections: %i[comment], expect: "and by no other step, so the model step never sees a write-capable credential"),

  Case.new(desc: "the comment is appended rather than upserted", file: W,
           edit: sub(/^          if \[ -n "\$existing" \]; then$/, '          if [ -z "$existing" ]; then'),
           sections: %i[comment], expect: "an existing comment is patched, not duplicated"),

  Case.new(desc: "the comment stops naming the revision it describes", file: W,
           edit: sub("for \\`$short\\` —", "—"),
           sections: %i[comment], expect: "and the short head SHA, which is how staleness is seen"),

  Case.new(desc: "the comment reaches past delivery for the artifact URL", file: W,
           edit: sub(/^          if \[ "\$BROWSABLE" = true \] && \[ -n "\$STABLE_URL" \]; then$/, "          if false; then"),
           sections: %i[comment], expect: "a browsable provider's URL is what gets linked"),

  Case.new(desc: "--no-pr-comment is accepted and changes nothing", file: RENDER,
           edit: sub("--no-pr-comment)        PR_COMMENT=0;", "--no-pr-comment)        PR_COMMENT=1;"),
           sections: %i[comment], expect: "--no-pr-comment drops the write scope"),

  # --mentor is the one setting that changes what is ON the page, so its default is the one that
  # matters most: on by default is the plausible edit — it looks generous.
  Case.new(desc: "mentor defaults to on, so every CI page teaches the framework", file: GENERATE,
           edit: sub("MENTOR=${CFG_mentor:-off}", "MENTOR=${CFG_mentor:-on}"),
           sections: %i[config], expect: "no mentor flag is passed by default"),

  # And the peek that reads --mentor's optional value. Consuming ANY next argument turns
  # `--mentor --effort low` into a mentor run at the default effort, with nothing saying so.
  Case.new(desc: "the optional stack name swallows whatever flag follows --mentor", file: GENERATE,
           edit: sub("case ${2:-} in rails|elixir|phoenix|rust|react|nextjs) MENTOR=$2; shift ;; esac", "case ${2:-} in ?*) MENTOR=$2; shift ;; esac"),
           sections: %i[config], expect: "a bare --mentor does not swallow the flag after it"),

  # The application-code gate. Two rules, and the cases below break each of them in the way a
  # plausible edit would — every one of these arrives looking like a tidy-up or a generosity.

  # Fail open is the whole safety property of rule 1: a path nobody anticipated is application code.
  Case.new(desc: "the gate treats an unrecognised path as not being application code", file: GATE,
           edit: sub(/^      printf .code.*$/, %(      printf "skip\\tunknown\\t%s\\t%s\\n" "$_path" "$_lines" ;;)),
           sections: %i[gate], expect: "an unrecognised path counts as application code"),

  # diff-render.sh also collapses a file for being BIG. Reading those reasons here would discard the
  # large hand-written change a reviewer most needs the map for, by calling it generated.
  Case.new(desc: "a big application file counts as generated", file: GATE,
           edit: sub('$2 == "lockfile"', '$2 == "lockfile" || $2 == "over-autoload"'),
           sections: %i[gate], expect: "a 900-line change in ONE file earns one"),

  # ASKED AND UNABLE TO ANSWER IS NOT AN EMPTY DIFF. Every failure mode of the gate ends in zero
  # application paths, and zero is the skip verdict.
  Case.new(desc: "an unresolvable base is reported as a skip rather than an error", file: GATE,
           edit: sub(/^    exit 4$/, "    exit 3"),
           sections: %i[gate], expect: "a base that cannot be resolved is an error, not a skip"),

  # RULE 2, AND THE ONE THAT MATTERS MOST. A skip needs BOTH measurements small. This is the edit
  # someone makes while "simplifying a condition".
  Case.new(desc: "the trivial skip joins its two thresholds with OR instead of AND", file: GATE,
           edit: sub('[ "$application" -le "$TRIVIAL_FILES" ] && [ "$lines" -le "$TRIVIAL_LINES" ]',
                     '[ "$application" -le "$TRIVIAL_FILES" ] || [ "$lines" -le "$TRIVIAL_LINES" ]'),
           sections: %i[gate], expect: "a 900-line change in ONE file earns one"),

  # The counts are over APPLICATION paths only, which is what makes them mean anything.
  Case.new(desc: "the line count sums the whole diff rather than the application paths", file: GATE,
           edit: sub('$1 == "code" { n += $4 }', "{ n += $4 }"),
           sections: %i[gate], expect: "a one-line model change beside a 5000-line lockfile is still trivial"),

  # A threshold nobody can change without regenerating the workflow is a threshold a team is stuck with.
  Case.new(desc: "the gate ignores the thresholds in .accountable-review.yml", file: GATE,
           edit: sub(/^\[ -n "\$TRIVIAL_LINES" \] .*$/, "TRIVIAL_LINES=$TRIVIAL_LINES_DEFAULT"),
           sections: %i[gate], expect: "trivial_lines: 0 in the config file generates a map for any application change"),

  Case.new(desc: "generation is no longer guarded by the gate", file: W,
           edit: drop(/if: steps\.scope\.outputs\.verdict == .generate./),
           sections: %i[workflow], expect: "generation is guarded by the scope check"),

  # A skipped run and a broken one look identical from outside. The step that explains the skip is
  # what makes the difference visible.
  Case.new(desc: "a skipped run says nothing about why there is no Review Map", file: W,
           edit: sub("verdict == 'skip'", "verdict == 'never'"),
           sections: %i[workflow], expect: "a skipped run says why, rather than just not happening"),

  # And the threshold written where it cannot mean the right thing: the job's own condition, from an
  # event payload whose counts are over the whole diff.
  Case.new(desc: "a whole-diff file count on the job condition decides whether a map is generated", file: W,
           edit: sub(FORK_GUARD, "      && github.event.pull_request.changed_files > 3\n" \
                                 "      && github.event.pull_request.head.repo.full_name"),
           sections: %i[workflow], expect: "the job condition counts no files"),

  # --- the previous map, whose failures are all silent. Every break below leaves a workflow that
  # runs, generates and delivers; what changes is only whether the next push can reuse anything.

  # The two keys drifting apart costs money rather than correctness: the save fills a cache nobody
  # looks in, and the only symptom is the bill.
  Case.new(desc: "the cache save writes a key the restore never looks for", file: W,
           edit: sub_in_range(%r{actions/cache/save@v4}, /key:/, /head\.sha/, "run_id"),
           sections: %i[previous], expect: "the restore and the save name the same key"),

  # A key that varies between two renders breaks the byte comparison install-workflow.sh tells
  # "already set up" from "edited by hand" by. A date is exactly what someone reaches for to expire a
  # cache. The shell case typed today's date; a fixed one is the same defect without the clock.
  Case.new(desc: "the cache key carries a date, so every second setup run reports drift", file: W,
           edit: sub("restore-keys: accountable-review-map-", "restore-keys: accountable-review-map-2026-10-07-"),
           sections: %i[previous], expect: "and the cache key carries no date"),

  # Caching without the push trigger is a cache with nothing to feed it.
  Case.new(desc: "the cache steps render whether or not the workflow regenerates on push", file: W,
           edit: sub(/^# SETUP:IF:push\n(?=.*(?:The previous Review Map|Kept for the next push))/, "# SETUP:IF:authors\n"),
           sections: %i[previous], expect: "the default file caches nothing — there is no second run to feed"),

  # Keeping whatever was in the directory when a step died.
  Case.new(desc: "the cache is saved even when the run did not deliver", file: W,
           edit: sub("if: success() && steps.scope.outputs.verdict == 'generate'", "if: steps.scope.outputs.verdict == 'generate'"),
           sections: %i[previous], expect: "the save runs only when this run actually delivered"),

  # Asking for an update against an empty directory. The honest place to decide that is here, where
  # the file either exists or does not.
  Case.new(desc: "--update is passed whether or not a previous page is there", file: GENERATE,
           edit: sub(/^if \[ "\$UPDATE" = on \] && \[ -f "\$OUTPUT_ABS\/index\.html" \]; then$/, 'if [ "$UPDATE" = on ]; then'),
           sections: %i[previous], expect: "no previous page means no --update, whatever the config says"),

  # The config key that would let a team turn it off, silently ignored.
  Case.new(desc: "review_map.update is parsed and then not read", file: GENERATE,
           edit: sub(/^\[ -n "\$UPDATE" \].*CFG_update.*$/, "UPDATE=true"),
           sections: %i[previous], expect: "update: false turns it off with the page still there"),

  # updated_from asserted rather than read: provenance that disagrees with the thing it is provenance
  # for, in the reassuring direction.
  Case.new(desc: "the manifest asserts what it was updated from instead of reading the page", file: GENERATE,
           edit: sub(/^updated_from=\$\(sed -n .*$/, "updated_from=$BASE_SHA"),
           sections: %i[previous], expect: "a page with no update segment records null"),

  # --- the second question, whose failures are all a map that quietly stops being true.

  # Either half alone is not evidence the map is current: a test-only push satisfies the
  # application-code half by itself.
  Case.new(desc: "the two halves of the still-current test are joined by OR", file: STILL,
           edit: drop_range(/^if printf .*PLAN.*grep -q/, /^fi$/),
           sections: %i[still], expect: "a test-only push that moves a cited line regenerates"),

  # Trivial is the gate's answer to its own question and the wrong answer to this one.
  Case.new(desc: "a trivially small application change counts as no application change", file: STILL,
           edit: sub(/^  3:trivial\).*$/, "  3:trivial) ;;"),
           sections: %i[still], expect: "a trivially small application change still regenerates"),

  # A restored directory holding a page but no manifest: which revision that page describes is
  # unknown, and unknown has to lead to the expensive answer.
  #
  # What this does NOT pin is the rule one line below it — that the previous head comes from the
  # manifest and never from the page — and no mutation here can. The page's own short SHA is a
  # seven-character prefix that `git rev-parse` resolves happily, so a version reading it would pass
  # every assertion in suite.rb. The rule is carried by the comment in the script and nothing else.
  Case.new(desc: "a restored map with no manifest is used as though it were current", file: STILL,
           edit: sub(/^\[ -f "\$MANIFEST" \] /, "# "),
           sections: %i[still], expect: "a restored map with no manifest regenerates"),

  # An absence treated as evidence.
  Case.new(desc: "nothing restored is treated as a map that is still current", file: STILL,
           edit: sub(/^\[ -f "\$PAGE" \] .*$/, "true"),
           sections: %i[still], expect: "nothing restored at all regenerates"),

  # The second half of the decision is about the restored map, so the ordering is a dependency.
  Case.new(desc: "the previous map is restored after the step that decides whether to generate", file: W,
           edit: drop_range(/^      - name: Restore the previous Review Map$/, /^# SETUP:END:push$/),
           sections: %i[still], expect: "the previous map is restored before the step that decides whether to generate"),

  # Computed and then ignored — the shape of check that runs, prints, and changes nothing.
  Case.new(desc: "the still-current answer is computed and never acted on", file: W,
           edit: sub(/^                echo "verdict=skip"$/, '                echo "verdict=generate"'),
           sections: %i[still], expect: "and the verdict it writes is skip — anything else computes the answer and ignores it"),

  # --- ripgrep on demand, whose every failure mode is a slower run rather than a wrong one.

  Case.new(desc: "ripgrep is installed whether or not there is a previous map to replay", file: W,
           edit: drop(/^        if: steps\.previous\.outputs\.cache-matched-key/),
           sections: %i[still], expect: "and only when a previous map was actually restored"),

  # Below the step that replays the searches: carry-plan has already refused by the time it lands.
  Case.new(desc: "ripgrep is installed after the step that replays the recorded searches", file: W,
           edit: drop_range(/^      - name: Install ripgrep/, /rebuilds the page instead of updating it"$/),
           sections: %i[still], expect: "ripgrep is installed after the restore and before the step that replays the searches"),

  # The install is an optimisation, so a failed one costs minutes rather than the map.
  Case.new(desc: "a failed ripgrep install fails the whole job instead of rebuilding the page", file: W,
           edit: sub(/^            \|\| echo "no ripgrep.*$/, "            ; :"),
           sections: %i[still], expect: "and a failed install leaves the run to rebuild the page rather than failing the job")
].freeze

# ------------------------------------------------------------------ running

def copy_plugin(dest)
  FileUtils.mkdir_p(dest)
  Dir.children(ROOT).reject { |c| c == ".git" }.each { |c| FileUtils.cp_r(File.join(ROOT, c), dest, preserve: true) }
end

def run_suite(root, sections)
  Dir.mktmpdir("setup-ci-self") { |tmp| SetupCiSuite.new(root, tmp, out: StringIO.new).run_sections(sections) }
end

# One case against one copy: break, run the sections it names, put the file back. Returns
# [verdict, message, red labels].
def run_case(root, c)
  target = File.join(root, c.file)
  original = File.read(target)
  broken = begin
    c.edit.call(original)
  rescue StandardError => e
    return [:bad, "the break itself failed to apply: #{c.desc} (#{e.message})", []]
  end
  # A break that changed nothing would make the suite pass for the right reason and be reported as
  # decorative; worse, a break that corrupted the file would make it fail for the wrong one. The
  # first is caught here, the second by naming the assertion that has to go red.
  return [:bad, "the break changed nothing: #{c.desc}", []] if broken == original

  begin
    File.write(target, broken)
    red = run_suite(root, c.sections).failures.map(&:label)
  ensure
    File.write(target, original)
  end
  if red.include?(c.expect)
    [:ok, "ok    #{c.sections.join(",")} fails when: #{c.desc}", red]
  elsif red.empty?
    [:bad, "bad   the suite still passed with: #{c.desc}", red]
  else
    [:bad, "bad   `#{c.expect}` stayed green with: #{c.desc} (red instead: #{red.join(" | ")})", red]
  end
end

discover = ARGV.delete("--discover")
jobs = [Etc.nprocessors, 8].min
if (i = ARGV.index("-j"))
  jobs = Integer(ARGV[i + 1], exception: false) or abort("self-test.rb: -j needs a number")
  ARGV.slice!(i, 2)
end
picked = ARGV.map { |a| Integer(a, exception: false) or (warn "self-test.rb: not a case number: #{a}"; exit 2) }
cases = picked.empty? ? CASES.each_with_index.to_a : picked.map { |n| [CASES.fetch(n - 1), n - 1] }

unknown = CASES.flat_map(&:sections).uniq - SetupCiSuite::SECTIONS.keys
abort "self-test.rb: unknown section #{unknown.join(", ")}" unless unknown.empty?

Dir.mktmpdir("setup-ci-self-test") do |scratch|
  # The sanity row: every section, on a clean copy, must pass. Without it a section that fails for
  # its own reasons makes every break aimed at it look caught.
  clean = File.join(scratch, "clean")
  copy_plugin(clean)
  red = run_suite(clean, SetupCiSuite::SECTIONS.keys).failures.map(&:label)
  unless red.empty?
    puts "bad   the unbroken copy already fails: #{red.join(" | ")}"
    puts "", "self-test: 0 ok, 1 bad (nothing below the sanity row can be trusted)"
    exit 1
  end
  puts "ok    the unbroken copy passes every section"

  # Workers, each with its own copy, each taking every jobs-th case. A case restores its file before
  # the next one starts, so a copy is only ever broken in one place at a time.
  slices = cases.group_by.with_index { |_, k| k % jobs }.values
  readers = slices.each_with_index.map do |slice, w|
    reader, writer = IO.pipe
    copy = w.zero? ? clean : File.join(scratch, "copy-#{w}").tap { |d| copy_plugin(d) }
    pid = fork do
      reader.close
      results = slice.map { |c, n| [n, run_case(copy, c)] }
      Marshal.dump(results, writer)
      writer.close
      exit!(0)
    end
    writer.close
    [pid, reader]
  end
  results = readers.flat_map do |pid, reader|
    data = reader.read
    Process.wait(pid)
    data.empty? ? [] : Marshal.load(data) # rubocop:disable Security/MarshalLoad
  end.sort_by(&:first)

  missing = cases.map(&:last) - results.map(&:first)
  bad = missing.size
  missing.each { |n| puts "bad   case #{n + 1} never reported: #{CASES[n].desc}" }
  results.each do |n, (verdict, message, red_labels)|
    bad += 1 if verdict == :bad
    puts "#{format("%2d", n + 1)} #{message}"
    red_labels.each { |l| puts "        red: #{l}" } if discover
  end

  puts "", "self-test: #{results.size - results.count { |_, (v, _, _)| v == :bad } + 1} ok, #{bad} bad"
  exit(bad.zero? ? 0 : 1)
end
