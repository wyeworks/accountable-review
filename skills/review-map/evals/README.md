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
├── profile.sh / profile.jq  where one run's wall clock went, from the session transcript
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

All of it is the model, and `profile.sh` is what says which part. Measured on this machine:
`make-fixtures.sh` 0.6s, `check.sh` on a written fragment 0.15s, `checks/self-test.sh` 1.5s,
`verdict-tally.sh` a few milliseconds. Producing one fragment took 345–490s on the first recorded
runs, and `--judge` adds a second call of the same order. So `-n 3 --judge` over both fixtures is a
dozen model calls and most of an hour, and nothing in the harness is worth optimising.

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

### The skill effort is the fourth, and it is not the `--effort` beside it

`run.sh` now takes two things called effort, and they are unrelated. `--effort` is the CLI reasoning
effort the *producing model* runs at, and it is half of `--fast`. `--skill-effort` is the flag the
*skill* is invoked with: at `high`, `SKILL.md` step 8 sends one `claim-falsifier` subagent at each
written behaviour flow to try to break its claims, and the run adjudicates what comes back. Both land
on the results line under their own keys and both are in `report.sh`'s group key, so a `high` row can
never be averaged into a `normal` one — the same argument that keeps `--brief` and `--full` apart.

A case declares `skill_effort` and `--skill-effort` overrides it. **A case file that declares none
means `normal`**, for the reason an absent `level` means `full`: every run recorded before the flag
existed did what `normal` names, and silently rereading the corpus would make old lines incomparable
with new ones.

**The falsifier is registered with `--agents`, not by loading the plugin**, which keeps the property
this file defends two sections up — the driver names the skill files by absolute path, so what is
measured is the prose rather than the packaging. `--agents` accepts the plugin-scoped identifier
verbatim, so the eval spawns the same name a real install does, and `run.sh` reads the description
and the tool list out of `agents/claim-falsifier.md` rather than keeping a second copy of them.
It is registered on **every** run, including `normal` ones where nothing spawns it: an unused agent
costs nothing, and an arm of an A/B carrying an extra CLI flag differs by something other than the
thing under test.

**No case gained an expectation for it, deliberately.** Six per case is a cap this file argues for,
and a seventh would make the grader worse at the other six — which would be measuring the judge
rather than the flag. The A/B runs the *existing* expectations at both efforts and compares:

```sh
./run.sh behaviour-flows -n 3 -j 3 --judge --skill-effort low
./run.sh behaviour-flows -n 3 -j 3 --judge --skill-effort high
./report.sh behaviour-flows
```

`checks/searches.sh` is the sharpest mechanical reading available here, because a recorded search
that does not reproduce is exactly what a falsifier is told to hunt; the judged expectations about
affected-but-unchanged entries are the other half.

**One run has fired it end to end; the flag still ships unmeasured, and those are different
statements.** The mechanism is confirmed — `behaviour-flows/rails-only-small` at `--skill-effort
high` spawned the falsifier, folded in two of its challenges after verifying them against the files
(a dead `scope :archived`, and an actor claim the code did not support), came back 28/0/0, and leaked
nothing about the pass onto the fragment. What that does **not** establish is whether the pass earns
its cost: n=1, with no `normal` arm on the same sha to compare against. Whether `high` is worth a
blocked round of agents is the question the axis exists to answer, and until both arms exist the
honest claim is that the pass is *available*, not that it *helps*.

The one cost signal from that run, offered as an order of magnitude and not as a measurement: 866s
against the 345–490s this file records for early section runs — on a different sha and a different
model, so the comparison is suggestive at best. Run both arms before quoting a ratio.
Read § *Two page runs against `monolith-guard-chain`* before scoring it — recall on planted findings
was total in both runs there, so a fixture whose findings are all true and all plantable cannot show
a falsifier earning its keep. What would is a fixture planting **plausible-but-wrong invitations**,
which none of the four does; that belongs in § *Next cases worth adding*.

## Profiling one run

`seconds` on a results line is one number for a whole run. It can say a run got slower; it can never
say where. `profile.sh` reads the session transcript Claude Code already writes — nothing in the
skill is instrumented, and it works on runs that happened before it existed:

