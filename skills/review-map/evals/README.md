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

- **Attribution.** A weak § 2 could be step 6's grouping, step 4's goal, or § 2's own spec. The score
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

**The reorder gave that limit a sharper edge, worth stating before someone writes another expectation
across it.** § 4's rule that a consequence a flow owns is compressed to a pointer is a relation
between § 2 and § 4, so a § 4 fragment can only be judged on its *shape* — one clause, one citation,
a link — and never on whether the compression was safe, because the flow it points at is not there
and neither is a reader who has read it. The first run against `monolith-guard-chain` restated a
flow-owned entry at full length, and part of why is that a standalone fragment has nothing to point
at. Judge the form here; the page cases judge whether anything was lost.

**The merged tail section is that limit one size larger, so `brief-tail` is worth reading with it in
mind.** At the default level, § 4's material and §§ 5–7's share one section, which means the pointer
relation and the canonical-home rule now run *inside* the fragment as well as across it — and the
fragment still cannot settle either, for the same reason. What it also cannot see is the failure the
merge specifically invites: a section that carries both a flow's explanation and the pointer back to
it, two paragraphs apart. That is duplication at conversational distance, it looks like thoroughness,
and only a page case reads far enough to catch it.

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
./run.sh brief-tail -n 3 --judge                # the default level's merged tail section
./run.sh blast-radius -n 3 --level brief        # the same case, other level: override the case file
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

### The detail level is the third axis, on the same argument

The skill produces two page shapes — `--brief`, the default, merges sections 4 to 7 into one; `--full`
writes all seven (`report-format.md` § *Detail levels*). Those are different documents from the same
diff, so a pass rate averaged over both describes neither, exactly as with model and effort.

So a case declares its level, `--level` overrides it, `run.sh` writes it on the jsonl line, and
`report.sh` makes it part of the group key. **A case file that declares no `level` means `full`** — the
default is the *harness's*, not the skill's, and the two differ on purpose: reading the existing corpus
as brief because the skill's default changed would silently reinterpret every result line already on
disk. `check.sh` takes `--level` too, and defaults it the same way.

Only one check reads it: `before-approving.sh`, because a missing comprehension checkpoint is correct
at brief and worth a WARN at full. Everything else survives the merge without a flag, because the
merged section keeps the `id="blast"` and `id="approving"` anchors the region extractors read — which
is a property of the markup, and therefore a thing to break by accident. `golden/approving-brief-*.html`
and the `self-test.sh` rows over them are what notice: three rows for the level's own rule, and two more
running `blast-radius.sh` and `page-invariants.sh` over the merged shape, whose whole job is to fail the
day the anchors move.

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
| `behaviour-flows.sh` | § 2: no layer grouping, and the two review-unit guards, per unit | page and fragment |
| `start-here.sh` | § 3: one list, an order with reasons, entries that link into a flow, the cap | page and fragment |
| `blast-radius.sh` | § 4: a diagram, an affected list, pointers into the flows and their shape, recorded searches, and no reading order left here | page and fragment |
| `searches.sh` | whether a recorded search **reproduces** the entry it is offered for — re-run inside `--repo` | page and fragment |
| `before-approving.sh` | § 6: the cap of five, questions that are questions, commands that are commands | page and fragment |
| `diagram.sh` | template classes only, no literal colours, nothing off-canvas, labels that fit, a key behind every dashed node, the budget | page and fragment |
| `diagram-shot.sh` | renders each diagram in both themes to PNG | page and fragment |

`SKIP` is load-bearing. A check that cannot run on this input says so out loud — a fragment has no
`:root`, no ledger and no banner — because silently dropping it is how a fragment ends up reading as
thoroughly verified as a page.

**`run.sh` passes `--repo`**, so the two checks that need the repository run on a section fragment
rather than skipping: `searches.sh` re-runs the recorded searches inside it, and
`page-invariants.sh` asks git whether the head is pushed — which is how the link rung finally became
mechanical for section runs instead of a thing only a reader could catch.

`searches.sh` is the one check whose rule is a relation between the page and a repository, so it is
also the one whose *coverage* has to be reported: it prints how many entries it skipped as pointers,
how many it could not resolve to a file, and — when nothing was recorded at all — that provenance was
unverifiable rather than false. A handful of FAILs over an unstated denominator would read as a clean
sweep of everything else.

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
| `monolith-guard-chain` | 7 files, server-rendered monolith, no client package, **GitHub remote, nothing pushed** (link rung 3) | the two sibling guards in the *changed* `application_controller.rb` still key on `steward?`, forty lines below the changed hunk; `steward/base_controller.rb` is the admission test the fix was aligned to, and its own profile guard is now unreachable; `matching/eligibility_filter.rb` rejects on `steward?` twice and `User.recommendable` does it again in SQL for four jobs, while `general_recommendations_eligible` excludes the free plan this same diff grants — so the two scopes disagree; `switch_to_free!`'s comment names a controller guard the new caller is not behind, and the protection survives only because `has_paid_subscription?` requires `plan_active?`; `chapters_controller.rb` skips the plan guard but not the profile-setup guard, and `chapters` is absent from `profile_setup_not_required?`, so the new redirect target bounces on the users `generate_steward_invite!` selects for; `load_management` reads approved memberships and acceptance creates none; `test/test_helper.rb` completes every test user's profile, so a green suite cannot observe any of it |

### Two page runs against `monolith-guard-chain`, and how not to score them

Two cold runs, same fixture, same prompt, same model (opus, skill at `eda1bf3`):

| | Planted findings named | `check.sh --final` |
|---|---|---|
| Run 1 | 15 / 15 | 53 passed, 0 failed |
| Run 2 | 15 / 15 | 48 passed, **1 failed**, 3 warnings |

