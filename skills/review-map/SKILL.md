---
name: review-map
description: Builds a published HTML review map of a pull request — what changed, the three to five judgments the reviewer has to make with the exact lines that settle each one, the order to read the code in, and what the change reaches in code it did not touch — so a reviewer can explain the change before judging it. Targets Rails and Elixir/Phoenix — a Phoenix LiveView app or a Rails or Phoenix JSON API, with or without a separate client such as Next.js. Use this whenever someone needs to understand a change rather than grade it: asks what a PR or branch does, where to start on a large diff, which files actually matter, what the change might break, whether the frontend and backend still agree, or needs to bring a reviewer up to speed on someone else's work — even if they never say "review map" or "walkthrough". Invoke with /accountable-review:review-map, optionally passing a PR number, URL, branch, or diff range. There is one page shape and no level flag: --brief and --light are accepted and change nothing, --full and --review stop the run as not implemented in this version. An effort level is separate: --effort high is the default and tries to falsify the run's own analysis before the page is written, --effort low skips that pass. Passing --output <dir> makes the run non-interactive: the page is written to <dir>/index.html as portable static HTML instead of being published, which is how CI generates one. Not for posting review comments or approval verdicts.
---

# Review Map

Turns a diff into one published page a reviewer can work from: what the change is for, which three
to five judgments it asks of them and where to look to make each one, the order to read the code in,
and what the change reaches outside the lines it touched.

**The page is a review agenda, and the deep analysis is how it is built — not what it prints.** A run
traces consumers across the whole diff, reads the tests, follows a value across the boundary and
attacks its own conclusions. What reaches the reader is the part they have to act on. Reducing the
reading obligation is the goal; reducing the analysis is the failure.

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

The procedure below relies on nine bundled files. Read each at the step that needs it rather than up
front — the procedure itself is the only part that has to be in context the whole way through.

Two of the nine come in a pair, and **step 2's stack detection picks one of each pair, never both.**
A Rails run reads the Rails lens file and the Rails catalogue; a Phoenix run reads the Phoenix pair.
Reading the other stack's file costs context and teaches the wrong searches.

| File | Read at | For |
|---|---|---|
| `references/report-format.md` | steps 1, 7, 8, 9 | The five sections, the review checkpoint, the chain component, the evidence tiers, source excerpts, impact paths, the canonical-home rule, the agenda budget and the deep-link ladder |
| `references/rails-nextjs.md` *or* `references/phoenix-liveview.md` | step 5, then while reading any layer | What a senior reviewer of **the stack step 2 detected** looks for, the runtime probes, and the search recipes for code the diff did not touch. Step 2 names it; step 5 is where it is read |
| `references/rails-docs.md` *or* `references/elixir-docs.md` | step 7, when a claim first asks for an anchor | The documentation URLs the page may cite, for that same stack. It is an allowlist, not a starting point: you look a concept up in it, you never read it to find concepts |
| `references/page-template.html` | step 9 | The design system. A run reads its **markup half** — component classes, two assembled checkpoints, the chain and the impact panel — with `scripts/page-skeleton.sh --markup`. The head, the whole token block and the page's one script are in the same file and are emitted rather than read |
| `scripts/page-skeleton.sh` | step 9, once | Writes that head, token block and script straight into the page, so none of it is read and none of it is typed. `--markup` is how the rest of the template is read |
| `scripts/diff-render.sh` | step 3, once | Says per path whether GitHub will render that file's diff, which is what decides the URL form for a line inside it |
| `scripts/excerpt.sh` | step 9 | Generates the collapsed source excerpts — the quotation has to be the real bytes |
| `scripts/ledger-rows.sh` | step 10 | Generates the diff inventory the evidence foot holds, and its deep links, from the diff |
| `scripts/coverage-gate.sh` | step 10 | Runs the completeness check |

Paths are relative to the base directory named at the top of this skill when it loads. That value is
how you reach the script — `$CLAUDE_PLUGIN_ROOT` is not set in the shell.

One thing bundled with the plugin is not a file you read: the `accountable-review:claim-falsifier`
subagent, spawned by name at the end of step 6 at `--effort high`, which is the default, and handed
one analysis note this run wrote. Its challenges are folded in at step 8. It is addressed, never
loaded — its instructions are its own, which is the point of putting them in a separate context.

## 1. Resolve the target and the effort

- Argument may be a PR number, a PR URL, a branch, or a diff range. With no argument, use the
  current branch against its base.
- **There is one page shape, and no flag chooses it.** Three flags about the shape still arrive on
  the command line, and each is handled explicitly rather than guessed at:
  - `--full` and `--review` **stop the run.** Neither is implemented in this version; see § *Two
    levels are not implemented in this version* below for what to say. Do not fall back to the
    default page and do not write one — a reader who asked for seven sections and got five would
    have no way to tell from the page that they had.
  - `--brief` and `--light` are **accepted and change nothing.** `--brief` was the name of this
    page's ancestor and an invocation someone kept in a script is not a typo; `--light` is the same
    courtesy for a reader guessing the opposite of `--full`. Take both silently.
  - An argument starting with `--` that is none of those, and is not one of `--effort`, `--output`,
    `--repository`, `--base-sha` or `--head-sha` with its value, is **reported, not guessed at**. A
    misread flag silently produces the wrong run, and the reader has no way to tell.
- **The page has a word budget, stated as guidance, and you write to it rather than trimming to
  it.** `references/report-format.md` § *The agenda budget* owns the numbers — 80 to 160 words for
  *What changed*, 50 to 140 a checkpoint, 700 to 1,500 visible words on a small or medium PR. Read
  it now, with the rest of that file, rather than discovering the caps while drafting. It caps prose
  and nothing else: no checkpoint, no citation, no evidence tier and no figure comes out for the
  budget's sake, and **the number it never touches is the checkpoint count.**
- **Read the effort off the invocation too, and hold it the same way.** One of `--effort high`,
  `--effort low`, in any position; **no flag means `high`**. It decides how hard the run works to
  be right, and at `--effort high` that buys exactly one thing today: the falsification pass —
  spawned at the end of step 6 against the analysis notes, folded in at step 8. `--effort low` opts
  out of it, and is the flag to reach for when the diff is small enough that a second reader has
  nothing to find.

  **`--effort normal` is accepted and means `low`.** It was the name of the opt-out back when it was
  the default, and a name that says *normal* for the path fewer runs take is the wrong way round.
  Take it silently rather than reporting it: an invocation someone had in a script is not a typo,
  and this is the one `--effort` value that is not guessing.

  **`high` is the default because it changes what the page finds, and it costs time it does not cost
  tokens.** Measured on one 28-file PR: the falsifiers cost **23 seconds of blocked
  parent, 0.9% of a 2607-second run**, because they run while stage 4 is drafted rather than instead
  of it. The same target at `low` missed five findings the falsified run carried, including the two
  the reviewer most needed.

  **That 0.9% is blocked wall clock and is not what the pass costs.** Each falsifier reads in its own
  context, and those tokens are the run's tokens: measured across three real runs, the pass was
  **17-23% of every cache-read token the run spent**, on 145-216 requests. Both numbers are true and
  they answer different questions — the first is why spawning them does not slow the run down, the
  second is what they add to the bill. `evals/profile.sh` prints them side by side, and the falsifier
  runs on its own model (`agents/claim-falsifier.md`) so the second number can be bought down without
  touching the first. **Effort is what decides whether the page is right, and nothing makes a run
  faster by making the page shorter** — the time goes into tracing consumers at step 5, not into
  writing sections. Three rules:
  - **It produces no section, no marker, no chip and no sentence.** Two pages of the same target at
    the two efforts differ in their claims, never in their shape, and a reader cannot tell which
    produced the one in front of them.
  - An `--effort` value that is none of the three is **reported, not guessed at** — work that
    silently differs, with nothing in the output to tell the reader which they got.
  - `--full` and `--review` stop the run at either effort. Effort implements neither.

  **Do not announce the effort** — nothing about the pass reaches the page, and step 8 says why.
