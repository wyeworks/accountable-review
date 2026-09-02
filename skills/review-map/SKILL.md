---
name: review-map
description: Builds a published HTML review map of a pull request — goal and use cases, behaviour flows carrying the API and client contract, where to start reading, blast radius including the unchanged code the change gives new meaning to, and what to check before approving — so a reviewer can explain the change before judging it. Targets Rails, with or without a separate client such as Next.js. Use this whenever someone needs to understand a change rather than grade it: asks what a PR or branch does, where to start on a large diff, which files actually matter, what the change might break, whether the frontend and backend still agree, or needs to bring a reviewer up to speed on someone else's work — even if they never say "review map" or "walkthrough". Invoke with /accountable-review:review-map, optionally passing a PR number, URL, branch, or diff range, plus a detail level: --brief (the default) merges the tail of the page into one section, --full writes all seven, --review is not implemented yet. An effort level is separate and orthogonal: --effort normal is the default, --effort high additionally tries to falsify the page's own claims before it is finished. Not for posting review comments or approval verdicts.
---

# Review Map

Turns a diff into one published page that makes a medium or large change navigable: what it is for,
how its behaviours work, what the API and the client now agree on, where the decisions live, where to
start reading, and what it can break.

**Do not determine whether the PR is correct. Help a competent reviewer determine whether it is.**
That is the whole product. A page good enough to approve from without reading code is a failure — the
reviewer ends up holding a verdict instead of a mental model, and the debt lands on whoever touches
the code next.

So the page is a navigation aid, never a replacement for reading the code. The question it has to
pass is: *after following this, can the reviewer explain what changed, why it works, and where the
important decisions live?* Not: *can a model summarize this diff?*

You are not a code reviewer here. Do not grade the change, do not recommend approval, do not post
comments on the PR. If the project has a review command, say so at the end and let it do that job.

## What is bundled

The procedure below relies on seven bundled files. Read each at the step that needs it rather than up
front — the procedure itself is the only part that has to be in context the whole way through.

| File | Read at | For |
|---|---|---|
| `references/report-format.md` | steps 1, 7, 8, 9 | The detail levels, the sections each one produces, the review-unit format, the evidence tiers, source excerpts, the canonical-home rule, depth rules and the deep-link ladder |
| `references/rails-nextjs.md` | step 5, then while reading any layer | What a senior reviewer of this stack looks for, the runtime probes, and the search recipes for code the diff did not touch |
| `references/rails-docs.md` | steps 7 and 9 | The Rails documentation URLs the page may cite. It is an allowlist, not a starting point |
| `references/page-template.html` | step 9 | The design system: tokens (light and dark), component classes, the two SVG diagram layouts, and the page's one small script |
| `scripts/excerpt.sh` | step 9 | Generates the collapsed source excerpts — the quotation has to be the real bytes |
| `scripts/ledger-rows.sh` | step 10 | Generates the coverage-ledger rows, and their deep links, from the diff |
| `scripts/coverage-gate.sh` | step 10 | Runs the completeness check |

Paths are relative to the base directory named at the top of this skill when it loads. That value is
how you reach the script — `$CLAUDE_PLUGIN_ROOT` is not set in the shell.

One thing bundled with the plugin is not a file you read: the `accountable-review:claim-falsifier`
subagent, spawned by name in step 8 and only at `--effort high`. It is addressed, never loaded — its
instructions are its own, which is the point of putting them in a separate context.

## 1. Resolve the target, the detail level and the effort

- Argument may be a PR number, a PR URL, a branch, or a diff range. With no argument, use the
  current branch against its base.
- **Read the detail level off the invocation, and hold it for the whole run.** One of `--brief`,
  `--full`, `--review`, in any position; **no flag means `--brief`**. What each level produces is in
  `references/report-format.md` § *Detail levels* — read it now, with the rest of that file, rather
  than inferring the shape from the section list. Three rules about the flag itself:
  - `--review` **stops the run.** It is not implemented; see § *The review level is not implemented
    yet* below for what to say. Do not fall back to another level and do not write a page.
  - An argument starting with `--` that is none of the three, and is not `--effort` with its value, is
    **reported, not guessed at**. A misread flag silently produces the wrong shape of page, and the
    reader has no way to tell.
  - Say which level you are producing when you first speak, in the same breath as the URL — a reader
    who wanted the full page should find that out at minute two, not at the end.
- **Read the effort off the invocation too, and hold it the same way.** One of `--effort normal`,
  `--effort high`, in any position; **no flag means `normal`**. It decides how hard the run works to
  be right, and at `--effort high` that buys exactly one thing today: the falsification pass in
  step 8. Three rules, two of them the level's own:
  - **It is a separate axis from the detail level, and they multiply rather than substitute.** Effort
    produces no section, changes no depth rule and moves no excerpt budget — the page is the same
    *shape* at either. `--brief --effort high` is the useful combination, not a contradiction: a short
    page whose claims were attacked.
  - An `--effort` value that is neither is **reported, not guessed at**, for the level's reason — work
    that silently differs, with nothing in the output to tell the reader which they got.
  - `--review` stops the run at every effort level. Effort does not implement it.

  Unlike the level, **do not announce the effort** — nothing about the pass reaches the page, and
  § *At `--effort high`* in step 8 says why.
