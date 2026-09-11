# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

There is no application code here. The repository is the `accountable-review` Claude Code plugin. It
ships two skills — `skills/review-map/` and `skills/setup-ci/` — plus the one subagent the first of
them spawns (`agents/claim-falsifier.md`, and only at `--effort high`), plus `ci/`, which is neither
a skill nor read by one. `review-map` turns a pull request into a published HTML **review agenda**:
what changed, the three to five judgments the reviewer has to make with the lines that settle each
one, the order to read the code in, and what the change reaches in code it did not touch. Two stacks
are supported: a Rails API with a Next.js client, which came first, and Elixir/Phoenix — a LiveView
app or a JSON API. Step 2 detects which, and the run reads that stack's lens file and its doc
catalogue, never both. `setup-ci` writes the GitHub Actions workflow that produces one automatically
on every review-ready pull request, and `ci/` is what that workflow runs.

**`review-map` is the product; `setup-ci` is plumbing for it.** The second exists so a team gets the
first without anyone remembering to ask, and nothing about it may change what the page is. The page
produced in CI and the page produced by a person are the same page from the same procedure — the
only difference is `--output`, which decides where the bytes land.

**The deep analysis is how the page is built, not what it prints.** A run traces consumers across
the whole diff, reads the tests, follows a value across the boundary and attacks its own conclusions;
what reaches the reader is the part they have to act on. Reducing the reading obligation is the goal.
Reducing the analysis is the failure, and it is the failure that will look like success — a shorter
page is easy to produce by looking less hard.

