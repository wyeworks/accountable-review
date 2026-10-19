# Deferred

What the eval gate knowingly lets through, one entry each: the criteria held out of the grade and
the findings a release carries. `README.md` § *What counts as good* owns the rules; this file is
the list. An entry leaves this file in the same commit as the change that earns it.

## Deferred criteria

A criterion classed `deferred` in `e2e/criteria.yml` is judged on every run and shown on every
table, and moves no status, no page cap and no exit code.

### The evidence judge's three tier criteria (1, 2, 3)

*No claim is stated as more than it is · no label on what the diff shows · an untouched line of a
changed file is cited.* Deferred at `8e7a7de`.

**The reading.** Over four measured shas (`2212dec`, `719d730`, `21e29c2`, `1dba6d1`) on both eval
PRs, three repetitions each:

| criterion | PR | 2212dec | 719d730 | 21e29c2 | 1dba6d1 |
|---|---|---|---|---|---|
| 1 | discourse-44560 | 0/3 | 0/3 | 0/3 | 0/3 |
| 1 | discourse-44196 | 0/3 | 0/3 | 1/3 | 0/3 |
| 3 | discourse-44560 | 0/3 | 0/3 | 0/3 | 0/3 |
| 3 | discourse-44196 | 1/3 | 0/3 | 3/3 | 0/3 |

Criterion 3 on 44196 moved 3/3 to 0/3 with no prose change between the last two shas, so three
repetitions per PR cannot tell a rule from noise on it. Every one of the 22 criterion-1 failures
named a **true** claim missing its provenance — a tier dropped where a claim is restated in
*What changed*, a checkpoint's opening sentence or an impact card's why; a line number typed as
`<code>:183</code>` instead of cited; a citation left in the shut search record — and none named a
false sentence; the judge's own evidence cites the file where each claim holds.

**Why deferred rather than fixed.** The rules those sentences break are in the prose in exact
words (`references/report-format.md` § *Evidence tiers*, `SKILL.md` step 8), two prose rules and
the step-10 lint did not move the rate, and the criterion fails on the first miss among some
forty sentences a page. It is a per-sentence compliance floor the current approach does not
lift, on an error that costs the reader a click rather than their trust, and as the truth
criterion it blocked every release. The lint still warns at step 10 and the judge still reads
every page; only the gate is off.

**What lifts it.** A change measured on the shape under README rule 7, on both PRs. The direction
is software rather than prose: `scripts/page-lint.sh` already computes the tier a cited sentence
should carry, so applying it rather than warning would leave uncited claims as the one rule left
to the run. Then criteria 1 to 3 return to `truth`, `form`, `form`.

## Findings carried

Blocking under the README's rules at the sha named, merged knowingly. Each is bounded work, not
a cycle of prose.

### `checkpoint-claims` 1 on discourse-44196 at `1dba6d1` — a *Look at* range that under-covers its clause

1/3, two failures, so it blocks as a truth criterion. In both failing pages a *Look at* entry's
title names more than its cited range shows: "its two callers" over lines holding one of them;
three checks over a range holding one. A reader opens the range and finds less than promised.
Same provenance family as the tier axis, classed truth because the clause is not what the lines
show. Candidate: a rule at step 8 that a range is read against every noun its title names, and
the judge already exists.

### `searches.rb` FAIL on three of six pages at `1dba6d1` — an affected entry no recorded search reaches

The *Affected, not changed* list cites a file (`staff_action_logger.rb` twice on 44196,
`execution.rb` on 44560) that none of the searches recorded in the foot could have found: the run
found it by reading and recorded no search. Under README rule 1 any check FAIL blocks. The check is
Ruby, so a run cannot see it at step 10. Candidate: port the rule to `scripts/page-lint.sh` as a
WARN naming the entry, relayed by `page-invariants.rb` the way the tier rules are, so the run can
record the search or drop the entry before it publishes.

### One documentation link with no `file:line` beside it, discourse-44196 r2 at `1dba6d1`

`rails-anchors.rb`: a link to the Rails guides sat beside no repository line. One page in six; a
reading before a rule.