```sh
./profile.sh                                   # newest run in this directory
./profile.sh --rundir "$RUNDIR"                # an eval repetition, by its pinned session
./profile.sh --transcript <file.jsonl> --all   # any transcript
./profile.sh --list                            # what transcripts exist, newest first
./profile.sh --timeline                        # call by call, instead of the rollup
```

It splits wall clock four ways, and **the split is the finding.** One whole-page run against a real
39-file PR: **1284.7s, of which 1203.4s was the model and 81.2s was tool execution — and inside the
model share, 457.2s was streaming output while 746.2s was spent before a request produced its first
token.** 95 requests carrying an average 182k-token context. Making the harness faster cannot buy back
more than six percent of a run, and that six percent is the part already measured in tenths of a
second.

**Break that 746s down before drawing a conclusion from it, because "before first token" sounds like
prefill and mostly is not.** Hold thinking near zero and vary context: 77k costs 2.3s, 146k costs
2.8s, 274k costs 3.1s. Tripling the context buys 0.8s. Now hold context and vary thinking: requests
over 2000 thinking tokens averaged **56.9s** to their first block, requests under 200 averaged
**2.8s**. So the 746s is one small fixed cost plus a lot of reasoning:

| | |
|---|---|
| ~2.5s per request | fixed — queue and first-token latency. 95 requests ≈ **240s, 19% of the run, buying nothing** |
| the remainder | thinking, which is the product and not overhead |

Which leaves exactly one lever, and it is neither context nor scripts: **fewer requests.** An earlier
version of this section named context size as a second lever; the numbers above are what retired it.

The other reading from the same run: the slowest *tool call* was 4.5s (`git fetch`), while the slowest
*request* was 264.5s — 35k output tokens streamed into one `Write` of the page. **The request is the
unit, not the tool call**; a profile that ranked tool calls would have reported that run as nearly
free. Two `Write`s account for 328.7s of the 457.2s of streaming.

**What it attributes, and what it refuses to.** Publish stages are mechanical: an `Artifact` call is a
boundary, and boundaries cannot arrive out of order. The ten steps are not. In that same run
`ledger-rows.sh` — a step-10 signature — first ran at 4m15s and again at 13m, and
`references/page-template.html` (step 9) was read before `references/rails-nextjs.md` (step 5). A
counter that advanced on first sight of a marker would have reported step 10 at minute four. So the
activity table charges each request's model time to the bucket of the tool call that request *ended
in*, names the bucket by purpose rather than by position, and keeps the `≈` in its `≈ step` column.
Steps 4, 6 and 8 leave no mechanical trace at all and interleave with the rest; their cost is spread
across the other rows and **there is no row for them**, because a row would be a number with nothing
behind it. The bucket table lives inline in `profile.jq` next to the paragraph that qualifies it —
one place, so the two cannot drift.

Read a row with many thinking tokens against a trivial tool call as reasoning parked in front of a
cheap call, not as the cost of that call. The clearest instance in the recorded run is a `discover`
row: 107.1s and 9,565 thinking tokens in front of a `find` that executed in 0.1s.

**The transcript is an internal file, and this reads it anyway.** Nothing documents
`~/.claude/projects/<slug>/<session>.jsonl`, so `profile.sh` asserts what it depends on and prints
**no tables at all** when an assertion fails: no assistant timestamps is a FAIL, zero `tool_use` →
`tool_result` pairs is a FAIL naming the key that moved, and a signature that never fires — a page
published with no `coverage-gate.sh` call, or a quarter of model time landing in `other` — is a WARN
saying the bucket table is behind `SKILL.md` rather than a row of zeroes. A table built on a schema
that moved is worse than no table. Two figures come from the `cost-state` record and are printed
marked *session-wide*, because a session that ran review-map and then other work carries one cost for
both.

