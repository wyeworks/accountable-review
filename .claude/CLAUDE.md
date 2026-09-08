# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

There is no application code here. The repository is the `accountable-review` Claude Code plugin. It
ships two skills — `skills/review-map/` and `skills/setup-ci/` — plus the one subagent the first of
them spawns (`agents/claim-falsifier.md`, and only at `--effort high`), plus `ci/`, which is neither
a skill nor read by one. `review-map` turns a pull request into a published HTML review map: what the
change is for, what it can break, what the API and its client now agree on, and where the decisions
live. Two stacks are supported: a Rails API with a Next.js client, which came first, and
Elixir/Phoenix — a LiveView app or a JSON API. Step 2 detects which, and the run reads that
stack's lens file and its doc catalogue, never both. `setup-ci` writes the GitHub
Actions workflow that produces one automatically on every review-ready pull request, and `ci/` is
what that workflow runs.

**`review-map` is the product; `setup-ci` is plumbing for it.** The second exists so a team gets the
first without anyone remembering to ask, and nothing about it may change what the page is. The page
produced in CI and the page produced by a person are the same page from the same procedure — the
only difference is `--output`, which decides where the bytes land.

Installed, it is invoked as `/accountable-review:review-map`: plugin skills are always namespaced by
the plugin name, so the manifest name and the skill directory name together decide the public
command. It takes a target, a **detail level** — `--brief` (the default), `--full`, `--review` — and an
orthogonal **effort** — `--effort high` (the default, adding an adversarial pass over the flows) or
`--effort low`, which opts out —
parsed in step 1 as prose, because `argument-hint` and `arguments` are not in the Agent Skills
frontmatter allowlist and `claude plugin validate --strict` rejects an unknown key. The "source" is
prose that another Claude instance executes, so the unit of quality is instruction clarity, not
compilation.

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

Then: `/accountable-review:review-map <PR number | PR URL | branch | ""> `.

Before pushing, `claude plugin validate . --strict` must pass — CI runs the same check, and so does
the community-marketplace review pipeline.

Because defect discovery is sampling rather than a deterministic function of the diff, a single run
is weak evidence. When judging whether a wording change improved things, run the same target more
than once, or the same wording against several PRs of different shapes (a 4-file bugfix, a migration,
a 100-file feature spanning both sides of the API) — small PRs and large ones exercise opposite
failure modes.

Two checks are worth making on every run, because they are where this version is most likely to be
wrong: open two entries from *affected but unchanged* and confirm the cited file really consumes the
changed thing, and confirm no sentence anywhere grades the PR.

Run both levels. They fail differently: `--full` strains the context and duplicates across seven
sections, `--brief` compresses four kinds of material into one section and its characteristic defect
is a tail that has quietly become a list of four things with the impact paths as one item. A wording
change judged at one level says little about the other.

`skills/review-map/evals/` is where that judging happens, at three scopes.
`fixtures/make-fixtures.sh` builds four repositories whose interesting findings sit deliberately
*outside* the diff, so there is a written right answer to check against. A **page** case is a whole
run, graded on what only a whole page carries. A **section** case produces one fragment from the
hand-authored upstream in `frozen/` and grades that — which is what makes "run it three times"
affordable, and three runs is the smallest sample that separates a wording change from noise. A
**component** check runs on a script's output or on one `<svg>`.

`bin/evals section behaviour-flows` is the loop — `./run.sh behaviour-flows -n 3 -j 3 --judge` then
`./report.sh`, which is what that dispatcher supplies and all it supplies; results carry the skill's
git sha, so a pass rate is attributable to a version of the prose. `--judge` adds the other half: one
model pass per fragment over the written expectations, anchored by running inside the fixture with
the frozen upstream, its counts under their own keys and never summed with the mechanical ones.

Every second of that loop is the model — the fixtures build in under a second and `check.rb` in under
two tenths — so `run.sh` takes `-j N` to run the repetitions at once and `--fast` (`--model sonnet
--effort low`) to read each one more cheaply. The first is free; the second is not, and the price is
comparability, which is why the model and effort land on every result line and `report.sh` makes them
part of the group key. Shape a wording change on the fast loop, then re-measure on the shipping model
before quoting a number. `--fast` leaves the judge alone deliberately: the producer is what is under
test, the judge is the measurement, and a cheap measurement is not a faster loop.

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
and a profile that reported only the first is why the pass read as free.

It infers nothing the transcript does not carry:
publish stages are mechanical, the ten steps are **not** —
`ledger-rows.sh` fires at minute four and again at minute thirteen — and steps 4, 6 and 8 leave no
trace at all, so they get no row. Read `evals/README.md` § *Where the time goes* and § *Profiling one
run* before quoting one of its numbers.

Section files are named by slug, never by number: `report-format.md`'s numbering is already the
source of order, and a filename repeating it only makes the reader look the number up. Read
`evals/README.md` before adding a case. Two things there are worth preserving above the rest — the
split between mechanical and judged expectations, and the plainly stated limit that a section eval
cannot see whether the page repeats itself.

## How the documents divide the work

Each reference owns one axis; keep them from bleeding into each other.

