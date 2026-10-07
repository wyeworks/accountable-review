# Evals

Three layers, because the thing being measured is prose, and prose has a part a script can settle
and a part it can't.

| Layer | Input | What it settles | When it runs |
|---|---|---|---|
| **Mechanical** | a page or a fragment, and the repository | Yes-or-no facts: the completeness gate, no verdict language, tiers, excerpts, links, the impact panel's shape | Every push, in CI (`bin/evals offline`) |
| **End to end** | a real merged OSS pull request | A whole run of the skill, checked mechanically, then judged per aspect by an LLM anchored in the checkout | Before a major release (`bin/evals e2e`) |
| **Calibration** | a certified gold page, plus copies each planting one defect | Whether a judge says what a person already decided it should say | Whenever a judge or its model changes (`bin/evals calibrate`) |

```
evals/
├── check.rb                 dispatcher over checks/, one tally
├── checks/                  one Ruby script per rule family, plus self-test.rb and frozen.rb
├── golden/                  fragments with known verdicts, for self-test.rb
├── e2e/
│   ├── prs.yml              the pull requests: pinned base and head, role calibration | eval
│   ├── run.rb               generate → check → judge → profile → one jsonl line
│   ├── judge.rb             one judge, one page
│   ├── judges/              what-changed.md is the one working judge; IDEAS.md is the rest
│   ├── calibrate.rb         each judge against gold and its planted defects
│   ├── calibration/         <id>/gold.html, defects/*.patch, labels.yml; status.json
│   ├── verdicts.rb          reads one verdicts.json; shared by judge.rb and self-test.rb
│   ├── report.rb            results/e2e.jsonl as an HTML page
│   └── history/             one summary per release, committed
├── profile.sh / profile.jq  where one run's time and money went, from the session transcript
├── verify-catalogue.sh      the documentation catalogues, opened. Needs network
├── trigger-eval.json        should-trigger / should-not-trigger queries — not wired to anything
└── results/                 one jsonl line per run or calibration pass (gitignored)
```

## What this replaced, and why

Until 1.0.2 this directory had a second harness: six synthetic fixture repositories built by a
2,900-line `make-fixtures.sh`, each planting findings outside the diff; seven whole-page cases in
`evals.json` that a person drove and graded by hand; and six section cases that produced one
section from a hand-written frozen upstream, run three times by `run.sh` and judged by `judge.sh`.
The section cases had graded sections of the page the agenda replaced and sat unrun in `deferred/`;
the page cases recorded nothing. **None of it was being used**, so it is gone rather than deferred
again. It is all in the history at the commit before this README was rewritten.

Three things about it were right and are kept: **a result line is stamped with the sha of the prose
that produced it**, so a number is attributable to a version; **the judge is anchored** — it runs
inside the repository and settles a claim by opening the file; and **three runs, not one**, because
defect discovery is sampling and variance is the measurement.

Two things were wrong, and they are why the replacement looks the way it does:

- **Synthetic fixtures only plant true findings, and they never reach link rung 1.** Every fixture
  had no remote or an unpushed branch, so no real permalink, no withheld-diff routing and no
  `#diff-` fragment was ever exercised by a whole run. A real merged pull request on GitHub
  exercises all of it, and every citation on the page resolves for whoever reads the report.
- **A judge nobody checked is a number generator.** `judge.sh` was never tested against an answer a
  person had already decided. Calibration is that test.

What went with the fixtures, and is still covered only mechanically, is listed in
`e2e/judges/IDEAS.md` § *What retiring the synthetic fixtures lost*.

## One command per scenario

`bin/evals` at the repo root is a dispatcher over everything in here. It owns the paths and nothing
else: every flag and every rule stays in the script it calls.

```sh
bin/evals offline                          # every no-model suite. What CI checks. About a minute and a half.
bin/evals offline frozen                   # or just one of them
bin/evals e2e                              # the PRs in e2e/prs.yml
bin/evals e2e discourse-43002 -n 3 -j 3    # three whole runs of one, at once
bin/evals calibrate                        # every judge against its gold page
bin/evals report                           # the HTML report
bin/evals catalogue elixir                 # the maintenance pass, per catalogue (rails | elixir | rust). Needs network.
```

