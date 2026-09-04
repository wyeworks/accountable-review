# Contributing

`accountable-review` is an open-source Claude Code plugin by [WyeWorks](https://github.com/wyeworks).
Issues and pull requests are welcome at
[wyeworks/accountable-review](https://github.com/wyeworks/accountable-review).

## Running it from a checkout

There is no build and no install step. Point Claude Code at the checkout from inside the Rails
project you want to review:

```bash
cd /path/to/your/rails-app
claude --plugin-dir /path/to/accountable-review
```

Then `/accountable-review:review-map <PR number | PR URL | branch | "">`. `/reload-plugins` picks up
edits without restarting the session.

## What you are editing

There is no application code here. The "source" is prose that another Claude instance executes, so
the unit of quality is instruction clarity, not compilation.

```
.claude-plugin/plugin.json         plugin manifest (name, version, metadata)
agents/claim-falsifier.md          adversarial verifier, spawned per flow at --effort high
skills/review-map/
├── SKILL.md                       the procedure Claude follows
├── references/
│   ├── report-format.md           parts, review-unit format, evidence tiers, deep links
│   ├── rails-nextjs.md            what to look for per layer, runtime probes, search recipes
│   ├── rails-docs.md              the Rails and gem doc paths the page may cite, pinned per version
│   └── page-template.html         design system, components, and the diagram catalogue
├── scripts/
│   ├── excerpt.sh                 generates the collapsed source excerpts, so they are quotations
│   ├── ledger-rows.sh             generates the ledger rows from the diff
│   └── coverage-gate.sh           asserts the ledger accounts for every changed path
└── evals/                         fixtures, page and section cases, and the mechanical checks
```

Each reference owns one axis — procedure, page format, domain knowledge, documentation catalogue,
design system — and several invariants span more than one file. `.claude/CLAUDE.md` documents how the
documents divide the work and which invariants have to stay in agreement; read it before changing
anything that looks like it is stated in two places.

Match the existing register when you write: direct, specific, no filler. Rules state *why*, and
several carry the observation that produced them — a rule stripped to an imperative loses the thing
that makes a model follow it under pressure.

## Verifying a change

Before pushing, the manifest check must pass. CI runs the same one:

```bash
claude plugin validate . --strict
```

That checks the manifest, not the prose, which is the part that matters here. The prose is verified
by running the skill against a real PR and reading the page it produces.

Because defect discovery is sampling rather than a deterministic function of the diff, a single run
is weak evidence. When judging whether a wording change improved things, run the same target more
than once, or the same wording against several PRs of different shapes — a four-file bugfix, a
migration, a hundred-file feature spanning both sides of the API. Run both detail levels: they fail
differently, and a wording change judged at one says little about the other.

`skills/review-map/evals/` is where that judging is systematised — fixtures with deliberately planted
findings, whole-page and single-section cases, and one mechanical check script per rule family. The
loop is:

```bash
cd skills/review-map/evals
./run.sh behaviour-flows -n 3 --judge && ./report.sh
```

Results carry the skill's git sha, the model and the effort, so a pass rate is attributable to a
version of the prose. `evals/README.md` has the rest — the split between mechanical and judged
expectations, how to add a case, and `profile.sh` for when the question is where a run's minutes went
rather than whether the page was right.

The check scripts have their own regression suite, which runs in CI and takes about a second:

```bash
skills/review-map/evals/checks/self-test.sh
```

One script needs the network and is maintenance rather than part of a run:
`evals/verify-catalogue.sh` opens every URL in `references/rails-docs.md`, across every Rails series
the version floor admits, and reports dead pages, dead anchors, and rows that differ by version. The
catalogue is the one thing a run cannot verify for itself.

## Releasing

`.claude-plugin/plugin.json`'s `version` is the update pin: users only receive a change once that
field moves, so bump it in the same commit as the change and tag the release.

```bash
claude plugin validate . --strict
claude plugin tag --push          # creates accountable-review--v<version>
```

The marketplace catalogue lives in a separate repository, `wyeworks/claude-plugins`.