- Find the base *ref*: the PR's base if there is one, else the default branch
  (`git symbolic-ref refs/remotes/origin/HEAD`, falling back to `main`, then `master`). This gives
  you a ref, not a merge point — do not compute a merge-base yourself. The three-dot diff below
  already resolves it, and hand-rolling one is how you end up diffing against a moved base.
- Use three-dot diffs throughout (`git diff BASE...HEAD`) so you see the branch's own work and not
  unrelated commits from the base.
- **Check the working tree** with `git status --porcelain`. Three-dot diffs ignore it entirely, so
  uncommitted edits mean the page can describe code that differs from what the reviewer has checked
  out. Say so in the page and cover the committed state only. If the uncommitted changes are
  substantial enough that the page would be misleading, stop and say why instead.
- If there is a GitHub PR, capture `owner`, `repo`, number, head SHA, title, author, body via
  `gh pr view <target> --json number,title,author,body,headRefOid,headRefName,baseRefName,url`.
  The number and the head SHA are what the links are built from.
- **Record the SHA the diff's left side comes from** as well — `git merge-base <BASE> HEAD` — with or
  without a PR. Deep links need both ends: head for a line that still exists, the left side for a line
  the change removed or for behaviour cited as it was. This is the one legitimate merge-base here, a
  permalink needs a commit rather than a range; keep using `BASE...HEAD` for every diff.
- If `gh` is missing or there is no PR, continue anyway with the local branch. This is a normal
  case, not an error.
- **Fix the work directory now, and derive it rather than choosing it.** Everything this run writes
  goes in one place, named after the target so a re-run recomputes it instead of remembering it:

  ```sh
  W="${TMPDIR:-/tmp}/review-map/<repo>-pr-<N>"      # a PR
  W="${TMPDIR:-/tmp}/review-map/<repo>-<branch>"    # no PR; / in the branch becomes -
  mkdir -p "$W"                                     # the page is $W/page.html
  ```

  Derived, not invented, because step 9 republishes to the same file path and step 10 reuses it on a
  re-run — one PR, one URL, across pushes as well as stages — and a session-scoped scratch directory
  cannot satisfy that: the next session gets a different one. Export `W` once and use it in every
  later command. A run that instead picked a path per command spent nine calls and seventy seconds
  re-establishing it while splicing excerpt files it had first written somewhere else and then had
  to move.
- **Fix the deep-link mode now, not at render time.** Check whether the head SHA is even reachable
  on a remote — `git branch -r --contains <HEAD_SHA>`, where empty output means it was never pushed
  and every permalink to it would 404. Unpushed branches and worktrees are among the most common
  targets for this skill, so expect this. Pick one rung from the ladder in
  `references/report-format.md` and hold it for every citation. The rung decides whether anything is
  clickable; it does not decide the form — inside a rung, a line in the diff links to the diff page
  and a line outside it links to a blob. At rung 2 there is no PR page, so check the base SHA for
  reachability too: without it there is no `compare` view to anchor into.

## 2. Discover the project

Assume nothing about layout or conventions — this skill travels between repos.

**Backend.** Locate the Rails root by finding `config/application.rb`. It may be at the repo root,
under a subdirectory such as `api/`, or there may be several (engines, monorepo). If more than one is
touched by the diff, ask which to cover. Detect, don't assume: RSpec vs Minitest; API-only
(`config.api_only`) vs server-rendered; the authorization library, if any; the serializer library;
the background job adapter; whether `strong_migrations` is present.

**Record the Rails version and its series**, from the `rails (x.y.z)` line in `Gemfile.lock`, along
with the exact locked versions of the gems above. The series is `major.minor` — `rails (8.0.2)` gives
`8.0` — and it is not bookkeeping: **every documentation link on the page is pinned with it**, so a
run that skipped this step cannot emit a doc link at all. Gem links pin to the exact locked version,
which is why those are recorded too. `references/rails-docs.md` § *Pinning* owns the forms; the same
version also decides what the page may claim, because two marks in that catalogue turn a
version-sensitive behaviour into a probe rather than a sentence.

**Frontend.** Locate it the same way — `package.json`, `next.config.*`, `app/` versus `pages/`. Then
find the seam between the two sides, because that is what the boundary material inside each
behaviour flow is built from:

- the API client or fetch wrapper, and where base URLs and error handling live;
- **whether types crossing the boundary are generated from the backend or hand-written.** Generated
  types drift loudly, at build time. Hand-written ones drift silently, which is the case worth
  hunting;
- runtime validation at the boundary (Zod or similar) and whether it is applied to every response or
  only some;
- the data-fetching layer: React Query, SWR, server components, route handlers.

**Conventions.** Look for the project's own in `CLAUDE.md`, `AGENTS.md`, `docs/`, `README`,
`CONTRIBUTING.md`. If found, check the PR against them. If not, infer the house style from adjacent
unchanged code of the same kind — often more accurate than a stale document.

## 3. Inventory the diff

- `git diff --name-status BASE...HEAD` is the source of truth for what changed.
- Bucket every path: migrations and schema, models, routes and controllers and serializers, services
  and jobs and mailers, config and dependencies, backend tests, frontend source, frontend types and
  API client, frontend tests, agent and developer tooling, generated files.
- **Keep the full file list.** Every path must appear in the finished page. This is a hard invariant,
  checked in step 10.
- If the whole diff is trivial (a few files, no migration, no new behaviour), say so and offer to
  stop rather than generate ceremony. A page nobody needs is worse than no page.

## 4. Derive the goal and the use cases