`offline` is about a minute on this machine, and it is not evenly spread: `setup-ci` is 48s of it
because its self-test re-runs the whole suite once per deliberate break (issue #71 is the port that
fixes that), `frozen` is 11s over 1,873 cases, and the Ruby suites together are 3s. It runs every
suite even after one fails and exits non-zero if any suite **did not run** — a suite whose
interpreter is missing is named in the tally rather than silently absent. Its `parity` line fails
when `.github/workflows/validate.yml` names a suite the dispatcher's table does not cover.

## End to end

`e2e/run.rb <id>` does one repetition as:

1. a detached worktree of the PR's repository at head, from a blobless clone in `$EVAL_CACHE`
   (default `~/.cache/accountable-review-e2e`);
2. **`ci/generate-review-map.sh --output`** — the skill run exactly as CI runs it, with the plugin
   loaded from this checkout. That is the one non-interactive path, and it is why this harness does
   not share the old one's blind spot: under a bare `claude -p` there is no `Artifact` tool, so a run
   could never do its last step (§ *The PR-528 rerun* below);
3. `check.rb --final --page --repo --base`;
4. every judge in `e2e/judges/`, **blind to step 3**;
5. `profile.sh` over the session, which `run.rb` pins with `--session-id` through a `--claude-bin`
   wrapper so the transcript can be found afterwards — parent and subagents both;
6. one line in `results/e2e.jsonl`.

While it runs, `e2e/progress.rb` draws a live board, one line per repetition: elapsed time against the median of earlier runs of the same PR, the latest tool call mapped to what it is for, falsifiers spawned, and checkpoints written against pending. Every field is read from the pinned transcript or the staged page, never guessed, and in a pipe or a CI log it prints one line per change instead.

When it ends it prints a verdict per repetition and overall, and exits on it: **✅ PASS** when a page was generated, `check.rb` reported no FAIL and every criterion of every calibrated judge passed; **❌ FAIL** (exit 1) otherwise, with the reasons listed; **🔍 LOOK** (exit 0) when a calibrated judge answered `unclear`, because a person has to read that before anyone knows. Warnings, an uncalibrated judge and the § 01 word count are shown and never decide it. `e2e/summary.rb` owns the rule.

Everything a repetition produced stays in its directory under `$EVAL_OUT` (default
`$TMPDIR/review-map-e2e/<id>/<batch>-r<n>/`): the page, `check.txt`, the judges' raw replies and
parsed verdicts, the profile, the generation log. `report.rb` links to all of it.

**The adapter needs a credential in the environment**, `ANTHROPIC_API_KEY` or the
`CLAUDE_CODE_OAUTH_TOKEN` that `claude setup-token` prints, because it is written for a runner
nobody is logged into. `run.rb` checks first and says so.

### The stamp

Every line carries `plugin_version`, `skill_sha` (with `+dirty` when the skill has uncommitted
edits), the skill's `effort`, the producing `model` (`ambient` when none was named — which is not a
fact about anything, so name it when you intend to compare), and per judge its file's sha, its
model and whether it is calibrated. `report.rb` groups by the first four, so a row measured on one
version of the prose is never averaged into another; a judge column is only coloured when that
judge is calibrated at the sha and model it ran at.

### The judge

One judge per aspect of the page, each a file in `e2e/judges/` with its pinned model, the section it
grades and at most five criteria in front matter, and the prompt below. **`what-changed.md` is the
only working one**, deliberately: one judge calibrated against a gold page tells us whether the
method works before it is copied six times. `IDEAS.md` records the other five and what a planted
defect for each would look like.

