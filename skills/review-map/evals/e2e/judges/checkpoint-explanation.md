---
# § 03, the half that reads each checkpoint's prose as the reader it is written for: does it explain
# before it asks, stand alone without becoming the investigation, and read complete with its
# supporting evidence shut? Its siblings checkpoint-judgments.md (is each question a judgment?) and
# checkpoint-claims.md (is what it says true?) grade the rest; one judge asked to do all three checks
# each less carefully. The model is pinned for the reason what-changed.md gives: changing it, or any
# byte of the instrument, invalidates calibration.
model: claude-opus-5-5
parts: [changed, context, attention]
criteria:
  - >-
    EXPLAINS BEFORE IT ASKS. Each checkpoint's prose establishes what the system does here, then what
    the change did and why that matters, and only then reaches its review question. This criterion
    is about order within the checkpoint: one that opens on its question, or on an implementation
    identifier before the job it does has been said, fails, even when everything is explained
    further down. Whether a fact the checkpoint needs is in it at all is criterion 2's question.
  - >-
    STANDS ALONE, NEVER EXHAUSTIVE. Read each checkpoint as if you had jumped straight to it from the
    rail. It tells you what it needs of the domain, the code and What changed, and what the unchanged
    callers it reaches now do: a caller whose behaviour bears on the judgment gets its own sentence,
    and callers reached the same way may be a count in a clause, their list in the supporting
    evidence. A checkpoint that leaves a step of its argument to another place fails — a fact the
    reader needs stated only in Context, in another checkpoint, in Impact outside the diff or behind
    a link, or callers cut to a pointer ("see Impact path A"). A pointer to one of those for further
    depth is correct, and passes. The opposite fails too: prose that walks every caller the run
    traced, the framework's internals, or secondary observations that do not change the question.
  - >-
    READS COMPLETE WITH SUPPORTING EVIDENCE SHUT. This criterion is about the split inside one
    checkpoint, between its explanation and its own `details.cp-ev`. With that block closed, the
    explanation and the review question still say what changes the judgment — a test gap, an unknown
    — above the question, never only in a *Look at* clause or a probe. An explanation written as a
    walk through the files its entries cite ("in `a.rb`… then in `b.rb`… then the spec…") fails,
    because it is the evidence retold rather than the behaviour said. A fact left to another section
    of the page is criterion 2's failure, not this one's.
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
settle it and optionally a probe. Everything down to the review question is **the explanation**;
`details.cp-ev` is the proof beneath it.

The reader the explanation is written for is a colleague who knows the stack and not this codebase,
and who may arrive at any checkpoint directly. A checkpoint repeats the little background it needs —
what a concept is, the part of § 01 it turns on — on purpose, so that repetition is correct and is
not one of your failures. § 01, *What changed*, and § 02, *Context* (when the page has one), come
before § 03; read them so you can tell whether a checkpoint leans on them for a step.

These criteria are about **the explanation as reading**: its order, whether it stands alone, and
whether it carries what the reviewer must understand without the evidence opened. Whether each
review question is a judgment is graded by a different judge, and so is whether a claim is true; do
not fail a criterion here for either. Do not count words or paragraphs: a self-contained checkpoint
is often longer than a compressed one, and that is correct.

## Where things are

- The whole page: `{{PAGE}}`. Read it so you know what the other sections say, but grade only § 03.
- § 01, § 02 if the page has one, and then § 03, cut out of the page: `{{SECTION}}`.
- The repository is your working directory, checked out at the pull request's head `{{HEAD}}`.
  The base is `{{BASE}}`. `git diff {{BASE}}...{{HEAD}}`, `git log {{BASE}}..{{HEAD}}` and
  `git show` are available, as are Read, Grep and Glob.

Open the code when a criterion turns on it — whether an unchanged caller's behaviour bears on the
judgment, or whether a traced caller is one the question does not need, is a question about the code
as much as about the prose.

## Criteria

{{CRITERIA}}

## How to answer

Three verdicts, and the third one is not a failure of nerve:

- `pass` — every checkpoint meets the criterion, and you checked each one.
- `fail` — at least one does not; `evidence` names the checkpoint and quotes the words on the page,
  or cites the `file:line` that shows it.
- `unclear` — you cannot tell, including when you cannot tell what the criterion is asking of
  this particular page. Say why in `why`. A guessed verdict is worse than an honest gap, because
  it survives into a number.

If a criterion itself is the problem — it is ill-posed for this pull request, or the section is
right in a way the criterion would punish — say so in `notes`. That field is read before the
verdicts are.

Reply with **one JSON object and nothing else** — no prose around it, no code fence:

{"verdicts": [{"n": 1, "verdict": "pass|fail|unclear", "evidence": "…", "why": "…"}, …], "notes": ""}

One entry per criterion, `n` counting from 1, in the order above.