`run.sh` pins a session id with `--session-id` and records it, so a finished repetition can be
profiled afterwards: the human report lands in `$RUNDIR/profile.txt` beside `check.txt`, the machine
copy in `profile.json`, and seven scalars — `session`, `requests`, `model_seconds`, `tool_seconds`,
`ttft_seconds`, `stream_seconds`, `output_tokens`, `thinking_tokens` — go on the jsonl line, where
`report.sh` prints them as a third `time` block under the same group key. Per-bucket seconds stay in
`profile.json`: `report.sh` matches flat field names, and the bucket taxonomy describes the current
procedure rather than stating a fact about a run, so a column per bucket would make old lines and new
lines incomparable in the one file whose purpose is comparing across shas.

`seconds` is left exactly as it was. It is harness wall clock — fixture rebuild, `claude` startup,
`check.sh`, the judge — so it exceeds `model_seconds + tool_seconds`, and that difference is the only
measurement of the harness's own overhead there is. On the run that validated this, 163s against
158.2s: 4.8s of harness.

Eval runs need `--all`, and `--rundir` implies it. The driver inlines the section instructions instead
of invoking the skill, so those transcripts carry no `attributionSkill` and there is nothing to filter
on — which is also why `--all` is never the default: with the filter off, neighbouring work in the
same session is counted.

### The PR-528 rerun, and why its timing is void

The first attempt to measure the staged-fill and work-directory changes on a real target was a rerun
of the exact diff the baseline came from — fayron PR #528, `a963bf65...d831b8c6`, 21 files, same model
and effort. Same diff on both sides removes the largest variance source, which is why it was the right
target. **The timing still came out unusable, and the reasons are worth writing down.**

Two things did land, and they are mechanical enough to read off the transcript directly:

- The derived work directory is used verbatim — `W="${TMPDIR:-/tmp}/review-map/fayron-pr-528"`, **112
  uses of `$W` and zero `SCRATCH=` re-exports**, against seven in the baseline.
- The page is filled in rather than rewritten: one `Write` of `page.html` plus nine `Edit`s, with a
  new section written to its own fragment file and spliced. **88.4 KB of page bytes emitted against
  the baseline's 105.2 KB, and the page is never re-emitted** — though 16% is well under the 28%
  predicted from the redundancy in the baseline's second `Write`.

What makes the wall clock meaningless is everything else. The run **spawned an `Explore` subagent**,
and a blocking subagent's whole runtime lands in the parent's next before-first-token gap: one request
absorbed **997.5s, 41% of the run**, and five requests over 60s accounted for 64% of model time
against the baseline's 43%. It also made **zero `Artifact` calls** — the tool is not available under
`claude -p` — so it skipped the publishing the baseline did twice. Net 2435.1s against 1284.7s, which
is not attributable to anything in the prose.

Three lessons, in descending order of how much they cost:

1. **`claude -p` is not the harness for a page-scope timing comparison.** No `Artifact` tool means the
   run cannot do the last step, and a run that stops early is not a faster run.
2. **The subagent had no rule against it.** `CLAUDE.md` said the skill spawns none and treated that as
   settled; `SKILL.md` never said so, and a run duly reached for one. It is a hard rule now — with
   one carved exception, the per-flow falsifier at `--skill-effort high`, whose agents go out in a
   single message precisely because of this measurement.
3. **`--json` drops the diagnostics, and a consumer that ignores them gets a confident wrong answer.**
   The comparison script read `--json` and never printed the `WARN` about the session having split into
   two runs, so it compared one half of the new run against the whole baseline and reported a 50%
   improvement. The warning was there; nothing forced it to be read. The gap threshold is 45 minutes
   now rather than 15, because a single legitimate run held a 16.6-minute blocked turn.

### What the loop said about batching, and why almost none of it shipped

Worth keeping as a worked example, because the profile pointed at a real inefficiency and the obvious
fix still failed the measurement twice.

The profile found that a run issued **exactly one tool call per turn, across 95 turns, never two** —
while about 2.5s of every turn is fixed cost, so roughly 240s of that run was per-turn overhead. Claude
Code runs several `tool_use` blocks from one turn concurrently, so batching looked like free money.

It was not. Three runs per wording, one fixture, one model:

| `SKILL.md` prose | n | turns | model | quality |
|---|---|---|---|---|
| none | 1 | 9 | 114s | clean |
| a "probe wide" section, plus pointers in steps 2 and 5 | 3 | 15 | 142s | clean |
| the same, reworded to "consolidation, not volume" | 3 | 21 | 171s | clean |
| **only the narrow step-9 line, for excerpts** | **3** | **11** | **107s** | **clean** |