What makes the verdicts worth anything is not the rubric, it is the anchoring. The judge runs
**inside the checkout at head**, with Read, Grep, Glob and read-only `git`, so "is this claim right"
is settled by opening the file the claim cites. Take that away and it decays into a second opinion
about prose. It never sees the mechanical results: two independent readings beat one reading
anchored to the other. And it cannot load a skill or an MCP server — `--disable-slash-commands` and
`--strict-mcp-config` — because a judge on a machine with this plugin installed must not be able to
run review-map on the page it is grading.

Three verdicts, not two. `unclear` exists so the judge does not have to guess — including when it
cannot tell what a criterion is asking of this page. A judge forced into a binary invents
confidence, and an invented verdict is worse than an honest gap because it survives into a number.

And a `notes` field, for when **the criterion is the problem** rather than the page. That is not a
courtesy: it corrected this repository's ground truth twice in the old harness's first two judged
runs — once reporting a factual error in a caption that no expectation covered, once rejecting the
wording of an expectation outright as false at line granularity. Read `notes` before the verdicts;
`report.rb` prints them above the table for that reason.

**Counting is never a criterion.** § 01's word budget is measured by `run.rb` (`changed_words`,
guidance 80–160) and shown beside the verdicts, not asked of the judge: a grader asked to verify
thirty things does all of them badly, and the mechanical ones are what it is worst at.

`e2e/verdicts.rb` does the parsing, recovering a fenced or prose-wrapped reply in memory and keeping
the raw one on disk, and `checks/self-test.rb` exercises it against `golden/verdicts-*.json` without
a model — a tally that reads a truncated file as "no fails" is the same defect as a check that
always passes, and worse here because what it emits looks like a measurement.

## Calibration

`e2e/calibration/README.md` owns the procedure. The shape: each calibration PR — **held out**, so
never in the eval set — has a gold page a person certified criterion by criterion, and one patch per
planted defect against it. `calibrate.rb` runs each judge three times on gold and on every variant.
**Specificity**: gold passes every criterion at least twice. **Sensitivity**: each variant's targeted
criterion fails at least twice. Both hold, or the judge is uncalibrated, and `status.json` records
the judge file's sha and model — so editing a judge uncalibrates it, which is the point. Editing the
rest of the instrument does not yet, and `e2e/calibration/README.md` § *Known gaps* says what that
and the masthead leave unmeasured.

**There is one calibration PR, `discourse/discourse#43002`**, chosen because its claims are easy to
check by hand. Its gold page is the unedited output of one run, certified by a person on 2026-09-30
(`calibration/discourse-43002/gold.yml`), and `what-changed` passed calibration against it and its six
planted defects on 2026-10-02. Making another is a real run and a person's reading, and
`calibration/README.md` has the steps. Gold is not `examples/` — those are regenerated when the format
moves, and gold has to stay put as long as its patches apply.

## Before a release

Before a **major** release: `bin/evals calibrate`, then `bin/evals e2e <id> -n 3 -j 3` for every
`eval` PR, then `bin/evals report --history <version>`, and commit the history file. Read the
report's notes before its numbers.

What that costs, from § *The money is a different ranking* below: one generation is 20–40 minutes
and 30–39M cache-read tokens, plus 17–23% for the falsifiers at the default effort, and each judge
call is a fraction of that. Three repetitions of five PRs is fifteen generations — an afternoon with
`-j`, and a bill worth deciding on rather than discovering.

## Profiling one run

`seconds` on a results line is one number for a whole run. It can say a run got slower; it can never
say where. `profile.sh` reads the session transcript Claude Code already writes — nothing in the
skill is instrumented, and it works on runs that happened before it existed:

