# Accountable Review

A [Claude Code](https://claude.com/claude-code) plugin that turns a pull request into a published
HTML **review map** — what the change is for, how its behaviours work, what the API and the client
now agree on, where the decisions live, where to start reading, and what it can break. It ships one
skill, `review-map`, targeting a Rails API with a Next.js client.

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

### How much page

```
/accountable-review:review-map 412              # --brief, the default
/accountable-review:review-map 412 --full
```

**`--brief`** merges the tail of the page — blast radius, cross-cutting consequences, before
approving, coverage — into **one** section built around the blast radius, with the questions and
commands a reviewer acts on attached. Four sections instead of seven.

**`--full`** writes all seven, and is the shape described in *What it produces* below.

What `--brief` does **not** do is thin out the first three sections. The behaviour flows are the
product, and a level that summarised them would be selling the thing the page exists for — so §§ 1–3
are identical at both levels, same depth, same excerpts, same rules. What it declines to spend is
four section shells on material that is often one screen: it merges, it drops the coverage ledger's
attention and grouping columns, and it drops the comprehension checkpoint. Every changed file still
appears, and the completeness check still runs, at both levels.

Reach for `--full` on a diff you are going to live inside for an hour — a migration, a change
spanning both sides of the API, someone else's hundred-file feature.

**`--review`** is planned: a code-review pass on top of the map, with its findings verified and
threaded into the flow that owns each one. It is not implemented, and passing it stops the run and
says so rather than producing a page that quietly leaves it out.

## What it produces

At `--full`, seven sections in the order a reviewer actually works, each owning one kind of thing,
with any the diff does not earn omitted outright. At the default `--brief`, the first three are these
unchanged and the last four are one section — see *How much page* above:

- **What changed** — intent, scope and the central behavioural change, with the use cases named as
  actor plus behaviour. Derived from tests, code and commits rather than copied from a possibly-stale
  PR description.
- **Behaviour flows** — the bulk, grouped by behaviour rather than by directory, and the one place
  each finding is explained. Each flow carries only what is specific to it: before and after, the
  path through the stack, the column it writes, the endpoint it goes through, the field crossing the
  backend/frontend boundary, the unchanged code it gives new meaning to, its tests and its test gap,
  and the decisions worth pausing on. It comes second because everything after it is easier to read
  once the mechanisms are known.
- **Start here** — the moment you open the code: one list, in the order to read it, of where to go
  and why. What most needs judgment and what to read first are the same question, so it is answered
  once. Each entry links into the flow that explains it.
- **Blast radius** — the same change seen whole, after the flows: the primary path end to end, plus
  the code that is *affected but unchanged* — the callers, serializers, queries, factories, policies
  and TypeScript types whose meaning this diff just changed. Where a flow already explained one,
  this is a pointer back to it; what no single flow owns is explained here. This is the part no diff
  can produce, and the reason the page exists.
- **Cross-cutting consequences** — only what genuinely spans flows: schema structure and migration
  safety, application invariants set beside database invariants, the authorization model, background
  jobs, deploy ordering, test infrastructure that changes how other specs behave, and changes to
  `CLAUDE.md`, hooks and skills, which alter how every human and agent works in the repo.
- **Before approving** — questions only the author can answer, validations worth running, the test
  gaps gathered in one place, and a comprehension checkpoint of at most five questions.
- **Coverage** — every changed file, where it is covered, and whether it is primary, supporting or
  secondary work.

### Each fact has one home

Persistence, endpoint contracts and the frontend boundary have no sections of their own, on purpose.
One behaviour crosses all three, so giving each its own section meant describing that behaviour three
times — and an earlier version did, along with a findings section that got re-explained later and a
checkpoint that quizzed you on the paragraph above it.

Now every fact, finding, risk and reviewer action is explained in exactly one place and referenced
from anywhere else in a sentence. On a real PR that took a 21-page page to 9 with nothing of value
removed. The reader who thinks *"I already read this"* stops reading, and everything after that is
wasted no matter how good it is.

The section order is what makes that affordable. The flows come before the starting list and before
the blast radius, so those two can point at a flow — *"`ActiveProjects` is explained in Flow B"* —
instead of carrying enough of the mechanism to be readable on their own.

### It arrives in stages

A large diff takes a while to explain, and a reviewer holding a ticket should not wait for all of it.
The page is published early and republished as parts complete, always to the same URL: open it at
minute two, watch it fill in, start reading the moment the part you need lands.

The behaviour flows are the bulk of the page, so they arrive **one flow at a time** rather than all
together — the split and what each flow will cover land first, then each flow as it is written.

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

### The code comes to you

Claims about *changed* code are cheap to check — you have the diff open anyway. Claims about
*unchanged* code are not: following one means opening an unfamiliar file with no context, so the
readers who do not follow it end up taking the finding on trust. Trust is the thing this page exists
to remove.

So the lines come to the reader. Where a claim would otherwise be taken on faith, the page carries a
collapsed excerpt of the real source, which you open when you are ready to check that particular
claim — verbatim, quoted by a script rather than retyped, and reading as a diff for changed lines and
as plain source for unchanged ones. The excerpts matter most on an unpushed branch, where nothing on
the page is clickable at all.

They also make the page shorter, which is the part that surprised us. A paragraph describing what a
guard does is longer than the guard, less precise, and unverifiable — so where the page would have
narrated the mechanism, it shows the lines and states the implication in one sentence instead.

One rule keeps this from turning into a diff viewer: **the page reads completely with every excerpt
closed.** The sentence carries the consequence, which is the thing the code does not say; the excerpt
carries the proof. What gets dropped is narration, never the finding.

### It anchors Rails behaviour, and proposes ways to see it

A lot of what a reviewer needs to know about a Rails change is not in the change. `update_all` at a
call site the diff never opened skips the validation this PR adds; a uniqueness validation is not a
unique index; `--sandbox` rolls back, so `after_commit` never fires there. So the page carries two
anchors for a claim that rests on Rails behaving as Rails.

**A link to where the rule is written down** — the Rails guides, the API, or the gem's own docs. It sits
beside the claim's `file:line`, never instead of it: a link to the guides says nothing about *your*
application, and the finding is always about your application. URLs come from a catalogue that ships
with the skill, verified by hand, because a run cannot open a URL to check it and a plausible-looking
API path is a 404 you discover on the reader's behalf.

**A console probe** — `bin/rails runner 'pp Project.validators_on(:slug).map { |v| [v.class, v.options] }'`,
`puts Project.archived.to_sql`, `connection.indexes(:projects)`. For an ActiveRecord change this is
usually better than a paragraph, because ActiveRecord's behaviour is assembled at boot from the class,
its concerns, its parents and the schema — the things a diff cannot show you together. A probe that
settles a claim goes in *how to validate*; one that makes a mechanism legible goes in *things to
understand*.

Probes are **proposed, not run**. The skill never boots your app, so the page shows the command and
never its output — an invented `=> true` would be the most concrete-looking thing on the page and the
only part of it that was fiction. Read-only reflection is written for `bin/rails runner`; anything that
writes is written for `bin/rails console --sandbox`, and the page says which, because a reviewer should
not be able to change a database by pasting what it told them to.

### It separates evidence from inference

A claim the diff shows directly carries no label. Anything else is marked — *from unchanged code*,
*inferred from tests*, *inferred*, *uncertain* — so an inference can never pass as a fact. Where the
intent cannot be established, the page says so instead of guessing:

> It is unclear whether existing time entries stay editable after archival. No test covers it.

### It adapts to the PR

The detail level decides how many sections there are; this decides how heavily each one is weighed,
and the two are separate axes. Parts appear only when the diff earns them, and depth scales with
weight. A four-file bugfix produces
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

`gh` is used when present, for PR metadata and deep links. A citation to a changed line lands on the
PR's diff page, on that line — the page the reviewer is already working in, where what the line
replaced is still visible. A citation to code the change did not touch cannot: no diff view can
address a line outside a hunk, so those land in the file at a pinned commit, which is also how the
page cites code as it was before the change. Without `gh`, or without a PR, the skill falls back to
the local branch and still links citations as long as the commit is pushed. On an unpushed branch it
degrades to plain text rather than emitting permalinks that would 404, and says so in the page.

## Layout

```
.claude-plugin/plugin.json         plugin manifest (name, version, metadata)
skills/review-map/
├── SKILL.md                       the procedure Claude follows
├── references/
│   ├── report-format.md           parts, review-unit format, evidence tiers, deep links
│   ├── rails-nextjs.md            what to look for per layer, runtime probes, search recipes
│   ├── rails-docs.md              the Rails documentation URLs the page may cite
│   └── page-template.html         design system, components, and the diagram catalogue
├── scripts/
│   ├── excerpt.sh                 generates the collapsed source excerpts, so they are quotations
│   ├── ledger-rows.sh             generates the ledger rows from the diff
│   └── coverage-gate.sh           asserts the ledger accounts for every changed path
└── evals/                         fixtures, page and section cases, and the mechanical checks
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
