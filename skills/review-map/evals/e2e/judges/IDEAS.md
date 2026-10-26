# Judges not yet written

**Notes, not code.** Six judges exist — `what-changed`, `checkpoint-judgments`,
`checkpoint-claims`, `reading-path`, `impact` and `evidence` — and each is calibrated only once a
person has certified a gold page for it. Everything below is a candidate, recorded so the next one
starts from the real question rather than from a blank file. `run.rb` and `calibrate.rb` pick up
every `*.md` in this directory except this one, so writing a judge means writing its file, then its
gold labels and defect patches. Nothing in the harness changes, except where a candidate below
says otherwise.

Each candidate lists what it would grade and what a planted defect for it would look like,
because a judge nobody can plant a defect for can't be calibrated. Most of them wait on a gold page
that carries their subject: `discourse-43002`'s has no Context, no figure inside a checkpoint, no
coding-decision checkpoint and no probe. The rule that applies to all of them: **grade the page,
never the PR.**

## § 02 context

The question the section exists to answer, and the one only a reader can grade: **could a reviewer
new to this repository follow checkpoint A after reading Context?** The specimen is
discourse#43845, whose first checkpoint asked whether every request creating an email-code account
still passes CAPTCHA and was unfollowable without three things the page never said — signup as a
sequence of requests, CAPTCHA as a plugin wrapping a controller method, and what an approval signup
is. A judge here reads Context and the checkpoints as that reader, and asks:

- **Followable.** Each checkpoint can be understood with only *What changed* and Context in hand.
  Defect: delete the entry a checkpoint relies on most; the page still passes every mechanical rule.
- **What it is, never what the change did.** No entry previews a judgment. Defect: append the
  checkpoint's own claim to the entry it relies on — *"and this PR moved the check to the later
  request"*.
- **Earned, not inventory.** Every entry is a concept a checkpoint needs, not a layer the diff
  touched. Defect: add an entry called *The session controller* that only restates the file's role.
  `start-here.rb` warns on an entry with no checkpoint pointer; a judge catches one that points at
  a checkpoint which never needed it.
- **Absent when it should be.** On a small, domain-obvious change — rubygems.org#6699 is the
  candidate — the page carries little or no Context. Defect: add two entries explaining concepts any
  Rails reviewer of that repository would know.
- **The repository, not the framework.** An entry that explains a Rails rule belongs in a primer
  under `--mentor`. Defect: an entry explaining `before_destroy`.

- **The shift shows the move.** When Context carries `figure.lifecycle.lc-shift`, does it show
  which request moved, is every transition a request a reviewer will meet in the code, and does it
  name the cases it does not draw? `figures.rb` holds the shape — two columns, one moved state at
  different positions — and can say nothing about whether the move drawn is the one the
  checkpoints turn on. Defect: a shift whose moved state is a UI step rather than a request, or
  one with no `ul.lc-cases` on a flow the reviewer's question shows has several.

## § 03 checkpoints, what the two judges leave

`checkpoint-judgments` grades whether each checkpoint is a judgment, asked once, ordered without a
grade and left to the reviewer; `checkpoint-claims` opens every cited line. Four things neither asks:

- **The coding-decision bar.** Each coding-decision checkpoint cites its own precedent — a
  decision in the repository, or a convention on the lens file's closed stack list — asks rather
  than answers, raises nothing the repository has itself settled on, is ranked after every
  behavioural one, and none displaces a behavioural judgment; two that share one precedent should
  have been merged. Defect: a coding-decision checkpoint with no citation from either source, one
  that rests on a convention the lens does not list, or one that recommends the fix. Needs a gold
  page with a coding-decision checkpoint on it.
- **The architectural bar.** Each architectural checkpoint states a shift — before, X was not true;
  at `file:line` it now is — and cites a written decision or a search at both revisions, the base
  half of which reproduces at the merge-base; it asks rather than answers, merges into a behavioural
  judgment that turns on the same lines, and is ranked after every behavioural judgment of a
  behavioural delta. Defect: a precedent an earlier instance falsifies, an edge that existed at the
  base in another file of the module, or *this couples X to Y* with nothing cited. Needs a gold page
  carrying a structural shift.
- **The ranking by delta.** Each delta's class (behavioural or refactor) agrees with the *Change
  shape* chip, a refactor delta leads with its equivalence, and no structural checkpoint precedes a
  behavioural judgment of a behavioural delta; the chip reads behavioural, refactor or mixed and follows
  the class rather than the PR's title; and a behavioural delta that relocates code carries an
  equivalence question for the callers meant not to notice. Defect: a refactor page that opens with
  where a class lives while the notes show a guard reordered; a `DEV:`-titled page whose chip says
  refactor while its own checkpoints describe behaviour that moved.
- **The count scales on the deltas § 01 names**, never on the file count, and **the ceiling on the
  Production bucket**, never on test, generated or docs files. Defect: three more checkpoints on a
  one-delta page — which also plants a merge failure, so it needs a page where the extra checkpoints
  are distinct judgments — or a page past seven whose Production bucket is under the first tier.

## § 03 figures

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

## § 05, what `impact` leaves

- **Omitted, not stubbed.** When nothing crosses into unchanged code the section and its rail entry
  go. Defect: a stub saying nothing reaches unchanged code, on a gold page whose diff crosses
  nothing — `discourse-43002`'s crosses, so a stub there would be false as well as a stub.
- **These are the right paths.** `impact` checks that every edge is true, not that the one to three
  paths drawn are the crossings a reviewer most needs.

## Evidence, what `evidence` leaves

- **Probes** can be answered in a fresh checkout, and the label says what the output would settle.
  Needs a gold page that proposes one.

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

It is the candidate that changes the harness: `judge.rb` hands a judge parts of the page and
nothing else, so `prs.yml` needs the field, `E2E::Pr` needs the member, and the list has to reach
the prompt. The threads have to be fetched into `prs.yml` ahead of time, because the judge has no
network.

# The eval set (one PR so far)

`prs.yml` has one eval PR, `discourse-44196`, chosen as the calibration PR's sibling. The eval set should be five to
eight merged, public PRs of different shapes, none of them the calibration PR:

- a small Rails bugfix
- a migration-heavy Rails change
- a large feature spanning a Rails API and a Next.js client (the boundary seam)
- a Phoenix LiveView change (the `phx-*` to `handle_event` seam)
- a Rust backend change (a migration with compile-time-checked queries, or a route added after an
  auth layer) and a Rust library change (a new variant on a public enum), one per lens
- a Next.js change (a server action that writes data, or a shared component that started reading
  `cookies()`) and a React library change (a component whose props or hook return shape moved), one
  per lens
- a docs-only or trivial PR, where the right output is a refusal
- a multi-commit PR run at `update_from`, then `--update` at head

## What retiring the synthetic fixtures lost, at the whole-run level

Each of these still has its mechanical half in `skills/review-map/tests/run.rb`. What's gone is
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
