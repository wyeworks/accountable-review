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
| `references/report-format.md` | Page structure — the review-unit format, the evidence tiers, which parts exist and what triggers each, depth rules, deep-link forms and the degradation ladder |
| `references/rails-nextjs.md` | Domain knowledge — what a senior reviewer of this stack looks for, per layer, plus the search recipes for affected-but-unchanged code |
| `references/page-template.html` | Design system — tokens, component classes, SVG diagram vocabulary |
| `scripts/ledger-rows.sh` | Generates the ledger rows, so the gate checks classification rather than typing |
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
  `rails-nextjs.md` are how, part 2 and the review-unit field are where it surfaces. The rule that
  makes it honest: **record what was searched**, so an empty result reads as evidence rather than as
  omission.
- **Completeness, and the one mechanical check.** Every path in the diff appears in the page. Stated
  in `SKILL.md` step 3, explained in `report-format.md` § *The completeness invariant*, and enforced in
  step 10 by `scripts/coverage-gate.sh`. Four files have to agree for that check to work: the script
  reads a `data-path` attribute, the template emits it on the ledger's path cell, `report-format.md`
  Part 12 requires it, and `SKILL.md` step 10 runs the script. Break any one and the gate stops
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
rather than quietly skim. When specialists do arrive, the seam is per-cohort, not per-layer, and the
orchestrator's job is reconnecting them into end-to-end behaviours.

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