Before any layer, establish what the change is *for*. The reviewer cannot judge a mechanism without
knowing the behaviour it is meant to produce.

Answer, concretely: what problem does this solve; what were the user or system use cases; what was
possible before; what becomes possible or changes after; which actors are involved; what are the
primary execution paths.

**Rank your sources by how much they can be trusted:**

| Source | Worth |
|---|---|
| Tests | The best available statement of *intended* behaviour, because someone had to write the expectation down |
| The code itself | What actually happens, which is not always the intent |
| Commit messages | Often carry the *why* that comments do not |
| The PR description | A **claim**. Cite it as intent, never as fact — it is frequently stale or thin, and that gap is exactly what this page exists to close |

Write each use case as an actor plus a behaviour plus a path, not as a feature name:

```
Use case A — A workspace admin archives a project
Archiving prevents new time entries but preserves historical ones.

ProjectSettings → PATCH /api/projects/:id → ProjectsController#update
  → Projects::Archive → Project → projects.archived_at
```

**Say which parts you inferred.** Where the intended behaviour is not pinned by a test or spelled out
in code, name the gap instead of smoothing it over: *"It is unclear whether existing time entries stay
editable after archival. No test covers it."* An honest gap is more useful to a reviewer than a
confident guess, and it is the kind of thing they can resolve in one question to the author.

## 5. Trace the flows and find affected-but-unchanged code

**This is the step that makes the page worth generating.** A diff already shows changed lines well.
What no diff shows is the unchanged code those lines just changed the meaning of — and that is where
the expensive bugs are. Spend more turns here than on prose.

Work outward from each changed thing to its consumers:

| Changed thing | Who you have to go find |
|---|---|
| A method or class | Its callers, and anything that subclasses or includes it |
| A column | Serializers exposing it, scopes and queries filtering on it, factories setting it, forms writing it |
| A validation or callback | Every write path that now behaves differently — `update_all` and `insert_all` bypass it |
| An enum or status value | Every branch on that value, on both sides of the boundary |
| A JSON key or response shape | The API client, the TS type, and every component reading it |
| A route | Anything constructing that URL, including the client and any external caller |
| A job or its arguments | Every enqueue site, plus in-flight jobs already queued with the old shape |

`references/rails-nextjs.md` carries the concrete search patterns per artifact kind. Use them; do not
improvise a grep and call the area clear.

**Record what you searched, not just what you found.** An empty result is a real finding — "no other
caller of `Project#archive`, searched `rg 'archive[!?]?\b' app lib`" — but only if the reader can see
the search. Unrecorded, absence and omission look identical, and the reviewer has to redo the work.

Then draw the primary flow end to end, from user action to persistence and back, and list the
secondary effects hanging off it. That flow is the page's backbone: the behaviour flows in
section 2 are its parts, and section 4 is the same picture seen whole.

## 6. Cluster into behaviour flows, then classify

**Group by behaviour, never by directory.** `Services / Models / Hooks / Components` is the repository's
structure, not the change's, and a reviewer who reads it still has to assemble the behaviour themselves.
Group into vertical slices instead — one per use case, each cutting through controller, service, model,
client and tests:

```
Flow A — Archiving a project
Flow B — Preventing time entries against archived projects
Flow C — Showing archived projects in historical reports
```

Say why you split it that way. The split *is* the insight, and a defensible one is the backbone of
the whole section.

Then label each flow and each leftover file:

- **Primary** — directly implements the stated use cases.
- **Supporting** — refactors or infrastructure the primary behaviour needed.
- **Secondary** — independently reviewable, outside the primary mental model.

**Stay neutral about secondary work.** The point is to tell the reviewer which changes they can hold
separately, not to criticize the author for bundling. "Appears unrelated to archival; no correctness
concern identified; review independently" is the whole register.

## 7. Build the review units

Every meaningful change gets the same seven-field shape, defined in `references/report-format.md`:
why this exists · implementation · relevant tests · affected but unchanged · things to understand ·
how to validate · reviewer questions.

A behaviour flow's **body is a unit** — a `.mech` block stating the mechanism, then the seven fields
as `<dt>`/`<dd>` pairs in one `dl.rows`, never loose in the section — and the flow's path, diagram and
decisions sit beside it, with decisions after the closing `</dl>`. Build it from the assembled flow in
`references/page-template.html` rather than from a description of it; the labels and the boundary are
in `report-format.md` § *The review unit* and § *Section 2*.

The unit is **borderless by design**, which makes this easier to get wrong than it looks: a flow that
spills its rows straight into the `<section>` still renders and reads nearly right. Copy the assembled
example.

**Two anchors are available for a claim that rests on Rails rather than on this diff**: a
documentation link, and a console probe the reviewer runs. Both land inside fields the unit already
has — *things to understand* to make a mechanism legible, *how to validate* to settle something —
and `references/report-format.md` § *Framework anchors* owns the routing, the budget and the two
rules that matter most: a doc link never appears without a `file:line` beside it, and a probe never
appears with output beneath it. Where a flow's change is ActiveRecord-shaped, reach for a probe before
reaching for a paragraph: `references/rails-nextjs.md` § *Runtime probes* has them, and the reason is
that a validation, a scope or a `dependent:` is assembled at boot from places the diff cannot show
together.

Two rules keep it from becoming ceremony:

- **Units are for meaningful changes only.** A file whose whole story is "regenerated by the
  migration" gets a ledger row, not seven fields. If you cannot fill *things to understand* with
  something a reader would not have guessed, it is not a unit.
