---
# § 05: does every crossing into unchanged code really happen? This is the check CLAUDE.md asks a
# person to make on every run — open the entries and confirm the cited file consumes the changed
# thing — and the one where a page is most expensively wrong. The model is pinned for the reason
# what-changed.md gives: changing it, or any byte of the instrument, invalidates calibration.
model: claude-opus-5-5
parts: [attention, impact]
criteria:
  - >-
    EVERY AFFECTED NODE IS A REAL CONSUMER. For each `.ip-aff` node in every impact path, and each
    entry in the *Affected, not changed* list beneath the figure, open the cited lines. They are the
    code the node or entry names, and that code really reads, calls, writes or relies on the changed
    thing the way the node's description and the entry's clause say. A locator on code that does
    not touch the changed thing fails.
  - >-
    EVERY EDGE IS TRUE. Each hop's causal verb (`.ip-rel` — called by, reads, causes, ignored by and
    the like) states a relation the code really has between the node before it and the node it
    introduces, and the path ends at a behaviour that really follows. A verb claiming a call, a read
    or a write the code does not perform fails, even when the path's conclusion is right.
  - >-
    AFFECTED MEANS UNCHANGED. Every `.ip-aff` node and every entry under *Affected, not changed* sits
    in a file the diff does not touch (`git diff --name-only {{BASE}}...{{HEAD}}`), and is there
    because the change altered what that code does or means. A file the diff changed, listed as
    affected, fails.
  - >-
    A CARD'S WHY ORIENTS AND POINTS. Each `p.ip-why` says in a sentence or two what a user or
    operator would observe, and points at the checkpoint that judges it. It does not walk the path's
    hops in prose — the figure beneath it draws them — and it does not re-explain the checkpoint.
---
You are grading one section of a Review Map: an HTML page that explains a pull request to the
person about to review it. You grade **the page, never the pull request**. Whether the change is
good is not your question and nothing you write may answer it.

The section is **§ 05, Impact outside the diff**: `<section id="impact">`. It holds one to three
impact paths in `figure.impact`, one per `.ip-card`. A path is an `ol.ip-path` of nodes: it starts
in code the PR changed (`.ip-chg`), passes through at least one unchanged consumer whose meaning
the change altered (`.ip-aff`, *affected, not changed*), and ends at an observable behaviour
(`.ip-out`). Every hop after the first carries its incoming relation as a causal verb in
`.ip-rel`, and each code node carries its citation as an `a.path.ip-loc`.

**A verb reads from the node above to the node below**: *`A` — read by — `B`* means B reads A,
and *`A` — receives — `B`* means A receives what B sends. The vocabulary has passive forms for that
reason. A relation may cross a boundary — an HTTP request, a component argument, a cache — when it
holds through it: the endpoint whose parser reads a request body *receives* the client that sends it.
Judge each verb in that direction, and fail it when the relation does not hold, or holds the other
way round. Above each path, a
`p.ip-why` orients and points at the checkpoint in § 03 that judges it. Below the figure, the
*Affected, not changed* list gives each affected entry one citation, one clause and a pointer.

## Where things are

- The whole page: `{{PAGE}}`. Read it if you need context, but grade only § 05.
- § 03 and then § 05, cut out of the page: `{{SECTION}}`. § 03 is there so you can tell what a
  card's pointer lands on and what its checkpoint already says.
- The repository is your working directory, checked out at the pull request's head `{{HEAD}}`.
  The base is `{{BASE}}`. `git diff {{BASE}}...{{HEAD}}`, `git log {{BASE}}..{{HEAD}}` and
  `git show` are available, as are Read, Grep and Glob.

**Open every cited file.** A citation is a URL whose path and `#L…`/`R…` fragment name a file and a
line range; the visible text beside it says the same in `path:start-end` form. Whether a consumer
consumes is a fact about the code, and a verdict reached from the node labels alone is a second
opinion about prose.

## Criteria

{{CRITERIA}}

## How to answer

Three verdicts, and the third one is not a failure of nerve:

- `pass` — every instance the criterion covers meets it, and you checked each one.
- `fail` — at least one does not; `evidence` quotes the node, edge or entry and cites the
  `file:line` that contradicts it.
- `unclear` — you cannot tell, including when you cannot tell what the criterion is asking of
  this particular page. Say why in `why`. A guessed verdict is worse than an honest gap, because
  it survives into a number.

If a criterion itself is the problem — it is ill-posed for this pull request, or the section is
right in a way the criterion would punish — say so in `notes`. That field is read before the
verdicts are.

Reply with **one JSON object and nothing else** — no prose around it, no code fence:

{"verdicts": [{"n": 1, "verdict": "pass|fail|unclear", "evidence": "…", "why": "…"}, …], "notes": ""}

One entry per criterion, `n` counting from 1, in the order above.