Quality never moved — 0.0 fail/run and 0.0 warn/run throughout. Turns moved the wrong way, twice, and
the *better-written* version was worse. Batching did start happening (up to five blocks in one turn,
where before there were none), so the instruction was followed; it simply cost more than it saved.

Two readings, and the second is the one to act on. The first wording said "running twenty probes you
may not need is cheaper than four adaptive rounds of five", which literally instructs a reader to probe
more — and recorded searches duly rose. But rewording it to lead with consolidation made turns *worse*,
which that explanation does not cover. What is left is that a section about turn efficiency in the
always-loaded file makes a run spend turns on turn efficiency, and a section eval has almost nothing to
batch, so the cost lands with none of the benefit.

So only the step-9 line survived, where the fan-out is real and named — the excerpts of one page are
independent by construction, and one run spent ten requests generating seven of them. It measures as
neutral, not as a win: 107s over three runs is the lowest figure recorded here, but the 9-turn baseline
is a single run and the honest reading of 11 against 9-10 is "no difference".

**The limit this ran into is the instrument, and it is worth stating before anyone re-runs the
experiment.** A section eval produces one fragment from the frozen upstream. It does no project
discovery and no tracing across a real diff, so the two phases with a genuine fan-out are exactly the
ones it cannot exercise — it can detect the cost of the prose and never the benefit. Deciding whether
batching helps needs a whole-page run against a fixture, profiled. Until that exists, the general
version stays out: on the only evidence available it is a regression, and "the benefit is somewhere the
harness cannot see" is an argument, not a measurement.

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

Three states, but **four milestones**, and the two numbers are unrelated: § 2 arrives one behaviour
flow at a time, so how many times a run republishes depends on how many flows the diff earns. A draft
snapshot is worth taking mid-§ 2 as well as at stage 1 — `golden/flows-partial-page.html` is what that
shape looks like, and `golden/flows-stubs-only-page.html` is the moment before it. Neither state is
visible to any check that reads the publish *sequence*, because none does: every check grades a
snapshot.

`--scope core` runs exactly the five checks the old single script ran, which is the comparison to make
if a page starts failing for a reason you did not expect.

## checks/

One script per rule family. Each prints `PASS` / `FAIL` / `WARN` / `SKIP` lines and nothing else;
`check.sh` decides which apply and adds them up.

| | Owns | Scope |
|---|---|---|
| `page-invariants.sh` | severity chips, verdict language, assurance language, evidence tiers, `data-path`, dead links, themes | page and fragment |
| `build-state.sh` | draft / final / stopped | page |
| `completeness.sh` | the gate, delegated to `scripts/coverage-gate.sh` | page |
| `excerpts.sh` | collapsed, summarised, tinted in all three themes, no range quoted twice, no syntax colouring written into the quotation, `data-lang` on unchanged blocks only, and a state tag that agrees with the diff — `Unchanged` never on a path the change touched, and no tag outside the generator's vocabulary | page and fragment |
| `behaviour-flows.sh` | § 2: no layer grouping, and the two review-unit guards, per unit | page and fragment |
| `start-here.sh` | § 3: one list, an order with reasons, entries that link into a flow, the cap | page and fragment |
| `blast-radius.sh` | § 4: a diagram, an affected list, pointers into the flows and their shape, recorded searches, and no reading order left here | page and fragment |
| `searches.sh` | whether a recorded search **reproduces** the entry it is offered for — re-run inside `--repo` | page and fragment |
| `before-approving.sh` | § 6: the cap of five, questions that are questions, commands that are commands | page and fragment |
| `rails-anchors.sh` | doc links against the catalogue and never standing alone; probes with no fabricated output, no unsandboxed write, and identifiers that exist in `--repo` | page and fragment |
| `diagram.sh` | template classes only, no literal colours, nothing off-canvas, labels that fit, a key behind every dashed node, the budget | page and fragment |
| `diagram-shot.sh` | renders each diagram in both themes to PNG | page and fragment |