| File | Owns |
|---|---|
| `SKILL.md` | The procedure — ten ordered steps from resolving the target to publishing — plus the product principle and the hard rules |
| `references/report-format.md` | Page structure — the detail levels and which sections each produces, what triggers each section, the review unit, the evidence tiers, source excerpts, **impact paths**, the canonical-home rule, depth rules and the deep-link ladder |
| `references/rails-nextjs.md` | Domain knowledge, **Rails** — what a senior reviewer of that stack looks for, per layer, plus the runtime probes and the search recipes for affected-but-unchanged code. Its three client-side sections are stack-independent, and the Phoenix file points at them rather than restating them |
| `references/phoenix-liveview.md` | Domain knowledge, **Phoenix/LiveView** — the same three parts for the other stack. Its centre of gravity is § *LiveView*: the `phx-*`-to-`handle_event` seam, which is that stack's compiler-free boundary and its richest source of affected-but-unchanged code |
| `references/rails-docs.md` | The documentation catalogue, **Rails** — the Rails and gem URL *paths* the page may cite, the per-series overrides, and the two marks that say what a sentence may claim. Data, not lenses: an allowlist, dated and re-verified by `evals/verify-catalogue.sh` |
| `references/elixir-docs.md` | The documentation catalogue, **Elixir** — hexdocs paths pinned per package, the same two marks, and a § *Version* that **withholds every link** until a verification run opens its rows. Currently closed, so an Elixir run anchors with probes and prose |
| `references/page-template.html` | Design system — tokens (light and a dark half of our own), component classes, the SVG vocabulary, the two-layout diagram catalogue, and the page's one small script. Four `SKELETON:` markers divide it: the head and tail ranges are **emitted** into the page by `page-skeleton.sh`, the middle is the markup a run reads |
| `agents/claim-falsifier.md` | The adversarial mandate — what to attack, that every challenge cites a line it opened, and that a claim it failed to break is reported too. At the **plugin root**, not under `skills/`: it is addressed by name, never read |
| `scripts/page-skeleton.sh` | Emits the head, the whole token block and the tint script straight into the page, and prints the markup half with `--markup`. Holds no bytes of its own — `tests/run.sh` proves that by partition |
| `scripts/excerpt.sh` | Generates the collapsed source excerpts, so the quotation is the real bytes |
| `scripts/ledger-rows.sh` | Generates the ledger rows and their deep links, so the gate checks classification rather than typing. `--paths-only` emits the unclassified carrier the brief level's page foot holds |
| `scripts/coverage-gate.sh` | The one mechanical check — set equality between the ledger and the diff |
| `skills/review-map/tests/` | The deterministic tests for those scripts, and the self-test that proves they fire |
| `bin/evals` | One command per eval scenario — `offline`, `section`, `page`, `catalogue`, and the rest in its own header. A dispatcher over `evals/` and `setup-ci/tests/` that owns the paths and the defaults `evals/README.md` argues for and **no rule of its own**; nothing it calls changed to make it work, so old result lines stay comparable. Its `parity` line is what stops its suite table drifting from `validate.yml` |
| `evals/` | Fixtures with planted findings, the frozen upstream, the drivers, the cases, `checks/`, and `profile.sh`, which measures what a run *cost* rather than whether it was right. `checks/` is Ruby; `run.sh`, `report.sh`, `judge.sh`, `verdict-tally.sh` and `profile.sh` stay shell because they are process orchestration and JSON. Not loaded at runtime; see `evals/README.md` |
| `evals/checks/` | One Ruby script per rule family, dispatched by `check.rb`; `self-test.rb` asserts a verdict per row of `self-test-cases.txt`. `reach.rb` grades § 4's composition and `impact-paths.rb` the figure inside it, and neither repeats the other. `lib/review_map/` is their shared library and `lib/test/` its tests; `checks/frozen/` holds every case's exact output for twelve of the thirteen checks — `diagram-shot`'s verdict is a function of the machine rather than of the input — and `frozen.rb` verifies against it. `evals/README.md` § *checks/ is Ruby* has how it got that way, and the four defects the corpus alone could not have found |
| `skills/setup-ci/SKILL.md` | The setup procedure — inspect, decide where it goes, install, report — plus what setup must never touch |
| `skills/setup-ci/references/workflow.md` | Every part of the generated workflow and why it is that way: the triggers, the draft and fork guards, concurrency, permissions, checkout depth, the pin, the credential |
| `skills/setup-ci/references/config.md` | `.accountable-review.yml` — the whole schema, the precedence rule, and why an unknown key is an error |
| `skills/setup-ci/references/delivery.md` | The delivery contract, the providers that exist and the ones only designed for, and why `command` is opt-in in CI |
| `skills/setup-ci/templates/workflow.yml` | The workflow itself. Four substitutions, and nothing else is configurable by design |
| `skills/setup-ci/scripts/` | `inspect-repo.sh` reports, `render-workflow.sh` renders deterministically, `install-workflow.sh` writes idempotently and refuses to clobber, `read-config.sh` is the only thing that knows the config file's shape |
| `skills/setup-ci/tests/` | The deterministic tests, and the self-test that proves they fire |
| `ci/generate-review-map.sh` | The CI adapter: runs `review-map` non-interactively, then checks the three things a person would have noticed by looking at the page |
| `ci/delivery/` | The delivery seam. `deliver.sh` dispatches; a provider is one file that reads `AR_*` and prints `key=value` |
| `README.md` | The public face — why comprehension debt is the problem, what a Review Map is, install, usage, CI setup, and the technical overview. Written for someone deciding whether to use this, so depth past that decision belongs in `docs/` |
| `docs/review-map.md` | The page anatomy for a reader who already wants it: the sections, the detail levels, staging, the review unit, excerpts, the framework anchors, the evidence tiers, and what the skill assumes about a repository. It **restates** `report-format.md` for the public and owns nothing — where the two disagree, the reference wins and this file is the one that is wrong |
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

- **Two page shapes, and one of them is the default.** `--brief` merges §§ 4–7 into one section;
  `--full` writes all seven; `--review` stops. The level is settled in `SKILL.md` step 1 beside the
  target and the link rung, and `report-format.md` § *Detail levels* and § *Section 4 at brief* own
  what it produces — **and own it alone.** Every other file points at them.

  Two rules make the level cheap instead of a second product. **It changes how many sections there
  are, never what a section teaches**: §§ 1–3 are byte-for-byte the same spec at both levels, and a
  run reading a shorter page as licence to explain less has misread the option. And **the merged
  section keeps the anchors**: `id="reach"` on the `<section>`, `id="approving"` on its last `<h3>`,
  the `Affected, not changed` `<dt>` label verbatim, and `<ul>` rather than
  `<ol class="begin">` in the approving part. That is why exactly one check knows the level —
  `evals/checks/before-approving.rb`, for the checkpoint — while `reach.rb`, `impact-paths.rb`,
  `searches.rb` and `page-invariants.rb` read the merged shape unchanged.

  The `Changed` label used to be on that list, and it was wrong twice over. `searches.rb` treats a
  `Changed` `<dt>` only as a scope *reset*, and in the template's order it preceded `Affected`, so it
  never fired — the docs asserted a dependency the code did not have. And the label is gone now
  anyway: § 4 lists no paths at either level.

  That second rule is markup, so it is breakable by accident and invisible when broken: with the
  anchor gone, `before-approving.rb` prints a **SKIP**, which reads as verified.
  `golden/approving-brief-clean.html` plus the `self-test.rb` rows running `reach.rb` and
  `page-invariants.rb` over it exist for the day someone moves one. That fixture carries the
  page-foot coverage disclosure for a related reason: with the inventory out of § 4, a brief golden
  without one gives `page-invariants.rb` § 4 zero `data-path` cells to look at, and it would pass on
  nothing.

  `--brief` is the default, so it is what almost every real page will be. Judge it first.
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

  The stack multiplies with the detail level and the effort exactly as those two multiply with each
  other, and like effort it **produces no section, no field, no tier, no component and no marker.**
  What it changes is the content of sentences, the nodes in a `.pipe` chain, and the command inside a
  `pre.probe`. `report-format.md` § *Detail levels* states this beside the effort paragraph, and
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
  say to search **both directions**, and why `report-format.md` § 2 gives it the second chain the
  serializer-to-type seam gets in Rails.