- **Validation steps must be real.** The actual rake task, the actual route, the actual factory in
  this repo — a command a reviewer can paste. Invented steps are worse than none, because they burn
  the reader's trust in the whole page on the first paste that fails.

## 8. Verify before asserting — at every publish boundary

This is not a phase that happens once, before writing. The page ships in stages (step 9), so it is a
gate each stage passes before it goes out. Content that has been published cannot be unpublished from
the reader's memory, and a wrong claim corrected in the last stage was still wrong in the first.

- **Read the file yourself before any claim reaches the page.** Not the diff hunk — the file. This is
  the single difference between a page that can be trusted and one that cannot.
- **Label the tier of anything the diff does not show directly.** Five tiers, rendered per
  `references/report-format.md`: explicitly changed · evidenced by unchanged code · inferred from
  tests · inferred from naming or architecture · uncertain. Silence means the first one. Never let an
  inference sit in the page wearing the clothes of a fact.
- **Tests are evidence of intent, not proof of correctness.** Say which behaviour they pin, which
  branch they leave open, and what still needs a human to exercise it.
- Where you could not confirm something, put it in the page as an open question. Do not round
  uncertainty up.
- Drop any finding that does not survive the check, and do not backfill it with something weaker.

### At `--effort high`: falsify each flow before the page is finished

Everything above is this run checking its own work. That is the weakest kind of check — the context
that wrote a claim is the one least able to see what it assumed. At `--effort high` the flows get a
second reader whose only job is to break them.

**When.** Once, after every behaviour flow has been **written** — which on a staged page means the
end of stage 3 in step 9, before stage 4. Not per flow as it is drafted: that would serialise a
blocked turn through the longest phase of the run. The trigger is the flows being written rather
than the stage, so it still applies when the flows are not being published at all.

**How.** One `accountable-review:claim-falsifier` per written flow, **all spawned in a single
message.** This is the one exception to the rule against subagents in § *Hard rules*, and the single
message is most of why it is affordable: several agents in one message block the run once, for the
slowest, where the same agents one at a time block it once each. A blocking subagent's whole runtime
lands in the parent's next before-first-token gap, and one run paid 997 seconds — 41% of its wall
clock — for a single sequential spawn.

Give each agent three things and no more: the repository path, `BASE` and `HEAD`, and **that one
flow's written HTML**, sliced out of `$W/page.html` by its `<section id="flow-x">` anchor. Not the
whole page — a falsifier holding the whole document is one long blocked turn again, and it has no way
to tell which claims are its to attack.

**Cap it at six.** Past that, take the flows carrying the most *affected but unchanged* entries and
the most `inferred` and `uncertain` tiers. Those are the claims a reader cannot check cheaply, which
is the only reason to spend an agent on them.

**A challenge is a claim to verify, not a finding to accept.** This step's first rule applies to the
falsifier exactly as it applies to you: open the cited file yourself. Then correct the flow, downgrade
its evidence tier, or drop the claim — and do not backfill a dropped claim with something weaker. A
challenge you cannot confirm is dropped, the same as any other finding that does not survive.

Corrections land as `Edit`s on the flow already in the page, never as a rewrite of it (step 9).

**Nothing about the pass reaches the page.** Not a sentence, not a marker, not a count of what it
corrected. Two reasons, and both are hard rules already: a tally of corrected claims grades this
page's own draft, and a page advertising that it was checked reads as the clean bill of health the
page must never be. Say what changed to the user, in chat, and leave the artifact silent.

A flow published at stage 3 and corrected here **was wrong while it was public**, and that is the
cost of running this after the flows rather than before each one. It is the right trade — the gate
above still runs at every flow's publish, and a claim retracted before the final publish beats one
that is never retracted — but it is a cost, not a free check.

## 9. Write and publish in stages

A large diff takes many turns to explain, and a reviewer holding a ticket does not want to wait for
all of them. Publish early and republish as parts complete: **the same file path every time, so the
URL never changes.** The reader can open it at minute two, watch it fill in, and start reading the
moment the part they need lands.

The mechanics are simply the `Artifact` tool's: republishing the same file path redeploys in place.

**Four milestones.** Each is a coherent thing to read, which is the point — a URL that changes under
someone mid-paragraph is worse than one that arrives late.

| Stage | After step | The page holds |
|---|---|---|
| 1 · Orientation | 4 | Section 1 (what changed), and the outline of the sections this diff earns, each marked pending |
| 2 · Blast radius | 5 | Adds section 4: the blast-radius diagram, changed vs potentially affected, and what was searched |
| 3 · Flows | 6, then per flow | Section 2's intro and the split — plus one pending stub per flow, named. Then each flow replaces its own stub as it is written |
| 4 · Complete | 10 | Sections 3, 5, 6 and 7, gate passed, build banner and every marker gone |

**At `--effort high` the falsification pass sits between stages 3 and 4** — see step 8. It adds no
milestone: it produces corrections to flows already published, not an arrival worth opening the tab
for, and the reader never learns it ran.

**The behaviour flow is the unit of staging, not section 2.** Section 2 is the bulk, so a stage that
delivered it whole would put the longest wait of the run behind one arrival — which is the shape
staging exists to avoid. Nothing new is needed to split it: `<section id="flows">` carries only the
intro, and each flow is already its own sibling `<section id="flow-x">` with a unique `id`, which is
exactly the anchor a later stage edits. The rail already renders a per-flow marker — take it and the
pending-section shape from `references/page-template.html` rather than inventing markup.