- **`--output <dir>` makes the run non-interactive.** It is the only flag that changes where the page
  goes rather than what is on it: the page is written to `<dir>/index.html` and **nothing is
  published** — no `Artifact` call, at any stage. Everything else is identical, and has to be. Same
  sections, same depth rules, same excerpt budget, same gate. A CI run and a person's run produce the
  same page from the same procedure; the moment this flag starts meaning a cheaper page, there are two
  products and only one of them is developed against.

  Three flags travel with it, carrying what `gh` would otherwise be asked for:

  ```
  --repository <owner/repo>   --base-sha <sha>   --head-sha <sha>
  ```

  **Prefer them over anything you derive.** `--base-sha` is `BASE` and `--head-sha` is `HEAD` for
  every diff in this run; do not compute a merge-base over them and do not call `gh` for what they
  already say. The caller knows which revision it asked about, and a run that recomputed a base from a
  branch that has since moved would describe a revision nobody requested. With `--repository` and a PR
  number the run also has what link rung 1 needs without `gh` at all — check reachability as always,
  but do not re-derive the identity of the change. The flags are legal on their own; they simply have
  no other reason to appear.

  `<dir>` must be **outside the repository under review**, for the reason the hard rules give: the
  page must never become part of the diff it describes.

  **`$W` is unchanged by this, and that matters.** `--output` moves the finished page, not the run's
  scratch: `$W` stays the derived work directory and excerpt fragments keep landing there. Write the
  page itself straight to `<dir>/index.html` — a crash then leaves a useful page where the caller is
  going to look for one — and leave `<dir>` holding nothing else, because whatever is in it is what
  gets delivered.

  `ci/generate-review-map.sh`, at the plugin root, is the only caller today. It supplies all four
  flags, checks afterwards that the page names its revision and no longer says it is being written,
  and refuses to deliver one that does.
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
  and a line outside it links to a blob, with one exception that is settled per file in step 3 and
  not per citation. At rung 2 there is no PR page, so check the base SHA for reachability too:
  without it there is no `compare` view to anchor into.

## 2. Discover the project

Assume nothing about layout or conventions — this skill travels between repos.

**Detect the stack first**, because it decides which two of the bundled files the rest of the run
reads:

- `config/application.rb`, or a `Gemfile`, → **Rails**: the lens file is `references/rails-nextjs.md`,
  the catalogue `references/rails-docs.md`.
- `mix.exs` → **Elixir/Phoenix**: the lens file is `references/phoenix-liveview.md`, the catalogue
  `references/elixir-docs.md`.
- **More than one root, or one of each** — a monorepo with an `api/` and a `services/`, engines, an
  umbrella — **ask which to cover** rather than picking. Same rule as several Rails roots, and for the
  same reason: covering the wrong half produces a page that is confidently about code the reviewer is
  not reading.
- **Neither** — say so plainly, cover the diff with the stack-independent material (the five
  sections, the checkpoints, the tiers, the impact chains, the evidence foot), and **emit no documentation link and no
  probe.** Do not default to Rails: a Rails lens applied to a Go service invents findings, and a
  catalogue that does not describe this application is the failure both catalogues fail closed to
  avoid.

**Detecting the stack is not reading its files.** This step decides *which* pair the rest of the run
uses. The lens is read at step 5, where its search recipes are the work; the catalogue at step 7,
when a claim first asks for a URL. Nothing between here and there needs either, and both are large —
a run that opens them now carries them through the whole of steps 3 to 6, which is where the
consumer tracing happens and where the context is already largest. The versions this step records
come out of `Gemfile.lock` or `mix.lock`, not out of the catalogue.

**Backend, Rails.** Locate the Rails root by finding `config/application.rb`. It may be at the repo
root, under a subdirectory such as `api/`, or there may be several (engines, monorepo). Detect, don't
assume: RSpec vs Minitest; API-only (`config.api_only`) vs server-rendered; the authorization library,
if any; the serializer library; the background job adapter; whether `strong_migrations` is present.

**Backend, Phoenix.** Locate the Mix project by finding `mix.exs`, and read the OTP app name from it —
that is what `lib/<app>` (the domain) and `lib/<app>_web` (the web layer) are named after, and the
split is where the context boundary lives. Detect, don't assume: the `Repo` module and its adapter;
**whether this is a LiveView app, a JSON API, or both** (`live "…"` in the router versus `json`
responses, `@derive {Jason.Encoder, …}` or a `…JSON` render module); how authentication is attached
(`on_mount` inside a `live_session`, or a plug in a `pipe_through` pipeline) — the two are different
mechanisms and a route can miss either; whether Oban, Broadway or bare `Task` does background work;
whether `assets/` holds JS hooks; and whether a separate frontend application exists at all.

**Record the versions the documentation links are pinned to.** This is not bookkeeping: **every
documentation link on the page is pinned with them**, so a run that skipped this step cannot emit a
doc link at all — recording the version is this step's job, and knowing which URL to pin is
step 7's. What to record differs by stack, and so does its shape:

- **Rails** — the Rails version and its *series* from the `rails (x.y.z)` line in `Gemfile.lock`
  (`rails (8.0.2)` gives `8.0`), plus the exact locked versions of the gems above, which pin to a tag.
  One series covers the whole framework.
- **Elixir** — the **exact locked version of each package** from `mix.lock` (`phoenix`,
  `phoenix_live_view`, `ecto`, `ecto_sql`, `plug`, `oban`), plus
  the Elixir version from `.tool-versions` or `mix.exs`. There is **no series**: hexdocs serves exact
  versions, each package pins independently, and a page carrying several different version segments is
  correct rather than broken. The catalogue carries a few packages beyond that list; if step 7 asks
  for one of them, `grep` its line out of `mix.lock` then — opening the catalogue here to find out
  which names to look for is the read this step is trying not to do.

Each catalogue's § *Pinning* owns the emitted forms. The same versions also decide what the page may
**claim**, because two marks in each catalogue turn a version-sensitive behaviour into a probe rather
than a sentence.

**Frontend.** If the stack is Phoenix LiveView with no separate client application, the frontend is the
`.heex` templates and whatever sits in `assets/` — there is no second application and no generated
type to reconcile, so skip to *Conventions* and let § *LiveView* in the lens file carry the seam. A
LiveView app's boundary is the `phx-*` attribute and the callback that answers it, not a JSON contract.
Otherwise locate the client the same way — `package.json`, `next.config.*`, `app/` versus `pages/`. Then
find the seam between the two sides, because that is what a contract judgment is built from:

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
- **Ask which of those files GitHub will actually render**, at link rungs 1 and 2, and hold the
  answer for the whole run:

  ```sh
  <skill base directory>/scripts/diff-render.sh BASE HEAD --collapsed-only
  ```

  Every path it prints is one whose diff sits behind *Load diff* — a generated file, a lockfile, a
  binary, a diff past 400 lines or 20 KB — so **a citation into one of those takes the blob form even
  though the line is inside the diff**, because a diff anchor there lands on a stub with the cited
  line nowhere in the page. Nothing about the page says which files these were; the only thing that
  changes is the href, and `references/report-format.md` § *When the diff will not render* owns the
  rule, the asymmetry and what the excerpt beside such a claim has to be. Read its trailing summary
  too: past 300 files or 1 MB of diff, GitHub withholds files that are individually small, and that
  is a limit to state in prose rather than to guess at per link. At rungs 3 and 4 there are no
  hrefs, so skip this.