- **The page never grades the change.** No severity scale, no risk score, no confidence percentage,
  no approval language. Stated as the product principle at the top of `SKILL.md`, repeated in its hard
  rules, and enforced structurally: the template has no chip that expresses a verdict, and
  `page-template.html` says so in its header comment. Reintroducing a severity vocabulary is the
  single easiest way to undo this iteration.

  **A page is allowed to *refuse* a grade out loud, and the check has to know the difference.**
  `page-invariants.rb` § 2 splits its patterns in two for this. Approval language is never right in
  any form; a graded *noun* — risk score, overall risk, severity score — fails only where nothing
  negates it, because § 7's ledger legitimately writes *"attention is a reading estimate, not a risk
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
  explains why a Rails consequence follows; a console probe asks the reviewer's own application; a
  primer callout is what a link escalates into when the reviewer cannot make the decision without the
  rule itself. The
  claim underneath keeps resting on a repo `file:line` at the tier it already carried, which is what
  keeps the five-tier invariant — four files agreeing — untouched. It is also the answer already
  written down for `--review`: where a claim came from is provenance, and provenance is not evidence.

  Two rules carry the link and the probe, and both are the kind that look like diligence when broken.
  **A doc link may only be a row of `references/rails-docs.md`, pinned to the version this app runs**,
  because the run cannot open a URL — no fetch step, and egress to those hosts is commonly blocked —
  so a constructed API path is a 404 the reader finds on the page's behalf, and an unpinned one is
  documentation for a Rails this app may not be running. Both fail while looking correct. See
  § *Pinning, and the two things it does not fix* for why the pin is about checkability rather than
  precision, and for the two marks that stop the page asserting a behaviour that moved. **A probe is
  proposed, never run**, so the page shows a command and never output: a fabricated `=> …` is the most
  concrete-looking thing on the page and the one part of it that is fiction. `report-format.md` § *Framework anchors* owns all of it — the primer included, in § *The primer callout* — plus the routing
  (verify → *Validate*, explain → *Understand*) and the budget, **and owns them alone**; `SKILL.md`
  steps 7 and 9 point at it, the § *Runtime probes* of whichever lens file the stack selected holds the
  probes and the rule for running them safely — `runner`-versus-`console --sandbox` in Rails, and in
  Elixir `mix run -e` plus the fact that there is **no sandbox console at all**, so a write wraps itself
  in `Repo.transaction(fn -> …; Repo.rollback(:probe) end)` — and `evals/checks/rails-anchors.rb`
  derives its allowlist from **both** catalogue files rather than hard-coding hosts. Its name is
  Rails-shaped and its scope is not, deliberately: renaming it would churn six files for no
  behavioural gain.

  **The primer is the third anchor, and it is the one that can undo the other two.** `aside.primer`
  sits between a flow's `.mech` and its `dl.rows`: a header naming the API, a paragraph or two, the
  citation that earned it, the pinned link, and a short `pre.demo`. It is the heaviest component on
  the page carrying no evidence of its own, which is why it has the tightest budget of anything here —
  **one per behaviour flow, and most flows earn none.**

  **It is not Rails-only, and the artwork is an attribution rather than decoration.** The catalogue
  carries gems and client libraries, so `.primer--lib` is the same callout with no mark, no
  trademark line and a neutral rule. Two failures follow from getting that wrong, and neither looks
  wrong on the page: the Rails logotype on a Pundit primer says the Rails Foundation wrote Pundit,
  and the logotype with no `.pr-tm` shows someone's mark without saying whose. Both are checked.
  The logotype is inlined from the official SVG because an external `<img>` is CSP-blocked and the
  run has no fetch step — it is drawn in `currentColor` off `--rails` rather than the brand hex, so
  it stays legible on the dark ground.

  **`.primer--lib` is also the variant Elixir gets, and today Elixir gets no primer at all.** A primer
  cannot exist without the doc link it escalates from, and `elixir-docs.md` § *Version* withholds every
  link in that file — so while the catalogue is closed a Phoenix page carries no `aside.primer`, and
  the flow explains the mechanism in its own prose against a `file:line`. That is not a gap in the
  component, it is two correct rules meeting, and it needs **no exemption in the check**: a linkless
  primer should fail, so the fix is that the skill does not emit one. Four files say so —
  `report-format.md` § *The primer callout*, `elixir-docs.md` § *Version*, `phoenix-liveview.md`'s
  opening pointer, and the template's comment above the assembled block. When the catalogue opens,
  Ecto and Phoenix take the unbranded variant for the reason directly above: the mark names whoever
  wrote the API.

  A consequence worth knowing before editing a check: `class="primer primer--lib"` does not match
  `class="primer"`, so **every primer matcher is a prefix match**. Written the obvious way, each rule
  about primers silently skipped the variant — the failure mode this repository keeps writing down,
  a rule that passes because it never looked.

  Two rules carry it, and each is invisible when broken. **`pre.demo` is not `pre.probe`, and the
  difference is the receiver.** A demo may show a `# =>` line *because* it runs on a class the app
  under review does not have: it quotes the manual, and the manual states results. Name an application
  class there and it is the fabricated-output defect with the rule switched off — which is why
  `rails-anchors.rb` asks the *inverse* of the probe-identifier question (a constant that **does**
  exist in the repo is the failure), and why a `pre.demo` anywhere outside a primer is refused
  outright. Merging the two classes would open a hole through the one rule protecting the most
  concrete-looking fiction the page could carry. **And a primer cites a `file:line` like every other
  doc link** — two paragraphs of framework prose read as self-justifying, so the citation rule
  flattens the whole aside into one block, which stops it both omitting its own citation and borrowing
  the one above it.

  Two things worth knowing before editing. The anchors are **level-independent** — they live in fields
  `--brief` leaves alone, and a primer lives in a flow, which §§ 1–3 render identically at both levels
  — so `rails-anchors.rb` must not read `LEVEL`, and `before-approving.rb` stays the only check that
  knows the level. And the link and the probe are built from **existing** tokens on purpose: `a.doc`
  and `pre.probe` introduce no colour. The primer breaks that, knowingly, for exactly one token:
  `--rails`, declared on bare `:root` and in **both** dark blocks, with `page-invariants.rb` § 6
  counting it by name — because nothing on the page depends on that colour to be readable, so a half
  declaration is invisible until someone opens a primer with the OS in dark mode.

  Two other checks had to be taught about it, and both for the same reason: the primer looks like
  something they already know about. `behaviour-flows.rb` takes its unit census over a **copy with the
  primer removed**, because the callout lands inside a unit region and carries a `class="path"` — kept,
  it would absolve a unit whose grid cites nothing, and `golden/flows-primer-uncited-unit.html` is that
  regression. `diagram.rb` excludes `svg.pr-mark`, because every rule it has is about a figure and the
  first one a 34px brand badge fails is *not inside `.scroller`*. The mark itself is geometric rather
  than the official logo: the run cannot fetch artwork and an external `<img>` is blocked by the
  artifact's CSP, so the trademark line at the foot of the callout is what keeps the stand-in honest.

  The failure mode to watch is not a wrong link. It is a page that links everything, becomes a Rails
  tutorial with a diff attached, and reads as more thorough while getting less navigable — the
  canonical-home regression arriving as citation instead of as repetition. The rule against it is the
  excerpt budget's: an anchor is earned by a decision the reviewer has to make. **The primer is the
  most persuasive way for that regression to return**, because a callout that teaches something true
  looks like care rather than like padding; a script can check that one is placed and cited legally
  and never that the flow needed it, which is what `evals/cases/rails-anchors.json` is for.
