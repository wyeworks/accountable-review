#!/bin/sh
# self-test.sh — the checks, checked.
#
# A check script that always passes is worse than no check script: it turns an unchecked
# rule into one the reader believes is checked. Every fragment in ../golden plants exactly
# one defect, and the table below says what each check is supposed to say about it.
#
# No model, no fixtures, about a second. That is why it belongs in CI next to
# `claude plugin validate`.
#
#   script | golden fragment | expected exit | a substring the output must contain | extra args
#
# Expected exit is 0 or 1. A WARN is not a failure, so a fragment that only warns expects
# 0 and is pinned by its substring instead.
#
# The fifth column is optional and exists for a check that needs more than a fragment. @GOLD@
# expands to the golden directory, so searches.sh can be handed a repository to search: it is
# the one check whose rule is a relation between the page and a repo, and a check that can only
# SKIP here is exactly what this file exists to prevent. It also carries --level for a fragment
# produced at the skill's brief detail level, and --page for a rule that only holds on a whole
# page — the same fragment is then named twice, in column two and after --page.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EVALS=$(dirname "$HERE")
GOLD=$EVALS/golden

pass=0; fail=0

run_case() {
  script=$1; fragment=$2; want_exit=$3; want_text=$4; extra=$5
  # Trim the column padding. It used to be harmless, because want_text ran to end of line; with
  # a fifth column it ends at a "|" and carries the spaces before it, so an untrimmed substring
  # matches nothing and every row with extra args fails for a reason that is not about the check.
  want_text=$(printf '%s' "$want_text" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  extra=$(printf '%s' "$extra" | sed "s|@GOLD@|$GOLD|g")
  # Unquoted on purpose: the column is a short argument list, not one argument.
  out=$(CHECK_TALLY=0 "$HERE/$script" --fragment "$GOLD/$fragment" $extra 2>&1) && got=0 || got=$?
  problem=
  [ "$got" = "$want_exit" ] || problem="exit $got, wanted $want_exit"
  case $out in
    *"$want_text"*) : ;;
    *) problem="${problem:+$problem; }no line matching \"$want_text\"" ;;
  esac
  if [ -z "$problem" ]; then
    pass=$((pass + 1)); echo "ok    $script  $fragment"
  else
    fail=$((fail + 1)); echo "BAD   $script  $fragment — $problem"
    echo "$out" | sed 's/^/        /'
  fi
}

while IFS='|' read -r s f e t x; do
  case $s in ''|\#*) continue ;; esac
  run_case "$(echo "$s" | tr -d ' ')" "$(echo "$f" | tr -d ' ')" "$(echo "$e" | tr -d ' ')" "$t" "$x"
