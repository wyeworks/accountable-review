# Re-running over new commits

Read this file only when the invocation carries `--update`, before acting on the flag. The step
numbers are `SKILL.md`'s; everything not named here runs as `SKILL.md` says.

`--update` says a page for this target already exists where this run would write, so read the
commits since the revision that page names and edit it in place. A pull request that keeps moving
through review then keeps a map that describes it, without a full run per push.

**What is bought, and what it is paid for with.** The saving is almost entirely step 5 — tracing
consumers across the diff is where the minutes and the tokens go, and an update traces only what
the new commits reach. The price is that every carried claim is a claim nobody re-read. That is the
whole trade, it is the only one, and `report-format.md` § *Build state* § *An updated page* is how
the reader is told about it.

**Read `references/report-format.md` § *Build state* § *An updated page* before writing anything.**
It owns the masthead line, the one disclosure sentence and the three refusals that keep an update
from becoming a level.

## First, decide whether this can be an update at all

Four checks are yours, because none of them can be recovered from a page. Do them before anything
else, and on any disagreement run fully and say so in chat:

- **The settings match the previous run.** Effort, mentor, context and impact — as step 1 resolved
  them, from a flag or from the file — are invisible on the page by design, so nothing can read them
  back off it. An update under different settings would produce a page half of which was written to
  different rules, and an `.accountable-review.yml` changed in the delta is a reason to run fully.
- **The stack is the one the page was written for**, per step 2.
- **The rung is the one step 1 just resolved.** The rung decides whether anything on the page is
  clickable, so a change in it rewrites every citation and there is nothing to carry.
- **The repository and the target are the same ones.**

Then the mechanical half, which is a script because by eye every checkpoint looks carryable — the
same reason `ledger-rows.sh` and `diff-render.sh` exist:

**The revision the page names** is the first seven-character hex token in its masthead `Revision`
cell — one targeted `grep`, not a read of the page — resolved with `git rev-parse` to the full SHA
the script wants:

```sh
PREV=$(git rev-parse "$(grep -o 'class="path"[^>]*>[0-9a-f]\{7\}' "<previous page>" \
  | head -n 1 | grep -o '[0-9a-f]\{7\}$')")
```

```sh
<skill base directory>/scripts/carry-plan.sh <previous page> \
  --prev-head "$PREV" --base BASE --head HEAD
```

It prints a plan and **exit 0**, or a reason and `verdict: full` and **exit 3**. A full verdict is
not an error and not something to argue with: run the whole procedure from step 2, and say in one
line which reason it gave. The reasons are the preconditions the script owns — the branch was
rebased or force-pushed, the base moved under the page, the page is a draft or a stopped run, the
delta is more than half the diff, a lock file moved, or a recorded search now finds a delta path.

**That last one is the one to understand rather than just obey.** Affected-but-unchanged code is
what this page is for, so the dangerous change is a new consumer appearing in a file *no checkpoint
cites* — invisible to any rule about what a checkpoint cites. The searches the previous page
recorded are the only thing that can see it, so the script replays them; a delta path among their
hits means these commits reached code the page reasoned about, and that is step 7's work rather
than an update's. It is also what keeps a `figure.converge` honest across pushes: the writer search
that earned it is one of those recorded searches, so a new writer of its invariant refuses the update
rather than leaving a figure that claims to list every path and no longer does.

## The plan, and what each row means

```
delta     app/queries/active.rb          the paths the new commits touched
cp        cp-a   carry   -               no delta path appears inside that checkpoint
cp        cp-b   redo    cites app/...   it does, so the judgment is re-derived
ctx       Approval signup  redo  cites app/...   a Context entry's one citation moved, so its *is* is re-read
ctx       lc-shift         carry -               the before-and-after figure, when Context draws one
excerpt   app/queries/active.rb  regen   quoted from a file the delta moved
excerpt   app/models/project.rb  keep    quoted from one it did not
```

**Carrying is about not re-tracing. It is not about freezing the agenda**, and confusing the two is
how an update goes wrong in the direction that looks tidy. A `carry` row means you do not re-open
that checkpoint's files. It does not mean the checkpoint survives untouched: step 7 still ranks the
whole agenda, and a new observation may merge into a carried checkpoint — at which point it is no
longer carried and goes through step 8 like anything else.

## The steps