- **The review unit** is the page's primitive: seven fields, fixed order, defined in
  `report-format.md` and rendered as a `.mech` block followed by one `dl.rows` — **and rendered
  nowhere else.** A behaviour flow's body *is* a unit; the path, the diagram and the decisions block
  sit beside it inside the flow section, with decisions after the closing `</dl>`. There is no
  endpoint card: the contract is the flow's own material and lives in its `.pipe` and its field rows.
  Two guards keep the unit from becoming ceremony — a unit needs a non-obvious *things to
  understand*, and fields may be omitted but never faked.

  Four files have to agree: `page-template.html` holds one behaviour flow **assembled whole** and
  the `<dt>` labels, `report-format.md` § *The review unit* holds those labels in a column of their
  own plus § 2's split between what the unit carries and what sits beside it,
  `evals/checks/behaviour-flows.rb` checks the `.mech`-per-`dl.rows` pairing and counts field labels
  outside a grid, and `evals/golden/flows-clean.html` is the reference markup.

  Two subtleties the check has to keep. It takes **two extractions, not one**: unit regions anchored
  on `.mech` for the per-unit guards and for naming, and the grids alone for the housing census — a
  flattened flow keeps its `.mech`, so a census over unit regions counts loose fields as housed and
  misreports the defect as something else. And `dl.rows` is **shared** with § 4, which renders
  Changed / Affected-not-changed with the same grid, so the check narrows to `id="flow-"` *before*
  counting; `evals/golden/flows-reach-rows.html` pins that. It replaced
  `flows-endpoint-rows.html`, which pinned the same class of false positive when `.ep-row` was
  shared with `article.endpoint` — the sharing moved, the trap did not go away.

  The reason this is an invariant and not a convention: the template used to show the section
  shell, the unit and the decisions block as three *detached* siblings, with the composition stated
  only in prose. A run read the prose, copied the markup as shown, and flattened all three flows
  into loose field blocks parented to the `<section>` — losing the card, handing field spacing
  to `section > * + *`, un-scoping every `.unit ...` rule, and dropping one flow's *things to
  understand* entirely when a decisions block took its slot. Nothing errored and no check fired.
  **A composition that is described but never shown assembled does not survive a weaker reader** —
  the same reasoning that puts diagram geometry in a catalogue instead of deriving it per run.

  **This is now more fragile, not less.** The unit used to be a bordered card, so a flattened flow
  visibly lost its box. A `.mech` plus a hairline grid is borderless by design: a flow that spills
  its rows into the `<section>` looks very nearly correct, which is why the pairing is checked rather
  than the presence of a wrapper.
- **Affected-but-unchanged code is the product.** Step 5 of `SKILL.md` finds it, the search recipes in
  `rails-nextjs.md` are how, and it surfaces twice, at different depths: the review-unit field inside
  the flow that owns it **explains** it, and § 4 *What this change reaches* shows the whole set at once, pointing
  at that flow in a clause rather than restating it. Code no single flow owns is explained in § 4
  instead — that is what makes it a section rather than an index. The rule that makes the whole thing
  honest: **record what was searched**, so an empty result reads as evidence rather than as omission.

  **The record is collapsed, and splitting it is what keeps that rule from eating the page.**
  `details.searched` is shut by default — the second component on the page a reader has to open — and
  it holds `ul.sr-list`, one row per search, each a command and a result *clause*. The finding stays
  in the open prose: "nothing else reads this column" is a sentence a reviewer meets without clicking,
  and the grep behind it is provenance. Get that split wrong in the other direction and the rule
  inverts — a finding left to be inferred from an empty row inside a shut toggle is hidden, not
  disclosed, which is the excerpt hard rule (`SKILL.md`, now written for *every* collapsed block
  rather than for excerpts alone).

  It was collapsed because open it was the longest thing in § 4 and the first thing a reviewer met,
  and because real pages filled it with paragraph-long re-explanations of entries sitting two inches
  above — § *One canonical home*'s restatement regression arriving disguised as provenance. Hence the
  row format: a `<code>` and a clause makes a verbose one *look* wrong, which prose never did.

  Four files agree: `page-template.html` holds the component and its CSS, `report-format.md` § *What
  was searched* owns the form, the budget and the open/collapsed split **alone**, `SKILL.md` step 5
  points at it, and `evals/checks/searches.rb` re-runs the recorded searches against the repository.
  That check keys on **text nodes beginning with a search tool**, not on the class or the element, so
  it survived this move untouched — but its four `golden/searches-*.html` fixtures did not, and
  migrating them is the actual work. They had already gone stale once when the design system changed,
  and `searches.rb` passed them for as long as they matched nothing on any real page.