Installed, it is invoked as `/accountable-review:review-map`: plugin skills are always namespaced by
the plugin name, so the manifest name and the skill directory name together decide the public
command. It takes a target and an **effort** — `--effort high` (the default, sending an adversarial
pass at the run's own analysis before any of it is written) or `--effort low`, which opts out —
parsed in step 1 as prose, because `argument-hint` and `arguments` are not in the Agent Skills
frontmatter allowlist and `claude plugin validate --strict` rejects an unknown key. **There is no
level flag**: `--brief` and `--light` are accepted and change nothing, `--full` and `--review` stop
the run as not implemented in this version. The "source" is prose that another Claude instance
executes, so the unit of quality is instruction clarity, not compilation.

There is no build and no linter, and the **prose** has no test suite: changes to it are verified by
running the skill against a real PR and reading the page it produces.
`claude plugin validate . --strict` checks the manifest, not the prose, which is the part that
matters there.

**The scripts are the exception, in both skills, and the boundary is prose versus software rather
than one skill versus the other.** `setup-ci` produces a YAML file and four shell scripts; `review-map`
has `page-skeleton.sh`, `excerpt.sh`, `ledger-rows.sh` and `coverage-gate.sh`. All of it is ordinary
software with right answers, so it has ordinary tests: `skills/setup-ci/tests/` and
`skills/review-map/tests/`, each a `run.sh` (no model, no network, about a second) beside a
`self-test.sh` that breaks the things `run.sh` claims to check and asserts the suite notices each one.
They all run in CI on every push, for the reason `evals/checks/self-test.rb` does: a check that passes
because it never looked is worse than no check. When you edit either template, or any script under
`skills/review-map/scripts/`, `skills/setup-ci/scripts/` or `ci/`, run them — `bin/evals offline` runs
every suite together, which is what CI does too.

That boundary moved once already, and the older wording said `review-map` had no tests at all. It was
true when the only thing under `scripts/` was a quotation generator nobody had broken yet; it stopped
being true the moment a script started deciding what a published page contains.

## Working on the skill

Run a Rails or a Phoenix project against this checkout — no install, and `/reload-plugins` picks up
edits without restarting:

```bash
cd /path/to/app && claude --plugin-dir /path/to/accountable-review
```

Then: `/accountable-review:review-map <PR number | PR URL | branch | "">`.

Before pushing, `claude plugin validate . --strict` must pass — CI runs the same check, and so does
the community-marketplace review pipeline.

Because defect discovery is sampling rather than a deterministic function of the diff, a single run
is weak evidence. When judging whether a wording change improved things, run the same target more
than once, or the same wording against several PRs of different shapes (a 4-file bugfix, a migration,
a 100-file feature spanning both sides of the API) — small PRs and large ones exercise opposite
failure modes.

**Three things are worth checking on every run, and the first is the one this version is most likely
to be wrong about.**

**Is every checkpoint a judgment?** The failure mode is a heading: *ProjectSearcher implementation*,
*Tests*, *Controller changes*. Each names a place rather than a decision, and each reads as
organised. The test is whether a reviewer could answer it by looking at the code and could get the
answer wrong. A page of five headings is the old per-layer format with the section shells removed,
and it will arrive looking tidier than the thing it replaced.

**Did the merge happen?** Step 7c is what makes the agenda short honestly. A constructor change, the
nil default it introduces and the two consumers that do not handle nil are one judgment; a run that
writes three checkpoints has said the same thing three times and will have spent its budget doing it.
Read the agenda asking which two of these are the same question.

**Open two entries from *Impact outside the diff* and confirm the cited file really consumes the
changed thing.** That is unchanged from every previous version, and it is still where a page is most
expensively wrong.

And the standing one: confirm no sentence anywhere grades the PR. **The checkpoints are ordered, and
an order is one step away from a scale** — a number beside a question, a *high* that crept into a
title, a first checkpoint described as the important one. That is the easiest way to undo this
iteration, and it will arrive as helpfulness.

**The page has a word budget and nothing checks it.** `report-format.md` § *The agenda budget* is
prose: 700–1,500 visible words on a small or medium PR, 80–160 for *What changed*, 50–140 a
checkpoint. `brief-budget.rb` used to enforce its predecessor and is deleted with the level it
belonged to, so the numbers are read by a person or by nobody. That is the honest state — the numbers
are a first calibration derived from component caps rather than measured on published pages — but it
means a page drifting long drifts silently. The one number that must never be graded is the
**checkpoint count**: a page that came in under a ceiling by losing a judgment has done the one thing
the budget forbids.

`skills/review-map/evals/` is where judging happens, and it currently has **one scope rather than
three**. `fixtures/make-fixtures.sh` builds four repositories whose interesting findings sit
deliberately *outside* the diff, so there is a written right answer to check against. A **page** case
is a whole run, graded on what only a whole page carries. A **component** check runs on a script's
output. The **section** cases are deferred — they graded one section of the page this design
replaced, and the agenda's unit is a checkpoint, which is a different driver rather than a rename
(`evals/deferred/README.md`).

**That deferral is the largest hole in the harness and should not be permanent.** A section case was
what made "run it three times" affordable, and three runs is the smallest sample that separates a
wording change from noise; without one, every question about whether prose improved is a whole-page
run or a guess. `evals/README.md` § *Adding a case* says what a checkpoint case has to grade and why
it is different in kind: the mechanical half is thin, and almost everything worth knowing about a
checkpoint — is it a judgment, was the merge right, did the chain earn its place — is judged.

`bin/evals offline` is what CI runs and what you run before pushing. `bin/evals page <id>` prints the
recipe for one whole-page case. Results carry the skill's git sha, so a pass rate is attributable to
a version of the prose.

When the question is where the minutes went rather than whether the page was right,
`evals/profile.sh` reads the transcript of a run — an eval repetition or a real PR — and splits its
wall clock into tool execution, streaming, and the wait before each request produces its first token.
On the run it was built against, that last part was 58% of the total and tool execution was 6%. Split
that 58% before concluding anything from it: most of it is thinking, and only about **2.5s per request
is fixed** — 95 requests paid roughly 240s of that for nothing, while tripling the context cost 0.8s.
So the one lever **for wall clock** is fewer requests, and context reduction is not worth prose for
that purpose. Two `Write`s of the page accounted for 329 of the 457 seconds of streaming.

**For cost the ranking inverts, and the same script now prints both.** Context is billed once per
request, so a 141-request run carrying 265k pays that 265k 141 times: on three real runs, cache
reads were 37-39M against 160-190k of output, about **70% of the bill**, and *when* a file is loaded
therefore matters as much as whether. The sentence above is not retired — it is true of the clock
and false of the invoice, which are different questions about the same requests. `profile.sh` prints
a *where the money goes* table beside the time one, and the two rank differently: read them side by
side and never one instead of the other.

It also reads the **subagent** transcripts under `<session>/subagents/`, which nothing used to. The
falsification pass costs 0.9% of blocked wall clock and **17-23% of every cache-read token** — the
first number is why spawning them does not slow the run, the second is what they add to the bill,
and a profile that reported only the first is why the pass read as free. **Both numbers were measured
against the old seam**, where the falsifier read a published flow section; it now reads an analysis
note, which is smaller and carries no markup, so the token figure is an upper bound that has not been
re-measured.

It infers nothing the transcript does not carry:
publish stages are mechanical, the ten steps are **not** —
`ledger-rows.sh` fires at minute four and again at minute thirteen — and steps 4, 6 and 8 leave no
trace at all, so they get no row. Read `evals/README.md` § *Where the time goes* and § *Profiling one
run* before quoting one of its numbers.

Read `evals/README.md` before adding a case.

## How the documents divide the work

Each reference owns one axis; keep them from bleeding into each other.

| File | Owns |
|---|---|
| `SKILL.md` | The procedure — ten ordered steps from resolving the target to publishing, step 7 being the synthesis that turns analysis into an agenda — plus the product principle and the hard rules |
| `references/report-format.md` | Page structure — the five sections and what triggers each, **the review checkpoint**, **chains** and the rule that decides which figure a chain is, the evidence tiers, source excerpts, impact paths, the canonical-home rule, the agenda budget and the deep-link ladder |
| `references/rails-nextjs.md` | Domain knowledge, **Rails** — what a senior reviewer of that stack looks for, per layer, plus the runtime probes and the search recipes for affected-but-unchanged code. Its three client-side sections are stack-independent, and the Phoenix file points at them rather than restating them |
| `references/phoenix-liveview.md` | Domain knowledge, **Phoenix/LiveView** — the same three parts for the other stack. Its centre of gravity is § *LiveView*: the `phx-*`-to-`handle_event` seam, which is that stack's compiler-free boundary and its richest source of affected-but-unchanged code |
| `references/rails-docs.md` | The documentation catalogue, **Rails** — the Rails and gem URL *paths* the page may cite, the per-series overrides, and the two marks that say what a sentence may claim. Data, not lenses: an allowlist, dated and re-verified by `evals/verify-catalogue.sh` |
| `references/elixir-docs.md` | The documentation catalogue, **Elixir** — hexdocs paths pinned per package, the same two marks, and a § *Version* that **withholds every link** until a verification run opens its rows. Currently closed, so an Elixir run anchors with probes and prose |
| `references/page-template.html` | Design system — tokens (light and a dark half of our own), component classes, the assembled checkpoint, the chain and the impact panel, and the page's one small script. **No `<svg>` anywhere.** Four `SKELETON:` markers divide it: the head and tail ranges are **emitted** into the page by `page-skeleton.sh`, the middle is the markup a run reads |
| `agents/claim-falsifier.md` | The adversarial mandate — what to attack in one **analysis note**, that every challenge cites a line it opened, and that a claim it failed to break is reported too. At the **plugin root**, not under `skills/`: it is addressed by name, never read |
| `scripts/page-skeleton.sh` | Emits the head, the whole token block and the tint script straight into the page, and prints the markup half with `--markup`. Holds no bytes of its own — `tests/run.sh` proves that by partition |
| `scripts/diff-render.sh` | Says per path whether GitHub will render that file's diff, which is what decides the URL form for a line inside it. GitHub's documented thresholds as constants, `.gitattributes` through `git check-attr`, and one dated name heuristic |
| `scripts/excerpt.sh` | Generates the collapsed source excerpts, so the quotation is the real bytes |
| `scripts/ledger-rows.sh` | Generates the evidence foot's inventory cells and their deep links, so the gate checks the page rather than someone's typing. `--paths-only` is the only mode the page uses |
| `scripts/coverage-gate.sh` | The one mechanical check — set equality between the inventory and the diff |
| `skills/review-map/tests/` | The deterministic tests for those scripts, and the self-test that proves they fire. `diff-render.sh`'s rows build their own two-commit repository, because its answer is a function of git rather than of a fixture |
| `bin/evals` | One command per eval scenario — `offline`, `page`, `catalogue`, and the rest in its own header; `section` is deferred with the cases it dispatched. A dispatcher over `evals/` and `setup-ci/tests/` that owns the paths and the defaults `evals/README.md` argues for and **no rule of its own**; nothing it calls changed to make it work, so old result lines stay comparable. Its `parity` line is what stops its suite table drifting from `validate.yml` |
| `evals/` | Fixtures with planted findings, the frozen upstream, `checks/`, `deferred/` (the section cases and drivers, unrun), and `profile.sh`, which measures what a run *cost* rather than whether it was right. `checks/` is Ruby; `run.sh`, `report.sh`, `judge.sh`, `verdict-tally.sh` and `profile.sh` stay shell because they are process orchestration and JSON. Not loaded at runtime; see `evals/README.md` |
| `evals/checks/` | One Ruby script per rule family, dispatched by `check.rb`; `self-test.rb` asserts a verdict per row of `self-test-cases.txt`. Nine of them, down from fifteen: six graded markup the agenda does not have, and two of those six would have SKIPped forever, which is worse than none because a SKIP reads as verified. `impact-paths.rb` grades `figure.impact` and nothing else, so a checkpoint's `figure.chain` — same markup, different job — is invisible to it by scope rather than by an exemption. `link-form.rb` grades the href against the citation it sits on — the span, the sha256 fragment, and the routing away from a diff GitHub withholds — and is the check whose rule is a relation between the page and a repository, which is what `golden/links-repo.sh` and `lib/review_map/fixture.rb` are for. `lib/review_map/` is their shared library and `lib/test/` its tests. `checks/frozen/` holds every case's exact output for all nine, and `frozen.rb` verifies against it. `evals/README.md` § *checks/ is Ruby* has how it got that way, and the four defects the corpus alone could not have found |
| `skills/setup-ci/SKILL.md` | The setup procedure — inspect, decide where it goes, install, report — plus what setup must never touch |
| `skills/setup-ci/references/workflow.md` | Every part of the generated workflow and why it is that way: the triggers, the draft and fork guards, concurrency, permissions, checkout depth, the pin, the credential |
| `skills/setup-ci/references/config.md` | `.accountable-review.yml` — the whole schema, the precedence rule, and why an unknown key is an error |
| `skills/setup-ci/references/delivery.md` | The delivery contract, the providers that exist and the ones only designed for, and why `command` is opt-in in CI |
| `skills/setup-ci/templates/workflow.yml` | The workflow itself. Four substitutions, and nothing else is configurable by design |
| `skills/setup-ci/scripts/` | `inspect-repo.sh` reports, `render-workflow.sh` renders deterministically, `install-workflow.sh` writes idempotently and refuses to clobber, `read-config.sh` is the only thing that knows the config file's shape |
| `skills/setup-ci/tests/` | The deterministic tests, and the self-test that proves they fire |
| `ci/generate-review-map.sh` | The CI adapter: runs `review-map` non-interactively, then checks the three things a person would have noticed by looking at the page. It passes no level — there is one page — and refuses `mode: full` rather than remapping it |
| `ci/delivery/` | The delivery seam. `deliver.sh` dispatches; a provider is one file that reads `AR_*` and prints `key=value` |
| `README.md` | The public face — why comprehension debt is the problem, what a Review Map is, install, usage, CI setup, and the technical overview. Written for someone deciding whether to use this, so depth past that decision belongs in `docs/` |
| `docs/review-map.md` | The page anatomy for a reader who already wants it: the five sections, the checkpoint, staging, excerpts, the framework anchors, the evidence tiers, and what the skill assumes about a repository. It **restates** `report-format.md` for the public and owns nothing — where the two disagree, the reference wins and this file is the one that is wrong |
| `docs/ci.md` | The public half of `setup-ci/references/delivery.md` — artifacts as a default rather than a contract, the DeliveryResult, and how a team adds a provider. Same rule: it restates, the reference owns |
| `CONTRIBUTING.md` | How to work on the plugin from a checkout — the layout, the eval loop, the self-tests, and the release process. Why a rule exists stays in this file; `CONTRIBUTING.md` is only how to run things |
| `evals/verify-catalogue.sh` | The only script here that needs the network: opens every URL in a catalogue — `rails-docs.md` across every Rails series the floor admits, `elixir-docs.md` at each package's newest release — and reports dead pages, dead anchors, and the rows that differ by version. Maintenance for the first, the **release gate** for the second, never part of a run — see § *The catalogue is the one thing a run cannot verify* |

`SKILL.md` is the only file loaded up front; the references are read on demand at the step that needs
them. That is why `SKILL.md` says *when* to load each one, and why detail belongs in the reference
rather than inlined into the procedure.

The one exception is the product principle and the hard rules, which stay in `SKILL.md` even though
they read like a reference. A rule that can be skipped is not a rule, and the always-loaded file is
the only place skipping is impossible.

## Invariants that span files

Editing one of these means checking the others still agree.

- **One page shape, and no flag chooses it.** `--full` and `--review` stop the run as not implemented
  in this version; `--brief` and `--light` are accepted and change nothing. The refusal is settled in
  `SKILL.md` step 1 beside the target and the link rung, its wording is in § *Two levels are not
  implemented in this version*, and `report-format.md` § *One page shape* states the consequence for
  the format.

  **Refusing `--full` rather than mapping it is the load-bearing half.** It named a seven-section
  page. Handing back a five-section agenda under that name is a flag that quietly changed meaning,
  and the reader has nothing on the page to tell them which they got. The same argument runs through
  the CI config: `ci/generate-review-map.sh` and `read-config.sh` reject `mode: full` and accept
  `brief` and `light` as aliases that reach nothing.

  **What the narrowing replaced is worth knowing, because the pressure to reintroduce it will come
  back as generosity.** There were two shapes, `--brief` merging four sections into one and carrying a
  word budget to keep it short, and `--full` writing all seven. Two products, only one of which anyone
  developed against, and a reader choosing between them was choosing a length rather than a document.
  What a reviewer wants is not a length setting: it is an answer to *what do I have to judge here, and
  where do I look?* A future full mode is the same agenda with depth beneath it — `report-format.md`
  § *A future full mode* records the four components this page put down and the rules they had —
  never a second document reached by a flag.

  **The agenda budget survived the level that carried it, and lost its check.** `report-format.md`
  § *The agenda budget* is prose: 700–1,500 visible words on a small or medium PR, per-part caps, a
  floor stated as a rule rather than a number. `brief-budget.rb` enforced its predecessor and is
  deleted, so nothing counts words now. Two of its lessons are kept in that section deliberately.
  Length is guidance rather than a failure, because a hard failure on length teaches a run to drop a
  claim to get under a number, which is worse than the long page. And **the checkpoint count is never
  budgeted**: a page that came in under the ceiling by losing a judgment has done the one thing the
  budget forbids.

  **The rail is emitted, not edited down.** `page-skeleton.sh --markup` hands a run the whole markup
  half, seven `data-rail` entries: four numbered sections and three checkpoint sub-entries. That used
  to be filtered per level by `SKELETON:ONLY:level=` markers and a validator that failed closed, all
  of which is deleted with the level. What replaced the filter is nothing, which is the right amount
  of machinery for a page with one shape: `tests/run.sh` counts the entries and `self-test.sh`
  duplicates one to prove the count fires.
- **The review checkpoint is the page's primitive.** Three to five of them under *What needs your
  attention*, each **one judgment** the reviewer has to make: an `<h3>` question, two to four
  sentences, an optional `figure.chain`, a `ul.lookat` of one to four deep-linked citations each with
  a clause, and an optional `p.open` labelled *Open question*. `report-format.md` § *The review
  checkpoint* owns all of it and owns it **alone**; `page-template.html` assembles one with every
  optional part, one without, and a pending stub.

  **It replaced a seven-field review unit, and the reason is the thing to preserve.** Every meaningful
  change got the same grid — implementation, tests, affected code, things to understand, validation,
  questions — whether or not each row had anything to say, and a reviewer read seven labelled rows per
  flow to find the one that mattered. The fields were right as *analysis* and wrong as a reading
  obligation. They are facets now: a test appears inside a checkpoint when it changes the judgment,
  and a list of the specs that touch the file does not appear at all.

  **The failure mode is a checkpoint that is a category**, and it will look organised. *ProjectSearcher
  implementation*, *Tests*, *Controller changes* each name a place rather than a decision. The test is
  whether a reviewer could answer it by looking at the code and could get the answer wrong. Five
  headings is the per-layer format this repository has now removed twice, arriving with the section
  shells taken off.

  **The second failure mode is a checkpoint that should have been merged.** `SKILL.md` step 7c is what
  makes the agenda short honestly: a constructor change, the nil default it introduces and the two
  consumers that do not handle nil are one judgment. A run that writes three has said the same thing
  three times, and will have spent its budget doing it.

  **Ordering is not grading, and the distance between them is one word.** The checkpoints are ranked by
  what a reviewer would most regret misunderstanding. A number beside a question, a *high* in a title,
  a first checkpoint described as the important one — each of those is a severity scale, and each will
  arrive as helpfulness. The one line that names an unresolved thing is `p.open`, labelled *Open
  question* and nothing else; `page-invariants.rb` warns on a bare `Watch` or `Blocking` label for
  exactly this reason, and that rule outlived the component it was written for.

  Nothing mechanical grades a checkpoint. `start-here.rb` requires the reading path to point at one,
  `rails-anchors.rb` counts them as the denominator for its doc-link budget, and `tests/run.sh` asserts
  the template assembles three. Whether a question is a judgment is a judged expectation, and
  `evals.json` is where it is asked.
- **Chains are the one figure vocabulary, in two places with two jobs, and the rule between them is
  mechanical.** `figure.impact` in section 04 and `figure.chain` inside a checkpoint are the same
  `ol.ip-path` with the same node kinds and the same causal verbs. `report-format.md` § *Chains* owns
  what they share; § *Impact paths* owns the panel's own caps and owns them alone.

  **The rule: a chain that crosses from changed code into unchanged code whose meaning the change
  altered is an impact path.** It lives in section 04, drawn once, and a checkpoint that turns on it
  says so in a clause. A chain inside a checkpoint shows mechanism *within* the change and therefore
  carries **no `.ip-aff`** — which makes the rule checkable rather than a matter of taste, and
  `tests/run.sh` checks it on the template with an awk range over the assembled chain. `.ip-step` is
  the kind that exists only in a checkpoint's chain: a hop that claims nothing about the diff.

  Without that rule the same consequence gets drawn twice at conversational distance, which reads as
  thoroughness — the canonical-home regression arriving as a figure rather than as a paragraph.
- **There is no `<svg>` on the page, at all.** Four SVG layouts used to be worked out to scale in the
  template — a boundary chain, a guard fork, an ER fragment, a lifecycle — so a run filled in text
  rather than deriving geometry. They are deleted, with the SVG class vocabulary, `.scroller`,
  `figure.inflow` and `.pipe`.

  **The reason is a measurement, not a preference.** An `<svg>` is the most expensive thing on a page
  to type, so the characteristic failure was never a wrong drawing but **no drawing**: two real pages
  published nine flows and zero figures with the layouts sitting readable in the template the whole
  time, and `behaviour-flows.rb` warned on both while nothing read the warning. A component has the
  opposite failure profile. It reflows on a phone, has no canvas to overflow, and cannot be drawn
  wrong — the only thing a run can get wrong is whether the edges are true, which is the thing worth
  its attention.

  What went with the catalogue: `diagram.rb`, whose whole subject was SVG conformance, and
  `diagram-shot.rb`, which rendered figures to PNG for a person to look at. Both would now SKIP
  forever. **That is a real loss** — crowding, overlap and an arrowhead landing beside its box needed
  eyes, and both defects that argument was built on were found in diagrams `diagram.rb` had just
  called clean. The trade is that a component cannot produce those defects, so the eyes are no longer
  owed. Reintroducing an SVG reintroduces the need, and `SKILL.md`'s hard rules say not to.
- **One stack reference per run, and the stack is invisible on the page.** `SKILL.md` step 2 detects
  Rails (`Gemfile`, `config/application.rb`) or Elixir (`mix.exs`) and **names** one lens file and
  one catalogue. Both roots, or neither, are handled explicitly — ask in the first case, degrade
  to the stack-independent page and emit no anchor in the second. Defaulting to Rails is the
  regression: a Rails lens over a Go service invents findings, confidently.

  **Naming them is not reading them, and the difference is worth about 43 KB of resident context.**
  The lens is read at step 5, where its search recipes are the work; the catalogue at step 7, when a
  claim first asks for a URL. Step 2 used to read both, against its own bundle table, which carried
  them through steps 3 to 6 — the consumer tracing, where the context is already largest and every
  token is re-billed per request. For Elixir it is starker still: that catalogue is closed at file
  scope, so the whole file bought one fact. It is still read at step 7 rather than hoisted, because
  the fact's home is `elixir-docs.md` § *Version* and six files already have to agree about it.

  Like effort, the stack **produces no section, no field, no tier, no component and no marker.**
  What it changes is the content of sentences, the nodes in a chain, and the command inside a
  `pre.probe`. `report-format.md` § *One page shape* states this beside the effort paragraph, and
  `page-template.html`'s header comment refuses a stack badge in the same breath as the severity chip
  and the verification badge — the three come back the same way and are refused in the same place.

  Two things are deliberately **not** duplicated, and both would look like thoroughness.
  `rails-nextjs.md`'s three client-side sections (§ *The boundary: serializers to types*, § *Next.js*,
  § *TypeScript and the client*) are about the client and the wire, not about Rails, so
  `phoenix-liveview.md` points at them in a clause; restating them would be a second canonical home
  for the same material. And the file keeps its Rails-shaped name: renaming it costs six references
  for no behavioural gain, so the pointer says why instead.

  **The LiveView boundary is the payoff, not a footnote.** A LiveView app has no serializer and no
  generated type, so the naive reading is that it has no contract. It has a sharper one: a `phx-*`
  attribute value and the `handle_event/3` clause that answers it, with nothing at compile time
  linking them and a crashed process rather than a wrong render when they disagree. Renaming an event
  in a `.heex` template without renaming its clause is this stack's canonical piece of
  affected-but-unchanged code, which is why step 5's table has a row for it, why the search recipes
  say to search **both directions**, and why and it earns a checkpoint's chain the way the
  serializer-to-type seam does in Rails.