- If the whole diff is trivial (a few files, no migration, no new behaviour), say so and offer to
  stop rather than generate ceremony. A page nobody needs is worse than no page.

## 4. Derive what changed

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

Write each behaviour down for yourself as an actor plus a behaviour plus a path, not as a feature
name. This is the notation step 6 clusters on and step 7 builds chains from:

```
A workspace admin archives a project — new time entries are prevented, historical ones preserved.
ProjectSettings → PATCH /api/projects/:id → ProjectsController#update
  → Projects::Archive → Project → projects.archived_at
```

**That is analysis, and it is not the page.** *What changed* gets one paragraph and at most a handful
of bullets — `references/report-format.md` § *Section 1* — and the paths feed step 6's clustering and
step 7's chains rather than being published as a list. A page that opened with five use cases and
their execution paths spent its first screen on material the checkpoints then said again.

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
| A method, class or context function | Its callers, and anything that subclasses, includes or imports it |
| A column or schema field | Whatever exposes it (a serializer, a `Jason.Encoder` derive list, a JSON render module), scopes and queries filtering on it, factories and fixtures setting it, forms writing it |
| A validation, callback or changeset | Every write path that now behaves differently — `update_all` and `insert_all` bypass it in both stacks, and a second changeset function on the same schema is a second write path |
| An enum or status value | Every branch on that value, on both sides of the boundary, including every exhaustive `case` |
| A JSON key or response shape | The API client, the TS type, and every component reading it |
| A LiveView event name | Its `handle_event/3` clause, **and** every `.heex` template and JS hook that fires it. Either half can be the stale one, and no diff shows the two together |
| A route | Anything constructing that URL, including the client and any external caller — and, for a `live` route, which `live_session` block it landed in |
| A job or its arguments | Every enqueue site, plus in-flight jobs already queued with the old shape |

The lens file the stack selected in step 2 — `references/rails-nextjs.md` or
`references/phoenix-liveview.md` — carries the concrete search patterns per artifact kind. Use them;
do not improvise a grep and call the area clear.

**Record what you searched, not just what you found — but the finding goes in the open prose and the
search goes in the collapsed record.** "Nothing else calls `Project#archive`" is the finding, and it
is a sentence a reader meets without opening anything; `rg 'archive[!?]?\b' app lib` is how you know,
and it belongs in `details.searched`, shut, inside the evidence foot. Unrecorded entirely, absence and omission look identical
and the reviewer redoes the work; left *only* inside the toggle, the finding is hidden rather than
disclosed. **One row per search: the command, then what it returned in a clause** — the form and the
budget are `references/report-format.md` § *What was searched*, which owns them.

Then draw the primary flow end to end, from user action to persistence and back, and list the
secondary effects hanging off it. That flow is the run's backbone: step 6 splits it into flows for
analysis, *Impact outside the diff* shows the crossings whole, and the checkpoints are the judgments
it turns on. **Milestone 2 publishes after this step** (step 9).

## 6. Cluster into flows, write the analysis notes, spawn the falsifiers

**Group by behaviour, never by directory.** `Services / Models / Hooks / Components` is the repository's
structure, not the change's, and a reviewer who reads it still has to assemble the behaviour themselves.
Group into vertical slices instead — one per use case, each cutting through controller, service, model,
client and tests:

```
Flow A — Archiving a project
Flow B — Preventing time entries against archived projects
Flow C — Showing archived projects in historical reports
```

Say why you split it that way, to yourself. The split *is* the insight, and it is what keeps a
checkpoint from turning out to be a directory.

**The flow is the unit of ANALYSIS and no longer a unit of the page.** Nothing below writes a flow
section: a flow becomes a note, the note is what gets attacked, and step 7 turns notes into the three
to five judgments the reader actually gets.

Then label each flow and each leftover file, for your own ranking in step 7 — the label reaches the
page only as what *What changed* leads with and what the agenda leaves off:

- **Primary** — directly implements the stated use cases.
- **Supporting** — refactors or infrastructure the primary behaviour needed.
- **Secondary** — independently reviewable, outside the primary mental model.

**Stay neutral about secondary work.** The point is to tell the reviewer which changes they can hold
separately, not to criticize the author for bundling. "Appears unrelated to archival; no correctness
concern identified; review independently" is the whole register.


### 6b. Write one analysis note per flow

Before anything is synthesised, write `$W/analysis/flow-<x>.md` for each flow — plain markdown, no
page markup. It is the record the falsifier attacks and the record step 7 ranks from, so it is
written for both readers at once: complete, cited, and dull.

Each note carries, under these headings:

- **Behaviour** — the actor, the behaviour and the path, from step 4.
- **Trace** — every hop with a `file:line`, in execution order, and the hunk each changed hop turns
  on.
- **Affected, not changed** — one entry per finding: `path:line`, the clause on why the change
  reaches it, and its evidence tier written out (`diff`, `from unchanged code`, `inferred from
  tests`, `inferred`, `uncertain`). Write the tier on **every** entry here, the `diff` ones included.
  On the page silence means the first tier; in a note silence is a claim nobody labelled, and the
  falsifier is told to treat it as one.
- **Searched** — one line per search, the command then the result clause, in the form
  `details.searched` will take.
- **Tests** — which behaviour each pins, which branch it leaves open.
- **Open** — what you could not establish, and what would settle it.

**Why a file and not a slice of the page.** The falsifier used to be handed a published
`<section id="flow-x">`, which meant a flow was wrong in public for as long as a challenge took to
arrive, and meant the agent read markup, excerpts and a rail to find the claims. A note has neither
cost. It also survives the run: on a diff that strains the context, `$W/analysis/` is what says which
region got a trace and which got skimmed.

### 6c. At `--effort high`: send the falsifiers at the notes

Everything so far is this run checking its own work. That is the weakest kind of check — the context
that wrote a claim is the one least able to see what it assumed. At `--effort high` the notes get a
second reader whose only job is to break them.

**When.** Here, as soon as the notes are written, and **before any of it reaches the page.** That is
the whole reason this moved: the pass used to run after the flows were published, so a corrected
claim had been public for as long as the challenge took to arrive.

**How.** One `accountable-review:claim-falsifier` per note, **all spawned in a single message.**
This is the one exception to the rule against subagents in § *Hard rules*.

**Then keep working — do not wait on them.** They come back as notifications, not as a blocked turn,
and the parent's job in the meantime is step 7. Measured on a real run: five falsifiers launched over
23 seconds, each returning a launch receipt in about 2 seconds, with the first challenges arriving
365 seconds later while the parent drafted. Blocked time was **0.9% of the run**. A run that spawns
them and then idles has converted the cheapest thing in this procedure into the most expensive.

**Cheap in wall clock is not cheap in tokens, and the cap is what holds the second one down.** Each
falsifier reads in its own context, and across three real runs the pass came to **17-23% of every
cache-read token the run spent** over 145-216 requests — the most expensive thing in the procedure
after step 5, and invisible in the parent's transcript. That is the cap's real job: six agents is the
point past which a second reader stops paying for itself.