So stage 3 **opens with a cheap publish**: the split rationale, and one named stub per flow saying what
it will cover. That arrival is worth having on its own — a reader learns the shape of the change before
any flow is written. Each flow then lands in its own republish. Two rules keep this from becoming a
republish per paragraph:

- **One publish per flow that lands, not per edit.** If two flows land in the same turn, one publish
  covers both. That bounds the arrivals by turns, which is the right bound: the turn is what a reader
  waits through.
- **Step 8 is the gate on each of them.** More publish boundaries means more gates, not a looser one.
  A flow is published when it is verified, not when it is drafted — a wrong claim corrected two flows
  later was still wrong when it shipped.

Sections 3, 5, 6 and 7 land together in stage 4 rather than one at a time, and that is not
inconsistency: section 3 is a route through the flows and cannot precede them, section 7's ledger and
the completeness gate both belong to step 10, and sections 5 and 6 are small. A stage has to be worth
opening the tab for.

**The four milestones are the same at `--brief`**, because they are cuts through the *procedure*, not
through the section list. What differs is where the pending markers go: with one tail section rather
than four, stage 2 writes the top of section 4 and marks its `<h3>` sub-parts pending in place. Take
that section from the block assembled whole in `references/page-template.html` — it composes five
components that each came from a different section, and a composition that is only described is the
one that gets flattened. Stage 3 is unchanged by the level: section 2 is identical at both.

**The page fills in out of document order, and that is fine.** Step 5 produces the blast radius; step
6 produces the flows. So section 4 lands while section 2 is still a pending stub, and a reader
arriving at stage 2 sees a gap above written material — and once stage 3 is under way, a written flow
sits above a pending sibling flow. The pending marker is what makes both readable — the risk the
build state exists to prevent is an unwritten section looking like an empty one, not a section
arriving early.

Saving as each flow completes has a second payoff worth stating: a crash then leaves a useful page
rather than nothing.

**Fill the page in; do not rewrite it.** After the first `Write`, every later stage replaces that
section's *pending* marker with the written section, using `Edit` on the block the marker sits in.
The file is already on disk and the earlier sections have not changed, so re-emitting them buys
nothing and costs the whole page again in generated tokens. This is not a small saving and it is the
single largest cost a profile of this skill finds: one run wrote a 23 KB staged page, then produced
its finished 82 KB version as one 35,000-token `Write` that re-emitted the first 23 KB byte for byte
— 258 seconds, 56% of everything that run spent streaming output. An intermediate save is one tool
call; an intermediate *rewrite* is the whole document. Use `Edit` and the pending marker is the
anchor you already have.

**Write section 3 last of the prose sections** — which is why it sits in stage 4 above. It is a route
through the flows and an index into them, so it cannot be written before they exist without being
guessed at.

**The banner is what makes this honest.** An unfinished page that looks finished is a worse artifact
than no page at all: a reviewer sees no cross-cutting section, concludes there was nothing to say
about it, and moves on. It was simply not written yet. So until the final publish the page carries a
build-state banner naming which sections are still pending, and every pending section appears in
the rail and in place as an explicit *pending* marker — not as an absence, and not as an "N/A"
placeholder. The two look nothing alike on purpose. `references/report-format.md` § *Build state*
has the form.

**Pin the title and favicon at the first publish** and do not change them, even if your understanding
of the PR improves. Readers find a tab by its name and icon; a page that renames itself mid-run reads
as a different page.

Everything else about writing holds at every stage:

- Follow `references/report-format.md` for the seven sections, when each appears, how deep it goes,
  and the rule that each fact has one home. Follow `references/page-template.html` for the design
  system, layout, and diagram styles.
- **One fact, one home.** Before writing a section, ask what it *owns* that no other section owns. If
  the answer is "it re-explains something from earlier", write the reference instead: one sentence
  pointing at where the explanation lives. `report-format.md` § *One canonical home* has the routing
  table and the reference form.

  This is the difference between a page a reviewer finishes and one they abandon. A 21-page page from
  this skill condensed to 9 with nothing of value removed — half of it was the same content arriving
  again. A reader who thinks *"I have read this already"* stops reading, and every section after that
  is wasted no matter how good it is.
- **Prefer an excerpt to a paragraph that narrates code.** Five lines plus one sentence of implication
  is shorter, checkable and more useful than describing the mechanism in prose. The sentence still has
  to stand alone with the block closed, because it carries the *implication* — what you drop is the
  narration, never the consequence. See `report-format.md` § *Excerpts are also the shortest way to say
  what code does*.
- **The template is the design system — do not load `artifact-design` to re-derive one.** That skill
  exists to choose a palette and pair typefaces; those decisions are already made here, and its own
  first instruction is to apply an existing system when one exists. Loading it costs a turn and
  yields nothing. Load it only if you have a deliberate reason to depart from the template, and
  `artifact-diagramming` only for a diagram the template's vocabulary cannot express.