- **Completeness, and the one mechanical check. It has no detail level.** Every path in the diff
  appears in the page, at every level, and the gate runs at every level. What the level changes is the
  *carrier*: § 7's classified ledger at `--full`, a shut `details.coverage-foot` below the last
  section at `--brief`, generated either way by `ledger-rows.sh` as `.gt-paths` cells that still carry
  `data-path`. That is the whole reason the carrier is a grid cell rather than a list item —
  `coverage-gate.sh` greps `data-path` page-wide and `page-invariants.rb` § 4 requires it on a
  `div class="c"`, so a `.filelist` would have cost the gate. `--brief` declines to *classify* the
  diff; it never declines to account for it, and a run that skipped the gate for want of a § 7 has
  turned a shorter page into one that may have dropped a file.

  **Neither carrier is § 4 any more, and moving it out cost nothing because the gate never parsed
  HTML.** § 4 used to hold the whole diff too — a `.filelist` at `--full`, `.gt-paths` cells at
  `--brief` — which made it the second ledger its own closing rule forbids, a few sections early. On a
  24-file PR that rendered as 24 links above a caption explaining that the eight worth opening were
  ranked in § 3. `coverage-gate.sh` is a raw-byte page-wide grep, so it cannot tell whether a carrier
  is visible, collapsed, or in a section at all: the whole change is markup and prose, and
  `coverage-gate.sh`, `completeness.rb`, `excerpts.rb` and `ci/generate-review-map.sh` were not
  touched. Collapsing it is legal because an inventory is *provenance*, which passes the reads-complete-when-shut
  rule where a finding never would — so nothing a reviewer acts on may go in there.

  One consequence for the harness, and it is the shape this repository keeps writing down: with the
  inventory out of § 4, a brief golden carrying no `data-path` at all makes `page-invariants.rb` § 4
  pass on zero cells. `golden/approving-brief-clean.html` and the three other brief fixtures carry
  the foot disclosure so that row still has something to look at. Stated
  in `SKILL.md` step 3, explained in `report-format.md` § *The completeness invariant*, and enforced in
  step 10 by `scripts/coverage-gate.sh`. Four files have to agree for that check to work: the script
  reads a `data-path` attribute, the template emits it on the ledger's grid cell
  (`<div class="c" data-path="…">`, not a `<td>` — the ledger is a CSS grid now), `report-format.md`
  § 7 requires it, and `SKILL.md` step 10 runs the script. Break any one and the gate stops
  checking. Note the asymmetry in the invariant itself: the page-wide rule is a subset test (the page
  cites unchanged files everywhere by design), while the gate is exact set equality against
  `git diff --name-only`, compared as whole strings — never substring matching, because `api/Gemfile`
  matches inside `api/Gemfile.lock`.
- **A staged page must never look finished.** The page publishes early and fills in at one URL
  (`SKILL.md` step 9) at both levels — the four milestones are cuts through the procedure, not through
  the section list. What the level moves is where a marker attaches: a section at `--full`, an `<h3>`
  sub-part at `--brief`, where the tail is one section written in pieces and the hazard is its first
  part making the whole thing read as done. Staging is only safe because an unfinished page says so: a build banner while it
  is being written, an explicit *pending* marker for every part that is coming, and both removed at
  the final publish. Four states have to stay distinguishable — written, pending, *not written*
  because the run stopped, and omitted because the diff did not earn it — since the whole risk is a
  reader taking any of the last three for "nothing to say here". A stopped run is the one that needs a
  deliberate edit: pending is a promise, and leaving one behind is worse than publishing late. The form lives in `report-format.md` § *Build state*, the components are
  `.buildstate` and `.pending`, and `evals/check.rb --draft` / `--final` check both ends of it.

  The pending marker earns a second keep, found by profiling rather than by reading: it is the
  **anchor a later stage edits**, which is what keeps staging from costing the whole document per
  stage. A run that instead re-`Write`s the file pays for every already-written section again — one
  did, producing its finished 82 KB page as a single 35,000-token write that re-emitted the staged
  23 KB byte for byte, 56% of everything that run spent streaming. Staging is only cheap if a stage
  writes what is new, so `SKILL.md` step 9 says fill in with `Edit`, never rewrite.

  **The behaviour flow — not § 2 — is the unit of staging**, which is the third granularity a
  `.pending` attaches at. This is what the milestone count moved for: §§ 1–3 and 5–7 have three
  arrivals between them and § 2 has as many as the diff earns flows, so a stage that delivered § 2
  whole would put the longest wait of the run behind one arrival, which is the thing staging exists
  to prevent. It cost no markup — `<section id="flows">` was already just the intro, each flow was
  already its own `<section id="flow-x">`, and the rail already rendered a per-flow marker. What was
  missing was the instruction to use them, and the instruction it replaced was conditional
  (*"if that stretches over many turns"*), which is why every real run delivered the tail in one
  chunk. Consequence for the banner: it counts **parts still pending** rather than *stage N of M*,
  because the total now depends on the flow count and a run would have to commit to it before
  knowing one. Nothing greps the count; `checks/build-state.rb` greps "absence is not a finding",
  which is why that sentence is the one that must survive editing.

  The flow stub is assembled in `page-template.html` beside the pending section, for the reason
  every composition there is: it carries no `.mech` and no `dl.rows`, which is what keeps it out of
  both censuses in `checks/behaviour-flows.rb` — a half-written § 2 must not read as a flattened one.
  `golden/flows-partial-page.html` pins that, and `golden/flows-stubs-only-page.html` pins the one
  narrow `skip` for the moment stage 3 opens and no flow is written yet. That skip takes a pending
  marker as its precondition deliberately: a SKIP reads as verified, so it has to be unreachable on
  a finished page.
