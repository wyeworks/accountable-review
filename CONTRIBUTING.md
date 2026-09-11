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

Then `/accountable-review:review-map <PR number | PR URL | branch | "">`, or
`/accountable-review:setup-ci` against a repository you do not mind writing a workflow file into.
`/reload-plugins` picks up edits without restarting the session.

## What you are editing

There is no application code here. The "source" is prose that another Claude instance executes, so
the unit of quality is instruction clarity, not compilation.

```
.claude-plugin/plugin.json         plugin manifest (name, version, metadata)
agents/claim-falsifier.md          adversarial verifier, one per analysis note at --effort high
ci/                                what runs in CI, not what a skill reads
├── generate-review-map.sh         runs review-map non-interactively into a static directory
└── delivery/
    ├── deliver.sh                 the delivery seam: dispatch, and the DeliveryResult
    ├── github-artifact.sh         the default provider
    └── command.sh                 hand the directory to a command the team owns
docs/                              the public documentation the README links out to
├── review-map.md                  anatomy of the page
└── ci.md                          the delivery seam, and how to add a provider
skills/review-map/
├── SKILL.md                       the procedure Claude follows
├── references/
│   ├── report-format.md           the five sections, the checkpoint, chains, tiers, deep links
│   ├── rails-nextjs.md            Rails: what to look for per layer, runtime probes, search recipes
│   ├── phoenix-liveview.md        Phoenix/LiveView: the same, for the other stack
│   ├── rails-docs.md              the Rails and gem doc paths the page may cite, pinned per version
│   ├── elixir-docs.md             the hexdocs paths, pinned per package — closed pending verification
│   └── page-template.html         design system and components — no svg, by design
├── scripts/
│   ├── page-skeleton.sh           emits the head, the token block and the tint script into the page
│   ├── diff-render.sh             says which files GitHub will not render, which decides the link form
│   ├── excerpt.sh                 generates the collapsed source excerpts, so they are quotations
│   ├── ledger-rows.sh             generates the evidence foot's inventory from the diff
│   └── coverage-gate.sh           asserts the inventory accounts for every changed path
├── tests/                         the deterministic tests for those scripts, and the proof they fire
└── evals/                         fixtures, page and section cases, and the mechanical checks
skills/setup-ci/
├── SKILL.md                       inspect the repository, then configure CI
├── references/
│   ├── workflow.md                every part of the generated workflow, and why
│   ├── config.md                  .accountable-review.yml — the whole schema and precedence
│   └── delivery.md                the delivery contract, and how to add a provider
├── templates/workflow.yml         the workflow itself
├── scripts/                       inspect, render, install, read-config
└── tests/                         the deterministic tests, and the proof they fire
```

Each reference owns one axis — procedure, page format, per-stack domain knowledge, documentation
catalogue, design system — and several invariants span more than one file. A Rails run reads the Rails
lens and the Rails catalogue; a Phoenix run reads the Phoenix pair, and neither should learn about the
other's contents. `.claude/CLAUDE.md` documents how the
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
migration, a hundred-file feature spanning both sides of the API. Two things are worth checking on
every run, because they are where this version is most likely to be wrong: open two entries from
*Impact outside the diff* and confirm the cited file really consumes the changed thing, and confirm
that every checkpoint is a judgment a reviewer could get wrong rather than a heading naming a file.

`skills/review-map/evals/` is where that judging is systematised — fixtures with deliberately planted
findings, whole-page cases, and one mechanical check script per rule family:

```bash
bin/evals page 1          # the recipe for one whole-page case
bin/evals page-check 1 page.html
```

The single-section cases are deferred: they graded one section of the page this design replaced, and
their equivalent unit is a checkpoint rather than a section (`evals/deferred/README.md`). Results
carry the skill's git sha, the model and the effort, so a pass rate is attributable to a version of
the prose. `evals/README.md` has the rest — the split between mechanical and judged expectations, how
to add a case, and `profile.sh` for when the question is where a run's minutes went rather than
whether the page was right.

The checks are Ruby — `check.rb` dispatches one script per rule family — and they have their own
regression suites, which run in CI and take a few seconds:

```bash
ruby skills/review-map/evals/checks/self-test.rb        # every golden fragment's asserted verdict
ruby skills/review-map/evals/checks/lib/test/test_page.rb  # the region scanner, directly
skills/review-map/evals/checks/frozen.rb                # ~1000 cases against their recorded output
skills/review-map/tests/run.sh                          # page-skeleton.sh and diff-render.sh
skills/review-map/tests/self-test.sh                    # every break run.sh claims to catch
skills/setup-ci/tests/run.sh                            # what the generated workflow contains
skills/setup-ci/tests/self-test.sh                      # ten deliberate breaks, each must fail it
```

A check script that always passes is worse than none, which is what the two self-tests are for: each
plants a defect and asserts that the rule fires. `frozen.rb` is the corpus that replaced the
shell-versus-Ruby equivalence oracle when the shell implementation was deleted — it is what notices a
rule quietly changing what it says.

One script needs the network and is maintenance rather than part of a run:
`evals/verify-catalogue.sh` opens every URL in both catalogues — `references/rails-docs.md` across
every Rails series the version floor admits, and `references/elixir-docs.md` at each package's newest
release — and reports dead pages, dead anchors, and rows that differ by version. A catalogue is the
one thing a run cannot verify for itself, and the Elixir one stays closed until this script opens it.

## Releasing

`.claude-plugin/plugin.json`'s `version` is the update pin: users only receive a change once that
field moves, so bump it in the same commit as the change and tag the release.

```bash
claude plugin validate . --strict
claude plugin tag --push          # creates accountable-review--v<version>
```

The marketplace catalogue lives in a separate repository, `wyeworks/claude-plugins`.