Spawn them in one message anyway. It costs nothing, it keeps the challenges arriving together rather
than trickling, and if a future harness does make them block, one message stalls the run once — for
the slowest — where the same agents one at a time stall it once each. That is not hypothetical: a run
that reached for a single blocking `Explore` agent paid 997 seconds, 41% of its wall clock, for one
sequential spawn.

Give each agent three things and no more: the repository path, `BASE` and `HEAD`, and **the path of
that one note**. Not the whole set — a falsifier holding every note is one long blocked turn again,
and it has no way to tell which claims are its to attack.

**Cap it at six.** Past that, take the notes carrying the most *affected, not changed* entries and
the most `inferred` and `uncertain` tiers. Those are the claims a reader cannot check cheaply, which
is the only reason to spend an agent on them.

## 7. Synthesise the agenda

The notes are the analysis. This step turns them into the page's argument, and it is a step of its
own because the failure it prevents is structural: a run that goes from notes straight to prose
writes one section per flow, which is the page this one replaced.

Nothing here opens a file the notes have not already cited. The work is deciding, not tracing. Do it
in this order, and write the outcome of each part into `$W/analysis/agenda.md` before moving on — the
falsifiers' challenges are arriving while you do this, and a written agenda is what lets step 8 fold
one in without re-deriving the ranking.

**7a. Name the semantic delta.** One sentence: what is true of the system after this change that was
not true before, in behavioural terms. Not what files moved — what a user, an operator or a
downstream caller now experiences differently. If the notes support two unrelated sentences, the PR
bundles two changes and *What changed* says so, neutrally. This sentence is the spine of section 01,
and every checkpoint has to be a judgment about it.

**7b. Identify the human judgments.** For each note, ask what a competent reviewer has to *decide*
rather than *learn*: whether a scope is still the one that was intended, whether a nil default is
safe for every consumer, whether a guard's new order admits a class it used to refuse, whether a
migration is safe to run against the rows that already exist. Write each as a question.

A judgment is something the reviewer could get wrong, with consequences. A fact is something they
read once. Facts feed the explanations; only judgments become checkpoints.

Some judgments hide outside any one flow, and a flow-by-flow reading is exactly what misses them.
`references/report-format.md` § *The review checkpoint* carries the list to ask against — migration
safety, an application invariant with no database counterpart, the authorization model, deploy
ordering, test infrastructure, agentic tooling, jobs and flags and environment variables and
transaction boundaries. Each is a checkpoint only if it is a judgment for *this* diff; the list is a
prompt, not a form.

**7c. Merge related observations.** A constructor change, the nil default it introduces and the two
consumers that do not handle nil are one judgment — *is nil safe here?* — not four observations.
Merge until each candidate is a single question whose answer settles everything under it.

This is where the agenda gets short honestly. Three observations that share a question are one
checkpoint, and a run that lists them separately has written the same judgment three times.

**7d. Rank.** Order the candidates by four things, in this priority: the consequence if the reviewer
misunderstands it; how uncertain the notes are about it, because the reviewer's attention is worth
most where the page's own evidence is weakest; how far it sits from the obvious reading of the diff,
since a consequence visible in the hunk needs less help than one three files away; and how important
the affected unchanged code is.

**The order is the order to think about them, and it is not a scale.** No number that reads as
severity, no *high* or *low*, no *blocking*, no *watch*. The rail and the reading path refer to a
checkpoint by its question.

**7e. Select the smallest useful agenda.** Three to five checkpoints. Fewer for a PR small enough
that three would be padding — a run that reached this step on a diff step 3 nearly stopped for may
have one. Ask: *if the reviewer understood and investigated these, would they have the right mental
model of this change?* If yes, stop.

A sixth candidate is a signal to merge again, not to add a sixth; if it will not merge, the checkpoint
nearest to it names it in one clause. **A finding that does not become a checkpoint is not lost** —
affected code keeps its entry in *Impact outside the diff* or in the evidence foot, and the sampling
caveat under the heading is what makes leaving a judgment off honest rather than hidden. What is never
done is dropping a checkpoint to hit a word count: § *The agenda budget* is guidance on how a
checkpoint is written, never on how many there are.

**7f. Choose each checkpoint's representation.** Every checkpoint has a question and an explanation of
two to four sentences. Then decide whether it also earns a chain, and how many *Look at* entries it
needs.

**The chain is earned when the judgment turns on a mechanism the reader cannot hold from prose** — a
guard order, a value derived across three or more hops, a request path with a branch in it. Ask it
affirmatively rather than looking for an excuse: *if the explanation would have to name three hops in
sequence, draw them.* It shows that mechanism **inside the change**, so if the chain you want to draw
crosses into unchanged code, it is an impact path: it belongs in section 04, drawn once, and the
checkpoint says so in a clause.

Diagram and prose have different jobs. The chain says how the value gets there; the explanation says
what the reader has to judge about it. **An explanation that walks the chain node by node is the
defect** — it doubles the length and teaches nothing twice, and it is what a run reaches for when it
is unsure the figure landed.

**7g. Select the evidence.** For each checkpoint, take only what is needed to investigate it:

- Which citations are load-bearing for the judgment. Those get a collapsed excerpt beside the *Look
  at* entry they confirm, generated in step 9.
- Which claims carry an evidence tier.
- Whether a probe would settle the question — a `pre.probe`, proposed and never run, inside the
  checkpoint after its explanation, with any setup it needs beside it. There is no separate
  validations section to send it to.
- Whether a doc link explains why the framework consequence follows. At most one `a.doc` per
  checkpoint, and never on a claim with no `file:line` beside it.

**The catalogue opens here** — `references/rails-docs.md` or `references/elixir-docs.md`, whichever
step 2 named, and not before. It is a lookup table: you go to it with a concept a claim already
needs, never read it to find concepts. Read its § *Version* first; a closed catalogue returns *no
link* for every concept, and a page with no doc link is narrower rather than wrong.

**Tests and author questions are facets, not sections.** A test appears inside a checkpoint when it
changes how the reviewer judges it — *"the spec at `:88` pins the admin branch and leaves the invitee
branch open"* — and a list of the specs that touch the file does not appear at all. An author question
goes on the checkpoint's `p.open` line.

**7h. Build the reading path.** Three to seven stops, in the order that builds understanding — schema
before the code that trusts it, the smallest complete example before the bulk, irreversible code last.
Each stop is a path, one sentence on why here, and a link to the checkpoint it belongs to. It is built
after the agenda because it is a route through the agenda. Ask, per stop: *what does the reviewer have
to understand first for the next file to make sense?*

**7i. Identify the external impact.** One to three paths from the notes' *affected, not changed*
entries: each starts in changed code, passes through at least one unchanged consumer, and ends at
something a user or an operator would see. Choosing the third-best over the fourth is the work; the
fourth keeps its entry below the figure or in the foot. **If nothing crosses into unchanged code,
section 04 is omitted and the rail loses its entry** — an empty section saying nothing reaches
unchanged code reads as a clean bill of health.

**7j. Deduplicate.** *What changed*, a checkpoint's explanation, a chain, the reading path and the
impact section can all mention the same scope. Each occurrence must serve a **different purpose** —
intent, judgment, mechanism, route, consequence — and be one clause wherever it is not the canonical
home. Read `references/report-format.md` § *One canonical home* for the routing table, then read your
agenda once looking only for the second time anything is explained.