- **Effort is orthogonal to the detail level, and invisible on the page.** `--effort high` (the
  default) and `--effort low` decide how hard a run works to be right; the level decides how many
  sections there are. They multiply rather than substitute, and `--brief --effort high` — a short
  page whose claims were attacked — is the combination worth having, which is why it is the one you
  get by default.

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

  The level is not where the budget goes: `--brief` bought 4.6% of wall clock
  for 35% fewer words, because the time is in step 5's consumer tracing rather than in writing
  sections. **Effort decides whether the page is right; the level decides how long it is.** Effort produces **no section, no
  marker, no chip and no sentence**: two pages of the same target at the two efforts differ in their
  claims, never in their shape, and a reader cannot tell which produced the one in front of them.

  Six files have to agree: `SKILL.md` step 1 parses it beside the level and step 8 owns what `high`
  does, `report-format.md` § *Detail levels* states that this file has nothing else to say about it,
  `page-template.html`'s header comment refuses the badge in the same breath as the severity chip,
  `agents/claim-falsifier.md` carries the mandate, `evals/checks/page-invariants.rb` §§ 2b and 2c fail
  a page that advertises having been checked or narrates its own drafting, and `README.md` § *How hard
  it works* is the public wording.

  **The falsifier's `model:` is a fourth thing that has to agree, and it agrees across the harness
  rather than across the page.** `agents/claim-falsifier.md` names it; `evals/run.sh` reads it out of
  that file into the `--agents` JSON, so an eval arm cannot silently measure a different model from
  the one that ships; the value lands on the result line as `falsifier_model` and in `report.sh`'s
  group key, so an opus-falsifier row can never be averaged into a sonnet one; and `profile.sh`
  prints the model the subagent transcripts actually recorded. That last one is the only real check:
  `--agents` accepts keys it does not understand without complaining, so sending the field is not
  proof it was honoured, and the transcript is. Like effort itself, none of this reaches the page —
  no section, no marker, no sentence.

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
  revising its own draft writes the same sentence. `report-format.md` § *Section 4* carries it for
  recorded searches, where it concentrates.

  Two things to know before editing § 2c. It **strips comments first** — `page-template.html`'s own
  header comments are written in precisely this register ("A previous version of this template showed
  the composition as three detached siblings") and ship verbatim inside every published page, so a
  check reading them would fail every page for its template's documentation;
  `golden/invariants-draft-narration.html` puts the trigger phrases in its own header comment so that
  stays true. And the register is right *here* and wrong on the page: this file's rules deliberately
  carry the observation that produced them, which is the habit the page must not inherit. The audience
  is the difference — a maintainer needs to know why a rule exists, a reviewer does not need this
  document's drafting history.

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
- **Seven sections at `--full`, four at `--brief`, and each fact has one home either way.** The format
  is deliberately *not* one section per
  architectural layer. It was, and that guaranteed restatement: one behaviour crosses persistence, the
  API, the boundary and its cohort, so it got described four times, and three further parts existed
  only to restate — findings surfaced in *start here* and re-explained inside a cohort, cross-cutting
  concerns retelling behaviours, a checkpoint quizzing the reader on the paragraph above. A 21-page
  page condensed to 9 with nothing of value removed, which measures the duplication at about half the
  document. So persistence, endpoint contracts and the backend/frontend boundary have **no sections of
  their own** — they are covered inside the behaviour flow they serve, and only what genuinely spans
  flows goes in § 5. `report-format.md` § *One canonical home* carries the routing table and the
  one-sentence reference form; § *Where the old per-layer material goes* maps the old twelve parts onto
  the seven. Reintroducing a per-layer section is how this regression comes back, and it will look like
  an improvement when it does.

  **The merged tail section is a second way for it to come back**, and a subtler one, because merging
  four sections is not the same as merging four *kinds of thing*. At `--brief` the routing table still
  applies with fewer destinations, and the failure to watch for is a section carrying both a flow's
  explanation and the pointer back to it two paragraphs apart — duplication at conversational distance,
  which reads as thoroughness. A section eval cannot see it; `evals.json` case 6 can.
- **The order is the reviewer's path, and the flow owns the explanation.** § 2 *Behaviour flows*
  teaches the mechanisms; § 3 *Start here* is the moment they open the code; § 4 *What this change reaches* is a
  second pass over the same change through one lens. Everything after § 2 therefore **points back**
  at it — a flow never defers an explanation forward, and §§ 3 and 4 never re-explain one. The
  earlier ordering put § 4 and a findings list before the flows, which forced both to
  carry enough mechanism to stand alone, and that was the page's main source of duplication. § 3 is
  **one list**: what most needs judgment and what to read first are the same question, and answering
  it twice is the shape to watch for coming back. Where the attention goes is expressed by what is on
  that list; every other file is accounted for by § 7's attention column.
- **The comprehension checkpoint is capped at five questions**, and each must be answerable from the
  page but **not by copying one sentence out of it**. A question whose verbatim answer sits in a
  paragraph above is restatement wearing a question mark. It lives inside § 6 *Before approving*
  alongside the author questions, validations and test gaps, not as a section of its own — the old
  standalone part overlapped all three.
- **Source excerpts are quotations, and the page reads complete without them.** The third page
  primitive: a collapsed `details.excerpt` holding verbatim code, in two variants — `--diff` for
  changed lines, `--source` for unchanged ones, which is the variant that carries the product because
  no diff view can address an unchanged line. Three things have to stay true together. The page must
  read completely with **every excerpt closed** — an excerpt confirms a claim, never carries one, and
  that is the whole difference between progressive disclosure and hidden content; the hard rule is in
  `SKILL.md`, the form and budget in `report-format.md` § *Source excerpts*, and the shape in
  `page-template.html`. The quotation is **generated by `scripts/excerpt.sh`, never typed** — a
  mistyped ledger row fails the gate loudly, whereas a paraphrased quotation is a false quotation the
  reader cannot catch. And **`data-path` is reserved to ledger rows**: `coverage-gate.sh` greps it
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

  A third thing, added after a run whose flows quoted only unchanged code: the `--diff` excerpt is a
  **floor, not a ration**. Each behaviour flow shows the hunk its behaviour turns on, because § 2 is
  read before the reviewer opens the diff in § 3; the load-bearing test rations everything on top of
  that. The old framing ("a changed line is cheap to follow, the reviewer has the diff open anyway")
  plus a section-wide cap of two is what suppressed it, so the cap now counts per flow inside § 2.
  `evals/checks/behaviour-flows.rb` warns when every excerpt in the flows is `--source`.

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
  constraint, which is exactly what § 5's invariants block reads for — so the rule constrains the tag
  and never the quotation. And **a path the diff touches is never `Unchanged` even where the quoted
  lines are untouched**, because §§ 4 and 7 split changed from affected-not-changed *by file*: one
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
- **Impact paths are § 4's figure, and the edge is the point of them.** A path runs from changed
  code, through the affected-but-unchanged code that gives the change its consequence, to an
  observable behaviour, with every hop past the first carrying its incoming relation as a causal
  verb. 2–5 paths, 3–5 nodes each, one `.ip-out` last, at least one `.ip-aff`, labels never
  sentences, no citations inside the panel.

  **What it replaced is the reason every one of those rules exists.** `.blast` was a four-column box
  grid whose only encoding was border style, so it carried membership of two sets and nothing else —
  and `report-format.md` conceded the gap in prose: *"It cannot show a directed edge … put it in the
  note under the panel, in words."* A figure with a footnote explaining what the figure could not
  draw. Real pages then supplied the missing relation by writing a clause into every box, and the
  panel became a grid of sentences with no edges: the layout arguing with its own content. That
  workaround rule is **deleted**, not inherited.

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

  **The vocabulary includes passive forms deliberately, and `ignored by` is the one to know.** A
  label reads from the node above to the node below, and half the edges here run producer to
  consumer, where the honest verb is *read by*. Without a passive a run inverts the pair to find an
  active verb and quietly reverses the figure. `ignored by` labels the commonest finding the page
  carries — a consumer that does *not* account for what changed — which is causal precisely because
  nothing happens; the box grid could only put that in a clause.

  Six files have to agree: `page-template.html` holds the CSS (head SKELETON range, so it is
  emitted and a run never types geometry) and the panel assembled whole in **both** section blocks,
  `report-format.md` § *Impact paths* owns the component, the vocabulary, the shape rules and the
  budget **alone**, `SKILL.md` step 9 points at it, `evals/checks/impact-paths.rb` carries the rules
  and its `CAUSAL` list, and the five `golden/impact-*.html` fixtures plus their `self-test.rb` rows
  prove each one fires. Extend the vocabulary in the reference and in `CAUSAL` together — the rule
  `diagram.rb` already states for its class vocabulary.

  Verdicts split on purpose. Shape is a FAIL; an unlisted verb and an over-long label are WARNs,
  because a hard failure on vocabulary teaches a run to mislabel an edge to satisfy the check, which
  is worse than an unlisted verb that is true. And the thing no script settles: whether these are the
  right 2–5 paths and whether each edge is **true**. `evals/cases/diagrams.json` is where that is
  asked, and the panel needs eyes — `diagram-shot.rb --visual` renders `<svg>` only, so it does not
  cover a component.

- **Diagram layouts come from the catalogue, not from the run — and only two kinds are drawings.**
  § 4's figure is the `.impact` impact-paths panel and the boundary chain is a `.pipe` spine: both are
  components because their **size is a function of the diff** — 2–5 paths of 3–5 nodes, a chain as
  long as the boundary it crosses — so a drawing would mean geometry derived per run. A component
  reflows on a phone and cannot be drawn wrong. ER fragment and lifecycle stay as inline SVG, worked
  out complete and to scale in `page-template.html`, with the grid stated in a comment above each.

  Four files have to agree: the template holds the geometry and the SVG class vocabulary,
  `report-format.md` § *Depth rules* holds which kind belongs to which section and the budget (and
  holds them **only** — the template does not restate the budget), `SKILL.md` step 9 points at the
  catalogue and says which two are components, and `evals/checks/diagram.rb` carries the class
  vocabulary the template defines. A class added to one and not the other is either unstyled or
  reported as invented. `legend` and `box-json` were removed from that vocabulary deliberately, not
  renamed: a run drawing impact paths as SVG should be told to use the component instead, and
  `impact-paths.rb` fails an `<svg>` found inside the panel from the other side.

  `--brief` draws no § 5 figures at all — no ER fragment, no lifecycle; migration safety is a row
  there — so its merged section holds the `.impact` panel and nothing that could compete for the
  budget, and `diagram.rb`'s per-`<section>` count needs no level awareness. What it must not become is
  a reason to skip the one figure a *flow* earns.

  The reason this is an invariant rather than a nicety: a diagram is the one component with no
  generator behind it, so a layout derived per run spends the run's attention on geometry instead of
  on whether the edges are true — and makes two pages from this skill incomparable. What a script
  can check is conformance; crowding, overlap and an arrowhead landing beside its box need eyes,
  which is what `checks/diagram-shot.rb --visual` and a judged expectation are for. Both defects in
  that sentence were found in diagrams the script had just called clean.

  Two rules no check can enforce, so they live in `report-format.md` § *Depth rules*: a box grid
  cannot express a **directed edge** (when the finding is "the code stops being produced at this
  hop", the note under the panel has to say it), and **a diagram carries labels, not sentences** —
  prose in an 880-wide scroller cannot reflow, so searches and caveats go in the `figcaption`.

  **No current fixture earns either surviving kind.** `rails-only-small` adds one nullable column and
  `monorepo-contract` has no state machine, so `evals/cases/diagrams.json` now tests that a run
  reaches for the *components* rather than SVG. Covering ER and lifecycle properly needs a new
  fixture with a migration and a status enum; until then those two catalogue layouts are checked by
  `diagram.rb` against the template itself and by nothing else.
- **The skeleton is emitted, never typed.** `references/page-template.html` carries four
  `SKELETON:` markers. Everything in the head and tail ranges — the `<head>`, the entire token
  block, the three highlight.js tags and the tint script, 54.5 KB of it — is written straight into
  the page by `scripts/page-skeleton.sh`, once, at the top of stage 1. A run never reads those bytes
  and never types them; what it reads is the markup between the markers, via `--markup`.

  It began as a cost change and that is the least of it. 54.5 KB was resident twice from stage 1
  onward — once as the template read, once as the write's own input — which is 6-8% of a run's cache
  reads, plus ~15k output tokens and about 110s of streaming. **The real payoff is that every colour
  on a published page now comes from a script.** Measured on the template: `--rails` ×3, `--syn-key`
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

  Marker text is load-bearing too. `diagram-shot.rb` reads the template with
  `range(from: /<style/, …)` and `Page#range` re-opens, so a marker containing an opening `style`,
  `script` or `svg` tag would corrupt a check that has nothing to do with this. Each marker is also
  **one line**: extraction is a line range over the marker line, so a marker spilling onto a second
  line would emit half a comment into every page.

- **Theme tokens.** Every colour is defined on bare `:root` *and* redefined in both dark blocks
  (`prefers-color-scheme` and `[data-theme="dark"]`). A colour declared only inside a media query is
  the classic unreadable-artifact bug. `evals/checks/page-invariants.rb` § 6 enforces the three
  states and `excerpts.rb` enforces it for the excerpt tints specifically, which are the newest
  colours and so the likeliest to be forgotten in two of the three.

  `--rails` is the newest of these and `--syn-*` the next newest, and both are easy to half-declare for
  the same reason: nothing on the page depends on either to be readable, so a value missing from the
  dark blocks is invisible until someone opens a primer or an excerpt with the OS in dark mode. Each is
  therefore counted by name — `--rails` in `page-invariants.rb` § 6, `--syn-key` in `excerpts.rb` —
  because the three blocks *existing* is not the same as a colour being in all three.

  Worth knowing when editing: the source design is **light-only**, and the dark half is ours. So the
  pairs that invert — `.checkpoint`, `.att-read`, `.pipe`'s terminal node, `.ip-out` — are written
  against tokens rather than literals precisely so they keep inverting *relative to the page* rather
  than flipping to an unreadable combination in one theme.

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

The skill runs in one context and spawns exactly one kind of agent, the per-flow falsifier. That is a
choice, not an omission — an earlier iteration fanned out to `Explore` agents per layer, and it came
out.

`SKILL.md`'s hard rules now say so outright, which they did not before: a real run reached for one
`Explore` agent and stalled the parent for 997 seconds — 41% of its wall clock — in a single blocked
turn. A boundary stated only here is a boundary the skill has never been told about.

**The one exception is the falsification pass** (`SKILL.md` step 8, and
`agents/claim-falsifier.md`), which since 0.16.0 runs by default. It is worth understanding why it does not reopen what the paragraphs
below closed, because the next thing that wants an exception will look similar and probably is not.

The seam is per **behaviour flow**, which is the seam those paragraphs already name as the right one:
a flow is a whole behaviour, so nothing is fragmented that the page had not already separated, and
there is no synthesis step afterwards to reassemble what a split threw away. The agent is read-only
and returns *challenges*, not page content — the parent still writes every word, and still opens
every cited file before acting on one, so no comprehension moves anywhere.

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

Two things it is not. It is not a licence for step 5 or step 6 to fan out — those still span the
whole diff by nature, and splitting them is still the mistake. And it is not a second context doing
the work: the falsifiers read, the parent writes, and the parent transcript still reads as one
context plus a handful of receipts. That last fact is a trap as well as a reassurance: it is why
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
through the goal, § 4 and five verified affected-but-unchanged findings, and would have
needed several times that budget to finish the behaviour flows and a 112-row ledger. Nothing about it
failed. It simply ran out of room, in a way the procedure has no policy for.

**`--brief` is not the answer to this, and it will be reached for as though it were.** It reduces the
number of sections; the 112-file run did not run out of room writing section shells, it ran out
tracing consumers and explaining flows, and `--brief` changes neither. A strained run at `--brief` owes
the same statement of which region it skimmed.

What makes this hard is that the honest sampling strategy runs against the skill's own instincts:

- **The completeness invariant is not the same as reading everything.** Every path must appear in the
  page; the depth rules already say most appear as a ledger row. So the question is not "which files
  do I cover" but "which files do I *open*", and the ledger is what makes a shallow pass on the rest
  legitimate rather than a silent gap.
- **Cheap signals exist and are unused.** Line counts per file, the status letter, whether a file has
  a matching spec, whether it is named in a commit message, whether anything outside the diff
  references it. `ledger-rows.sh` already prints the first two. A defensible sampling rule could be
  built from them without opening anything.
- **The sections are not equally compressible.** Persistence and the API contract are small and
  load-bearing, and skimping there is what makes a page wrong. Behaviour flows are where the volume
  is, and a flow read at half depth still teaches the shape. So the budget should be spent
  unevenly, and the skill currently gives no basis for that.
- **Whatever is skipped has to be visible.** A skimmed region must say so in place, in the same voice
  as a stated limit, not in a footnote nobody reads. The build states already carry the vocabulary for
  this — a fifth shape alongside written, pending, not written and omitted.

Decomposition may dissolve some of this: a per-flow agent has its own context, so the aggregate
budget grows. It does not dissolve all of it — the orchestrator still has to decide how many flows
are worth an agent, and that is the same question one level up.

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
while doing it.

**`--effort high` has now built half of this**, which is the reason to read the rest of this section
before writing the level rather than after. The routing it needs — an external challenge arriving,
being verified against the file, and landing in the flow that owns it in the page's own voice with no
grade attached — is the mechanism `SKILL.md` step 8 now runs at `high`. What `--review` still has to
solve is where the claims come from and how a *graded* source is stripped, not what to do with one
once it arrives.

**The seam that resolves it, and the reason this level is worth building at all:** a review finding
enters the page as a **claim to verify**, never as a finding to display. Two steps already do that
work. Step 8 says read the file yourself before any claim reaches the page, and drop what does not
survive. Step 5 routes a consequence to the code it reaches. So a verified finding lands in the flow
that owns it — in *things to understand*, or *reviewer questions*, or *affected but unchanged* — in
the page's own voice, with the review's severity label stripped. An unverified one is dropped, by a
rule that already exists. The review pass becomes a *search strategy* feeding step 5, which is
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
- **Findings and flows do not line up one to one.** A review comments per hunk; this page is organised
  per behaviour. A finding spanning two flows, or landing in a file no flow owns, needs the same
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