done <<'CASES'
diagram.sh          | diagram-clean.html            | 0 | labels fit their boxes
diagram.sh          | diagram-literal-colour.html   | 1 | is a literal colour
diagram.sh          | diagram-offcanvas.html        | 1 | outside the 880x200 viewBox
diagram.sh          | diagram-invented-class.html   | 1 | is not in the template vocabulary
diagram.sh          | diagram-label-overflow.html   | 0 | likely spills
diagram.sh          | diagram-no-legend.html        | 1 | reads as deleted
diagram.sh          | diagram-placeholder.html      | 1 | survives inside the diagram
diagram.sh          | diagram-unwrapped.html        | 1 | is not inside .scroller
diagram.sh          | diagram-edge-label-collision.html | 0 | runs under a box
behaviour-flows.sh  | flows-clean.html              | 0 | no flow is grouped by directory
behaviour-flows.sh  | flows-layer-grouped.html      | 1 | is a layer name
behaviour-flows.sh  | flows-unit-no-understand.html | 1 | has no things-to-understand
behaviour-flows.sh  | flows-unit-uncited.html       | 1 | makes claims with no file:line
behaviour-flows.sh  | flows-source-only.html        | 0 | no flow shows the hunk its behaviour turns on
behaviour-flows.sh  | flows-unit-flattened.html     | 1 | outside a dl.rows
behaviour-flows.sh  | flows-decisions-interleaved.html | 1 | belongs after the closing
behaviour-flows.sh  | flows-blast-rows.html         | 0 | every field row is inside a dl.rows
behaviour-flows.sh  | flows-pending-page.html       | 0 | section 2 is still pending | --page @GOLD@/flows-pending-page.html
behaviour-flows.sh  | flows-stubs-only-page.html    | 0 | every flow is still a stub | --page @GOLD@/flows-stubs-only-page.html
behaviour-flows.sh  | flows-partial-page.html       | 0 | every dl.rows is introduced by a .mech block | --page @GOLD@/flows-partial-page.html
blast-radius.sh     | blast-clean.html              | 0 | point into the flows that explain them
blast-radius.sh     | blast-readorder.html          | 1 | the reading order lives in section 3
blast-radius.sh     | blast-no-pointer.html         | 0 | an in-page anchor works at every link rung
blast-radius.sh     | blast-pointer-restated.html   | 1 | carry more than one citation
searches.sh         | searches-clean.html           | 0 | reachable from a recorded search | --repo @GOLD@/searches-repo
searches.sh         | searches-unreachable.html     | 1 | reachable from no recorded search | --repo @GOLD@/searches-repo
searches.sh         | searches-bre-dialect.html     | 0 | reachable from a recorded search | --repo @GOLD@/searches-repo
searches.sh         | searches-git-grep.html        | 0 | reachable from a recorded search | --repo @GOLD@/searches-repo
searches.sh         | searches-clean.html           | 0 | needs --repo to re-run
start-here.sh       | start-here-clean.html         | 0 | each with a why
start-here.sh       | start-here-no-why.html        | 1 | is not a reading order
start-here.sh       | start-here-two-lists.html     | 1 | it is one list
before-approving.sh | approving-clean.html          | 0 | within the cap of 5
before-approving.sh | approving-six-questions.html  | 1 | the cap is 5
# The brief detail level, where sections 4 to 7 are one section. The first three rows are
# the level's own rule (the checkpoint belongs to --full); the last two are the ones that
# matter more, because they pin that the merge did NOT need a flag: blast-radius.sh and
# page-invariants.sh read the merged section through the anchors it kept, unchanged.
before-approving.sh | approving-brief-clean.html      | 0 | right at --brief | --level brief
before-approving.sh | approving-brief-checkpoint.html | 1 | the checkpoint belongs to --full | --level brief
before-approving.sh | approving-brief-no-anchor.html  | 1 | carries it on its last | --page @GOLD@/approving-brief-no-anchor.html --level brief
# And the sharpened version of those last two. approving-brief-clean.html pins the merged SHAPE,
# and passed the citation rule only because it happens to carry one <a class="cite">; a real
# --brief page cites section 4 with a.path and carries none, so the rule counted the <li> under
# "Before approving" as uncited section-4 entries and failed a correct page. This row pins the
# condition rather than the shape.
blast-radius.sh     | blast-brief-uncited.html        | 0 | citations present alongside the lists | --level brief
blast-radius.sh     | approving-brief-clean.html      | 0 | no reading order here | --level brief
page-invariants.sh  | approving-brief-clean.html      | 0 | data-path is only on ledger rows | --level brief
page-invariants.sh  | invariants-clean.html         | 0 | no severity chips
page-invariants.sh  | invariants-severity-chip.html | 1 | severity chips reintroduced
page-invariants.sh  | invariants-verdict.html       | 1 | verdict language found
page-invariants.sh  | invariants-risk-score.html    | 1 | graded noun asserted rather than refused
page-invariants.sh  | invariants-risk-score-leading.html  | 1 | graded noun asserted rather than refused
page-invariants.sh  | invariants-risk-score-trailing.html | 1 | graded noun asserted rather than refused
page-invariants.sh  | invariants-clean.html        | 0 | no asserted risk or severity score
page-invariants.sh  | invariants-assurance.html    | 1 | assurance language
page-invariants.sh  | invariants-draft-narration.html | 1 | narrates its own drafting
page-invariants.sh  | invariants-no-tier.html       | 1 | no evidence tier labels
page-invariants.sh  | invariants-loose-data-path.html | 1 | outside a ledger cell
excerpts.sh         | excerpt-clean.html            | 0 | collapsed by default
excerpts.sh         | excerpt-open.html             | 1 | open by default
excerpts.sh         | excerpt-duplicate.html        | 1 | same range is excerpted more than once
rails-anchors.sh    | anchors-clean.html            | 0 | all from the catalogue            | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-uncatalogued-url.html | 1 | in neither references/rails-docs.md nor references/elixir-docs.md | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-unpinned-link.html    | 1 | unpinned Rails doc link           | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-mixed-series.html     | 1 | different Rails series            | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-link-alone.html       | 1 | with no file:line beside them     | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-link-in-excerpt.html  | 1 | inside a collapsed excerpt        | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-fabricated-output.html | 1 | looks like its own output        | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-probe-legit-forms.html | 0 | none showing output the run did not observe | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-runner-mutates.html   | 1 | no 'console --sandbox' is named   | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-invented-attribute.html | 1 | absent from the repository      | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-invented-scope.html   | 1 | are not defined in this repository | --repo @GOLD@/searches-repo
# The Elixir arms of the same two rules. anchors-hexdocs-clean.html is the row nothing else
# would have pinned: it carries TWO different package versions on purpose, so a future reader
# who "generalizes" Rails' one-app-one-series rule to hexdocs turns this row red here instead
# of turning a correct Phoenix page red in the field. The wrong-package row pins that the needle
# keeps the package, which is the only reason a right-module-wrong-package 404 fails at all.
rails-anchors.sh    | anchors-hexdocs-clean.html    | 0 | hexdocs link(s) carry a version segment | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-hexdocs-unpinned.html | 1 | unpinned hexdocs link(s)          | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-hexdocs-wrong-package.html | 1 | in neither references/rails-docs.md nor references/elixir-docs.md | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-clean.html            | 0 | needs --repo to ask whether
# The primer callout. The first row is the clean one; the five after it are the rules that
# would otherwise be checked by nothing. The demo rows are the pair worth reading together:
# a demo may carry a result line ONLY because its receiver is not this application's, so one
# rule asks whether the receiver is generic and the other asks whether the block is inside a
# primer at all — without the second, pre.demo is a hole through the fabricated-output rule
# that anything on the page could use.
rails-anchors.sh    | anchors-primer-clean.html     | 0 | quote the manual                  | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-primer-app-symbol.html | 1 | are classes from this repository | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-demo-outside-primer.html | 1 | outside a primer               | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-primer-no-citation.html | 1 | with no file:line beside them   | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-primer-no-link.html   | 1 | carry no documentation link       | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-primer-two-in-flow.html | 1 | more than one primer            | --repo @GOLD@/searches-repo
# The component is not Rails-only — a gem or a client library takes .primer--lib, which is the
# same callout with no mark, no trademark line and a neutral rule. Both failures it guards are
# attributions rather than layout, and neither looks wrong on the page: the logotype on a gem
# primer says the Rails Foundation wrote that gem, and the logotype with no .pr-tm shows someone's
# mark without saying whose. The scaffold row is a REGRESSION rather than a rule — a real eval run
# had `class Post < ApplicationRecord` reported as naming an application class, which made the
# idiomatic generic receiver the hardest one to write.
rails-anchors.sh    | anchors-primer-lib.html       | 0 | quote the manual                  | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-primer-lib-rails-mark.html | 1 | no rubyonrails.org link      | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-primer-no-trademark.html | 1 | no trademark line              | --repo @GOLD@/searches-repo
rails-anchors.sh    | anchors-primer-scaffold-receiver.html | 0 | quote the manual          | --repo @GOLD@/searches-repo
# And the two other scripts a primer passes through, which is where it could break something
# that has nothing to do with it. behaviour-flows.sh must not read a flow with a callout as a
# flattened one, and must NOT let the callout's own citation stand in for the unit's — the
# last row is that regression, and it fails only because the unit census is taken over a copy
# with the primer removed. diagram.sh must not mistake a 34px brand mark for a figure: every
# rule it has is about a figure, and the first one it would fail is "not inside .scroller".
behaviour-flows.sh  | anchors-primer-clean.html     | 0 | every dl.rows is introduced by a .mech block
behaviour-flows.sh  | flows-primer-uncited-unit.html | 1 | makes claims with no file:line
diagram.sh          | anchors-primer-clean.html     | 0 | no diagrams in this input
excerpts.sh         | excerpt-typed-highlight.html  | 1 | hljs- classes are written into the markup
excerpts.sh         | excerpt-diff-lang.html        | 1 | --diff excerpt carries data-lang
# The state tag. A published page carried db/structure.sql:304-313 tagged Unchanged while its
# own ledger listed that path as changed — the generator hard-coded the label, so the one part
# of the block that was not read off the repository was the only part that was false. The first
# row is that page in miniature; the second is the same shape tagged the way the generator tags
# it now, and it is the row that matters, because a rule that fires on every excerpt sitting
# near a ledger would be worse than the defect. The third needs neither ledger nor repository:
# a tag outside the closed vocabulary was typed, whatever the diff says.
excerpts.sh         | excerpt-unchanged-changed-file.html | 1 | the change touches the file
excerpts.sh         | excerpt-at-head.html          | 0 | no excerpt labels a changed file Unchanged
excerpts.sh         | excerpt-typed-tag.html        | 1 | outside the generator's vocabulary
# And the same three when git is asked and CANNOT ANSWER. Both of these rules learn what the
# change touched from a repository, and each read a failure as an answer: the state-tag rule
# tested the exit status of a pipeline ending in `sort`, which succeeds whatever git did, so an
# unresolvable --base produced an EMPTY changed set and a PASS — turning the caught defect two
# rows up into a clean bill of health. The first row below is that: exit 1, not 0, because a
# page with a ledger is still checkable. The second is its clean counterpart under the same
# conditions. The third has no ledger, so there is nothing to fall back on and the rule must
# say so rather than pass vacuously.
#
# The last row is the same defect in page-invariants.sh, which took `git branch -r --contains`
# failing for "no remote contains it" — a false PASS on a page with no permalinks, and a false
# FAIL on one that has them. One row covers both, because the fix answers before either branch
# is reached.
excerpts.sh         | excerpt-unchanged-changed-file.html | 1 | the change touches the file   | --repo @GOLD@/searches-repo --base 0000000000000000000000000000000000000000
excerpts.sh         | excerpt-at-head.html          | 0 | against the page's own ledger | --repo @GOLD@/searches-repo --base 0000000000000000000000000000000000000000
excerpts.sh         | excerpt-typed-tag.html        | 1 | could not be read             | --repo @GOLD@/searches-repo --base 0000000000000000000000000000000000000000
page-invariants.sh  | invariants-clean.html         | 0 | cannot say whether            | --repo @GOLD@/searches-repo --head 0000000000000000000000000000000000000000
CASES