Every one of them except `diagram-shot.sh` now has a Ruby twin that shadows it byte for byte —
see § *The Ruby port*.

`SKIP` is load-bearing. A check that cannot run on this input says so out loud — a fragment has no
`:root`, no ledger and no banner — because silently dropping it is how a fragment ends up reading as
thoroughly verified as a page.

**`run.sh` passes `--repo`**, so the three checks that need the repository run on a section fragment
rather than skipping: `searches.sh` re-runs the recorded searches inside it, `rails-anchors.sh` asks
whether the constants a probe names exist there, and `page-invariants.sh` asks git whether the head is
pushed — which is how the link rung finally became mechanical for section runs instead of a thing only
a reader could catch.

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

### rails-anchors.sh

The two framework anchors, and the one check whose allowlist lives in another file: it derives the
permitted documentation URLs from `references/rails-docs.md`, so a row added there is legal here
without touching this directory, and a URL a run invented is not. Beyond that it settles what a script
can settle about a probe — no fabricated output beneath a command nobody ran, no write outside a
sandboxed console, no production environment, and, given `--repo`, every constant and attribute a
probe names existing in the repository. That last one is `searches.sh`'s argument applied to commands
instead of searches: a plausible identifier is the failure mode, and it stays invisible until someone
pastes it.

It says SKIP on a page with neither anchor, which is most pages produced before this existed.

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

## The Ruby port

Every rule check in this directory now exists twice: as the `.sh` that `check.sh` and
`self-test.sh` still dispatch, and as a `.rb` beside it. The only one not ported is
`diagram-shot.sh`, which drives Playwright to render PNGs and is a driver rather than a rule.

The contract is **byte-identical output** — every line, the exit code, and stderr. That is
deliberate rather than fussy. The `PASS` / `FAIL` / `WARN` / `SKIP` strings *are* this
directory's product: they are what a maintainer reads when a wording change in the skill moves
a number, so a port that reworded them would be a rewrite of the thing under measurement,
dressed as a refactor.

`checks/equivalence.rb` is what holds that. It discovers pairs by name, then grades each over
two case sources: a sweep of every fragment in `golden/` and the real `page-template.html`, in
both `--page` and `--fragment`; and every row of `self-test.sh`, replayed with that row's own
arguments. The second source is not redundancy — the sweep never passes `--repo`, `--base` or
`--level`, so it would compare two SKIPs for `searches.sh`, whose entire rule is a relation
between the page and a repository, and would miss the brief level altogether. It reports
**1521 cases, 0 differing, across 10 of 12 checks**, and it names what is still shell on every
run — today `rails-anchors` — because a partial migration that printed only "0 differing" would
read as a finished one.

It runs the cases concurrently (`-j`, default `nprocessors` capped at 8) for the same reason
`run.sh` does: a thousand cases is two thousand processes, and serially that is over two
minutes, which is long enough that the oracle stops being run. 34 seconds is short enough. The
results are re-ordered before printing, because a diff report that arrives differently each run
is not a diff report.

### What it cost, per check

| Check | `.sh` code | `.rb` code | |
|---|---|---|---|
| `build-state` | 54 | 53 | −1 |
| `completeness` | 19 | 22 | +3 |
| `start-here` | 53 | 48 | −5 |
| `before-approving` | 60 | 57 | −3 |
| `blast-radius` | 68 | 74 | +6 |
| `excerpts` | 70 | 72 | +2 |
| `page-invariants` | 57 | 62 | +5 |
| `behaviour-flows` | 137 | 152 | +15 |
| `searches` | 163 | 215 | **+52** |
| `diagram` | 221 | 266 | **+45** |
| **total** | **902** | **1021** | **+119** |

Plus the library: `lib.sh`'s 55 code lines became 174 (`page.rb` 87, `check.rb` 87), and
`test_page.rb`'s 188 lines have no counterpart at all — 17 tests, 56 assertions, and **11 of 11
mutations of the library caught**. So the port is about 25% more code, and the honest summary is
that **Ruby did not make this smaller; it made it checkable.**

