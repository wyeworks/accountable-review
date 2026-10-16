---
# Evidence across the page: is no claim stated as more than it is, is nothing the diff shows
# labelled, is every untouched line of a changed file cited, is every excerpt earned, and does the
# page read complete with every collapsed block shut? The first is the truth criterion, and the
# three tier rules are three criteria so that one mis-tier among forty claims fails the one rule it
# breaks and not all of them. The model is pinned for the reason what-changed.md
# gives: changing it, or any byte of the instrument, invalidates calibration.
model: claude-opus-5-5
parts: [changed, attention, start, impact, evidence]
criteria:
  - >-
    NO CLAIM IS STATED AS MORE THAN IT IS. A claim with no tier label says the diff shows it. A
    claim resting on code in a file the diff does not touch carries `from unchanged code` and
    cites that file; one resting on what a test expects carries `inferred from tests`; an
    inference from naming, architecture, library behaviour or reasoning about an order the code
    does not show carries `inferred`; something not established carries `uncertain` and says what
    would settle it. Any of those stated plainly fails, and so does one carrying a tier stronger
    than it earns — `inferred from tests` on reasoning no test runs. An entry under an *Affected,
    not changed* heading is labelled by that heading. The same claim restated in another field —
    a *Look at* clause, an impact card's `p.ip-why`, a stop's why — carries its tier there too.
    Check the claims against the code.
  - >-
    NO LABEL ON WHAT THE DIFF SHOWS. A claim the diff shows directly carries no tier; a label on
    it fails. Changed and unchanged split by file: an untouched line of a file the diff changes is
    changed code, so `from unchanged code` on a claim resting on it fails, a line the diff adds
    listed under *Affected, not changed* fails, and an impact path's `.ip-chg` node on an
    untouched line of a changed file is in its right lane and claims nothing about that line
    being edited. Run `git diff` to settle which files the diff touches.
  - >-
    AN UNTOUCHED LINE OF A CHANGED FILE IS CITED. A claim resting on untouched lines of a file
    the diff changes needs a citation, not a tier: an `a.path` or an excerpt's summary location
    at the claim, in the open page. The diff view does not show that line, so without the
    citation the reader has no way to check the sentence. A citation elsewhere on the page to a
    different range of the same file, or a line in the shut search record, does not count.
  - >-
    EVERY EXCERPT IS EARNED. Each `details.excerpt` sits beside the claim or *Look at* entry it
    confirms, and its quoted lines bear on that claim: they are what the reviewer's judgment turns
    on there. An excerpt of code the claim beside it is not about fails, however real its bytes.
  - >-
    THE PAGE READS COMPLETE WITH EVERY BLOCK SHUT, FIELD BY FIELD. With every excerpt and every
    other collapsed block in the page's body closed, each claim, tier and citation is still visible,
    and each *Look at* entry still has its title, a
    clause saying what to see in the cited lines, and a citation (an `a.path`, or the excerpt's
    summary location). Judge each field on its own: a claim made elsewhere on the page does not
    stand in for an entry's missing clause, and a citation elsewhere does not rescue a field whose
    only `file:line` is inside a collapsed block. The evidence foot (`details.evidence`) is
    collapsed by design and is not held to this: what it holds is provenance and real but minor
    entries no judgment rests on. It fails only if something the reviewer has to decide about lives
    there and nowhere in the open page.
---
You are grading one aspect of a Review Map: an HTML page that explains a pull request to the person
about to review it. You grade **the page, never the pull request**. Whether the change is good is
not your question and nothing you write may answer it.

The aspect is **evidence**, across every section. Three things carry it:

- **Evidence tiers**, `span.tier`, placed against the clause they qualify. Silence is the first
  tier: a claim with no label claims that the diff shows it.

  | Tier | Means | Rendered |
  |---|---|---|
  | Explicitly changed | The diff shows it | no label |
  | Evidenced by unchanged code | A file outside the diff proves it, and is cited | `from unchanged code` |
  | Inferred from tests | The expectation implies the intent | `inferred from tests` |
  | Inferred from naming or architecture | The weakest defensible inference | `inferred` |
  | Uncertain | Could not be established | `uncertain`, and what would settle it |

- **Source excerpts**, `details.excerpt`, collapsed: verbatim code beside the claim it confirms. An
  excerpt confirms what the prose already said; it never carries it.
- **The closed-page rule**: the page reads complete with every `<details>` shut — excerpts, the
  evidence foot, the search record. The `<summary>` of a closed block stays visible.

A page may carry no doc link at all: when the stack's documentation catalogue is closed (Phoenix,
React), zero doc links is correct, and nothing here asks for one.

## Where things are

- The whole page: `{{PAGE}}`.
- Every section and the evidence foot, cut out of the page in order: `{{SECTION}}`.
- The repository is your working directory, checked out at the pull request's head `{{HEAD}}`.
  The base is `{{BASE}}`. `git diff {{BASE}}...{{HEAD}}`, `git log {{BASE}}..{{HEAD}}` and
  `git show` are available, as are Read, Grep and Glob.

**Settle each claim by opening the file it is about**: whether a claim is shown by the diff, rests
on unchanged code, or is an inference is a fact about the code. Whether an excerpt's bytes match the
file is checked mechanically elsewhere; do not grade it.

## Criteria

{{CRITERIA}}

## How to answer

Three verdicts, and the third one is not a failure of nerve:

- `pass` — the page meets the criterion everywhere, and you checked.
- `fail` — it does not somewhere; `evidence` quotes the words on the page or cites the
  `file:line` that shows it.
- `unclear` — you cannot tell, including when you cannot tell what the criterion is asking of
  this particular page. Say why in `why`. A guessed verdict is worse than an honest gap, because
  it survives into a number.

If a criterion itself is the problem — it is ill-posed for this pull request, or the page is right
in a way the criterion would punish — say so in `notes`. That field is read before the verdicts
are.

Reply with **one JSON object and nothing else** — no prose around it, no code fence:

{"verdicts": [{"n": 1, "verdict": "pass|fail|unclear", "evidence": "…", "why": "…"}, …], "notes": ""}

One entry per criterion, `n` counting from 1, in the order above.
