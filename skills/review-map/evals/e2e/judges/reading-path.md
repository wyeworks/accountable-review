---
# § 04: is the reading path a route through the code that points at the agenda rather than
# repeating it? The model is pinned for the reason what-changed.md gives: changing it, or any
# byte of the instrument, invalidates calibration.
model: claude-opus-5-5
parts: [attention, start]
criteria:
  - >-
    EVERY STOP POINTS WHERE ITS CODE IS JUDGED. Each stop's `a.ptr` names a checkpoint that exists
    on the page, and the stop's code is code that checkpoint's judgment turns on — cited in it, or
    what its explanation is about. A stop sent to a checkpoint that never concerns its code fails.
    Every checkpoint is reachable from the list: a stop points at it, or a stop's why names it.
  - >-
    THE ORDER HAS REASONS. The stops are ordered by conceptual dependency — the schema before the
    code that trusts it, what a later stop needs before that stop — not by the diff, the alphabet or
    the layer. Nothing a stop says contradicts where it sits: a stop whose why says it depends on
    the stops above it, placed first, fails.
  - >-
    A STOP POINTS, IT DOES NOT RE-EXPLAIN. Each `span.why` says, in about one sentence, what this
    code establishes for what comes next, or what on it needs judgment. A why that restates its
    checkpoint's explanation — the mechanism, the consequence, the decision the reviewer is asked to
    make — fails: the checkpoint is where that is said, and the stop points at it.
  - >-
    WHAT A STOP SAYS IS TRUE. Every factual claim a `span.why` makes about the code — what a file
    holds, who calls it, what it decides — is true at head. Open the file.
---
You are grading one section of a Review Map: an HTML page that explains a pull request to the
person about to review it. You grade **the page, never the pull request**. Whether the change is
good is not your question and nothing you write may answer it.

The section is **§ 04, Read the code in this order**: `<section id="start">`, an `ol.begin` of a
few stops. Each stop is a place in the code with its citation, a `span.why` saying why to read it
here, and an `a.ptr` pointing at the checkpoint it belongs to. It is the moment the reviewer opens
the code, having read the judgments in § 03, *What needs your attention*; it is a route, not an
index of § 03, and it never explains a judgment the checkpoint already explains.

## Where things are

- The whole page: `{{PAGE}}`. Read it if you need context, but grade only § 04.
- § 03 and then § 04, cut out of the page: `{{SECTION}}`. § 03 is there so you can tell where a
  pointer lands and what its checkpoint already says.
- The repository is your working directory, checked out at the pull request's head `{{HEAD}}`.
  The base is `{{BASE}}`. `git diff {{BASE}}...{{HEAD}}`, `git log {{BASE}}..{{HEAD}}` and
  `git show` are available, as are Read, Grep and Glob.

**Settle each claim by opening the file it is about.** Do not count stops or words: neither is one
of your criteria.

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
