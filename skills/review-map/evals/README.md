# Evals

Three grading scopes, because the thing being measured is prose and the prose has parts.

| Scope | Input | What it can settle |
|---|---|---|
| **Page** | a whole published page, from a real run | The invariants that only exist across sections |
| **Section** | one HTML fragment, produced from the frozen upstream | Everything internal to one section |
| **Component** | a script's output, or an `<svg>` lifted out of either | Mechanics: excerpt shape, ledger rows, diagram conformance |

```
evals/
├── evals.json               the page cases: one whole run each
├── trigger-eval.json        should-trigger / should-not-trigger queries
├── cases/                   the section cases, one file per section slug
├── drivers/                 the prompts that produce one section from frozen upstream
├── frozen/                  that upstream, hand-authored per fixture
├── fixtures/make-fixtures.sh  builds the repositories everything runs against
├── check.sh                 dispatcher over checks/, one tally
├── checks/                  one script per rule family, plus self-test.sh
├── golden/                  fragments with known verdicts, for self-test.sh
├── run.sh / report.sh       produce a section N times; aggregate the results
├── judge.sh / judge-prompt.md  grade one fragment against the written expectations
├── verdict-tally.sh         read one verdicts.json, shared by judge.sh and run.sh
└── results/                 one jsonl line per run (gitignored)
```

## Why the split

Before this, an eval was a whole run: one page, one 272-line script, twelve judged expectations. Three
things were wrong with that as a way to *improve* the skill.

- **Attribution.** A weak § 4 could be step 6's grouping, step 4's goal, or § 4's own spec. The score
  could not say which.
- **Cost.** Re-measuring a three-word change cost a full multi-turn run, and `CLAUDE.md` already says
  one run is weak evidence. Repetition was the thing that was unaffordable.
- **Grader attention.** A grader asked to verify thirty things does all of them badly, and the
  mechanical ones are what it is worst at.

So the section scope exists to make iteration cheap, and the page scope stays as the gate.

## What each scope cannot settle

Read this before quoting a number from `report.sh`.

A **section** eval cannot see duplication across sections, cannot run the completeness gate, and
cannot judge the page-wide excerpt budget — one canonical home is a relation *between* sections, and a
fragment has no other sections to relate to. Those stay with the page cases.

Freezing the upstream also removes the step whose variance the page cases measure. A section at 100%
is therefore compatible with poor pages; it just locates the defect upstream, which is a useful
reading rather than a contradiction.

A **section pass-rate is not page quality.** Nothing in `results/` claims otherwise, and neither
should a summary built from it.

## Running a section

```sh
./run.sh behaviour-flows -n 3
./run.sh behaviour-flows -n 3 --judge          # and grade the judged expectations too
./run.sh behaviour-flows -n 3 --judge --fast -j 3   # the iteration loop; see below
./run.sh diagrams --fixture monorepo-contract --visual
./report.sh behaviour-flows
```

`run.sh` rebuilds the fixtures, substitutes the driver's placeholders, runs `claude -p` from inside the
fixture, checks the fragment it wrote, and appends one line to `results/<case>.jsonl` stamped with the
skill's git sha. That stamp is the point: it makes a pass rate attributable to a wording version.

Two things to know about how it runs. It does **not** load the plugin — the driver names the skill
files by absolute path, which is what isolates the prose being measured from the packaging around it;
packaging is what the page cases exercise. And it defaults to `--permission-mode bypassPermissions`,
because the fixtures are disposable repositories under `$TMPDIR` and the alternative is a runner that
hangs overnight on a prompt nobody is watching. `EVAL_PERMISSION_MODE` overrides it.

`--judge` runs `judge.sh` after the check, and its counts land in the jsonl under their own keys with
a `judged` flag beside them — never summed with the mechanical ones, because a number that silently
mixes a script's verdict with a model's reading is worse than two numbers. Without `--judge` the
expectations are still yours to read by hand; `judge.sh` also runs standalone on any fragment.

**Three runs, not one.** Variance is the measurement. One green run of a section says almost nothing;
three runs where the same expectation fails twice is a finding about the spec.

## Where the time goes

All of it is the model. Measured on this machine: `make-fixtures.sh` 0.6s, `check.sh` on a written
fragment 0.15s, `checks/self-test.sh` 1.5s, `verdict-tally.sh` a few milliseconds. Producing one
fragment took 345–490s on the first recorded runs, and `--judge` adds a second call of the same order.
So `-n 3 --judge` over both fixtures is a dozen model calls and most of an hour, and nothing in the
harness is worth optimising.

Which leaves two levers — run the repetitions at once, or read each one with a cheaper model. `run.sh`
has both:

| | Costs | Buys |
|---|---|---|
| `-j N` | nothing but concurrent API load | wall clock: the N repetitions run at once, in batches of `N` |
| `--model` / `--effort`, or `--fast` for the pair | comparability | a cheaper reader per run |
| `--judge-model` / `--judge-effort` | comparability of the judged half | a cheaper grader |

