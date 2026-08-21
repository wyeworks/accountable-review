# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

There is no application code here. The repository is the `accountable-review` Claude Code plugin. It
ships a single skill — `skills/review-map/` — that turns a pull request into a published HTML review
map: what the change is for, what it can break, what the API and its client now agree on, and where
the decisions live. The first target stack is a Rails API with a Next.js client.

Installed, it is invoked as `/accountable-review:review-map`: plugin skills are always namespaced by
the plugin name, so the manifest name and the skill directory name together decide the public
command. The "source" is prose
that another Claude instance executes, so the unit of quality is instruction clarity, not compilation.

There is no build, no test suite, and no linter. Changes are verified by running the skill against a
real PR and reading the page it produces. `claude plugin validate . --strict` checks the manifest,
not the prose, which is the part that matters here.

## Working on the skill

Run a Rails project against this checkout — no install, and `/reload-plugins` picks up edits without
restarting:

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

`skills/review-map/evals/` holds a seed set for both. `fixtures/make-fixtures.sh` builds three
repositories whose interesting findings sit deliberately *outside* the diff, so there is a written
right answer to check against, and `check.sh` runs the expectations a script can settle — the coverage
gate, severity chips, verdict language, unlabelled inference, dead permalinks, theme states. Read
`evals/README.md` before adding a case; the split between mechanical and judged expectations is the
part worth preserving.

## How the documents divide the work

Each reference owns one axis; keep them from bleeding into each other.

| File | Owns |
|---|---|
| `SKILL.md` | The procedure — ten ordered steps from resolving the target to publishing — plus the product principle and the hard rules |
| `references/report-format.md` | Page structure — the seven sections and what triggers each, the review unit, the evidence tiers, source excerpts, the canonical-home rule, depth rules and the deep-link ladder |
| `references/rails-nextjs.md` | Domain knowledge — what a senior reviewer of this stack looks for, per layer, plus the search recipes for affected-but-unchanged code |
| `references/page-template.html` | Design system — tokens, component classes, SVG diagram vocabulary |
| `scripts/excerpt.sh` | Generates the collapsed source excerpts, so the quotation is the real bytes |
| `scripts/ledger-rows.sh` | Generates the ledger rows and their deep links, so the gate checks classification rather than typing |
| `scripts/coverage-gate.sh` | The one mechanical check — set equality between the ledger and the diff |
| `evals/` | Fixtures with planted findings, the cases, and `check.sh`. Not loaded at runtime; see `evals/README.md` |

`SKILL.md` is the only file loaded up front; the references are read on demand at the step that needs
them. That is why `SKILL.md` says *when* to load each one, and why detail belongs in the reference
rather than inlined into the procedure.

The one exception is the product principle and the hard rules, which stay in `SKILL.md` even though
they read like a reference. A rule that can be skipped is not a rule, and the always-loaded file is
the only place skipping is impossible.

## Invariants that span files

Editing one of these means checking the others still agree.

- **The page never grades the change.** No severity scale, no risk score, no confidence percentage,
  no approval language. Stated as the product principle at the top of `SKILL.md`, repeated in its hard
  rules, and enforced structurally: the template has no chip that expresses a verdict, and
  `page-template.html` says so in its header comment. Reintroducing a severity vocabulary is the
  single easiest way to undo this iteration.
- **Evidence tiers.** Five of them, listed in `report-format.md` § *Evidence tiers*, rendered as
  `span.tier`. A claim the diff shows directly carries **no** label — silence is the first tier. That
  asymmetry is deliberate: labelling everything is noise, and noise gets skipped.
- **The review unit** is the page's primitive: seven fields, fixed order, defined in
  `report-format.md` and rendered as `article.unit`. Two guards keep it from becoming ceremony — a
  unit needs a non-obvious *things to understand*, and fields may be omitted but never faked.
- **Affected-but-unchanged code is the product.** Step 5 of `SKILL.md` finds it, the search recipes in
  `rails-nextjs.md` are how, § 2 and the review-unit field are where it surfaces. The rule that
  makes it honest: **record what was searched**, so an empty result reads as evidence rather than as
  omission.
