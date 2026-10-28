# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**This file states the current rules and nothing else.** No history, no "it used to", no incident
that produced a rule, no measurement from a past run. See § *Editing style*.

## What this repository is

There is no application code here. The repository is the `accountable-review` Claude Code plugin,
with Codex support for `review-map` as a plugin from this repository's own Codex marketplace. It
ships two skills — `skills/review-map/` and `skills/setup-ci/` — plus the one subagent the first of
them spawns (`agents/claim-falsifier.md`, and only at `--effort high`), plus `ci/`, which is neither
a skill nor read by one, plus `hooks/`, a Claude Code mod that sets a progress line while
`review-map` runs and changes nothing about the page. `review-map` turns a pull request into a
published HTML **review agenda**: what changed, the judgments the reviewer has to make with the
lines that settle each one, the order to read the code in, and what the change reaches in code it
did not touch. Four stacks are supported: Rails (with or without a Next.js client); Elixir/Phoenix —
a LiveView app or a JSON API; Rust, in two lenses — **Rust in general** (a library, a CLI, a
workspace that serves nothing) and **Rust backend** (an HTTP or gRPC server), which reads the
general lens and a second one on top of it; and React, built the same way — **React in general** (a
single-page app, a component library) and **Next.js**, which reads the React lens and a second one
on top of it. Step 2 detects which, and the run reads that stack's lens and its doc catalogue, never
another's. `setup-ci` writes the GitHub Actions workflow that produces one automatically on every
review-ready pull request, and `ci/` is what that workflow runs.

**`review-map` is the product; `setup-ci` is plumbing for it.** Nothing about the second may change
what the page is. The page produced in CI and the page produced by a person are the same page from
the same procedure — the only difference is `--output`, which decides where the bytes land.

**The deep analysis is how the page is built, not what it prints.** A run traces consumers across
the whole diff, reads the tests, follows a value across the boundary and attacks its own conclusions;
what reaches the reader is the part they have to act on. Reducing the reading obligation is the goal.
Reducing the analysis is the failure, and it looks like success — a shorter page is easy to produce
by looking less hard.

**Every change to the plugin answers to `docs/MANTRA.md`: preserve the difficulty of engineering
judgment, eliminate the difficulty of understanding the explanation.** Read it before changing what
a page says or how it says it. A change that makes the page harder to read is a defect however
correct it is. So is a change that answers a question the reviewer should be left to judge, however
helpful it seems. The agent does the work of explaining; the human does the work of judging.

