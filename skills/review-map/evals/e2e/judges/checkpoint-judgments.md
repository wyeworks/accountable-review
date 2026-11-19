---
# § 03, the half that reads the agenda as a reviewer would: is each checkpoint a judgment, asked
# once, in an order that is not a grade, left for the reviewer to decide? Its siblings
# checkpoint-explanation.md (does the prose explain before it asks?) and checkpoint-claims.md (is
# what it says true?) grade the rest; one judge asked to do all three checks each less carefully.
# The model is pinned for the reason what-changed.md gives: changing it, or any byte of the
# instrument, invalidates calibration.
model: claude-opus-5-5
parts: [changed, attention]
criteria:
  - >-
    A JUDGMENT, NOT A CATEGORY. Each checkpoint's review question — the `p.open` labelled *Review
    question*, last in its explanation — is a question a reviewer could answer by reading the code and
    could get wrong. A question with nothing to decide in it ("Is the controller change correct?",
    "Review the tests") fails. Its `<h3>` names the behaviour the checkpoint is about; a heading that
    names a place instead — a layer, a directory, a file, a class, "Tests", "Controller and model
    changes" — fails too, because the rail and the reading path name the checkpoint by that heading.
    A heading that is a behaviour and not a question is correct, and passes.
  - >-
    ONE JUDGMENT, ASKED ONCE. No two checkpoints are the same question. Two checkpoints that share a
    cause and would be settled by the same decision should have been one checkpoint, and fail this
    criterion. Two that cite the same file or line but ask the reviewer to decide different things
    are distinct, and pass.
  - >-
    THE ORDER IS NOT A GRADE. Checkpoints are ordered, and nothing turns the order into a scale: no
    number or severity word beside a question, no "high", "critical" or "blocking", no checkpoint
    described as the most important, the main one, or the one to read if you read only one. A
    sentence saying the checkpoints are ordered by what would cost most to misread states the
    ordering rule, and passes.
  - >-
    ASKS, DOES NOT ANSWER. Each checkpoint explains what changed and what follows from it, and leaves
    the decision to the reviewer. It does not pronounce the behaviour a bug or correct, does not
    prescribe the fix, and does not recommend approving or blocking the change. A GAP naming what
    the tests leave open, or a review question only the author can settle, is not an answer.
---
You are grading one section of a Review Map: an HTML page that explains a pull request to the
person about to review it. You grade **the page, never the pull request**. Whether the change is
good is not your question and nothing you write may answer it.

The section is **§ 03, What needs your attention**: `<section id="attention">` and the checkpoints
inside it, each a `<section class="cp">`. A checkpoint is one judgment the reviewer has to make. In
order: an `<h3>` naming the behaviour; prose explaining the situation, the change and what follows,
which may hold one figure and one inline code snippet; optionally a `div.gap`, labelled *GAP*, naming
what the tests leave open; the `p.open` labelled *Review question*, always, last in the explanation;
and `details.cp-ev`, shut, labelled *Supporting evidence*, holding a *Look at* list of the lines that
settle it and optionally a probe. § 01, *What changed*, comes before it and names the independent
changes the PR makes; read it so you know what the agenda is about.

These criteria are about **the agenda's shape and voice**: whether each checkpoint is a judgment,
whether two are one, whether the order grades, whether a checkpoint answers its own question.
Whether its prose explains before it asks is graded by a different judge, and so is whether its
claims are true; do not fail a criterion here for either.

## Where things are

- The whole page: `{{PAGE}}`. Read it so you know what the other sections say, but grade only § 03.
- § 01 and then § 03, cut out of the page: `{{SECTION}}`.
- The repository is your working directory, checked out at the pull request's head `{{HEAD}}`.
  The base is `{{BASE}}`. `git diff {{BASE}}...{{HEAD}}`, `git log {{BASE}}..{{HEAD}}` and
  `git show` are available, as are Read, Grep and Glob.

Open the code when a criterion turns on it — whether two checkpoints share a cause is a question
about the code as much as about the prose. Do not count checkpoints or words: neither is one of
your criteria.

## Criteria

{{CRITERIA}}

## How to answer

Three verdicts, and the third one is not a failure of nerve:

- `pass` — the section meets the criterion, and you checked.
- `fail` — it does not; `evidence` quotes the words on the page or cites the `file:line` that
  shows it.
- `unclear` — you cannot tell, including when you cannot tell what the criterion is asking of
  this particular page. Say why in `why`. A guessed verdict is worse than an honest gap, because
  it survives into a number.

If a criterion itself is the problem — it is ill-posed for this pull request, or the section is
right in a way the criterion would punish — say so in `notes`. That field is read before the
verdicts are.

Reply with **one JSON object and nothing else** — no prose around it, no code fence:

{"verdicts": [{"n": 1, "verdict": "pass|fail|unclear", "evidence": "…", "why": "…"}, …], "notes": ""}

One entry per criterion, `n` counting from 1, in the order above.