Two rules keep this from becoming ceremony:

- **A checkpoint is a judgment, never a category.** *Controller changes* is a directory; *Does the
  new filter preserve the intended scope?* is a question a reviewer can get wrong. If a candidate
  cannot be phrased as a question the reviewer answers by looking at the code, it is an explanation
  and belongs in a sentence somewhere else.
- **Validation steps must be real.** The actual rake or mix task, the actual route, the actual
  factory in this repo — a command a reviewer can paste. Invented steps are worse than none, because
  they burn the reader's trust in the whole page on the first paste that fails.

**Milestone 3 opens after this step** (step 9), with one pending stub per checkpoint.

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
- **A correction replaces the claim; it never annotates it.** Whatever made you revise something
  already written — a second reading of the file, a falsifier challenge, a search you re-ran — the
  page ends up carrying the corrected claim in the present tense, in its own voice, as though it had
  always said that. The page never tells the reader what an earlier draft of it said.

  **Keep the fact, drop the autobiography.** This is the half that gets over-applied: if a recorded
  search needs `-P` to reproduce, the reader who re-runs it needs that caveat, and it belongs on the
  search's own line as a caveat. What does not belong is the story of the pattern that returned
  nothing. Correct the claim, keep what a reader would need, and say what changed to the user in
  chat.

  This one is written without noticing, because it reads as candour rather than as advertising —
  which is exactly the disguise a page forbidden to claim assurance is vulnerable to. One real page
  carried ten of them: *"the mistake the first version of this section made"*, *"the first pass ran
  this over `app/views` alone and found six"*, *"seven controllers, not the four the first pass
  reported"*. Every one of those sentences had a true and useful fact inside it and buried it in the
  run's own history. Note that this repository's prose is deliberately written the *other* way — a
  rule here states the observation that produced it — and that register is right for whoever edits
  the skill next and wrong for the page. The reviewer is reading about a pull request; how this
  document got drafted is not part of it. `evals/checks/page-invariants.rb` § 2c fails a page that
  does it.

### Fold the falsifiers' challenges in

At `--effort high` the falsifiers were spawned at the end of step 6 and have been reading while you
synthesised. Their challenges are the second half of this step.

**When.** Before a checkpoint's stub is replaced with the written thing, read whatever has landed for
the notes it draws on. Draft in ranked order; if the next checkpoint's note still has a falsifier out,
draft the one after it. If every checkpoint is drafted and one agent is still out, publish — the rules
above ran on your own reading of the files — and fold the late challenge in as an `Edit`. **Never
idle waiting**: the 0.9% holds only because the parent works while they read.

**A challenge is a claim to verify, not a finding to accept.** This step's first rule applies to the
falsifier exactly as it applies to you: open the cited file yourself. Then correct the note and the
checkpoint that draws on it, downgrade the evidence tier, or drop the claim — and do not backfill a
dropped claim with something weaker. A challenge you cannot confirm is dropped, the same as any other
finding that does not survive.

Corrections land as `Edit`s on the checkpoint already in the page, when one is, never as a rewrite of
it (step 9).

**Nothing about the pass reaches the page.** Not a sentence, not a marker, not a count of what it
corrected. Two reasons, and both are hard rules already: a tally of corrected claims grades this
page's own draft, and a page advertising that it was checked reads as the clean bill of health the
page must never be. Say what changed to the user, in chat, and leave the artifact silent.

**The form this actually takes never mentions the pass at all.** It is *"the first version of this
section got it wrong"* — a correction annotated with the history that produced it, which is this pass,
narrated. A run reads that as honesty and writes ten of them. The rule against it is the correction
rule above, and it applies to every claim you revise here: fix the sentence, keep the caveat a reader
would need, and let the draft history go.

**A checkpoint is published only after the analysis under it has been attacked**, which is what moving
the pass ahead of the page bought. What remains is the late challenge, and the rule for it is the one
above: a claim retracted before the final publish beats one that is never retracted.

## 9. Write and publish in stages

A large diff takes many turns to explain, and a reviewer holding a ticket does not want to wait for
all of them. Publish early and republish as parts complete: **the same file path every time, so the
URL never changes.** The reader can open it at minute two, watch it fill in, and start reading the
moment the part they need lands.

The mechanics are simply the `Artifact` tool's: republishing the same file path redeploys in place.

**Non-interactively (`--output`, step 1) there is nothing to publish, and no reader waiting.** The
stages stop being arrivals and become save points: write each one to `<dir>/index.html` as it
completes, with `Edit` rather than a rewrite exactly as below, and skip every `Artifact` call. Keep
writing them — a run that dies two thirds of the way through leaves a page worth having, which is the
other reason staging exists — but do not spend a turn announcing a boundary nobody is watching. The
banner and the markers still come off at the end: step 10 is unchanged, and the CI adapter refuses to
deliver a page still carrying one.

**Four milestones.** Each is a coherent thing to read, which is the point — a URL that changes under
someone mid-paragraph is worse than one that arrives late.

| Stage | After step | The page holds |
|---|---|---|
| 1 · Orientation | 4 | The skeleton, written once by `page-skeleton.sh`; then the masthead and *What changed*, with sections 02 to 05 marked pending |
| 2 · Impact | 5 | *Impact outside the diff* — or, when nothing crosses into unchanged code, its stub and its rail entry removed |
| 3 · Agenda | 7, then per checkpoint | Section 02's heading, its one caveat sentence, and one pending stub per checkpoint carrying its question. Then each checkpoint replaces its own stub as it is written |
| 4 · Complete | 10 | *Read the code in this order*, the evidence foot, gate passed, build banner and every marker gone |

**At `--effort high` the falsifiers were spawned at the end of step 6 and fold in during stage 3** —
see step 8. They add no milestone: they produce corrections to analysis, not an arrival worth opening
the tab for, and the reader never learns they ran.

**The checkpoint is the unit of staging, not section 02.** Section 02 is the bulk, so a stage that
delivered it whole would put the longest wait of the run behind one arrival — which is the shape
staging exists to avoid. Nothing new is needed to split it: `<section id="attention">` carries the
heading and the caveat, and each checkpoint is already its own nested `<section class="cp" id="cp-x">`
with a unique `id`, which is exactly the anchor a later stage edits. The rail already renders a
per-checkpoint marker — take it and the pending stub from `references/page-template.html` rather than
inventing markup.

So stage 3 **opens with a cheap publish**: the heading, the caveat, and one stub per checkpoint whose
line of substance is **the question**. That arrival is worth having on its own — a reader learns what
the judgments *are* before any of them is written, which is most of what they came for. Each
checkpoint then lands in its own republish. Two rules keep this from becoming a republish per
paragraph:

- **One publish per checkpoint that lands, not per edit.** If two land in the same turn, one publish
  covers both. That bounds the arrivals by turns, which is the right bound: the turn is what a reader
  waits through.
- **Step 8 is the gate on each of them.** More publish boundaries means more gates, not a looser one.
  A checkpoint is published when it is verified, not when it is drafted.

*Read the code in this order* and the evidence foot land together in stage 4, and that is not
inconsistency: the reading path is a route through the checkpoints and cannot precede them, and the
foot belongs to step 10's gate. A stage has to be worth opening the tab for.