- **The page never grades the change.** No severity scale, no risk score, no confidence percentage,
  no approval language. Stated as the product principle at the top of `SKILL.md`, repeated in its hard
  rules, and enforced structurally: the template has no chip that expresses a verdict, and
  `page-template.html` says so in its header comment. Reintroducing a severity vocabulary is the
  single easiest way to undo this iteration.

  **A page is allowed to *refuse* a grade out loud, and the check has to know the difference.**
  `page-invariants.rb` § 2 splits its patterns in two for this. Approval language is never right in
  any form; a graded *noun* — risk score, overall risk, severity score — fails only where nothing
  negates it, because a page legitimately writes *"attention is a reading estimate, not a risk
  score"*. That sentence is the invariant defending itself in the one place a reader is most likely
  to read a column as severity, and the check used to fail it for containing the words. A rule that
  punishes a page for refusing a verdict teaches the run to stop refusing it out loud.

  The negation test is per occurrence, inside a 48-character window bounded by sentence punctuation,
  and the negation must be a **whole word bounded on both sides** — POSIX `awk` has no `\b`, and each
  missing boundary silently excuses a real grade: without the leading one, `no` matches inside
  *another* and *cannot*; without the trailing one, `not` matches inside *notice*. Both were found by
  running the rule against sentences, not by reading it, and `golden/invariants-risk-score-leading`
  and `-trailing` pin one boundary each — deliberately one per fixture, because a fixture planting
  two bypasses keeps failing while either regresses and therefore pins neither.

  That pair also forced § 2's graded-noun test and § 2c onto the **comment-stripped** copy. The first
  version of the leading fixture described its own defect in its header comment, so the phrase
  appeared twice and deleting the rule left the fixture still failing — a mutation test reporting a
  bypass as caught. Real pages carry `page-template.html`'s comments verbatim, so this was a live bug
  and not only a fixture artefact.
- **Evidence tiers.** Five of them, listed in `report-format.md` § *Evidence tiers*, rendered as
  `span.tier`. A claim the diff shows directly carries **no** label — silence is the first tier. That
  asymmetry is deliberate: labelling everything is noise, and noise gets skipped.
- **Framework anchors are provenance, not evidence, and there is still no sixth tier.** A doc link
  explains why a Rails consequence follows; a console probe asks the reviewer's own application. The
  claim underneath keeps resting on a repo `file:line` at the tier it already carried, which is what
  keeps the five-tier invariant untouched. It is also the answer already written down for `--review`:
  where a claim came from is provenance, and provenance is not evidence.

  Two rules carry the link and the probe, and both are the kind that look like diligence when broken.
  **A doc link may only be a row of `references/rails-docs.md`, pinned to the version this app runs**,
  because the run cannot open a URL — no fetch step, and egress to those hosts is commonly blocked —
  so a constructed API path is a 404 the reader finds on the page's behalf, and an unpinned one is
  documentation for a Rails this app may not be running. Both fail while looking correct. See
  § *Pinning, and the two things it does not fix* for why the pin is about checkability rather than
  precision, and for the two marks that stop the page asserting a behaviour that moved. **A probe is
  proposed, never run**, so the page shows a command and never output: a fabricated `=> …` is the
  most concrete-looking thing on the page and the one part of it that is fiction.

  `report-format.md` § *Framework anchors* owns all of it — the routing (verify → the checkpoint the
  probe settles, explain → a clause in its explanation) and the budget, **and owns them alone**;
  `SKILL.md` steps 7g and 9 point at it, the § *Runtime probes* of whichever lens file the stack
  selected holds the probes and the rule for running them safely — `runner`-versus-`console --sandbox`
  in Rails, and in Elixir `mix run -e` plus the fact that there is **no sandbox console at all**, so a
  write wraps itself in `Repo.transaction(fn -> …; Repo.rollback(:probe) end)` — and
  `evals/checks/rails-anchors.rb` derives its allowlist from **both** catalogue files rather than
  hard-coding hosts. Its name is Rails-shaped and its scope is not, deliberately: renaming it would
  churn several files for no behavioural gain.

  **There was a third anchor and it is gone: the primer callout**, an `aside.primer` inside a flow,
  one per flow at most, `--full` only, gated on the doc link it escalated from, carrying a `file:line`
  and a `pre.demo` that could show a `# =>` line only because its receiver was a class the app under
  review did not have. It went with the level that gated it, and `report-format.md` § *A future full
  mode* records its rules. Three things it taught are worth keeping without it.

  **`pre.demo` and `pre.probe` were different components because the receiver differed**, and merging
  them would have opened a hole through the one rule protecting the most concrete-looking fiction the
  page can carry. There is no `pre.demo` now, which means the page's rule is simply *no output, ever*
  — simpler, and the simplicity is the point.

  **A doc-link budget needs a denominator**, and `rails-anchors.rb` used `<dt>` count when the fields
  were the unit. It counts checkpoints now: at most one link each, and a page carrying more links than
  judgments has stopped selecting.

  **And the failure mode the primer concentrated is still the failure mode.** It is not a wrong link.
  It is a page that links everything, becomes a Rails tutorial with a diff attached, and reads as more
  thorough while getting less navigable — the canonical-home regression arriving as citation instead
  of as repetition. The rule against it is the excerpt budget's: an anchor is earned by a decision the
  reviewer has to make. A script can check that a link is real and legally placed, never that the
  judgment needed it.
- **The synthesis phase is where the agenda comes from, and it is a step of its own for a reason.**
  `SKILL.md` step 7 takes the analysis notes and produces the page's argument: name the semantic
  delta, identify the human judgments, merge the observations that share one, rank by consequence if
  misunderstood, select three to five, choose each one's representation, select its evidence, build
  the reading path, pick the impact chains, dedupe across the five places a fact can land.

  **A run that goes from notes straight to prose writes one section per flow**, which is the page this
  one replaced wearing new section names. That is the failure the step exists to prevent, and it is
  why "make the report shorter" is not an instruction that could have produced this design: the
  shortening has to happen in what gets *decided*, not in how the decisions get written up.

  The step opens no file the notes have not already cited. It is the one place in the procedure whose
  work is entirely judgment, and the one place where the falsifiers' challenges arrive while it runs.
- **Affected-but-unchanged code is the product.** Step 5 of `SKILL.md` finds it, the search recipes in
  `rails-nextjs.md` are how, and it surfaces at three depths on the page. The **checkpoint** that
  turns on it explains it, with the line in its *Look at* list. **Section 04** shows the crossings
  whole — one to three chains, with the entries the chains run through cited beneath the figure and
  pointing back at the checkpoint in a clause. The **evidence foot** holds what is real, found and
  cited but not something the reviewer has to decide about.

  **That third bucket is where this invariant is most likely to fail quietly.** Moving an entry down
  is the easiest way to make the page shorter and the hardest to notice, and the rule against it is
  one sentence: nothing a reviewer acts on lives only in the foot. If a foot entry is a judgment they
  have to make, it is a checkpoint that was mis-filed.

  The rule that makes the whole thing honest is unchanged: **record what was searched**, so an empty
  result reads as evidence rather than as omission.

  **The record is collapsed, and splitting it is what keeps that rule from eating the page.**
  `details.searched` is shut by default, inside the foot, and holds `ul.sr-list`, one row per search,
  each a command and a result *clause*. The finding stays in the open prose: "nothing else reads this
  column" is a sentence a reviewer meets without clicking, and the grep behind it is provenance. Get
  that split wrong in the other direction and the rule inverts — a finding left to be inferred from an
  empty row inside a shut toggle is hidden, not disclosed, which is the closed-block hard rule.

  It was collapsed because open it was the longest thing in the section that held it and the first
  thing a reviewer met, and because real pages filled it with paragraph-long re-explanations of
  entries sitting two inches above — § *One canonical home*'s restatement regression arriving
  disguised as provenance. Hence the row format: a `<code>` and a clause makes a verbose one *look*
  wrong, which prose never did.

  Four files agree: `page-template.html` holds the component and its CSS, `report-format.md` § *What
  was searched* owns the form, the budget and the open/collapsed split **alone**, `SKILL.md` step 5
  points at it, and `evals/checks/searches.rb` re-runs the recorded searches against the repository.

  **That check needed one edit and it is worth knowing why.** It scopes its affected-entry region on
  the verbatim `Affected, not changed` eyebrow and resets on a small set of closing tags. The label
  now appears twice — beside the impact panel and again in the foot — with `details.searched` between
  them, so without `</ul>` and `</section>` among the resets the region opened in section 04 ran
  straight into the foot and read **every recorded search as a claim that needed a recorded search**.
  The check keys on text nodes beginning with a search tool rather than on a class, which is why
  nothing else about it moved.
- **Completeness, and the one mechanical check.** Every path in the diff appears in the page, and the
  gate runs on the finished page. The carrier is `div.gt.gt-paths` inside `details.evidence` at the
  foot, generated by `ledger-rows.sh --paths-only` as `.gt-paths` cells carrying `data-path`. That is
  the whole reason the carrier is a grid cell rather than a list item — `coverage-gate.sh` greps
  `data-path` page-wide and `page-invariants.rb` § 4 requires it on a `div class="c"`, so a
  `.filelist` would have cost the gate.

  **The classification went and the accounting stayed.** The page used to carry a ledger with three
  judgements per row: which section covers the file, how much attention it needs, and which group it
  belongs to. Where a reviewer's attention goes is now said by what is on the reading path and in what
  order, and saying it again in a column beside every file was a second ranking competing with the
  first. `ledger-rows.sh` still emits the four-cell form without `--paths-only`; nothing calls it, and
  `report-format.md` § *A future full mode* is where it is written down.

  **The carrier is not section 04, and the gate never noticed it move.** § 04 used to hold the whole
  diff too, which made it the second inventory its own closing rule forbids. On a 24-file PR that
  rendered as 24 links above a caption explaining that the eight worth opening were ranked elsewhere.
  `coverage-gate.sh` is a raw-byte page-wide grep, so it cannot tell whether a carrier is visible,
  collapsed, or in a section at all — which is why that change cost no script. Collapsing it is legal
  because an inventory is *provenance*, which passes the reads-complete-when-shut rule where a finding
  never would. Collapsed is not optional and neither is the gate: a run that skipped it because the
  list is out of sight has turned a shorter page into one that may have dropped a file.

  Stated in `SKILL.md` step 3, explained in `report-format.md` § *The completeness invariant*, and
  enforced in step 10 by `scripts/coverage-gate.sh`. Four files have to agree for that check to work:
  the script reads a `data-path` attribute, the template emits it on the inventory's grid cell
  (`<div class="c" data-path="…">`, not a `<td>` — the inventory is a CSS grid), `report-format.md`
  § *Section 5* requires it, and `SKILL.md` step 10 runs the script. Break any one and the gate stops
  checking. Note the asymmetry in the invariant itself: the page-wide rule is a subset test (the page
  cites unchanged files everywhere by design), while the gate is exact set equality against
  `git diff --name-only`, compared as whole strings — never substring matching, because `api/Gemfile`
  matches inside `api/Gemfile.lock`.
