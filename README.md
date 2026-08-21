# Accountable Review

A [Claude Code](https://claude.com/claude-code) plugin that turns a pull request into a published
HTML **review map** — what the change is for, what it can break, what the API and the client now
agree on, and where the decisions live. It ships one skill, `review-map`, targeting a Rails API with
a Next.js client.

It does not grade the PR. The product principle is narrower and more useful than that:

> **Do not determine whether the PR is correct. Help a competent reviewer determine whether it is.**


## Why

A `git diff` shows you what changed. It cannot tell you what the change *is* — which files carry the
design and which are churn, what order to read them in, which constant is load-bearing, or why the
author put a transaction there.

That gap is [comprehension debt](https://addyosmani.com/blog/comprehension-debt/): the widening
distance between code that gets produced and code anyone actually understands. Generating nine
thousand lines is now cheap; understanding them is not. A PR approved without being understood was
waved through, and the debt comes due the first time someone has to change it.

This plugin exists to close that gap, by knowing what a senior reviewer of this stack looks for and
rendering it as something you can read. The test it has to pass: after following the page, can the
reviewer explain what changed, why it works, and where the important decisions live?

## Install

Inside Claude Code — register the marketplace, then install the plugin:

```
/plugin marketplace add wyeworks/claude-plugins
/plugin install accountable-review@wyeworks
```

Or non-interactively, from a terminal:

```bash
claude plugin marketplace add wyeworks/claude-plugins
claude plugin install accountable-review@wyeworks
```

For a team that wants it enabled for everyone working on a repository, install at project scope so
the plugin is declared in the repo's settings rather than your own:

```bash
claude plugin marketplace add wyeworks/claude-plugins --scope project
claude plugin install accountable-review@wyeworks --scope project
```

Scopes are `user` (default, every project), `project` (checked in, shared with collaborators), and
`local` (this machine, this project, uncommitted).

## Generate a Review Map

```
/accountable-review:review-map              # current branch against its base
/accountable-review:review-map 412          # a PR number
/accountable-review:review-map https://github.com/org/repo/pull/412
/accountable-review:review-map feature/some-branch
```

You get back a URL. The page is a private Claude Artifact until you share it.

Re-running for the same PR republishes to the same URL, so the review map tracks the PR across
pushes instead of scattering links.

## What it produces

The page follows a review path, with every part omitted outright when the diff does not earn it:

- **What this does** — the use cases, as actor plus behaviour plus execution path. What was possible
  before, what is possible now, what is now prevented — derived from tests, code and commits rather
  than copied from a possibly-stale PR description.
- **Review map** — the blast radius. The primary flow end to end, plus the code that is *affected but
  unchanged*: the callers, serializers, queries, factories, policies and TypeScript types whose
  meaning this diff just changed. This is the part no diff can produce, and the reason the page
  exists.
- **State and persistence** — ER diagram, migration safety, and application invariants set beside
  database invariants. The gap between those two columns is where the interesting problems live.
- **API surface** — the interface reconstructed as a contract: params, real response bodies, the full
  error list, and a side-effects row per endpoint.
- **Backend ↔ frontend contract** — one field followed across the boundary, from serializer to JSON
  to TypeScript type to hook to component, plus the mismatch table: nullable fields typed non-null,
  enum values missing from a union, error statuses nothing handles, deploy-ordering hazards.
- **Behaviour cohorts** — the bulk, grouped by use case rather than by directory, each as a review
  unit.
- **Cross-cutting concerns, test harness, developer tooling** — authorization, jobs, transactions,
  caching, env vars; test *infrastructure* changes that reach specs nobody in the PR opened; and
  changes to `CLAUDE.md`, hooks and skills, which alter how every human and agent works in the repo.
- **Comprehension checkpoint** — PR-specific questions you should be able to answer before approving.
- **Coverage ledger** — every changed file, where it is covered, and whether it is primary,
  supporting or secondary work.

### It arrives in stages

A large diff takes a while to explain, and a reviewer holding a ticket should not wait for all of it.
The page is published early and republished as parts complete, always to the same URL: open it at
minute two, watch it fill in, start reading the moment the part you need lands.

While it is still being written it says so, in a banner, and every part that is coming but not yet
written is marked pending in the contents and in place. That is the difference between a useful
early page and a dangerous one — a reader who sees no contract section should be able to tell whether
there was nothing to say or whether it simply has not been written yet. At the final publish the
banner and the markers are removed, and the coverage gate runs.

A run that dies halfway therefore leaves a page that is honest about being half a page, rather than
leaving nothing at all.

### The review unit

Every meaningful change gets the same seven fields: why this exists · implementation · relevant
tests · **affected but unchanged** · things to understand · how to validate · reviewer questions.

Validation steps are real commands against your repository, not invented ceremony. Tests appear
twice on purpose: beside the behaviour they pin, and again as their own section when the change
touches the test machinery itself.

### It separates evidence from inference

A claim the diff shows directly carries no label. Anything else is marked — *from unchanged code*,
*inferred from tests*, *inferred*, *uncertain* — so an inference can never pass as a fact. Where the
intent cannot be established, the page says so instead of guessing:

> It is unclear whether existing time entries stay editable after archival. No test covers it.

### It adapts to the PR

Parts appear only when the diff earns them, and depth scales with weight. A four-file bugfix produces
a one-screen page, not an empty template. If a PR genuinely does not need one, the skill says so
instead of generating ceremony.

### It covers the whole diff

Ranking attention is not the same as skipping things. Every file in the diff appears somewhere, even
if only as a ledger row reading "regenerated by the migration". A reviewer who wants to read all of
it can, and never has to wonder whether something was quietly dropped.

### It is not a code reviewer, and it does not grade

Claude Code ships `/code-review`, and many teams add their own. This skill answers a different
question — *what is this, and where do I look?* — and produces a document that outlives the review
rather than comments that vanish into it. There is no severity scale, no risk score, no approval
recommendation: the reviewer decides, the page equips them. It never posts to GitHub.

Nor does it claim to have found everything. Three independent passes over the same 109-file diff
produced eight distinct headline findings between them, with only one appearing in all three.
Explanation is reproducible; defect discovery is sampling. The page says so, and never reads as a
clean bill of health.

## What it assumes

Only that it is running in Claude Code, against a git repository containing a Rails application.

Everything else is discovered: where the Rails root is (repo root, a subdirectory, an engine), RSpec
or Minitest, API-only or server-rendered, the authorization library, whether there is a frontend at
all and where its API client and types live, and whether the project documents its own conventions.
Where a project has no convention docs, the skill infers house style from adjacent unchanged code —
usually more accurate than a stale document anyway.

The frontend sections need both sides in the diff. In a repository with no client, or a PR that does
not touch one, they are omitted rather than filled in.

`gh` is used when present, for PR metadata and deep links. Without it, or without a PR, the skill
falls back to the local branch and still links citations as long as the commit is pushed. On an
unpushed branch it degrades to plain text rather than emitting permalinks that would 404, and says
so in the page.

## Layout

```
.claude-plugin/plugin.json         plugin manifest (name, version, metadata)
skills/review-map/
├── SKILL.md                       the procedure Claude follows
├── references/
│   ├── report-format.md           parts, review-unit format, evidence tiers, deep links
│   ├── rails-nextjs.md            what to look for per layer, and the search recipes
│   └── page-template.html         design system and component vocabulary
├── scripts/
│   ├── ledger-rows.sh             generates the ledger rows from the diff
│   └── coverage-gate.sh           asserts the ledger accounts for every changed path
└── evals/                         fixtures, cases, and the mechanical checks
```

## Contributing

To run the plugin from a checkout without installing it:

```bash
claude --plugin-dir /path/to/accountable-review
```

`/reload-plugins` picks up edits without restarting. See `.claude/CLAUDE.md` for how the four
documents divide the work and which invariants span them.

## License

MIT