# The judged half has one piece a script can test: reading a verdict file. A tally that reads a
# truncated or fenced file as "no fails" is the same defect as a check that always passes, and it is
# worse here because the number it produces looks like a measurement.
tally() {
  fragment=$1; want_exit=$2; want_text=$3; shift 3
  out=$(CHECK_TALLY=0 "$EVALS/verdict-tally.sh" "$GOLD/$fragment" "$@" 2>&1) && got=0 || got=$?
  problem=
  [ "$got" = "$want_exit" ] || problem="exit $got, wanted $want_exit"
  case $out in
    *"$want_text"*) : ;;
    *) problem="${problem:+$problem; }no line matching \"$want_text\"" ;;
  esac
  if [ -z "$problem" ]; then
    pass=$((pass + 1)); echo "ok    verdict-tally.sh  $fragment"
  else
    fail=$((fail + 1)); echo "BAD   verdict-tally.sh  $fragment — $problem"
    echo "$out" | sed 's/^/        /'
  fi
}

tally verdicts-clean.json     0 "judged: 6 pass, 0 fail, 0 unclear" --expected 6
tally verdicts-mixed.json     0 "judged: 4 pass, 1 fail, 1 unclear" --expected 6
tally verdicts-mixed.json     0 "note on the expectations:"         --expected 6
tally verdicts-short.json     0 "3 verdict(s) for 6 expectation(s)" --expected 6
tally verdicts-fenced.json    0 "judged: 1 pass"                    --expected 1
tally verdicts-prose.json     1 "is not JSON"                       --expected 6
tally verdicts-bad-value.json 0 "carry a value that is not"         --expected 2
tally verdicts-clean.json     0 "6 0 0"                             --counts

# The page-only checks refuse a fragment rather than passing on evidence they do not have.
# That refusal is itself a rule worth pinning: exit 3, and a SKIP line saying why.
for s in completeness.sh build-state.sh; do
  out=$(CHECK_TALLY=0 "$HERE/$s" --fragment "$GOLD/flows-clean.html" 2>&1) && got=0 || got=$?
  case "$got:$out" in
    3:*"needs a whole page"*) pass=$((pass + 1)); echo "ok    $s  refuses a fragment" ;;
    *) fail=$((fail + 1)); echo "BAD   $s  should refuse a fragment (exit 3), got exit $got: $out" ;;
  esac
done

echo
echo "self-test: $pass ok, $fail bad"
[ "$fail" -eq 0 ]