`-j` is free of consequence — the runs are independent, each writes its own `$RUNDIR`, and each prints
its tally as a single labelled line so parallel output stays attributable. `--fast` is not free, which
is why what it changed is recorded: `model` and `effort` go on every jsonl line beside the sha, and
`report.sh` makes them part of the group key. A sonnet/low row can therefore never be averaged into a
row measured on the shipping model — the fast loop tells you which wording to keep, and the last pass
before believing a number runs on the model the skill ships against. A row printed as `-/-` was
produced by whatever the ambient config was that day, which is not a fact about anything; name the
model when you intend to compare.

`--fast` deliberately leaves the judge alone. The producer is the thing under test and a cheaper
reader of it is a legitimate cheaper experiment; the judge **is** the measurement, so a cheap judge
does not make the loop faster, it makes the number softer. `--judge-model` and `--judge-effort` are
there for when you mean it, and `report.sh` prints the judge's model on the judged line rather than in
the group key — it does not affect the checks, so splitting the whole group by it would claim a
dependency that is not there. Two graders in one group get two judged lines, never a mean over both.

Every knob has an environment variable, for a shell you keep open: `EVAL_MODEL`, `EVAL_EFFORT`,
`EVAL_JUDGE_MODEL`, `EVAL_JUDGE_EFFORT`, plus the existing `EVAL_PERMISSION_MODE` and `EVAL_TIMEOUT`.

## Running a page

Unchanged from before:

```sh
./fixtures/make-fixtures.sh
cd $TMPDIR/review-map-fixtures/rails-only-small
claude --plugin-dir /path/to/accountable-review
```

Paste the case's `prompt` from `evals.json`; when it publishes, check the page:

```sh
<skill>/evals/check.sh --page /path/to/page.html --repo . --base HEAD~1 \
  --expect 'app/queries/active_projects.rb' --forbid 'N/A'
```

The page ships in stages at one URL, so there are three page states. `--final`, the default, runs the
completeness gate and insists no banner or pending marker survived. `--draft` checks a page caught
mid-run: the banner has to be there, carrying the sentence that stops a pending part reading as
nothing to say. `--stopped` is for a run that ended early on purpose — the banner must state what was
not written rather than promise stages that are never coming. Page case 4 needs the first two, so copy
the page file aside right after the first publish; that snapshot is the only record of stage 1.

`--scope core` runs exactly the five checks the old single script ran, which is the comparison to make
if a page starts failing for a reason you did not expect.

## checks/

One script per rule family. Each prints `PASS` / `FAIL` / `WARN` / `SKIP` lines and nothing else;
`check.sh` decides which apply and adds them up.

| | Owns | Scope |
|---|---|---|
| `page-invariants.sh` | severity chips, verdict language, evidence tiers, `data-path`, dead links, themes | page and fragment |
| `build-state.sh` | draft / final / stopped | page |
| `completeness.sh` | the gate, delegated to `scripts/coverage-gate.sh` | page |
| `excerpts.sh` | collapsed, summarised, tinted in all three themes, no range quoted twice | page and fragment |
| `blast-radius.sh` | § 2: a diagram, an affected list, a reading order with reasons, recorded searches | page and fragment |
| `behaviour-flows.sh` | § 4: no layer grouping, and the two review-unit guards, per unit | page and fragment |
| `before-approving.sh` | § 6: the cap of five, questions that are questions, commands that are commands | page and fragment |
| `diagram.sh` | template classes only, no literal colours, nothing off-canvas, labels that fit, a key behind every dashed node, the budget | page and fragment |
| `diagram-shot.sh` | renders each diagram in both themes to PNG | page and fragment |

`SKIP` is load-bearing. A check that cannot run on this input says so out loud — a fragment has no
`:root`, no ledger and no banner — because silently dropping it is how a fragment ends up reading as
thoroughly verified as a page.

## The judge

One pass over one fragment, all the expectations at once. That is the cheaper arrangement, and its
failure mode is the one this file already names: a grader asked to verify many things at once verifies
each of them less carefully. Six is small enough to be worth trying before paying for a call per
expectation, and the per-expectation variant is the obvious next step if verdicts start looking thin.

What makes the verdicts worth anything is not the rubric, it is the anchoring. The judge runs **inside
the fixture**, with the frozen upstream, so "is this claim right" is settled by opening the file the
claim cites. Take that away and it decays into a second opinion about prose. It also never sees the
mechanical results: two independent readings beat one reading anchored to the other.

Three verdicts, not two. `unclear` exists so the judge does not have to guess — including when it
cannot tell what an expectation is asking. A judge forced into a binary invents confidence, and an
invented verdict is worse than an honest gap because it survives into a number.

And a `notes` field, for when **the expectation is the problem** rather than the fragment. That is not
a courtesy — it has corrected this repository's ground truth twice in two runs. On `monorepo-contract`
it reported no ill-posed expectation but volunteered a factual error no expectation covered: a diagram
caption claiming a component reads a field it never touches, inherited from the specimen label in the
template's own catalogue. On `rails-only-small` it rejected the wording of an expectation outright —
"contains no changed file" is false at line granularity, because the flow's entry point lives in a
file the diff modifies elsewhere — and pointed out that the fragment's own phrasing was the sharper
one. Both fixes are in the repo; neither was a change to the section under test.