- **Two of the four diagram kinds are components, not drawings.** The blast radius is a `.blast` box
  grid and the boundary chain is a `.pipe` spine — build those from the template's markup, not as SVG.
  The ER fragment and the lifecycle are still hand-authored inline SVG using the template's classes,
  so they work in a local file as well as when published. **Take those two layouts from the catalogue
  in `page-template.html` — worked out to scale — and fill in the text rather than deriving geometry.**
  Which kind belongs to which section is in `report-format.md` § *Depth rules*, beside the budget and
  beside the two rules a check cannot enforce: a box grid cannot show a directed edge, and a diagram
  carries labels rather than sentences. Deriving a layout spends the run's attention on the part that
  does not matter: what matters is whether the edges are true, and a followable edge that is wrong
  costs the reviewer more than no diagram.
- **Generate source excerpts, do not type them.** Two things get quoted, not one. The lines a claim
  would otherwise ask the reader to take on faith — above all *affected but unchanged*, which no diff
  view can address — and **the changed hunk each behaviour flow turns on**, because § 2 is read before
  the reviewer opens the diff in § 3, so a flow that only describes its change is asking to be
  believed until then. Quote both inline as collapsed excerpts, from the generator:

  ```sh
  <skill base directory>/scripts/excerpt.sh --at app/models/project.rb:41-52 --why "..."
  <skill base directory>/scripts/excerpt.sh --diff app/models/project.rb --base BASE --why "..."
  ```

  An excerpt is a *quotation*, and that is why it is generated. A mistyped ledger row fails the gate
  loudly; a paraphrased quotation is a false quotation, and nothing in the page or in the reader's
  experience catches it. The script reads the real bytes and does the HTML escaping, which matters
  more than it sounds — ERB and TSX are full of `<`, `>` and `&`. It also tags the `--source` block
  with the language, which is what the page tints from at read time — pass `--lang` only when the
  extension lies, and never write a colour class into the code yourself: a hand-coloured quotation is
  a quotation someone edited.

  So **do not read the generated HTML back and retype it into the page.** Send each excerpt to a file
  in `$W`, leave a one-line placeholder where it belongs, and splice the files in with shell at the
  end. Retyping is how a generated quotation quietly becomes a typed one — the failure this bullet
  exists to prevent — and it pays for every excerpt twice in generated tokens.

  **Generate all of them in one call.** The excerpts do not depend on each other, so one call with a
  line per excerpt costs one round trip where seven calls cost seven. A run that did it one at a time
  spent ten requests on work worth two.

  Two rules travel with them. The page must read completely with every excerpt **closed** — that one
  is a hard rule below, and it is judged field by field, not page-wide. And an excerpt is earned by a
  citation that is **load-bearing for a decision the reviewer has to make**, not by a citation merely
  pointing at unchanged code — otherwise every *affected but unchanged* entry earns one automatically
  and the budget caps nothing. That test rations what sits on top of the per-flow hunk; it is never a
  reason a flow goes without showing its own change.

  **Do not carry a number in your head for this.** The budget, the locations excerpts may appear in,
  and how the link rung changes it all live in `references/report-format.md` § *Source excerpts*, and
  they live there only — an earlier version of this bullet restated the cap in slightly different
  words and the two drifted apart within one run.
- **Pin every documentation URL to the version this app runs**, using the series and gem versions
  recorded in step 2. The catalogue stores paths with no version segment; a link that reaches the page
  without one silently means *current stable*, which is how a 7.1 app gets handed 8.1 documentation.
  Where the catalogue has no verified path for this app's version, **emit no link** — explain it in
  prose and cite the repo line. `references/rails-docs.md` § *Pinning* owns the forms and the
  overrides.
- **A `‡ probe` row may not be asserted.** Those are behaviours that changed inside the supported
  Rails range, so no sentence about them is true of every app. Name the setting that decides it and
  propose a probe; the page asks rather than tells. A `‡ since X` row is stated as the default, naming
  X. `references/rails-docs.md` § *What the marks mean*.
- **Take every documentation URL from `references/rails-docs.md`, and never construct one.** You
  cannot check a URL from here — there is no fetch step, and the sandboxes this runs in commonly block
  those hosts — so a plausible-looking API path is a 404 the reader finds on your behalf, which costs
  the same trust as an invented rake task. A concept the catalogue does not carry is explained in prose
  with the repo citation it applies to; that is the ordinary outcome, not a failure. The rules and the
  budget are in `references/report-format.md` § *Framework anchors*, and they live there only.
- **A probe is proposed, never run.** Do not boot the application under review. The page shows the
  command; it never shows output, because there is none to show — and a fabricated `=>` line is the
  most concrete-looking thing on the page and the one part of it that is fiction. Name whether the
  snippet wants `bin/rails runner` or `bin/rails console --sandbox`, and use the project's real
  constants: a probe naming a scope this repo does not have is an invented command.
- Render citations in the rung chosen in step 1. Inside a rung the form is not a preference: a line
  the diff contains gets the PR diff anchor, so the reviewer lands in the review they are already
  working in rather than in the file at head, where nothing marks what the line replaced. A line the
  diff does not contain gets a blob permalink at the SHA that line actually exists at — head for
  unchanged code, base for code the change removed or for behaviour described as it was. Both forms,
  and the rung table, are in `references/report-format.md` § *Deep links*.
- Write the page to `$W/page.html` — the work directory derived in step 1 — and never into the repo.
  The page must never become part of the diff it describes. Excerpt fragments go in the same
  directory, so splicing them in is a path away rather than a move.

Tell the user the URL when stage 1 goes out, say it will fill in, and do not repeat it on every
republish — one link, mentioned once, then a note when it is complete.

## 10. Complete the page and gate it