Where it grew is the interesting part. Seven checks came out within six lines of the shell,
three of them shorter. The two that grew by fifty are `searches` and `diagram` — which were the
densest and least readable shell in the directory, and the two most likely to be quietly wrong.
`diagram`'s SVG geometry is now arithmetic over named structs instead of a 130-line `awk`
program with a hand-rolled `attrnum` function; `searches`' dialect selection is a method with
the reason above it rather than a nested `case` on glob patterns.

The counterweight is the census: **193 external commands** across the shell checks became
**one** method, `Check#shell`, used by exactly two of them. Everything else is now in-process.

### What the port had to keep, and nearly did not

- **`awk`'s rule order is the semantics.** Its print rule ran before its close rule, so a
  region includes the line that ends it. `Page#from`'s `stop_after` is awk's `seen` guard, not
  a knob: section 6's author-question region is anchored on an `<h3>` and terminated by `<h3>`,
  so without it the region comes back empty and that whole part goes unchecked.
- **Occurrence counts are not line counts.** `excerpts.sh` used `grep -o | wc -l` where other
  checks use `grep -c`, and it compares `<details>` against `<summary>` — so a page with two on
  one line must count two. Every call site now says which it means.
- **A `String` pattern is a fixed string.** The shell used `grep -F` for the build-state banner
  and `grep -E` elsewhere. `Page#has?` honours that, so a literal `.` or `?` in a future banner
  sentence cannot start matching what it does not say.
- **`length()` in mawk counts bytes.** `diagram`'s label-width arithmetic uses `bytesize` for
  that reason: a label carrying an em dash would otherwise be measured differently here than
  there, and the width check is what catches the commonest hand-authored SVG defect.
- **`awk` numbers stringify through `CONVFMT`.** `120` prints as `120`, not `120.0`, so every
  number reaching a `diagram` message goes through one `%.6g` helper.
- **The matching stays in `grep`.** Ruby has no BRE, and `\|` is alternation in grep's default
  dialect but a literal pipe in `rg`. Translating a page's own recorded search into a Ruby
  regexp would silently change what that page claims to have searched for, so `searches.rb`
  ports the parsing, the orchestration and the reporting, and hands every pattern to the tool
  whose dialect it was written in.
- **`completeness` still shells out to `scripts/coverage-gate.sh`.** That script is runtime
  code, run by `SKILL.md` step 10 inside the user's project. Reimplementing the comparison
  would give the completeness invariant two implementations that could disagree — which is the
  failure the delegation exists to prevent.

### Two intentional differences

Both were found by constructing inputs the corpus does not contain, which is the only way to
find them — `equivalence.rb` is silent on behaviour no fixture exercises, and saying so is more
useful than a clean number.

**Array iteration order.** The shell iterated two arrays with `for (key in array)`, whose order
POSIX leaves unspecified — mawk walks `diagram.sh`'s coordinate names as `x1 cy y2 x2 y x y1 cx`.
It is reachable: a `<text x="900" y="300">` in an 880×200 viewBox is off-canvas on both axes, and
the shell reports `y` first where the Ruby reports `x`. Nothing in `golden/` or the template has
that shape, and the same goes for the per-section diagram budget, which needs two sections both
carrying diagrams. The Ruby uses declaration order and document order. That is a narrowing
rather than a divergence: the shell's output in those cases was whatever the local `awk` did.

**grep's binary-file heuristic.** `diagram.sh` finds its diagrams with `grep -n '<svg'`, and on
a file containing NUL bytes grep prints `binary file matches` instead of line numbers — so the
shell reports `SKIP  no diagrams in this input` on a page whose diagrams are all there, and
warns on stderr while doing it. The Ruby reads the file and checks them. This is declined
deliberately: reproducing the heuristic would mean writing a NUL-byte test into `Page` in order
to make the diagram rules silently stop firing, and a published page is HTML written by the
skill. Only `diagram` is affected, because it is the only check that reads line numbers out of
grep rather than asking a yes/no question.

### What the first rebase proved

`main` moved twelve commits while this branch sat open, and it changed six of the nine checks
the port shadows plus `lib.sh` — a new `strip_comments` helper, a section-4 region that now
also ends at the merged tail's sub-anchors, `git grep` accepted as a recorded search, a
non-breaking hyphen decoded out of citations, `svg.pr-mark` excluded from the diagram census,
and the primer callout dropped before the unit census. None of that was announced to the port.