**Write to the budget as you draft, not by editing it back down afterwards.** `report-format.md`
§ *The agenda budget* has the numbers, and a stage that overspends and then compresses pays for the
same prose twice — once streamed, once re-edited — which is the cost step 9 exists to avoid. It also
compresses in the wrong direction: cutting a drafted paragraph tends to take the clause a claim
rested on, where writing to the cap takes the sentence that was never needed. Nothing there is
negotiable against a figure: the count exempts every chain label, every `<code>` and `<pre>`, and
everything inside a collapsed block, so a long page is never fixed by dropping a drawing.

**The page fills in out of document order, and that is fine.** Step 5 produces the impact section;
step 7 produces the checkpoints. So section 04 lands while section 02 is still stubs, and a reader
arriving at stage 2 sees a gap above written material — and once stage 3 is under way, a written
checkpoint sits above a pending sibling. The pending marker is what makes both readable — the risk the
build state exists to prevent is an unwritten section looking like an empty one, not a section
arriving early.

Saving as each checkpoint completes has a second payoff worth stating: a crash then leaves a useful page
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

**Write *Read the code in this order* last of the prose sections** — which is why it sits in stage 4
above. It is a route through the checkpoints and an index into them, so it cannot be written before
they exist without being guessed at.

**The banner is what makes this honest.** An unfinished page that looks finished is a worse artifact
than no page at all: a reviewer sees no cross-cutting section, concludes there was nothing to say
about it, and moves on. It was simply not written yet. So until the final publish the page carries a
build-state banner naming which sections are still pending, and every pending section appears in
the rail and in place as an explicit *pending* marker — not as an absence, and not as an "N/A"
placeholder. The two look nothing alike on purpose. `references/report-format.md` § *Build state*
has the form.

**Pin the title and favicon at the first publish** and do not change them, even if your understanding
of the PR improves. Readers find a tab by its name and icon; a page that renames itself mid-run reads
as a different page. The title is pinned earlier than that and by the script — `--title` substitutes it
into the head and HTML-escapes it, which a PR title containing an `&` needs — so do not write it again.
Everything else about writing holds at every stage:

- Follow `references/report-format.md` for the five sections, when each appears, how deep it goes,
  and the rule that each fact has one home. Follow `references/page-template.html` for the design
  system and the components — read with `scripts/page-skeleton.sh --markup`, which prints the
  component half and leaves out the 54 KB you are about to be given for free.

  **The rail you are given is the rail to publish.** Copy it; do not renumber it. Remove the 04 entry
  only when step 7i found nothing crossing into unchanged code, and then remove the section with it.
- **Write the skeleton once, before anything else in stage 1:**

  ```sh
  <skill base directory>/scripts/page-skeleton.sh --out "$W/page.html" --title "<PR title or branch>"
  ```

  That puts the head, the entire token block and the page's one script into the file already. Then
  the first `Edit` replaces its one-line body placeholder with the rail, `<main>`, the build banner,
  the masthead and section 1. It refuses with exit 3 if the page already has content, which is the
  guard against re-running it over a page a reader is already looking at.

  **Never write a `<style>` block, a `:root`, a colour, or a `<script>` into the page.** They are
  already there and **you have not read them** — so a token you name is a token you guessed, and a
  second declaration of a colour is a second canonical home for it. This is the same rule as the one
  below about excerpts, for the same reason: bytes a script generated are bytes you must not retype.
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
- **Figures are components, and there is no `<svg>` on this page.** Two figure vocabularies exist and
  the template assembles both: the vertical labelled chain — `figure.impact` in section 04,
  `figure.chain` inside a checkpoint — and the `dl.ba` before/after pair. Build them from the
  template's markup. `report-format.md` § *Chains* owns the node kinds, the causal vocabulary and the
  rule that decides which of the two figures a given chain is; § *Impact paths* owns the panel's own
  caps and owns them alone.

  What this replaced was four SVG layouts worked out to scale in the template. They cost more than
  they carried: an `<svg>` is the most expensive thing on a page to type, so the characteristic
  failure was never a wrong drawing but **no drawing** — two real pages published nine flows and zero
  figures with the layouts sitting readable in the template the whole time. A component reflows on a
  phone, has no canvas to overflow, and cannot be drawn wrong. The only thing left to get wrong is
  whether the edges are true, which is the part worth your attention.
- **A checkpoint chain shows mechanism inside the change, and holds no affected-unchanged node.** A
  request path, a value derived over several hops, the order guards run in — `.ip-chg` and `.ip-step`
  nodes ending at one `.ip-out`. The moment a hop lands in unchanged code whose meaning the change
  altered, it is an impact path: draw it once in section 04 and let the checkpoint say so in a clause.
  Redrawing it there is the canonical-home regression arriving as a figure.
- **Inherit the markup, never the strings.** Every label in the assembled examples is a claim about a
  file, and a claim copied out of a specimen is a false claim nothing catches — a run once inherited
  a specimen's last box caption onto a component that never touches the field, and only a reader
  comparing the figure with the code noticed.
- **An impact path ends at a behaviour, and passes through unchanged code on the way.** The panel is
  1–3 chains, **each in its own `.ip-card`**, each starting in the diff and ending at something a
  user or an operator would see, with every hop carrying its causal verb — *reads*, *falls back to*,
  *filtered out by*. A chain that stops at a function has not reached a consequence; a chain with no
  unchanged node is a call stack inside the diff, and belongs inside the checkpoint it explains. And
  it carries **labels, not sentences**: the `file:line` and the clause belong to the affected entries
  below it. The panel this replaced was a grid of boxes, and every real page filled the boxes with
  prose to supply the relation the layout could not express — which is the failure to watch for
  coming back.
- **Three paths, not five, and one per card.** Choosing the third-best consequence over the fifth is
  the work here: the two that do not make the panel are not dropped, their entries are in the
  affected list below it or in the evidence foot, and their explanation is in the checkpoint that
  turns on them, if one does. A run that stacks four or five chains inside one card has rebuilt the
  panel this replaced, where the reader on the third chain has the first one's geometry behind them.
- **Generate source excerpts, do not type them.** An excerpt sits collapsed **beside the claim or the
  *Look at* entry it confirms** — never in a block of its own, and never in the evidence foot. What
  earns one is a citation the judgment turns on: the lines a reader would otherwise take on faith,
  above all *affected, not changed*, which no diff view can address, and the changed hunk where
  seeing it is what makes the judgment possible. Quote inline as collapsed excerpts, from the
  generator:

  ```sh
  <skill base directory>/scripts/excerpt.sh --at app/models/project.rb:41-52 --base BASE --why "..."
  <skill base directory>/scripts/excerpt.sh --diff app/models/project.rb --base BASE --why "..."
  ```

  An excerpt is a *quotation*, and that is why it is generated. A mistyped ledger row fails the gate
  loudly; a paraphrased quotation is a false quotation, and nothing in the page or in the reader's
  experience catches it. The script reads the real bytes and does the HTML escaping, which matters
  more than it sounds — ERB, TSX and HEEx are full of `<`, `>` and `&`. It also tags the `--source` block
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

  **Both forms need `--base`, including `--at`**, because the state tag in the summary is a claim
  about the diff and the script reads it off the diff rather than assuming it — a changed file quoted
  at head is tagged `At head`, not `Unchanged`. It is the one part of an excerpt the bytes cannot
  vouch for: before it was derived, a run published a changed `db/structure.sql` labelled Unchanged on
  a page whose own ledger listed it as changed. Quoting a changed file that way is right where a hunk
  cannot show what the committed code permits; the tag is what has to be true.

  Two rules travel with them. The page must read completely with every excerpt **closed** — that one
  is a hard rule below, and it is judged entry by entry, not page-wide. And an excerpt is earned by a
  citation that is **load-bearing for a decision the reviewer has to make**, not by a citation merely
  pointing at unchanged code — otherwise every affected entry earns one automatically and the budget
  caps nothing. There is no per-section floor: a checkpoint about a changed guard quotes the guard
  because the judgment turns on it, not because a rule says every part of the page shows its diff.

  **Do not carry a number in your head for this.** The budget, the locations excerpts may appear in,
  and how the link rung changes it all live in `references/report-format.md` § *Source excerpts*, and
  they live there only — an earlier version of this bullet restated the cap in slightly different
  words and the two drifted apart within one run.