**Read the pages to score them; do not grep for identifiers.** The first attempt at the table above
scored 14/15 and 12/15 by grepping each page for a method or index name. All three "misses" were
false negatives. Run 1 covers the roster gap at `chapters_controller.rb:88-91` and
`manage.html.erb` without ever writing `load_management`; run 2 writes "the invite guard at
`chapter.rb:89-93`" rather than `generate_steward_invite!`, and cites `db/schema.rb:25-27` rather
than `index_chapters_on_steward_id`. A page that cites a line range instead of a name is following
the citation rules, so grep-scoring penalises exactly the behaviour the format asks for.

So this pair says something narrower than "findings are a sample" and something sharper. **Recall on
findings that were deliberately planted was total, twice.** Where the runs genuinely diverged was
everywhere else:

- *Beyond* the planted set. Run 1 alone found that no fixture or test represents an **unaccepted**
  `institute_roles` row — a third producer of flagged-but-not-admitted — and that the success notice
  is probably swept by the second redirect. Run 2 alone found that `ProfileSetupController#update`
  returns the user to the dashboard rather than the chapter, that `chapter_steward` is a sticky
  boolean `dependent: :nullify` can falsify, and that the stewarded chapter appears in no navigation.
- In structure. Run 1 split the flows by *which decision is being made*; run 2 split them by *who the
  user is*, and built a six-column guard-chain table run 1 has no equivalent of.

Neither is a superset of the other, and neither missed anything the fixture planted. Treat a planted
set as a floor test — it measures whether the skill finds what is known to be there, not the tail,
and the tail is where the variance lives.

Run 2's hard failure is the thing to carry into reading any green run: a diagram using `.node-dead`
with no legend behind it, plus a label overflowing its box by 4px. Diagrams are the component with no
generator, and they are where two runs most reliably differ.

If you change a fixture, change `frozen/` and the expectations with it. A fixture whose planted finding
has been edited away turns a real eval into one that always passes; a frozen upstream that has drifted
turns every section eval into a test of agreement with a stale document.

## Adding a section

Four files, and the fifth is optional:

1. `frozen/<fixture>/` — already there for all three real fixtures; extend it if the section needs
   upstream that is not yet written down.
2. `drivers/<slug>.md` — the prompt. Read `drivers/README.md` first: a driver pins inputs and must not
   restate a rule from `SKILL.md` or `report-format.md`.
3. `cases/<slug>.json` — at most six judged expectations, plus `level` if the section belongs to one
   detail level rather than both. Leave it out and the case runs at `full`.
4. `check.sh` — add the slug to the `RUN` table. A case reusing an existing scope at another level, as
   `brief-tail` reuses `blast-radius`, needs nothing here: the level rides on `--level`, not the scope.
5. `checks/<slug>.sh` plus a golden fragment, if the section has anything mechanically checkable.

Slugs, not numbers: `report-format.md`'s numbering is the source of order, and a filename that repeats
it only makes the reader look the number up. That rule earned itself when §§ 2 and 4 swapped places:
`blast-radius` and `behaviour-flows` kept their names, their files and their history, and only their
prose had to move.

The remaining sections are `what-changed`, `start-here`, `cross-cutting` and `coverage-ledger`. The last
two exist only at `--full`, which is worth knowing before writing them: a case for either has to declare
`"level": "full"` or it will grade a fragment the default level does not produce at all.
`start-here` is half built — `checks/start-here.sh` and its three goldens exist and run standalone
via `check.sh --fragment <file> --scope start-here` — but it has no driver and no case, so
`run.sh start-here` will not find one. Adding those two files is what makes it a section eval.

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
4. **A repo with no `config/application.rb`** at the root, so Rails-root discovery has to discover
   something.
5. **A `diagrams` case for `monolith-guard-chain`.** `behaviour-flows` and `blast-radius` now have
   one each and have been run; `diagrams` has not. This is the fixture where *affected but unchanged*
   carries the most weight, which makes it the one whose blast-radius figure has the most to get
   wrong — writers, the fact, and readers, with the readers outnumbering everything else.

`monolith-guard-chain` closed what used to be item 4 here — a Rails-only monolith with
server-rendered views, to exercise the other branch of the behaviour flows.

**Rungs 1 and 2 are not reachable offline, and trying was instructive.** The fixture originally
pushed its branch to a local bare repository and then rewrote the remote URL to
`github.com/acme/commons`, so that `git branch -r --contains HEAD` — the ladder's reachability
test, which reads `refs/remotes` and never contacts a server — would report the head as pushed.
That bought a rung-2 label on paper. The first live run ignored it: it ran `gh`, got
`Could not resolve to a Repository`, and emitted plain text, which is correct, because a permalink
into a repository that does not exist 404s regardless of what `refs/remotes` says.

Two things to take from that. A fictional remote can never reach rung 2, so a fixture claiming it
is claiming something a good run will refuse. And the trick had punched a hole in
`checks/page-invariants.sh` § 5: with `refs/remotes` populated, that check passes a page of dead
permalinks — the always-passing check this file warns about two sections up. The push is reverted
and the fixture is an honest rung 3. Reaching rung 1 or 2 needs a real repository, which means
network, which means it is not a fixture concern.

## On harnesses

The page cases use the schema `skill-creator` documents, with three additions: `fixture` names the repo
a case runs in, `check` is its mechanical command, and `level` is the detail level its prompt asks for.
The section cases add `driver` and `scope`, and `level` there too.

`claude plugin eval` is the better long-term home, since it lives in the CLI, runs a no-plugin baseline
arm for free, and belongs in CI. It is early access and not enabled on this account, so nothing here is
written in its `case.yaml` format — config written against an unverifiable schema is guessing. The
fixtures, the frozen upstream and `checks/` are the durable part and carry over to either.