```sh
./profile.sh                                   # newest run in this directory
./profile.sh --session <uuid> --all            # an e2e repetition, by the session run.rb pinned
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

Which leaves exactly one lever **on the clock**, and it is neither context nor scripts: **fewer
requests.** An earlier version of this section named context size as a second lever; the numbers
above are what retired it — *for wall clock*, which is the only thing they measured.

### The money is a different ranking of the same requests

Context is billed once per request, so a run does not pay its context once — it pays it per request.
On three real `review-map` runs (fayron #529 and #21819999, oli-torus), the parent spent **30-39M
cache-read tokens against 160-190k of output**, carrying **250-305k of context across 121-141
requests**. Cache reads are roughly **70% of the bill**. So *when* a file is loaded matters as much
as whether, and the paragraph above is true of the clock and false of the invoice.

Both tables print, and they rank differently. On fayron #529 the `search` bucket was 66% of cache
reads and 75% of model seconds — agreeing — while `publish` was 4% of the money and 1% of the time.
A change that helps one can be neutral for the other, so read them side by side and quote whichever
question you are actually answering.

**`profile.sh` also reads the subagent transcripts now**, under `<session>/subagents/`, which nothing
used to. The falsification pass is the case that matters: **0.9% of blocked wall clock and 17-23% of
every cache-read token**, over 145-216 requests. Reporting only the first is why the pass read as
free, and a run cost taken from the parent transcript alone is a fifth to a quarter short. **Both
numbers were measured against the old seam**, where a falsifier read a published flow section rather
than an analysis note, so the token figure is an upper bound nobody has re-measured; the wall-clock
one should hold, since what makes it small is that the parent keeps working. The report
prints the model those transcripts recorded, because `--agents` accepts a `model` key it may not
honour — the transcript is the check, not the flag.

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

`e2e/run.rb` pins a session id with `--session-id`, through a one-line `--claude-bin` wrapper handed
to `ci/generate-review-map.sh`, so a finished repetition can be profiled afterwards: the human report
lands in its run directory as `profile.txt`, the machine copy as `profile.json`, and seven scalars —
`requests`, `model_seconds`, `tool_seconds`, `ttft_seconds`, `stream_seconds`, `output_tokens`,
`thinking_tokens` — go on the jsonl line beside the session. Per-bucket seconds stay in
`profile.json`, because the bucket taxonomy describes the current procedure rather than stating a
fact about a run, so a column per bucket would make old lines and new lines incomparable in the one
file whose purpose is comparing across shas.

`seconds` on the line is harness wall clock — worktree, `claude` startup, `check.rb`, the judges —
so it exceeds `model_seconds + tool_seconds`, and that difference is the only measurement of the
harness's own overhead there is.

`run.rb` passes `--all`, and there it is exact rather than loose: the session is pinned to one run,
so there is no neighbouring work for the `attributionSkill` filter to exclude. `--all` is still never
the default, because on an ordinary interactive session it would count everything else done there.

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
fix still failed the measurement twice. It was measured with the retired section harness, so read
"section eval" below as that instrument; the lesson about the instrument is the part that transfers.

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
batching helps needs a whole-page run, profiled — `bin/evals e2e` and `profile.sh` are that
instrument now, and nobody has run the experiment on them yet. Until someone does, the general
version stays out: on the only evidence available it is a regression, and "the benefit is somewhere the
harness cannot see" is an argument, not a measurement.

## checks/

One script per rule family. Each prints `PASS` / `FAIL` / `WARN` / `SKIP` lines and nothing else;
`check.rb` decides which apply and adds them up.

| | Owns | Scope |
|---|---|---|
| `page-invariants.rb` | severity chips, verdict language, assurance language, evidence tiers, `data-path`, dead links, themes | page and fragment |
| `build-state.rb` | draft / final / stopped | page |
| `completeness.rb` | the gate, delegated to `scripts/coverage-gate.sh` | page |
| `excerpts.rb` | collapsed, summarised, tinted in all three themes, no range quoted twice, no syntax colouring written into the quotation, `data-lang` on unchanged blocks only, and a state tag that agrees with the diff — `Unchanged` never on a path the change touched, and no tag outside the generator's vocabulary | page and fragment |
| `start-here.rb` | § 03: one list, an order with reasons, entries that link into a checkpoint, the cap of three to seven | page and fragment |
| `impact-paths.rb` | § 04's figure: 1-3 paths, one per `.ip-card` and each with its own lane labels, each starting in the diff, passing through unchanged code and ending at one observable behaviour, every edge labelled with a causal verb, labels rather than prose, no citations and no SVG inside the panel. It grades `figure.impact` only, so a checkpoint's `figure.chain` is invisible to it by scope | page and fragment |
| `figures.rb` | a checkpoint's figure: at most one per checkpoint, of a known kind — chain, converge, lifecycle, structure — each holding its shape and caps, a locator on every code node and transition and never on an outcome or an invariant, no `.ip-aff` in a chain or a lifecycle, no connector between a converge's paths. It warns on a converge with no recorded search on its page, a transition named after its callback, and a `.cv-note` that grades. The tenth check, and the first to read a `figure.chain` on a published page | page and fragment |
| `searches.rb` | whether a recorded search **reproduces** the entry it is offered for — re-run inside `--repo` | page and fragment |
| `rails-anchors.rb` | doc links against the catalogue and never standing alone; probes with no fabricated output, no unsandboxed write, and identifiers that exist in `--repo` | page and fragment |
| `link-form.rb` | the href against the citation it sits on: the span its text names, a `#diff-` fragment that hashes back to a path in the diff, and no anchor into a diff GitHub withholds | page and fragment |