`equivalence.rb` named all of it, per check, in thirty seconds:

```
blast-radius       0 identical, 146 differing     page-invariants  0 identical, 147 differing
diagram          129 identical,  21 differing     searches       141 identical,   4 differing
behaviour-flows  150 identical,   3 differing
build-state, completeness, start-here, before-approving, excerpts    0 differing
```

Two things in that are the whole argument for keeping the shell alongside the port. The five
checks `main` did not touch came back **untouched and green**, which is what makes the other
five a *finding* rather than a suspicion. And `rails-anchors.sh` — a check that did not exist
when the port was written — appeared in the "still shell" line without anyone adding it,
because pair discovery is by filename.

Re-porting the drift also found two library defects the corpus could not have:

- **`Page#scan` returned capture groups.** `grep -o` prints the whole match; `String#scan`
  returns the groups as soon as a pattern has any, so the new assurance rule reported
  `independently` where the shell reported `independently verified`. One wrong message, and one
  per future pattern — so the fix went into `Page`, not into a rule that has to remember
  `(?:...)`. Two call sites that scan a plain `String` still need the non-capturing form, and
  say so where they are.
- **`Page#without`'s closing line was unpinned.** Inverting it changed nothing anywhere in the
  1454 cases, so the sweep stayed green; a mutation of the library caught it, and it now has a
  test. That is the division of labour the two mechanisms are for — the corpus grades behaviour
  the fixtures reach, and mutation grades the library itself.

### And again, the next day — this time caught in CI

`main` moved twice more while the branch was open, and the second time the CI job added the day
before was what found it. `equivalence.rb` failed the PR with **1471 identical, 46 differing**,
all `excerpts`, every diff `sh only`. GitHub runs `pull_request` CI on the merge ref, so the job
was grading the port against a `main` two commits newer than the branch, including three golden
fixtures the branch had never seen.

The drift was PR #12, and it is the most interesting one yet because it is a defect of exactly
the kind this whole directory exists to catch: `scripts/excerpt.sh --at` hard-coded `Unchanged`
on every `--source` block — a claim about the diff it had never looked at — and a run published
`db/structure.sql:304-313` tagged `Unchanged` on a page whose own ledger listed that file as
changed. Verbatim bytes under a false label, which is the one defect in an excerpt a reader
cannot catch, because an excerpt reads as *more* trustworthy the closer they look at it. So
`excerpts.sh` gained both halves of the fix and `excerpts.rb` had neither:

- **lexical** — a `--source` tag must be one of `Unchanged`, `Added`, `Removed`, `At head`,
  `Before the change`, and a `--diff` tag must be `Changed`. Anything else was typed.
- **relational** — every `Unchanged` against the changed set, taken from `git diff --name-status
  -M` when `--repo` and `--base` are given and otherwise from the page's own `data-path` ledger,
  which the completeness invariant guarantees is the whole diff.

Three details of that were reasoned about rather than observed, so each was tested on purpose
after the corpus went green: a rename contributes **both** paths (`R100 old new`), verified in
both directions against a scratch repository; several mislabelled blocks join with `"; "`; and
the changed set is matched **whole-line, never substring**, because `api/Gemfile` sits inside
`api/Gemfile.lock`.

### Two latent defects the port surfaced, then fixed in both

Reproducing the shell exactly meant copying two places where a **failing `git` was read as an
answer**. The port copied them deliberately — a port may not quietly change a verdict — and they
were then fixed in the shell and the Ruby together, with a `self-test.sh` row each, which is the
only way a change like this is allowed to happen.

**`excerpts.sh` — a false PASS.** The relational rule tested the exit status of a pipeline ending
in `sort`, which succeeds whatever `git` did. So an unresolvable `--base` produced an *empty*
changed set, matched nothing, and reported `no excerpt labels a changed file Unchanged, against
the diff`. Measured on the fixture that plants the real defect:

