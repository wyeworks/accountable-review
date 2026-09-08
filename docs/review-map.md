# Anatomy of a Review Map

What the page contains, why it is shaped that way, and what it assumes about your repository. The
[README](../README.md) covers what a Review Map is for; this is the reference for what actually
lands on the page.

The product principle every rule below serves:

> **Do not determine whether the PR is correct. Help a competent reviewer determine whether it is.**

## The sections

At `--full`, seven sections in the order a reviewer actually works, each owning one kind of thing,
with any the diff does not earn omitted outright. At the default `--brief`, the first three are these
unchanged and the last four are merged into one — see *Detail levels* below:

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
- **What this change reaches** — the same change seen whole, after the flows. Its figure is
  **impact paths**: two or three directed chains, each in a card of its own, each running from code
  the PR changed, through the code that is *affected but unchanged* — the callers, serializers,
  queries, factories, policies and TypeScript types whose meaning this diff just changed — to what
  someone would then observe. Every hop carries the relation that makes it causal: *reads*, *falls
  back to*, *ignored by*. Beneath the figure, each affected entry gets a citation and a clause;
  where a flow already explained one, this is a pointer back to it, and what no single flow owns is
  explained here. This is the part no diff can produce, and the reason the page exists.
- **Cross-cutting consequences** — only what genuinely spans flows: schema structure and migration
  safety, application invariants set beside database invariants, the authorization model, background
  jobs, deploy ordering, test infrastructure that changes how other specs behave, and changes to
  `CLAUDE.md`, hooks and skills, which alter how every human and agent works in the repo.
- **Before approving** — questions only the author can answer, validations worth running, the test
  gaps gathered in one place, and a comprehension checkpoint of at most five questions.
- **Coverage** — every changed file, where it is covered, and whether it is primary, supporting or
  secondary work. At `--brief` there is no such section and the file list sits in a shut disclosure
  at the foot of the page, because a list of every changed path is an inventory rather than
  something to read.

## Detail levels

**`--brief`**, the default, merges the tail of the page — what the change reaches, cross-cutting
consequences, before approving, coverage — into **one** section, *Reach & checks*, built around the
impact paths, with the questions and commands a reviewer acts on attached. Four sections instead of
seven.

**`--full`** writes all seven.

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

## Each fact has one home

Persistence, endpoint contracts and the frontend boundary have no sections of their own, on purpose.
One behaviour crosses all three, so giving each its own section meant describing that behaviour three
times — and an earlier version did, along with a findings section that got re-explained later and a
checkpoint that quizzed you on the paragraph above it.

Now every fact, finding, risk and reviewer action is explained in exactly one place and referenced
from anywhere else in a sentence. On a real PR that took a 21-page page to 9 with nothing of value
removed. The reader who thinks *"I already read this"* stops reading, and everything after that is
wasted no matter how good it is.

The section order is what makes that affordable. The flows come before the starting list and before
the reach section, so those two can point at a flow — *"`ActiveProjects` is explained in Flow B"* —
instead of carrying enough of the mechanism to be readable on their own.

## It arrives in stages

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

## The review unit

Every meaningful change gets the same seven fields: why this exists · implementation · relevant
tests · **affected but unchanged** · things to understand · how to validate · reviewer questions.

Validation steps are real commands against your repository, not invented ceremony. Tests appear
twice on purpose: beside the behaviour they pin, and again as their own section when the change
touches the test machinery itself.

## The code comes to you

Claims about *changed* code are cheap to check — you have the diff open anyway. Claims about
*unchanged* code are not: following one means opening an unfamiliar file with no context, so the
readers who do not follow it end up taking the finding on trust. Trust is the thing this page exists
to remove.

So the lines come to the reader. Where a claim would otherwise be taken on faith, the page carries a
collapsed excerpt of the real source, which you open when you are ready to check that particular
claim — verbatim, quoted by a script rather than retyped, and reading as a diff for changed lines and
as plain source for unchanged ones. Each block also says which state it is quoting, and the script
works that out from the diff instead of asserting it: the bytes of a quotation vouch for themselves,
and its label is the one part that cannot. The excerpts matter most on an unpushed branch, where
nothing on the page is clickable at all.

They also make the page shorter, which is the part that surprised us. A paragraph describing what a
guard does is longer than the guard, less precise, and unverifiable — so where the page would have
narrated the mechanism, it shows the lines and states the implication in one sentence instead.

