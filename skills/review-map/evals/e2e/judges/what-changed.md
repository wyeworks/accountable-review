---
# The one working judge. Its model is pinned here rather than inherited, because the judge IS the
# measurement: a cheaper or different grader does not make a number cheaper, it makes it softer.
# Changing this line, or any byte of this file, invalidates calibration — judge.rb stamps the
# file's sha on every verdict and calibrate.rb records which sha and model were calibrated.
model: claude-opus-5-5
section: changed
criteria:
  - >-
    ACCURATE. Every factual claim § 01 makes about what the change does — the problem it solves,
    what is now true that was not, who is affected, the change-shape chip — is true of the code at
    head against the base. Open the files; the diff is `git diff {{BASE}}...{{HEAD}}`. A claim the
    code does not support, or supports only in part, fails this criterion even if it is plausible.
  - >-
    COMPLETE AT THE LEVEL OF DELTAS. If the pull request carries genuinely independent changes,
    § 01 names each one, as an actor plus a behaviour; if it carries one, § 01 does not split it
    into bullets that are really steps of one behaviour. A missing independent change fails. So
    does a list of execution paths or use cases standing where the deltas should be.
  - >-
    ORIENTS, DOES NOT TEACH, AND SAYS WHERE ITS CLAIMS COME FROM. § 01 explains mechanism only
    where it is needed to follow the change and leaves the rest to the checkpoints. Where it uses
    the PR description it attributes it rather than stating it as fact, and where intent is
    inferred rather than shown by the diff it carries an evidence tier (a `span.tier`).
  - >-
    STATED LIMITS ARE TRUE AND STATED ONCE. Any limit § 01 states — a region the run skimmed, a
    client it could not read, a dirty tree, the absence of a separate client — is true of this
    repository and appears once, in the page's own voice, not repeated elsewhere on the page. If
    § 01 states no limit and you can see one the page owed (for example, the page never says it
    could not read a client that exists), that fails too.
  - >-
    NO VERDICT. No sentence in § 01 grades the change, scores or ranks its risk, recommends
    approving or rejecting it, asserts that the change was covered or that nothing was found, or
    narrates how the page itself was drafted or checked. Describing what the change does is not
    grading it; "safe", "low risk", "looks good", "fully covered" and "on a second pass" are.
---
You are grading one section of a Review Map: an HTML page that explains a pull request to the
person about to review it. You grade **the page, never the pull request**. Whether the change is
good is not your question and nothing you write may answer it.

The section is **§ 01, What changed**: the masthead plus `<section id="changed">`. It orients a
reviewer in a screenful — what the change does, what is now true that was not — and leaves every
judgment to the sections after it.

## Where things are

- The whole page: `{{PAGE}}`. Read it so you can tell whether § 01 repeats what a later section
  owns, but grade only § 01.
- § 01 on its own: `{{SECTION}}`.
- The repository is your working directory, checked out at the pull request's head `{{HEAD}}`.
  The base is `{{BASE}}`. `git diff {{BASE}}...{{HEAD}}`, `git log {{BASE}}..{{HEAD}}` and
  `git show` are available, as are Read, Grep and Glob.

**Settle each claim by opening the file it is about.** A verdict reached by reading the page
alone is a second opinion about prose, and that is not what is being asked. Do not count words:
the length of § 01 is measured elsewhere and is not one of your criteria.

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
right in a way the criterion would punish — say so in `notes`. That field has corrected this
project's ground truth before, and it is read before the verdicts are.

Reply with **one JSON object and nothing else** — no prose around it, no code fence:

{"verdicts": [{"n": 1, "verdict": "pass|fail|unclear", "evidence": "…", "why": "…"}, …], "notes": ""}

One entry per criterion, `n` counting from 1, in the order above.