- **A staged page must never look finished.** The page publishes early and fills in at one URL
  (`SKILL.md` step 9). Staging is only safe because an unfinished page says so: a build banner while
  it is being written, an explicit *pending* marker for every part that is coming, and both removed at
  the final publish. Four states have to stay distinguishable — written, pending, *not written*
  because the run stopped, and omitted because the diff did not earn it — since the whole risk is a
  reader taking any of the last three for "nothing to say here". A stopped run is the one that needs a
  deliberate edit: pending is a promise, and leaving one behind is worse than publishing late. The
  form lives in `report-format.md` § *Build state*, the components are `.buildstate` and `.pending`,
  and `evals/check.rb --draft` / `--final` check both ends of it.

  **Omitted and pending is where the agenda makes that harder, and section 04 is the case.** A diff
  whose consequences all stay inside it earns no impact section: the section and its rail entry go,
  and what must not appear is a stub saying nothing reaches unchanged code. That sentence is a clean
  bill of health with a marker on it.

  The pending marker earns a second keep, found by profiling rather than by reading: it is the
  **anchor a later stage edits**, which is what keeps staging from costing the whole document per
  stage. A run that instead re-`Write`s the file pays for every already-written section again — one
  did, producing its finished 82 KB page as a single 35,000-token write that re-emitted the staged
  23 KB byte for byte, 56% of everything that run spent streaming. Staging is only cheap if a stage
  writes what is new, so `SKILL.md` step 9 says fill in with `Edit`, never rewrite.

  **The checkpoint — not section 02 — is the unit of staging.** Section 02 is the bulk, so a stage
  that delivered it whole would put the longest wait of the run behind one arrival, which is the thing
  staging exists to prevent. It costs no markup: `<section id="attention">` is the heading and the
  caveat, each checkpoint is already its own nested `<section class="cp" id="cp-x">`, and the rail
  renders a per-checkpoint marker.

  **And the checkpoint stub is worth more than the flow stub it replaced**, which is the part to keep.
  A flow stub said what the flow would cover. A checkpoint stub carries **the question** — so stage 3
  opens by publishing what the change is asking the reviewer to judge, ten minutes before any
  explanation exists. That is most of what a reader came for, arriving first.

  Consequence for the banner: it counts **parts still pending** rather than *stage N of M*, because the
  total depends on how many checkpoints the diff earns and a run would have to commit to it before
  knowing one. Nothing greps the count; `checks/build-state.rb` greps "absence is not a finding", which
  is why that sentence is the one that must survive editing.