- **Remove the build banner and every pending marker** — including the per-flow stubs and the rail's
  flow markers from stage 3. A finished page still carrying "2 parts still pending" is the worst
  outcome of staged delivery: it undersells work that is actually done, and the next reader cannot
  tell whether you stopped early or forgot the banner. If a section really was left unwritten, say so
  in prose as a stated limit — that is a different sentence from "pending".
- **Generate the ledger, do not type it.** Run the bundled generator from the repository under review
  and paste its output into the ledger table:

  ```sh
  <skill base directory>/scripts/ledger-rows.sh BASE HEAD
  ```

  It emits one row per changed path with the `data-path` attribute already set, each preceded by a
  hint comment carrying the git status letter and line counts — usually enough to decide the attention
  level without opening the file. Three cells are left as placeholders for you to fill: which section
  covers the file, its attention level, and its group. A row still reading `{{SECTION}}` is a row
  nobody classified, which is the point.

  **At `--brief`, add `--paths-only`** and paste the result into the merged section's `Changed` list:

  ```sh
  <skill base directory>/scripts/ledger-rows.sh BASE HEAD --paths-only
  ```

  One cell per path instead of four — no section, no attention level, no group, because those three
  judgements are the ledger's ranking and `--brief` declines to do it. The path and its `data-path`
  are unchanged, which is what keeps the gate below running at both levels. Combine it with the link
  flag your rung earned exactly as at `--full`.

  **Pass the link option your rung earned**, so the rows come out linked and you never type inside the
  cell the gate reads:

  ```sh
  <skill base directory>/scripts/ledger-rows.sh BASE HEAD --pr owner/repo#N                 # rung 1
  <skill base directory>/scripts/ledger-rows.sh BASE HEAD --compare owner/repo@base...head  # rung 2
  <skill base directory>/scripts/ledger-rows.sh BASE HEAD --blob owner/repo@sha             # rung 2, base unpushed
  <skill base directory>/scripts/ledger-rows.sh BASE HEAD                                   # rungs 3 and 4
  ```

  Rungs 1 and 2 both land on a diff page, whose fragment is the SHA-256 of the path — `--pr` and
  `--compare` compute it. A row names a file, so these link the file, not a line: the row is the
  reviewer's way into the diff. A run without the flag hand-inserted seven such anchors into the very
  `<td>` that carries `data-path`, which is typing inside the one cell this script exists to keep
  untyped.

  This exists because the gate below compares sets, and a hand-typed hundred-path ledger fails it for
  boring reasons: one truncation, one stale row after a rebase. Generating the rows makes the gate a
  check on your classification rather than on your typing.
- **Completeness gate.** Then run the gate from the same place:

  ```sh
  <skill base directory>/scripts/coverage-gate.sh <page.html> BASE HEAD
  ```

  The base directory is named at the top of this skill when it loads; `$CLAUDE_PLUGIN_ROOT` is *not*
  set in the shell, so do not reach for it.

  Use the script rather than improvising the check. Not because improvising is forbidden, but because
  the tempting improvisation — grepping the page for each path — silently passes on truncated paths:
  `api/Gemfile` matches inside `api/Gemfile.lock`. The script compares sets as whole strings, prints
  what is missing and what is surplus, and fails loudly when the `data-path` attributes are absent
  instead of reporting a pass it did not earn.

  The gate runs once, here, against the finished page, **at every detail level**. `--brief` produces a
  shorter page, not an unaccounted-for one: it drops the ledger's three judgements and keeps its one
  guarantee. A run that skipped the gate because the page has no section 7 has quietly turned a
  shorter page into a page that may have dropped a file, which is the one thing the level was never
  allowed to do. Earlier stages ship with the path list visibly marked partial; a gate that passed on
  a partial list would mean nothing.
- Confirm the page renders: no horizontal overflow on `body`, diagrams and wide tables fit or scroll
  in their own container, and all three theme states resolve (`data-theme="dark"`,
  `data-theme="light"`, and the unstamped `prefers-color-scheme` default most viewers get). The design
  is warm-paper light; the dark half is ours, so a colour declared in only one place is a bug the
  reader sees and you will not.
- Carry the template's `<script>` block across **verbatim, and add nothing to it** — including the two
  `<script src>` lines above it. It is a scroll-progress bar, a rail scroll-spy and the syntax tint on
  unchanged excerpts: presentation only, and the page reads correctly with the whole block deleted, in
  one ink. Do not give § 6 checkboxes, tick state or an "n of m" counter — a count of cleared items
  reads as progress toward approval, which is the verdict this page does not carry.
- Publish the final state to the same path. Report that it is complete, what the change does in two or
  three lines, and anything you could not verify. Mention the project's own review command if it has
  one.
- On a re-run for the same PR, the path is the **same one step 1 derives** — that derivation is what
  makes the URL survive across pushes as well as across stages. One PR, one link, however many times
  this runs, without having to remember where the last run put it.

## When a run stops early

Sometimes a run ends before the page is finished — the diff was larger than the context, the user
called it, something failed. The page is already published, so the question is what it should say.

**Not the draft banner.** "Still being written, 3 parts still pending" is a promise, and nothing is
writing it any more. A reader who comes back an hour later to the sections they were told were coming
has been misled by a page that was accurate when it shipped.

Convert it instead into a stated limit — the same components, different words:

- The banner says what was covered, that the run stopped, and that the absence of the rest is not a
  finding about the change.