All Ruby, with `lib/review_map/` as their shared library — see § *checks/ is Ruby* for how they
got that way, and for the four defects that the byte-for-byte corpus alone could not have found.

**Six checks were deleted with the page shape they graded** — `behaviour-flows.rb`, `reach.rb`,
`before-approving.rb`, `brief-budget.rb`, `diagram.rb` and `diagram-shot.rb`. The first four keyed on
markup the agenda does not have. The last two would have SKIPped forever, and a check that can only
say *nothing to look at* is worse than none: it reads as verified.

**What went with `brief-budget.rb` is worth keeping in mind before writing its successor.** Its
verdicts were split by design — shape fails, length warns, the floor fails — because a hard failure
on length teaches a run to drop a claim to get under a number, which is worse than the long page the
rule was written to prevent. The agenda budget is prose in `report-format.md` with no check behind it
at all, which is the honest state until someone measures published pages rather than arguing from
component caps. **The number a successor must never grade is the checkpoint count.**

`SKIP` is load-bearing. A check that cannot run on this input says so out loud — a fragment has no
`:root`, no ledger and no banner — because silently dropping it is how a fragment ends up reading as
thoroughly verified as a page.

**`e2e/run.rb` passes `--repo` and `--base`**, so every check that needs the repository or the diff
runs on a generated page rather than skipping: `searches.rb` re-runs the recorded searches inside the
checkout, `rails-anchors.rb` asks whether the constants a probe names exist there,
`page-invariants.rb` asks git whether the head is pushed, and `link-form.rb` grades all of its rules —
the span a citation names, the `#diff-` fragment against a real path, and no anchor into a diff GitHub
withholds. The last two could never grade on the retired fixtures, which had no pushed head; on a
merged OSS pull request they grade every citation. Given a fragment and `--repo` alone, only
`link-form.rb`'s first rule grades and the rest SKIP, which is the right way round.

`searches.rb` and `link-form.rb` are the two checks whose rule is a relation between the page and a
repository. `link-form.rb` is also the reason `golden/links-repo.sh` exists: the third of its rules
cannot be graded against files alone, so that fixture is a real two-commit repository, built under
`TMPDIR` with every commit field fixed so its base SHA is stable for `frozen.rb`, and expanded into
the cases file as `@REPO@` by `lib/review_map/fixture.rb`. A rule that could only ever SKIP in
`self-test-cases.txt` is what that file exists to prevent. `searches.rb` is the one whose *coverage*
has to be reported as well: it prints how many entries it skipped as pointers,
how many it could not resolve to a file, and — when nothing was recorded at all — that provenance was
unverifiable rather than false. A handful of FAILs over an unstated denominator would read as a clean
sweep of everything else.

### rails-anchors.rb