- **Pin every documentation URL to the version this app runs**, using the versions recorded in step 2.
  Both catalogues store paths with no version segment; a link that reaches the page without one
  silently means *current stable*, which is how a 7.1 app gets handed 8.1 documentation. What gets
  substituted differs: Rails pins **one series** for the framework and an exact tag per gem, while
  Elixir pins **each package's exact locked version independently**, so a correct Elixir page carries
  several different version segments and that is not a defect. Where the catalogue has no verified path
  for this app's version, **emit no link** — explain it in prose and cite the repo line. Each
  catalogue's § *Pinning* owns the forms and the overrides.
- **A `‡ probe` row may not be asserted.** Those are behaviours that changed inside the supported
  range, so no sentence about them is true of every app. Name the setting or the version that decides
  it and propose a probe; the page asks rather than tells. A `‡ since X` row is stated as the default,
  naming X. Each catalogue's § *What the marks mean*.
- **Take every documentation URL from the catalogue step 2 selected, and never construct one.** You
  cannot check a URL from here — there is no fetch step, and the sandboxes this runs in commonly block
  those hosts — so a plausible-looking API path is a 404 the reader finds on your behalf, which costs
  the same trust as an invented rake task. A concept the catalogue does not carry is explained in prose
  with the repo citation it applies to; that is the ordinary outcome, not a failure. The rules and the
  budget are in `references/report-format.md` § *Framework anchors*, and they live there only.

  **A catalogue can also be closed as a whole**, and one currently is: `references/elixir-docs.md`
  § *Version* withholds every link until a verification run dates it. Read that section before
  emitting an Elixir doc link — while it is closed, the answer for every concept is *no link*, and an
  Elixir run anchors with probes and prose instead. This is the fail-closed rule at file scope, not a
  bug to work around.
- **A probe is proposed, never run.** Do not boot the application under review. The page shows the
  command; it never shows output, because there is none to show — and a fabricated `=>` or
  `{:ok, %Project{}}` line is the most concrete-looking thing on the page and the one part of it that
  is fiction. Name which runner the snippet wants — `bin/rails runner` or `bin/rails console --sandbox`
  in Rails, `mix run -e` or `iex -S mix` in Elixir — and say when a write needs wrapping, because
  **Elixir has no sandbox console**: anything that writes goes inside
  `Repo.transaction(fn -> …; Repo.rollback(:probe) end)` or it changes the reviewer's database.
  Use the project's real constants and module names: a probe naming a scope or a context this repo does
  not have is an invented command.
- Render citations in the rung chosen in step 1. Inside a rung the form is not a preference: a line
  the diff contains gets the PR diff anchor, so the reviewer lands in the review they are already
  working in rather than in the file at head, where nothing marks what the line replaced. A line the
  diff does not contain gets a blob permalink at the SHA that line actually exists at — head for
  unchanged code, base for code the change removed or for behaviour described as it was. Both forms,
  and the rung table, are in `references/report-format.md` § *Deep links*.

  Two things decide the rest of the href, and both are mechanical. A line in a file step 3 listed as
  **collapsed** takes the blob form despite being in the diff — § *When the diff will not render*.
  And **a citation that names a range links the range**: `:51-72` under an href ending at `R51`
  promises a span and delivers a line, with nothing on the page to say the two disagree. `R51-R72`
  in a diff anchor, `#L51-L72` in a blob, both ends on the same side.
- The page lives at `$W/page.html` — the work directory derived in step 1 — and never in the repo.
  `page-skeleton.sh --out` creates it; every stage after that edits it in place.
  The page must never become part of the diff it describes. Excerpt fragments go in the same
  directory, so splicing them in is a path away rather than a move. With `--output` the page is
  `<dir>/index.html` instead; the fragments still go in `$W`, and nothing but the page belongs in
  `<dir>`.

Tell the user the URL when stage 1 goes out, say it will fill in, and do not repeat it on every
republish — one link, mentioned once, then a note when it is complete. With `--output` there is no
URL: say where the file is, once, and nothing more.

## 10. Complete the page and gate it

- **Remove the build banner and every pending marker** — including the per-checkpoint stubs and the
  rail's checkpoint markers from stage 3. A finished page still carrying "2 parts still pending" is the worst
  outcome of staged delivery: it undersells work that is actually done, and the next reader cannot
  tell whether you stopped early or forgot the banner. If a section really was left unwritten, say so
  in prose as a stated limit — that is a different sentence from "pending".
- **Generate the inventory, do not type it.** Run the bundled generator from the repository under
  review and paste its cells into `div.gt.gt-paths` inside `details.evidence`, the shut disclosure
  below the last section:

  ```sh
  <skill base directory>/scripts/ledger-rows.sh BASE HEAD --paths-only
  ```

  One cell per path, each with its `data-path` attribute already set and preceded by a hint comment
  carrying the git status letter and line counts. No section, no attention level, no group: those
  three judgements were a classified ledger the page no longer carries. Where a reviewer's attention
  goes is said by what is on the reading path, and saying it again in a column beside every file was
  the second inventory section 04 is told not to become — on a real page, 24 links above a caption
  explaining that the eight worth opening were ranked elsewhere.

  **It does not go in section 04.** That section is about consequences, and a list of every changed
  file inside it is exactly the shape above.

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

  The gate runs once, here, against the finished page. The inventory being **collapsed** is legal —
  it is provenance, and an inventory passes the reads-complete-when-shut rule where a finding never
  would — but collapsed is not optional, and neither is the gate: a run that skipped it because the
  path list is out of sight has turned a shorter page into one that may have dropped a file. Earlier
  stages ship with the list visibly marked partial; a gate that passed on a partial list would mean
  nothing.
- Confirm the page renders: no horizontal overflow on `body`, chains and wide tables fit or scroll
  in their own container, and all three theme states resolve (`data-theme="dark"`,
  `data-theme="light"`, and the unstamped `prefers-color-scheme` default most viewers get). The design
  is warm-paper light; the dark half is ours, so a colour declared in only one place is a bug the
  reader sees and you will not.
- Carry the template's `<script>` block across **verbatim, and add nothing to it** — including the
  three `<script src>` lines above it (the core bundle plus the `erb` and `elixir` grammars, neither of
  which is in the common bundle). It is a scroll-progress bar, a rail scroll-spy and the syntax tint on
  unchanged excerpts: presentation only, and the page reads correctly with the whole block deleted, in
  one ink. Do not give the checkpoints checkboxes, tick state or an "n of m" counter — a count of cleared items
  reads as progress toward approval, which is the verdict this page does not carry.
- Publish the final state to the same path — or, with `--output`, simply leave the finished file at
  `<dir>/index.html`; there is nothing to publish and nothing to remember. Report that it is complete,
  what the change does in two or three lines, and anything you could not verify. Mention the project's
  own review command if it has one.
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
- The evidence foot's summary says the gate did not run, and warns against reading the written
  sections as a full account of the diff.

