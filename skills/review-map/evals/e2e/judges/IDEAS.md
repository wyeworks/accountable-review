# Judges not yet written

**Notes, not code.** `what-changed.md` is the only working judge, on purpose: one judge
calibrated against a gold page tells us whether the method works before the method is copied
six times. Everything below is a candidate, recorded so the next one starts from the real
question rather than from a blank file. `run.rb` and `calibrate.rb` pick up every `*.md` in this
directory except this one, so writing a judge means writing its file, then its gold labels and
defect patches. Nothing in the harness changes.

Each candidate lists what it would grade and what a planted defect for it would look like,
because a judge nobody can plant a defect for can't be calibrated. The rule that applies to
all of them: **grade the page, never the PR.**

## § 02 checkpoints

The one most likely to be wrong, and the most expensive to judge. It probably needs to be two
judges, because one judge asked to check thirty things checks each of them less carefully.

- Each checkpoint is a **judgment, not a category**: a reviewer could answer it by looking at the
  code and could get the answer wrong. *ProjectSearcher implementation*, *Tests* and *Controller
  changes* fail. Defect: retitle a checkpoint as the layer it lives in.
- **The step 7c merge happened.** No two checkpoints are the same question. Defect: split one
  checkpoint into two that share a cause and a decision.
- **The order does not read as a grade.** No number beside a question, no *high* in a title, no
  first checkpoint described as the important one. Defect: insert "the most important" into the
  first explanation.
- **Every *Look at* entry is true.** The cited line shows what the clause says. Defect: shift a
  citation's line range off the line it claims.
- **The coding-decision bar.** At most one coding-decision checkpoint, it cites an in-repo
  precedent, it asks rather than answers, and it never displaces a behavioural judgment. Defect:
  a coding-decision checkpoint with no in-repo citation, or one that recommends the fix.
- **The count scales on the deltas § 01 names**, never on the file count.

## § 02 figures

`figures.rb` holds the shape and the locators. Everything below is what it cannot hold, and the
first item is the one that makes the feature worth having or not.

- **The figure was worth drawing.** A reviewer reading it understands that part of the change faster
  than from the explanation and the diff. Defect: replace a converge with a chain of three files
  joined by arrows, labels and locators intact — still well-formed, and now says nothing a list would
  not.
- **The shape is the judgment's shape.** A converge for an invariant with several writers, a lifecycle
  for an entity with states, and not the reverse. Defect: redraw a converge's paths as a lifecycle's
  states.
- **A converge lists every writer the repository has.** The path it misses is the finding it exists
  for. Defect: delete the `.ip-aff` bypass path and its *Look at* entry; the figure still passes every
  mechanical rule. This one needs `--repo`, because the answer is a search, not a reading.
- **Every edge is true.** Each locator performs the edge or transition it sits on. Defect: move a
  transition's locator to the line above the `update!` it names.
- **Zero was right.** No checkpoint without a figure would have been clearer with one, and no figure
  exists because the PR is large. This is the hardest to grade and the most important to keep: the
  regression is a page that draws more because drawing is now possible.
- **No figure grades.** No *critical* in a `.cv-note`, no figure caption that ranks. `figures.rb`
  warns on the common words; a judge reads the rest.

## § 03 reading path

- It is one list, each stop links into a checkpoint, and the order has reasons.
- A stop re-explains nothing the checkpoint owns. Defect: a `span.why` restating the
  checkpoint's explanation.

## § 04 impact outside the diff

This is the check `CLAUDE.md` tells a person to do on every run, and the strongest reason to
automate one. The judge opens every entry and confirms the cited file really consumes the
changed thing, and that each edge's causal verb is true. Defect: point an `.ip-aff` locator at a
file that doesn't read the value. It also checks that the panel is omitted, not stubbed, when
nothing crosses into unchanged code.

## Evidence and anchors

- The tiers are honest: inference is labelled, and a claim the diff shows carries no label.
- Every excerpt is earned by a load-bearing citation, and the page reads complete with every
  `details` shut, judged field by field.
- Probes can be answered in a fresh checkout, and the label says what the output would settle.
- **On a Phoenix page, zero doc links is expected**, because `elixir-docs.md` is closed. A rubric
  that asks for a doc link fails every correct Phoenix page.

## Voice and economy

- One canonical home: each fact is explained once, and later mentions are a one-sentence
  pointer.
- No assurance, no narrated drafting, and no autobiography in a correction (SKILL.md step 8).
- The page's word total is measured mechanically, not judged, the way `run.rb` already measures
  § 01.

## Recall

This one needs no gold page. Each eval PR in `prs.yml` gets a `reference_judgments` list: what
the PR's **real reviewers** raised in its threads, and what follow-up commits later fixed. The
judge reads the page and says, for each one, whether the page reaches it. **Read the page, don't
grep it.** Two runs against the retired `monolith-guard-chain` fixture scored 14/15 and 12/15 by
grep and 15/15 by reading, because a page that cites a line range instead of a method name is
following the citation rules.

# The eval set (one PR so far)

`prs.yml` has one eval PR, `discourse-44196`, chosen as the calibration PR's sibling. The eval set should be four to
six merged, public PRs of different shapes, none of them the calibration PR:

- a small Rails bugfix
- a migration-heavy Rails change
- a large feature spanning a Rails API and a Next.js client (the boundary seam)
- a Phoenix LiveView change (the `phx-*` to `handle_event` seam)
- a docs-only or trivial PR, where the right output is a refusal
- a multi-commit PR run at `update_from`, then `--update` at head

## What retiring the synthetic fixtures lost, at the whole-run level

Each of these still has its mechanical half in `skills/review-map/tests/run.sh`. What's gone is
a whole run that exercises it.

- **The trivial refusal** (the old `trivial` fixture). A docs-only OSS PR restores it.
- **`--update` refusing on P6** (the old `two-push` fixture): a new consumer in a file no
  checkpoint cites, visible only to the first map's replayed search. An OSS PR with that shape is
  rare, so this may need an `update_from` chosen for it, or it stays covered only mechanically.
- **The Rails 7.1 `insert_all` override path.** It comes back only if an eval repo happens to
  lock 7.1. `verify-catalogue.sh` still proves the URLs.
- **A recall floor from planted answers.** The synthetic fixtures planted findings outside the
  diff, so recall had a written right answer. `reference_judgments` is the replacement, and it's
  weaker: real reviewers miss things too.