The three framework anchors, and the one check whose allowlist lives in another file: it derives the
permitted documentation URLs from `references/rails-docs.md`, so a row added there is legal here
without touching this directory, and a URL a run invented is not. Beyond that it settles what a script
can settle about a probe — no fabricated output beneath a command nobody ran, no write outside a
sandboxed console, no production environment, and, given `--repo`, every constant and attribute a
probe names existing in the repository. That last one is `searches.rb`'s argument applied to commands
instead of searches: a plausible identifier is the failure mode, and it stays invisible until someone
pastes it.

§ 8 is the primer callout `--mentor` admits, and it is the part of this script that grades a
component rather than a URL: that every primer sits inside a checkpoint, carries exactly one
documentation link and one repo `file:line` of its own, holds no runtime probe, brings no logotype
back, and that the page stays inside one-per-checkpoint and three-per-page. The rule with the
longest reach is the smallest: **a `pre.demo` may sit only inside a primer**, because a demo's
result line is legal purely through its receiver, and outside the callout nothing constrains the
receiver. That arm runs on every page, primer or not — a loose demo on a page with no primer at all
is the worst version of the defect rather than an inapplicable one, so it asserts where the rest of
this script would SKIP.

It says SKIP on a page with no link and no probe, which is most pages produced before this existed.

## checks/self-test.rb

Runs the checks against `golden/`, where every fragment plants exactly one defect, and asserts the
verdict. No model, about a second, and it belongs in CI: **a check script that always passes is worse
than none**, because it turns an unchecked rule into one the reader believes is checked.

Adding a check means adding a golden fragment that makes it fire. Adding a golden fragment means
watching its keyword: two of the first eight passed for the wrong reason because their own `aria-label`
contained the word the check greps for.

## checks/ is Ruby

Every rule check, the dispatcher and the suite. `check.rb` decides which checks apply and adds
up what they printed; `self-test.rb` asserts a verdict per row of `self-test-cases.txt`;
`lib/review_map/` is the shared library and `lib/test/` its tests. What stayed shell stayed for
a reason: `profile.sh` is process orchestration and JSON, which is the shell's strongest ground,
and `verify-catalogue.sh` opens URLs and is documented as not a check. The shell orchestration that
used to sit beside them — `run.sh`, `report.sh`, `judge.sh`, `verdict-tally.sh` — went with the
synthetic harness, and its replacement under `e2e/` is Ruby.

### How it was done, and why that matters more than the result

The port ran beside the shell for its whole life, and every step was graded byte for byte —
every line, the exit code, stderr — by an `equivalence.rb` that discovered pairs by filename and
replayed two case sources: the whole of `golden/` and the real `page-template.html` in both
kinds, plus every row of the case table with its own `--repo`, `--base` and `--level`. It
finished at **1935 identical, 0 differing across 12 of 12** and was then deleted, because with
one implementation there is nothing left to compare against.

That contract — byte-identical output — is why this reads as a refactor rather than a rewrite.
The `PASS` / `FAIL` / `WARN` / `SKIP` strings *are* this directory's product: they are what a
maintainer reads when a wording change in the skill moves a number, so a port that reworded them
would have rewritten the thing under measurement while claiming to preserve it.

**The corpus is frozen rather than lost.** `checks/frozen/` holds every case's exact output,
recorded from the Ruby at the moment equivalence reported zero differences — which makes those
files a record of what the *shell* did, transcribed by a port proven equal to it.
`checks/frozen.rb` verifies against them and `--freeze` re-records. Whole output rather than a
digest, deliberately: the diff of those files in a pull request says which cases moved and how,
so re-freezing is a reviewable act rather than a hash nobody can read.

**Eleven checks, not twelve**, and the twelfth is the rule this corpus has: *a record must be a
function of the input.* `diagram-shot` is a function of the machine — it says `no Chrome found`
on a container without a browser, `no diagrams to render` on one with a browser and a fragment
carrying no `<svg>`, a `PASS` per rendered PNG where Chrome works, and a `FAIL` per image where
Chrome starts and cannot write. This repository has produced three of those four for the same
input. It also renders as a **side effect**, six PNGs per case into `references/shots/`, which a
read-only sweep must not do.

