# Accountable Review

A [Claude Code](https://claude.com/claude-code) plugin that turns a pull request into a published
HTML **review map** — what the change is for, how its behaviours work, what the API and the client
now agree on, where the decisions live, where to start reading, and what it can break. It ships two
skills: `review-map`, which produces the page, targeting a Rails API with a Next.js client, and
`setup-ci`, which arranges for one to be produced automatically on every review-ready pull request.

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

### How hard it works

A separate axis, and orthogonal to the one above:

```
/accountable-review:review-map 412                    # --effort high, the default
/accountable-review:review-map 412 --effort low       # opt out of the falsification pass
/accountable-review:review-map 412 --full
```

Everything the skill writes rests on claims it checked itself — and the context that wrote a claim
is the one least able to see what it assumed. **`--effort high`**, which is what you get unless you
ask otherwise, adds a second reader that does not share that context. Once the behaviour flows are written, one read-only `claim-falsifier` subagent
is sent at each of them, with a single mandate: assume this flow is wrong in ways that matter, and
find evidence in the repository that contradicts it. It produces no competing explanation and
rewrites nothing — it comes back with challenges, each anchored in a line it opened, plus the claims
it attacked and could not break.

The run then does to those challenges what it does to any other finding: opens the cited file itself,
and corrects, downgrades or drops the claim. A challenge it cannot confirm is dropped, exactly as an
unconfirmed finding is.

It is on by default because it is very nearly free and it changes what the page finds. The agents
read while the run keeps drafting rather than instead of it: on a 28-file pull request the whole
pass cost 23 seconds of waiting, under 1% of the run, and the same change reviewed without it missed
five things the falsified page carried. `--effort low` turns it off, which is worth doing when
the diff is small enough that a second reader has nothing to find.

That is still the one carved exception — the skill otherwise spawns nothing at all, because an
earlier version fanned work out to helper agents and paid 997 seconds, 41% of its wall clock, in a
single stalled turn.

**The page looks exactly the same either way.** No badge, no marker, no count of what was corrected.
Verification is not a feature the page advertises: an evidence tier says how a claim is known, and a
stamp saying how hard someone looked is the clean bill of health this page must never read as. What
changed is reported to you in the terminal, not to whoever opens the link.

## Team CI setup

One command turns "someone runs the review map by hand, sometimes" into "every review-ready pull
request has one, and the whole team can open it":

```
/accountable-review:setup-ci
```

It looks at the repository first — what CI you already have, whether Claude Code is already running in
it, what conventions your workflows follow — and then writes one file,
`.github/workflows/accountable-review.yml`. It touches nothing else, and running it twice is safe: the
second run compares what it would write against what is there and says *unchanged*.

```
pull request marked ready for review
        ↓
Review Map generated for that exact revision
        ↓
uploaded as a GitHub Actions artifact
        ↓
available to everyone who can see the repository
```

Then a push to that pull request regenerates it, and cancels the run that is now describing a
revision nobody is reviewing.

### What you get

| | |
|---|---|
| Triggers | `ready_for_review`, `synchronize`, `reopened` |
| Draft pull requests | Ignored — pushing to a draft costs nothing |
| Fork pull requests | Skipped: a `pull_request` run from a fork gets no secrets |
| Detail level | `--brief` |
| Delivery | GitHub Actions artifact, kept 30 days |
| Concurrency | One run per pull request; superseded runs cancelled |
| Permissions | `contents: read`, and nothing else |

One thing is left for you: **the credential.** Add `ANTHROPIC_API_KEY` (or `CLAUDE_CODE_OAUTH_TOKEN`)
as a repository secret. Setup cannot see your secrets, so it says outright that this is outstanding
rather than implying everything is ready.

One thing to know about the triggers: `opened` is not among them, so a pull request opened *directly*
as ready for review gets its first Review Map on its next push. If your team does not start work as
drafts, add `opened` to the list — the draft guard still holds.

The workflow is read-only and analysis-only. It never pushes, comments, approves, merges, or sets a
check with a verdict in it, and it never boots your application: no migrations, no database service,
no scripts from the pull request. That is the same principle the page itself follows — validation
commands are shown to a reviewer, never run on their behalf.

### Configuration, if you need any

Usually none. Where you do, `.accountable-review.yml`:

```yaml
review_map:
  mode: full
  delivery:
    provider: github-artifact
    retention_days: 14
```

It is read when the workflow runs, so changing it does not mean regenerating the workflow. Setup will
not write one that only restates the defaults — a file nobody chose is one more thing to keep in sync.

### Artifacts are the default, not the contract

**Review Maps are portable static HTML.** The default CI setup stores them as GitHub Actions
artifacts because that needs no hosting, no extra credential, no external service and no manual step
to share them. The cost is honest and worth naming: an artifact has to be downloaded and extracted
before anyone can read it.

Generation and delivery are separate on purpose:

```
Review Map generation  →  review-map/index.html  →  delivery provider
```

Generation writes a static directory and knows nothing about where it ends up. A provider is one
script that says where it went:

```json
{ "provider": "github-artifact",
  "location": "accountable-review-pr-412-a93bd21",
  "browsable": false,
  "stable_url": null }
```

A static host returns `browsable: true` and a URL people can click. Adding one — S3, R2, an internal
static host, a Claude Artifact — changes nothing about how the page is produced, which is the whole
point of the seam. A generic `command` provider is already there for teams that would rather write
four lines of their own shell than wait for an adapter.

Claude Artifacts are deliberately *not* the CI default. They are an excellent destination — it is
where the interactive skill publishes — but automatic organisation-wide sharing is not a reliable
zero-configuration path today, so nothing in the architecture depends on them.

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
as plain source for unchanged ones. Each block also says which state it is quoting, and the script
works that out from the diff instead of asserting it: the bytes of a quotation vouch for themselves,
and its label is the one part that cannot. The excerpts matter most on an unpushed branch, where nothing on
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
unique index; `--sandbox` rolls back, so `after_commit` never fires there. So the page carries three
anchors for a claim that rests on Rails behaving as Rails.

**A link to where the rule is written down** — the Rails guides, the API, or the gem's own docs. It sits
beside the claim's `file:line`, never instead of it: a link to the guides says nothing about *your*
application, and the finding is always about your application. URLs come from a catalogue that ships
with the skill, because a run cannot open a URL to check it and a plausible-looking API path is a 404
you discover on the reader's behalf.

**Every link is pinned to the version you are running.** The series from your `Gemfile.lock` for the
Rails hosts, the exact locked version for a gem's tag — so a 7.1 app gets 7.1 documentation, and the
page you land on prints "Ruby on Rails 7.1.6" in its header for you to check against your own lock
file. An unpinned link silently means *current stable*, which is how a tool ends up explaining 8.1
behaviour to a 7.1 app with total confidence. Where the catalogue has no verified page for your
version, you get no link at all — the mechanism is explained in prose against a line of your code
instead, because an unlinked explanation cannot mislead and a link to the wrong version can.

Pinning fixes the link, not the sentence, so a handful of concepts get no sentence either. `enum`,
`perform_later`'s enqueue timing and strong parameters all changed inside the supported range — 8.0
introduced `params.expect`, 8.0 removed `enum`'s keyword syntax — and no single claim about them is
true of every app. For those the page names the setting that decides it and proposes a probe rather
than telling you what Rails does.

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

**And occasionally a primer** — a short callout inside the flow it belongs to, naming the API, saying
what the behaviour actually is in two paragraphs, and pointing at the pinned documentation. It is for
the narrower case where you cannot make the decision in front of you *without* the framework rule:
which of `archived_at_changed?` and `saved_change_to_archived_at?` a callback wants, say, when the
answer decides whether the callback fires at all. It cites the line in your code that earned it, like
any other link, and the four-line snippet beside it runs on a class your app does not have — so its
`# =>` lines quote the manual rather than claiming something about your application that nothing ran.

It works for the rest of the stack too, minus the branding: a primer about a gem — Pundit's
`authorize` raising rather than returning false, a Sidekiq job re-running `perform` from the top —
is the same callout with the mark and the trademark line dropped and a neutral rule in place of the
red one. The logotype is an attribution, not decoration, so it appears only where the link does.

There is at most one per flow, and most flows get none. That ceiling is the point: the failure mode
here is not a wrong link, it is a page that explains every mechanism it touches, becomes a Rails
tutorial with a diff attached, and reads as more thorough while getting harder to navigate. An anchor
of any kind has to be earned by a decision you have to make.

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
recommendation — and no verification badge either: the reviewer decides, the page equips them. It
never posts to GitHub.

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
agents/claim-falsifier.md          adversarial verifier, spawned per flow at --effort high
ci/                                what runs in CI, not what a skill reads
├── generate-review-map.sh         runs review-map non-interactively into a static directory
└── delivery/
    ├── deliver.sh                 the delivery seam: dispatch, and the DeliveryResult
    ├── github-artifact.sh         the default provider
    └── command.sh                 hand the directory to a command the team owns
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

## Contributing

To run the plugin from a checkout without installing it:

```bash
claude --plugin-dir /path/to/accountable-review
```

`/reload-plugins` picks up edits without restarting. See `.claude/CLAUDE.md` for how the four
documents divide the work and which invariants span them.

## License

MIT
