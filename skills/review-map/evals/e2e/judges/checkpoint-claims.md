---
# § 03, the half that opens every cited line: is what each checkpoint says about the code true?
# Its sibling checkpoint-judgments.md grades the agenda's shape. The model is pinned for the reason
# what-changed.md gives: changing it, or any byte of the instrument, invalidates calibration.
model: claude-opus-5-5
parts: [attention]
criteria:
  - >-
    EVERY LOOK AT ENTRY IS TRUE. For each entry in a `ul.lookat`, open the lines it cites — the
    `a.path`'s range, or, for an entry carrying an excerpt, the excerpt's location. Those lines show
    what the entry's title and clause say they show. A citation whose range misses the thing it
    names — the right file, the wrong lines — fails, and so does a clause the lines contradict.
  - >-
    EVERY EXPLANATION IS TRUE. Each factual claim a checkpoint's explanation paragraph makes about
    what the code does, at head against the base, is true. Open the files. A claim carrying an
    evidence tier is held to what that tier admits: an `inferred` claim passes when it is a
    defensible inference from the code, and fails only when the code contradicts it.
  - >-
    EVERY STATED ABSENCE IS TRUE. A GAP saying no test covers something, an Open question saying
    something could not be established, and any sentence saying that nothing reads, calls or tests
    a thing — each is true of the repository at head. Search for the test or the reader it says is
    missing (`git grep`, Grep) before you pass it.
---
You are grading one section of a Review Map: an HTML page that explains a pull request to the
person about to review it. You grade **the page, never the pull request**. Whether the change is
good is not your question and nothing you write may answer it.

The section is **§ 03, What needs your attention**: `<section id="attention">` and the checkpoints
inside it, each a `<section class="cp">`. A checkpoint is one judgment the reviewer has to make —
an `<h3>` question, a short explanation, a *Look at* list of the lines that settle it (title,
clause, citation), and optionally a figure, a GAP (a stated absence) and an Open question.

These criteria are about **truth**: whether what each checkpoint says about the code is so. Whether
a checkpoint is well-posed, merged or ordered is graded by a different judge; do not fail a
criterion here for that.

## Where things are

- The whole page: `{{PAGE}}`. Read it if you need context, but grade only § 03.
- § 03, cut out of the page: `{{SECTION}}`.
- The repository is your working directory, checked out at the pull request's head `{{HEAD}}`.
  The base is `{{BASE}}`. `git diff {{BASE}}...{{HEAD}}`, `git log {{BASE}}..{{HEAD}}` and
  `git show` are available, as are Read, Grep and Glob.

**Settle each claim by opening the file it is about.** A citation is a URL whose path and
`#L…`/`R…` fragment name a file and a line range: a `/blob/<sha>/` link names the file at that
commit, and a `/pull/<n>/files#diff-…R<a>-R<b>` link names lines `a`–`b` of the file at head. The
visible text beside it says the same in `path:start-end` form. A verdict reached by reading the page
alone is a second opinion about prose, and that is not what is being asked.

## Criteria

{{CRITERIA}}

## How to answer

Three verdicts, and the third one is not a failure of nerve:

- `pass` — every instance the criterion covers meets it, and you checked each one.
- `fail` — at least one does not; `evidence` quotes the words on the page and cites the
  `file:line` that contradicts them.
- `unclear` — you cannot tell, including when you cannot tell what the criterion is asking of
  this particular page. Say why in `why`. A guessed verdict is worse than an honest gap, because
  it survives into a number.

If a criterion itself is the problem — it is ill-posed for this pull request, or the section is
right in a way the criterion would punish — say so in `notes`. That field is read before the
verdicts are.

Reply with **one JSON object and nothing else** — no prose around it, no code fence:

{"verdicts": [{"n": 1, "verdict": "pass|fail|unclear", "evidence": "…", "why": "…"}, …], "notes": ""}

One entry per criterion, `n` counting from 1, in the order above.