Its first freeze recorded the "no Chrome" line 162 times, from a container that has none, and
CI — whose runner ships Chrome — went red on all 162 at once. The comment that caused it was in
`diagram-shot.rb` and read *"CI has no browser"*: a claim about the world, written down years
after it stopped being true, believed by the next reader. So the exclusion is stated in both
files, and the cost with it — nothing pins `diagram-shot` now that the shell is deleted. That is
the right trade for the one check whose product is images for a person to look at, and it is
still a cost.

### What it cost

| | shell | Ruby |
|---|---|---|
| Checks | 12 | 12 |
| External commands | ~230 | one method, `Check#shell`, used by four |
| Tempfiles | ~20 | 0 |
| Unit tests | none possible | 24 tests, 67 assertions, every mutation of the library caught |
| Frozen regression corpus | none | 1873 cases, over 11 of the 12 checks |

Seven checks came out within six lines of their shell. `searches` and `diagram` grew by about
fifty each — and those were the densest, least readable shell in the directory and the two most
likely to be quietly wrong. **Ruby did not make this smaller. It made it checkable.**

### What had to be kept, and nearly was not

- **`awk`'s rule order is the semantics.** Its print rule ran before its close rule, so a region
  includes the line that ends it. `Page#from`'s `stop_after` is awk's `seen` guard rather than a
  knob: section 6's author-question region is anchored on an `<h3>` and terminated by `<h3>`.
- **Occurrence counts are not line counts.** `excerpts` used `grep -o | wc -l` where others use
  `grep -c`, and it compares `<details>` against `<summary>`.
- **A `String` pattern is a fixed string**, because the shell used `grep -F` for the build-state
  banner and `grep -E` elsewhere.
- **`length()` in mawk counts bytes**, so `diagram`'s label-width arithmetic uses `bytesize`.
- **`awk` numbers stringify through `CONVFMT`**, so `120` prints as `120`.
- **The matching stays in `grep`** for `searches`: Ruby has no BRE, and `\|` is alternation in
  grep's default dialect but a literal pipe in `rg`. Translating a page's own recorded search
  would silently change what that page claims to have searched for.
- **`completeness` still shells out to `scripts/coverage-gate.sh`**, which is runtime code — two
  implementations of that invariant could disagree.

### The four things the corpus could not have found

Worth writing down, because each was found a different way and none of them by the sweep.

**Two came from re-reading the diff.** `Page#scan` returned capture groups where `grep -o`
prints the whole match, so an assurance rule reported `independently` for `independently
verified`; the fix went into the library rather than into a rule that has to remember `(?:...)`.
And `Page#without`'s closing-line rule was unpinned — inverting it changed nothing across every
case, so a **mutation of the library** caught it instead.

**One came from constructing the boundary cases a comment claimed.** The graded-noun rule
consumes its working string after each match rather than scanning past it, and that truncation
is what makes it per occurrence: `"not a risk score, but the overall risk is 4"` must refuse the
first and catch the second. Scanning with an offset left the earlier refusal excusing the later
assertion — a false PASS on a sentence that grades, and every one of ~1600 cases agreed until
the sentence was written by hand.

**One was a defect in the shell, fixed in both.** Two rules read a failing `git` as an answer:
the state-tag rule tested the exit status of a pipeline ending in `sort`, so an unresolvable
`--base` produced an empty changed set and a PASS — turning a caught defect into a clean bill of
health — and `page-invariants` § 5 took `git branch -r --contains` failing for "no remote
contains it". The port copied both deliberately, because a port may not quietly change a
verdict, and they were then fixed in the shell and the Ruby together with a row each, every one
confirmed red against the unfixed shell first.

**So the frozen corpus is necessary and not sufficient**, and `lib/test/` is the other half. The
sweep grades behaviour the fixtures reach; mutation grades the library itself; and a rule whose
comment makes a claim is worth testing against that claim by hand.

### One intentional difference