- **Completeness, and the one mechanical check.** Every path in the diff appears in the page. Stated
  in `SKILL.md` step 3, explained in `report-format.md` § *The completeness invariant*, and enforced in
  step 10 by `scripts/coverage-gate.sh`. Four files have to agree for that check to work: the script
  reads a `data-path` attribute, the template emits it on the ledger's path cell, `report-format.md`
  § 7 requires it, and `SKILL.md` step 10 runs the script. Break any one and the gate stops
  checking. Note the asymmetry in the invariant itself: the page-wide rule is a subset test (the page
  cites unchanged files everywhere by design), while the gate is exact set equality against
  `git diff --name-only`, compared as whole strings — never substring matching, because `api/Gemfile`
  matches inside `api/Gemfile.lock`.
- **A staged page must never look finished.** The page publishes early and fills in at one URL
  (`SKILL.md` step 9), which is only safe because an unfinished page says so: a build banner while it
  is being written, an explicit *pending* marker for every part that is coming, and both removed at
  the final publish. Four states have to stay distinguishable — written, pending, *not written*
  because the run stopped, and omitted because the diff did not earn it — since the whole risk is a
  reader taking any of the last three for "nothing to say here". A stopped run is the one that needs a
  deliberate edit: pending is a promise, and leaving one behind is worse than publishing late. The form lives in `report-format.md` § *Build state*, the components are
  `.buildstate` and `.pending`, and `evals/check.sh --draft` / `--final` check both ends of it.
- **Findings are a sample, not an audit.** The page must never read as a clean bill of health. This is
  load-bearing, not hedging: the skill explains, and explanation is reproducible, but defect discovery
  is not.
- **Deep-link mode is chosen once**, in step 1, from the four-rung ladder in `report-format.md` —
  driven by whether the head SHA is reachable on a remote. Unpushed branches are the common case, and
  the correct behaviour there is plain text, not a permalink that 404s.
- **Seven sections, and each fact has one home.** The format is deliberately *not* one section per
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
  `evals/check.sh` holds the mechanical half of all three; whether the prose survives with the blocks
  shut is a judged expectation, because no script can tell.
  Two things the first live run changed, both worth keeping stated. The closed-page rule is judged
  **field by field**: a citation elsewhere on the page does not rescue a field whose only `file:line`
  sits inside the collapsed block, and `check.sh` cannot see that. And the budget's test is that the
  citation is **load-bearing for a decision the reviewer must make** — the obvious phrasing, "one per
  field that earns one", is circular, because *affected but unchanged* is by definition nothing but
  claims a reader would take on faith, so every such field earns one automatically and the cap bounds
  nothing. The budget, the permitted locations and the rung adjustment live in `report-format.md`
  **only**; `SKILL.md` points at them. An earlier version restated the cap in slightly different words
  and the two drifted apart within one run — hence the rule that this one has a single home.
- **Theme tokens.** Every colour is defined on bare `:root` *and* redefined in both dark blocks
  (`prefers-color-scheme` and `[data-theme="dark"]`). A colour declared only inside a media query is
  the classic unreadable-artifact bug.

## Deliberately single-context

The skill runs in one context. It spawns no subagents, and that is a choice, not an omission — an
earlier iteration fanned out to `Explore` agents per layer, and it came out.

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

The run in question — `experiment/ai-hours-assistant` in wye-time, 112 files, 14.8k insertions, a
Rails API and a Next.js client in one diff — got through the goal, the blast radius and five verified
affected-but-unchanged findings, and would have needed several times that budget to finish the
behaviour flows and a 112-row ledger. Nothing about it failed. It simply ran out of room, in a way
the procedure has no policy for.

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

## Boundaries the skill must keep

These are deliberate scope limits, not omissions — do not "improve" the skill past them.

- **It helps a reviewer decide; it does not decide.** The page carries evidence, relationships,
  invariants, uncertainty and validation steps. It never carries a verdict. `/code-review` is a
  different tool answering a different question.
- It never posts to GitHub or anywhere outside the artifact.
- It never writes the page into the repository under review — scratch location only.
- It re-publishes to the same file path on a re-run, so one PR keeps one URL across pushes.
- It assumes only Claude Code plus a git repo containing a Rails app. Everything else — Rails root
  location, RSpec vs Minitest, API-only vs server-rendered, auth library, whether a frontend exists
  and where its client and types live — is discovered, never assumed. Adding an assumption about
  project layout is a regression.
- The frontend is a first-class half of the contract, not a frontend review. The page follows fields
  and error cases across the boundary; it does not critique component design.

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