`evals/check.rb --stopped` checks all four. This is the third legitimate state of the page, alongside
in-progress and complete, and the only one that requires a deliberate edit rather than a deletion.

## Two levels are not implemented in this version

`--full` used to write seven sections, and `--review` was meant to run the project's code-review pass
as well and thread its findings through the map. Neither exists in this version, and no effort level
implements either: `--effort high` falsifies this run's own analysis, which is a different job from
importing someone else's findings. **Stop, and say so** — do not fall back to the default page and do
not write one:

> `--full` and `--review` are not implemented in this version of review-map. Re-run without a level
> flag for the review agenda: what changed, what needs your attention, the order to read the code in,
> and what the change reaches outside the diff. Nothing was published.

`--brief` and `--light` are the opposite case — accepted, silent, and without effect, because the
default page is already the short one and a script that still passes `--brief` should keep working.

Offer the project's own review command if it has one, and say plainly that it answers a different
question — that offer is the same one step 10 makes at the end of an ordinary run.

Publishing a page and labelling the missing part *pending* is the wrong answer here, for the reason
`references/report-format.md` § *Build state* gives: pending is a promise, and nothing is coming.
`.claude/CLAUDE.md` carries the design notes on both, and `references/report-format.md` § *A future
full mode* records which components this page put down and where their rules would return.

## Working in a worktree

Worktrees are among this skill's most common targets, and a worktree-isolated session sandboxes shell
commands: compound one-liners that chain `git` with `grep`, `&&`, or a redirect are refused as
unverifiable. Run those as separate plain commands. Budget a few extra turns for it rather than
fighting the sandbox with quoting.

## How big should the page be?

Short by design and long by exception, and the two are governed differently.

**Prose is governed by guidance**, in `references/report-format.md` § *The agenda budget*: 80 to 160
words for *What changed*, 50 to 140 a checkpoint, 700 to 1,500 visible words on a small or medium PR.
A hundred-file diff legitimately runs past those numbers — but not by adding checkpoints. Five is the
ceiling and a sixth is merged or named in a clause; what a big diff buys is more *Look at* entries
per checkpoint, the impact figure's third card, and an inventory that grows with the diff at no cost
to anyone, because it is collapsed.

**Trim only content that fails its own test** — a chain whose explanation walks its nodes, a *Look at*
entry with no clause, an explanation that restates *What changed*, a checkpoint that turns out to be
a category. Never trim toward an imagined length, and **never trim a checkpoint out**. A page that
came in under the numbers by losing a judgment has done the one thing the budget forbids; the numbers
are what to argue with, never the agenda.

This runs in a single context by design, so a very large diff will strain it. That is a signal worth
reporting, not one to hide: if you had to skim a region to fit, say which region, in *What changed*,
in the same voice as any other stated limit. `$W/analysis/` is what shows which flows got a trace and
which got a glance.

**`--effort high` is not a way to make a large diff fit** — it points the other way. The falsifier has
its own context, but every challenge it returns comes back into *yours*, and you have to open each
cited file to act on it. On a diff already straining this context, that is more pressure, not less.
Say which region you skimmed at either effort, and let the cap of six do its work: the notes carrying
the most unverifiable claims are worth the challenges, and the rest are worth the room.

## Hard rules

- Every claim carries a `file:line`, linked when a link is possible.
- **Never grade the PR.** No approval recommendation, no risk score, no confidence percentage, no
  "looks good". The reviewer decides; the page equips them. Evidence, relationships, invariants,
  uncertainty, and validation steps are the output — verdicts are not. **The checkpoints are ordered
  and an order is not a scale**: no number beside a question, no *blocking*, no *watch*. The line that
  names an unresolved thing is labelled *Open question* and nothing else.
- **Never present inference as fact.** If the diff does not show it, the page says how you know.
- **Never invent a URL, and never invent output.** Documentation links come from the catalogue the
  stack detected in step 2 — `references/rails-docs.md` or `references/elixir-docs.md` — and from
  nowhere else, including when that catalogue is closed and the answer is no link at all. Console
  probes are proposed unrun, with no transcript beneath them. There is no exception: the page never
  shows a result line, because the run never booted the application, and a fabricated `=> …` is the
  most concrete-looking thing on the page and the one part of it that is fiction.
- **The page must read completely with every collapsed block closed.** Three components collapse — a
  source excerpt beside the entry it confirms, `details.searched`, and `details.evidence`, the foot
  that is section 05 — and the rule is the same for all three: they confirm a claim the prose already
  made, and never carry one. A claim that exists only inside a collapsed block is hidden content
  wearing the clothes of progressive disclosure. Judge this **entry by entry**: a citation that
  appears elsewhere on the page does not rescue a *Look at* entry whose only `file:line` is inside the
  block a reader has not opened.

  For the search record the trap is the empty result: "no other caller" is a finding and belongs in
  the open; the grep proving it is what collapses. For the foot the trap is **promotion by omission** —
  lower-priority affected code and the recorded searches may live there because they are provenance,
  but nothing a reviewer acts on may live *only* there. If an entry in the foot is a judgment they
  have to make, it is a checkpoint that was mis-filed.
- **Never imply the page found everything.** It did not, and measurably so: three independent
  analyses of the same 109-file diff produced eight distinct headline findings between them, with
  only *one* appearing in all three. Explanation is reproducible; defect discovery is sampling. Say
  plainly that what the page surfaced is a pass, not an audit, and never let it read as a clean bill
  of health. Say it **once**, under *What needs your attention*, and nowhere else. Where a reviewer needs assurance rather than orientation, point them at a dedicated
  review pass.
- **Never draw an `<svg>`.** The page's figures are two components — the vertical labelled chain and
  the `dl.ba` pair — assembled from the template. A drawing derived per run spends the run's attention
  on geometry instead of on whether the edges are true, and makes two pages from this skill
  incomparable; a component cannot be drawn wrong.
- Never drop a file from the page to keep it tidy.
- Never post to GitHub, Linear, or anywhere outside the artifact.
- Never commit the page into the repo under review, and never write it there. `--output` does not
  relax this: a directory inside the checkout would make the page part of the next diff, and on a PR
  branch part of the change it describes.
- **Do this work yourself; spawn no subagents — with exactly one exception, named below.** Steps 5
  and 6 span the whole diff by nature — step 5 traces consumers across both sides of the stack, step 6
  groups behaviour no single layer contains — and handing either to an agent with its own context
  moves comprehension fragmentation from the reviewer to the agents, which is the problem the page
  exists to solve. It is also slower in practice, not faster: a run that reached for one `Explore`
  agent stalled the parent for 997 seconds, 41% of its wall clock, in a single blocked turn. If the
  diff is too large to hold, say which region you skimmed — that is the honest failure and it is a
  signal worth having.

  **The exception is the falsification pass spawned at the end of step 6 and folded in at step 8,
  which runs by default.** It is the one split that does not commit the mistake above: the seam is per
  *analysis note*, which is per flow, and a flow is already a whole behaviour rather than a layer of
  one, so nothing is fragmented that was not already separate. It reads a note this run wrote, never
  the page. It is read-only, it returns challenges rather than page content — you still write every
  word — and its agents go out in a single message and are not waited on, so the run keeps drafting
  while they read. Nothing else spawns anything, at any effort level, and a run that reaches for an
  `Explore` agent to help with step 5 has broken this rule whatever flag it was given.