One rule keeps this from turning into a diff viewer: **the page reads completely with every excerpt
closed.** The sentence carries the consequence, which is the thing the code does not say; the excerpt
carries the proof. What gets dropped is narration, never the finding.

## It anchors framework behaviour, and proposes ways to see it

A lot of what a reviewer needs to know about a change is not in the change. `update_all` at a call
site the diff never opened skips the validation this PR adds; a uniqueness validation is not a unique
index; `--sandbox` rolls back, so `after_commit` never fires there. On the Phoenix side,
`Repo.update_all` builds no changeset at all, a `unique_constraint` does nothing without the index
behind it, and a `phx-click` renamed in a template without its `handle_event` clause crashes the
LiveView the first time someone clicks it. So the page carries three anchors for a claim that rests
on the framework behaving as the framework.

**A link to where the rule is written down** — the Rails guides, the Rails API, hexdocs, or the
library's own docs. It sits beside the claim's `file:line`, never instead of it: a link to the guides
says nothing about *your* application, and the finding is always about your application. URLs come
from a catalogue that ships with the skill, because a run cannot open a URL to check it and a
plausible-looking API path is a 404 you discover on the reader's behalf.

**Every link is pinned to the version you are running.** The series from your `Gemfile.lock` for the
Rails hosts, the exact locked version for a gem's tag, each package's exact version from your
`mix.lock` for hexdocs — so a 7.1 app gets 7.1 documentation, and the page you land on prints "Ruby on
Rails 7.1.6" in its header for you to check against your own lock file. An unpinned link silently
means *current stable*, which is how a tool ends up explaining 8.1 behaviour to a 7.1 app with total
confidence. Where the catalogue has no verified page for your version, you get no link at all — the
mechanism is explained in prose against a line of your code instead, because an unlinked explanation
cannot mislead and a link to the wrong version can.

**On Elixir, that "no link at all" is currently the whole answer, and it is worth being plain about.**
The Elixir catalogue ships complete — every path, pinned per package, with the same rules — but not one
of its rows has been opened yet, and its own release gate is a verification run that opens all of them.
Until that run happens the file withholds every link: an Elixir page anchors with probes and prose, and
emits no documentation URL. That is a narrower page, not a broken one, and it is the same fail-closed
rule as above applied to a whole file rather than one row. Shipping an allowlist nobody had opened
would have been the more impressive-looking choice and the wrong one — a URL constructed from a naming
pattern is the one defect class no script catches.

Pinning fixes the link, not the sentence, so a handful of concepts get no sentence either. `enum`,
`perform_later`'s enqueue timing and strong parameters all changed inside the supported range — 8.0
introduced `params.expect`, 8.0 removed `enum`'s keyword syntax — and no single claim about them is
true of every app. For those the page names the setting that decides it and proposes a probe rather
than telling you what Rails does. The Rails marks came out of reading four CHANGELOGs across three
series; the Elixir ones are a first pass that no equivalent audit has confirmed yet, and the file says
so of itself rather than letting a reader assume otherwise.

**A console probe** — `bin/rails runner 'pp Project.validators_on(:slug).map { |v| [v.class, v.options] }'`,
`puts Project.archived.to_sql`, `connection.indexes(:projects)`; or, on Phoenix,
`mix run -e 'IO.inspect MyApp.Project.changeset(%MyApp.Project{}, %{}).errors'`,
`Ecto.Adapters.SQL.to_sql(:all, MyApp.Repo, query)`, `mix phx.routes`. For a framework-shaped change
this is usually better than a paragraph, because the behaviour is assembled from things a diff cannot
show you together: in Rails at boot, from the class, its concerns, its parents and the schema; in
Phoenix at compile time, from macros and from the `live_session` block your new route may or may not
have landed inside. A probe that settles a claim goes in *how to validate*; one that makes a mechanism
legible goes in *things to understand*.

**And a probe cannot be out of date**, which is why it is the anchor the Elixir half leans on while its
catalogue is closed. It interrogates the installed code instead of describing it.

Probes are **proposed, not run**. The skill never boots your app, so the page shows the command and
never its output — an invented `=> true` would be the most concrete-looking thing on the page and the
only part of it that was fiction. Read-only reflection is written for `bin/rails runner` or
`mix run -e`; a write is written for `bin/rails console --sandbox` in Rails, and — because Elixir has
no sandbox console at all — for an explicit `Repo.transaction(fn -> …; Repo.rollback(:probe) end)` in
Phoenix. The page says which, because a reviewer should not be able to change a database by pasting
what it told them to.

