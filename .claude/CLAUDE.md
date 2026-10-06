# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

There is no application code here. The repository is the `accountable-review` Claude Code plugin,
with Codex support for `review-map` as a plugin from this repository's own Codex marketplace. It
ships two skills — `skills/review-map/` and `skills/setup-ci/` — plus the one subagent the first of
them spawns (`agents/claim-falsifier.md`, and only at `--effort high`), plus `ci/`, which is neither
a skill nor read by one. `review-map` turns a pull request into a published HTML **review agenda**:
what changed, the judgments the reviewer has to make with the lines that settle each
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
command. It takes a target, an **effort** — `--effort high` (the default, sending an adversarial
pass at the run's own analysis before any of it is written) or `--effort low`, which opts out — and
`--mentor`, off by default, which is the one flag that puts anything on the page. All of it is
parsed in step 1 as prose, because `argument-hint` and `arguments` are not in the Agent Skills
frontmatter allowlist and `claude plugin validate --strict` rejects an unknown key. **There is no
level flag**, and an unrecognised one is reported rather than guessed at. The "source" is prose that
another Claude instance executes, so the unit of quality is instruction clarity, not compilation.

There is no build and no linter, and the **prose** has no test suite: changes to it are verified by
running the skill against a real PR and reading the page it produces.
`claude plugin validate . --strict` checks the manifest, not the prose, which is the part that
matters there.

**The scripts are the exception, in both skills, and the boundary is prose versus software rather
than one skill versus the other.** `setup-ci` produces a YAML file and four shell scripts; `review-map`
has `page-skeleton.sh`, `excerpt.sh`, `ledger-rows.sh` and `coverage-gate.sh`. All of it is ordinary
software with right answers, so it has ordinary tests: `skills/setup-ci/tests/` and
`skills/review-map/tests/`, each a `run.sh` (no model, no network, seconds). `review-map`'s sits
beside a `self-test.sh` that breaks the things `run.sh` claims to check and asserts the suite notices
each one, for the reason `evals/checks/self-test.rb` does: a check that passes because it never
looked is worse than no check. `setup-ci` had one too and it was removed: it re-ran `run.sh` once per
break, 52 of them, about ten minutes a push. `review-map`'s grew the same shape — 53 rows at six and
a half minutes — and was cut rather than removed: **a row earns its `run.sh` pass only where the
sanity row cannot vouch for the assertion** (one expecting zero, a range, an order, or a script's
logic), and each row runs only the section of `run.sh` its mutation can reach. `self-test.sh`'s
header owns that rule. When you edit either template, or any script under
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
prose: 80–160 for *What changed*, 50–140 a checkpoint, and a page total that is those parts summed —
about 700–1,500 visible words at four checkpoints on a small or medium PR, derived rather than flat
so that a wider agenda cannot be forced under its own per-checkpoint floor. `brief-budget.rb` used to enforce its predecessor and is deleted with the level it
belonged to, so the numbers are read by a person or by nobody — except § 01, whose word count
`evals/e2e/run.rb` records on every end-to-end run as guidance, never as a verdict. That is the honest state — the numbers
are a first calibration derived from component caps rather than measured on published pages — but it
means a page drifting long drifts silently. The one number that must never be graded is the
**checkpoint count**: a page that came in under a ceiling by losing a judgment has done the one thing
the budget forbids.

`skills/review-map/evals/` is where judging happens, in three layers. **Mechanical**: `check.rb`
and the ten checks, run on every push. **End to end** (`evals/e2e/`): a whole run of the skill
against a **real merged OSS pull request** pinned in `prs.yml`, generated through
`ci/generate-review-map.sh --output` exactly as CI does, checked mechanically, then graded by one
LLM judge per aspect of the page, anchored in the checkout and blind to the mechanical results.
**Calibration**: a judge counts only once it has matched a person's verdicts on a certified gold
page and on copies of it that each plant one defect. Calibration PRs are held out of the eval set.

**One judge exists, and that is deliberate** — `judges/what-changed.md`, for § 01. The other aspects
(checkpoints, reading path, impact, evidence, voice, recall) are notes in `judges/IDEAS.md`, not
code: one calibrated judge proves the method before the method is copied. The single calibration PR
is `discourse/discourse#43002`, whose gold page was certified by a person on 2026-09-30; the judge
passed calibration against it on Opus on 2026-10-02, which `calibration/status.json` records.

**The old synthetic harness is gone, not deferred** — fixture repositories with planted answers,
hand-driven page cases, and section cases that graded a page this design replaced. None of it was
being used. What it still covered at whole-run level (the trivial refusal, `--update`'s P6 refusal,
the 7.1 override path, a planted recall floor) is listed in `IDEAS.md`; each keeps its mechanical half
in `tests/run.sh`.

`bin/evals offline` is what CI runs and what you run before pushing. `bin/evals e2e`, `calibrate`
and `report` are the rest, run before a major release. Results carry the skill's git sha, so a pass
rate is attributable to a version of the prose, and an uncalibrated judge's column is never shown as
a score.

When the question is where the minutes went rather than whether the page was right,
`evals/profile.sh` reads the transcript of a run — an eval repetition or a real PR — and splits its
wall clock into tool execution, streaming, and the wait before each request produces its first token.
It reads the **subagent** transcripts under `<session>/subagents/` too, so the falsification pass is
counted rather than invisible.

**Two rankings, and they invert.** The lever for **wall clock** is fewer requests, because only about
2.5s per request is fixed and context costs almost nothing in time. The lever for **cost** is context,
because it is billed once per request and cache reads are roughly 70% of the bill — so *when* a file
is loaded matters as much as whether. Neither sentence is retired by the other: they are different
questions about the same requests, `profile.sh` prints a table for each, and the two are read side by
side and never one instead of the other.

It infers nothing the transcript does not carry: publish stages are mechanical, the ten steps are
**not** — `ledger-rows.sh` fires at minute four and again at minute thirteen — and steps 4, 6 and 8
leave no trace at all, so they get no row. The numbers live in `evals/README.md` § *Profiling one run*,
which is the only place they are maintained; read it before quoting one, and `SKILL.md` step 6c for
what the falsification pass costs and why that is two numbers.

Read `evals/README.md` before adding a PR or a judge.
## How the documents divide the work

Each reference owns one axis; keep them from bleeding into each other.

| File | Owns |
|---|---|
| `SKILL.md` | The procedure — ten ordered steps from resolving the target to publishing, step 7 being the synthesis that turns analysis into an agenda — plus the product principle and the hard rules |
| `references/report-format.md` | Page structure — the five sections and what triggers each, **the review checkpoint** and the coding-decision kind of it, **chains** and the rule that decides which figure a chain is, **the three topology figures** and the order a shape is chosen in, the evidence tiers, **mentor mode and the primer callout**, source excerpts, impact paths, the canonical-home rule, the agenda budget and the deep-link ladder |
| `references/rails-nextjs.md` | Domain knowledge, **Rails** — what a senior reviewer of that stack looks for, per layer, plus § *Coding decisions*, the runtime probes and the search recipes for affected-but-unchanged code. Its three client-side sections are stack-independent, and the Phoenix file points at them rather than restating them |
| `references/phoenix-liveview.md` | Domain knowledge, **Phoenix/LiveView** — the same three parts for the other stack. Its centre of gravity is § *LiveView*: the `phx-*`-to-`handle_event` seam, which is that stack's compiler-free boundary and its richest source of affected-but-unchanged code |
| `references/rails-docs.md` | The documentation catalogue, **Rails** — the Rails and gem URL *paths* the page may cite, the per-series overrides, and the two marks that say what a sentence may claim. Data, not lenses: an allowlist, dated and re-verified by `evals/verify-catalogue.sh` |
| `references/elixir-docs.md` | The documentation catalogue, **Elixir** — hexdocs paths pinned per package, the same two marks, and a § *Version* that **withholds every link** until a verification run opens its rows. Currently closed, so an Elixir run anchors with probes and prose |
| `references/page-template.html` | Design system — tokens (light and a dark half of our own), component classes, the assembled checkpoint, the chain, one of each topology figure and the impact panel, and the page's one small script. **No `<svg>` anywhere.** Four `SKELETON:` markers divide it: the head and tail ranges are **emitted** into the page by `page-skeleton.sh`, the middle is the markup a run reads |
| `references/claim-falsifier.md` | The shared adversarial mandate, read by an independent reader in either host — what to attack in one **analysis note**, that every challenge cites a line it opened, and that a claim it failed to break is reported too |
| `references/hosts/` | Host-specific delivery and delegation: Claude Artifact or local HTML everywhere else (`generic.md` is the reference for every non-Claude host, Codex and Pi the primary examples), named Claude agent (a general-purpose one when `npx skills add` installed the skill without the plugin, so `agents/` never arrived) or Codex subagent tools |
| `agents/claim-falsifier.md` | The Claude agent wrapper — tools and model. At the **plugin root**, not under `skills/`: it is addressed by name, never read, and its parent supplies the absolute path to the shared mandate |
| `scripts/page-skeleton.sh` | Emits the head, the whole token block and the tint script straight into the page, and prints the markup half with `--markup`. Holds no bytes of its own — `tests/run.sh` proves that by partition |
| `scripts/diff-render.sh` | Says per path whether GitHub will render that file's diff, which is what decides the URL form for a line inside it. GitHub's documented thresholds as constants, `.gitattributes` through `git check-attr`, and one dated name heuristic |
| `scripts/excerpt.sh` | Generates the collapsed source excerpts, so the quotation is the real bytes |
| `scripts/ledger-rows.sh` | Generates the evidence foot's inventory cells and their deep links, so the gate checks the page rather than someone's typing. `--paths-only` is the only mode the page uses |
| `scripts/coverage-gate.sh` | The one mechanical check — set equality between the inventory and the diff |
| `scripts/carry-plan.sh` | The re-run decision — the delta since the previous map, the preconditions that refuse one, and per checkpoint whether it may be carried. Mechanical because by eye every checkpoint looks carryable |
| `skills/review-map/tests/` | The deterministic tests for those scripts, and the self-test that proves they fire. `diff-render.sh`'s rows build their own two-commit repository, because its answer is a function of git rather than of a fixture. `frontmatter.rb` puts every skill's and agent's frontmatter through a strict YAML parser, because `claude plugin validate --strict` passed an unquoted `: ` that Pi's loader rejects without a word |
| `skills/review-map/tests/codex-plugin.rb` | The Codex manifest and catalogue against Claude's manifest — same name and version, `review-map` the only skill shipped, the catalogue's one entry pointing at this repository — and seven mutations of its own inputs that it must catch |
| `bin/evals` | One command per eval scenario — `offline`, `e2e`, `calibrate`, `report`, `catalogue`, and the rest in its own header. A dispatcher over `evals/` and `setup-ci/tests/` that owns the paths and the defaults `evals/README.md` argues for and **no rule of its own**; nothing it calls changed to make it work, so old result lines stay comparable. Its `parity` line is what stops its suite table drifting from `validate.yml` |
| `evals/` | `checks/`, `golden/`, `e2e/` and `profile.sh`, which measures what a run *cost* rather than whether it was right. Not loaded at runtime; see `evals/README.md` |
| `evals/e2e/` | The end-to-end harness, in Ruby. `prs.yml` pins real merged OSS pull requests with a `calibration` or `eval` role; `run.rb` generates through `ci/generate-review-map.sh --output`, checks, judges and profiles; `judges/` holds one working judge and `IDEAS.md`; `calibration/` holds the gold page, the one-defect patches, the labels and `status.json`, which is what makes a judge's column a measurement; `report.rb` writes the HTML report and, with `--history`, the one committed summary per release |
| `evals/checks/` | One Ruby script per rule family, dispatched by `check.rb`; `self-test.rb` asserts a verdict per row of `self-test-cases.txt`. Ten of them: fifteen became nine when six graded markup the agenda does not have — two of those six would have SKIPped forever, which is worse than none because a SKIP reads as verified — and `figures.rb` is the tenth. `impact-paths.rb` grades `figure.impact` and nothing else, so a checkpoint's `figure.chain` — same markup, different job — is invisible to it by scope rather than by an exemption; `figures.rb` grades the checkpoint's figures, that chain among them. `link-form.rb` grades the href against the citation it sits on — the span, the sha256 fragment, and the routing away from a diff GitHub withholds — and is the check whose rule is a relation between the page and a repository, which is what `golden/links-repo.sh` and `lib/review_map/fixture.rb` are for. `lib/review_map/` is their shared library and `lib/test/` its tests. `checks/frozen/` holds every case's exact output for all ten, and `frozen.rb` verifies against it. `evals/README.md` § *checks/ is Ruby* has how it got that way, and the four defects the corpus alone could not have found |
| `skills/setup-ci/SKILL.md` | The setup procedure — inspect, decide where it goes, install, report — plus what setup must never touch |
| `skills/setup-ci/references/workflow.md` | Every part of the generated workflow and why it is that way: the triggers, the draft and fork guards, concurrency, permissions, checkout depth, the pin, the credential |
| `skills/setup-ci/references/config.md` | `.accountable-review.yml` — the whole schema, the precedence rule, and why an unknown key is an error |
| `skills/setup-ci/references/delivery.md` | The delivery contract, the providers that exist and the ones only designed for, and why `command` is opt-in in CI |
| `skills/setup-ci/templates/workflow.yml` | The workflow itself. Version substitutions, the four when-decisions behind `SETUP:IF:` blocks, and nothing else configurable by design |
| `skills/setup-ci/scripts/` | `inspect-repo.sh` reports, `render-workflow.sh` renders deterministically and resolves the `SETUP:` blocks, `install-workflow.sh` writes idempotently, refuses to clobber, and recovers the when-decisions from the file it is about to replace, `read-config.sh` is the only thing that knows the config file's shape |
| `skills/setup-ci/tests/` | The deterministic tests, and the self-test that proves they fire |
| `ci/generate-review-map.sh` | The CI adapter: runs `review-map` non-interactively, then checks the three things a person would have noticed by looking at the page. It passes no level — there is one page, and a page-shape argument is an unknown argument here rather than a silent no-op |
| `ci/map-still-current.sh` | The second range — does the map we already have still describe this head? Composes `application-code.sh` over the delta with `carry-plan.sh` over the restored page, and adds no rule of its own |
| `ci/application-code.sh` | The scope gate, in two rules: does this diff change application code at all, and is what it changes more than trivial? Both counted over application paths only, the trivial thresholds joined by **and**, and it fails open, so an unrecognised path is code |
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

- **One page shape, and no flag chooses it.** No argument names a length, a depth or a second
  document, anywhere in the plugin: not on the skill's command line, not on
  `ci/generate-review-map.sh`, and not as a key in `.accountable-review.yml`. `SKILL.md` step 1
  settles it beside the target and the link rung, and `report-format.md` § *One page shape* states
  the consequence for the format. **`--mentor` adds a component and does not choose a shape** — the
  bullet below it owns that distinction and the subtraction rule that holds it.

  **The load-bearing half is that a page-shape argument is unknown rather than tolerated.** A flag
  or a config key taken silently and mapped onto this page is a name that quietly changed meaning,
  and the reader has nothing on the page to tell them which they got — so the skill reports it, the
  CI adapter exits 2 on it, and `read-config.sh` falls through to its unknown-key rule. That is one
  rule in three places rather than three aliases, and `setup-ci/tests/run.sh` pins the last two.

  **What the narrowing replaced is worth knowing, because the pressure to reintroduce it will come
  back as generosity.** There were two shapes, a short one merging four sections into one and
  carrying a word budget to keep it short, and a long one writing all seven. Two products, only one
  of which anyone developed against, and a reader choosing between them was choosing a length rather
  than a document. What a reviewer wants is not a length setting: it is an answer to *what do I have
  to judge here, and where do I look?* A future full mode is the same agenda with depth beneath it —
  `report-format.md` § *A future full mode* records the four components this page put down and the
  rules they had — never a second document reached by a flag.

  **The agenda budget survived the level that carried it, and lost its check.** `report-format.md`
  § *The agenda budget* is prose: per-part caps and a page total that is those parts summed, which
  at four checkpoints on a small or medium PR comes to 700–1,500 visible words; plus a floor stated
  as a rule rather than a number. `brief-budget.rb` enforced its predecessor and is
  deleted, so nothing gates words now; the end-to-end harness records § 01's count and nothing else. Two of its lessons are kept in that section deliberately.
  Length is guidance rather than a failure, because a hard failure on length teaches a run to drop a
  claim to get under a number, which is worse than the long page. And **the checkpoint count is never
  budgeted**: a page that came in under the ceiling by losing a judgment has done the one thing the
  budget forbids.

  **The rail is emitted, not edited down.** `page-skeleton.sh --markup` hands a run the whole markup
  half, seven `data-rail` entries: four numbered sections and three checkpoint sub-entries. That used
  to be filtered per level by `SKELETON:ONLY:level=` markers and a validator that failed closed, all
  of which is deleted with the level. What replaced the filter is nothing, which is the right amount
  of machinery for a page with one shape: `tests/run.sh` counts the entries, and the sanity row of
  `self-test.sh` is what proves that count looked.
- **`--mentor` is the only flag that puts anything on the page, and subtraction is what keeps it from
  being a level.** It admits one component — the primer callout, `aside.primer`, the third framework
  anchor — inside the checkpoints that earn one, for a reviewer new to the *stack* rather than to the
  change. **Delete every primer from a mentor page and what remains is the page the same run would
  have written without the flag.** Nothing else moves: same sections, same checkpoints in the same
  ranked order, same reading path, same panel, same foot, same budget on every other part.

  **That subtraction is the whole distance from a second document reached by a flag**, and it is the
  sentence to keep. Such a flag names a *different document*, with nothing on the page to tell a
  reader which one they were holding; a mentor page differs by components a reader can see.
  Which is also why it takes **no badge** — the effect announces itself, and a count of primers would
  be the page grading its own thoroughness. `page-template.html` refuses it beside the severity chip,
  the verification badge and the stack badge, because that fourth refusal has the best excuse of the
  four and would otherwise come back alone.

  **Its header names the stack, not the component** — *Understanding Ruby on Rails*, not
  *Rails | Primer* — because a reader can see what kind of block it is and cannot see what it is
  about to teach them, and its frame is Rails red on `--primer-*`. A logotype is still refused:
  there is no `<svg>` on this page, `rails-anchors.rb` fails a primer carrying `pr-mark`, `pr-tm` or
  one, and the near-black display serif of the header is the ceiling.

  **A primer holds its checkpoint's one doc link rather than adding a second**, so the anchor budget
  is relocated and never raised: mentor buys explanation, never citations. It is also **gated** on
  that link, which is what makes a closed catalogue mean no primers for that stack — Phoenix gets the
  ordinary page today, and one verification run lifts it.

  Three things about it look like generosity and are not. **A run that earns no primer writes none**,
  because manufacturing a lesson to honour a flag is how this becomes a framework manual with a diff
  attached. **A stack name is checked, never obeyed** — `--mentor rails` in a `mix.exs` repository
  stops the run, since an override would reintroduce a Rails lens over something that is not Rails.
  And the one exception to *never invent output* lives here, with its whole safety in the receiver:
  `pre.demo` may show a result line only because it quotes the manual on a class this repository does
  not have, so a demo goes nowhere but inside a primer and a probe never inside one.

  Ten files and a fixture set have to agree. `report-format.md` § *Mentor mode* owns every rule
  **alone**, with § *One page shape*, § *The review checkpoint*'s slot, § *Framework anchors*' third
  row and § *The agenda budget*'s separate count pointing at it; `SKILL.md` parses it at step 1,
  checks the stack name and the catalogue at step 2, earns one at step 7g, writes it at step 9 and
  carries the demo exception in its hard rules; `page-template.html` holds the CSS in the head range
  and the callout assembled inside checkpoint A; `evals/checks/rails-anchors.rb` § 8 grades it on the
  **comment-stripped** copy, behind eight `golden/anchors-primer-*` fixtures and `anchors-demo-loose`;
  `tests/run.sh` asserts the template assembles exactly one and `tests/self-test.sh` breaks it three
  ways; and the CI half is `ci/generate-review-map.sh`, `read-config.sh`, `references/config.md` and
  `setup-ci/tests/`, where **off is the absence of the flag** rather than `--mentor off`, because the
  skill parses no such value.

  **It has no eval axis, and that is the honest gap.** An axis is a column on every result line, and
  adding one for a feature with no case behind it makes old lines incomparable in exchange for
  nothing measured. The mechanical half is covered; whether a primer was worth spending a callout on
  is judged, and no judge asks it yet — `evals/e2e/judges/IDEAS.md` is where it would go.
- **The review checkpoint is the page's primitive.** Three to five of them under *What needs your
  attention* **per independent semantic delta *What changed* names**, seven on the page at the
  outside, each **one judgment** the reviewer has to make: an `<h3>` question, two to four
  sentences, an optional `figure.chain`, a `ul.lookat` of one to four entries — each a short title,
  a clause and its deep-linked citation, in that order — an optional `div.gap` labelled *GAP*, and
  an optional `p.open` labelled *Open question*. Both labels are fixed, and for one reason: an
  absence and an unresolved question are the two places a severity word gets in. `report-format.md`
  § *The review checkpoint* owns all of it and owns it **alone**; `page-template.html` assembles one
  with every optional part, one without, and a pending stub.

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

  **The count scales on the delta, never on the diff.** Three to five per independent semantic delta
  *What changed* names, seven on the page at the outside — so eighty files of one rename is still
  three to five, and only a PR shipping genuinely independent changes earns a sixth. **What replaced
  a flat ceiling of five is the observation that the ceiling contradicted a hard rule**: a sixth
  judgment had to go to a clause or to the evidence foot, and the foot is where
  promotion-by-omission forbids a judgment to live. Five files agree — `report-format.md` § *The
  review checkpoint* owns it alone and § *Section 3* owns the routing that bounds it, `SKILL.md`
  step 7e and § *How big should the page be?* carry it into the procedure, and `start-here.rb` warns
  on a checkpoint no stop points at. Nothing grades the count; `rails-anchors.rb` pins its
  per-checkpoint denominators at five so a wider agenda cannot quietly loosen the anchor budget.

  **Ordering is not grading, and the distance between them is one word.** The checkpoints are ranked by
  what a reviewer would most regret misunderstanding. A number beside a question, a *high* in a title,
  a first checkpoint described as the important one — each of those is a severity scale, and each will
  arrive as helpfulness. The one line that names an unresolved thing is `p.open`, labelled *Open
  question* and nothing else; `page-invariants.rb` warns on a bare `Watch` or `Blocking` label for
  exactly this reason, and that rule outlived the component it was written for.

  Nothing mechanical grades a checkpoint. `start-here.rb` requires the reading path to point at one,
  `rails-anchors.rb` counts them as the denominator for its doc-link budget, and `tests/run.sh` asserts
  the template assembles three. Whether a question is a judgment is a judged expectation, and it is
  the first candidate in `evals/e2e/judges/IDEAS.md` — no working judge asks it yet.
- **Two kinds of checkpoint, and the second one is ranked behind the first.** A **behavioural** checkpoint judges what
  the system now does. A **coding-decision** checkpoint judges how the change was built — where a class
  was put, what kind of object it is, which existing abstraction it went around. They render
  identically and nothing on the page says which is which.

  **The rule is name the departure, and cite it from one of two sources.** The form is *the PR chose
  X; Y is the settled answer for the same job; is X deliberate?* The `Y` is either **this repository's
  decision** — a line in its convention doc, else a sibling file or populated directory, as a *Look at*
  entry — or **a stack convention on the lens file's closed list**, cited through its catalogue row as
  the checkpoint's one doc link. **The repository outranks the stack**: a codebase that settled on the
  PR's choice has no departure, whatever the manual says. **No citation from either, no question.**
  The list is closed and documented so that the second source is the same bar one level up rather
  than the run's sense of good Rails; it exists only where the catalogue is open, so Phoenix is
  repo-only until `elixir-docs.md` is verified. A preference stated with nothing to cite is the page
  grading the author's taste.

  **No fixed count; the citation is the cap.** One per departure, each with its own citation,
  merged first when two share a precedent; they **never displace a behavioural judgment** and never
  push the page past seven — outside the per-delta three to five, inside the ceiling; ranked last. The
  exception is a refactor, where they may be the only judgments the diff carries and then they are the
  page. A departure with nothing to cite is written nowhere — an observation about shape with no home
  is noise, not a finding.

  **It was one per page, and that was the wrong cap.** The worry was a style review arriving as
  thoroughness, but the citation bar already prevents that — a page can only ask as many as the
  codebase has settled answers for — and a flat one threw away the second real departure on a PR
  that had two, which is a judgment a reviewer who knows the codebase would have asked.

  It exists because the page was **behavioural by construction and that is only half of reviewing**.
  The run that produced it saw the fact and had nowhere to take it: a Review Map called a class "a small
  presentation model", put it first on the reading path, and never asked why a class like that was in
  `app/models` when the app had an `app/services`. One sentence had blocked it — step 7a's *"in
  behavioural terms"*.

  **It was repo-only, and that was the wrong bar.** Two sources was a maintainer's call: a team's
  written decision is the strongest `Y`, and where a repository has written nothing, the conventions
  Rails itself documents still hold. What keeps the second from becoming taste is that the run may not
  extend the list — adding a row means adding its catalogue row through `verify-catalogue.sh`.

  Six files agree: `SKILL.md` step 2 collects the directory inventory and steps 7a, 7b, 7d and 7e spend
  it; `report-format.md` § *Coding decisions* owns the bar and the caps **alone** and § *Where
  checkpoints come from* lists it last; both lens files carry the shapes and the searches that produce
  the citation, and `rails-nextjs.md` the closed stack list; `README.md` and `docs/review-map.md` are the public wording. Nothing mechanical checks
  any of it — like the category test, whether a departure was real and whether the page asked rather
  than answered are judged, and `evals/e2e/judges/IDEAS.md` records the judge that would ask them.
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

  **Both figures carry a locator on every code node**, and § *Chains* owns that rule because both do:
  an `a.path.ip-loc`, last inside `.ip-box`, `{{DIFF}}` on `.ip-chg` and `{{BLOB}}` on `.ip-aff` and
  `.ip-step`, and **never on `.ip-out`**, which is a behaviour rather than a file. It carries no
  `data-path` — `coverage-gate.sh` greps that attribute page-wide, so a locator using one would
  register as a surplus path and fail the page's one mechanical gate.

  **This inverted a rule, and which half inverted is the part to keep.** § *Chains* used to say no
  `file:line` sits inside a figure at all, and `impact-paths.rb` failed a page for any `a.path` in the
  panel. That rule was written against a panel whose nodes had their labels *replaced* by file names,
  so the figure said where to look and never what was there — and it ended that defect by banning the
  reader's only way of locating a node along with it. Every node named a symbol, and which of four
  hundred files that symbol lived in was the question the figure most reliably raised. So the address
  is back on a line of its own, and what stays forbidden is the narrower thing that was actually
  wrong: a citation standing **in for** the label or the clause. What did not move is the canonical
  home of the *clause* — that is still the affected list beneath the panel, and a locator is not a
  second one. `golden/impact-prose-nodes.html` pins the surviving half and now carries a correct
  locator on the very node whose label is a path, so it fails for one reason rather than two.
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
- **Three of the deleted shapes came back as components, and the shape is chosen before it is
  drawn.** `figure.converge` (several paths that must keep one invariant), `figure.lifecycle` (states
  and the actions between them) and `figure.structure` (an entity and its relationships) sit in a
  checkpoint's figure slot beside `figure.chain`, **one figure per checkpoint of any kind**, built
  from the same `.ip-*` boxes and locators. The guard fork is still not drawable and still goes to
  prose. Step 7f asks the shape questions in a fixed order — converge first, chain last — writes the
  answer into `agenda.md`, and step 9 types the figure from that block only. **Zero figures is a valid
  result and the count is never graded**; a page with more diagrams is not a better page.

  **The converge is the one to understand, because it is the first checkpoint figure allowed to hold
  `.ip-aff`, and the direction of the edge is what makes that safe.** An impact path flows *out* of
  the change to a consequence; a converge's paths flow *in*, from writers, to an invariant — so an
  unchanged writer that skips the callback the others run is drawn there, never also as an impact
  card, with a *Look at* entry carrying the clause a node cannot. And its list **claims to be
  complete**, which is why it is earned only by a recorded writer search: it looks most finished
  exactly when it is most wrong. The same recorded search is what `carry-plan.sh`'s P6 replays, so
  `--update` refuses rather than carrying a converge a new writer has falsified.

  **`.cv-note` is a third free-text slot a severity word can enter**, after `GAP` and *Open question*,
  and the only one without a fixed label. It says what a path skips, never how much that matters.

  Seven files agree: `report-format.md` § *Topology figures* owns the shapes, the gates and the caps
  **alone**, and § *Chains*, § *The review checkpoint*, § *One canonical home* and § *What was
  searched* point at it; `SKILL.md` step 7f selects and step 9 builds; `page-template.html` holds the
  CSS (head range, including the one print rule — an `.ip-out` fill prints white-on-white otherwise)
  and assembles one each in checkpoints C to E; both lens files say which signal earns which shape;
  `claim-falsifier.md` attacks a writer list for the path it missed; `evals/checks/figures.rb` grades
  shape and locators, the first check to read a page's `figure.chain`; and `tests/run.sh` asserts the
  template. `CAUSAL` moved to `checks/lib/review_map/vocabulary.rb` because two checks now read it, and
  `lib/test/test_page.rb` fails when it and § *Impact paths*'s list disagree.
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

  **A resolved tick is how the verdict arrives next, and `--update` is the door it comes through.**
  When a re-run finds that new commits answered a checkpoint, the tempting thing is to strike it
  through or label it *resolved* — showing the reviewer what has been addressed. A page with three
  of five questions ticked is a page reporting progress toward approval, which is the one output
  this format exists to withhold. The checkpoint is deleted instead, with its reading-path stop and
  its rail entry, and nothing marks where it was.

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
  explains why a framework consequence follows; a console probe asks the reviewer's own application;
  a primer states the rule outright, at `--mentor` only. The claim underneath keeps resting on a repo
  `file:line` at the tier it already carried, which is what keeps the five-tier invariant untouched
  in all three cases. It is also the answer already written down for an imported review finding:
  where a claim came from is provenance, and provenance is not evidence.

  Two rules carry the first two, and both are the kind that look like diligence when broken. **A doc link may
  only be a row of the stack's catalogue, pinned to the version this app runs**, because the run
  cannot open a URL — no fetch step, and egress to those hosts is commonly blocked — so a constructed
  API path is a 404 the reader finds on the page's behalf, and an unpinned one documents a Rails this
  app may not be running. **A probe is proposed, never run**, so the page shows a command and never
  output: a fabricated `=> …` is the most concrete-looking thing on the page and the one part of it
  that is fiction. See § *The catalogue is the one thing a run cannot verify* for why the pin is about
  checkability rather than precision.

  The third anchor is `--mentor`'s and § *Mentor mode* owns it; the only thing it changes here is
  that a primer **holds** its checkpoint's one doc link rather than adding a second, so the budget
  below is relocated and never raised.

  `report-format.md` § *Framework anchors* owns the rest **alone** — the routing, the budget, the
  earning test, answerability, and the label's three segments; `SKILL.md` steps 7g and 9 point at it;
  the § *Runtime probes* of whichever lens the stack selected holds the probes and the rule for
  running them safely; and `evals/checks/rails-anchors.rb` derives its allowlist from **both**
  catalogue files rather than hard-coding hosts — its name is Rails-shaped and its scope is not,
  deliberately, since renaming it would churn several files for no behavioural gain.

  **The failure mode is not a wrong link.** It is a page that links everything, becomes a Rails
  tutorial with a diff attached, and reads as more thorough while getting less navigable — the
  canonical-home regression arriving as citation instead of as repetition. An anchor is earned by a
  decision the reviewer has to make, and a script can check that a link is real and legally placed,
  never that the judgment needed it.
- **The synthesis phase is where the agenda comes from, and it is a step of its own for a reason.**
  `SKILL.md` step 7 takes the analysis notes and produces the page's argument: name the semantic
  delta, identify the human judgments, merge the observations that share one, rank by consequence if
  misunderstood, select the agenda, choose each one's representation, select its evidence, build
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
  `data-path` page-wide and `page-invariants.rb` § 4 counts it on a `div class="c"` or the retired
  `<td>`, so a `.filelist` would have cost the gate.

  **The classification went and the accounting stayed.** The page used to carry a ledger with three
  judgements per row: which section covers the file, how much attention it needs, and which group it
  belongs to. Where a reviewer's attention goes is now said by what is on the reading path and in what
  order, and saying it again in a column beside every file was a second ranking competing with the
  first. `ledger-rows.sh` still emits the four-cell form without `--paths-only`; nothing calls it, and
  `report-format.md` § *A future full mode* is where it is written down.

  **The carrier is not section 04, and the gate never noticed it move.** *Impact outside the diff*
  used to hold the whole diff too, which made it the second inventory its own closing rule forbids.
  On a 24-file PR that rendered as 24 links above a caption explaining that the eight worth opening
  were ranked elsewhere. `coverage-gate.sh` is a raw-byte page-wide grep, so it cannot tell whether
  a carrier is visible, collapsed, or in a section at all — which is why that change cost no script.
  Collapsing it is legal because an inventory is *provenance*, which passes the
  reads-complete-when-shut rule where a finding never would. Collapsed is not optional and neither
  is the gate: a run that skipped it because the list is out of sight has turned a shorter page into
  one that may have dropped a file.

  **Nothing narrows this, and `--update` is the first thing that could have.** An update re-reads
  only the commits since the previous map, so it is narrowed almost everywhere — and the inventory
  and the gate are exempt, in full, over the whole `BASE...HEAD` range. An update changes which
  claims were re-read; it changes nothing about which paths must be accounted for. The failure to
  watch for is not a skipped gate but a patched inventory: a run that adds the delta's rows to the
  existing `div.gt.gt-paths` instead of regenerating the block has started typing in the one cell
  `ledger-rows.sh` exists to keep untyped, and the gate passes either way.

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

  **The `id` on `<section class="cp">` now serves two jobs, and the second one is why it is
  unique rather than merely tidy**: it is the anchor a later *stage* edits, and the anchor a later
  *run* edits under `--update`. One mechanism, two distances — minutes apart within a run, days
  apart across pushes — which is why an update needed no new markup at all.

  The never-re-`Write` observation below has a read-side twin that `--update` makes reachable:
  **never re-*read* the page either.** An 80 KB page is about 25,000 tokens to read, the same order
  as the rewrite this rule exists to stop, and an update that reads it whole has spent the saving
  before it starts. Grep an index of ids and citations, then `Read` with `offset`/`limit`.

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

  **That makes section 04 the last thing to publish rather than the first, and the ordering is a
  dependency rather than a preference.** Every impact card's `p.ip-why` ends in a pointer at the
  checkpoint that judges it, so there is no `#cp-x` to point at until the agenda's stubs have landed.
  It published after step 5 for two versions, which bought a card that either carried a dead fragment
  or invented one, and spent the arrival before 7c could merge two crossings into one judgment.
  `SKILL.md` step 9's milestone table orders it and step 5 says outright that it no longer publishes;
  `report-format.md` § *Impact paths* owns the pointer that forces it.

  **And the checkpoint stub is worth more than the flow stub it replaced**, which is the part to keep.
  A flow stub said what the flow would cover. A checkpoint stub carries **the question** — so stage 2
  opens by publishing what the change is asking the reviewer to judge, ten minutes before any
  explanation exists. That is most of what a reader came for, arriving first.

  Consequence for the banner: it counts **parts still pending** rather than *stage N of M*, because the
  total depends on how many checkpoints the diff earns and a run would have to commit to it before
  knowing one. Nothing greps the count; `checks/build-state.rb` greps "absence is not a finding", which
  is why that sentence is the one that must survive editing.
- **Effort decides whether the page is right, and it is invisible on the page.** `--effort high` (the
  default since 0.16.0) and `--effort low` decide how hard a run works to be right. Nothing else
  varies: two pages of the same target at the two efforts differ in their claims and never in their
  form. Effort produces **no section, no marker, no chip and no sentence**, and a reader cannot tell
  which one produced the page in front of them, deliberately.

  **The seam is ahead of the page, which is the design fact worth stating.** Step 6 writes one
  analysis note per flow, sends one falsifier at each, and step 7 synthesises while they read; step 8
  folds the challenges in before a checkpoint's stub is replaced. Under the old order a flow was
  published at stage 3 and corrected afterwards, so **it was wrong while it was public** — a cost
  that no longer has to be paid. What remains is the late challenge arriving after a checkpoint has
  landed, and the rule for that is the one it always was: a claim retracted before the final publish
  beats one that is never retracted. § *Deliberately single-context* says why the pass is the one
  exception and what it costs; `SKILL.md` step 6c holds the numbers — do not restate them here.

  Six files have to agree: `SKILL.md` step 1 parses it, step 6c owns what `high` does and step 8 what
  happens to the result; `report-format.md` § *One page shape* states that the format has nothing to
  say about it; `page-template.html`'s header comment refuses the badge in the same breath as the
  severity chip; `agents/claim-falsifier.md` carries the mandate and pins its own `model:`;
  `evals/checks/page-invariants.rb` §§ 2b and 2c fail a page that advertises having been checked or
  narrates its own drafting; and `README.md` § *How hard it works* is the public wording. The
  falsifier's model is checked across the **harness** rather than the page: `evals/e2e/run.rb`
  generates with the plugin loaded, so the agent file's own `model:` is what a run gets, and
  `profile.sh` prints what the subagent transcripts actually recorded. That is the only real check —
  a pinned field is not proof it was honoured.

  **A verification badge is the same regression as a severity chip, and it will look more innocent.**
  Grading the PR is obviously forbidden; grading *the page* — "every claim verified", a count of what
  the pass corrected, a `.verified` chip — reads as transparency while asserting exactly the assurance
  the format exists to withhold.

  **But the badge is not how the leak actually arrives. This is:** *"the mistake the first version of
  this section made"*. A correction annotated with the history that produced it — the falsification
  pass, narrated, without ever naming it. It slips every rule above because it reads as candour rather
  than as advertising, and one real `--effort high` page carried **ten** of them while the three pages
  beside it carried none. Every one had a true and useful fact inside it. So the rule is *keep the
  fact, drop the autobiography* — `SKILL.md` step 8's **correction replaces, never annotates**, which
  is a general-effort rule, because a normal run revising its own draft writes the same sentence.
  The register is right *in this file* and wrong on the page: a maintainer needs to know why a rule
  exists, a reviewer does not need the page's drafting history.

  On a result line the skill's effort is `effort` and the producing model is `model`, and both are
  in `report.rb`'s group key, so a `high` row is never averaged into a `low` one.
- **`--update` buys cheapness with claims nobody re-read, and the page says which revision it
  describes rather than how much of it was re-read.** A re-run reads the commits since the previous
  map, re-analyses what they reach and edits that page in place. The saving is almost entirely step
  5; the price is that a carried claim was not re-verified.

  **The page is the state.** Every claim carries a `file:line`, every excerpt `data-src`, the
  masthead the revision — so there is no sidecar and no new attribute. `$W/analysis/` is used when
  present and never required: it survives on a laptop and never on a CI runner, and a design that
  needed it would be two designs.

  **It is the third kind of flag, and the taxonomy is what stops it becoming a level.** `--effort` is
  invisible because both efforts describe one revision; `--mentor` is visible and safe by
  subtraction; `--update` must be visible because parts of its page describe an earlier head. So it
  puts one fixed sentence on the page and an `updated from <sha>` masthead segment, and both say
  **which revision the content describes, never how hard the run worked**. A *resolved* tick or a
  *new/carried* chip is the severity scale back, and an answered checkpoint is deleted instead.

  **Carrying is about not re-tracing, not about freezing the agenda.** Step 7 re-ranks the whole
  agenda on every update; an update that appended its new checkpoints would turn a ranked agenda
  into a changelog. **Which checkpoints carry is a script, because by eye every one looks
  carryable**: `carry-plan.sh`, six preconditions joined by AND, failing to a *full* run. Its P6 is
  the one that protects the product — the dangerous delta is a new consumer in a file no checkpoint
  cites, so the page's recorded searches are replayed.

  **Every way it can go wrong must lead to the page that has no cost** — a cache miss, a missing
  `rg`, a refused precondition all regenerate in full. In CI the carrier is `actions/cache`, never
  the previous artifact, because downloading that would make the workflow a second thing that knows
  where the map goes.

  Owners, each **alone** for its part: `scripts/carry-plan.sh` (preconditions, carry rule);
  `SKILL.md` § *Re-running over new commits* (procedure; steps 1, 9, 10 and two hard rules point at
  it); `report-format.md` § *Build state* § *An updated page* (the wording and the refusals);
  `setup-ci/references/workflow.md` § *The previous map* (the cache, ripgrep, why not the artifact).
  Also agreeing: `report-format.md` §§ *Section 1* (masthead segment, merge-base), *One page shape*,
  *The review checkpoint* (delete, never tick) and *Source excerpts* (never carried across its
  file's delta); `page-template.html` (refuses the carry badge); `read-config.sh`'s `update` key and
  `references/config.md`; `ci/generate-review-map.sh` (conditional pass-through, manifest `@3`);
  `templates/workflow.yml`'s two cache steps; `setup-ci/tests/run.sh`.
  Graded by `page-invariants.rb` §§ 2b, 2c and 2e (the last unconditional: no recency marker on any page) and
  `build-state.rb --updated` (the disclosure, once), behind three `golden/invariants-update-*`
  fixtures — `-clean` must stay green, because a rule that fails a page for admitting its limits
  gets the admission removed. `tests/run.sh` covers each precondition either side of its boundary
  and may record no `rg` search (its comment says why); the whole-run eval waits on a `prs.yml`
  entry with `update_from` (`evals/e2e/judges/IDEAS.md`).
- **Findings are a sample, not an audit — and the page no longer says so.** The rule is unchanged and
  load-bearing rather than hedging: the skill explains, explanation is reproducible, defect discovery
  is not, and the page must never read as a clean bill of health. What moved is where the sentence
  lives. A standing caveat under *What needs your attention* is true of every Review Map rather than
  of this one, so a reader meets it once per map and starts skipping the line under the heading —
  which is the first checkpoint. It is stated once for the tool in `README.md` § *What a Review Map
  cannot do*, where someone deciding whether to trust these pages reads it, and never on the page.

  **The removal is a sentence, never the prohibition beside it.** The page still asserts no coverage:
  no *no issues found*, no summary saying the diff was covered, nothing that reads as assurance.
  Removing the hedge while leaving the overclaim reachable is how this becomes a page that sounds
  certain, and it is the direction to watch.

  Seven files agree: `SKILL.md`'s hard rules own the prohibition and the redirect, `report-format.md`
  § *The review checkpoint* records what the caveat was and why it went while § *Section 2* and the
  section table carry the consequence, `page-template.html` refuses it in a comment where the line
  used to be, `README.md` and `docs/review-map.md` are the public wording, and the mechanical half
  inverted with it — `start-here.rb` used to require the sentence page-wide and now checks nothing
  about it, while `page-invariants.rb` § 2d warns when one comes back. That § 2d sits beside § 2b
  deliberately: one catches the page overclaiming its coverage, the other the page hedging it, and
  a rule written for either is blind to the other.
- **Deep-link mode is chosen once**, in step 1, from the four-rung ladder in `report-format.md` —
  driven by whether the head SHA is reachable on a remote. Unpushed branches are the common case, and
  the correct behaviour there is plain text, not a permalink that 404s. **A git that cannot answer is
  not the same as unpushed**: three states, not two, and the middle one refuses.

  The rung decides whether anything is clickable. It does **not** decide the form, and the form is
  not a taste: a line inside the diff links to the diff page, because that is the page the reviewer
  is working in and a blob at head shows the new line with no trace of what it replaced. A line
  outside the diff links to a blob at the commit that line exists at — head for unchanged code, the
  diff's left side for code the change removed. Neither form is the fallback; *affected but unchanged*
  is the page's product and no diff view can address it. **A citation that names a range links a
  range**, in either form, both ends on the same side.

  **One exception, and it is a verdict rather than a judgement.** GitHub withholds some diffs behind
  *Load diff*, so those citations take the blob form and the excerpt beside them becomes the `--diff`
  variant. Two things make that cheap: the size rule is not the whole rule — one changed line in a
  generated `db/structure.sql` is small by every measurement and GitHub withholds it anyway, which is
  the case a threshold alone waves through and the one a Rails page actually cites — and being wrong
  is asymmetric, since a blob link where the diff would have rendered still lands on the line and only
  loses the red and the green. So the verdict leans towards the anchor.

  Five files have to agree: `report-format.md` § *When the diff will not render* owns the rule
  **alone** and § *Deep links* carries the three URL forms and the ladder; `SKILL.md` step 3 runs the
  classifier once and step 9 points at both; `scripts/diff-render.sh` holds the verdict, its
  constants and its dated lockfile heuristic; `tests/run.sh` covers every signal it reads; and
  `evals/checks/link-form.rb` re-asks that same script rather than keeping a second copy of the
  thresholds — which is why `golden/links-repo.sh` is the one golden fixture that has to be a real git
  repository, so that a rule which could only ever SKIP does not reach `self-test-cases.txt`.

  **A template carrying an unformed value teaches a run to publish one.** Two real runs published 73
  ranged citations under one-line anchors *after* the range form landed in § *Deep links*, because
  every citation in the template rendered as `href="{{LINK}}"` — one opaque placeholder over the one
  link whose form is load-bearing. The template now spells the anchor out at every line-bearing
  citation, with `{{DIFF}}` and `{{BLOB}}` defined once before any citation appears and `{{LINK}}`
  surviving only where a citation names no line. This is the doc-link pinning precedent applied to the
  other link, and it was missed for the same reason.

  **Where a link lands is a separate rule from what it addresses, and it is applied rather than
  typed.** Every link that leaves the page carries `target="_blank"` and `rel="noopener noreferrer"`,
  set on load by the tail script `page-skeleton.sh` emits — because a citation is followed from the
  middle of an unfinished agenda, and replacing the page costs the reader their place in it. The
  page's own links are exempt, tested as *same document, differing only by fragment* rather than by
  class, so the rail and the Checkpoint pointers stay put and anything added later is covered. It is
  the tint's precedent, for the tint's reason: an attribute a run types at every citation is an
  attribute missing from one of them. Five files agree — `page-template.html` holds the pass and the
  markup comment saying not to type one, `report-format.md` § *Every off-page link opens in a new
  tab* owns the rule, `SKILL.md` step 9 forbids the attribute beside the colour and the `<script>`,
  and `tests/run.sh` asserts the pair (the rule in the tail, zero `target=` in the markup half) with
  a `self-test.sh` row behind the zero.

  And the guard this repository has now paid for three times, which `diff-render.sh` carries in its
  refs handling: **asked and unable to answer is not an empty diff.** A `git diff` feeding a pipeline
  leaves the exit status at 0 and prints no rows, which reads as *no file is withheld* — the most
  reassuring thing it can say and the one with the least behind it. `excerpts.rb`'s state-tag rule
  shipped with exactly that bug, and `page-invariants.rb` § 5 with its sibling.
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
- **The order is the reviewer's path, and the checkpoint owns the explanation.** *What needs your
  attention* teaches the judgments; *Read the code in this order* is the moment they open the code;
  *Impact outside the diff* is the same change seen through one lens. Everything after the attention
  section therefore **points back** at it — a checkpoint never defers an explanation forward, and the
  reading path and the impact panel never re-explain one. The reading path is **one list**: what most
  needs judgment and what to read first are the
  same question, and answering it twice is the shape to watch for coming back. Where the attention
  goes is expressed by what is on that list and in what order; every other file is accounted for in
  the evidence foot, unranked.

  **Those pointers have exactly two names, and a flow is not one of them.** *Checkpoint A* and
  *Impact path A* are the reader's designators; the flows step 6 clusters are the run's own unit of
  **analysis**, named in `$W/analysis/` and nowhere on the page. A checkpoint reading *"a
  leader-opened thread (Flow A) has no `connection_id`"* has pointed at a section nobody wrote.

  **It leaks because the three labels share one alphabet** — the note is A, the checkpoint id is
  `cp-a`, the impact path is A — so nothing local tells a run which one is its own, and one real
  page mixed both namespaces inside a single paragraph. Four files agree: `report-format.md`
  § *One canonical home* owns the rule **alone** and carries the reference form in the letter
  form, `SKILL.md` step 6 states it where the labels are minted, `page-invariants.rb` § 7 greps
  the comment-stripped copy for it, and `golden/invariants-flow-designator.html` plants it beside
  a correct *Impact path A* so the fixture fails for the collision rather than for the token.

  **The section sign is the same leak from a different source.** These documents used to call the
  page's sections *§ 01* to *§ 05*, and a run writes in the voice it reads, so a page said *"today
  only § 01's"* — a pointer with three readings and no target. They now name a section by its title
  and keep `§` for their own headings. The page never writes `§` outside a
  `<code>` span or an excerpt: a section of the page by its linked title, a repository heading in
  words with its file cited. Same four files, same owner; `page-invariants.rb` § 8 is the check,
  behind `golden/invariants-section-sign.html` and the `-quoted` fixture that keeps its exemptions
  honest.
- **Source excerpts are quotations, and the page reads complete without them.** A page primitive: a
  collapsed `details.excerpt` holding verbatim code, in two variants — `--diff` for changed lines,
  `--source` for unchanged ones, which is the variant that carries the product because no diff view
  can address an unchanged line. Four things have to stay true together.

  The page must read completely with **every excerpt closed** — an excerpt confirms a claim, never
  carries one, and that is the whole difference between progressive disclosure and hidden content.
  The rule is judged **field by field**: a citation elsewhere on the page does not rescue a field
  whose only `file:line` sits inside the collapsed block, and `check.rb` cannot see that. An excerpt
  sits **beside the claim or the *Look at* entry it confirms**, never in the evidence foot, which is
  provenance a reader is not expected to open. The quotation is **generated by `scripts/excerpt.sh`,
  never typed** — a mistyped ledger row fails the gate loudly, whereas a paraphrased quotation is a
  false quotation the reader cannot catch. And **`data-path` is reserved to inventory cells**:
  `coverage-gate.sh` greps it page-wide, so an excerpt using one would register as a surplus path and
  fail the page on its best content. Excerpts carry `data-src`.

  **The tint is applied, never authored**, and the state tag is computed, never copied — the two
  places a quotation can lie about itself while the bytes stay verbatim. `--at` requires `--base` and
  derives the tag from the diff, because hard-coding `Unchanged` published a false label on a changed
  file and the block read as *more* trustworthy the closer you looked. Four files agree on each:
  `scripts/excerpt.sh` computes them, `report-format.md` §§ *Source excerpts* and *Syntax tint* own
  the rules and the closed tag vocabulary **alone**, `page-template.html` holds the `--syn-*` tokens
  and the tinting script, and `evals/checks/excerpts.rb` fails a page shipping `hljs-` classes in its
  markup or a tag the diff contradicts. Adding a language to `guess_lang` without its `<script src>`
  in the template tints nothing, silently.

  Two things are easy to get backwards. **Quoting a changed file at head is right, not the defect** —
  a hunk of an 18,000-line `structure.sql` cannot show that a table has *no* `CHECK` constraint,
  which is exactly what an invariant checkpoint reads for — so the rule constrains the tag and never
  the quotation. And the budget's test is that a citation is **load-bearing for a decision the
  reviewer must make**; "one per field that earns one" is circular, because *affected but unchanged*
  is by definition claims a reader would take on faith, so every such field earns one automatically
  and the cap bounds nothing. The budget, the permitted locations and the rung adjustment live in
  `report-format.md` **only** — an earlier version restated the cap here in slightly different words
  and the two drifted apart within one run.

  Watch for pages whose excerpts are all `--source`. A per-flow `--diff` floor used to prevent that
  and went with the flows; seeing the hunk is very often what a judgment turns on, and nothing warns
  when it is missing any more.
- **Impact paths are section 04's figure, and the edge is the point of them.** A path runs from changed
  code, through the affected-but-unchanged code that gives the change its consequence, to an
  observable behaviour, every hop past the first carrying its incoming relation as a causal verb.
  1–3 paths, 3–5 nodes each, one path per `.ip-card`, at least one `.ip-aff`, one `.ip-out` last, and
  one `p.ip-why` per card.

  Six files have to agree: `page-template.html` holds the CSS (head SKELETON range, so a run never
  types geometry) and the panel assembled whole, and its comments own the lane crossing —
  `--ip-drop`, the elbow, the dotted divider — because that is where the declarations are;
  `report-format.md` § *Impact paths* owns the panel's rules, its budget and `p.ip-why` **alone**,
  while § *Chains* owns what it shares with a checkpoint's `figure.chain`, including the locator;
  `SKILL.md` step 7i decides both and step 9 points at them; `evals/checks/impact-paths.rb` carries
  the rules and its `CAUSAL` list — **extend the vocabulary there and in the reference together**;
  and the fourteen `golden/impact-*.html` fixtures prove each rule fires.
  `evals/checks/link-form.rb` is the sixth, since widening its `CITATION` pattern to compound classes
  is what gives every `a.path.ip-loc` locator that check's span, fragment and routing rules for free.

  Two ways this erodes, both arriving as an improvement. **Loosening the cap back past 3** turns the
  figure into a section to scroll, and it will arrive as thoroughness — a consequence that no longer
  fits keeps its entry in the affected list and its explanation in the checkpoint, which is
  § *One canonical home* doing its job. And **a `p.ip-why` that walks the hops** is the `.blast`
  footnote returning in a component that cannot have one: the figure supplying its edges in prose
  because prose is easier to write than a true edge. It orients and points; the checkpoint owns the
  explanation. Shape is a FAIL and vocabulary a WARN, because a hard failure on a verb teaches a run
  to mislabel a true edge.

  What no script settles: whether these are the right 2–3 paths and whether each edge is **true**.
  The tighter cap makes that sharper, not softer — choosing three consequences out of six is part of
  the work — and the § 04 judge in `evals/e2e/judges/IDEAS.md` is where it would be asked.
- **The skeleton is emitted, never typed.** `references/page-template.html` carries four `SKELETON:`
  markers. Everything in the head and tail ranges — the `<head>`, the entire token block, the three
  highlight.js tags and the tint script, 54.5 KB of it — is written straight into the page by
  `scripts/page-skeleton.sh`, once, at the top of stage 1. A run never reads those bytes and never
  types them; what it reads is the markup between the markers, via `--markup`, which takes no flag.

  It began as a cost change and that is the least of it. **The payoff is that every colour on a
  published page now comes from a script** — all of them in the head range, none in the markup half —
  so the half-declared-token defect that § *Theme tokens* below and `excerpts.rb` exist to catch is
  not merely checked, it is unreachable.

  Four files agree: the template holds the markers and the bytes, `page-skeleton.sh` extracts them,
  `SKILL.md` step 9 calls it once and forbids writing a `<style>`, a `:root`, a colour or a `<script>`
  into the page, and `tests/run.sh` proves the script holds no bytes of its own. That last one is the
  load-bearing part, and it is a **partition** test rather than a comparison: strip the markers and
  the preamble, and head + markup + tail must be the template byte for byte. Extracting with awk and
  comparing against the script's own awk would test the script against itself and pass for any
  consistent pair of bugs, which is why two of `self-test.sh`'s cases mutate the *script*.

  Two constraints on the marker text itself, neither of them obvious from the script. A marker must
  hold no opening `style`, `script` or `svg` tag, because `Page#range` re-opens on its own `from`
  pattern and would corrupt any check scanning for one; and each marker is **one line**, because
  extraction is a line range over it and a marker spilling onto a second would emit half a comment
  into every page.

  **Two things must not appear in the markup half at all, and `tests/run.sh` counts both at zero**:
  an `<svg` opening tag, because this page has no drawings, and a literal tint class, because the tint
  is applied at read time and a hand-coloured quotation is a quotation someone edited. That is why the
  template's excerpt comment describes that class rather than spelling it — the rule and the prose
  about the rule would otherwise be the same bytes.
- **Theme tokens.** Every colour is defined on bare `:root` *and* redefined in both dark blocks
  (`prefers-color-scheme` and `[data-theme="dark"]`). A colour declared only inside a media query is
  the classic unreadable-artifact bug. `evals/checks/page-invariants.rb` § 6 enforces the three
  states and `excerpts.rb` enforces it for the excerpt tints specifically, which are the newest
  colours and so the likeliest to be forgotten in two of the three.

  The `--syn-*` tints are the ones easiest to half-declare: nothing on the page depends on them to be
  readable, so a value missing from the dark blocks is invisible until someone opens an excerpt with
  the OS in dark mode. They are therefore counted **by name** — `--syn-key` in `excerpts.rb`,
  `--syn-key`, `--ex-add` and `--primer-ink` in `tests/run.sh` — because the three blocks *existing*
  is not the same as a colour being in all three. `--rails` was counted the same way in
  `page-invariants.rb` § 6 and is gone; the counting idiom is what outlived it, and `--primer-*` is
  what it now guards — a red brought back for the primer's frame, never for the logotype the old
  token was spent on.

  Worth knowing when editing: the source design is **light-only**, and the dark half is ours. So the
  one pair that inverts — `.ip-out`, the filled node that ends a chain — is written against tokens
  rather than literals precisely so it keeps inverting *relative to the page* rather than flipping to
  an unreadable combination in one theme.

- **Four semantic colour families, a fifth ramp that means nothing, one ramp shape, and a rule about
  what each is allowed to mean.** `--nav-*` (slate 252), `--gap-*` (ochre 72), `--unchanged-*`
  (teal 200), `--prov-*` (plum 318) and `--primer-*` (red 28) each carry the same five slots — `bg`,
  `bg-2`, `rule`, `rule-2`, `ink` — at fixed lightness and chroma per slot, so no two can drift apart
  in weight, and the dark half is the light ramp reflected rather than a second hand-picked set. All
  of it is in `page-template.html`'s token block, which is in the head `SKELETON:` range and
  therefore **emitted by `page-skeleton.sh`**: a run never types a colour.

  **The rule is the system, not the ramp.** Slate means *you can click it* and may appear on nothing
  else. Ochre means *something is missing and the page is saying so* — `p.open`, the inferred tier,
  the build banner — and never a severity. Teal means *this code is not in the diff*: the
  `from unchanged code` tier, the dashed `.ip-aff` node and its legend key, the *Affected, not
  changed* lists. Plum means *how a thing is known*: the excerpt `.tag`, `details.searched`, the
  evidence foot, the probe label. Green and red inside an excerpt stay what they were — added and
  removed lines, there and nowhere else — and are still the reason no fifth semantic *meaning* gets a
  hue.

  **`--primer-*` is the exception, and it is safe because it is not a meaning.** It frames
  `aside.primer` and reaches nothing else: Rails red, so a reviewer new to the stack recognises the
  block written for them before reading a word of it. It passes teal's test in the strongest form
  available — it is attached to no claim at all, since what it frames is a quotation of the manual —
  and the ramp is named for its component rather than for a meaning precisely so it has nowhere to
  spread. **Red on anything the page asserts about the change is the severity chip arriving as a
  palette**, and that is the direction to watch. One open question is recorded rather than guessed at:
  Rails is the only stack that earns a primer today, because `elixir-docs.md` withholds every link
  and a primer is gated on one, so if that catalogue opens the answer is a variant class on the aside
  — never a colour a run types, and never the branded/unbranded split already deleted once.
  `tests/run.sh` counts `--primer-ink` by name in all three theme states, and `report-format.md`
  § *Mentor mode* owns the page-level rule.

  **Teal is the one that had to be argued, and the argument is why it is safe on this page.** The
  changed/unchanged distinction is the most load-bearing one the page draws and it was carried by a
  dash alone: two near-identical greys in the impact panel's two lanes. A hue is the obvious fix and
  the obvious objection is that a page with no severity vocabulary should not start colour-coding
  claims. It does not: *not in the diff* is a fact about the repository rather than a judgment of the
  change, so it cannot be read as a verdict — which is exactly the test any future hue has to pass.
  Plum passes it for the same reason, being provenance rather than meaning. A hue for *risk*, for
  *confidence*, or for *how hard the run looked* fails it, and is the severity chip arriving as a
  palette.

  **Two off-system hex values went, and that is the cheap half.** `--accent-line` and `--select` were
  a link underline and a selection fill picked by hand in both themes — four values maintained apart
  from everything else, doing what two slots of the slate ramp already do. `--syn-key` moved from hue
  315 to 318 so the syntax tint's keyword colour is the provenance hue rather than a fifth position
  nobody chose.

  **`page-invariants.rb` § 3 had to widen, and the bug it had is the shape this repository keeps
  finding.** It matched `class="tier"` against a closing quote, so the two tiers that now carry a
  family modifier counted as zero labels — and a checkpoint resting entirely on code outside the diff
  would have been told it was presenting inference as fact. A rule that passes is not a rule that
  looked. `golden/invariants-tier-modifier-only.html` pins it, and deliberately does **not** quote the
  attribute in its own header comment: § 3 reads raw bytes rather than a comment-stripped copy, so a
  fixture describing its own defect would pass for the wrong reason.

  One more thing moved with the teal. `.ev-list` was scoped `.evidence .ev-list`, and that list
  appears **twice** — beside the impact panel in section 04 and again in the foot — so the section-04
  copy had no rules at all. Unscoping it is what lets both carry the teal rule, and it is a bug the
  palette found rather than one the palette caused.
- **A published example is regenerated, never edited, and it names the version that produced it.**
  `examples/` holds two real runs against public pull requests, served at
  `wyeworks.github.io/accountable-review` by `.github/workflows/pages.yml`, which uploads that
  directory and nothing else. Public repositories are the requirement rather than a preference: a
  map whose every citation 404s for the reader is not an example of anything.

  **The failure is silent and it is staleness.** The page format moves, and nothing about a page
  rendering a two-release-old shape says so — so the version is recorded rather than implied, and a
  format change means running the skill again, not patching the HTML. A hand-tuned example shows
  what someone could write instead of what the skill does, which is the one thing an example may
  not do. Four files carry the version and have to agree: `examples/README.md` owns the provenance
  and the regeneration recipe **alone**, `examples/index.html`'s foot and `README.md`
  § *Example Review Map* restate it, and `CONTRIBUTING.md`'s layout lists the directory.

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

  **The seam is also what decided how a re-run finds the previous map.** Downloading the last
  artifact is the obvious carrier and was refused for this bullet's reason: the workflow would
  become a second thing that knows the map is an artifact, and a team on a static host would find
  their re-runs silently rebuilding from scratch. A cache keyed on the pull request is a side
  channel that knows nothing about the destination. `references/workflow.md` § *The previous map*
  owns that argument.

  **The failure mode is a destination threaded back into generation** — an `--artifact-name` on
  `generate-review-map.sh`, an "upload the map" step inside the skill — and it will arrive as a
  convenience. If a new provider seems to need a change in `review-map` or in
  `generate-review-map.sh`, the seam is in the wrong place; move the seam.

  A subtlety worth keeping: `github-artifact` does **not** move bytes. Uploading from a step script
  means reimplementing the Actions artifact protocol, so it names the destination and the workflow's
  standard upload step does the transfer. That split is fine — generation still cannot tell which
  happened — but it is why the provider emits `artifact_name` and `retention_days` as extra keys, and
  why extras are carried through to `$GITHUB_OUTPUT` at all.
- **Two rules decide whether CI generates a Review Map, and both are measured over application
  paths only.** `ci/application-code.sh`, from a `scope` step every later step is guarded on. Rule 1:
  does the diff change application code at all. Rule 2: is it more than trivial — skipped when
  application files ≤ `trivial_files` **and** application lines ≤ `trivial_lines` (2 and 20), read
  from `.accountable-review.yml` at run time and never rendered into the YAML.

  **AND, and the polarity is what will get edited.** From the generating side it reads as an OR,
  which invites a "simplification". A needless map costs a model run somebody ignores; a missing one
  is invisible — so the suppressing predicate is the one that must be hard to satisfy. **Application
  paths only is why this cannot be a job `if:`**: the payload's counts are whole-diff and it has no
  file list. The gate **fails open**, and a skip says which rule fired and the counts behind it.

  **The same question is asked again over `<previous head>..<head>`**, by `ci/map-still-current.sh`,
  because with a map per push `BASE...HEAD` cannot see that *this* push changed no application code.
  It adds no rule — `application-code.sh` over the delta, `carry-plan.sh` over the restored page —
  and downgrades the scope step's own verdict, so no guard moved. **Only `no-application-code`
  counts, never `trivial`**, and **it stands the job down rather than rewriting the page**: a script
  refreshing model-authored HTML risks a stale number on a page that looks current.

  Eight files agree: `ci/application-code.sh` holds both rules; `ci/map-still-current.sh` the
  composition **alone**; `read-config.sh` and `references/config.md` the two keys;
  `templates/workflow.yml` the `scope` step and the guards; `references/workflow.md` § *The
  application-code gate* owns the reasoning **alone** — polarity, payload, fail-open, the default's
  trade, the second range; `SKILL.md`'s hard rules forbid counting anything but application code or
  baking a number into the YAML; `tests/run.sh` covers each threshold either side (`bulky`, `spread`,
  `masked`) and both halves of the second question; `docs/ci.md` restates it.
  either side of each threshold and both halves of the second question, and `docs/ci.md` restates it.
- **The CI page and a person's page are the same page.** `--output <dir>` changes where the bytes
  land and nothing else: same sections, same depth rules, same excerpt budget, same completeness
  gate. `SKILL.md` step 1 owns the flag, step 9 says the stages become save points rather than
  publishes, step 10 says there is nothing to publish at the end.

  **A cheaper CI page is the regression to watch**, and it will look like thrift — skip the excerpts
  nobody will open, skip the flows on a big diff, skip the gate because there is no reader. Take any
  of those and there are two products, only one of which is developed against, and the one the team
  actually reads in CI is the one nobody looks at while editing the prose. There is one answer to
  "how much page", at both levels of watching, and `--output` is not a second one.
- **A Review Map names its revision, on the page.** Two short SHAs in the masthead's `Revision`
  cell, head → base, beside the branch names. Three files agree: `report-format.md` § *Section 1*
  states the rule, `page-template.html` carries the cell, and `ci/generate-review-map.sh` refuses to
  deliver a page that does not contain the head's short SHA.

  It is not CI-specific and must not become so. A branch name goes stale the moment someone pushes,
  and a page that describes an earlier revision while looking current is the one failure a reader
  cannot detect from the inside — which is exactly what regenerating per push creates, several pages
  that differ only by revision.
- **The workflow is a design with exactly one settings axis, and the axis is *when*.** The draft
  guard, the fork guard, the concurrency group and `contents: read` still have no knobs, because a
  knob on each is a way to end up generating Review Maps for draft pull requests or handing this job
  write access — which is the thing the setup exists to prevent. Everything a team configures **about
  the map** is still read from `.accountable-review.yml` at **run** time, so changing it never means
  regenerating the file; that split is what makes "the workflow respects `retention_days: 14`" true
  without a second setup run, and why `tests/run.sh` checks retention through `deliver.sh` rather
  than by grepping YAML.

  What is rendered from flags is the decisions about **when a Review Map is generated** — the push
  trigger and the bot authors — plus **whether the link is commented on the pull request**. None can
  be run-time settings: the first two *are* the triggers and the guard, and the third decides what
  permission the job holds.

  **The test is whether the decision can be made *before* the job exists**, not whether it decides
  that a run happens. How big a change has to be decides exactly that and is still run-time
  configuration, because what it counts is application paths and the payload is whole-diff: 0.28.0
  put it on the `if:`, where it could only measure the wrong thing. § *The application-code gate*
  owns where it went and what happened to its four flags. `SKILL.md` step 3 confirms them in
  one block before writing, and § *What it configures* splits its table along that line.

  **The defaults are the answers a real team reached by hand**, in two pull requests against a
  generated workflow (fayron#633 and #634): `opened` in, `synchronize` out so a pull request gets one
  map, dependabot skipped, and small changes skipped — that last one now measured over application
  code by the gate above rather than over the whole diff here. A team editing the
  generated file to reach the same place, and then living with a permanent drift report, is the
  evidence that these were defaults rather than preferences.

  **The knobs are only safe because of the read-back**, and that is the half to keep. The rendered
  file carries a `# Decisions:` line holding the canonical, complete flag form of all of them;
  `install-workflow.sh` recovers it and passes it ahead of the current call's flags. Without it, the
  ordinary reason to re-run setup — moving the version pin — reports every confirmed decision as
  drift and reverts them all under `--update`, which is setup reverting a team's decision while
  claiming to upgrade them. The line is a pure function of the flags, which is what keeps it clear of
  the byte-comparison rule in the bullet below.

  Six files agree: `templates/workflow.yml` holds the `SETUP:IF:`/`SETUP:END:` blocks and the line,
  `render-workflow.sh` resolves them, `install-workflow.sh` recovers them, `SKILL.md` step 3 confirms
  them, `references/workflow.md` §§ *Triggers*, *The guard* and *The line that records the decisions*
  own the rules **alone**, and `tests/run.sh` checks that each knob changes bytes — a knob that
  renders the same file either way makes the confirmation theatre.

  **Two ways to write the guard expression produce a workflow GitHub rejects outright**, and neither
  is visible to a YAML parse, which is how both shipped. Actions expressions have **no arithmetic**,
  so `(additions + deletions) > 50` is an invalid-file error rather than a sum — the two counts are
  compared separately against the same number. And in a folded scalar a **more-indented line is not
  folded**, so its newline survives into the expression; every line sits at six spaces and the
  operators lead their lines to remove the thing anyone would align. `tests/run.sh` asserts both
  structurally, because no offline tool validates the expression grammar and the only reliable signal
  is GitHub's own validation on push.
- **Idempotency is decided by comparing bytes, so nothing rendered may vary.** No timestamp, no run
  id, no randomness, no "generated on" comment — `install-workflow.sh` tells "already set up" from
  "edited by hand" by `cmp`, and a date would make every second run report drift. `tests/run.sh`
  asserts the rendered file contains today's date nowhere.

  The `# Decisions:` line is not an exception to this and the distinction is the whole reason it
  is allowed: it is a pure function of the flags, so two renders with the same flags produce the same
  bytes. What is forbidden is a value that varies **between two renders of the same request**, not a
  value that records the request.

  **That assertion has to run against the whole file, comments included.** It did not, briefly: the
  negative assertions run against a comment-stripped copy so the workflow may explain in a comment why
  it does not use `pull_request_target`, and a timestamp added as a comment sailed straight through
  a test whose entire purpose was to catch it. `tests/run.sh` now reads the whole file for it.
- **Drift is reported, never resolved.** A hand-edited Accountable Review workflow is a file a team
  owns, and setup reverting their pinned action or tightened timeout is the worst thing this command
  can do. `install-workflow.sh` prints the diff and exits 3; `--update` is the only way past it, and
  `SKILL.md` step 3 says to show the user and ask.
- **CI must not become the place that runs the application.** The page proposes validation commands
  and never runs them — the reason no probe output ever appears — and a workflow that booted the app
  "so the map could be better" would be that decision made by the back door, with its own safety
  design skipped. The template starts no service, runs no migration, and executes no script from the
  pull request; `tests/run.sh` asserts all three against the comment-stripped file.
- **The workflow posts one comment, and that is the entire write surface.** A link to the Review Map
  and the revision it describes, upserted against `<!-- accountable-review -->` so a reopen or a
  ready/draft toggle updates it rather than adding a second. It is what `pull-requests: write` is
  for, it is the only thing that scope is used for, and `--no-pr-comment` removes the step and the
  permission **together** — a repository carrying a write scope for a step that is not there is a
  standing grant nobody can account for.

  **This reversed the rule that the workflow posts nothing**, and the reason is the only thing that
  justifies the reversal: the run summary already said where the map went, and nobody opens a
  workflow run to find out whether there is something worth opening. Maps were being generated,
  uploaded, and never read. A boundary that makes the product undiscoverable is not protecting the
  product.

  **The line that did not move is verdict.** No check run, no status, no review, no label, no
  approval, and nothing in the comment that grades the change. The next request is the check — "so
  the map shows up in the status list" — and a passing check is a verdict whatever it is named, which
  is the product principle undone by the same door this comment came through. The comment is the
  visibility; that was the whole reason to spend a scope.

  **Actions has no per-step permissions, so containment is by injection rather than by scope.**
  `GITHUB_TOKEN` reaches only the step that names it in `env:`, and the step that runs a model over a
  contributor's branch does not. `tests/run.sh` asserts that exactly one step in the whole file names
  the token, because that is the fact making the scope acceptable and it is one careless `env:` away
  from gone.

  **And the comment reads the DeliveryResult rather than reaching past it** — a browsable provider's
  `stable_url` is linked as a page, the artifact provider's download URL as a zip. A comment step
  that knew about artifacts directly would be the second thing that knows where the map goes, which
  is the seam below being quietly unpicked.

  Six files agree: `templates/workflow.yml` holds the step and the permission behind the same
  `SETUP:IF:comment` blocks, `render-workflow.sh` renders both or neither, `SKILL.md` step 3 names
  the write scope out loud and its hard rules bound what may be posted, `references/workflow.md`
  § *The comment* owns the rules **alone**, `references/delivery.md` owns what it reads, and
  `tests/run.sh` executes the step against a stubbed `gh` on both the create and the upsert path —
  the one piece of shell in this repository that writes to someone else's repository, so it is run
  rather than read.
- **The product principle reaches the artifact, not just the page.** `manifest.json` is provenance —
  which revision, which plugin version, whether the coverage gate passed — and carries no severity, no
  score and no approval, for the same reason the page carries none. The job summary says what the
  Review Map is *for* and says outright that it does not review the change. A "Review Map: PASS" check
  on a pull request would undo the whole format, and it is exactly the shape the next feature request
  will take.

## The catalogue is the one thing a run cannot verify

`references/rails-docs.md` and `references/elixir-docs.md` are allowlists, and a run takes URLs from
them without opening any. That runtime rule is not up for revisiting — `rails-docs.md`'s opening
says why a live search per anchor is worse. What follows is that a catalogue's correctness is a
**maintenance** property with a date on it, and `evals/verify-catalogue.sh` is the maintenance: every
row in the **pinned** form a run actually emits, every series in the floor, table rows only, dated.
Its header carries the first sweep's eight defects and their three classes; the one to remember is
`active_record_nested_attributes.html`, a plausible URL constructed once and admitted, which no
script catches and no care while writing prevents.

**`elixir-docs.md` is closed, and that is the feature.** Every Elixir row was written the way that
URL was, so the file withholds every link until a dated verification line replaces its § *Version*
paragraph — the fail-closed rule at file scope. An Elixir run anchors with probes and prose, and
`--mentor` on Phoenix produces no primer. `verify-catalogue.sh --catalogue references/elixir-docs.md`
is that file's **release gate**, not optional maintenance.

**Every doc link is pinned, for checkability rather than precision**: a pinned page names its
version, so the reader can hold it against their lock file. Below the floor, or with no verified
path for the series, **no link at all**. Pinning fixes the URL and not the sentence, which is what
the marks are for — `‡ probe` (the behaviour moved; name the setting, propose a probe) and
`‡ since X` (state the default, name X). Different actions, not severities. **The probe is the
version-proof anchor**, and the reason `‡ probe` routes there rather than to a better link.

**Rails pins one series per app; Elixir pins per package**, so a correct Phoenix page carries several
version segments and generalising the one-series rule to hexdocs would fail every correct Phoenix
page while passing every test. `golden/anchors-hexdocs-clean.html` exists for exactly that edit. A
hexdocs path keeps its package (`ecto/Ecto.Changeset.html#cast/4`), because `Ecto.Migration` under
`ecto` is a 404 that reads as correct.

Six files agree. Each catalogue's §§ *Version*, *Pinning* and *What the marks mean* own the forms and
marks **alone**; `report-format.md` § *Framework anchors* says why the page cares; `SKILL.md` step 2
records the versions (skip it and no doc link can be emitted) and step 7 carries the two rules;
`verify-catalogue.sh` verifies; `checks/rails-anchors.rb` enforces offline — a version segment on
every link, one series for Rails only, no unsubstituted `{version}`, no other series' override path,
whole-token allowlist matching — with the reason for each beside its rule. **`page-template.html` is
the sixth and the one missed first**: it shows the doc link already pinned with the version as a
placeholder, because a template carrying the unpinned form, or a literal `v8.0`, teaches it to every
run. The four bypasses that check once had share one shape — **a rule that passes is not a rule that
looked**.

## Deliberately single-context, with one named exception

The skill runs in one context and spawns exactly one kind of agent, the falsifier that reads one
analysis note. That is a choice, not an omission — an earlier iteration fanned out to `Explore`
agents per layer and came out, and a later run that reached for one stalled 997 seconds, 41% of its
wall clock, in a single blocked turn. `SKILL.md`'s hard rules say so, because a boundary stated only
here is one the skill was never told about.

**The falsification pass is the exception, and why it does not reopen the rule is the part to
keep**, because the next thing that wants an exception will look similar and probably is not. Its
seam is per **analysis note**, which is per flow — a whole behaviour, so nothing is fragmented the
analysis had not already separated. It is read-only and returns *challenges*, not page content: the
parent writes every word and opens every cited file before acting on one. It reads a note rather
than a published section, so nothing is wrong in public while a challenge is in flight; and step 7
reassembles the parent's own notes, not several agents' conclusions.

**It costs tokens, not wall clock, and the two are different questions.** Blocked time is under 1% of
a run because the parent keeps drafting; the falsifiers' own contexts are a fifth of the run's
cache-read tokens — which is why `agents/claim-falsifier.md` pins its own model, and why a cost
quoted from the parent transcript alone is short. **A run that waits on them has lost the whole
argument**: spawn-then-idle turns the cheapest step into the most expensive, and is the likeliest way
this default gets reverted by someone measuring it. The numbers and their provenance live in
`SKILL.md` step 6c and `evals/README.md` § *Profiling one run*; do not restate them here.

**It is not a licence for steps 5, 6 or 7 to fan out.** The first two span the whole diff by nature
— splitting them by layer moves comprehension fragmentation from the human to the agents — and
step 7 holds the whole agenda at once to merge and rank it, the least splittable thing in the
procedure. So a very large diff strains this version, and `SKILL.md` says to *report* the strain
rather than quietly skim. When specialists arrive, the seam is per-flow, never per-layer.

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

## The other unsolved half: threading a review pass through the map

Running the project's code-review pass as well, and threading its findings through the map, is not
built and has no flag. It used to have one, declared and parsed and stopping the run, and that is
gone — a name reserved for something nobody is writing is a promise on the command line. What is
kept is the design brief, written down so the next iteration starts from the real question rather
than rediscovering it.

**It is not "run `/code-review` and paste the output", and the reason is the product principle.** A
code-review pass produces graded findings — severity, confidence, a ranked list. This page carries no
verdict, structurally: the template has no chip that expresses one, and reintroducing a severity
vocabulary is named above as the single easiest way to undo this iteration. So the naive
implementation breaks the invariant the whole format is built to hold, and it will look like a feature
while doing it. **The agenda makes that sharper rather than easier**: a graded finding list is very
nearly the shape of a ranked checkpoint list, and the difference — that one carries severities and
the other carries questions — is one word per item wide.

**`--effort high` has now built half of this**, which is the reason to read the rest of this section
before writing it rather than after. The routing it needs — an external challenge arriving, being
verified against the file, and landing in the checkpoint that turns on it in the page's own voice
with no grade attached — is the mechanism `SKILL.md` steps 6c and 8 now run at `high`. What is still
to solve is where the claims come from and how a *graded* source is stripped, not what to do with
one once it arrives.

**The seam that resolves it, and the reason this is worth building at all:** a review finding
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
  do not assume it. A repo with none should degrade to the ordinary page, saying so.
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
  different tool answering a different question — and a review pass threaded through the map, if one
  is ever built, will not change that: it borrows the review's *search*, not its conclusions. See
  § *The other unsolved half*.
- **It links to the manual; it does not reproduce it.** The catalogue exists so a framework
  consequence is followable, not so the page can teach Rails to a reader who does not need it. And it
  never executes what it proposes: the skill does not boot the application under review, which is why
  no probe output ever appears. Changing that is a new decision with its own safety design, not an
  extension of this one.
- **`review-map` never posts to GitHub or anywhere outside the artifact**, and that has not changed.
  The skill writes a page; if a link needs to reach a pull request, the thing that posts it is the
  generated workflow's own last step, after generation has finished and in a different process.
  Threading it into the skill would put a write token in the process that reads a contributor's
  branch, and would make the delivery seam a fiction.

  **What did change is the CI side, and it changed deliberately.** The generated workflow posts one
  comment: a link and the revision it describes, upserted against a hidden marker. No check run, no
  status, no review, no label, and nothing in it that grades the change. `setup-ci`'s hard rules and
  `references/workflow.md` § *The comment* own the boundary; see also the invariant below.
- It never writes the page into the repository under review — a work directory under `$TMPDIR` only,
  **derived** in step 1 from the repo and the target rather than chosen per run, or the directory
  `--output` names, which `ci/generate-review-map.sh` refuses to let sit inside the checkout.
- It re-publishes to the same file path on a re-run, so one PR keeps one URL across pushes. That is
  the reason the path is derived and not picked: a session-scoped scratch directory is a different
  directory next session, so "the same path again" needs a rule, not a memory. Profiling a run that
  had no rule found nine calls and seventy seconds spent re-establishing a path and moving excerpt
  files that had been written somewhere else first.
- It assumes Claude Code or Codex plus a git repo containing a Rails or a Phoenix app. Everything else —
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

**This file is loaded in full at the start of every session in this repository, and nothing else
here is.** That is what it is for — a rule that can be skipped is not a rule — and it is also the
reason it is the one document with a standing cost. What belongs here is what **spans files**: the
rule, the one observation that makes it stick, and the list of files that have to agree. What does
not belong here is the detail that has a canonical home one file away — the CSS beside the
declaration, the check's rationale beside the check, the vocabulary beside the grader.

**A bullet growing past roughly 400 words is the signal that a fact moved to the wrong home**, not a
sign the subject got more important. The growth is almost always a paragraph recording what someone
learned while debugging the component — real, worth keeping, and belonging next to the thing it
describes, where the next person to edit it will actually be looking. § *One canonical home* is the
page's rule; it is this file's rule too, and this file is the one most likely to break it, because
appending here is always easier than finding the right home. When you add a paragraph, check first
whether the reference, the script or the check already says it: twice now the two had drifted, and
the copy here was the stale one.

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
gh release create accountable-review--v<version> --verify-tag --title "accountable-review <version>"
```

**The tag is not a label, it is what `setup-ci` installs.** `render-workflow.sh` derives
`accountable-review--v<version>` from the installed `plugin.json`, and the generated workflow
`git clone --branch`es it, so a release tagged any other way ships a `setup-ci` whose every workflow
fails at install. Nothing caught that for four releases: 0.24.0 to 1.0.1 were tagged plain, 1.0.2 to
1.0.4 not at all, and the prefixed tag first existed at 1.0.5. The plain tags stay on the remote as
history; do not add more.

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

**Codex has a manifest and a catalogue of its own, both in this repository**, and the version is
one value in two files. `.codex-plugin/plugin.json` carries the same `name` and `version` as
`.claude-plugin/plugin.json`, so the bump above is a bump of both; `.agents/plugins/marketplace.json`
names one plugin whose source is this repository (`local`, `./`), so `codex plugin marketplace add
wyeworks/accountable-review` is the whole distribution and the release tag serves both hosts.

Two facts about Codex decided that shape, and both are in its source rather than its docs. **It
reads `.codex-plugin/plugin.json` ahead of Claude's manifest and falls back to it otherwise** — and
Claude's has no `skills` field, so the fallback loads Codex's default `./skills`, which ships
`setup-ci` into a host whose CI half still runs Claude. The Codex manifest exists to say
`"skills": "./skills/review-map"`, and that one line is the reason the file is not redundant.
**It also reads `.claude-plugin/marketplace.json`, but skips the `github` source kind** the
`wyeworks/claude-plugins` entry uses (it accepts `local`, `url`, `git-subdir` and `npm`), so pointing
Codex at that catalogue lists nothing — which is why Codex's catalogue lives here rather than there.
Installed either way the skill is `accountable-review:review-map`, because both hosts namespace a
plugin skill by the manifest's `name`, and that shared name is the parity. Nothing in
`claude plugin validate --strict` reads either Codex file, so `tests/codex-plugin.rb` is the check
that they still agree, and it runs in `bin/evals offline` and CI.

Two things do not belong at the plugin root: a `CLAUDE.md` (it ships to every install but is never
loaded as project context, which is why this file lives in `.claude/`), and any component directory
inside `.claude-plugin/` — only the manifest goes there.

**`AGENTS.md` is at the root and is not an exception to the first half, because the reason does not
reach it.** A root `CLAUDE.md` is excluded for being dead weight: Claude Code reads `.claude/CLAUDE.md`
instead, so the root copy ships everywhere and is loaded nowhere. The root is the only place Codex
looks, so `AGENTS.md` there is the one that gets read rather than the one that does not. It is a
pointer at this file and holds only the three facts this file cannot state, being written for the
host that has the `claude` CLI. Keep it a pointer: a second copy of these rules is
§ *One canonical home* broken in the file that owns the rule, and this repository has already
watched that happen once, with the stale copy winning.