Which is the argument for reading `notes` before reading the verdicts. A judged run that comes back
all-pass has still told you something if the notes are not empty.

`verdict-tally.sh` does the parsing for both `judge.sh` and `run.sh`, so there is one implementation
and `self-test.sh` can exercise it against `golden/verdicts-*.json` without a model — a tally that
reads a truncated file as "no fails" is the same defect as a check that always passes, and worse here
because what it emits looks like a measurement.

## The mechanical / judged line

`check.sh` owns the yes-or-no facts: does the ledger account for every changed path, are severity chips
back, is there verdict language, is any inference unlabelled, does a diagram use a colour that only
exists in one theme. A script checks those identically every time, for nothing, in CI.

Everything in `expectations` needs a reader: whether the cohort split is defensible, whether an
affected-but-unchanged entry is *right* rather than merely present, whether the page still reads
completely with every excerpt closed — judged field by field, which no script can see.

Diagrams sit on the line and need both halves. `diagram.sh` catches what is countable; crowding,
overlap and an arrowhead that lands beside its box rather than on it are none of those things.
`diagram-shot.sh --visual` produces the images, and looking at them is the check. Both defects in the
sentence above were found that way, in diagrams this script had just called clean — and one of them
became a new check.

## checks/self-test.sh

Runs the checks against `golden/`, where every fragment plants exactly one defect, and asserts the
verdict. No model, about a second, and it belongs in CI: **a check script that always passes is worse
than none**, because it turns an unchecked rule into one the reader believes is checked.

Adding a check means adding a golden fragment that makes it fire. Adding a golden fragment means
watching its keyword: two of the first eight passed for the wrong reason because their own `aria-label`
contained the word the check greps for.

## The fixtures plant their answers

Each fixture contains findings that are true but **not in the diff**, which is the skill's whole claim.
They are the ground truth the expectations check against:

| Fixture | Diff | Planted, outside the diff |
|---|---|---|
| `rails-only-small` | 5 files, no client, **no remote** (link rung 4) | `app/queries/active_projects.rb` scopes the selectable list; new slug uniqueness validation has no unique index |
| `monorepo-contract` | 7 files across `api/` and `web/`, **remote configured but nothing pushed** (link rung 3) | the wire key is `archived_at` and the type declares `archivedAt`, with no case transform anywhere, so the field is `undefined` for every project; the serializer also emits `null` against a non-null type; the archive endpoint can 422 and no client handles it; `web/src/queries/selectableProjects.ts` filters the list; `archive!` calls an association the model never declares |
| `trivial` | 1 file, a README typo | nothing — the right output is a refusal to generate ceremony |

If you change a fixture, change `frozen/` and the expectations with it. A fixture whose planted finding
has been edited away turns a real eval into one that always passes; a frozen upstream that has drifted
turns every section eval into a test of agreement with a stale document.

## Adding a section

Four files, and the fifth is optional:

1. `frozen/<fixture>/` — already there for both real fixtures; extend it if the section needs upstream
   that is not yet written down.
2. `drivers/<slug>.md` — the prompt. Read `drivers/README.md` first: a driver pins inputs and must not
   restate a rule from `SKILL.md` or `report-format.md`.
3. `cases/<slug>.json` — at most six judged expectations.
4. `check.sh` — add the slug to the `RUN` table.
5. `checks/<slug>.sh` plus a golden fragment, if the section has anything mechanically checkable.

Slugs, not numbers: `report-format.md`'s numbering is the source of order, and a filename that repeats
it only makes the reader look the number up. The remaining sections are `what-changed`, `start-here`,
`cross-cutting` and `coverage-ledger`.

## Next cases worth adding

In rough order of value:

1. **Stability of the explanation.** Run one section twice and diff the two fragments. The claim is
   that explanation is reproducible while findings are a sample; nothing yet tests the first half, and
   the section scope is the first time it has been cheap enough to.
2. **A large diff.** Single-context is a deliberate choice, and the failure mode is silent skimming. A
   60-file fixture with a planted finding in the least interesting corner would show whether the run
   reports the strain or hides it.
3. **A dropped file.** Feed a page with one ledger row deleted and confirm the run notices, rather than
   trusting that the gate is wired up.
4. **A Rails-only monolith** with server-rendered views, to exercise the other branch of § 4.
5. **A repo with no `config/application.rb`** at the root, so Rails-root discovery has to discover
   something.

## On harnesses

The page cases use the schema `skill-creator` documents, with two additions: `fixture` names the repo
a case runs in, and `check` is its mechanical command. The section cases add `driver` and `scope`.

`claude plugin eval` is the better long-term home, since it lives in the CLI, runs a no-plugin baseline
arm for free, and belongs in CI. It is early access and not enabled on this account, so nothing here is
written in its `case.yaml` format — config written against an unverifiable schema is guessing. The
fixtures, the frozen upstream and `checks/` are the durable part and carry over to either.