- **Effort decides whether the page is right, and it is invisible on the page.** `--effort high` (the
  default) and `--effort low` decide how hard a run works to be right. Nothing else varies: there is
  one page shape, and two pages of the same target at the two efforts differ in their claims and never
  in their form.

  **The default moved to `high` in 0.16.0, on two measurements against fayron#529.** The pass costs
  0.9% of wall clock because the falsifiers do not block (§ *Deliberately single-context*), and the
  same PR at `normal` missed five findings the falsified run carried — including an admin who never
  reaches the gate written to admit them, and sixteen consumers of a column the change made nullable,
  two of which send email.

  **That 0.9% is wall clock, and the pass is not cheap in tokens.** Profiling the subagent
  transcripts put it at **17-23% of every cache-read token** across three real runs — the second
  most expensive thing in the procedure. Both numbers are load-bearing and neither replaces the
  other: the first is why `high` can be the default at all, the second is why
  `agents/claim-falsifier.md` carries its own `model:` rather than inheriting the parent's. Quoting
  the 0.9% as though it settled the cost question is the mistake this paragraph exists to prevent,
  and it is the one the first version of it made.

  **Both numbers were measured against the old seam and have not been re-measured.** The falsifier
  used to be handed a published `<section id="flow-x">` — markup, excerpts, a rail — and is now handed
  an analysis note, which is smaller and is prose. The token figure is an upper bound; the wall-clock
  figure should be unchanged, since what made it 0.9% is that the parent keeps working, and it still
  does. Re-measuring is worth a `profile.sh` run on the first real PR through this version.

  **The seam moved ahead of the page, and that is the change worth stating.** Step 6 writes one
  analysis note per flow to `$W/analysis/`, sends one falsifier at each, and step 7 synthesises while
  they read; step 8 folds the challenges in before a checkpoint's stub is replaced. Under the old
  order a flow was published at stage 3 and corrected afterwards, so **it was wrong while it was
  public** — an accepted cost that no longer has to be paid. What remains is the late challenge
  arriving after a checkpoint has landed, and the rule for that is the one it always was: a claim
  retracted before the final publish beats one that is never retracted.

  **A run that waits on them has lost the whole argument.** The 0.9% holds only because the parent
  works while they read. Spawn-then-idle turns the cheapest step in the procedure into the most
  expensive, and it is the likeliest way this default gets reverted by someone measuring it.

  Effort produces **no section, no marker, no chip and no sentence**. A reader cannot tell which
  effort produced the page in front of them, deliberately.

  Six files have to agree: `SKILL.md` step 1 parses it, step 6c owns what `high` does and step 8 owns
  what happens to the result, `report-format.md` § *One page shape* states that this file has nothing
  else to say about it, `page-template.html`'s header comment refuses the badge in the same breath as
  the severity chip, `agents/claim-falsifier.md` carries the mandate, `evals/checks/page-invariants.rb`
  §§ 2b and 2c fail a page that advertises having been checked or narrates its own drafting, and
  `README.md` § *How hard it works* is the public wording.

  **The falsifier's `model:` is a fourth thing that has to agree, and it agrees across the harness
  rather than across the page.** `agents/claim-falsifier.md` names it; `evals/run.sh` reads it out of
  that file into the `--agents` JSON, so an eval arm cannot silently measure a different model from
  the one that ships; the value lands on the result line as `falsifier_model` and in `report.sh`'s
  group key, so an opus-falsifier row can never be averaged into a sonnet one; and `profile.sh`
  prints the model the subagent transcripts actually recorded. That last one is the only real check:
  `--agents` accepts keys it does not understand without complaining, so sending the field is not
  proof it was honoured, and the transcript is.

  **A verification badge is the same regression as a severity chip, and it will look more innocent.**
  Grading the PR is obviously forbidden; grading *the page* — "every claim verified", a count of what
  the pass corrected, a `.verified` chip — reads as transparency while asserting exactly the assurance
  the format exists to withhold. That is why the refusal lives beside the severity refusal in the
  template rather than in a section of its own, and why § 2b's patterns are high-precision: a bare
  `verified` is a real Rails column name, and the sanctioned "a pass, not an audit" contains *audit*.

  **The badge is not how the leak actually arrives. This is:** *"the mistake the first version of this
  section made"*. A correction annotated with the history that produced it — which is the falsification
  pass, narrated, without ever naming it. It slipped every rule above because it reads as candour
  rather than as advertising, and a real `--effort high` page against a 28-file PR carried **ten** of
  them while the three pages beside it carried none. Every one had a true and useful fact inside it:
  the `git grep` basic-regex caveat is exactly what a reader re-running a recorded search needs. So the
  rule is *keep the fact, drop the autobiography* — `SKILL.md` step 8's **correction replaces, never
  annotates**, which is a general-effort bullet rather than a `high`-only one, because a normal run
  revising its own draft writes the same sentence.

  Two things to know before editing § 2c. It **strips comments first** — `page-template.html`'s own
  header comments are written in precisely this register ("What this replaced is the reason every one
  of those rules exists") and ship verbatim inside every published page, so a check reading them would
  fail every page for its template's documentation; `golden/invariants-draft-narration.html` puts the
  trigger phrases in its own header comment so that stays true. And the register is right *here* and
  wrong on the page: this file's rules deliberately carry the observation that produced them, which is
  the habit the page must not inherit. The audience is the difference — a maintainer needs to know why
  a rule exists, a reviewer does not need this document's drafting history.

  The eval axis is `--skill-effort`, not `--effort`: `evals/run.sh` already had an `--effort` meaning
  the CLI reasoning effort the reader runs at, and two knobs under one name in one script is a bug
  waiting for a hurried reader. Both are in `report.sh`'s group key.
- **Findings are a sample, not an audit.** The page must never read as a clean bill of health. This is
  load-bearing, not hedging: the skill explains, and explanation is reproducible, but defect discovery
  is not.
- **Deep-link mode is chosen once**, in step 1, from the four-rung ladder in `report-format.md` —
  driven by whether the head SHA is reachable on a remote. Unpushed branches are the common case, and
  the correct behaviour there is plain text, not a permalink that 404s.

  **A git that cannot answer is not the same as unpushed**, and `page-invariants.rb` § 5 used to
  treat it as such: written with `|| true`, an unreadable `--repo` or an unresolvable head gave empty
  output, which read as "on no remote" — a false PASS on a page with no permalinks and a false FAIL
  on one that has them, both from an answer git never gave. Three states, not two, and the middle one
  refuses.

  The rung decides whether anything is clickable. It does **not** decide the form, and the form is not
  a taste: a line inside the diff links to the diff page — `pull/{n}/files` at rung 1,
  `compare/{base}...{head}` at rung 2 — because that is the page the reviewer is working in and a blob
  at head shows the new line with no trace of what it replaced. A line outside the diff links to a
  blob at the commit that line exists at: head for unchanged code, the diff's left side for code the
  change removed or for behaviour cited as it was. Neither form is the fallback; *affected but
  unchanged* is the page's product and no diff view can address it. Three files have to agree —
  `report-format.md` § *Deep links* owns both forms and the ladder, `SKILL.md` steps 1, 9 and 10 point
  at them and record both SHAs, and `ledger-rows.sh` takes `--pr`, `--compare` or `--blob` so a run
  never types an href into the `<td>` the coverage gate reads.

  **There is one exception to *inside the diff means a diff anchor*, and it is a verdict rather than
  a judgement.** GitHub does not render every diff — a file marked `linguist-generated`, a lockfile,
  a binary, or a diff past **400 lines or 20 KB** sits behind *Load diff* — and an anchor into one of
  those lands on the stub with the cited line nowhere in the page. So those citations take the blob
  form. The numbers are GitHub's own
  ([repository limits](https://docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits):
  400 lines / 20 KB to auto-load, 20,000 lines / 500 KB to be shown at all, 1 MB and 300 files for
  the whole diff), which is why they are constants in `scripts/diff-render.sh` rather than flags —
  and why the one heuristic in that script, its lockfile-name list, carries a date and the same
  warning the doc catalogue does: it mirrors Linguist's built-in detection, which lives in GitHub's
  repository and not in this one. `.gitattributes` is asked through `git check-attr`, so the repo's
  own marks need no list at all.

  Two things make that cheap. **The size rule is not the whole rule** — one changed line in a
  generated `db/structure.sql` is small by every measurement and GitHub withholds it anyway, which
  is the case a threshold alone waves through and the one a Rails page actually cites. And **being
  wrong is asymmetric**: a blob link where the diff would have rendered still lands on the line and
  only loses the red and the green, so the verdict leans towards the anchor and the excerpt beside
  such a claim becomes the `--diff` variant, which is § *Deep links*' rung-3 rule arriving per file
  instead of per run.

  **A citation that names a range links a range**, in either form — `R51-R72`, `#L51-L72`, both ends
  on the same side. A real run published `…_test.exs:51-72` under an href ending at `R51`: the text
  promises twenty-two lines, the link selects one, and nothing on the page says which to believe.
  The diff-anchor range form was missing from `report-format.md` entirely, so the run had nowhere to
  put the `72` — the defect was in the spec, not in the writing.

  **Fixing the spec did not fix the pages, and `page-template.html` is why.** Two real runs published
  73 ranged citations between them under one-line anchors *after* the range form landed in
  § *Deep links*, because every citation in the template rendered as `href="{{LINK}}"` — one opaque
  placeholder over the one link on the page whose **form is load-bearing** (diff versus blob, `R`
  versus `L`, line versus range). The rule was stated in a comment beside the fourth citation of
  fourteen, by which point a run had already copied three. So the template now spells the anchor out
  at every line-bearing citation — `{{DIFF}}R{{START}}-R{{END}}`, `{{BLOB}}#L{{START}}-L{{END}}`,
  with the *same two placeholders* in the text — and defines `{{DIFF}}` and `{{BLOB}}` once at the
  top of the markup half, before any citation appears. `{{LINK}}` survives only where a citation
  names no line and so has no anchor to get wrong.

  This is the doc-link precedent applied to the other link, and it was missed for the same reason
  the doc link's was: § *Pinning* already argues that a template carrying the unpinned form teaches
  a run to publish a page that fails its own check. A template carrying an *unformed* href does the
  same thing, and costs 4.4 KB of the markup half to fix.

  Five files have to agree on those two: `report-format.md` § *When the diff will not render* owns
  the rule **alone** and § *Deep links* carries the three URL forms, `SKILL.md` step 3 runs the
  classifier once and step 9 points at both, `scripts/diff-render.sh` holds the verdict,
  `tests/run.sh` covers every signal it reads, and `evals/checks/link-form.rb` re-asks that same
  script rather than keeping a second copy of the thresholds. That last one is why
  `golden/links-repo.sh` exists: it is the only golden fixture that has to be a real git repository,
  built under `TMPDIR` with fixed commit fields so its base SHA is stable for `frozen.rb`, and
  `lib/review_map/fixture.rb` is what expands `@REPO@` in the cases file for the two graders that
  read it. A rule that could only ever SKIP in `self-test-cases.txt` is what that file exists to
  prevent.

  `diff-render.sh` also carries the guard this repository has now paid for twice: **asked and unable
  to answer is not an empty diff.** Every `git diff` in it feeds a pipeline, so an unresolvable ref
  leaves the exit status at 0 and prints no rows — which reads as *no file is withheld*, the most
  reassuring thing it can say and the one with the least behind it. The refs are resolved up front
  and an unresolvable one exits 4. `excerpts.rb`'s state-tag rule shipped with exactly that bug, and
  `page-invariants.rb` § 5 with its sibling.
- **Five sections, and each fact has one home.** The format is deliberately *not* one section per
  architectural layer. It was, and that guaranteed restatement: one behaviour crosses persistence, the
  API, the boundary and its cohort, so it got described four times, and three further parts existed
  only to restate. A 21-page page condensed to 9 with nothing of value removed, which measures the
  duplication at about half the document. So persistence, endpoint contracts and the backend/frontend
  boundary have **no sections of their own** — they are covered inside the checkpoint whose judgment
  turns on them. `report-format.md` § *One canonical home* carries the routing table and the
  one-sentence reference form, and a paragraph mapping where each part of the old shape went.

  Reintroducing a per-layer section is how this regression comes back, and it will look like an
  improvement when it does. **The agenda's own version of it is a checkpoint per file**, which looks
  like coverage: *ProjectSearcher implementation*, *Migration*, *Tests*. Five of those is the per-layer
  format with the section shells taken off, and it is cheaper to write than four merged judgments,
  which is exactly why a run reaches for it.
- **The order is the reviewer's path, and the checkpoint owns the explanation.** § 02 *What needs your
  attention* teaches the judgments; § 03 *Read the code in this order* is the moment they open the
  code; § 04 *Impact outside the diff* is the same change seen through one lens. Everything after § 02
  therefore **points back** at it — a checkpoint never defers an explanation forward, and §§ 03 and 04
  never re-explain one. § 03 is **one list**: what most needs judgment and what to read first are the
  same question, and answering it twice is the shape to watch for coming back. Where the attention
  goes is expressed by what is on that list and in what order; every other file is accounted for in
  the evidence foot, unranked.
- **Source excerpts are quotations, and the page reads complete without them.** A page
  primitive: a collapsed `details.excerpt` holding verbatim code, in two variants — `--diff` for
  changed lines, `--source` for unchanged ones, which is the variant that carries the product because
  no diff view can address an unchanged line. Three things have to stay true together. The page must
  read completely with **every excerpt closed** — an excerpt confirms a claim, never carries one, and
  that is the whole difference between progressive disclosure and hidden content; the hard rule is in
  `SKILL.md`, the form and budget in `report-format.md` § *Source excerpts*, and the shape in
  `page-template.html`. An excerpt sits **beside the claim or the *Look at* entry it confirms**, never
  in the evidence foot: the foot is provenance a reader is not expected to open, and a quotation that
  makes a judgment possible is not provenance. The quotation is **generated by `scripts/excerpt.sh`, never typed** — a
  mistyped ledger row fails the gate loudly, whereas a paraphrased quotation is a false quotation the
  reader cannot catch. And **`data-path` is reserved to inventory cells**: `coverage-gate.sh` greps it
  page-wide, so an excerpt using it would register as a surplus path, most reliably when quoting
  unchanged code — the gate would fail on the page's best content. Excerpts carry `data-src`.
  `evals/check.rb` holds the mechanical half of all three; whether the prose survives with the blocks
  shut is a judged expectation, because no script can tell.
  **The tint is applied, never authored.** `--source` excerpts are syntax-coloured at read time and
  `--diff` excerpts are not, and the asymmetry is the same one that produced the two variants: a hunk
  is not one lexical stream (a removed line and its replacement are alternate realities, and a lexer
  fed both mis-reads everything after the first unbalanced quote), and its rows already spend colour
  on *added* and *removed*. Four files agree: `excerpt.sh` puts a `data-lang` on the `--at` block and
  nothing else, `page-template.html` holds the `--syn-*` tokens, the `.hljs-*` rules and the script
  that does it, `report-format.md` § *Syntax tint* owns the rule, and `evals/checks/excerpts.rb`
  fails a page that ships `hljs-` classes in its markup — a hand-coloured quotation is a quotation
  someone edited.

  **Two grammars are loaded beside highlight.js's common bundle, because neither is in it**: `erb` for
  Rails views and `elixir` for Elixir modules. A language added to `excerpt.sh`'s `guess_lang` without
  its `<script src>` in the template tints nothing, silently — the page still reads, in one ink, which
  is why nothing catches it. **`.heex` and `.eex` deliberately emit no `data-lang`**: highlight.js
  ships no HEEx grammar, and both near-misses are wrong invisibly — `elixir` mis-reads the markup
  around the interpolations, `erb` tints Elixir as Ruby because `<%= %>` is the same delimiter. That
  omission is commented in both files as intentional, because it reads exactly like a gap. The script verifies its own reconstruction character by character before touching
  the DOM and leaves the line alone on any mismatch, which is the only reason a script may touch a
  quotation at all. Everything about it degrades to the untinted page: no script, no network, a
  blocked CDN or an unknown language each leave the block in one ink.

  **The per-flow `--diff` floor is gone with the flows, and what it was defending against is not.**
  It said every behaviour flow showed the hunk its behaviour turned on, because that section was read before
  the reviewer opened the diff. A checkpoint asks a question instead, and the answer is sometimes in
  unchanged code alone — so the excerpt test applies uniformly now, including to a changed hunk. The
  defence is that seeing the hunk is very often exactly what a judgment turns on, which makes the
  uniform test reach the same place the floor did without a rule of its own. Watch for pages whose
  excerpts are all `--source`: that was the failure the floor was written for, and nothing warns on it
  any more.

  **The state tag is the fourth, and it is the only part of an excerpt the bytes cannot vouch for.**
  `--at` used to hard-code `Unchanged`, which is a claim about the diff the script had never looked
  at, and a run duly published `db/structure.sql:304-313` tagged Unchanged on a page whose own ledger
  listed that file as changed. The quotation was verbatim; the label was false; the block read as
  *more* trustworthy the closer you looked. So `--at` now requires `--base` and computes the tag —
  `Unchanged`, `Added`, `Removed`, `At head`, `Before the change`, and `Changed` for a hunk — which
  makes the vocabulary closed, and `evals/checks/excerpts.rb` checks it both ways: an `Unchanged` tag
  against the changed set (a repo when it has one, otherwise the page's own ledger, which the
  completeness invariant guarantees is the whole diff), and every tag against the vocabulary, for the
  inputs where there is nothing to compare against.

  Two things about it are easy to get backwards. **Quoting a changed file at head is right, not the
  defect** — a hunk of an 18,000-line `structure.sql` cannot show that a table has *no* `CHECK`
  constraint, which is exactly what an invariant checkpoint reads for — so the rule constrains the tag
  and never the quotation. And **a path the diff touches is never `Unchanged` even where the quoted
  lines are untouched**, because section 04 and the evidence foot split changed from affected-not-changed *by file*: one
  word in two senses on one page, with nothing to tell the reader which was meant. That precision
  belongs in the prose, where it can be stated. Four files agree — `scripts/excerpt.sh` computes it,
  `report-format.md` § *Source excerpts* owns the rule and the vocabulary, `page-template.html` says
  the tag in its example is computed rather than copied, and `evals/checks/excerpts.rb` plus the three
  `golden/excerpt-*` rows check it — plus three more for the case where git is asked and cannot
  answer, since the relational half tested the exit status of a *pipeline* and so read a failing git
  as an empty diff, passing the very page two rows above it — one of which is the clean counterpart:
  a rule that fired on every
  excerpt sitting near a ledger would be worse than the defect.

  Two things the first live run changed, both worth keeping stated. The closed-page rule is judged
  **field by field**: a citation elsewhere on the page does not rescue a field whose only `file:line`
  sits inside the collapsed block, and `check.rb` cannot see that. And the budget's test is that the
  citation is **load-bearing for a decision the reviewer must make** — the obvious phrasing, "one per
  field that earns one", is circular, because *affected but unchanged* is by definition nothing but
  claims a reader would take on faith, so every such field earns one automatically and the cap bounds
  nothing. The budget, the permitted locations and the rung adjustment live in `report-format.md`
  **only**; `SKILL.md` points at them. An earlier version restated the cap in slightly different words
  and the two drifted apart within one run — hence the rule that this one has a single home.
- **Impact paths are section 04's figure, and the edge is the point of them.** A path runs from changed
  code, through the affected-but-unchanged code that gives the change its consequence, to an
  observable behaviour, with every hop past the first carrying its incoming relation as a causal
  verb. 1–3 paths, 3–5 nodes each, **one path per `.ip-card`**, one `.ip-out` last, at least one
  `.ip-aff`, labels never sentences, no citations inside the panel.

  **What it replaced is the reason every one of those rules exists.** `.blast` was a four-column box
  grid whose only encoding was border style, so it carried membership of two sets and nothing else —
  and `report-format.md` conceded the gap in prose: *"It cannot show a directed edge … put it in the
  note under the panel, in words."* A figure with a footnote explaining what the figure could not
  draw. Real pages then supplied the missing relation by writing a clause into every box, and the
  panel became a grid of sentences with no edges: the layout arguing with its own content. That
  workaround rule is **deleted**, not inherited.

  **The cap is 3 and the frame is the card, and both came from reading a published page.** It shipped
  as 2–5 paths stacked inside one bordered panel under a run of `.ip-hd` headers, and a real page
  took all five. At that length they stop being read as diagrams: the reader on the third chain has
  the first one's geometry behind them, a gap is the only thing saying where one path ends, and a
  shared frame invites a sixth. So `.impact` is a group now — the label, one `.legend`, the note —
  and each path is an `.ip-card` with its own `.ip-hd` and its own `.ip-lanes`.

  **Nothing is lost by the two paths that no longer fit, and that is what makes the cap affordable.**
  A consequence left out of the panel keeps its entry in the affected list beneath the panel and its explanation
  in the checkpoint that turns on it, which is § *One canonical home* doing exactly its job. Loosening the cap
  back out is how the figure becomes a section to scroll, and it will arrive as thoroughness.

  **The lane labels repeat in every card, deliberately**, which is the one requirement the split
  introduced that a run is likely to get wrong from the outside: one set of labels above one panel
  was correct for as long as there was one panel, and the mental model outlives the markup. A card is
  a whole figure, so a reader arriving at the third one must not scroll back for what its two columns
  mean. `impact-paths.rb` counts them per card, clamped at zero so the rule **abstains** when the
  card-to-path pairing has already failed — a card holding two paths carries a spare set of labels,
  and reporting that as surplus furniture is one defect reported as two.

  Two design choices carry most of the weight, and both remove a way a run can be wrong rather than
  adding a rule about it. **The lane is derived from the node kind** — `.ip-chg` left, `.ip-aff`
  right, `.ip-out` spanning both — so the changed/existing boundary is structurally true and there is
  no lane class to put on the wrong node. And **the label is an element, not an attribute**, so an
  unlabelled edge is a *missing* `.ip-rel` rather than an empty one, which is what makes the rule
  that matters most mechanically checkable at all.

  The first of those pays off twice, because **the lane crossing draws itself.** A change of lane
  *is* `.ip-chg + .ip-aff` or its reverse, so an adjacent-sibling selector adds the elbow with no
  extra markup and nothing for a run to place — it marks kinds, and the figure connects itself.
  Worth knowing before editing the CSS: the elbow runs the whole way between the two connector
  rails rather than stopping at the lane boundary. The boundary-stub version was the first attempt
  and it left a crossing path looking like two disconnected halves, which is precisely the reading
  the component exists to prevent. `.ip-aff + .ip-out` needs the same rule for the last hop,
  because the spanning outcome's rail sits in lane 1.

  **And it descends `--ip-drop` before it turns**, which was the third attempt: turning flush
  against the source box made the horizontal read as a line leaving the box *sideways*, where every
  other hop leaves a node downward. **Four rules have to agree on that one length, and the fourth
  is the one that breaks silently** — the destination rail has to start at the corner rather than
  at the row's top edge, or a hairline the length of the drop dangles above it in the other lane.
  The other three are the stub, the horizontal, and the reset to `0` under 780px, where the lanes
  collapse and there is no crossing to draw. It is a custom property on `.impact` for exactly that
  reason: agreement by scope beats agreement by comment.

  **Solid hairlines flow, dashes bound**, and the lane divider is the second thing that came out of
  looking at a rendered card. It was a 1px solid `--rule-strong` — byte-for-byte a connector — so
  the one line on the figure that carries no direction was drawn like the ones that do, and a path
  crossing it read as joining it. It is dotted `--rule-dash` now, at 2 on and 9 off: dashes are
  already how `.ip-aff` says *the existing system*, and the sparse pattern is what keeps a divider
  running the full height of a card from carrying more ink than the chain it sits behind. The
  colour deliberately did **not** go a step lighter — that loses the dots rather than quieting
  them, and the density is the right knob.

  **The vocabulary includes passive forms deliberately, and `ignored by` is the one to know.** A
  label reads from the node above to the node below, and half the edges here run producer to
  consumer, where the honest verb is *read by*. Without a passive a run inverts the pair to find an
  active verb and quietly reverses the figure. `ignored by` labels the commonest finding the page
  carries — a consumer that does *not* account for what changed — which is causal precisely because
  nothing happens; the box grid could only put that in a clause.

  Five files have to agree: `page-template.html` holds the CSS (head SKELETON range, so it is
  emitted and a run never types geometry) and the panel assembled whole in section 04,
  `report-format.md` § *Impact paths* owns the panel's own rules and its budget **alone** while
  § *Chains* owns what it shares with a checkpoint's `figure.chain`, `SKILL.md` step 9 points at both, `evals/checks/impact-paths.rb` carries the rules
  and its `CAUSAL` list, and the eight `golden/impact-*.html` fixtures plus their `self-test.rb` rows
  prove each one fires. Extend the vocabulary in the reference and in `CAUSAL` together — the rule
  the deleted `diagram.rb` stated for its class vocabulary, and which outlived it.

  **One of those eight is clean, and it is the one that matters most for the caps.** Running the
  check over a real published page produced two WARNs, and the rules were wrong rather than the
  page: the label cap counted `&ldquo;` as seven characters, so a 32-character label was reported
  as 44; and `subscribed by` — the honest label for a topic reaching the process that is *not*
  listening — was outside `CAUSAL`. So the cap measures glyphs now, through a `display_length`
  local to that check rather than through `ReviewMap.unescape`, which decodes the five entities
  the shell version did and must keep doing exactly that because `searches.rb` and
  `rails-anchors.rb` compare against what it produced. `golden/impact-entities-vocab-clean.html`
  carries both, with a `self-test.rb` row per rule pinned on its own PASS line — the
  `anchors-hexdocs-clean.html` pattern, and the reason to reach for it is the same: a cap that
  fires on correct content teaches a run to shorten a true label.

  Two of those fixtures are the card split, and both plant markup that draws.
  `impact-shared-card.html` puts two paths in one card **and pairs it with a card holding none**,
  because that is precisely what comparing two counts would wave through — so the rule reads the
  interleaving of card and path openings rather than the arithmetic. And `impact-four-paths.html` is
  one over the cap rather than three: the fixture it replaced planted six against a ceiling of five,
  which means it would have kept failing all the way down and pinned no particular cap.

  Verdicts split on purpose. Shape is a FAIL; an unlisted verb and an over-long label are WARNs,
  because a hard failure on vocabulary teaches a run to mislabel an edge to satisfy the check, which
  is worse than an unlisted verb that is true. And the thing no script settles: whether these are the
  right 2–3 paths and whether each edge is **true** — a question the tighter cap makes sharper, not
  softer, because choosing three out of six consequences is now part of the work.
  A page case is where that is asked, since the case that used to ask it
  is deferred with the rest of the section scope.

- **The skeleton is emitted, never typed.** `references/page-template.html` carries four
  `SKELETON:` markers. Everything in the head and tail ranges — the `<head>`, the entire token
  block, the three highlight.js tags and the tint script, 54.5 KB of it — is written straight into
  the page by `scripts/page-skeleton.sh`, once, at the top of stage 1. A run never reads those bytes
  and never types them; what it reads is the markup between the markers, via `--markup`.

  It began as a cost change and that is the least of it. 54.5 KB was resident twice from stage 1
  onward — once as the template read, once as the write's own input — which is 6-8% of a run's cache
  reads, plus ~15k output tokens and about 110s of streaming. **The real payoff is that every colour
  on a published page now comes from a script.** Measured on the template: `--syn-key` ×3, `--ex-add`
  ×3, the media dark block, both `[data-theme]` blocks — all of them in the head range, none in the
  markup half. The half-declared-token defect that § *Theme tokens* below and `excerpts.rb` exist to
  catch is not merely checked now, it is unreachable.

  Four files agree: the template holds the markers and the bytes, `page-skeleton.sh` extracts them,
  `SKILL.md` step 9 calls it once and forbids writing a `<style>`, a `:root`, a colour or a
  `<script>` into the page, and `skills/review-map/tests/run.sh` proves the script holds no bytes of
  its own. That last one is the load-bearing part, and it is a **partition** test rather than a
  comparison: strip the markers and the maintainer preamble, and head + markup + tail must be the
  template byte for byte. Extracting with awk and comparing against the script's own awk would test
  the script against itself and pass for any consistent pair of bugs — which is why two of
  `self-test.sh`'s cases mutate the *script* and not the template.

  Marker text is load-bearing too. A marker containing an opening `style`, `script` or `svg` tag
  would corrupt a check that scans for one — `Page#range` re-opens on its own `from` pattern, so the
  hazard survives even though the check that made it concrete (`diagram-shot.rb`, which lifted the
  `<style>` block out of the template) is gone. Each marker is also **one line**: extraction is a
  line range over the marker line, so a marker spilling onto a second line would emit half a comment
  into every page.

  **Two things must not appear in the markup half at all, and `tests/run.sh` counts both at zero**:
  an `<svg` opening tag, because this page has no drawings, and a literal tint class, because the
  tint is applied at read time and a hand-coloured quotation is a quotation someone edited. That is
  why the template's excerpt comment describes that class rather than spelling it — the rule and the
  prose about the rule would otherwise be the same bytes, which is the shape this repository keeps
  writing down.

  **`--markup` takes no flag, and the machinery that made it take one is deleted.** A second marker
  kind, `SKELETON:ONLY:level=<brief|full>`, used to bracket the regions belonging to one detail
  level — sections 4 to 7 against the merged brief section, and the rail below 03 — with a validator
  that failed closed on an unpaired marker, a nested pair, an unknown tag or a tag with no region.
  All of it goes with the level. `--markup` is now the plain extraction between `HEAD:END` and
  `TAIL:START`.

  **What that machinery bought is worth recording, because a future full mode will want it back.**
  The rail had shipped in the seven-entry form with a comment telling a `--brief` run to cut it to
  four and renumber — a transformation performed from prose that no check ever looked at, on the
  default level. The filter replaced that with a rail assembled at both shapes. If a level ever
  returns, it returns that way: **emitted, not described**, and subtractive by construction, so that
  *no line was added* is assertable without a second extraction to test the script against its own
  awk.

- **Theme tokens.** Every colour is defined on bare `:root` *and* redefined in both dark blocks
  (`prefers-color-scheme` and `[data-theme="dark"]`). A colour declared only inside a media query is
  the classic unreadable-artifact bug. `evals/checks/page-invariants.rb` § 6 enforces the three
  states and `excerpts.rb` enforces it for the excerpt tints specifically, which are the newest
  colours and so the likeliest to be forgotten in two of the three.

  The `--syn-*` tints are the ones easiest to half-declare: nothing on the page depends on them to be
  readable, so a value missing from the dark blocks is invisible until someone opens an excerpt with
  the OS in dark mode. They are therefore counted **by name** — `--syn-key` in `excerpts.rb`,
  `--syn-key` and `--ex-add` in `tests/run.sh` — because the three blocks *existing* is not the same
  as a colour being in all three. `--rails` was counted the same way in `page-invariants.rb` § 6 and
  is gone with the primer that was its only user; the counting idiom is what outlived it.

  Worth knowing when editing: the source design is **light-only**, and the dark half is ours. So the
  one pair that inverts — `.ip-out`, the filled node that ends a chain — is written against tokens
  rather than literals precisely so it keeps inverting *relative to the page* rather than flipping to
  an unreadable combination in one theme.

## Invariants the CI setup adds

Same rule as above: editing one of these means checking the others still agree.

- **Generation does not know where the page goes.** `review-map` writes a portable static directory;
  `ci/delivery/deliver.sh` is the only thing that knows what happens to it afterwards. That seam is
  the reason GitHub artifacts can be the default without being a commitment — a team that later puts
  Review Maps on a static host adds one file under `ci/delivery/` and changes one line of
  configuration, and nothing about how the page is produced moves.

  Five files agree: `deliver.sh` dispatches and prints the DeliveryResult, a provider is one
  `<name>.sh` reading `AR_*` and printing `key=value`, `references/delivery.md` owns the contract
  **alone**, the workflow template guards its upload step with
  `if: steps.delivery.outputs.provider == 'github-artifact'` so a different provider makes it stand
  aside, and `tests/run.sh` asserts the four canonical fields.

  **The failure mode is a destination threaded back into generation** — an `--artifact-name` on
  `generate-review-map.sh`, an "upload the map" step inside the skill — and it will arrive as a
  convenience. If a new provider seems to need a change in `review-map` or in
  `generate-review-map.sh`, the seam is in the wrong place; move the seam.

  A subtlety worth keeping: `github-artifact` does **not** move bytes. Uploading from a step script
  means reimplementing the Actions artifact protocol, so it names the destination and the workflow's
  standard upload step does the transfer. That split is fine — generation still cannot tell which
  happened — but it is why the provider emits `artifact_name` and `retention_days` as extra keys, and
  why extras are carried through to `$GITHUB_OUTPUT` at all.
- **The CI page and a person's page are the same page.** `--output <dir>` changes where the bytes
  land and nothing else: same sections, same depth rules, same excerpt budget, same completeness
  gate. `SKILL.md` step 1 owns the flag, step 9 says the stages become save points rather than
  publishes, step 10 says there is nothing to publish at the end.

  **A cheaper CI page is the regression to watch**, and it will look like thrift — skip the excerpts
  nobody will open, skip the flows on a big diff, skip the gate because there is no reader. Take any
  of those and there are two products, only one of which is developed against, and the one the team
  actually reads in CI is the one nobody looks at while editing the prose. `--brief` is the answer to
  "how much page", at both levels of watching; `--output` is not a second one.
- **A Review Map names its revision, on the page.** Two short SHAs in the masthead's `Revision` cell,
  head → base, beside the branch names. Three files agree: `report-format.md` § 1 states the rule,
  `page-template.html` carries the cell, and `ci/generate-review-map.sh` refuses to deliver a page
  that does not contain the head's short SHA.

  It is not CI-specific and must not become so. A branch name goes stale the moment someone pushes,
  and a page that describes an earlier revision while looking current is the one failure a reader
  cannot detect from the inside — which is exactly what regenerating per push creates, several pages
  that differ only by revision.
- **The workflow is a design, not a settings file.** The triggers, the draft guard, the fork guard,
  the concurrency group and `contents: read` have no knobs, because a knob on each is a way to end up
  generating Review Maps for draft pull requests, which is the thing the setup exists to prevent.
  `render-workflow.sh` substitutes four values — which plugin, which ref, which Claude Code, which
  Node — and everything a team legitimately configures is read from `.accountable-review.yml` at
  **run** time by the scripts the workflow calls, so changing it never means regenerating the file.

  That split is what makes "the workflow respects `retention_days: 14`" true without a second setup
  run, and it is why `tests/run.sh` checks retention through `deliver.sh` rather than by grepping
  YAML.
- **Idempotency is decided by comparing bytes, so nothing rendered may vary.** No timestamp, no run
  id, no randomness, no "generated on" comment — `install-workflow.sh` tells "already set up" from
  "edited by hand" by `cmp`, and a date would make every second run report drift. `tests/run.sh`
  asserts the rendered file contains today's date nowhere.

  **That assertion has to run against the whole file, comments included.** It did not, briefly: the
  negative assertions run against a comment-stripped copy so the workflow may explain in a comment why
  it does not use `pull_request_target`, and a timestamp added as a comment sailed straight through
  a test whose entire purpose was to catch it. `tests/self-test.sh` case 6 is that regression.
- **Drift is reported, never resolved.** A hand-edited Accountable Review workflow is a file a team
  owns, and setup reverting their pinned action or tightened timeout is the worst thing this command
  can do. `install-workflow.sh` prints the diff and exits 3; `--update` is the only way past it, and
  `SKILL.md` step 3 says to show the user and ask.
- **CI must not become the place that runs the application.** The page proposes validation commands
  and never runs them — the reason no probe output ever appears — and a workflow that booted the app
  "so the map could be better" would be that decision made by the back door, with its own safety
  design skipped. The template starts no service, runs no migration, and executes no script from the
  pull request; `tests/run.sh` asserts all three against the comment-stripped file.
- **The product principle reaches the artifact, not just the page.** `manifest.json` is provenance —
  which revision, which plugin version, whether the coverage gate passed — and carries no severity, no
  score and no approval, for the same reason the page carries none. The job summary says what the
  Review Map is *for* and says outright that it does not review the change. A "Review Map: PASS" check
  on a pull request would undo the whole format, and it is exactly the shape the next feature request
  will take.

## The catalogue is the one thing a run cannot verify

Both `references/rails-docs.md` and `references/elixir-docs.md` are allowlists, and the run takes URLs
from them without opening them — there is no fetch step and egress to those hosts is commonly blocked. That is the right runtime rule
and it is not up for revisiting: a live search per anchor would add requests to the run's scarcest
resource, make two runs of the same PR cite different URLs, break `assumes only Claude Code plus a git
repo`, and put SEO-ranked mirrors of Rails 4 docs inside the trust boundary the allowlist exists to
draw.

What follows from it is that the file's correctness is a **maintenance** property with a date on it,
not a property of the run. The first re-check found **8 defects in the 88 URLs it then held**, in three classes:
version drift the unversioned URLs cannot notice (7.2 moved `insert_all`; the controller guide renamed
one section twice), a guide page that had never existed in any series, and three fragments GitHub
stopped emitting. Only the first is what "the docs moved" intuitively means, and only the second is
catchable by reading.

### `elixir-docs.md` is closed, and that is the feature

The Elixir catalogue ships **complete in structure and content and withholding every link.** Its
§ *Version* says no row in it has been opened, and instructs the run to emit nothing from it until a
dated verification line replaces that paragraph. So an Elixir run today anchors with probes and prose
and carries no documentation URL at all.

This is not a half-finished file, it is the fail-closed rule applied at **file scope** rather than at
row scope, and the reason is the defect class directly above: the worst thing the Rails sweep found was
not rot but `active_record_nested_attributes.html`, a plausible URL constructed once and admitted to
the allowlist, which no script catches and no amount of care while writing prevents. Every Elixir row
was written the same way that one was — from knowledge, by a process with no egress to hexdocs. Holding
them closed is the only honest state for rows nobody has opened.

**What lifts it is one command**, and `evals/verify-catalogue.sh --catalogue references/elixir-docs.md`
is therefore that file's release gate rather than optional maintenance the way it is for the Rails one.
A clean run prints a dated line and the package versions it checked at; that line replaces the withhold
and the links go live in the same commit.

Two things worth knowing before touching it. **The marks in it are a first pass**, not the output of a
CHANGELOG audit like the Rails ones — the file says so of itself, and says that the LiveView `0.20 → 1.x`
range is where an audit would pay most. And **the probe is unaffected and is the better anchor anyway**,
which is the position `rails-docs.md` § *Pinning* already argues on its own terms: a probe interrogates
the installed code instead of describing it, so it cannot be out of date and cannot 404. A closed
catalogue makes an Elixir page narrower, not wrong.

### Pinning per series, and pinning per package

The two catalogues pin differently, and exactly one page-level rule differs with them.

Rails has a single `major.minor` for the whole framework, so **one app, one series**: a page mixing
`/v7.1/` with `/v8.0/` pinned from something other than this repo's `Gemfile.lock`, and
`checks/rails-anchors.rb` fails it. An Elixir app pins `ecto`, `phoenix`, `phoenix_live_view`, `oban`
and `elixir` independently from `mix.lock`, and hexdocs serves *exact* versions rather than resolving a
series prefix to the newest patch — so **a correct Elixir page carries several different version
segments**, and generalizing the one-series rule to hexdocs would fail every correct Phoenix page while
passing every existing test. `evals/golden/anchors-hexdocs-clean.html` exists for exactly that edit: it
is a *clean* fragment carrying two package versions on purpose, so the mistake goes red in `self-test.rb`
instead of in the field.

Two consequences follow for the machinery. The stored path **keeps its package** —
`ecto/Ecto.Changeset.html#cast/4` — because `Ecto.Migration` under `ecto` rather than `ecto_sql` is a
404 that reads as correct, and keeping the package in the path is the only thing that makes it
checkable; `anchors-hexdocs-wrong-package.html` pins that. And `verify-catalogue.sh` checks a hexdocs
row **once, at its package's newest stable release**, the way it already checks a gem row, because
there is no series axis to expand along. The six standard-library docs (`elixir`, `eex`, `ex_unit`,
`iex`, `logger`, `mix`) have no hex package at all and take Elixir's own release version, with
`--elixir-version` as the override when the GitHub API is unreachable.

### Pinning, and the two things it does not fix

**Every doc link is pinned to the app's own version** — the Rails `major.minor` from `Gemfile.lock`
for the two Rails hosts, the exact locked version for a gem's tag. Unconditionally, including for the
39 rows whose meaning has not moved in a decade. The reason is not precision, it is *checkability*: a
pinned Rails doc page prints "Ruby on Rails 8.0.5.1" in its header and a GitHub tag shows the tag, so
the reader can hold the link against their own lock file. An unpinned path silently means current
stable and offers nothing to check — which is how a page explains 8.1 behaviour to a 7.1 app in a tone
of complete confidence. Above the verified ceiling the run pins anyway and the script catches it
later; below the floor, or where a row has no verified path, **it emits no link at all.** Failing
closed is the guarantee: an unlinked explanation cannot mislead.

Pinning fixes the URL. It does **not** fix the sentence, and that is the part that actually misleads.
A perfectly pinned 8.0 link under *"`perform_later` enqueues before the transaction commits"* is more
authoritative and still wrong, because 8.0 defaults `enqueue_after_transaction_commit` on. So an audit
of the Active Record / Active Job / Action Pack / Active Support CHANGELOGs for 7.2, 8.0 and 8.1
classified all 47 Rails rows, and the result is two marks that constrain the **claim**, never the link:

- `‡ probe` — the behaviour changed inside the range, so no sentence is true of every app. The page
  may not assert it: name the setting that decides it and propose a probe. Three rows.
- `‡ since X` — surface was added in X, the default still holds. State it as the default and name X.
  Five rows. A probe here would be over-citation, which is the failure the anchor budget exists for.

They are different actions, not severities, and collapsing them costs something either way. The audit
also found the old single ‡ was catching about a quarter of what it existed to catch: of three marked
rows two were right, one was over-applied (nested `transaction` join semantics never moved), and six
version-sensitive rows carried no mark — including strong parameters, where **8.0 introduced
`params.expect`** and a page could confidently recommend it to a 7.2 app that cannot run it.

**The probe is the version-proof anchor**, and that is why `‡ probe` routes there rather than to a
better link. A probe interrogates the installed code instead of describing it, so it cannot be out of
date. The catalogue's whole version problem dissolves for probes and is only ever managed for links.

`evals/verify-catalogue.sh` is the maintenance pass — every row in the **pinned** form a run actually
emits, every series in the floor, per-series overrides honoured, dated, exit 1 on any defect. Checking
the unpinned form would be checking a string nothing emits. A clean run now proves something stronger
than it used to: every row resolves for every app the catalogue admits (currently 322/322). Three
things about it are load-bearing:

- **It reads table rows only** (`grep '^|'`), because the prose quotes the dead URLs it is warning
  about, and a whole-file sweep would verify the warnings. `checks/rails-anchors.rb` now narrows the
  same way, for the same reason — it derives its allowlist from this file, so a URL named in a caveat
  would otherwise allowlist itself.
- **It is not under `checks/`.** `check.rb` dispatches offline rules over a page; this needs the
  network, so it is neither dispatched nor part of `self-test.rb`.
- **It cannot replace reading the page.** It proves a URL resolves and an anchor exists, never that
  the page documents the concept the row claims. § *Adding a row* still comes first.

The version floor is **7.1 → current stable**, one string at the top of the script. Three of 57 rows
resolve to a different path in some series — `insert_all` moved class in 7.2, the controller guide
renamed one section twice, conditional validation gained a plural — and each carries its override
inline in the cell as `· <series>: <path>`, right where a run is already looking rather than in a
table it has to remember to consult. Below the floor: no link.

Six files have to agree. Each catalogue's § *Pinning* and § *What the marks mean* own the forms and
the marks **alone**; `report-format.md` § *Framework anchors* states why the page cares and points;
`SKILL.md` step 2 records the versions (a run that skips it cannot emit a doc link) and step 7 carries
the two rules; `verify-catalogue.sh` verifies the pinned form; and `checks/rails-anchors.rb` enforces
offline what it could not before — **every doc link carries a version segment, in either stack**, and
**the Rails ones all agree on one series**, because one app has one Rails version and a page mixing
`/v7.1/` with `/v8.0/` pinned from something other than this repo. That second rule is Rails-only and
must stay that way: see § *Pinning per series, and pinning per package*.

`page-template.html` is the sixth, and it is the one that was missed first time round: it shows the
doc link **already pinned**, with the version as a placeholder and a comment saying it is substituted
per run. The assembled example is what step 9 copies markup from, so a template carrying the unpinned
form teaches a run to publish a page that fails its own check — and one carrying a literal `v8.0`
teaches one app's version to every other. `golden/anchors-unpinned-link.html` and
`golden/anchors-mixed-series.html` prove both fire.

Two more rules in that check exist because a review found them missing, and all four bypasses shared
one shape — **a rule that passes is not a rule that looked**:

- **An unsubstituted `{version}`** matches its own catalogue row perfectly, so the allowlist test
  waves it through while it is a guaranteed 404. Forgetting the substitution is the likeliest
  mechanical failure of gem pinning, so it gets its own rule rather than relying on a rule about
  something else.
- **A path catalogued only as another series' override.** Pinning
  `Persistence/ClassMethods.html#method-i-insert_all` at `/v8.0/` returns HTTP 200 on a page that
  never mentions the method — the exact defect § *Version* calls worse than a 404, reintroduced by the
  override mechanism meant to fix it. The check knows the page's series and the row knows the
  override's, and nothing had correlated them.

The allowlist test itself was matching **substrings**, against a comment claiming it did not:
`guides.rubyonrails.org/v8.0/validations.html` — a 404 — passed because `validations.html` sits inside
`active_record_validations.html`. It matches whole backticked tokens now. The rule whose stated
purpose is *"a URL nobody opened is a 404 the reader finds"* was passing a 404.

And the fixtures needed `Gemfile.lock`, which none had: pinning reads the locked version, so every
fixture run would have been obliged to emit no links at all, making the case expectations
unsatisfiable. `rails-only-small` and `monorepo-contract` now lock **7.1** deliberately — that is the
series the `insert_all` override applies to, so the fixtures exercise the override rather than only
the common path.

## Deliberately single-context, with one named exception

The skill runs in one context and spawns exactly one kind of agent, the falsifier that reads one
analysis note. That is a
choice, not an omission — an earlier iteration fanned out to `Explore` agents per layer, and it came
out.

`SKILL.md`'s hard rules now say so outright, which they did not before: a real run reached for one
`Explore` agent and stalled the parent for 997 seconds — 41% of its wall clock — in a single blocked
turn. A boundary stated only here is a boundary the skill has never been told about.

**The one exception is the falsification pass** (`SKILL.md` step 6c, folded in at step 8, and
`agents/claim-falsifier.md`), which since 0.16.0 runs by default. It is worth understanding why it does not reopen what the paragraphs
below closed, because the next thing that wants an exception will look similar and probably is not.

The seam is per **analysis note**, which is per flow, which is the seam those paragraphs already name
as the right one: a flow is a whole behaviour, so nothing is fragmented that the analysis had not
already separated. The agent is read-only and returns *challenges*, not page content — the parent
still writes every word, and still opens every cited file before acting on one, so no comprehension
moves anywhere.

**The note is what the agent reads, and that is a change from the first version of this pass.** It
used to be handed a published `<section id="flow-x">` — markup, excerpts, a rail — which meant two
costs: the agent spent reads finding the claims inside a document, and a flow corrected by a
challenge **had been wrong in public** for as long as the challenge took to arrive. A note is prose,
every citation is a `path:line`, and it exists before anything is published. There is now a synthesis
step after the split (step 7), which is the one thing those paragraphs warn about — but it
reassembles the parent's own notes rather than several agents' conclusions, which is the distinction
that made the warning necessary.

**And it does not block, which is the fact that changed the default.** The agents launch async and
return a receipt in about two seconds; the challenges arrive as notifications while the parent drafts
stage 4. Measured on a 28-file PR at `--brief`: five falsifiers, **23 seconds of blocked parent, 0.9%
of a 2607-second run**, first challenges landing 365 seconds after the last spawn.

**The cost objection the flag was gated behind was half right, and the half that was right is the
tokens.** It does not cost *wall clock* — that part was an artefact of how the pass was assumed to
work. It does cost tokens: each falsifier reads in its own context, and profiling those transcripts
put the pass at **17-23% of every cache-read token** a run spends, over 145-216 requests. Two numbers,
two questions, and the flag is defensible on the first while remaining the second most expensive
thing in the procedure. What follows is not that the default is wrong but that the *model* is a knob:
`agents/claim-falsifier.md` pins its own, because a reader whose output the parent re-verifies before
using is the safest place in this design to spend less.

They still go out in a single message. It costs nothing, the challenges then arrive together rather
than trickling, and if a harness ever does make them block, one message stalls the run once — for the
slowest — where the same agents one at a time stall it once each. The 997 seconds were one sequential
blocking spawn, and that number is about `Explore`, not about the falsifier.

Two things it is not. It is not a licence for step 5, step 6 or step 7 to fan out — the first two
span the whole diff by nature, and step 7's whole job is holding the whole agenda at once in order to
merge and rank it, which is the least splittable thing in the procedure. And it is not a second
context doing the work: the falsifiers read, the parent writes, and the parent transcript still reads
as one context plus a handful of receipts. That last fact is a trap as well as a reassurance: it is why
`profile.sh` reads `<session>/subagents/` too, and why a run cost quoted from the parent alone is a
fifth to a quarter short.

**A run that waits on them has lost the whole argument.** The 0.9% holds only because the parent
drafts while they read; spawn-then-idle turns the cheapest step in the procedure into the most
expensive, and it is the likeliest way this default gets reverted by someone measuring it.

The reason is that the decomposition is the *next* thing to get right, not something to inherit
half-specified. Two of this version's steps span the whole diff by nature: step 5 traces consumers
across both sides of the stack, and step 6 groups behaviour that no single layer contains. Splitting
those by layer is exactly the mistake the page exists to correct — it would move comprehension
fragmentation from the human to the agents, and the synthesis step would have to reassemble what the
split threw away.

So a very large diff will strain this version. That is the signal the next iteration is meant to act
on, which is why `SKILL.md` tells the skill to *report* the strain (say which region it skimmed)
rather than quietly skim. When specialists do arrive, the seam is per-flow, not per-layer, and the
orchestrator's job is reconnecting them into end-to-end behaviours.

### The unsolved half: how to sample a diff too large to read

`SKILL.md` says to report the strain. It does not say how to *choose* what to skim, and that gap is
the one thing a 112-file run exposed that has not been fixed. Naming it here so the next iteration
starts from the real question rather than rediscovering it.

The run in question — 112 files, 14.8k insertions, a Rails API and a Next.js client in one diff — got
through the goal, the impact section and five verified affected-but-unchanged findings, and would have
needed several times that budget to finish the flows and account for 112 paths. Nothing about it
failed. It simply ran out of room, in a way the procedure has no policy for.

**The agenda is not the answer to this, and it will be reached for as though it were.** A five-item
agenda over a 112-file diff is not a smaller problem: the run did not run out of room writing
sections, it ran out tracing consumers, and the synthesis step cannot rank judgments it never found.
What the agenda does change is the *reporting* — a strained run owes a statement of which region it
skimmed, and `$W/analysis/` now shows which flows got a trace and which got a glance, which is a
better record than the page ever carried.

What makes this hard is that the honest sampling strategy runs against the skill's own instincts:

- **The completeness invariant is not the same as reading everything.** Every path must appear in the
  page; the depth rules already say most appear as a ledger row. So the question is not "which files
  do I cover" but "which files do I *open*", and the ledger is what makes a shallow pass on the rest
  legitimate rather than a silent gap.
- **Cheap signals exist and are unused.** Line counts per file, the status letter, whether a file has
  a matching spec, whether it is named in a commit message, whether anything outside the diff
  references it. `ledger-rows.sh` already prints the first two. A defensible sampling rule could be
  built from them without opening anything.
- **The work is not equally compressible.** A migration and an API contract are small and
  load-bearing, and skimping there is what makes a page wrong. Tracing every consumer of every
  changed thing is where the volume is, and a trace stopped one hop short still finds most of what
  matters. So the budget should be spent unevenly, and the skill currently gives no basis for that.
- **Whatever is skipped has to be visible.** A skimmed region must say so in *What changed*, in the
  same voice as any other stated limit, not in a footnote nobody reads. The build states already
  carry the vocabulary for this — a fifth shape alongside written, pending, not written and omitted.

Decomposition may dissolve some of this: a per-flow agent has its own context, so the aggregate
budget grows. It does not dissolve all of it — the orchestrator still has to decide how many flows
are worth an agent, and that is the same question one level up. And it runs into step 7, which has to
hold every note at once to merge and rank them; more notes is a bigger synthesis, not a smaller one.

## The other unsolved half: `--review`

`--review` is declared, parsed, and stops. `SKILL.md` § *The review level is not implemented yet* has
the runtime behaviour; this is the design brief, written down so the next iteration starts from the
real question. It is meant to run the project's code-review pass as well and thread its findings
through the map.

**It is not "run `/code-review` and paste the output", and the reason is the product principle.** A
code-review pass produces graded findings — severity, confidence, a ranked list. This page carries no
verdict, structurally: the template has no chip that expresses one, and reintroducing a severity
vocabulary is named above as the single easiest way to undo this iteration. So the naive
implementation breaks the invariant the whole format is built to hold, and it will look like a feature
while doing it. **The agenda makes that sharper rather than easier**: a graded finding list is very
nearly the shape of a ranked checkpoint list, and the difference — that one carries severities and
the other carries questions — is one word per item wide.

**`--effort high` has now built half of this**, which is the reason to read the rest of this section
before writing the level rather than after. The routing it needs — an external challenge arriving,
being verified against the file, and landing in the checkpoint that turns on it in the page's own
voice with no grade attached — is the mechanism `SKILL.md` steps 6c and 8 now run at `high`. What `--review` still has to
solve is where the claims come from and how a *graded* source is stripped, not what to do with one
once it arrives.

**The seam that resolves it, and the reason this level is worth building at all:** a review finding
enters the page as a **claim to verify**, never as a finding to display. Two steps already do that
work. Step 8 says read the file yourself before any claim reaches the page, and drop what does not
survive. Step 5 routes a consequence to the code it reaches. So a verified finding lands in the checkpoint whose judgment it bears on — in the explanation, in a
*Look at* entry, or on the *Open question* line — in the page's own voice, with the review's severity
label stripped. A finding that is a judgment of its own becomes a checkpoint and goes through step
7's merging and ranking like any other. An unverified one is dropped, by a rule that already
exists. The review pass becomes a *search strategy* feeding step 5, which is
exactly where this skill is weakest, rather than a section of imported conclusions.

Four things to settle before writing it:

- **It probably needs a sixth evidence tier**, something like *reported by the review pass, verified
  against the file*. Five tiers are an invariant four files agree on (`report-format.md`, the
  template's `span.tier`, `page-invariants.rb` § 3, and the cases), and the asymmetry that only four
  of them carry a label is deliberate. Adding one is a real change, not a footnote — and the
  alternative is defensible: a verified finding is just *evidenced by unchanged code* or *explicitly
  changed* like any other, and where the claim came from is provenance rather than evidence.
- **It is the first place the skill depends on something outside itself.** Everything else assumes
  only Claude Code plus a git repo. `/code-review` ships with the CLI, but a project may have its own,
  and the boundary against assuming project layout applies here too: discover the review command,
  do not assume it. A repo with none should degrade to `--full`, saying so.
- **Findings and checkpoints do not line up one to one.** A review comments per hunk; this page is
  organised per judgment, and three comments on three hunks are routinely one judgment. A finding spanning two flows, or landing in a file no flow owns, needs the same
  routing decision § *One canonical home* already answers — which is encouraging, because it means the
  rule exists, and it means the mapping has to be written down rather than left to the run.
- **The hard rule against posting anywhere is not relaxed.** A page that now contains review material
  is still a page, and still never a comment on the PR.

One thing not to do: publish a page and mark the review part *pending*. Pending is a promise, and
nothing is writing it.

## Boundaries the skill must keep

These are deliberate scope limits, not omissions — do not "improve" the skill past them.

- **It helps a reviewer decide; it does not decide.** The page carries evidence, relationships,
  invariants, uncertainty and validation steps. It never carries a verdict. `/code-review` is a
  different tool answering a different question — and `--review`, when it exists, will not change
  that: it borrows the review's *search*, not its conclusions. See § *The other unsolved half*.
- **It links to the manual; it does not reproduce it.** The catalogue exists so a framework
  consequence is followable, not so the page can teach Rails to a reader who does not need it. And it
  never executes what it proposes: the skill does not boot the application under review, which is why
  no probe output ever appears. Changing that is a new decision with its own safety design, not an
  extension of this one.
- It never posts to GitHub or anywhere outside the artifact. **This is unchanged by running in CI**,
  which is the obvious next thing to want: no pull request comment, no check run, no status with a
  verdict in it. The workflow run is where the artifact is discoverable, and `setup-ci`'s hard rules
  say the same thing from the other side.
- It never writes the page into the repository under review — a work directory under `$TMPDIR` only,
  **derived** in step 1 from the repo and the target rather than chosen per run, or the directory
  `--output` names, which `ci/generate-review-map.sh` refuses to let sit inside the checkout.
- It re-publishes to the same file path on a re-run, so one PR keeps one URL across pushes. That is
  the reason the path is derived and not picked: a session-scoped scratch directory is a different
  directory next session, so "the same path again" needs a rule, not a memory. Profiling a run that
  had no rule found nine calls and seventy seconds spent re-establishing a path and moving excerpt
  files that had been written somewhere else first.
- It assumes only Claude Code plus a git repo containing a Rails or a Phoenix app. Everything else —
  which of the two it is, the Rails root location or the `lib/<app>` and `lib/<app>_web` split, RSpec
  vs Minitest vs ExUnit, API-only vs server-rendered vs LiveView, how authorization is attached,
  whether a separate frontend exists and where its client and types live — is discovered, never
  assumed. Adding an assumption about project layout is a regression, and **defaulting to a stack when
  neither is detected is the same regression wearing a helpful face**: the honest output is the
  stack-independent page with no anchor on it.
- The frontend is a first-class half of the contract, not a frontend review. The page follows fields
  and error cases across the boundary; it does not critique component design. In a LiveView app the
  boundary is the `phx-*` attribute and the callback answering it rather than a JSON contract, and the
  same limit applies: the page follows the event and the assign, it does not review the markup.

## Editing style

The skill's prose carries its own reasoning: rules state *why*, and several include the observation
that produced them. Preserve that when editing — a rule stripped to an imperative loses the thing
that makes a model follow it under pressure. Match the existing register: direct, specific, no filler.
Documentation-only changes still belong in the same voice as `README.md`, which is the public face of
the project.

## Publishing

`.claude-plugin/plugin.json` is the plugin manifest. Its `version` is the update pin: users only
receive a change once that field moves, so bump it in the same commit as the change and tag the
release.

```bash
claude plugin validate . --strict
claude plugin tag --push          # creates accountable-review--v<version>
```

The marketplace catalogue lives in a separate repository, `wyeworks/claude-plugins`, whose
`.claude-plugin/marketplace.json` is named `wyeworks` and points at this repo:

```json
{
  "name": "accountable-review",
  "source": { "source": "github", "repo": "wyeworks/accountable-review" },
  "description": "Turns a pull request into a published review map a reviewer can read before judging the change."
}
```

Keep `version` out of that entry — `plugin.json` wins when both are set, and one source of truth is
less to forget. A catalogue entry may pin `ref` or `sha` instead if a release needs holding back.

Two things do not belong at the plugin root: a `CLAUDE.md` (it ships to every install but is never
loaded as project context, which is why this file lives in `.claude/`), and any component directory
inside `.claude-plugin/` — only the manifest goes there.