| `excerpt-unchanged-changed-file.html` | exit | verdict |
|---|---|---|
| no `--repo`, ledger path | 1 | FAIL — defect caught |
| `--repo` + unresolvable `--base`, **before** | 0 | **PASS — defect masked** |
| `--repo` + unresolvable `--base`, **after** | 1 | FAIL, against the ledger, with a WARN naming the git failure |

A stale or unfetched base SHA turned a caught defect into a clean bill of health, on the one rule
whose purpose is catching a label the diff contradicts. Now `git`'s own status is tested, the rule
falls back to the ledger, and it says out loud that it did — which matters because `run.sh` passes
`--repo` and `--base` on every page run, so without the WARN a wrong base silently downgrades
every run to ledger-only.

**`page-invariants.sh` — a false PASS *and* a false FAIL.** `git branch -r --contains` written with
`|| true` collapsed "no remote contains it" and "git said nothing" into one answer, so an
unreadable repo read as **unpushed**: a page with no permalinks got
`unpushed head: citations are plain text` and a page with them got
`emits GitHub permalinks, but the head commit is on no remote`. Both verdicts came from an answer
git never gave. The three states are separated now and the rule refuses rather than guesses.

The four rows are conditions rather than markup, so they use `self-test.sh`'s fifth column with an
unresolvable ref, and **each was confirmed red against the unfixed shell first** — a row that
passes before the fix pins nothing. 88 ok → 92 ok.

### What is left

`.github/workflows/validate.yml` runs both halves of that on every push, in a third job beside
`manifest` and `checks`: the library's tests, and `equivalence.rb` over all 968 cases. It is the
job that earns its place *because* the port coexists — `check.sh` still dispatches only the `.sh`,
so nothing else in the repository notices when an edit to one makes the pair disagree. Ruby is
pinned rather than taken from the runner image, because `minitest` is a bundled gem rather than a
default one. That job is deleted along with the `.sh` files, at which point the library's tests
become the whole story.

`rails-anchors.sh` is not ported — 517 lines and 21 self-test rows, the largest check in the
directory, and porting it while the oracle was red would have been new work on top of a broken
signal. `equivalence.rb` names it on every run, so nothing about that is hidden.

The nine ports coexist with their shell originals, deliberately: `equivalence.rb` needs both
sides to compare, so deleting the `.sh` would remove the oracle at the moment the port is least
proven. Flipping `check.sh` and `self-test.sh` over and deleting the shell is a separate change,
and the reason it is separate is that it is mostly a **documentation** edit — these scripts are
cited by filename in `SKILL.md`, `references/report-format.md`, this file, `golden/README.md`,
`drivers/*.md` and `frozen/monolith-guard-chain/target.md`. The code is the cheap half.

The drivers — `run.sh`, `report.sh`, `judge.sh`, `verdict-tally.sh`, `profile.sh` and the two
`.jq` programs — are not ported and are the weakest case for it: they are process orchestration
and JSON handling, which is where the shell is least bad.

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

`rails-anchors` reuses the `behaviour-flows` scope rather than adding one, the way `brief-tail` reuses
`blast-radius`: the anchors live inside the review unit's fields, so what it grades is a § 2 fragment.
It is a case about restraint more than presence — the mechanical half already settles whether an anchor
is real, and what a reader has to settle is whether it was worth making.

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
5. **A fixture that plants a plausible-but-wrong invitation.** Every fixture here plants findings
   that are *true* and outside the diff, which measures recall. `--skill-effort high` exists to catch
   the opposite thing — a claim the run would confidently make and that the code contradicts — and
   nothing here can show it working. The shape wanted is a file that reads as a consumer of the
   changed thing and is not one: a serializer whose field is overridden downstream, a scope shadowed
   by a default, a caller behind a guard the change cannot reach.
6. **A `diagrams` case for `monolith-guard-chain`.** `behaviour-flows` and `blast-radius` now have
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

`profile.sh` is the one piece here written against a schema nobody publishes: the session transcript
under `~/.claude/projects/`. So it is the first thing to break after a Claude Code upgrade, and it is
built to break loudly — see § *Profiling one run*. Everything it reports is derived from timestamps
and `usage` on records the transcript already carries, so there is nothing to migrate if it does
break, only a reader to repair. The fixtures, the frozen upstream and `checks/` remain the durable
part.