**And occasionally a primer** — a short callout inside the flow it belongs to, naming the API, saying
what the behaviour actually is in two paragraphs, and pointing at the pinned documentation. It is for
the narrower case where you cannot make the decision in front of you *without* the framework rule:
which of `archived_at_changed?` and `saved_change_to_archived_at?` a callback wants, say, when the
answer decides whether the callback fires at all. It cites the line in your code that earned it, like
any other link, and the four-line snippet beside it runs on a class your app does not have — so its
`# =>` lines quote the manual rather than claiming something about your application that nothing ran.

It works for the rest of the stack too, minus the branding: a primer about a library — Pundit's
`authorize` raising rather than returning false, a Sidekiq job re-running `perform` from the top —
is the same callout with the mark and the trademark line dropped and a neutral rule in place of the
red one. The logotype is an attribution, not decoration, so it appears only where the link does.

There is at most one per flow, and most flows get none. That ceiling is the point: the failure mode
here is not a wrong link, it is a page that explains every mechanism it touches, becomes a Rails
tutorial with a diff attached, and reads as more thorough while getting harder to navigate. An anchor
of any kind has to be earned by a decision you have to make.

## It separates evidence from inference

A claim the diff shows directly carries no label. Anything else is marked — *from unchanged code*,
*inferred from tests*, *inferred*, *uncertain* — so an inference can never pass as a fact. Where the
intent cannot be established, the page says so instead of guessing:

> It is unclear whether existing time entries stay editable after archival. No test covers it.

## It adapts to the PR

The detail level decides how many sections there are; this decides how heavily each one is weighed,
and the two are separate axes. Parts appear only when the diff earns them, and depth scales with
weight. A four-file bugfix produces a one-screen page, not an empty template. If a PR genuinely does
not need one, the skill says so instead of generating ceremony.

## It covers the whole diff

Ranking attention is not the same as skipping things. Every file in the diff appears somewhere, even
if only as a ledger row reading "regenerated by the migration". A reviewer who wants to read all of
it can, and never has to wonder whether something was quietly dropped. A mechanical check runs at the
final publish and fails the run if the page and `git diff --name-only` disagree.

Where that inventory sits is the one thing the detail level moves: the *Coverage* section at `--full`,
a shut disclosure at the foot of the page at `--brief`. It is deliberately not inside *What this
change reaches* — that section is about consequences, and a list of every changed path in the middle
of it is a second copy of the ledger where a reader is looking for something else.

## It is not a code reviewer, and it does not grade

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

Only that it is running in Claude Code, against a git repository containing a Rails or a Phoenix
application.

**Which of the two is detected, not configured** — a `Gemfile` or `config/application.rb` for Rails, a
`mix.exs` for Elixir — and it decides which lens file and which doc catalogue the run reads. A repo
holding both asks you which to cover rather than guessing. A repo holding neither says so and covers
the diff with the parts of the page that do not depend on a stack, rather than applying a Rails lens
to something that is not Rails and inventing findings.

Everything else is discovered too: where the Rails root is (repo root, a subdirectory, an engine) or
where `lib/<app>` and `lib/<app>_web` are, RSpec or Minitest or ExUnit, API-only or server-rendered or
LiveView, how authorization is attached, whether there is a separate frontend at all and where its API
client and types live, and whether the project documents its own conventions. Where a project has no
convention docs, the skill infers house style from adjacent unchanged code — usually more accurate than
a stale document anyway.

The separate-frontend sections need both sides in the diff. In a repository with no client, or a PR
that does not touch one, they are omitted rather than filled in. A LiveView app has no separate client
by design, and there the same material goes to the seam it actually has: the `phx-*` attribute and the
callback that answers it, the form field and the changeset's `cast` list.

`gh` is used when present, for PR metadata and deep links. A citation to a changed line lands on the
PR's diff page, on that line — the page the reviewer is already working in, where what the line
replaced is still visible. A citation to code the change did not touch cannot: no diff view can
address a line outside a hunk, so those land in the file at a pinned commit, which is also how the
page cites code as it was before the change. Without `gh`, or without a PR, the skill falls back to
the local branch and still links citations as long as the commit is pushed. On an unpushed branch it
degrades to plain text rather than emitting permalinks that would 404, and says so in the page.
