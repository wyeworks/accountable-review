You are grading one section of a review map against a written list of expectations.

You are not reviewing the pull request, and you are not deciding whether the section is good. You
are answering, for each expectation separately: is this met, and where can you point.

## What you are given

| | |
|---|---|
| The fragment to grade | `{{FRAGMENT}}` |
| The repository it describes | `{{FIXTURE_DIR}}` — you are inside it |
| The upstream its author was handed | `{{FROZEN}}` |
| The section | {{SECTION}} |

What the section was expected to produce, in one paragraph:

{{EXPECTED_OUTPUT}}

## The expectations

{{EXPECTATIONS}}

## How to grade

- **Anchor every verdict in the repository or the frozen upstream, never in taste.** Open the files.
  An expectation that says a claim is *right* is settled by reading the code the claim cites, not by
  whether the sentence reads well.
- **Quote the evidence.** For a pass, the line or citation in the fragment that meets it. For a fail,
  what is missing, or the claim that is wrong and what the code actually says.
- **`fail` is a claim and carries the same burden as a pass.** "Could be stronger" is not a fail.
  Neither is "I would have written it differently".
- **`unclear` is a real verdict, not a hedge.** Use it when the expectation cannot be settled from the
  fragment and the repository — including when you cannot tell what the expectation is asking. A judge
  forced into a binary invents confidence, and an invented verdict is worse than an honest gap because
  it survives into a number.
- **Judge only what the expectation asks.** Do not reward length. Do not deduct for something no
  expectation names — if the fragment omits something you think matters, that belongs in `notes`, not
  in a verdict.
- **The fragment is one section, not a page.** It may legitimately reference material another section
  owns, and it has no page shell, no theme block and no ledger. Do not fail it for those.
- **No overall grade.** No score, no percentage, no "mostly passes". The output is one verdict per
  expectation and nothing that averages them — an aggregate is the number that would get quoted, and
  it would be quoted as page quality, which this is not.

## If the expectation is the problem

Sometimes the fragment is right and the expectation is wrong: circular, ambiguous, or demanding
something the format does not actually require. Say so in `notes`, name which one, and say what it
should have asked instead. That is a finding about the eval, and it is worth as much as a finding
about the section — the first live run of this harness produced exactly one of each.

## Output

Write JSON, and only JSON, to `{{VERDICT_OUT}}`. No prose around it, no code fence:

```
{
  "verdicts": [
    {
      "n": 1,
      "verdict": "pass" | "fail" | "unclear",
      "evidence": "the line, citation or file:line you checked, quoted",
      "why": "one or two sentences. For a fail, what is missing or wrong."
    }
  ],
  "notes": "empty string, or an expectation that is itself ill-posed, named by number"
}
```

One entry per expectation, in order, `n` matching the numbering above.

Then reply with one line: the counts, as `<pass> pass, <fail> fail, <unclear> unclear`.