Installed, it is invoked as `/accountable-review:review-map`: plugin skills are namespaced by the
plugin name. It takes a target, an **effort** — `--effort high` (the default, sending an adversarial
pass at the run's own analysis before any of it is written) or `--effort low`, which opts out —
`--mentor`, off by default, the one flag that puts anything inside a checkpoint, and
`--context auto|never|always|collapsed`, which tunes section 02 alone. The repository's
`.accountable-review.yml` supplies effort, mentor and context when no flag does. All of it is parsed
in step 1 as prose, because `argument-hint` and `arguments` are not in the Agent Skills frontmatter
allowlist and `claude plugin validate --strict` rejects an unknown key. **There is no level flag**,
and an unrecognised one is reported rather than guessed at. The "source" is prose that another Claude
instance executes, so the unit of quality is instruction clarity, not compilation.

There is no build and no linter, and the **prose** has no test suite: changes to it are verified by
running the skill against a real PR and reading the page it produces. `claude plugin validate .
--strict` checks the manifest, not the prose.

**The scripts are the exception, in both skills: the boundary is prose versus software.**
`setup-ci`'s templates and scripts and `review-map`'s scripts are ordinary software with right
answers, so they have ordinary tests: `skills/review-map/tests/run.rb` and
`skills/setup-ci/tests/run.rb` (no model, no network, seconds). Each sits beside a self-test that
breaks the things the suite claims to check and asserts it notices each one: a check that passes
because it never looked is worse than no check. **A self-test row runs only the section its
mutation can reach, and names the one assertion it must turn red**, so a break that fails for an
unrelated reason is reported rather than counted; both self-tests run their rows in parallel.
`review-map/tests/self-test.rb`'s header owns which defects earn a row — only where the sanity row
cannot vouch for the assertion. Only the tests are Ruby; the scripts they
call stay shell, because shell is what runs on a team's runner. When you edit either template, or
any script under `skills/review-map/scripts/`, `skills/setup-ci/scripts/` or `ci/`, run them —
`bin/evals offline` runs every suite together, which is what CI does too.

**The skill's size ceilings are a ratchet.** `SKILL.md` is loaded whole on every run and grows one
reasonable paragraph at a time, so `tests/skill-budget.rb` holds it and every reference to a
ceiling in `tests/budgets.yml`: lower one when its file shrinks, and raise one only on purpose, in
the same commit as the growth, so the growth is in the diff a reviewer reads. A new reference needs
a row and a sentence in `SKILL.md` saying when to read it.

## Working on the skill

Run a Rails or a Phoenix project against this checkout — no install, and `/reload-plugins` picks up
edits without restarting:

```bash
cd /path/to/app && claude --plugin-dir /path/to/accountable-review
```

Then: `/accountable-review:review-map <PR number | PR URL | branch | "">`.

Before pushing, `claude plugin validate . --strict` must pass — CI runs the same check, and so does
the community-marketplace review pipeline.

Defect discovery is sampling rather than a deterministic function of the diff, so a single run is
weak evidence. When judging whether a wording change improved things, run the same target more than
once, or the same wording against several PRs of different shapes (a 4-file bugfix, a migration, a
100-file feature spanning both sides of the API) — small PRs and large ones exercise opposite
failure modes.

**What to check on every run:**

- **Is every review question a judgment?** The failure mode is a category: *ProjectSearcher
  implementation*, *Tests*, *Controller changes* — a place rather than a decision, and it reads as
  organised. The test is whether a reviewer could answer it by looking at the code and could get the
  answer wrong. The heading names a behaviour, so a place there is the same failure one line up.
- **Could you follow each checkpoint without leaving it?** Read the explanation before the question
  and ask whether it told you what the system does, what changed and why it matters — or whether you
  had to assemble that from *Context*, another checkpoint or a link. Jump to one from the rail and
  check that the unchanged callers it reaches are explained there, not only in *Impact*. A dense,
  correct sentence that packs four relationships is the failure, and it reads as concise.
- **Did the merge happen?** Step 7c is what makes the agenda short honestly. A constructor change,
  the nil default it introduces and the two consumers that do not handle nil are one judgment, not
  three. Read the agenda asking which two of these are the same question.
- **Open two entries from *Impact outside the diff* and confirm the cited file really consumes the
  changed thing.** That is where a page is most expensively wrong.
- **No sentence grades the PR.** The checkpoints are ordered, and an order is one step away from a
  scale — a number beside a question, a *high* in a title, a first checkpoint described as the
  important one. It arrives as helpfulness.

**The page has no word budget.** `report-format.md` § *The agenda budget* says why: the cheapest way
under a word count is conceptual compression, which moves the work of assembling the explanation onto
the reader. What bounds the page is relevance to a judgment. § 01's word count is still recorded by
`evals/e2e/run.rb`, as an observation and never a verdict. **The checkpoint count is never graded**:
a page that got shorter by losing a judgment has done the one thing that section forbids.

`skills/review-map/evals/` is where judging happens, in three layers. **Mechanical**: `check.rb`
and the ten checks, run on every push. **End to end** (`evals/e2e/`): a whole run of the skill
against a **real merged OSS pull request** pinned in `prs.yml`, generated through
`ci/generate-review-map.sh --output` exactly as CI does, checked mechanically, then graded by one
LLM judge per aspect of the page, anchored in the checkout and blind to the mechanical results.
**Calibration**: a judge counts only once it has matched a person's verdicts on a certified gold
page and on copies of it that each plant one defect. Calibration PRs are held out of the eval set.

**Seven judges exist** — `what-changed` (§ 01 with its masthead), `checkpoint-judgments`,
`checkpoint-explanation` and `checkpoint-claims` (§ 03's shape, its prose and its truth),
`reading-path`, `impact` and `evidence`. The
aspects with no judge yet (Context, figures, coding decisions, probes, voice, recall) are notes in
`judges/IDEAS.md`, most waiting on a gold page that carries their subject. The calibration PR is
`discourse/discourse#43002`; a judge is measured against it only once `gold.yml` lists it as
certified, and `calibration/status.json` records each judge's calibration state against the
**instrument's** sha — the judge's file, `judge.rb` and `verdicts.rb` hashed together.
Whole-run cases with no harness yet (the trivial refusal, `--update`'s P6 refusal, the 7.1 override
path, a planted recall floor) are listed in `IDEAS.md`; each keeps its mechanical half in
`tests/run.rb`.

`bin/evals offline` is what CI runs and what you run before pushing. `bin/evals e2e`, `calibrate`
and `report` are the rest, run before a major release. Results carry the skill's git sha, so a pass
rate is attributable to a version of the prose, and an uncalibrated judge's column is never shown as
a score.

When the question is where the minutes went rather than whether the page was right,
`evals/profile.sh` reads the transcript of a run — an eval repetition or a real PR — including the
**subagent** transcripts under `<session>/subagents/`, and splits its wall clock into tool
execution, streaming, and the wait before each request's first token.

**Two rankings, and they invert.** The lever for **wall clock** is fewer requests; the lever for
**cost** is context, billed once per request, so *when* a file is loaded matters as much as whether.
`profile.sh` prints a table for each, and the two are read side by side, never one instead of the
other. It infers nothing the transcript does not carry: publish stages are mechanical, the ten steps
are not, and steps 4, 6 and 8 leave no trace, so they get no row. The numbers live in
`evals/README.md` § *Profiling one run* and nowhere else; read it before quoting one, and `SKILL.md`
step 6c for what the falsification pass costs.

Read `evals/README.md` before adding a PR or a judge.

## How the documents divide the work

Each reference owns one axis; keep them from bleeding into each other.

| File | Owns |
|---|---|
| `SKILL.md` | The procedure — ten ordered steps from resolving the target to publishing, step 7 being the synthesis that turns analysis into an agenda — plus the product principle and the hard rules |
| `references/report-format.md` | Page structure — the six sections and what triggers each, **Context** and its earning test, **the review checkpoint**, its coding-decision and architectural kinds, and the ranking by delta with the ceiling, **chains** and the rule that decides which figure a chain is, **the three topology figures** and the order a shape is chosen in, the evidence tiers, **mentor mode and the primer callout**, source excerpts, impact paths, the canonical-home rule, the agenda budget and the deep-link ladder |
| `references/rails-nextjs.md` | Domain knowledge, **Rails** — what a senior reviewer of that stack looks for, per layer, plus § *Coding decisions*, the runtime probes and the search recipes for affected-but-unchanged code. Its three client-side sections are stack-independent, and the other lens files point at them rather than restating them |
| `references/phoenix-liveview.md` | Domain knowledge, **Phoenix/LiveView** — the same three parts for that stack. Its centre of gravity is § *LiveView*: the `phx-*`-to-`handle_event` seam, the stack's compiler-free boundary and its richest source of affected-but-unchanged code |
| `references/discover/` | What to detect per stack at `SKILL.md` step 2 — `rails.md`, `phoenix.md`, `rust.md` (with its backend section) and `react.md` (with its Next.js section): the layout, the libraries, the test runner, the frontend's shape, and the versions every doc link is pinned with. One file per stack, read once and whole after detection, so a run carries only its own stack's |
| `references/rails-docs.md` | The documentation catalogue, **Rails** — the Rails and gem URL *paths* the page may cite, the per-series overrides, and the two marks that say what a sentence may claim. Data, not lenses: an allowlist, dated and re-verified by `evals/verify-catalogue.sh` |
| `references/elixir-docs.md` | The documentation catalogue, **Elixir** — hexdocs paths pinned per package, the same two marks, and a § *Version* that **withholds every link** until a verification run opens its rows. Closed, so an Elixir run anchors with probes and prose |
| `references/rust.md` | Domain knowledge, **Rust of any kind** — organised around what the compiler was told not to check or cannot see: the wildcard arm, the `pub` item, the unbuilt feature combination, the module whose safe code keeps an `unsafe` block sound. The whole lens for Rust in general, and the first layer for a Rust backend. Its probes read the build — `--locked` always — because Rust has no console |
| `references/rust-backend.md` | Domain knowledge, **Rust backend** — read **after** `rust.md`, never instead of it, and restating none of it: routes and layers (an `axum` layer covers only the routes added before it), extractors, the wire contract, migrations against compile-time-checked queries, and the request whose future is dropped when the client leaves |
| `references/react.md` | Domain knowledge, **React of any kind** — organised around what TypeScript is silent about: when code runs (an effect's dependencies, a missing cleanup), which instance state belongs to, whose identity a memo or a context compares, and every consumer of a component, hook or query key outside the diff. The whole lens for React in general, and the first layer for Next.js. Its probes use the project's own package manager, `--no-install` on every `npx` |
| `references/nextjs.md` | Domain knowledge, **Next.js** — read **after** `react.md`, never instead of it: the server/client boundary, server actions as public endpoints, route handlers, rendering mode and the cache (per-user data cached for everyone is its sharpest finding), the file tree as router, middleware or proxy, and a Prisma or Drizzle schema. `rails-nextjs.md` § *Next.js* is the short form a Rails run reads; this file is the depth behind it |
| `references/react-docs.md` | The documentation catalogue, **React** — react.dev and nextjs.org paths stored **with their host**, a nextjs.org path also with its **router**, pinned per **major**. **Closed**; its sweep has one question to answer before any row — whether each host addresses its *current* major at the versioned form |
| `references/rust-docs.md` | The documentation catalogue, **Rust** — docs.rs paths pinned per crate and doc.rust-lang.org paths pinned to the toolchain, each stored **with its host** because `cargo` is both a crate and a book. **Open** |
| `references/page-template.html` | Design system — the rules every theme's tokens keep (it declares none of its own), component classes, the assembled checkpoint, the chain, one of each topology figure and the impact panel, and the page's one small script. **No `<svg>` anywhere.** Four `SKELETON:` markers divide it: the head and tail ranges are **emitted** into the page by `page-skeleton.sh`, the middle is the markup a run reads. A fifth, `SKELETON:THEME`, inside the head, is where the themes go |
| `references/themes/` | The three looks — `daylight` (the default), `workshop`, `field-notes` — each one file: a font link and one `<style>` holding its tokens in all three theme states and its overrides, every element carrying `data-style`. All emitted at the `SKELETON:THEME` line, the unchosen ones `media="not all"`; never read by a run |
| `references/update.md` | The `--update` procedure — the four checks no page can answer, `carry-plan.sh`'s plan and what each row means, which steps run in full and which narrow, and how the existing page is edited. Read only when the flag is passed, so a fresh run never carries it |
| `references/claim-falsifier.md` | The shared adversarial mandate, read by an independent reader in either host — what to attack in one **analysis note**, that every challenge cites a line it opened, and that a claim it failed to break is reported too |
| `references/hosts/` | Host-specific delivery and delegation: Claude Artifact or local HTML everywhere else (`generic.md` is the reference for every non-Claude host, Codex and Pi the primary examples), named Claude agent (a general-purpose one when `npx skills add` installed the skill without the plugin, so `agents/` never arrived) or Codex subagent tools |
| `agents/claim-falsifier.md` | The Claude agent wrapper — tools and model. At the **plugin root**, not under `skills/`: it is addressed by name, never read, and its parent supplies the absolute path to the shared mandate |
| `hooks/` | A Claude Code mod — the status line while `review-map` runs interactively, tokens and the 5-hour window included, with one transcript line of what the run spent when it ends. `progress.ts` reads, `board.ts` formats, `activity.json` is the tool-call-to-purpose table `evals/e2e/progress.rb` reads too, and `skills/review-map/tests/activity.rb` holds that one file to both readers. Inert until the skill expands; `.codex-plugin/plugin.json` names no hooks |
| `scripts/page-skeleton.sh` | Emits the head, the themes (the repository's default switched on) and the tint script straight into the page, and prints the markup half with `--markup`. Holds no bytes of its own — `tests/run.rb` proves that by partition |
| `scripts/diff-render.sh` | Says per path whether GitHub will render that file's diff, which decides the URL form for a line inside it. GitHub's documented thresholds as constants, `.gitattributes` through `git check-attr`, and one dated name heuristic |
| `scripts/excerpt.sh` | Generates the collapsed source excerpts, so the quotation is the real bytes |
| `scripts/ledger-rows.sh` | Generates the evidence foot's inventory cells and their deep links, so the gate checks the page rather than someone's typing. `--paths-only` is the only mode the page uses |
| `scripts/coverage-gate.sh` | The one mechanical gate — set equality between the inventory and the diff |
| `scripts/page-lint.sh` | The reading a run acts on at step 10, in shell because it runs on the user's machine: a placeholder is the one FAIL, and a tier that disagrees with the changed set is a WARN naming its sentence. `page-invariants.rb` § 10 relays it, so the rule has one implementation |
| `scripts/read-config.sh` | The only thing that knows `.accountable-review.yml`'s shape, and the one parser every reader uses — the skill at step 1, `page-skeleton.sh`, and the `ci/` scripts. In `review-map` because the skill ships alone |
| `scripts/usage.sh` | What a Codex run spent, read off the thread's rollout log and its falsifiers': `mark` at step 1, `report` at step 10, said in chat and never on the page. Claude Code's status line counts the same live, so a Claude run never calls it |
| `scripts/carry-plan.sh` | The re-run decision — the delta since the previous map, the preconditions that refuse one, and per checkpoint and per Context entry whether it may be carried. Mechanical because by eye every checkpoint looks carryable |
| `skills/review-map/tests/` | The deterministic tests for those scripts, in Ruby: `suite.rb` holds them one method per section, `run.rb` runs every section, and `self-test.rb` breaks each rule on a copy of the skill and runs only the section that should notice. `diff-render.sh`'s rows build their own two-commit repository, because its answer is a function of git. `frontmatter.rb` puts every skill's and agent's frontmatter through a strict YAML parser, because `claude plugin validate --strict` accepts an unquoted `: ` that Pi's loader rejects silently, and holds a skill's name and description to the Agent Skills spec's limits, which the same validator does not check |
| `skills/review-map/tests/codex-plugin.rb` | The Codex manifest and catalogue against Claude's manifest — same name and version, `review-map` the only skill shipped, the catalogue's one entry pointing at this repository — and seven mutations of its own inputs that it must catch |
| `skills/review-map/tests/skill-budget.rb` and `budgets.yml` | Every skill's `SKILL.md` and Markdown reference under a line and byte ceiling, every reference named in its `SKILL.md`, every `references/` path it names present; a `SKILL.md` past the spec's 500 lines, or over its history-marker ceiling, is a WARN. The ceilings live in `budgets.yml` and nowhere else |
| `bin/evals` | One command per eval scenario — `offline`, `e2e`, `calibrate`, `report`, `catalogue`, and the rest in its own header. A dispatcher over `evals/`, `setup-ci/tests/` and `bin/examples check` that owns the paths and defaults and **no rule of its own**. Its `parity` line stops its suite table drifting from `validate.yml` |
| `bin/examples` | The published examples — `regen` regenerates each at the revision its committed `manifest.json` pins, `render` writes the provenance regions in `examples/README.md` and `examples/index.html`, `check` fails a version or a region gone stale. Outside `examples/` because Pages uploads that directory |
| `evals/` | `checks/`, `golden/`, `e2e/` and `profile.sh`, which measures what a run *cost* rather than whether it was right, plus `DEFERRED.md`, the one list of what the gate knowingly lets through. Not loaded at runtime; see `evals/README.md` |
| `evals/e2e/` | The end-to-end harness, in Ruby. `prs.yml` pins real merged OSS pull requests with a `calibration` or `eval` role; `run.rb` generates through `ci/generate-review-map.sh --output`, checks, judges and profiles; `judges/` holds one file per judge and `IDEAS.md`; `calibration/` holds the gold page, the one-defect patches, the labels and `status.json`, which is what makes a judge's column a measurement; `report.rb` writes the HTML report and, with `--history`, the one committed summary per release; `triage.rb` writes the local queue of verdicts a person must read — truth failures, unclears, notes — whose readings are exported JSON, never a grade; `grade.rb` holds the thresholds `evals/README.md` § *What counts as good* owns, reading each criterion's class — truth, form or deferred, the last judged and gated by nothing — from `criteria.yml` — **never from a judge's file**, whose bytes are its instrument sha, so `test_grade.rb` pins the two to the same length |
| `evals/checks/` | One Ruby script per rule family, ten of them, dispatched by `check.rb`; `self-test.rb` asserts a verdict per row of `self-test-cases.txt`. A check that could only SKIP does not exist, because a SKIP reads as verified. `impact-paths.rb` grades `figure.impact` and nothing else; `figures.rb` grades a checkpoint's figures, `figure.chain` among them. `link-form.rb` grades the href against the citation it sits on — the span, the sha256 fragment, and the routing away from a diff GitHub withholds — which is a relation between the page and a repository, hence `golden/links-repo.sh` and `lib/review_map/fixture.rb`. `lib/review_map/` is their shared library and `lib/test/` its tests. `checks/frozen/` holds every case's exact output, and `frozen.rb` verifies against it |
| `skills/setup-ci/SKILL.md` | The setup procedure — inspect, decide where it goes, install, report — plus what setup must never touch |
| `skills/setup-ci/references/workflow.md` | Every part of the generated workflow and why it is that way: the triggers, the draft and fork guards, concurrency, permissions, checkout depth, the pin, the credential |
| `skills/setup-ci/references/config.md` | `.accountable-review.yml` — the whole schema, who reads which key, the precedence rule, and why an unknown key is an error |
| `skills/setup-ci/references/delivery.md` | The delivery contract, the providers that exist and the ones only designed for, and why `command` is opt-in in CI |
| `skills/setup-ci/templates/workflow.yml` | The workflow itself. Version substitutions, the when-decisions behind `SETUP:IF:` blocks, and nothing else configurable by design |
| `skills/setup-ci/scripts/` | `inspect-repo.sh` reports, `render-workflow.sh` renders deterministically and resolves the `SETUP:` blocks, `install-workflow.sh` writes idempotently, refuses to clobber, and recovers the when-decisions from the file it is about to replace |
| `skills/setup-ci/tests/` | The deterministic tests, in Ruby: `suite.rb` holds them one method per section, `run.rb` runs every section, and `self-test.rb` breaks each rule on a copy of the plugin and runs only the section that should notice. The scripts they test are called as subprocesses |
| `ci/generate-review-map.sh` | The CI adapter: resolves the page settings, runs `review-map` non-interactively with every one of them explicit, then checks the three things a person would have noticed by looking at the page. A page-shape argument is an unknown argument here |
| `ci/map-still-current.sh` | The second range — does the map we already have still describe this head? Composes `application-code.sh` over the delta with `carry-plan.sh` over the restored page, and adds no rule of its own |
| `ci/application-code.sh` | The scope gate, in two rules: does this diff change application code at all, and is what it changes more than trivial? Both counted over application paths only, the trivial thresholds joined by **and**, and it fails open, so an unrecognised path is code |
| `ci/delivery/` | The delivery seam. `deliver.sh` dispatches; a provider is one file that reads `AR_*` and prints `key=value` |
| `README.md` | The public face — why comprehension debt is the problem, what a Review Map is, install, usage, CI setup, and the technical overview. Written for someone deciding whether to use this, so depth past that decision belongs in `docs/` |
| `docs/review-map.md` | The page anatomy for a reader who already wants it. It **restates** `report-format.md` for the public and owns nothing — where the two disagree, the reference wins |
| `docs/ci.md` | The public half of `setup-ci/references/delivery.md`. Same rule: it restates, the reference owns |
| `docs/MANTRA.md` | The principle every change to the plugin is weighed against: which difficulty the page keeps (the judgment) and which it removes (understanding the explanation). Written for whoever develops the plugin. A run never reads it; the skill's prose carries it as rules |
| `CONTRIBUTING.md` | How to work on the plugin from a checkout — the layout, the eval loop, the self-tests, and the release process. Why a rule exists stays in this file; `CONTRIBUTING.md` is only how to run things |
| `evals/verify-catalogue.sh` | The only script here that needs the network: opens every URL in a catalogue and reports dead pages, dead anchors, and the rows that differ by version. Maintenance for an open catalogue, the **release gate** for a closed one, never part of a run — see § *The catalogue is the one thing a run cannot verify* |

`SKILL.md` is the only file loaded up front; the references are read on demand at the step that needs
them. That is why `SKILL.md` says *when* to load each one, and why detail belongs in the reference
rather than inlined into the procedure. The exception is the product principle and the hard rules,
which stay in `SKILL.md`: a rule that can be skipped is not a rule, and the always-loaded file is the
only place skipping is impossible.

## Invariants that span files

Editing one of these means checking the others still agree.

- **One page shape, and no flag chooses it.** No argument names a length, a depth or a second
  document, anywhere in the plugin: not on the skill's command line, not on
  `ci/generate-review-map.sh`, and not as a key in `.accountable-review.yml`. `SKILL.md` step 1
  settles it, and `report-format.md` § *One page shape* states the consequence for the format.
  `--mentor` adds a component and does not choose a shape — see the next bullet.

  **A page-shape argument is unknown, never tolerated.** A flag or key taken silently and mapped
  onto this page is a name that changed meaning with nothing on the page to say so — so the skill
  reports it, the CI adapter exits 2 on it, and `read-config.sh` refuses it as an unknown key. One
  rule in three places; `setup-ci/tests/suite.rb` pins the last two. What a reviewer wants is an
  answer to *what do I have to judge here, and where do I look?*, not a length setting. A future full
  mode is the same agenda with depth beneath it — `report-format.md` § *A future full mode* — never
  a second document reached by a flag.

  **There is no word budget, and length has no check.** `report-format.md` § *The agenda budget*
  owns what bounds the page instead. Length is never a failure, because a failure on length teaches a
  run to compress an explanation or drop a claim to get under a number. **The checkpoint count is
  never budgeted.**

  **The rail is emitted, not edited down.** `page-skeleton.sh --markup` hands a run the whole markup
  half, eleven `data-rail` entries: five numbered sections and six checkpoint sub-entries.
  `tests/run.rb` counts the entries, and the sanity row of `self-test.rb` proves that count looked.
- **`--mentor` is the only flag that puts anything inside a checkpoint, and subtraction is what keeps
  it from being a level.** It admits one component — the primer callout, `aside.primer`, the third
  framework anchor — inside the checkpoints that earn one, for a reviewer new to the *stack* rather
  than to the change. **Delete every primer from a mentor page and what remains is the page the same
  run would have written without the flag.** Same sections, same checkpoints in the same order, same
  reading path, same panel, same foot, same budget on every other part. It takes **no badge** — the
  effect is visible, and a count of primers would be the page grading its own thoroughness.

  **Its header names the stack, not the component** — *Understanding Ruby on Rails*, not *Rails |
  Primer* — and its frame is Rails red on `--primer-*`. No logotype: there is no `<svg>` on this
  page, and `rails-anchors.rb` fails a primer carrying `pr-mark`, `pr-tm` or one.

  **A primer holds its checkpoint's one doc link rather than adding a second** — the anchor budget is
  relocated, never raised. It is **gated** on that link, so a closed catalogue means no primers for
  that stack: Phoenix and React get the ordinary page until their catalogues open.

  **A run that earns no primer writes none**; manufacturing a lesson to honour a flag turns the page
  into a framework manual. **A stack name is checked, never obeyed** — `--mentor rails` in a
  `mix.exs` repository stops the run. **`--mentor off`** turns it off, which matters only when the
  repository's file turned it on. The one exception to *never invent output* lives here: `pre.demo`
  may show a result line only because it quotes the manual on a class this repository does not have,
  so a demo goes nowhere but inside a primer and a probe never inside one.

  These agree: `report-format.md` § *Mentor mode* owns every rule **alone**, with § *One page shape*,
  § *The review checkpoint*'s slot, § *Framework anchors*' third row and § *The agenda budget*'s
  primer line pointing at it; `SKILL.md` parses it at step 1, checks the stack name and the
  catalogue at step 2, earns one at step 7g, writes it at step 9 and carries the demo exception in
  its hard rules; `page-template.html` holds the CSS in the head range and the callout inside
  checkpoint A; `evals/checks/rails-anchors.rb` § 8 grades it on the **comment-stripped** copy, behind
  the `golden/anchors-primer-*` fixtures and `anchors-demo-loose`; `tests/run.rb` asserts the template
  assembles exactly one and `tests/self-test.rb` breaks it; and the CI half is
  `ci/generate-review-map.sh` (which always passes `--mentor`, `--mentor off` or `--mentor <stack>`),
  `read-config.sh`, `references/config.md` and `setup-ci/tests/`.

  **It has no eval axis.** An axis is a column on every result line; whether a primer was worth a
  callout is a judged question, and `evals/e2e/judges/IDEAS.md` is where its judge would go.
- **The review checkpoint is the page's primitive.** Three to five of them under *What needs your
  attention* **per independent semantic delta *What changed* names**, under a ceiling of seven, nine
  or eleven that the Production bucket sets, each **one judgment** the reviewer has to make: an `<h3>`
  naming the behaviour (the rail and the reading path name it by that heading), prose that explains
  before it asks — with at most one figure and one inline snippet where they carry the argument — an
  optional `div.gap` labelled *GAP*, `p.open` labelled *Review question*, always and last in the
  explanation, the primer at `--mentor`, and then `details.cp-ev`, shut and labelled *Supporting
  evidence*: a `ul.lookat` of one to four entries — each a short title, a clause and its deep-linked citation, in
  that order — and an optional probe. Both GAP and the question's labels are fixed, because an
  absence and the question are the two places a severity word gets in.
  `report-format.md` § *The review checkpoint* owns all of it **alone**; `page-template.html`
  assembles one with every optional part, one without, and a pending stub carrying its heading and
  question.

  **Explain first, challenge second.** The prose establishes what the system does, then what the
  change did and why it matters, facts and unknowns told apart in the sentence, and only then is the
  question asked — because a question met before its situation makes the reviewer reconstruct the
  explanation, and the page keeps the difficulty of the judgment, not of reading. The sequence is the
  rule, never a paragraph count or a sub-heading.

  **Each checkpoint stands alone — understandable, never exhaustive.** A reader who jumps straight to
  one learns from it what it needs of the domain, the code and *What changed*, and what the unchanged
  callers it reaches now do — a sentence for a caller whose behaviour bears on the judgment, a count
  for the ones reached the same way, their list in the evidence; a pointer to *Context*, *Impact* or
  another checkpoint is depth, never a step. The trail the run walked and framework internals are
  evidence unless they change the question, and a figure replaces the prose that would walk it. So
  background is repeated into a checkpoint on purpose, while the finding and the question keep one
  home — the *Six sections* bullet below. Under `--mentor` the checkpoint reads complete without its primer,
  and the primer is kept whole as teaching material. `report-format.md` § *The review checkpoint*
  owns it, with § *One canonical home*, § *Section 2* and § *Mentor mode* agreeing.

**Narrative first, proof beneath it, and purpose decides the side, not format.** The explanation
reads continuously and complete with the evidence shut; a figure or a short inline snippet sits in
it only where it carries the argument, and a citation only where a sentence resting on unchanged
code keeps it beside its tier, as the claim itself linked (`a.ref`), never a `(path:line)` aside.
One `<strong>` per paragraph marks the sentence the judgment turns on, never a grade, and each
explanation is revised once for voice from a draft that step 10 holds it to. What a reviewer needs
to understand or challenge the change is explanation, uncertainty and test gaps included; what they
need to substantiate it is evidence, one click from the question, never retelling the narrative and
carrying no count. `report-format.md` owns the rules (§ *The review checkpoint*, § *The voice
pass*, § *A citation inside the narration*); the template, `excerpt.sh --inline`, `page-lint.sh`,
`link-form.rb`, `rails-anchors.rb`, `carry-plan.sh`, `figures.rb`, `excerpts.rb` and
`impact-paths.rb` must agree with them, and each says in its own header which rule it holds.
  **Analysis facets are not a reading obligation.** A test appears inside a checkpoint when it
  changes the judgment; a list of the specs that touch a file does not appear at all.

  **Failure mode one: a checkpoint that is a category** — *ProjectSearcher implementation*, *Tests*,
  *Controller changes*. The test is whether a reviewer could answer its review question by looking at
  the code and could get the answer wrong. **Failure mode two: a checkpoint that should have been merged** —
  `SKILL.md` step 7c.

  **The count scales on the delta, the ceiling on the Production bucket, and neither on the raw
  diff**: eighty files of one rename is still three to five, and test, generated and docs files buy
  no room. The ceiling is room for more deltas and for the structural kinds, never a target, and
  section 04 stays three to seven stops at every tier, so a page that cannot route every checkpoint
  is too wide whatever its tier. `report-format.md` § *Ranking by delta* owns the tiers. A judgment the cap would push out does not go to a clause or to the evidence foot, because
  the foot is where promotion-by-omission forbids a judgment to live. `report-format.md` § *The
  review checkpoint* owns the count and § *Section 4* the routing that bounds it; `SKILL.md` step 7e
  and § *How big should the page be?* carry it; `start-here.rb` warns on a checkpoint no stop points
  at. Nothing grades the count; `rails-anchors.rb` pins its per-checkpoint denominators at five so a
  wider agenda cannot loosen the anchor budget.

  **Ordering is not grading.** Checkpoints are ranked by what a reviewer would most regret
  misunderstanding. A number beside a question, a *high* in a title, a first checkpoint described as
  the important one — each is a severity scale. The one line that hands over the judgment is
  `p.open`, labelled *Review question*; `page-invariants.rb` warns on a bare `Watch` or `Blocking`
  label.

  Nothing mechanical grades a checkpoint's quality. `start-here.rb` requires the reading path to
  point at one, `rails-anchors.rb` counts them for its doc-link budget, and `tests/run.rb` asserts the
  template assembles three. Whether a question is a judgment, asked once and ordered without a grade
  is `evals/e2e/judges/checkpoint-judgments.md`'s question; whether its prose explains before it
  asks, stands alone and reads complete with its evidence shut, `checkpoint-explanation.md`'s;
  whether its claims are true, `checkpoint-claims.md`'s.
- **Three kinds of checkpoint, and the structural two rank behind every behavioural judgment.** A
  **behavioural** checkpoint judges what the system now does; an **architectural** one, what the
  change made true of its structure (a dependency direction, a second owner of a fact, a boundary
  crossed, a new runtime component, the first of its kind); a **coding-decision** one, how the change
  was built (where a class was put, what kind of object it is, which abstraction it went around).
  They render identically and nothing labels the kind.

  **Every delta is classed behavioural or refactor**, and the masthead's *Change shape* chip is the
  class and its only trace — behavioural · refactor · mixed, nothing finer, because *bugfix* claims an
  intent the code rarely states. `page-invariants.rb` § 9b warns on any other word and on a
  masthead without the chip, because the `what-changed` judge asks only whether the chip is true.
  **The band outranks the delta**: every behavioural judgment and every refactor's *is behaviour
  preserved?* first, page-wide, then architectural questions, then coding
  decisions, because misreading structure costs a conversation and misreading behaviour costs
  production. `report-format.md` § *Ranking by delta* owns the order, the within-kind order and the
  ceiling tiers **alone**; `SKILL.md` steps 7a, 7d and 7e point at it rather than copy it.

  **Both structural kinds share one bar: no citation, no question**, because a structural opinion
  with nothing to point at is the page grading the design or the author's taste. An architectural
  question cites a written decision or a search at both revisions — the base half a `git grep -P` at
  the merge-base sha, never a tool that compiles or boots the app. A coding decision names the
  departure and cites this repository's settled answer or a row of the lens file's closed stack list,
  the repository outranking the stack; Phoenix is repo-only until its catalogue opens. Each has three
  tests behind the citation, merges into a behavioural judgment that turns on the same lines, never
  displaces one, and never takes the page past its ceiling; free room is never a reason to look for
  one.

  These agree: `SKILL.md` steps 2, 5 and 7a–7e; `report-format.md` § *Architectural questions* and
  § *Coding decisions*, each owning its bar and tests **alone**; every lens file's shapes and
  searches, and `rails-nextjs.md`'s closed list naming `rails-docs.md` rows; `claim-falsifier.md`,
  which attacks the base half; `carry-plan.sh`'s P6, which exempts a search whose every tree is the
  merge-base (P2 holds it fixed), behind `tests/run.rb` rows and `self-test.rb` mutations;
  `searches.rb`, which credits no head entry to it, behind `golden/searches-other-tree.html`; `README.md` and `docs/review-map.md`. No judge grades either kind
  yet; `evals/e2e/judges/IDEAS.md` records the ones that would.
- **Chains are the one figure vocabulary, in two places with two jobs, and the rule between them is
  mechanical.** `figure.impact` in section 05 and `figure.chain` inside a checkpoint are the same
  `ol.ip-path` with the same node kinds and causal verbs. `report-format.md` § *Chains* owns what
  they share; § *Impact paths* owns the panel's own caps **alone**.

  **A chain that crosses from changed code into unchanged code whose meaning the change altered is an
  impact path.** It lives in section 05, drawn once, and a checkpoint that turns on it says so in a
  clause. A chain inside a checkpoint shows mechanism *within* the change and carries **no
  `.ip-aff`**; `tests/run.rb` checks it on the template with a range over the assembled chain.
  `.ip-step` exists only in a checkpoint's chain: a hop that claims nothing about the diff.

  **Every code node carries a locator**: an `a.path.ip-loc`, last inside `.ip-box`, `{{DIFF}}` on
  `.ip-chg` and `{{BLOB}}` on `.ip-aff` and `.ip-step`, **never on `.ip-out`**, which is a behaviour
  rather than a file. It carries no `data-path` — `coverage-gate.sh` greps that attribute page-wide.
  A citation never stands **in for** the label or the clause; the clause's canonical home is the
  affected list beneath the panel. `golden/impact-prose-nodes.html` pins that, with a correct locator
  on the node whose label is a path, so it fails for one reason.
- **There is no `<svg>` on the page, at all.** Figures are components: they reflow on a phone, cannot
  overflow a canvas and cannot be drawn wrong, so the only thing a run can get wrong is whether the
  edges are true. An SVG would bring back the need for visual inspection of crowding, overlap and
  misplaced arrowheads, which no check here performs. `SKILL.md`'s hard rules forbid one.
- **Three topology shapes are components, and the shape is chosen before it is drawn.**
  `figure.converge` (several paths that must keep one invariant), `figure.lifecycle` (states and the
  actions between them) and `figure.structure` (an entity and its relationships) sit in a checkpoint's
  figure slot beside `figure.chain`, **one figure per checkpoint of any kind**, built from the same
  `.ip-*` boxes and locators. A guard fork is not drawable and goes to prose. Step 7f asks the shape
  questions in a fixed order — converge first, chain last — writes the answer into `agenda.md`, and
  step 9 types the figure from that block only. **Zero figures is a valid result and the count is
  never graded.**

  **The converge may hold `.ip-aff` because its edges flow in.** An impact path flows *out* of the
  change to a consequence; a converge's paths flow *in*, from writers, to an invariant — so an
  unchanged writer that skips what the others run is drawn there, never also as an impact card, with
  a *Look at* entry carrying the clause a node cannot. Its list **claims to be complete**, so it is
  earned only by a recorded writer search, and `carry-plan.sh`'s P6 replays that search so `--update`
  refuses to carry a converge a new writer has falsified.

  **`.cv-note` is a free-text slot a severity word can enter**, beside `GAP` and *Review question*, and
  the only one without a fixed label. It says what a path skips, never how much that matters.

  These agree: `report-format.md` § *Topology figures* owns the shapes, gates and caps **alone**, and
  § *Chains*, § *The review checkpoint*, § *One canonical home* and § *What was searched* point at
  it; `SKILL.md` step 7f selects and step 9 builds; `page-template.html` holds the CSS (head range,
  including the print rule for the `.ip-out` fill) and assembles one each in checkpoints C to E;
  both lens files say which signal earns which shape; `claim-falsifier.md` attacks a writer list for
  the path it missed; `evals/checks/figures.rb` grades shape and locators; and `tests/run.rb`
  asserts the template. `CAUSAL` lives in `checks/lib/review_map/vocabulary.rb` because two checks
  read it, and `lib/test/test_page.rb` fails when it and § *Impact paths*'s list disagree.
- **One stack reference per run, and the stack is invisible on the page.** `SKILL.md` step 2 detects
  Rails (`Gemfile`, `config/application.rb`), Elixir (`mix.exs`), Rust (`Cargo.toml`) or React (a
  `package.json` depending on `react`) and **names** one lens and one catalogue. Two stacks' roots:
  ask. None: degrade to the stack-independent page and emit no anchor. **Defaulting to a stack is a
  regression**: a Rails lens over a Go service invents findings, confidently.

  **A second lens is a layer, not an alternative.** A Rust backend reads `rust.md` then
  `rust-backend.md`, decided by whether the crates *the diff touches* depend on a server framework; a
  Cargo workspace is one root. Next.js reads `react.md` then `nextjs.md`, decided by whether the
  package the diff touches depends on `next`; a JavaScript workspace is one root. A second
  self-contained file would be a second canonical home for the shared lens.

  **A client beside a backend is the backend's, until the diff is only the client.** A Rails, Phoenix
  or Rust repository with a React app in it stays that stack whenever the diff touches the backend —
  that lens carries the client half. Only a diff confined to the client is the React stack.

  **Naming them is not reading them.** The lens is read at step 5, where its search recipes are the
  work; the catalogue at step 7, when a claim first asks for a URL — never at step 2, which would carry
  them as context through the consumer tracing where every token is re-billed per request.

  The stack **produces no section, no field, no tier, no component and no marker.** It changes the
  content of sentences, the nodes in a chain and the command inside a `pre.probe`.
  `report-format.md` § *One page shape* says so, and `page-template.html`'s header comment refuses a
  stack badge beside the severity chip and the verification badge.

  **Two things are deliberately not duplicated.** `rails-nextjs.md`'s three client-side sections
  (§ *The boundary: serializers to types*, § *Next.js*, § *TypeScript and the client*) are about the
  client and the wire, so the other lens files point at them in a clause. And the file keeps its
  Rails-shaped name; the pointer says why.

  **The LiveView boundary is that stack's payoff.** A `phx-*` attribute value and the
  `handle_event/3` clause that answers it have nothing at compile time linking them, and disagreeing
  crashes a process. Renaming an event in a `.heex` template without renaming its clause is the
  stack's canonical affected-but-unchanged code: step 5's table has a row for it, the search recipes
  search **both directions**, and it earns a checkpoint's chain.
- **The page never grades the change.** No severity scale, no risk score, no confidence percentage,
  no approval language. The product principle at the top of `SKILL.md`, repeated in its hard rules,
  and enforced structurally: the template has no chip that expresses a verdict, and its header comment
  says so.

  **A resolved tick is a verdict.** When a re-run finds that new commits answered a checkpoint, the
  checkpoint is **deleted**, with its reading-path stop and its rail entry, and nothing marks where it
  was. Striking it through or labelling it *resolved* reports progress toward approval.

  **A page may refuse a grade out loud, and the check knows the difference.** `page-invariants.rb`
  § 2 fails approval language in any form; a graded *noun* — risk score, overall risk, severity
  score — fails only where nothing negates it, so *"attention is a reading estimate, not a risk
  score"* passes. The negation test is per occurrence, inside a 48-character window bounded by
  sentence punctuation, and the negation must be a **whole word bounded on both sides** (POSIX `awk`
  has no `\b`: `no` matches inside *another*, `not` inside *notice*).
  `golden/invariants-risk-score-leading` and `-trailing` pin one boundary each — one per fixture, so
  each pins its own. § 2's graded-noun test and § 2c run on the **comment-stripped** copy, because
  real pages carry the template's comments verbatim.
- **Evidence tiers.** Five of them, listed in `report-format.md` § *Evidence tiers*, rendered as
  `span.tier`. A claim the diff shows directly carries **no** label — silence is the first tier.
  Labelling everything is noise, and noise gets skipped.

  **Changed and unchanged split by file, everywhere the page says either.** An untouched line of a
  changed file is changed code for the tier, the excerpt's `Unchanged` tag, the `.ip-aff` node, the
  impact lanes (*In this PR's files*, *Outside the diff*) and the *Affected, not changed* lists
  alike, because one word meaning two things on one page leaves the reader unable to tell which.
  `report-format.md` § *Evidence tiers* states it for the tier; § *Source excerpts* and § *Impact
  paths* state it for their components; `SKILL.md` step 6 files such a hop under *Trace*; and
  `excerpts.rb`, `impact-paths.rb` and `searches.rb` hold the tag, the node and the list against one
  changed set, `checks/lib/review_map/changed.rb`. `scripts/page-lint.sh`, relayed by `page-invariants.rb` § 10, warns on the three ways a
  label can disagree with that set — a sentence citing a file outside the diff with no tier, `from
  unchanged code` with nothing cited, `from unchanged code` on a sentence citing only changed files —
  never failing, because a hard failure on a label teaches a run to label everything; whether a tier
  is *earned* is the `evidence` judge's question.
- **Framework anchors are provenance, not evidence, and there is no sixth tier.** A doc link explains
  why a framework consequence follows; a console probe asks the reviewer's own application; a primer
  states the rule outright, at `--mentor` only. The claim keeps resting on a repo `file:line` at the
  tier it already carried. Where a claim came from is provenance, and provenance is not evidence.

  **A doc link may only be a row of the stack's catalogue, pinned to the version this app runs**,
  because the run cannot open a URL — a constructed path is a 404 the reader finds on the page's
  behalf, and an unpinned one documents a version this app may not run. **A probe is proposed, never
  run**, so the page shows a command and never output: a fabricated `=> …` is the most
  concrete-looking thing on the page and the one part that is fiction. A primer **holds** its
  checkpoint's one doc link rather than adding a second.

  `report-format.md` § *Framework anchors* owns the routing, the budget, the earning test,
  answerability and the label's three segments **alone**; `SKILL.md` steps 7g and 9 point at it; the
  selected lens's § *Runtime probes* holds the probes and the rule for running them safely; and
  `evals/checks/rails-anchors.rb` derives its allowlist from **every** catalogue file rather than
  hard-coding hosts — Rails-shaped name, stack-wide scope.

  **The failure mode is a page that links everything** and becomes a framework tutorial with a diff
  attached. An anchor is earned by a decision the reviewer has to make; a script can check that a
  link is real and legally placed, never that the judgment needed it.
- **The synthesis phase is where the agenda comes from.** `SKILL.md` step 7 takes the analysis notes
  and produces the page's argument: name the semantic delta, identify the human judgments, merge the
  observations that share one, rank by consequence if misunderstood, select the agenda, choose each
  one's representation, select its evidence, build the reading path, pick the impact chains, dedupe
  across the places a fact can land. **A run that goes from notes straight to prose writes one
  section per flow** — the per-layer page under new section names. The shortening happens in what
  gets *decided*, not in how the decisions get written up. Step 7 opens no file the notes have not
  already cited, and it is where the falsifiers' challenges arrive.
- **Affected-but-unchanged code is the product.** Step 5 of `SKILL.md` finds it, the lens files'
  search recipes are how, and it surfaces at three depths. The **checkpoint** that turns on it
  explains it, with the line in its *Look at* list. **Section 05** shows the crossings whole — one to
  three chains, with the entries they run through cited beneath the figure and pointing back at the
  checkpoint in a clause. The **evidence foot** holds what is real and cited but not something the
  reviewer has to decide about. **Nothing a reviewer acts on lives only in the foot**; a foot entry
  that is a judgment is a mis-filed checkpoint.

  **Record what was searched**, so an empty result reads as evidence rather than as omission. The
  record is `details.searched`, shut by default, inside the foot: `ul.sr-list`, one row per search, a
  `<code>` command and a result *clause*. The finding stays in the open prose — "nothing else reads
  this column" is a sentence a reviewer meets without clicking; the grep behind it is provenance. A
  finding left to be inferred from an empty row inside a shut toggle is hidden, not disclosed.

  These agree: `page-template.html` holds the component and its CSS; `report-format.md` § *What was
  searched* owns the form, the budget and the open/collapsed split **alone**; `SKILL.md` step 5
  points at it; `evals/checks/searches.rb` re-runs the recorded searches against the repository. That
  check scopes its affected-entry region on the verbatim `Affected, not changed` eyebrow, which appears
  twice — beside the impact panel and in the foot — so `</ul>` and `</section>` must stay among its
  region resets.
- **Step 10 lints the finished page with `scripts/page-lint.sh`, and the page carries no trace of
  it.** Shell and awk only: a user's run may depend on nothing the evals need, and Ruby is the
  evals'. A placeholder is its one FAIL, fixed before the final publish; a tier that disagrees with
  the changed set is a WARN whose sentence is corrected or left, in chat. Nothing about it reaches
  the page, which is the verification-badge rule applied to the run's own tooling. These agree:
  `SKILL.md` step 10 and its scripts table, `hooks/activity.json` (the call's purpose on the
  progress line), `tests/run.rb` and `self-test.rb` (its rows and the mutations behind them),
  `evals/checks/page-invariants.rb` § 10, which relays its tier lines as `completeness.rb` relays
  the gate, and `ci/generate-review-map.sh`, which runs none of it because the skill already has.
- **Completeness, and the one mechanical gate.** Every path in the diff appears in the page, and the
  gate runs on the finished page. The carrier is `div.gt.gt-paths` inside `details.evidence` at the
  foot, generated by `ledger-rows.sh --paths-only` as cells carrying `data-path`. It is a grid cell
  (`<div class="c" data-path="…">`) because `coverage-gate.sh` greps `data-path` page-wide and
  `page-invariants.rb` § 4 counts it on a `div class="c"` or a `<td>`. The inventory is unranked:
  where a reviewer's attention goes is said by the reading path, not by a column. `ledger-rows.sh`
  without `--paths-only` emits a four-cell form nothing calls; § *A future full mode* records it.

  The inventory is collapsed because it is *provenance*, which passes the reads-complete-when-shut
  rule. **The gate is never skipped because the list is out of sight**, and **nothing narrows it** —
  `--update` regenerates the inventory and runs the gate over the whole `BASE...HEAD` range; patching
  the delta's rows into the existing block is typing into the one cell `ledger-rows.sh` keeps
  untyped.

  Stated in `SKILL.md` step 3, explained in `report-format.md` § *The completeness invariant*, and
  enforced in step 10 by `scripts/coverage-gate.sh`. These agree: the script reads `data-path`, the
  template emits it on the grid cell, § *Section 6* requires it, and step 10 runs the script. The
  page-wide rule is a subset test (the page cites unchanged files everywhere); the gate is exact set
  equality against `git diff --name-only`, compared as whole strings — never substrings, because
  `api/Gemfile` matches inside `api/Gemfile.lock`.
- **A staged page must never look finished.** The page publishes early and fills in at one URL
  (`SKILL.md` step 9): a build banner while it is being written, a *pending* marker for every part
  that is coming, both removed at the final publish. Four states stay distinguishable — written,
  pending, *not written* because the run stopped, and omitted because the diff did not earn it. A
  stopped run needs a deliberate edit: pending is a promise. The form lives in `report-format.md`
  § *Build state*, the components are `.buildstate` and `.pending`, and `evals/check.rb --draft` /
  `--final` check both ends.

  **Omitted is not a stub.** A diff whose consequences stay inside it earns no impact section: the
  section and its rail entry go, and no stub says nothing reaches unchanged code — that is a clean
  bill of health with a marker on it.

  **The `id` on `<section class="cp">` is unique** because it is the anchor a later *stage* edits and
  the anchor a later *run* edits under `--update`. **Fill in with `Edit`, never re-`Write` the page**,
  and **never re-*read* the page whole** — grep an index of ids and citations, then `Read` with
  `offset`/`limit`; a whole-page read or rewrite costs the order of the page itself per stage.

  **The checkpoint is the unit of staging**, not section 03 — each `<section class="cp" id="cp-x">`
  arrives on its own. A checkpoint stub carries **the question**, so stage 2 publishes what the change
  asks the reviewer to judge before any explanation exists. **Section 05 publishes last**: every
  impact card's `p.ip-why` points at the checkpoint that judges it, so the `#cp-x` targets must exist
  first. `SKILL.md` step 9's milestone table orders it; `report-format.md` § *Impact paths* owns the
  pointer.

  The banner counts **parts still pending**, not *stage N of M*, because the total depends on how
  many checkpoints the diff earns. `checks/build-state.rb` greps "absence is not a finding", so that
  sentence must survive editing.
- **Effort decides whether the page is right, and it is invisible on the page.** `--effort high` (the
  default) and `--effort low` decide how hard a run works to be right. Two pages of the same target at
  the two efforts differ in their claims and never in their form: **no section, no marker, no chip
  and no sentence**.

  **The seam is ahead of the page.** Step 6 writes one analysis note per flow and sends one falsifier
  at each; step 7 synthesises while they read; step 8 folds the challenges in before a checkpoint's
  stub is replaced. A late challenge after a checkpoint has landed is still folded in — a claim
  retracted before the final publish beats one never retracted. § *Single-context, with one named
  exception* says why the pass is the exception; `SKILL.md` step 6c holds the numbers.

  **A verification badge is a severity chip.** "Every claim verified", a count of what the pass
  corrected, a `.verified` chip — each grades *the page*. So does a correction annotated with the
  history that produced it (*"the mistake the first version of this section made"*). **Correction
  replaces, never annotates** — `SKILL.md` step 8, a rule at every effort. Keep the fact, drop the
  autobiography.

  These agree: `SKILL.md` step 1 parses it, step 6c owns what `high` does and step 8 what happens to
  the result; `report-format.md` § *One page shape*; `page-template.html`'s header comment refuses the
  badge; `agents/claim-falsifier.md` carries the mandate and pins its own `model:`;
  `evals/checks/page-invariants.rb` §§ 2b and 2c fail a page that advertises having been checked or
  narrates its own drafting; `README.md` § *How hard it works* is the public wording. The falsifier's
  model is checked across the harness: `evals/e2e/run.rb` generates with the plugin loaded, and
  `profile.sh` prints what the subagent transcripts recorded. On a result line the skill's effort is
  `effort` and the producing model is `model`, both in `report.rb`'s group key.
- **`--update` buys cheapness with claims nobody re-read, and the page says which revision it
  describes rather than how much of it was re-read.** A re-run reads the commits since the previous
  map, re-analyses what they reach and edits that page in place. The saving is step 5; the price is
  that a carried claim was not re-verified.

  **The page is the state.** Every claim carries a `file:line`, every excerpt `data-src`, the
  masthead the revision — no sidecar, no new attribute. `$W/analysis/` is used when present and never
  required.

  **It must be visible, because parts of its page describe an earlier head**: one fixed sentence and
  an `updated from <sha>` masthead segment, both saying **which revision the content describes, never
  how hard the run worked**. A *resolved* tick or a *new/carried* chip is the severity scale; an
  answered checkpoint is deleted.

  **Carrying is about not re-tracing, not about freezing the agenda.** Step 7 re-ranks the whole
  agenda on every update. **Which checkpoints carry is a script**: `carry-plan.sh`, six
  preconditions joined by AND, failing to a *full* run. P6 replays the page's recorded searches,
  because the dangerous delta is a new consumer in a file no checkpoint cites. The resolved settings
  (effort, mentor, context) must match the previous run's, and an `.accountable-review.yml` changed in
  the delta forces a full run. **Every way it can go wrong leads to a full run** — a cache miss, a
  missing `rg`, a refused precondition. In CI the carrier is `actions/cache`, never the previous
  artifact.

  Owners, each **alone** for its part: `scripts/carry-plan.sh` (preconditions, carry rule);
  `references/update.md` (procedure; `SKILL.md` steps 1, 9, 10 and two hard rules point at
  it); `report-format.md` § *Build state* § *An updated page* (the wording and the refusals);
  `setup-ci/references/workflow.md` § *The previous map* (the cache, ripgrep, why not the artifact).
  Also agreeing: `report-format.md` §§ *Section 1* (masthead segment, merge-base), *One page shape*,
  *The review checkpoint* (delete, never tick) and *Source excerpts* (never carried across its file's
  delta); `page-template.html` (refuses the carry badge); `read-config.sh`'s `update` key and
  `references/config.md`; `ci/generate-review-map.sh` (conditional pass-through, manifest `@3`);
  `templates/workflow.yml`'s two cache steps; `setup-ci/tests/suite.rb`. Graded by
  `page-invariants.rb` §§ 2b, 2c and 2e (no recency marker on any page) and `build-state.rb
  --updated` (the disclosure, once), behind the `golden/invariants-update-*` fixtures — `-clean` must
  stay green, because a rule that fails a page for admitting its limits gets the admission removed.
  `tests/run.rb` covers each precondition either side of its boundary; the whole-run eval waits on a
  `prs.yml` entry with `update_from` (`evals/e2e/judges/IDEAS.md`).
- **Findings are a sample, not an audit, and the page asserts no coverage.** The skill explains;
  explanation is reproducible, defect discovery is not. The page carries no *no issues found*, no
  summary saying the diff was covered, nothing that reads as assurance — and **no standing caveat**
  either, because a sentence true of every Review Map is skipped and sits right above the first
  checkpoint. The caveat is stated once for the tool in `README.md` § *What a Review Map cannot do*.

  These agree: `SKILL.md`'s hard rules own the prohibition and the redirect; `report-format.md`
  § *The review checkpoint* and § *Section 3* carry the consequence; `page-template.html` refuses the
  caveat in a comment; `README.md` and `docs/review-map.md` are the public wording;
  `page-invariants.rb` § 2d warns when the caveat comes back, beside § 2b, which catches the page
  overclaiming — a rule written for either is blind to the other.
- **Deep-link mode is chosen once**, in step 1, from the four-rung ladder in `report-format.md` —
  driven by whether the head SHA is reachable on a remote. On an unpushed branch, plain text rather
  than a permalink that 404s. **A git that cannot answer is not the same as unpushed**: three states,
  and the middle one refuses.

  The rung decides whether anything is clickable, not the form. A line inside the diff links to the
  diff page; a line outside it links to a blob at the commit that line exists at — head for unchanged
  code, the diff's left side for removed code. **A citation that names a range links a range**, both
  ends on the same side.

  **One exception, a verdict rather than a judgement**: GitHub withholds some diffs behind *Load
  diff*, so those citations take the blob form and the excerpt beside them becomes `--diff`. The
  size rule is not the whole rule — a generated `db/structure.sql` is withheld at one changed line —
  and the verdict leans towards the blob, since a blob link where the diff would have rendered still
  lands on the line.

  These agree: `report-format.md` § *When the diff will not render* owns the rule **alone** and
  § *Deep links* the three URL forms and the ladder; `SKILL.md` step 3 runs the classifier once and
  step 9 points at both; `scripts/diff-render.sh` holds the verdict and its constants;
  `tests/run.rb` covers every signal it reads; `evals/checks/link-form.rb` re-asks that same script,
  which is why `golden/links-repo.sh` is a real git repository.

  **The template spells the anchor out at every line-bearing citation**, with `{{DIFF}}` and
  `{{BLOB}}` defined before any citation and `{{LINK}}` only where a citation names no line — an
  opaque placeholder teaches a run to publish an unformed link.

  **Every off-page link opens in a new tab, applied rather than typed**: `target="_blank"` and
  `rel="noopener noreferrer"`, set on load by the tail script `page-skeleton.sh` emits. The page's own
  links — same document, differing only by fragment — are exempt. These agree: `page-template.html`
  holds the pass and the comment saying not to type one, `report-format.md` § *Every off-page link
  opens in a new tab* owns the rule, `SKILL.md` step 9 forbids the attribute, and `tests/run.rb`
  asserts the rule in the tail and zero `target=` in the markup half, with a `self-test.rb` row
  behind the zero.

  **Asked and unable to answer is not an empty diff.** A `git diff` feeding a pipeline leaves the exit
  status at 0 and prints no rows, which reads as *no file is withheld*. `diff-render.sh`'s refs
  handling, `excerpts.rb`'s state-tag rule and `page-invariants.rb` § 5 each guard it.
- **Six sections, and each fact has one home.** The format is *not* one section per architectural
  layer: one behaviour crosses persistence, the API, the boundary and its cohort, and a section per
  layer describes it four times. Persistence, endpoint contracts and the backend/frontend boundary
  have **no sections of their own** — they are covered inside the checkpoint whose judgment turns on
  them. `report-format.md` § *One canonical home* carries the routing table and the one-sentence
  reference form. **The one home is for a finding and a judgment; background runs one way, into a
  checkpoint**, which repeats what it needs of a concept, *What changed* or a consequence in unchanged
  code so it stands alone, while no other section retells a checkpoint. **The agenda's version of the per-layer page is a checkpoint per file** — *Migration*,
  *Tests* — and it is cheaper to write than merged judgments, which is why a run reaches for it.
- **Context is earned per concept, names the repository rather than the framework, and its setting
  tunes the bar rather than choosing a document.** Section 02 sits between *What changed* and the
  agenda and introduces the pieces of *this repository* a checkpoint relies on and a newcomer would
  lack — a sequence of requests, a plugin wrapping a core method, a domain term a setting introduces.

  **Three lines hold it.** It is **earned**, so most pages carry none and the section is omitted with
  its rail entry — never a stub saying no context is needed. It says **what a thing is, never what the
  change did to it**. It is **depth, never a step**: every checkpoint already says what it needs of
  the concept, and an entry is earned where the fuller picture helps. And its entries are **concepts
  the checkpoints need, never the layers the diff touched**. The pointer each entry ends in — `span.ctx-used`, naming the checkpoints that rely on it
  — makes the last rule checkable.

  **`--context` / `review_map.context` is not a second document.** `auto` is the default and the rule
  above. `never` and `collapsed` pass `--mentor`'s subtraction test — delete section 02, or open its
  fold, and the `auto` page remains, with every checkpoint unchanged because none leaned on the
  section. `always` **lowers the bar and never fills the section**: an impact path's use counts, a
  clause-explained concept qualifies, the cap stays at five, and nothing qualifying still omits the
  section. `collapsed` is the one named exception to the reads-complete-when-shut rule, safe because
  an entry carries no claim. No value is announced on the page.

  **The rail does not close up when Context is omitted**: *01, 03* says a section went, which is true.

  **It holds one figure, and only one kind: the shift.** `figure.lifecycle.lc-shift` draws the
  request sequence before and after, when the change moved *which request does what* and two or more
  checkpoints turn on that (one checkpoint makes it that checkpoint's plain lifecycle). **The moved
  state is filled in both columns**, so the comparison survives stacked columns on a phone, and **it
  draws the main path and says so**, with differing cases a line each.

  These agree: `report-format.md` § *Section 2* owns the rules and § *How much Context* the four
  values **alone**, with § *One canonical home*, § *The agenda budget*, § *Build state*, § *Mentor
  mode*, § *A future full mode* and § *Topology figures* (the shift's shape) pointing at it;
  `SKILL.md` steps 1, 7k and 9 and `references/update.md`; `page-template.html` holds `dl.ctx`, its rail entry
  and `details.ctx-fold`; `tests/run.rb` and `self-test.rb` assert its place, pointers, absences and
  exactly one figure; `checks/start-here.rb` warns on an entry with no pointer or a dead one, behind
  the `golden/context-*` fixtures, and reads through the fold; `figures.rb` grades the shift behind
  the `golden/figures-shift-*` fixtures and `figures-context-chain`; the CI half is `read-config.sh`,
  `references/config.md`, `ci/generate-review-map.sh` (always passes `--context`) and
  `setup-ci/tests/`; `README.md` and `docs/review-map.md` are the public wording. Whether an entry was
  worth writing is judged; `evals/e2e/judges/IDEAS.md` § *§ 02 context* records that judge.
- **The order is the reviewer's path, and the checkpoint owns the explanation.** *What needs your
  attention* teaches the judgments; *Read the code in this order* is the moment they open the code;
  *Impact outside the diff* is the same change through one lens. Everything after the attention
  section **points back** at it — a checkpoint never defers a step of its explanation forward, and the reading
  path and the impact panel never re-explain one. The reading path is **one list**: what most needs
  judgment and what to read first are the same question. Every other file is accounted for in the
  evidence foot, unranked.

  **Pointers have exactly two names: *Checkpoint A* and *Impact path A*.** The flows step 6 clusters
  are the run's unit of **analysis**, named in `$W/analysis/` and nowhere on the page; the three share
  one alphabet, so nothing local tells a run which is its own. **The page never writes `§`** outside a
  `<code>` span or an excerpt: a section of the page is named by its linked title, a repository
  heading in words with its file cited. These documents name the page's sections by title and keep
  `§` for their own headings, because a run writes in the voice it reads.

  `report-format.md` § *One canonical home* owns both rules **alone**; `SKILL.md` step 6 states the
  first where the labels are minted; `page-invariants.rb` § 7 (designator, behind
  `golden/invariants-flow-designator.html`, which plants it beside a correct *Impact path A*) and § 8
  (section sign, behind `golden/invariants-section-sign.html` and its `-quoted` twin) grep the
  comment-stripped copy.
- **Source excerpts are quotations, and the page reads complete without them.** A collapsed
  `details.excerpt` holding verbatim code, in two variants — `--diff` for changed lines, `--source`
  for unchanged ones, which carries the product because no diff view can address an unchanged line.

  The page reads completely with **every excerpt closed** — judged **field by field**: a citation
  elsewhere does not rescue a field whose only `file:line` sits inside the collapsed block. An excerpt
  sits **in the *Look at* entry it confirms**, inside the checkpoint's supporting evidence, and never
  in the evidence foot; the one open excerpt is the inline snippet an explanation may show, which
  explains rather than confirms (see *Narrative first* above). The
  quotation is **generated by `scripts/excerpt.sh`, never typed**. **`data-path` is reserved to
  inventory cells**; excerpts carry `data-src`.

  **The tint is applied, never authored, and the state tag is computed, never copied.** `--at`
  requires `--base` and derives the tag from the diff. These agree: `scripts/excerpt.sh` computes
  them, `report-format.md` §§ *Source excerpts* and *Syntax tint* own the rules and the closed tag
  vocabulary **alone**, `page-template.html` holds the `--syn-*` tokens and the tinting script, and
  `evals/checks/excerpts.rb` fails a page shipping `hljs-` classes in its markup or a tag the diff
  contradicts. A language added to `guess_lang` needs its `<script src>` in the template, or it tints
  nothing, silently.

  **Quoting a changed file at head is right** — a hunk cannot show that a table has *no* `CHECK`
  constraint — so the rule constrains the tag, never the quotation. **The budget's test is that a
  citation is load-bearing for a decision the reviewer must make.** The budget, the permitted
  locations and the rung adjustment live in `report-format.md` **only**.

  Watch for pages whose excerpts are all `--source`; seeing the hunk is often what a judgment turns
  on, and nothing warns when it is missing.

  **In a *Look at* entry, the excerpt's summary location is the entry's citation.** An entry is
  title, clause, then *either* an `a.path` *or* an excerpt generated with `--in-entry` (no summary
  why, because the clause is right above it). A short entry citation carries an excerpt by default,
  and the per-checkpoint ration covers only excerpts that add to the prose. These agree: `excerpt.sh`
  links `.ex-loc`, `page-template.html` assembles entries that way, `report-format.md` § *The review
  checkpoint* and § *Source excerpts* own the rule, `excerpts.rb` reads a linked location, and
  `tests/run.rb` asserts both the script and the template, with `self-test.rb` rows behind each zero.
- **Impact paths are section 05's figure, and the edge is the point of them.** A path runs from
  changed code, through the affected-but-unchanged code that gives the change its consequence, to an
  observable behaviour, every hop past the first carrying its incoming relation as a causal verb.
  1–3 paths, 3–5 nodes each, one path per `.ip-card`, at least one `.ip-aff`, one `.ip-out` last, one
  `p.ip-why` per card.

  These agree: `page-template.html` holds the CSS (head range) and the panel assembled whole, and its
  comments own the lane crossing — `--ip-drop`, the elbow, the dotted divider; `report-format.md`
  § *Impact paths* owns the panel's rules, budget and `p.ip-why` **alone**, while § *Chains* owns what
  it shares with `figure.chain`; `SKILL.md` step 7i decides both and step 9 points at them;
  `evals/checks/impact-paths.rb` carries the rules and reads `CAUSAL` — **extend the vocabulary there
  and in the reference together**; the `golden/impact-*.html` fixtures prove each rule fires; and
  `evals/checks/link-form.rb`'s `CITATION` pattern covers compound classes, so every `a.path.ip-loc`
  gets that check's rules.

  **The cap stays at 3** — a consequence that does not fit keeps its entry in the affected list and
  its explanation in the checkpoint. **A `p.ip-why` orients and points; it never walks the hops.**
  Shape is a FAIL and vocabulary a WARN, because a hard failure on a verb teaches a run to mislabel a
  true edge. Whether each edge is **true** is `evals/e2e/judges/impact.md`'s question; whether these
  are the right paths has no judge yet (`evals/e2e/judges/IDEAS.md`).
- **The skeleton is emitted, never typed.** `references/page-template.html` carries four `SKELETON:`
  markers. Everything in the head and tail ranges — the `<head>`, the themes' token blocks, the
  highlight.js tags and the tint script — is written straight into the page by
  `scripts/page-skeleton.sh`, once, at the top of stage 1. A run never reads or types those bytes;
  it reads the markup between the markers, via `--markup`. **Every colour on a published page comes
  from a script**, so a half-declared token cannot be produced by a run.

  These agree: the template holds the markers and the bytes, `page-skeleton.sh` extracts them,
  `SKILL.md` step 9 calls it once and forbids writing a `<style>`, a `:root`, a colour or a `<script>`
  into the page, and `tests/run.rb` proves the script holds no bytes of its own by **partition**:
  strip the markers and the preamble, and head + markup + tail must be the template byte for byte.
  Two of `self-test.rb`'s cases mutate the *script*, because a template mutation moves both sides of
  that comparison together.

  A marker holds no opening `style`, `script` or `svg` tag (`Page#range` re-opens on its own `from`
  pattern), and each marker is **one line** (extraction is a line range over it).

  **The markup half contains no `<svg` and no literal tint class**; `tests/run.rb` counts both at
  zero. The template's excerpt comment describes that class rather than spelling it.
- **Three themes on every page; the repository picks the default and the reader picks theirs.**
  Daylight, Workshop and Field Notes share every byte of markup and every base rule; a theme is one
  file under `references/themes/` — fonts, tokens, overrides — and `page-skeleton.sh` writes **all**
  of them at the template's `SKELETON:THEME` line, **after** the base styles so overrides win, every
  one but the default carrying `media="not all"`. The default comes from `--theme` >
  `ACCOUNTABLE_REVIEW_THEME` > `review_map.theme` > `daylight`; `page-skeleton.sh` reads the file
  through `read-config.sh`, whole, and refuses an unknown name or a file the parser refuses rather
  than defaulting. The *Aa* menu the tail script builds into the masthead switches the theme and
  light/dark/auto; a head script applies the saved choice before first paint. Two `localStorage`
  keys, every call in a `try`.

  **Every byte of it is emitted, none of it typed.** The menu's CSS is in the head range and its
  markup is built at load, so a run neither reads nor writes any of it; `tests/run.rb` counts the
  menu at zero in the markup half, with a `self-test.rb` row behind the zero.

  **A theme is a look, never a page shape.** No skill flag names it, the run never chooses it, and a
  page's content is identical in all three. A theme treatment (a highlighter, a glyph on `p.open`)
  **applies to every instance of its component alike** — a theme that marked one checkpoint
  differently from another, or used red on a claim, would be the severity chip as a palette — and no
  theme boxes `.gap` like the question: the GAP is a quieter note beneath which only `p.open` is a box.

  These agree: the theme files; the template's marker and the comment beside it; `page-skeleton.sh`;
  the tail script's menu and the head script; `read-config.sh`'s theme list, which
  `setup-ci/tests/suite.rb` compares with the directory; `references/config.md`;
  `ci/generate-review-map.sh`, which passes a `--config` file's theme through the environment;
  `tests/run.rb` (the partition with every theme spliced in, the menu's absence from the markup half,
  the guarded storage, every theme's colours on bare `:root` and in both dark blocks tagged by
  selector, and the refusals); and `evals/checks/frozen.rb`, which grades the template with the themes
  spliced in, because the bare template declares no colour.
- **Theme tokens.** Every colour is defined on bare `:root` *and* redefined in both dark blocks
  (`prefers-color-scheme` and `[data-theme="dark"]`). A colour declared only inside a media query is
  the classic unreadable-artifact bug. `evals/checks/page-invariants.rb` § 6 enforces the three
  states and `excerpts.rb` enforces it for the excerpt tints. The `--syn-*` tints are counted **by
  name** — `--syn-key` in `excerpts.rb`; `--syn-key`, `--ex-add`, `--primer-ink` and
  `--primer-rust-ink` in `tests/run.rb` — because three blocks existing is not a colour in all three.
  Each theme's dark half is ours; `.ip-out`, the one filled node that inverts, is written against
  tokens so it inverts relative to the page in every theme.
- **Semantic colour families, and a rule about what each may mean.** `--nav-*` (slate), `--gap-*`
  (ochre), `--unchanged-*` (teal) and `--prov-*` (plum), plus the primer frames `--primer-*` (red)
  and `--primer-rust-*` (graphite), each carry the same five slots — `bg`, `bg-2`, `rule`, `rule-2`,
  `ink` — at fixed lightness and chroma per slot, the dark half the light ramp reflected. Hues move a
  few degrees between themes; meanings do not. `--primer-rust-*` breaks the ramp once: its `rule-2`
  is near-black, the frame's identity. All of it lives in the theme files, emitted by
  `page-skeleton.sh`: a run never types a colour.

  **The rule is the system.** Slate means *you can click it* and appears on nothing else. Ochre means
  *something is unsettled and the page is saying so* — `p.open`, the inferred tier, the build banner —
  never a severity. Teal means *this code is not in the diff*: the `from unchanged code` tier, the
  dashed `.ip-aff` node and its legend key, the *Affected, not changed* lists. Plum means *how a thing
  is known*: the excerpt `.tag`, `details.searched`, the evidence foot, the probe label. Green and red
  inside an excerpt mean added and removed lines, there and nowhere else.

  **The test any hue must pass: it states a fact about the repository or about provenance, never a
  judgment of the change.** *Not in the diff* passes; a hue for *risk*, *confidence* or *how hard the
  run looked* fails. **The primer frames are not a meaning**: they frame `aside.primer` and reach
  nothing else — Rails red so a reviewer new to the stack recognises the block written for them, and
  graphite for Rust through the variant class `aside.primer.pr-rust`, which re-points every
  `--primer-*` slot. The class is the stack's, read off the doc link's host, and `rails-anchors.rb`
  § 8g fails a mismatch either way. Red on anything the page asserts about the change is the severity
  chip as a palette. Phoenix gets the same shape once `elixir-docs.md` opens. `report-format.md`
  § *Mentor mode* owns the page-level rule.

  `.ev-list` is unscoped because it appears in section 05 and in the foot, and both carry the teal
  rule. `page-invariants.rb` § 3 matches `class="tier` with any family modifier, behind
  `golden/invariants-tier-modifier-only.html`, which does not quote the attribute in its own header
  comment because § 3 reads raw bytes.
- **A published example is regenerated every release, never edited, and nothing said about it is
  typed.** `examples/` holds real runs against public pull requests, served at
  `wyeworks.github.io/accountable-review` by `.github/workflows/pages.yml`, which uploads that
  directory and nothing else — so the tooling lives in `bin/`. Public repositories are required: a
  map whose every citation 404s is not an example. Each example is the run's `index.html` and the
  `manifest.json` written beside it, and **the manifest is both the pin and the provenance**.
  `bin/examples regen` generates through `ci/generate-review-map.sh --output` at the pinned head with
  the manifest's settings, refuses a page `check.rb --final` fails, and reuses the e2e harness's
  checkout, force-push guard included. `render` writes every count, date and version into the named
  `examples:begin` regions; `check`, in `bin/evals offline`, fails while a manifest names another
  version than `plugin.json`, so a version bump is red until the examples are regenerated. **A
  regenerated page is read before it is committed**, and a worse one is re-run, never edited. Prose
  outside the regions says why a pull request was chosen and nothing a regeneration could falsify.
  These agree: `bin/examples`; `examples/README.md`, which owns the provenance rule and the recipe
  **alone**; `examples/index.html`; `README.md` § *Example Review Map*; `CONTRIBUTING.md`
  § *Releasing*; `bin/evals` and `validate.yml`, which run `check`.
- **The progress line is read, never guessed.** Two surfaces show a run in progress: the e2e board
  (`evals/e2e/progress.rb`) and the status line `hooks/progress.ts` sets in an interactive session.
  Each field comes from something the run produced: an engine event or a transcript line, the staged
  page, the clock. **Activity is shown by purpose, never as a step**, because steps interleave.
  **The one estimate is the bar, labelled `~`**, and outside the harness it needs a recorded history:
  the mod writes its own generation times to `$.store`, per repository and per kind of run (high,
  low, `--update`), only for a run whose coverage gate passed before its turn answered, excluding
  time waiting between turns. With nothing recorded it shows elapsed time and no bar.

  **What the run spends is read too, and never reaches the page.** Tokens are the usage of every
  `turn.step` the run makes, the main loop's and its falsifiers'; the 5-hour figure is how far the
  engine's `five_hour` reading moved since the run's first one, and a window that reset in
  between shows no share. The end of a run logs one line to the transcript. Codex has no surface a
  plugin draws on, so `scripts/usage.sh` reads its rollout log and the run says the same line in
  chat at step 10 (`references/hosts/generic.md`). A cost figure on the page would grade how hard
  the run worked, so none is written there.

  **One table, two languages.** `hooks/activity.json` is read by Ruby and by JavaScript;
  `tests/activity.rb` refuses a pattern the two engines read differently, and a label that reads as a
  step counter. **It observes and does nothing else**: every hook passes its event on unchanged behind
  a `.catch` that still does.

## Invariants the CI setup adds

Same rule as above: editing one of these means checking the others still agree.

- **`.accountable-review.yml` means the same thing wherever it is read.** The page keys — `effort`,
  `mentor`, `context`, `theme` — are read by the skill itself, so a person's run and a CI run of one
  repository start from the same settings; `update`, `trivial_*` and `delivery` are CI's. Precedence
  is flag > file > default in both, and every reader parses the **whole** file with
  `skills/review-map/scripts/read-config.sh`, so a key CI refuses stops a person's run too. The CI
  adapter passes every page key **explicitly**, defaults included (`--mentor off`, `--context
  auto`), because the skill reads the checkout's file under its flags and an absent flag would be
  decided twice.

  These agree: `read-config.sh`; `SKILL.md` step 1 and `references/update.md`; `page-skeleton.sh`;
  `ci/generate-review-map.sh`; `setup-ci/references/config.md` § *Who reads which key*, which owns the
  split **alone**; `README.md` § *Configuration*; and the two suites, `tests/run.rb` for the local
  refusal and `setup-ci/tests/suite.rb` for the explicit pass-through.
- **Generation does not know where the page goes.** `review-map` writes a portable static directory;
  `ci/delivery/deliver.sh` is the only thing that knows what happens to it afterwards. A team that
  puts Review Maps on a static host adds one file under `ci/delivery/` and changes one line of
  configuration, and nothing about how the page is produced moves.

  These agree: `deliver.sh` dispatches and prints the DeliveryResult; a provider is one `<name>.sh`
  reading `AR_*` and printing `key=value`; `references/delivery.md` owns the contract **alone**; the
  workflow template guards its upload step with `if: steps.delivery.outputs.provider ==
  'github-artifact'`; and `tests/suite.rb` asserts the four canonical fields.

  **The seam decides how a re-run finds the previous map**: a cache keyed on the pull request, never
  the last artifact, which would make the workflow a second thing that knows the map is an artifact.
  `references/workflow.md` § *The previous map* owns that.

  **A destination threaded back into generation breaks the seam** — an `--artifact-name` on
  `generate-review-map.sh`, an "upload the map" step inside the skill. If a provider seems to need a
  change in `review-map` or `generate-review-map.sh`, the seam is in the wrong place; move the seam.

  `github-artifact` does **not** move bytes: it names the destination and the workflow's standard
  upload step does the transfer, which is why the provider emits `artifact_name` and
  `retention_days` as extra keys, and why extras are carried through to `$GITHUB_OUTPUT`.
- **Two rules decide whether CI generates a Review Map, both measured over application paths only.**
  `ci/application-code.sh`, from a `scope` step every later step is guarded on. Rule 1: does the diff
  change application code at all. Rule 2: is it more than trivial — skipped when application files ≤
  `trivial_files` **and** application lines ≤ `trivial_lines` (2 and 20), read from
  `.accountable-review.yml` at run time and never rendered into the YAML.

  **AND is the polarity, and it stays.** A needless map costs a model run somebody ignores; a missing
  one is invisible — so the suppressing predicate is the one that must be hard to satisfy.
  **Application paths only is why this cannot be a job `if:`**: the payload's counts are whole-diff
  and carry no file list. The gate **fails open**, and a skip says which rule fired and the counts.

  **The same question is asked over `<previous head>..<head>`** by `ci/map-still-current.sh`, because
  with a map per push `BASE...HEAD` cannot see that *this* push changed no application code. It adds
  no rule — `application-code.sh` over the delta, `carry-plan.sh` over the restored page — and
  downgrades the scope step's own verdict, so no guard moves. **Only `no-application-code` counts,
  never `trivial`**, and **it stands the job down rather than rewriting the page**.

  **What counts as application code is the repository's to correct, never to switch off.**
  `review_map.paths.code` and `.skip` are checked before the built-in list, a path in both is code,
  and a path in neither falls through to the built-in rules and from there to code — so the override
  cannot turn fail-open off, and a configured verdict prints `configured`. This repository is the
  first user: its skills are Markdown.

  These agree: `ci/application-code.sh` holds both rules and the override; `ci/map-still-current.sh`
  the composition **alone**; `read-config.sh` and `references/config.md` the four keys (the two lists
  are the schema's only non-scalars); `templates/workflow.yml` the `scope` step and the guards;
  `references/workflow.md` § *The application-code gate* owns the reasoning **alone**; `SKILL.md`'s
  hard rules forbid counting anything but application code or baking a number into the YAML;
  `tests/suite.rb` covers each threshold either side (`bulky`, `spread`, `masked`), each override
  either side plus an unmatched path staying code, and both halves of the second question;
  `docs/ci.md` restates it.
- **The CI page and a person's page are the same page.** `--output <dir>` changes where the bytes
  land and nothing else: same sections, same depth rules, same excerpt budget, same completeness
  gate. `SKILL.md` step 1 owns the flag, step 9 makes the stages save points rather than publishes,
  step 10 has nothing to publish at the end. **A cheaper CI page is the regression** — skipped
  excerpts, skipped flows on a big diff, a skipped gate — and it looks like thrift.
- **A Review Map names its revision, on the page.** Two short SHAs in the masthead's `Revision`
  cell, head → base, beside the branch names. These agree: `report-format.md` § *Section 1* states
  the rule, `page-template.html` carries the cell, and `ci/generate-review-map.sh` refuses to deliver
  a page that does not contain the head's short SHA. It is not CI-specific: a page that describes an
  earlier revision while looking current is the one failure a reader cannot detect from the inside.
- **The workflow has exactly one settings axis, and the axis is *when*.** The draft guard, the fork
  guard, the concurrency group and `contents: read` have no knobs. Everything a team configures
  **about the map** is read from `.accountable-review.yml` at **run** time, so changing it never
  means regenerating the file — which is why `tests/suite.rb` checks retention through `deliver.sh`
  rather than by grepping YAML.

  What is rendered from flags is **when a Review Map is generated** — the push trigger and the bot
  authors — plus **whether the link is commented on the pull request**. **The test is whether the
  decision can be made *before* the job exists.** How big a change has to be fails that test, because
  what it counts is application paths, so it is run-time configuration (§ *The application-code
  gate*). `SKILL.md` step 3 confirms the flags in one block before writing, and § *What it
  configures* splits its table along that line.

  **The defaults** are `opened` in, `synchronize` out so a pull request gets one map, dependabot
  skipped, and small changes skipped by the gate above.

  **The knobs are safe because of the read-back.** The rendered file carries a `# Decisions:` line
  holding the canonical, complete flag form of all of them; `install-workflow.sh` recovers it and
  passes it ahead of the current call's flags, so re-running setup to move the version pin does not
  revert a team's decisions. The line is a pure function of the flags.

  **One ref is recorded there too**: `--plugin-branch`, because tracking a branch (this repository
  dogfooding itself) is a choice a re-run must not swap for a tag; a release pin is recorded by its
  absence, and `manifest.json`'s `plugin.commit` keeps a branch build attributable.

  These agree: `templates/workflow.yml` holds the `SETUP:IF:`/`SETUP:END:` blocks and the line,
  `render-workflow.sh` resolves them, `install-workflow.sh` recovers them, `SKILL.md` step 3 confirms
  them, `references/workflow.md` §§ *Triggers*, *The guard* and *The line that records the decisions*
  own the rules **alone**, and `tests/suite.rb` checks that each knob changes bytes.

  **The guard expression has two traps no YAML parse catches.** Actions expressions have **no
  arithmetic**, so `(additions + deletions) > 50` is an invalid file — compare the two counts
  separately. And in a folded scalar a **more-indented line is not folded**, so its newline survives
  into the expression; every line sits at six spaces and the operators lead their lines.
  `tests/suite.rb` asserts both structurally.
- **Idempotency is decided by comparing bytes, so nothing rendered may vary.** No timestamp, no run
  id, no randomness, no "generated on" comment — `install-workflow.sh` tells "already set up" from
  "edited by hand" by `cmp`. `tests/suite.rb` asserts the rendered file holds nothing shaped like a
  date, against the **whole file, comments included**, and renders it under a stubbed `date`
  answering two different days and requires the same bytes. The `# Decisions:` line is allowed
  because it is a pure function of the flags: what is forbidden is a value that varies **between two
  renders of the same request**.
- **Drift is reported, never resolved.** A hand-edited Accountable Review workflow is a file a team
  owns. `install-workflow.sh` prints the diff and exits 3; `--update` is the only way past it, and
  `SKILL.md` step 3 says to show the user and ask.
- **CI must not become the place that runs the application.** The page proposes validation commands
  and never runs them. The template starts no service, runs no migration, and executes no script from
  the pull request; `tests/suite.rb` asserts all three against the comment-stripped file.
- **The workflow posts one comment per revision, and that is the entire write surface.** A link to
  the Review Map and the revision it describes, marked `<!-- accountable-review -->`: a map for a new
  head is a new comment, because an edit notifies nobody, and a re-run at a head a comment already
  names (a reopen, a ready/draft toggle) edits that one. It is what `pull-requests: write` is for and the only thing that
  scope is used for, and `--no-pr-comment` removes the step and the permission **together**. The
  comment exists because a map nobody is told about is not read.

  **No verdict, ever.** No check run, no status, no review, no label, no approval, and nothing in the
  comment that grades the change. A passing check is a verdict whatever it is named.

  **Containment is by injection, not scope**: Actions has no per-step permissions, so `GITHUB_TOKEN`
  reaches only the step that names it in `env:`, and the step that runs a model over a contributor's
  branch does not. `tests/suite.rb` asserts exactly one step names the token.

  **The comment reads the DeliveryResult** — a browsable provider's `stable_url` linked as a page,
  the artifact provider's download URL as a zip — and never knows about artifacts directly.

  These agree: `templates/workflow.yml` holds the step and the permission behind the same
  `SETUP:IF:comment` blocks, `render-workflow.sh` renders both or neither, `SKILL.md` step 3 names the
  write scope out loud and its hard rules bound what may be posted, `references/workflow.md` § *The
  comment* owns the rules **alone**, `references/delivery.md` owns what it reads, and
  `tests/suite.rb` executes the step against a stubbed `gh` on the create, the same-head and the new-head path.
- **The product principle reaches the artifact, not just the page.** `manifest.json` is provenance —
  which revision, which plugin version, which settings, whether the coverage gate passed — and carries
  no severity, no score and no approval. The job summary says what the Review Map is *for* and that it
  does not review the change.

## The catalogue is the one thing a run cannot verify

The documentation catalogues (`rails-docs.md`, `elixir-docs.md`, `rust-docs.md`, `react-docs.md`)
are allowlists, and a run takes URLs from them without opening any; `rails-docs.md`'s opening says
why a live search per anchor is worse. A catalogue's correctness is therefore a **maintenance**
property with a date on it, and `evals/verify-catalogue.sh` is the maintenance: every row in the
**pinned** form a run actually emits, every series in the floor, table rows only, dated. A plausible
URL constructed from a naming scheme and never opened is the defect no script catches and no care
while writing prevents.

**A catalogue written from memory ships closed**: it withholds every link until a dated
verification line replaces its § *Version* paragraph. `elixir-docs.md` and `react-docs.md` are
closed — an Elixir or React run anchors with probes and prose, and `--mentor` there produces no
primer — and `verify-catalogue.sh --catalogue <file>` is each one's **release gate**. `react-docs.md`'s
sweep answers one question first: whether each host addresses its current major at the versioned form
§ *Pinning* writes; if not, that § and `rails-anchors.rb`'s React arm change in the same commit.
`rust-docs.md` is **open**; the verifier checks newest releases only, so its § *Version* also records a
hand sweep across the floor, and a Rust catalogue change is re-verified the same way.

**Every doc link is pinned, for checkability rather than precision**: a pinned page names its
version, so the reader can hold it against their lock file. Below the floor, or with no verified
path for the series, **no link at all**. Pinning fixes the URL and not the sentence, which is what
the marks are for — `‡ probe` (the behaviour moved; name the setting, propose a probe) and
`‡ since X` (state the default, name X). Different actions, not severities. **The probe is the
version-proof anchor.**

**Rails pins one series per app; the others pin per package**, so a correct Phoenix page carries
several version segments, and generalising the one-series rule fails every correct Phoenix page
(`golden/anchors-hexdocs-clean.html`). A hexdocs path keeps its package
(`ecto/Ecto.Changeset.html#cast/4`). **Rust pins per crate and the toolchain separately**
(`golden/anchors-docsrs-clean.html`), and a docs.rs path keeps the crate's name *and* its identifier
(`docs.rs/actix-web/actix_web/…`). **React pins per major, `react` and `next` separately**
(`golden/anchors-reactdocs-clean.html`), and a nextjs.org path keeps its router, because the same
function under `docs/pages/` resolves and documents code the app does not run.

These agree: each catalogue's §§ *Version*, *Pinning* and *What the marks mean* own the forms and
marks **alone**; `report-format.md` § *Framework anchors* says why the page cares; `SKILL.md` step 2
records the versions (skip it and no doc link can be emitted) and step 7 carries the two rules;
`verify-catalogue.sh` verifies; `checks/rails-anchors.rb` enforces offline — a version segment on
every link, one series for Rails only, no unsubstituted `{version}`, no other series' override path,
whole-token allowlist matching; and `page-template.html` shows the doc link pinned with the version
as a placeholder, never unpinned and never a literal version.

## Single-context, with one named exception

The skill runs in one context and spawns exactly one kind of agent, the falsifier that reads one
analysis note. `SKILL.md`'s hard rules say so. **Steps 5, 6 and 7 never fan out**: the first two
span the whole diff by nature — splitting them by layer moves comprehension fragmentation from the
human to the agents — and step 7 holds the whole agenda at once to merge and rank it. When
specialists arrive, the seam is per-flow, never per-layer.

**Why the falsification pass is the exception.** Its seam is per **analysis note** — a whole
behaviour, nothing fragmented the analysis had not already separated. It is read-only and returns
*challenges*, not page content: the parent writes every word and opens every cited file before
acting on one. It reads a note rather than a published section, so nothing is wrong in public while
a challenge is in flight; and step 7 reassembles the parent's own notes, not several agents'
conclusions. A future exception has to pass the same tests.

**It costs tokens, not wall clock.** The parent keeps drafting while the falsifiers read, so blocked
time is negligible, but their own contexts are billed — which is why `agents/claim-falsifier.md`
pins its own model, and why a cost quoted from the parent transcript alone is short. **A run that
waits on them turns the cheapest step into the most expensive.** The numbers live in `SKILL.md`
step 6c and `evals/README.md` § *Profiling one run*.

A very large diff strains a single context, and `SKILL.md` says to *report* the strain rather than
quietly skim.

## Open problem: how to sample a diff too large to read

`SKILL.md` says to report the strain; it does not say how to *choose* what to skim. What a solution
has to respect:

- **The agenda is not the answer.** A run that runs out of room runs out tracing consumers at step
  5; the synthesis step cannot rank judgments it never found. What the agenda changes is reporting:
  a strained run owes a statement of which region it skimmed, and `$W/analysis/` shows which flows
  got a trace and which a glance.
- **Completeness is not reading everything.** Every path must appear in the page; the question is
  which files to *open*, and the inventory is what makes a shallow pass on the rest legitimate.
- **Cheap signals exist and are unused**: line counts per file, the status letter, whether a file
  has a matching spec, whether a commit message names it, whether anything outside the diff
  references it. `ledger-rows.sh` already prints the first two.
- **The work is not equally compressible.** A migration and an API contract are small and
  load-bearing; tracing every consumer is where the volume is, and a trace stopped one hop short
  still finds most of what matters. The budget should be spent unevenly.
- **Whatever is skipped has to be visible**, in *What changed*, in the voice of any other stated
  limit — a fifth build state alongside written, pending, not written and omitted.

Per-flow decomposition grows the aggregate budget but not step 7's, which must hold every note at
once.

## Open problem: threading a review pass through the map

Running the project's code-review pass as well, and threading its findings through the map, is not
built and has no flag — a name reserved for something nobody is writing is a promise on the command
line.

**It is not "run `/code-review` and paste the output".** A review pass produces graded findings;
this page carries no verdict, and a graded finding list is one word per item away from a ranked
checkpoint list. **A review finding enters the page as a claim to verify, never as a finding to
display**: step 8 reads the file before any claim reaches the page and drops what does not survive,
and step 5 routes a consequence to the code it reaches. A verified finding lands in the checkpoint
whose judgment it bears on, in the page's own voice, with the severity stripped; one that is a
judgment of its own becomes a checkpoint through step 7. The review pass becomes a *search strategy*
feeding step 5. `--effort high` already runs the routing half (steps 6c and 8); what is unsolved is
where the claims come from and how a graded source is stripped.

To settle before writing it:

- **A sixth evidence tier or not.** Something like *reported by the review pass, verified against
  the file* would change an invariant four files agree on (`report-format.md`, the template's
  `span.tier`, `page-invariants.rb` § 3, the cases). The alternative is that a verified finding takes
  an existing tier and its origin is provenance.
- **Discover the review command, do not assume it.** A repository with none degrades to the ordinary
  page, saying so.
- **Findings and checkpoints do not line up one to one.** A review comments per hunk; this page is
  per judgment. The mapping follows § *One canonical home* and has to be written down.
- **The skill still never posts anywhere.**

Do not publish a page with the review part marked *pending*: pending is a promise, and nothing is
writing it.

## Boundaries the skill must keep

These are deliberate scope limits, not omissions — do not "improve" the skill past them.

- **It helps a reviewer decide; it does not decide.** The page carries evidence, relationships,
  invariants, uncertainty and validation steps, never a verdict. A review pass threaded through the
  map borrows the review's *search*, not its conclusions.
- **It links to the manual; it does not reproduce it**, and it never executes what it proposes: the
  skill does not boot the application under review. Changing that is a new decision with its own
  safety design, not an extension of this one.
- **`review-map` never posts to GitHub or anywhere outside the artifact.** If a link needs to reach a
  pull request, the generated workflow's own last step posts it, after generation and in a different
  process; threading it into the skill would put a write token in the process that reads a
  contributor's branch. `setup-ci`'s hard rules and `references/workflow.md` § *The comment* own the
  CI boundary.
- It never writes the page into the repository under review — a work directory under `$TMPDIR` only,
  **derived** in step 1 from the repo and the target, or the directory `--output` names, which
  `ci/generate-review-map.sh` refuses to let sit inside the checkout.
- It republishes to the same file path across stages, and the path is derived, not picked, so a
  re-run finds the previous page by rule rather than memory. **A fresh run never publishes over an
  earlier session's page**: `--update` keeps one PR at one URL, because it edits that page; a fresh
  run in Claude Code publishes a new Artifact, since overwriting means reading the old page whole
  first and replaces a review someone may be comparing against. `references/hosts/claude-code.md`
  owns the rule.
- It assumes Claude Code or Codex plus a git repo containing a Rails or a Phoenix app, a Rust crate
  or workspace, or a React or Next.js app. Everything else — which of them it is, the Rails root or
  the `lib/<app>` and `lib/<app>_web` split, a Cargo workspace's members and whether the changed ones
  serve requests, a JavaScript workspace's packages, its package manager and which Next.js router the
  changed files use, the test framework, API-only vs server-rendered vs LiveView, how authorization is
  attached, whether a separate frontend exists and where its client and types live — is discovered,
  never assumed. **Defaulting to a stack when none is detected is the same regression as assuming a
  layout**: the honest output is the stack-independent page with no anchor on it.
- The frontend is a first-class half of the contract, not a frontend review. The page follows fields
  and error cases across the boundary; it does not critique component design. In a LiveView app the
  boundary is the `phx-*` attribute and the callback answering it, and the page follows the event and
  the assign, not the markup. **On a React stack the components are the application**, so the lens
  reads them for behaviour — when an effect runs, which instance holds state, who renders a component
  and with what — and never critiques styling, naming or component taste; a departure from how the
  codebase builds components is a coding-decision question with a citation.

## Editing style

**This file is loaded in full at the start of every session in this repository, and nothing else
here is.** What belongs here is what **spans files**: the rule, the reason it holds today in a
clause, and the list of files that have to agree. What does not belong here is detail with a
canonical home one file away — the CSS beside the declaration, the check's rationale beside the
check, the vocabulary beside the grader.

**This file holds current rules only. Never write history into it.** No "it used to", "was
replaced", "came back", "the first version", "once", "no longer"; no incident or past run that
produced a rule; no measurement from a past run; no account of what a rule replaced. State the rule
as it is now, with the reason it holds now. When a rule changes, rewrite the sentence in place —
never append the change as a paragraph. History belongs in git and in commit messages; a rule's
supporting evidence, if it is worth keeping, belongs beside the thing it describes (the reference,
the script, the check), not here.

**A bullet growing past roughly 300 words is the signal that a fact moved to the wrong home.**
§ *One canonical home* is the page's rule and this file's rule too. When you add a sentence, check
first whether the reference, the script or the check already says it.

**The skill's prose is different**: rules there state *why*, and some include the observation that
produced them, because a rule stripped to an imperative loses what makes a model follow it under
pressure. Preserve that when editing the skill. Match the existing register: direct, specific, no
filler. Documentation-only changes belong in the same voice as `README.md`, the public face of the
project.

## Publishing

`.claude-plugin/plugin.json` is the plugin manifest. Its `version` is the update pin: users only
receive a change once that field moves. **A release is the maintainer's decision, not a side effect
of a change**: do not touch `version` in either manifest unless a bump is explicitly asked for. When
a change would ship only with one, say so in a line and leave the field alone. When a release is
asked for, bump both manifests, run `bin/examples regen` and read the pages, commit the bump and
the examples together, and tag it.

```bash
claude plugin validate . --strict
claude plugin tag --push          # creates accountable-review--v<version>
gh release create accountable-review--v<version> --verify-tag --title "accountable-review <version>"
```

**The tag is what `setup-ci` installs.** `render-workflow.sh` derives
`accountable-review--v<version>` from the installed `plugin.json`, and the generated workflow
`git clone --branch`es it, so a release tagged any other way ships a `setup-ci` whose every workflow
fails at install. Plain version tags on the remote are not used; do not add more.

The marketplace catalogue lives in a separate repository, `wyeworks/claude-plugins`, whose
`.claude-plugin/marketplace.json` is named `wyeworks` and points at this repo:

```json
{
  "name": "accountable-review",
  "source": { "source": "github", "repo": "wyeworks/accountable-review" },
  "description": "Turns a pull request into a published review map a reviewer can read before judging the change."
}
```

Keep `version` out of that entry — `plugin.json` wins when both are set. A catalogue entry may pin
`ref` or `sha` instead if a release needs holding back.

**Codex has a manifest and a catalogue of its own, both in this repository**, and the version is one
value in two files. `.codex-plugin/plugin.json` carries the same `name` and `version` as
`.claude-plugin/plugin.json`; `.agents/plugins/marketplace.json` names one plugin whose source is this
repository (`local`, `./`), so `codex plugin marketplace add wyeworks/accountable-review` is the whole
distribution and the release tag serves both hosts.

Codex reads `.codex-plugin/plugin.json` ahead of Claude's manifest and falls back to it otherwise;
Claude's has no `skills` field, so the fallback would load `./skills` and ship `setup-ci` into a host
whose CI half still runs Claude. The Codex manifest says `"skills": "./skills/review-map"`. Codex also
reads `.claude-plugin/marketplace.json` but skips the `github` source kind the `wyeworks/claude-plugins`
entry uses, which is why Codex's catalogue lives here. Installed either way the skill is
`accountable-review:review-map`, because both hosts namespace a plugin skill by the manifest's `name`.
Nothing in `claude plugin validate --strict` reads either Codex file, so `tests/codex-plugin.rb` checks
that they agree, in `bin/evals offline` and CI.

Two things do not belong at the plugin root: a `CLAUDE.md` (it ships to every install but is never
loaded as project context, which is why this file lives in `.claude/`), and any component directory
inside `.claude-plugin/` — only the manifest goes there. **`AGENTS.md` is at the root** because the
root is the only place Codex looks. It is a pointer at this file and holds only the facts this file
cannot state, being written for the host that has the `claude` CLI. Keep it a pointer: a second copy
of these rules would be § *One canonical home* broken.
