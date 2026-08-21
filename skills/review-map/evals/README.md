# Evals

A seed set: three capability cases, eight trigger queries, and the machinery to run
them. Small on purpose — enough to catch a regression in the parts most likely to
regress, and shaped so cases can be added without rethinking the setup.

```
evals/
├── evals.json               the cases: prompt, what success looks like, expectations
├── trigger-eval.json        should-trigger / should-not-trigger queries
├── fixtures/make-fixtures.sh  builds the repositories the cases run against
├── check.sh                 the mechanical expectations, as one command
└── ../scripts/coverage-gate.sh  reused by check.sh, so the rule has one implementation
```

## Running one

```sh
./fixtures/make-fixtures.sh                       # → $TMPDIR/review-map-fixtures
cd $TMPDIR/review-map-fixtures/rails-only-small
claude --plugin-dir /path/to/accountable-review
```

Then paste the case's `prompt`. When it publishes, run the case's `check` against the
page it wrote:

```sh
<skill>/evals/check.sh --page /path/to/page.html --repo . --base HEAD~1 \
  --expect 'app/queries/active_projects.rb' --forbid 'N/A'
```

The page ships in stages at one URL, so `check.sh` has two modes. `--final`, the default, runs the
coverage gate and insists no build banner or pending marker survived. `--draft` checks a page caught
mid-run: the banner has to be there, carrying the sentence that stops a pending part from reading as
nothing to say.

Case 4 needs both, so copy the page file aside right after the first publish, before the next stage
overwrites it — that snapshot is the only record of what stage 1 looked like.

There is a third mode, `--stopped`, for a run that ended before the page was finished. It checks that
the banner stopped promising stages that are not coming, and that the markers read *not written*
rather than *pending*. It came out of the first real run against a 112-file branch, which stopped by
choice at the review map and left exactly that page behind.

The prompts are written the way a user would say them from inside the repo, so they
double as a weak trigger test. That does conflate two failures — if the skill never
fires you learn nothing about the page — so `trigger-eval.json` tests triggering
separately, and is the file to grow when the description changes.

`check.sh` also owns the mechanical half of the source excerpts: that `data-path` never
escapes the ledger (the coverage gate reads it page-wide, so an excerpt using it breaks
the gate), that every excerpt ships collapsed with a real summary, and that the two
excerpt tints exist in all three theme blocks.

The half it cannot own is the one that matters: **does the page still read completely
with every excerpt closed?** That needs a reader, so it lives in `expectations`. It is
the rule that separates progressive disclosure from hidden content, and a script has no
way to tell whether a sentence still makes sense once the block under it is shut.

## Why the expectations are split

`check.sh` owns the yes-or-no facts: does the ledger account for every changed path,
are severity chips back, is there verdict language, is any inference unlabelled, does
the page emit permalinks to a commit that was never pushed, do all three theme states
resolve. A script checks those identically every time, for nothing, in CI.

Everything else in `expectations` needs a reader — whether the cohort split is
defensible, whether the affected-but-unchanged entry is *right* rather than merely
present. Those go to a human or a grader agent. Keeping them apart is not tidiness: a
grader asked to verify thirty things does all of them badly, and the mechanical ones
are exactly the ones it is worst at.

## The fixtures plant their answers

Each fixture contains findings that are true but **not in the diff**, which is the
skill's whole claim. They are the ground truth the expectations check against:

| Fixture | Diff | Planted, outside the diff |
|---|---|---|
| `rails-only-small` | 5 files, no client, **no remote** (link rung 4) | `app/queries/active_projects.rb` scopes the selectable list; new slug uniqueness validation has no unique index |
| `monorepo-contract` | 7 files across `api/` and `web/`, **remote configured but nothing pushed** (link rung 3) | serializer emits `null`, TS declares `archivedAt: string`; archive endpoint can 422 and no client handles it; `web/src/queries/selectableProjects.ts` filters the list |
| `trivial` | 1 file, a README typo | nothing — the right output is a refusal to generate ceremony |

If you change a fixture, change the expectations with it. A fixture whose planted
finding has been edited away turns a real eval into one that always passes.

## Next cases worth adding

In rough order of value:

1. **Stability of the explanation.** Run one fixture twice and diff the two pages. The
   claim is that explanation is reproducible while findings are a sample; nothing
   currently tests the first half.
2. **A large diff.** Single-context is a deliberate choice, and the failure mode is
   silent skimming. A 60-file fixture with a planted finding in the least interesting
   corner would show whether it reports the strain or hides it.
3. **A dropped file.** Feed a page with one ledger row deleted and confirm the run
   notices, rather than trusting that the gate is wired up.
4. **A Rails-only monolith** with server-rendered views, to exercise the other branch
   of Part 4.
5. **A repo with no `config/application.rb`** at the root, so Rails-root discovery has
   to actually discover something.

## On harnesses

These files use the schema `skill-creator` documents, with two additions: `fixture`
names the repo a case runs in, and `check` is its mechanical command. That harness is
runnable today — it spawns a subagent per case, grades, and opens a viewer.

`claude plugin eval` is the better long-term home, since it lives in the CLI, runs a
no-plugin baseline arm for free, and belongs in CI. It is early access and not enabled
on this account yet, so nothing here is written in its `case.yaml` format — writing
config against an unverifiable schema would be guessing. The fixtures and `check.sh`
are the durable part and carry over to either.