- Every marker changes from *pending* to *not written*. Pending is a promise; not written is a fact.
- The ledger note says the gate did not run, and warns against reading the written sections as a full
  account of the diff.

`evals/check.sh --stopped` checks all four. This is the third legitimate state of the page, alongside
in-progress and complete, and the only one that requires a deliberate edit rather than a deletion.

## The review level is not implemented yet

`--review` is meant to run the project's code-review pass as well, and thread its findings through
the map. That is not built, and no effort level implements it: `--effort high` falsifies the page's
own claims, which is a different job from importing someone else's findings. **Stop, and say so** —
do not fall back to another level and do not write a page:

> `--review` runs a code-review pass on top of the review map, and is not implemented yet. Re-run
> with `--brief` for the default page or `--full` for all seven sections. Nothing was published.

Offer the project's own review command if it has one, and say plainly that it answers a different
question — that offer is the same one step 10 makes at the end of an ordinary run.

Publishing a page and labelling the review part *pending* is the wrong answer here, for the reason
`references/report-format.md` § *Build state* gives: pending is a promise, and nothing is coming.
`.claude/CLAUDE.md` carries the design notes on what this level has to solve before it can ship —
the short version is that a code-review pass produces graded findings and this page carries no
verdicts, so a finding has to enter as a *claim to verify* rather than as a finding to display.

## Working in a worktree

Worktrees are among this skill's most common targets, and a worktree-isolated session sandboxes shell
commands: compound one-liners that chain `git` with `grep`, `&&`, or a redirect are refused as
unverifiable. Run those as separate plain commands. Budget a few extra turns for it rather than
fighting the sandbox with quoting.

## How big should the page be?

Adaptivity trims ceremony on small PRs; it does not cap large ones. A hundred-file diff legitimately
produces a long reference document — the run this guidance came from wrote ~135 KB and that was
right. The pressure while writing is always to cut, so: **do not trim a large page toward some
imagined ideal length.** Trim only content that fails its own test — a diagram that restates a table,
a paragraph without a citation, a section the diff did not earn, a review unit with nothing in
*things to understand*.

This runs in a single context by design, so a very large diff will strain it. That is a signal worth
reporting, not one to hide: if you had to skim a region to fit, say which region, in the page.

**The detail level is not a budget for this.** `--brief` produces fewer sections; it does not licence
a thinner account of the ones it does produce, and it is not the answer to a diff that will not fit.
A strained run at `--brief` still says which region it skimmed.

**Nor is `--effort high` a way to make a large diff fit** — it points the other way. The falsifier
has its own context, but every challenge it returns comes back into *yours*, and you have to open
each cited file to act on it. On a diff already straining this context, that is more pressure, not
less. Say which region you skimmed at either effort, and let the cap of six do its work: the flows
carrying the most unverifiable claims are worth the challenges, and the rest are worth the room.

## Hard rules

- Every claim carries a `file:line`, linked when a link is possible.
- **Never grade the PR.** No approval recommendation, no risk score, no confidence percentage, no
  "looks good". The reviewer decides; the page equips them. Evidence, relationships, invariants,
  uncertainty, and validation steps are the output — verdicts are not.
- **Never present inference as fact.** If the diff does not show it, the page says how you know.
- **Never invent a URL, and never invent output.** Documentation links come from
  `references/rails-docs.md`; console probes are proposed unrun, with no transcript beneath them.
- **The page must read completely with every source excerpt closed.** An excerpt confirms a claim the
  prose already made; it never carries one. A claim that exists only inside a collapsed block is
  hidden content wearing the clothes of progressive disclosure. Judge this **field by field**: a
  citation that appears elsewhere on the page does not rescue a field whose only `file:line` is inside
  the block a reader has not opened.
- **Never imply the page found everything.** It did not, and measurably so: three independent
  analyses of the same 109-file diff produced eight distinct headline findings between them, with
  only *one* appearing in all three. Explanation is reproducible; defect discovery is sampling. Say
  plainly that what the page surfaced is a pass, not an audit, and never let it read as a clean bill
  of health. Where a reviewer needs assurance rather than orientation, point them at a dedicated
  review pass.
- Never drop a file from the page to keep it tidy.
- Never post to GitHub, Linear, or anywhere outside the artifact.
- Never commit the page into the repo under review.
- **Do this work yourself; spawn no subagents — with exactly one exception, named below.** Steps 5
  and 6 span the whole diff by nature — step 5 traces consumers across both sides of the stack, step 6
  groups behaviour no single layer contains — and handing either to an agent with its own context
  moves comprehension fragmentation from the reviewer to the agents, which is the problem the page
  exists to solve. It is also slower in practice, not faster: a run that reached for one `Explore`
  agent stalled the parent for 997 seconds, 41% of its wall clock, in a single blocked turn. If the
  diff is too large to hold, say which region you skimmed — that is the honest failure and it is a
  signal worth having.

  **The exception is the falsification pass in step 8, and only at `--effort high`.** It is the one
  split that does not commit the mistake above: the seam is per *behaviour flow*, and a flow is
  already a whole behaviour rather than a layer of one, so nothing is fragmented that was not already
  separate. It is read-only, it returns challenges rather than page content — you still write every
  word — and its agents go out in a single message, so the run blocks once. Nothing else spawns
  anything, at any effort level, and a run that reaches for an `Explore` agent to help with step 5 has
  broken this rule whatever flag it was given.