| Step | On an update |
|---|---|
| 2 · Discover the project | **In full.** A few existence checks and two lock-file reads; a push can bump Rails |
| 3 · Inventory the diff | **In full**, over `BASE...HEAD`. The gate depends on it |
| 4 · Derive what changed | **Narrowed**: ask only whether the delta moves the semantic delta or a stated limit. The metric strip is recomputed from step 3 |
| 5 · Trace | **Narrowed to the delta.** No re-tracing of carried flows. This is the whole saving |
| 6 · Notes and falsifiers | **Narrowed**: notes for delta-touched flows only, falsifiers only at those notes, cap of six unchanged |
| 7 · Synthesise | 7a re-asked cheaply; 7b and 7c over delta candidates only; **7d re-ranks the whole agenda** and **7e enforces the caps over the whole agenda**; 7f–7j for touched checkpoints only; **7k over the whole agenda**, re-opening only the entries and figure the plan marks `redo`. *Read the code in this order* is rewritten whole if the agenda moved at all |
| 8 · Verify | **In full and unconditionally, for everything written or re-derived.** Never for carried material |
| 9 · Write | `Edit`s only. No skeleton, no banner, `Revision` cell last |
| 10 · Complete and gate | **In full, always** |

Step 7d is cheap and is never skipped: ranking is reasoning over a handful of one-line questions
with no file reads. An update that appended its new checkpoints to the end instead would have
turned a ranked agenda into a changelog, which is the failure this table exists to prevent.

Step 7k is whole for 7d's reason: its input is the finished agenda, and the agenda was re-ranked
whole. Reading the checkpoints for what they assume costs no file reads. The exception is an entry
the plan marks `redo` — its one citation is in the delta, so what it says the thing *is* may no
longer be true, and that file is opened before the entry is kept. Everything else follows from the
four conditions in `references/report-format.md` § *Section 2*, applied to the agenda as it now
stands: an entry whose every checkpoint was deleted goes; an entry a redone checkpoint now explains
in its own clause goes, because condition 2 fails; a new or redone checkpoint may earn an entry the
previous page did not have; and five is still the cap over the whole section.

The before-and-after figure is decided the same way and has its own plan row, `lc-shift`. Marked
`redo`, a transition it draws cites a file the delta moved, so its columns are re-derived from the
lines rather than kept. Carried or not, it stands only while two or more checkpoints still turn on
the sequence: below two it leaves Context, and the one checkpoint left relying on it takes the
sequence in its own figure slot, which makes that checkpoint re-derived rather than carried.

Step 5's narrowing is the one place to be honest with yourself. The delta is the set of files the
new commits touched, and tracing what *those* reach is the work — not re-confirming what the
previous map already traced.

## Writing it

- **`page-skeleton.sh` is not called.** There is a page already. It refuses with exit 3 on a page
  that has content, and **a run that hits that refusal during an update has lost the page it meant
  to edit — stop and regenerate deliberately, never `--force`.**
- **No build banner and no pending markers, at any point.** The page is complete at every instant
  of an update. There is no state for *being updated*: a banner would risk being left behind, and
  `ci/generate-review-map.sh` refuses to deliver a page still carrying one.
- **The `Revision` cell is the last edit of the run.** Until it changes, the page honestly names
  the revision it still mostly describes — and if the update dies halfway, the page fails the CI
  adapter's check that it names its head rather than being delivered as a current map of an old
  revision. Add the disclosure sentence to *What changed* in the same edit.
- **A checkpoint the new commits answered is deleted**, with its reading-path stop and its rail
  entry, and nothing marks where it was. `report-format.md` § *The review checkpoint* owns that
  rule. **Its pointer goes with it**: every `span.ctx-used` that named it drops that link, and a Context entry left
  naming no checkpoint is deleted, because a pointer at an id the page no longer carries is an entry
  this page did not earn. The before-and-after figure's caption pointer loses it the same way.
- **Sections 02 and 05 may need adding rather than filling, and 02 may need removing.** If the
  previous page omitted 05 and the delta now crosses into unchanged code, or omitted 02 and step 7k
  now earns an entry, the section and its rail entry are new — 05 inside its fold at `--impact
  collapsed` — and omitted is not pending, so there is
  no stub to replace. These are the places an update writes where the page does not already carry a
  marker. The reverse is 02's alone: when step 7k leaves no entry standing, the section and its rail
  entry are deleted rather than emptied, since a Context with no entries is a stub saying the change
  needs none.
- **Every excerpt the plan marks `regen` is regenerated**, in one `excerpt.sh` call with any new
  ones. `report-format.md` § *Source excerpts* says why a carried one is the component's single way
  of lying.
- **Do not read the whole page.** `grep -n` for the checkpoint ids, the questions and the citations
  to build an index, then `Read` with `offset` and `limit` only the ranges you are re-deriving. An
  80 KB page is about 25,000 tokens, and reading it whole is the same defect as re-`Write`ing it,
  pointed the other way.

## Finishing

Step 10 is unchanged and none of it is narrowed. The inventory is regenerated whole with
`ledger-rows.sh --paths-only` and the block replaced — never hand-edited, never patched with the
new rows — and `coverage-gate.sh` runs against the finished page over the full `BASE...HEAD` range.
An update changes which claims were re-read; it changes nothing about which paths must be
accounted for.

Then say in chat what the update did: the delta, how many checkpoints were re-derived, and that a
run without `--update` re-reads the whole diff. That belongs in chat and not on the page, for the
reason `report-format.md` § *Build state* gives.