The shell iterated two arrays with `for (key in array)`, which POSIX leaves unspecified — mawk
walks `diagram`'s coordinate names as `x1 cy y2 x2 y x y1 cx`. It is reachable: a
`<text x="900" y="300">` in an 880×200 viewBox is off-canvas on both axes. Nothing in `golden/`
has that shape. The Ruby uses declaration order and document order, which is a narrowing rather
than a divergence — the shell's output there was whatever the local `awk` did.

The other one is `grep`'s binary-file heuristic, declined for the same reason: on NUL bytes
`grep -n` prints `binary file matches` instead of line numbers, so the shell skipped a page whose
diagrams were all present. Reproducing that would mean writing a NUL test into `Page` in order to
make the rules stop firing.

### What drift cost while both existed

`main` moved under the branch three times in three days, and every time the drift landed in the
ported checks: six checks and `lib.sh` in one go, then the excerpt state tag, then the verdict
split. The oracle named all of it, per check, in about thirty seconds — twice before the port's
own CI job existed, and once through that job, which is what made the third one arrive as a
failed check rather than as a surprise.

That is the argument for the coexistence window and equally the argument for closing it: the
window is what made the port safe, and every day it stayed open cost a re-port.

### The oracle after the flip, which is still one command away

It drifted a fourth time, after the shell was deleted: `main` moved seventeen commits while this
branch waited, and three of them landed on `.sh` files that no longer exist — a second catalogue
and a hexdocs pinning rule in `rails-anchors`, a quote-aware fabricated-output rule beside it,
and `LC_ALL=C` on four sorts in `page-invariants`. A delete/modify conflict is where a port gets
quietly re-forked: the shell's change is right there in the conflict, and applying it to the Ruby
by reading is how the two stop being the same program.

They do not have to be re-read, because **the shell is still in the history and still runs**:

```sh
git worktree add --detach /tmp/oracle origin/main
# then run each checks/*.sh from the worktree against this checkout's golden/, and diff
```

Every case the corpus holds, graded that way after the port, plus `diagram-shot`'s 162 which it
does not: **2035 identical, 0 differing across all twelve checks.** That is the same guarantee the corpus was recorded under, re-established rather
than assumed — and it settles the `LC_ALL=C` question by measurement, which is the only way it
could be settled: the sort it pins is Ruby's byte order already, so the change is a no-op here and
`page-invariants` agrees on all 175 of its cases.

The lesson is narrow and worth keeping: **a shell script deleted from the tree is not a deleted
oracle.** For as long as the last commit carrying it is reachable, a port that must absorb a
change to it can be graded against it instead of reviewed against it.

## What the retired fixtures taught, which still holds

**Read the pages to score them; do not grep for identifiers.** Two cold runs against the retired
`monolith-guard-chain` fixture were first scored 14/15 and 12/15 by grepping each page for a method or
index name. All three "misses" were false negatives: one page covered the roster gap by citing
`chapters_controller.rb:88-91` without ever writing `load_management`, the other wrote "the invite
guard at `chapter.rb:89-93`" rather than the method's name. A page that cites a line range instead of
a name is following the citation rules, so grep-scoring penalises exactly the behaviour the format
asks for. Read properly, both were 15/15 — which is the second lesson: **a planted set is a floor
test.** It measures whether the skill finds what is known to be there, not the tail, and the tail is
where two runs genuinely diverged — each found real things the other did not, and they split the
same diff into different checkpoints. That is why the recall judge in `IDEAS.md` reads rather than
greps, and why its reference list is a floor too.

## On harnesses

`claude plugin eval` is the better long-term home — it lives in the CLI, runs a no-plugin baseline
arm for free, and belongs in CI. It was early access and not enabled on this account when this was
written, so nothing here is in its `case.yaml` format: config written against an unverifiable schema
is guessing. `prs.yml`, the judges, the calibration set and `checks/` are the durable part and carry
over to either.

`profile.sh` is the one piece written against a schema nobody publishes — the session transcript
under `~/.claude/projects/` — so it is the first thing to break after a Claude Code upgrade, and it is
built to break loudly. Everything it reports is derived from timestamps and `usage` on records the
transcript already carries, so there is nothing to migrate if it does break, only a reader to repair.
