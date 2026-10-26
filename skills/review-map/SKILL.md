---
name: review-map
description: >-
  Use this skill when someone needs to understand a pull request or branch before judging it: what a PR does, where to start on a large diff, which files matter, what the change might break in code it did not touch, or whether frontend and backend still agree. Also use it to bring a reviewer up to speed on someone else's work, even if they never say "review map" or "walkthrough". It builds one HTML page: what changed, the judgments the reviewer must make with the exact lines that settle each one, the order to read the code in, and the change's reach outside the diff. Works on Rails, Elixir/Phoenix, Rust and React/Next.js codebases, including APIs, LiveView apps, libraries and workspaces. Takes a PR number, URL, branch or diff range. Not for posting review comments, approving, grading a change, or writing PR descriptions or release notes.
---

# Review Map

Turns a diff into one HTML page a reviewer can work from: what the change is for, which
judgments it asks of them and where to look to make each one, the order to read the code in, and
what the change reaches outside the lines it touched.

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

## Host and invocation

Use `/accountable-review:review-map` in Claude Code or `$accountable-review:review-map` in Codex
(`/review-map` and `$review-map` when installed as a standalone skill, as `npx skills add` does).
Both accept a
PR number, URL, branch, or diff range; `--effort high` (default) or `--effort low`;
`--mentor` with an optional stack or `off`; `--context auto|never|always|collapsed`; and
`--output <dir>`. The repository's `.accountable-review.yml` supplies the first three when no flag
does (step 1).

Before step 1, read **only your host's reference**: [Claude Code](references/hosts/claude-code.md)
in Claude Code, and [the one for every other host](references/hosts/generic.md) anywhere else — Codex
and Pi being the primary examples, and any other agent that loaded this skill getting the same
local-file delivery. It owns delegation and delivery mechanics;
the ten steps below own the review. Resolve bundled paths relative to this `SKILL.md`,
not the repository being reviewed. User instructions take precedence over skill guidance.

## What is bundled

The procedure below relies on the bundled files in this table. Read each at the step that needs it rather than up
front — the procedure itself is the only part that has to be in context the whole way through.

Three of the ten are chosen per run, and **you read your own and never another's.** Step 2's stack
detection picks the lens and the catalogue: a Rails run reads the Rails pair, a Phoenix run the
Phoenix pair, a Rust run the Rust lens and the Rust catalogue, a React run the React lens and the
React catalogue — and reading another stack's file costs context and teaches the wrong searches.
**Two stacks have a lens of two files, and they are built the same way.** The Rust backend reads
`references/rust.md`, the lens every Rust run gets, and then `references/rust-backend.md` on top of
it, because a server is still a crate and the backend file restates none of the language. A Next.js
app reads `references/react.md`, the lens every React run gets, and then `references/nextjs.md` on top
of it, because a Next.js app is still a React tree. A Rust run that is not a backend reads `rust.md`
alone, and a React run that is not Next.js reads `react.md` alone. The host reference is the same
rule one level up — yours, not the other host's.

| File | Read at | For |
|---|---|---|
| `references/hosts/claude-code.md` *or* `references/hosts/generic.md` | before step 1 | Delivery and delegation mechanics for **the host this run is in** — Claude Code's, or the one for every other host (Codex, Pi, …) — how a stage reaches the reader, and how step 6c's independent reader is launched. The ten steps own the review; this owns the machinery under it |
| `references/report-format.md` | step 1 § *Deep links* only; whole at step 7, for 7, 8 and 9 | The six sections, the review checkpoint, the Context section, the chain component, the evidence tiers, source excerpts, impact paths, the canonical-home rule, the agenda budget and the deep-link ladder |
| `references/discover/rails.md`, `phoenix.md`, `rust.md` *or* `react.md` | step 2, once, after detection | What to detect about **the stack step 2 found** — its layout, libraries and test runner — and which versions the documentation links are pinned to. Small, and read whole |
| `references/rails-nextjs.md`, `references/phoenix-liveview.md`, `references/rust.md` (+ `references/rust-backend.md` for a Rust backend) *or* `references/react.md` (+ `references/nextjs.md` for a Next.js app) | step 5, then while reading any layer | What a senior reviewer of **the stack step 2 detected** looks for, the runtime probes, and the search recipes for code the diff did not touch. Step 2 names it; step 5 is where it is read |
| `references/rails-docs.md`, `references/elixir-docs.md`, `references/rust-docs.md` *or* `references/react-docs.md` | step 7, when a claim first asks for an anchor | The documentation URLs the page may cite, for that same stack. It is an allowlist, not a starting point: you look a concept up in it, you never read it to find concepts |
| `references/update.md` | step 1, only with `--update` | Re-running over new commits: whether this can be an update at all, `scripts/carry-plan.sh` and its plan, which steps run in full or narrowed, and how the existing page is edited. A run without the flag never opens it |
| `references/page-template.html` | step 9 | The design system. A run reads its **markup half** — component classes, two assembled checkpoints, the chain and the impact panel — with `scripts/page-skeleton.sh --markup`. The head, the whole token block and the page's one script are in the same file and are emitted rather than read |
| `scripts/page-skeleton.sh` | step 9, once | Writes that head, token block and script straight into the page, so none of it is read and none of it is typed. `--markup` is how the rest of the template is read |
| `references/themes/` | never | The three looks — Daylight (default), Workshop, Field Notes — each a font link, a token block and its overrides. `page-skeleton.sh` writes all three into the head with the repository's choice switched on, and the tail script builds the reader's *Aa* menu that switches them; a run never reads one, never chooses one, and never types the menu |
| `scripts/diff-render.sh` | step 3, once | Says per path whether GitHub will render that file's diff, which is what decides the URL form for a line inside it |
| `scripts/excerpt.sh` | step 9 | Generates the collapsed source excerpts — the quotation has to be the real bytes |
| `scripts/ledger-rows.sh` | step 10 | Generates the diff inventory the evidence foot holds, and its deep links, from the diff |
| `scripts/coverage-gate.sh` | step 10 | Runs the completeness check |
| `scripts/page-lint.sh` | step 10 | Reads the finished page: placeholders are a FAIL to fix, a tier that disagrees with the diff is a WARN to read |
| `scripts/usage.sh` | steps 1 and 10, outside Claude Code | What the run spent, for a host with no status line to show it — the host reference says when. Its line goes in chat, never on the page |

Paths are relative to this skill's base directory; do not rely on a plugin-root environment
variable such as `$CLAUDE_PLUGIN_ROOT`, which is not set in the shell.

One bundled file is not one you read: `references/claim-falsifier.md`, the independent reader's
mandate. At `--effort high`, which is the default, a reader is sent at each analysis note this run
wrote at the end of step 6, and its challenges are folded in at step 8. You hand that reader the
mandate's absolute path; you never load it yourself — its instructions are its own, which is the
point of putting them in a separate context. The host reference owns how the reader is launched.

## 1. Resolve the target and the effort

- Argument may be a PR number, a PR URL, a branch, or a diff range. With no argument, use the
  current branch against its base.
- **There is one page shape, and no flag chooses it.** No argument selects a length, a depth or a
  second document, and there is nothing to map one onto if someone invents one. An argument starting
  with `--` that is not one of `--effort`, `--mentor`, `--context`, `--output`, `--update`, `--repository`,
  `--base-sha` or `--head-sha` with its value is **reported, not guessed at**. A misread flag silently produces the
  wrong run, and the reader has no way to tell.
- **Read the repository's settings before the flags that override them.** If the repository's top
  level has an `.accountable-review.yml`, run, once:

  ```sh
  <skill base directory>/scripts/read-config.sh "<repo top level>/.accountable-review.yml"
  ```

  It prints one `CFG_<key>='<value>'` line per key the file sets and nothing for a key it does not.
  `CFG_effort`, `CFG_mentor` and `CFG_context` are the team's standing answers, and the order is
  **flag, then file, then default** — the same order CI applies, so a person's run and a CI run of
  the same repository start from the same settings. `CFG_mentor` reads as the flag would: `true`
  is a bare `--mentor`, `false` is off, a stack name is checked at step 2 like one on the command
  line. `CFG_theme` is `page-skeleton.sh`'s, which reads it itself; `update`, `trivial_*` and
  `delivery` are CI's and change nothing here — `--update` is only ever a flag on this skill.

  **A non-zero exit stops the run**, with the parser's message: the file names a key or a value
  that does not exist, and a setting read as nothing is a team's decision silently replaced by a
  default — the unknown-flag rule, one file over. The file read is the working tree's, which is the
  copy the person has checked out. Say in chat which settings came from it.
- **The page has a word budget, stated as guidance, and you write to it rather than trimming to
  it.** `references/report-format.md` § *The agenda budget* owns the numbers, and you read it with
  the rest of that file at step 7, before a word of the page is drafted. It caps prose and nothing
  else, and **the number it never touches is the checkpoint count.**
- **Resolve the page settings — effort, mentor, context — flag first, then the file, then the
  default**, and hold them for the whole run. Every value not listed below is **reported, not
  guessed at**: a flag read wrongly is work that silently differs, with nothing on the page to tell
  the reader which run they got.

  | Flag | Values | Default | What it decides | Owned by |
  |---|---|---|---|---|
  | `--effort` | `high`, `low` | `high` | Whether step 6c sends falsifiers at the notes | step 6c, step 8 |
  | `--mentor` | bare, a stack name, `off` | off | Whether a checkpoint may carry a primer | `report-format.md` § *Mentor mode*, step 7g |
  | `--context` | `auto`, `never`, `always`, `collapsed` | `auto` | How much of section 02 the page carries, and nothing else | `report-format.md` § *How much Context*, step 7k |
  | `--output <dir>` | a directory outside the repository | — | Where the page lands: `<dir>/index.html`, nothing published | below |
  | `--update` | — | — | Edit the existing page over the commits since its revision | `references/update.md` |

  **None of them is announced on the page** — no marker, chip, banner or sentence for any setting.
  Two pages of one target at different settings differ in their claims (effort), their primers
  (mentor) or section 02 (context), never in a component that names the setting. Say which settings
  you took, and from where, in chat.

  - **`--effort`.** `high` is the default because it changes what the page finds, and what it costs
    is tokens rather than time: on one 28-file PR the falsifiers cost **23 seconds of blocked
    parent, 0.9% of a 2607-second run**, because they read while the next stage is drafted, and the
    same target at `low` missed five findings the falsified run carried, including the two the
    reviewer most needed. Step 6c says what the tokens are. `--effort low` is for a diff small
    enough that a second reader has nothing to find. **`--effort normal` is accepted silently and
    means `low`** — the old name of the opt-out, still in people's scripts, and the one value that
    is not guessing. Nothing makes a run faster by making the page shorter: the time goes into
    tracing consumers at step 5.
  - **`--mentor`** says the reviewer is new to the **stack** rather than to the change. A stack name
    — `rails`, `elixir`, `phoenix`, `rust`, `react`, `nextjs` — **is checked at step 2, never used to
    choose**: taking it as an override would put a Rails lens over a service that is not Rails.
    `react` agrees with either React stack; `nextjs` only with a Next.js one. A bare `--mentor` is
    the form to prefer; `--mentor off` matters only when the repository's file turned it on.
    `report-format.md` § *Mentor mode* owns the rest — above all the subtraction rule: delete the
    primers and what remains is the page the run would have written without the flag.
  - **`--context`** tunes section 02 and nothing else; `never` compensates nowhere, and `always`
    lowers the bar without filling the section. § *How much Context* owns all four values.
- **`--output <dir>` makes the run non-interactive.** It changes where the page goes and nothing
  else: the page is written to `<dir>/index.html` and **nothing is published** — no `Artifact` call,
  at any stage. Same sections, same depth rules, same excerpt budget, same gate; the moment this flag
  starts meaning a cheaper page, there are two products and only one of them is developed against.

  Three flags travel with it, carrying what `gh` would otherwise be asked for:

  ```
  --repository <owner/repo>   --base-sha <sha>   --head-sha <sha>
  ```

  **Prefer them over anything you derive.** `--base-sha` is `BASE` and `--head-sha` is `HEAD` for
  every diff in this run; do not compute a merge-base over them and do not call `gh` for what they
  already say — a base recomputed from a branch that has since moved describes a revision nobody
  requested. With `--repository` and a PR number the run has what link rung 1 needs without `gh`;
  check reachability as always. The flags are legal on their own.

  `<dir>` must be **outside the repository under review** (the hard rules say why), and holds the
  page and nothing else, because whatever is in it is what gets delivered. **`$W` is unchanged**:
  excerpt fragments and notes still go there, and the page itself is written straight to
  `<dir>/index.html`, so a crash leaves a useful page where the caller looks.
  `ci/generate-review-map.sh` drives this path, supplies all four flags, and refuses to deliver a
  page that does not name its revision or still says it is being written.
- **`--update` re-reads only the commits since the last map**, editing the page that already exists
  where this run would write. `references/update.md` owns every rule about it; read that file before
  acting on the flag. **It is not a level and not an effort**: it never lowers a cap, skips the gate,
  skips step 8 for anything it writes, or admits or removes a component. **With no previous page, or
  when its carry plan refuses, it falls back to a full run and says so in chat** — a full run is
  always the better page, so every way the flag can fail leads to one.
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

  Derived, not invented, because step 9 republishes to the same file path across stages and a re-run
  finds the previous page there — `--update` edits it, a fresh run sets it aside — and a
  session-scoped scratch directory cannot satisfy that: the next session gets a different one.
  Whether a fresh run keeps the earlier page's link is the host reference's to say. A fresh run that
  finds a page there moves the directory aside — `mv "$W" "$W.prev-$(date +%Y%m%d%H%M)"`, then
  `mkdir -p "$W"` — before writing anything: never delete it, and never `--force` the skeleton over
  it. Export `W` once and use it in every later command, so excerpt fragments land beside the page
  rather than somewhere they have to be moved from.
- **Fix the deep-link mode now, not at render time.** Check whether the head SHA is even reachable
  on a remote — `git branch -r --contains <HEAD_SHA>`, where **exit 0 and empty output** means it was
  never pushed and every permalink to it would 404. Unpushed branches and worktrees are among the most
  common targets for this skill, so expect this. **A non-zero exit is a state of its own and neither
  of the other two**: git was asked and could not answer, so nothing is known about reachability. Do
  not read it as unpushed — say in the masthead that reachability could not be determined and render
  citations as plain text, rather than asserting a branch is unpushed on an answer git never gave.
  Pick one rung from the ladder in
  `references/report-format.md` § *Deep links* and hold it for every citation. Read that section
  alone now — it is the file's last, so `sed -n '/^## Deep links$/,$p'` prints it whole — and leave
  the rest of the file for step 7: nothing in steps 2 to 6 writes the page, and every token loaded
  here is billed again on each of the requests the tracing makes. This defers one file, the page's
  rules; it is not a rule against reading before step 7 — step 5 reads the stack's lens, because
  its search recipes are the tracing. The rung decides whether anything is
  clickable; it does not decide the form — inside a rung, a line in the diff links to the diff page
  and a line outside it links to a blob, with one exception that is settled per file in step 3 and
  not per citation. At rung 2 there is no PR page, so check the base SHA for reachability too:
  without it there is no `compare` view to anchor into.

## 2. Discover the project

Assume nothing about layout or conventions — this skill travels between repos.

**Detect the stack first**, because it decides which of the bundled files the rest of the run
reads:

- `config/application.rb`, or a `Gemfile`, → **Rails**: the lens file is `references/rails-nextjs.md`,
  the catalogue `references/rails-docs.md`.
- `mix.exs` → **Elixir/Phoenix**: the lens file is `references/phoenix-liveview.md`, the catalogue
  `references/elixir-docs.md`.
- `Cargo.toml` → **Rust**, and then one more question decides which of the two Rust stacks: **does
  the code this diff touches serve requests?** It does when a crate the diff changes — or a crate
  that one is a path dependency of, inside this workspace — lists a server framework among its
  `[dependencies]`: `axum`, `actix-web`, `rocket`, `warp`, `poem`, `salvo`, `tonic` or `loco-rs`.
  Then it is a **Rust backend**: the lens is `references/rust.md` *and then*
  `references/rust-backend.md`. Otherwise it is **Rust in general** — a library, a CLI, an embedded
  target, a WASM module — and the lens is `references/rust.md` alone. Either way the catalogue is
  `references/rust-docs.md`.

  **A workspace is one root, not several.** A `Cargo.toml` with a `[workspace]` table and a dozen
  members is one Rust project, and the members are where step 5's consumers live; it is never the
  "more than one root" case below. Neither is a workspace that holds one server crate and several
  libraries — the backend question above is answered by what the diff touches, so a change confined
  to a library the server does not depend on is Rust in general even in a repository that serves
  requests. The name of the framework is evidence and its absence is too: a crate depending on
  `hyper` or `reqwest` alone is a client, not a backend.
- `package.json` listing `react` among its `dependencies`, `devDependencies` or `peerDependencies` —
  and no Rails, Phoenix or Rust root that this diff touches — → **React**, and then one more question
  decides which of the two React stacks: **does the package this diff touches depend on `next`?** It
  does when the changed files' nearest `package.json` lists `next`, or a `next.config.*` sits beside
  it. Then it is a **Next.js app**: the lens is `references/react.md` *and then*
  `references/nextjs.md`. Otherwise it is **React in general** — a Vite or Create React App
  single-page app, a component library, a React Router or TanStack Router app, the React half of an
  Electron or React Native codebase — and the lens is `references/react.md` alone. Either way the
  catalogue is `references/react-docs.md`.

  **A JavaScript workspace is one root, not several**, for the reason a Cargo workspace is: a
  `workspaces` field, a `pnpm-workspace.yaml` or a Turborepo or Nx config holding an `apps/web` and a
  `packages/ui` is one React project, and the shared packages are where step 5's consumers live. The
  Next.js question is answered per diff, so a change confined to `packages/ui` is React in general
  even in a workspace whose app is Next.js.

  **A client beside a backend is the backend's client, until the diff says otherwise.** A Rails,
  Phoenix or Rust repository carrying a Next.js or React app in `web/` or `frontend/` is the backend's
  stack when the diff touches the backend: its lens already treats the client as the other half of
  the contract, and `rails-nextjs.md`'s client sections are where that half lives. When every changed
  application path sits in the client, it is the React stack instead — detected from the diff, with
  no question to put, by the rule in the next bullet. A repository whose only root is a
  `package.json` with `react` is React, whatever serves its API.
- **More than one root, or one of each** — a monorepo with an `api/` and a `services/`, engines, an
  umbrella, a Rails or Phoenix app carrying a Rust crate for a native extension (`rb-sys`,
  `magnus`, `rustler`), or a Rust or Phoenix service and an unrelated React app side by side —
  **ask which to cover** rather than picking. Same rule as several Rails
  roots, and for the same reason: covering the wrong half produces a page that is confidently about
  code the reviewer is not reading.

  **Look at the diff before asking, and answer it from there when you can.** If every changed
  application path sits under one root, that root is detected rather than chosen and there is no
  question to put. Ask only when the diff genuinely spans more than one.

  **Non-interactively (`--output`) there is nobody to ask, and picking is still forbidden.** So when
  the diff does not settle it, **stop** and say which roots were found and that the run needs one
  named — a missing map is reported by the caller and a confidently wrong one is not. This is the
  case CI meets most often, which is why it is spelled out rather than left to the general rule.
- **None of these** — say so plainly, cover the diff with the stack-independent material (the five
  sections, the checkpoints, the tiers, the impact chains, the evidence foot), and **emit no documentation link and no
  probe.** Do not default to Rails: a Rails lens applied to a Go service invents findings, and a
  catalogue that does not describe this application is the failure every catalogue fails closed to
  avoid.

**If `--mentor` named a stack, check it here and nowhere else.** The detection above is the answer;
the name on the command line is a claim to test against it. Agreement is silent. A disagreement —
`--mentor rails` in a repository whose only root is `mix.exs`, `--mentor rust` in a Rails app
with no `Cargo.toml`, or `--mentor nextjs` on a Vite app — **stops the run**, names both
readings and says to re-run with a bare `--mentor`. It is never correct input, which is why it is
handled like any other flag value that cannot apply rather than resolved in the run's favour: the
likeliest cause is the wrong checkout, and a page confidently about the wrong repository is the
failure a one-line stop is cheap against. What it must never do is let the name pick the lens.

**Detecting the stack is not reading its files.** This step decides *which* pair the rest of the run
uses. The lens is read at step 5, where its search recipes are the work; the catalogue at step 7,
when a claim first asks for a URL. Nothing between here and there needs either, and both are large —
a run that opens them now carries them through the whole of steps 3 to 6, which is where the
consumer tracing happens and where the context is already largest. The versions this step records
come out of `Gemfile.lock`, `mix.lock`, `Cargo.lock` or the JavaScript lock file, not out of the
catalogue.

**Then read the detected stack's discovery file, once, whole**: `references/discover/rails.md`,
`phoenix.md`, `rust.md` or `react.md` — the Rust and React files carry the backend and Next.js
additions in a section of their own. It says what to detect about the application before any
tracing and which versions to record. Read no other stack's; a run whose stack step 2 did not
detect reads none.

**Record the versions the documentation links are pinned to.** This is not bookkeeping: **every
documentation link on the page is pinned with them**, so a run that skipped this step cannot emit a
doc link at all — recording the version is this step's job, and knowing which URL to pin is
step 7's. What to record differs by stack, and so does its shape — the stack's discovery file says
which versions, from which lock file, and in what form.

Each catalogue's § *Pinning* owns the emitted forms. The same versions also decide what the page may
**claim**, because two marks in each catalogue turn a version-sensitive behaviour into a probe rather
than a sentence.

**At `--mentor`, a closed catalogue also decides whether the flag can do anything.** A primer is what
a doc link escalates into and is gated on carrying one, so while `elixir-docs.md` § *Version*
withholds every link a Phoenix run at `--mentor` writes no primers at all and produces the ordinary
page — and the same holds for a React or Next.js run while `react-docs.md` is closed. Say that to
the user, in chat, when the run starts — a flag that silently did nothing is worse than one that
says why it could not. Do **not** say it on the page: a line explaining the absence of
primers is the mentor badge § *Mentor mode* refuses, with an apology attached.

**Frontend.** The discovery file says what the frontend is on this stack — LiveView templates, a
library with none, or on React the application itself — and when to skip what follows. Where a
separate client exists, locate it (`package.json`, `next.config.*`, `app/` versus `pages/`) and find
the seam between the two sides, because that is what a contract judgment is built from:

- the API client or fetch wrapper, and where base URLs and error handling live;
- **whether types crossing the boundary are generated from the backend or hand-written.** Generated
  types drift loudly, at build time. Hand-written ones drift silently, which is the case worth
  hunting;
- runtime validation at the boundary (Zod or similar) and whether it is applied to every response or
  only some;
- the data-fetching layer: React Query, SWR, server components, route handlers.

**Conventions.** Look for the project's own in `CLAUDE.md`, `AGENTS.md`, `docs/`, `README`,
`CONTRIBUTING.md`. If found, check the PR against them. If not, infer the house style from adjacent
unchanged code of the same kind — often more accurate than a stale document. Note which top-level
directories under `app/` (or `lib/<app>/`, a Rust crate's `src/` and the workspace's crate
list, or a React app's `src/` and a JavaScript workspace's `apps/` and `packages/`) exist and what
each holds: that inventory is the evidence
step 7b needs to ask whether a coding decision in this diff departs from one, and a departure it
cannot cite — from this inventory, a convention doc, or the lens file's stack conventions — is a
question it may not ask. A written decision found here is worth noting with its line.

**Architecture, written down.** Look too for what the repository says about its own structure: an
`ARCHITECTURE.md`, ADRs (`docs/adr/`, `doc/architecture/`), and the files a tool enforces boundaries
from — packwerk's `package.yml`, an Elixir `boundary` declaration, an eslint import-restriction rule,
a Cargo workspace's member dependencies. Note each with its path. They are the first source step 7b
cites for an architectural question, and a shift the repository has written down as allowed is no
question at all.

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
- **Notice a uniform transform before you start opening its instances.** A rename, a codemod, a
  regenerated lockfile or a vendored bump shows itself in the cheap signals you already have — a run
  of `R` status letters, eighty files each moving three lines with the same add-to-delete ratio in
  `git diff --numstat`, the paths `--collapsed-only` just printed. **That bulk is one judgment — *is
  the transform uniform, and what did it miss?* — plus an inventory**, so open the exceptions rather
  than the instances: the files where the transform did something different, and the places that
  should have been transformed and were not. Reading the eighty spends the run's scarcest resource on
  the part of the diff carrying the least to decide.
- If the whole diff is trivial (a few files, no migration, no new behaviour), say so and offer to
  stop rather than generate ceremony. A page nobody needs is worse than no page.
  **Non-interactively (`--output`), make the page.** There is nobody to offer to, and the offer has
  already been answered upstream: `ci/application-code.sh` measures exactly this and skips the job
  before the skill is reached, so a run that got here is one that gate judged worth a map. Say the
  diff is slight in *What changed*, as a stated limit, and carry on.

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

**The step's first call is the lens's heading index, before any consumer search**: `grep -n '^## '`
over the lens file the stack selected in step 2 (both files on a Rust backend or a Next.js app).
Then, in the next turn and side by side, `Read` with `offset` and `limit` the file's opening (above
its first `##`), § *Search recipes*, and every section for a layer this diff touches. Skipping it is
not a saving. Its per-layer questions are what a trace improvised from the diff alone does not think
to ask, and a missing finding fails no check: the page just reads complete. A run that greps for its
own guesses in the lens instead of reading those sections finds only what it already knew to look for.

Work outward from each changed thing to its consumers:

| Changed thing | Who you have to go find |
|---|---|
| A method, class, context function or Rust function | Its callers, and anything that subclasses, includes, imports or re-exports it — in Rust, across every member of the workspace |
| A Rust trait, a `pub` item, or an enum a downstream `match` covers | Every implementor and every downstream crate; a new enum variant reaches only the `match`es with a wildcard arm, silently — the exhaustive ones were already fixed for the diff to compile |
| A column or schema field | Whatever exposes it (a serializer, a `Jason.Encoder` derive list, a JSON render module), scopes and queries filtering on it, factories and fixtures setting it, forms writing it |
| A validation, callback or changeset | Every write path that now behaves differently — `update_all` and `insert_all` bypass it in Rails and Ecto alike, and a second changeset function on the same schema is a second write path |
| An enum or status value | Every branch on that value, on both sides of the boundary, including every exhaustive `case` |
| A JSON key or response shape | The API client, the TS type, and every component reading it |
| A LiveView event name | Its `handle_event/3` clause, **and** every `.heex` template and JS hook that fires it. Either half can be the stale one, and no diff shows the two together |
| A route | Anything constructing that URL, including the client and any external caller — and, for a `live` route, which `live_session` block it landed in |
| A job or its arguments | Every enqueue site, plus in-flight jobs already queued with the old shape |
| A migration, on a Rust backend | Every query on the changed columns — and, where queries are compile-time checked, whether the offline query data (`.sqlx/`) moved with it, because an unchanged query checked against stale data compiles |
| A Cargo feature or a dependency's version | Every crate in the workspace that enables it, every `#[cfg(feature = …)]` it gates, and which combinations CI builds |
| A React component's props, a hook's return value, or a context's value | Every place it is rendered or called — including through a barrel re-export, a `lazy()` import, a map of components and a story — and, for a context, which subtrees have no provider above them |
| A query key, a cache tag, or a Next.js server action that writes data | Every reader of that key or tag, and every mutation that should invalidate it; on Next.js, every page that renders the data the action writes against the paths and tags it revalidates |
| A file under a Next.js `app/` or `pages/` tree | The URL it serves: every link, `router.push`, `redirect` and `revalidatePath` to it, the middleware `matcher` that does or does not cover it, and whether a new request-time read made the routes rendering it dynamic |

The lens file the stack selected in step 2 — `references/rails-nextjs.md`,
`references/phoenix-liveview.md`, `references/rust.md` with `references/rust-backend.md` on a Rust
backend, or `references/react.md` with `references/nextjs.md` on a Next.js app — carries the concrete search patterns per artifact kind. Use them;
do not improvise a grep and call the area clear.

**Record what you searched, not just what you found — but the finding goes in the open prose and the
search goes in the collapsed record.** "Nothing else calls `Project#archive`" is the finding, and it
is a sentence a reader meets without opening anything; `rg 'archive[!?]?\b' app lib` is how you know,
and it belongs in `details.searched`, shut, inside the evidence foot. Unrecorded entirely, absence and omission look identical
and the reviewer redoes the work; left *only* inside the toggle, the finding is hidden rather than
disclosed. **One row per search: the command, then what it returned in a clause** — the form and the
budget are `references/report-format.md` § *What was searched*, which owns them.

**Every affected entry needs a row that reproduces it, including one you reached without searching.**
That file is not read until step 7, so the rule is here, where the rows are made: an evaluation re-runs
each recorded search and fails an entry no row returns. The entry this misses is the one found by
following a call — the diff adds `AuditTrail.record(changes: …)`, you open `record` and see what it
does with the hash. Reading the callee is how you found it; a search is how the reviewer re-finds it,
so record the one that does (`rg -n 'def (self\.)?record\b' app`).

**Then measure the structure, on both sides.** For each changed file, note what it now depends on
that its module did not: a reference from one top-level module, context, package or crate into
another, a new writer of a table or a fact, a new process, queue, cache or external call. For each
candidate, search the merge-base too — `git grep -n -P '<pattern>' <merge-base sha> -- <scope>`, with the sha
written out so the recorded row reproduces — because *new* is a claim about the base and the hunk
does not show the base. **The base search measures what the head search measures, at another
revision** — the same pattern and scope wherever `git grep` can carry them; two patterns measure two
facts, and their difference is not a shift. `-P`, not `-E`:
git's ERE takes no `\b`, `\w` or `\s` on macOS and returns nothing rather than failing, which reads
as *absent at the base*. An empty result at the base for
an edge that exists at head is the shift; an empty result at head outside the diff for a kind of
thing the diff adds is a precedent. Record both searches like any other, and write the result into
the flow's note, because step 7 opens nothing the notes have not cited. The lens file's
§ *Architectural questions* has the patterns per stack; searches only, never a tool that compiles or
boots the application to answer.

Then draw the primary flow end to end, from user action to persistence and back, and list the
secondary effects hanging off it. That flow is the run's backbone: step 6 splits it into flows for
analysis, *Impact outside the diff* shows the crossings whole, and the checkpoints are the judgments
it turns on. **Nothing publishes after this step**: the crossings found here reach the page at
milestone 3, after 7c has had its chance to merge two of them into one judgment and after there is a
checkpoint for each card to point at (step 9).

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

**The flow is the unit of ANALYSIS and never a unit of the page.** Nothing below writes a flow
section: a flow becomes a note, the note is what gets attacked, and step 7 turns notes into the
ranked handful of judgments the reader actually gets.

**And no sentence on the page ever names one.** These letters are yours, for the notes in
`$W/analysis/` and for your own ranking; the page's designators are *Checkpoint A* and *Impact path
A*, which are the reader's. A checkpoint reading *"a leader-opened thread (Flow A) has no
`connection_id`"* has pointed at a section nobody wrote. It is easy to write and hard to see, because
the note you are holding, the checkpoint you are writing and the impact path beside it are all
lettered — `references/report-format.md` § *One canonical home* owns the rule.

**Nor does the page ever write `§`.** This file and its references use it for their own headings —
*§ Something* — and pages have carried it as *§ 01* for *What changed*; the page has no such names
and nothing that links them, so a `§` that reaches a sentence points nowhere a reader can go. Name a
section of the page by its title, linked to its id; name a heading in a repository file in words,
with the file cited; or, best, say the thing the section stood for. Same rule, same owner.

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
  falsifier is told to treat it as one. **Affected means a file `git diff --name-only` does not
  list**: an untouched method inside a changed file goes in *Trace*, because the page splits changed
  from unchanged by file and a run that files it here draws it teal and labels it
  `from unchanged code` on a page whose inventory lists the file as changed. **And it means the
  change reaches it.** Code the search found that the change does *not* reach — the check that
  reads a value the change stores nowhere, the status computation whose inputs an edit leaves alone
  — is insulation: file it under *Trace* or *Open* as evidence for whichever judgment asks whether
  it is reached, never here, because whatever is filed here becomes an *Affected, not changed* entry.
- **Searched** — one line per search, the command then the result clause, in the form
  `details.searched` will take. **Every *Affected, not changed* entry is in some line's output**;
  for one you reached by opening a callee rather than by searching, add the search that finds it
  now. The reviewer re-finds an entry by re-running the record; one no line returns is an assertion
  however true it is, and a later run's replay of the record cannot see it.
- **Tests** — which behaviour each pins, which branch it leaves open.
- **Open** — what you could not establish, and what would settle it.

**Why a file and not a slice of the page.** A note can be attacked before any of it is public, and
the falsifier reads claims rather than markup, excerpts and a rail. It also survives the run: on a diff that strains the context, `$W/analysis/` is what says which
region got a trace and which got skimmed.

### 6c. At `--effort high`: send the falsifiers at the notes

Everything so far is this run checking its own work. That is the weakest kind of check — the context
that wrote a claim is the one least able to see what it assumed. At `--effort high` the notes get a
second reader whose only job is to break them.

**When.** Here, as soon as the notes are written, and **before any of it reaches the page**, so a
corrected claim is never one a reader saw.

**How.** One independent reader per note, launched the way **your host reference** says — Claude
spawns the registered `accountable-review:claim-falsifier` agent (a general-purpose one when
installed without the plugin), and every other host works down its reference's ladder: its own
subagent tool, else a read-only background run of its own CLI —
**up to the host’s available concurrency.** This is the one exception to the rule against subagents in
§ *Hard rules*.

**Then keep working — do not wait on them.** They come back as notifications, not as a blocked turn,
and the parent's job in the meantime is step 7. Launch receipts come back in seconds and the first
challenges minutes later, which is why the pass costs under 1% of the run's wall clock — and only
while you keep drafting. A run that spawns them and then idles has converted the cheapest thing in
this procedure into the most expensive.

**Cheap in wall clock is not free in tokens, and the cap is what holds both costs down.** Each
falsifier reads in its own context, and those tokens are the run's: with one note per falsifier the
pass came to **2-5% of every cache-read token the run spent**, over 13-33 requests, and none of it
shows in the parent's transcript — `evals/profile.sh` reads the subagents' to count it. It is that
small because a note is all a falsifier reads; hand one more than its note and the share grows with
what it was handed. Claude's falsifier runs on its own model (`agents/claim-falsifier.md`), so that
share can be bought down without touching the wall clock; Codex inherits its configured model, and
both measurements are from Claude runs.

The other cost lands in your context, not theirs: every challenge comes back to you, and step 8 has
you open its cited file before acting on it. That is the cap's real job. Six agents is the point past
which a second reader stops paying for itself — in their tokens and in the verification each
challenge asks of you.

Launch the selected readers without waiting between launches, up to the host’s concurrency
limit. Queue any remaining notes and continue drafting; one blocking spawn is the failure the hard
rules describe.

Give each agent four things and no more: the absolute path of `references/claim-falsifier.md`, which
it is asked to read first; the repository path; `BASE` and `HEAD`; and **the path of that one note**.
Not the whole set — a falsifier holding every note is one long blocked turn again, and it has no way
to tell which claims are its to attack.

**Cap it at six.** Past that, take the notes carrying the most *affected, not changed* entries and
the most `inferred` and `uncertain` tiers. Those are the claims a reader cannot check cheaply, which
is the only reason to spend an agent on them.

## 7. Synthesise the agenda

The notes are the analysis. This step turns them into the page's argument, and it is a step of its
own because the failure it prevents is structural: a run that goes from notes straight to prose
writes one section per flow, which is the page this one replaced.

**Read `references/report-format.md` now, whole**, if this run has not — step 1 read only its
§ *Deep links*. Every rule about the page lives there, and from here to step 10 the run is writing
the page. **Read it in one turn**: four `Read` calls side by side, at offsets 1, 701, 1401 and 2101
with a limit of 700 each, and one more at 2801 only if the last came back full. A `cat` spills past
the output limit into a file that then comes back one chunk per request, and each of those requests
re-bills the whole context the run has built by now.

Nothing else here opens a file the notes have not already cited. The work is deciding, not tracing. Do it
in this order, and write the outcome of each part into `$W/analysis/agenda.md` before moving on — the
falsifiers' challenges are arriving while you do this, and a written agenda is what lets step 8 fold
one in without re-deriving the ranking.

**7a. Name the semantic delta.** One sentence: what is true of the system after this change that was
not true before, in behavioural terms. Not what files moved — what a user, an operator or a
downstream caller now experiences differently. If the notes support two unrelated sentences, the PR
bundles two changes and *What changed* says so, neutrally. This sentence is the spine of section 01,
and almost every checkpoint has to be a judgment about it.

**Almost, because there are three kinds of checkpoint and only the first answers to this sentence.**
A **behavioural** checkpoint is a judgment about the delta — what the system now does. An
**architectural** checkpoint is a judgment about what the change makes true of the system's
structure: a dependency that now runs a new way, a second owner of a fact, a boundary crossed, a new
runtime component, the first of its kind. A **coding-decision** checkpoint is a judgment about how
the change was built: where a class was put, what kind of object it is, which existing abstraction it
went around. The second and third kinds never displace the first, and 7b to 7e say why and how.

**Then class each delta: behavioural or refactor.** A behavioural delta changes what a user, an
operator or a downstream caller experiences; a refactor intends to change structure and leave
behaviour as it was. Write the class beside the delta's sentence in `agenda.md`. It reaches the page
only through the masthead's *Change shape* chip, which is the class itself — *behavioural*,
*refactor*, or *mixed* when the deltas differ — and it decides the order in 7d. The chip follows your
class, never the PR's title: where the two disagree, *What changed* names the title's claim in a
clause, attributed. **A refactor whose notes show behaviour that moved is
not a refactor**: class it behavioural, and the moved behaviour is its first judgment. The author
calling it a refactor is a claim, attributed, per step 4.

**7b. Identify the human judgments.** For each note, ask what a competent reviewer has to *decide*
rather than *learn*: whether a scope is still the one that was intended, whether a nil default is
safe for every consumer, whether a guard's new order admits a class it used to refuse, whether a
migration is safe to run against the rows that already exist. Write each as a question.

A judgment is something the reviewer could get wrong, with consequences. A fact is something they
read once. Facts feed the explanations; only judgments become checkpoints.

**Then ask the two structural questions, each behind the same bar: no citation, no question.**

- **A coding decision names the departure**: *the PR chose X; this codebase already does Y for the
  same job; is X deliberate?* — a value object under `app/models` where `app/services/` holds four of
  its kind, a query built in a controller where `app/queries/` exists, a lookup table re-declared
  beside the module that already owns it. **Placement is one axis of three** — where it was put,
  what kind of object it is, which existing abstraction it went around — and the third is the one a
  run stops before reaching: a second source of truth for a fact the app already defines. `Y` is
  cited from **this repository's decision** (a convention-doc line, else a populated directory or a
  sibling file step 2 inventoried) or **a stack convention on the lens file's closed list**, through
  its catalogue row, and **the repository outranks the stack**. A convention you know but the lens
  does not list is taste.
- **An architectural question states the shift**: *before this PR, X was not true of the system; at
  `file:line` it now is; is that intended?* — a module that now names one it never did, a second
  writer of a column, an outbound call inside a request where every other one is enqueued, the first
  cache in the app. It is cited from a written decision step 2 found (an ADR, an `ARCHITECTURE.md`, a
  boundary a tool enforces), else from the two searches step 5 recorded, base and head. A shift the
  repository has written down as allowed is no shift.

**A citation admits a candidate; it does not make one.** Something similar existing is where the
question starts, and most candidates end there: `report-format.md` § *Coding decisions* and
§ *Architectural questions* each own three tests, and the one both share is **no reason in any note**
— read the candidate against every note, because the ordering that explains a copy, or the
requirement that explains a shift, is usually in another flow's trace.

**Ask it; never answer it.** No *should have been*, *unidiomatic*, *the Rails way*, *coupled*,
*leaky* or *cleaner*. The reviewer knows why the codebase is shaped as it is and you do not — step
6's neutrality rule is the register, and a decision you cannot resolve goes on the *Open question*
line, not into a verdict.

**In a refactor delta, ask the equivalence first.** A refactor's claim is that nothing a caller sees
moved, so its first judgment is *is behaviour preserved?*, with the lines where it would not be — a
guard reordered, a default that travelled, a callback no longer run, a scope that changed shape. Skip
it only when the notes found no place the two versions could differ. **A behavioural delta owes it
too** where it moves code whose callers are meant not to notice — checks relocated, a method
extracted — asked once for all of those callers and ranked with the behavioural judgments by the four
criteria, not first; `report-format.md` § *Ranking by delta* owns it.

Some judgments hide outside any one flow, and a flow-by-flow reading is exactly what misses them.
`references/report-format.md` § *The review checkpoint* carries the list to ask against — migration
safety, an application invariant with no database counterpart, the authorization model, deploy
ordering, test infrastructure, agentic tooling, jobs and flags and environment variables and
transaction boundaries, and the coding decisions that depart from something this repository
already does. Each is a checkpoint only if it is a judgment for *this* diff; the list is a prompt,
not a form.

**7c. Merge related observations.** A constructor change, the nil default it introduces and the two
consumers that do not handle nil are one judgment — *is nil safe here?* — not four observations.
Merge until each candidate is a single question whose answer settles everything under it.

This is where the agenda gets short honestly. Three observations that share a question are one
checkpoint, and a run that lists them separately has written the same judgment three times.

**Coding-decision candidates go through the same merge, and it can delete them.** Read each against
every note: a fact another flow traced — a value captured before a write clears it, a subset taken
for a reason — is often the reason the departure exists, and then there is no departure to ask
about.

**Architectural candidates go through it too, in two directions.** One that turns on the same lines
as a behavioural judgment merges into it — the behavioural question stays and the shift becomes a
clause, because what the system now does outranks what it now permits. And three files that each add
the same edge are one question with three *Look at* entries. A shift that is also an impact path
keeps both, the checkpoint asking and section 05 drawing, each pointing at the other in a clause.

**7d. Rank.** Order the candidates by four things, in this priority: the consequence if the reviewer
misunderstands it; how uncertain the notes are about it, because the reviewer's attention is worth
most where the page's own evidence is weakest; how far it sits from the obvious reading of the diff,
since a consequence visible in the hunk needs less help than one three files away; and how important
the affected unchanged code is.

**Those four order the behavioural judgments; `report-format.md` § *Ranking by delta* owns the rest
of the order.** In one line: **the band outranks the delta** — every behavioural judgment and every
refactor's *is behaviour preserved?* first, page-wide, then architectural questions, then coding
decisions, because misreading structure costs the reviewer a conversation and misreading behaviour
costs them production.

**The order is the order to think about them, and it is not a scale.** No number that reads as
severity, no *high* or *low*, no *blocking*, no *watch*. The rail and the reading path refer to a
checkpoint by its question.

**7e. Select the smallest useful agenda.** Three to five checkpoints **per independent semantic delta
7a named**, and the page's **ceiling** at the outside — seven, nine or eleven, set by the files and
changed lines of the Production bucket. `report-format.md` § *Ranking by delta* owns the tiers and
how they are counted; test, generated and docs files never count, so a regenerated lockfile buys no
room. Fewer for a PR small enough that three would be
padding — a run that reached this step on a diff step 3 nearly stopped for may have one. Ask: *if the
reviewer understood and investigated these, would they have the right mental model of this change?* If
yes, stop.

**The count follows the delta; the ceiling follows the application code; neither follows the raw
diff.** One delta is three to five whatever the diff weighs: eighty files of one rename is one judgment, and one behaviour reaching across four layers is
also one — its reach becomes *Look at* entries, a figure and a card in section 05, not more
checkpoints. Two delta bullets in *What changed* is what earns a sixth behavioural judgment; a higher
ceiling earns none on its own — it is room for more deltas and for the structural questions, never a
target. The delta bullets are on the page, so the reader has already been told why the agenda is
longer; never name the tier.

**A sixth candidate under one delta is a signal to merge again**, not to add a sixth; if it will not
merge, the checkpoint nearest to it names it in one clause. At the ceiling, stop adding: write
7a's bundling sentence in *What changed* and, if you skimmed, the statement of which region. One past
the ceiling is a list the reviewer will triage instead of an agenda they can hold.

**Two conditions on going past the fifth**, and check both before you do:

- **Every checkpoint is routable from section 04** — its own stop, or a stop whose `span.why` names
  it. If routing them all would consume the whole reading order and leave no room for conceptual
  sequence, the agenda is wider than the page carries. `report-format.md` § *Section 4* owns the rule.
- **It rests on a note you traced, not one you glanced at.** `$W/analysis/` records which is which. A
  checkpoint built on a glance is the page's weakest claim sitting under a heading that promises the
  exact lines that settle it — and on a strained run the glanced notes are exactly the ones a wide
  agenda reaches for.

**A short agenda on a large diff is two different things, and you have to say which.** Two checkpoints
over sixty files is either a merge that went well or a trace that stopped early. Decide it here: if
7c genuinely collapsed the diff to two questions, that is the right page and nothing is owed. If you
ran out of room, the region you skimmed is stated in *What changed* under § *How big should the page
be?*, which is the rule that already covers it.

**A finding that does not become a checkpoint is not lost** — affected code keeps its entry in
*Impact outside the diff* or in the evidence foot, which is what makes leaving it off the agenda
honest rather than hidden. **A judgment is the exception**: an entry in
the foot the reviewer has to decide about is a checkpoint that was mis-filed, per the hard rule below,
which is why the agenda has room to grow rather than a ceiling that would push one down there. What is
never done is dropping a checkpoint to hit a word count: § *The agenda budget* is guidance on how a
checkpoint is written, never on how many there are.

**Architectural questions and then coding decisions take the last slots, as many as clear their
bars and fit** — fitting is a limit, never a reason, and none is the common right answer. One per
departure or shift, each with its own citation, merged first as in 7c. **They never displace a
behavioural judgment and never take the page past its ceiling**; when room runs out, the most settled
ones stay and architectural questions are kept ahead of coding decisions. **In a refactor delta they
are the judgments**, after its equivalence — say plainly in *What changed* that the delta is a
refactor rather than manufacturing a behavioural checkpoint to sit in front of them.

**7f. Choose each checkpoint's representation.** Every checkpoint has a question and an explanation of
two to four sentences. Then decide whether it also earns a figure, which shape, and how many *Look at*
entries it needs. **Each entry is three things in order — a title, a clause, then the citation.** The title names
what is at that location in two to six words, so four entries can be scanned rather than read; the
file name is not a title, because the citation says that already. `report-format.md` § *The review
checkpoint* owns the rest.

**The chain is earned when the judgment turns on a mechanism the reader cannot hold from prose** — a
guard order, a value derived across three or more hops, a request path with a branch in it. Ask it
affirmatively rather than looking for an excuse: *if the explanation would have to name three hops in
sequence, draw them.* It shows that mechanism **inside the change**, so if the chain you want to draw
crosses into unchanged code, it is an impact path: it belongs in section 05, drawn once, and the
checkpoint says so in a clause.

**A chain is one of four shapes, and it is asked about last.** Before drawing one, ask what shape the
judgment actually has — in this order, stopping at the first yes:

1. Do several independent paths have to preserve one property? → `figure.converge`
2. Does an entity move between named states? → `figure.lifecycle`
3. Did a persistent entity or relationship appear, change or disappear? → `figure.structure`
4. Would the explanation otherwise name three hops in sequence? → `figure.chain`
5. None of these → no figure, which is the commonest answer and a correct one.

Converge is first because the path that does not keep the invariant is the finding, and a chain
drawn through any one path hides it. A figure also has to pass four gates; `report-format.md`
§ *Topology figures* owns them and every shape's rules.

**A converge needs its writer search before it may be drawn.** Its list claims to be every path, and
the missing one is the defect it exists to show. So run the lens's recipe for a changed validation,
callback or default — the bulk writes and direct constructors that skip it — and record it in
`details.searched`. No recorded search, no converge. An unchanged writer it turns up is drawn **in**
the converge as `.ip-aff`, never also as an impact card, and gets a *Look at* entry carrying its clause.

**Write the decision into `agenda.md` before any markup**, one short block per checkpoint that earns a
figure:

```
cp-b figure: converge
  question: which paths must keep ownership history truthful?
  invariant: one open history row per owner and gem
  nodes: ownership confirmed (app/models/ownership.rb:112) · … · gem disowned, skips destroy callbacks (app/models/rubygem.rb:301, unchanged)
  search: rg -n 'delete_all|update_all|update_column' app lib — 1 bypass
```

Step 9 types the figure from that block and nothing else. Deciding the shape and typing it are
different acts, and a figure improvised from the raw notes while writing markup is the one that grows
a node nobody traced.

Diagram and prose have different jobs. The figure says how the value gets there, or which paths must
hold; the explanation says what the reader has to judge about it. **An explanation that walks the
figure node by node is the defect** — it doubles the length and teaches nothing twice, and it is what a
run reaches for when it is unsure the figure landed.

**7g. Select the evidence.** For each checkpoint, take only what is needed to investigate it:

- Which citations are load-bearing for the judgment. Those get a collapsed excerpt beside the *Look
  at* entry they confirm, generated in step 9.
- Which claims carry an evidence tier.
- Whether a probe would settle the question **and would answer where the reviewer runs it** — a
  `pre.probe`, proposed and never run, after the explanation, at most one per checkpoint. **A probe
  whose three-part label you cannot complete — instrument, safety, what the output would settle — was
  not earned.** § *Framework anchors* owns answerability and the label.
- Whether a doc link explains why the framework consequence follows: at most one `a.doc` per
  checkpoint, and never on a claim with no `file:line` beside it.
- **At `--mentor` only: whether that link should be a primer instead.** Ask it of the judgment, not
  of the flag: *would the reviewer decide this better knowing the framework's rule than knowing where
  to read it?* One per checkpoint, three per page, holding that checkpoint's one doc link. **A run
  that earns none writes none** — three is a ceiling, never a quota, and a manufactured lesson turns
  the page into a framework manual. § *Mentor mode* owns the rest.

**The catalogue opens here** — `references/rails-docs.md`, `references/elixir-docs.md`,
`references/rust-docs.md` or `references/react-docs.md`, whichever step 2 named, and not before. It is a lookup table: you go to it with a concept a claim already
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
to understand first for the next file to make sense?* A why says what the file does, and claims it is
the only place something happens only where its checkpoint does — `report-format.md` § *Section 4*
says why that is the sentence most often false at head.

**7i. Identify the external impact.** One to three paths from the notes' *affected, not changed*
entries: each starts in changed code, passes through at least one unchanged consumer, and ends at
something a user or an operator would see. Choosing the third-best over the fourth is the work; the
fourth keeps its entry below the figure or in the foot. **If nothing crosses into unchanged code,
section 05 is omitted and the rail loses its entry** — an empty section saying nothing reaches
unchanged code reads as a clean bill of health.

For each path you keep, settle two things here rather than while typing markup. **What the path is
about** — one or two sentences on what goes wrong and to whom, plus which checkpoint judges it; that
is the card's `p.ip-why`, and deciding it now is what stops it becoming a retelling of the hops.
And **where each node's code is**: every changed and every affected node needs a `path:line` for its
locator, and a node you cannot address is a node you have not actually traced.

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

**7k. Name the context.** At `--context never`, skip this step and write *context: never* in
`agenda.md`. At `always`, read the conditions below with § *How much Context*'s lowered bar; at
`collapsed`, exactly as written. Last, because it is decided against the finished agenda: read each
checkpoint as a reviewer who knows the stack and not this repository, and list what it assumes they
can name — a sequence of requests, a plugin wrapping core code, a domain term a setting introduces.
A concept gets an entry only when **all four** of `references/report-format.md` § *Section 2*'s
conditions hold: a checkpoint uses it, that checkpoint would otherwise assume it, a newcomer to this
repository would lack it, and it is the repository's rather than the framework's. Write the entries
into `agenda.md` under `## Context`, each with its one-sentence *is*, its citation, and the
checkpoint letters that use it; at most five. **No entry is a correct result** when nothing meets all four, and
then the section is omitted rather than stubbed — say *none earned* in `agenda.md` and nowhere else.

**Then ask whether the change moved which request does what** — the request that creates or commits
something moved, a step was inserted or removed, a check moved from one request to another — **and
whether two or more checkpoints turn on that sequence.** Both yes, and Context draws it before and
after as `figure.lifecycle.lc-shift`, in place of the entry that would have said it in words; one
checkpoint relying on it leaves it to that checkpoint's own figure slot, which 7f already settled. Settle it in
`agenda.md` the way 7f settles a figure: the shared first state, each column's states with the
request and the `path:line` behind every transition (the Before column at the base), the one state
that moved, the case the figure draws, and each case that differs in a clause. A sequence you cannot
cite a line for at every step is not drawn. `references/report-format.md` § *Topology figures* owns
the shape.

The trap is a list of what the diff touched. *The controller*, *the plugin*, *the spec* is
inventory, and the per-layer page arriving under a new heading; an entry no checkpoint letter can be
written beside was not earned. The other trap is the judgment arriving early: an entry says what a
thing **is**, never what the change did to it.

**Milestone 2 opens after this step** (step 9), with one pending stub per checkpoint. Milestone 3
follows it once 7i's cards and 7k's entries have checkpoints to point at.

## 8. Verify before asserting — at every publish boundary

This is not a phase that happens once, before writing. The page ships in stages (step 9), so it is a
gate each stage passes before it goes out. Content that has been published cannot be unpublished from
the reader's memory, and a wrong claim corrected in the last stage was still wrong in the first.

- **Read the file yourself before any claim reaches the page.** Not the diff hunk — the file. This is
  the single difference between a page that can be trusted and one that cannot.
- **Label the tier of anything the diff does not show directly.** Five tiers, rendered per
  `references/report-format.md`: explicitly changed · evidenced by unchanged code · inferred from
  tests · inferred from naming or architecture · uncertain. Silence means the first one. Never let an
  inference sit in the page wearing the clothes of a fact. Three wear them most often, because the
  page shows the lines they are built from: what happens when two requests interleave, that nothing
  else reads, writes or calls something, and what the language or a library does with a value. The
  reference's § *Evidence tiers* says what each needs before it is stated plainly; the one most
  often false is the absence, and it is written only after naming every hit its search returned.
  A claim keeps its tier wherever it is restated — a *Look at* clause, an impact card's
  `p.ip-why`, a stop's why — because a reader may meet it there first.
- **No label is not no citation.** A claim about an untouched line of a changed file carries no
  tier, and so it carries that line's citation at the claim, in the open page — the diff view does
  not show it, and without the line the reader has no way to check the sentence. A tier or a
  citation in another field, or in the shut search record, does not cover it.
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
  reported"*. Every one had a true and useful fact inside it, buried in the run's own history. This
  file states the observation behind a rule on purpose; that register is for whoever edits the skill,
  never for the page. The reviewer is reading about a pull request; how this
  document got drafted is not part of it. `evals/checks/page-invariants.rb` § 2c fails a page that
  does it.

### Fold the falsifiers' challenges in

At `--effort high` the falsifiers were spawned at the end of step 6 and have been reading while you
synthesised. Their challenges are the second half of this step.

**When.** Before a checkpoint's stub is replaced with the written thing, read whatever has landed for
the notes it draws on. Draft in ranked order; if the next checkpoint's note still has a falsifier out,
draft the one after it. If every checkpoint is drafted and one agent is still out, publish — the rules
above ran on your own reading of the files — and fold the late challenge in as an `Edit`. **Never
idle waiting**: the pass is cheap in wall clock only because you work while they read.

**A launch receipt is not a result.** Before the final publish, account for every reader you sent: a
challenge folded in, or nothing found, or a reader that failed. If one failed, or delegation was
unavailable when step 6c ran, follow your host reference's incomplete-pass rule — say in chat which
note went unchecked, and never treat a partial pass as a completed one. Nothing about that reaches
the page, which carries no account of how hard it was checked.


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

**The correction rule above applies to every claim you revise here.** The pass's own trace is never
a sentence about the pass; it is *"the first version of this section got it wrong"*, and the fix is
the same — correct the sentence, keep the caveat a reader would need, let the draft history go. A
late challenge is still folded in: a claim retracted before the final publish beats one never
retracted.

## 9. Write and publish in stages

A large diff takes many turns to explain, and a reviewer holding a ticket does not want to wait for
all of them. Publish early and republish as parts complete: **the same file path every time, so the
URL never changes.** The reader can open it at minute two, watch it fill in, and start reading the
moment the part they need lands. A crash then leaves a useful page rather than nothing.

The host reference supplies the delivery mechanics. Claude publishes an Artifact; Codex and every
other host save portable HTML locally. There, every later “publish” means saving that same local file,
not calling a publishing tool. `Write` and `Edit` below mean file creation and targeted edits
with the host’s available tools, not required tool names.

**Non-interactively (`--output`, step 1) the stages are save points, not arrivals.** Write each to
`<dir>/index.html` as it completes, with `Edit` exactly as below, skip every `Artifact` call, and do
not spend a turn announcing a boundary nobody is watching. The banner and the markers still come off
at step 10, and the CI adapter refuses a page still carrying one. **With `--update` there are no
stages and no banner at all** — `references/update.md` owns that run's writing.

**Four milestones.** Each is a coherent thing to read — a URL that changes under someone
mid-paragraph is worse than one that arrives late.

| Stage | After step | The page holds |
|---|---|---|
| 1 · Orientation | 4 | The skeleton, written once by `page-skeleton.sh`; then the masthead and *What changed*, with sections 02 to 05 marked pending — at `--context never`, section 02 and its rail entry are deleted here instead, since nothing will fill them |
| 2 · Agenda | 7, then per checkpoint | Section 03's heading, its one lead sentence, and one pending stub per checkpoint carrying its question. Then each checkpoint replaces its own stub as it is written |
| 3 · Context and impact | 7i and 7k, after stage 2's opening publish | *Context*, as step 7k settled it (inside its fold at `--context collapsed`) — or its stub and rail entry removed when nothing was earned — and *Impact outside the diff*, as step 7i settled it |
| 4 · Complete | 10 | *Read the code in this order*, the evidence foot, gate passed, build banner and every marker gone |

**Context and section 05 arrive after the agenda because they point into it.** Every Context entry
and every impact card's `p.ip-why` ends in a pointer at a checkpoint, and until stage 2's opening
publish has landed the stubs there is no `#cp-x` to point at. *Read the code in this order* is a
route through the checkpoints, so it is written last and lands with the evidence foot. The
falsifiers fold in during stage 2 (step 8) and add no milestone.

**The checkpoint is the unit of staging, not section 03.** `<section id="attention">` carries the
heading and its lead sentence, and each checkpoint is its own `<section class="cp" id="cp-x">` with
a unique `id` — the anchor a later stage edits. Take the per-checkpoint rail marker and the pending
stub from the template rather than inventing markup. Stage 2 **opens with a cheap publish**: the
heading, the lead, and one stub per checkpoint whose line of substance is **the question** — a reader
learns what the judgments *are* before any is written. Then:

- **One publish per checkpoint that lands, not per edit.** Two landing in one turn share a publish.
- **Publish in the turn that completes the stage, never in a turn of its own.** Send the `Edit`s and
  the `Artifact` publish together; the calls run in order, so the publish carries the edited file. A
  publish alone in a request re-bills the whole context for one call.
- **Step 8 is the gate on each of them.** A checkpoint is published when it is verified, not when it
  is drafted.

**Every turn from here re-bills the whole context**, which by stage 2 is past 200k tokens. So **make
every `Edit` that is ready in the same turn, side by side** — edits to different ids do not touch each
other — and **do not inspect the page to find where an edit goes**: every anchor is an `id` or a
marker the template names. When one is genuinely in doubt, `grep -n` for it in a call that does other
work. **Write to the budget as you draft** (§ *How big should the page be?*); compressing afterwards
pays for the same prose twice and tends to cut the clause a claim rested on.

**Fill the page in; never rewrite it.** After the first `Write`, every later stage replaces a
*pending* marker with `Edit`. Re-emitting a page already on disk is the single largest cost a profile
of this skill has found — one run's finished page as a single 35,000-token `Write`, 56% of everything
it streamed — and the pending marker is the anchor you already have. Its read-side twin holds too:
never read the page whole.

**Write the markup the way the template writes it, prose included**: tags on their own lines, one
component per block, and paragraph text wrapped at about a hundred characters, never one long line
per element and never minified. A later stage edits a block it has to be able to name, and the page
checks scan by line.

**Until the final publish the page carries the build banner and a *pending* marker** for every part
still to come, in the rail and in place — never an absence and never an "N/A".
`references/report-format.md` § *Build state* has the form. The page fills in out of document order,
and the markers are what keep an unwritten section from reading as an empty one. **Pin the title and
favicon at the first publish** and never change them: readers find a tab by its name and icon.

Everything else about writing holds at every stage:

- **Write the skeleton once, before anything else in stage 1:**

  ```sh
  <skill base directory>/scripts/page-skeleton.sh --out "$W/page.html" --title "<PR title or branch>"
  ```

  It writes the head, the repository's **theme** (`review_map.theme`, else Daylight — the script
  finds it) and the page's one script, and HTML-escapes the title, so do not write it again. **Pass
  no `--theme`**: the look is the team's setting, not the run's. If it refuses the theme or the file
  (exit 2), stop and report its message; it refuses with exit 3 if the page already has content. The
  first `Edit` then replaces the one line containing `SKELETON:BODY` with the rail, `<main>`, the
  build banner, the masthead and section 1. The line after it is the skeleton's own `</main>`, so
  **open `<main>` and never close it** — every later section goes in before that line.

  **Make that one call do the writing's lookups too**, since each would otherwise cost a request at a
  context past 200k tokens: write the markup half (`page-skeleton.sh --markup`) to `$W/markup.html`,
  print `scripts/excerpt.sh`'s usage (`sed -n '2,/^[^#]/p'`), and at rung 1 or 2 write each changed
  path's `#diff-` anchor — `printf '%s' "$path" | shasum -a 256` — beside it in `$W/anchors.txt`.
  Read `$W/markup.html` in one turn: two `Read` calls side by side, offsets 1 and 501 with a limit of
  500, one more at 1001 only if the second came back full.
- **The template is the design system.** Follow `references/page-template.html` for the components
  and `references/report-format.md` for what goes in them, which step 7 has already read: § *One
  canonical home* for what each section owns, § *Chains*, § *Topology figures* and § *Impact paths*
  for every figure, § *Source excerpts* for the excerpt budget and placement, § *Framework anchors*
  and the catalogue's § *Pinning* and § *What the marks mean* for every doc link, § *Mentor mode* for
  the primer, § *Deep links* and § *When the diff will not render* for every href. Two of those
  decide a sentence as you write it: **every doc link is a catalogue row pinned with the versions
  step 2 recorded** — no verified path for this version, no link, and the claim rests on its repo
  line in prose — and **an excerpt plus one sentence of implication beats a paragraph narrating the
  code** (§ *Excerpts are also the shortest way to say what code does*).
- **Never write a `<style>` block, a `:root`, a colour, or a `<script>` into the page.** They are
  already there and **you have not read them**, so a token you name is a token you guessed. **Never
  write a `target` on a link**: the page's script opens off-page links in a new tab on load and
  exempts the page's own pointers.
- **The rail you are given is the rail to publish.** Copy it; do not renumber it. Remove the 05 entry
  only when step 7i found nothing crossing into unchanged code and the 02 entry only when step 7k
  earned no concept or `--context never` skipped it, removing the section with it. A rail reading 01,
  03, 04 says a section was omitted, which is true.
- **Inherit the markup, never the strings.** Every label in the template's assembled examples — a
  figure's box captions, a primer's prose about `ActiveModel::Dirty` — is a claim about a file, and a
  claim copied out of a specimen is a false claim nothing catches. Type a topology figure only from
  its `agenda.md` block, and the shift from the one step 7k wrote.
- **Figures are components, and there is no `<svg>` on this page.** A component reflows, has no
  canvas to overflow and cannot be drawn wrong; the only thing left to get wrong is whether the edges
  are true. A chain that lands in unchanged code is an impact path, drawn once in section 05.
- **Generate source excerpts; never type them.** An excerpt is a quotation, and a paraphrased
  quotation is a false one nothing catches. The script reads the real bytes, escapes them, tags the
  language and derives the state tag from the diff:

  ```sh
  <skill base directory>/scripts/excerpt.sh --at app/models/project.rb:41-52 --base BASE --blob URL --in-entry
  <skill base directory>/scripts/excerpt.sh --diff app/models/project.rb --base BASE --link DIFF_ANCHOR --why "..."
  ```

  **Both forms need `--base`**, because the tag is a claim about the diff. Pass `--blob` or `--link`
  whenever the rung allows; an entry with an excerpt has no `a.path` of its own and uses `--in-entry`.
  **Generate all of them in one call**, one line per excerpt, each to a file in `$W`. **Never read the
  generated HTML back and retype it**: leave a one-line placeholder where each belongs and splice the
  files in with shell at the end. Never write a colour class into the code; pass `--lang` only when
  the extension lies.
- **A probe is proposed, never run**, in the project's real constants and module names, with the
  runner and safety rule the lens's § *Runtime probes* gives for this stack. The hard rules say why
  no output ever follows it.
- The page lives at `$W/page.html`, or `<dir>/index.html` with `--output`, and never in the repo.
  Excerpt fragments go in `$W` either way.

Tell the user the URL (or local file link outside Claude Code) when stage 1 goes out, say it will fill
in, and do not repeat it on every republish — one link, mentioned once, then a note when it is
complete. With `--output` there is no URL: say where the file is, once.

## 10. Complete the page and gate it

- **Remove the build banner and every pending marker** — including the per-checkpoint stubs and the
  rail's checkpoint markers from stage 2. A finished page still carrying "2 parts still pending" is the worst
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
  carrying the git status letter and line counts. No section, no attention level, no group: where a
  reviewer's attention goes is said by the reading path, and a column ranking every file beside it is
  a second inventory.

  **It does not go in section 05.** That section is about consequences, and a list of every changed
  file inside it is exactly the shape above.

  **Pass the link option your rung earned**, so the rows come out linked and you never type inside the
  cell the gate reads:

  ```sh
  <skill base directory>/scripts/ledger-rows.sh BASE HEAD --paths-only --pr owner/repo#N                 # rung 1
  <skill base directory>/scripts/ledger-rows.sh BASE HEAD --paths-only --compare owner/repo@base...head  # rung 2
  <skill base directory>/scripts/ledger-rows.sh BASE HEAD --paths-only --blob owner/repo@sha             # rung 2, base unpushed
  <skill base directory>/scripts/ledger-rows.sh BASE HEAD --paths-only                                   # rungs 3 and 4
  ```

  **`--paths-only` is on every one of them, and dropping it is not a smaller row.** Without it the
  script emits the four-cell classified form, three cells of which are the literal placeholders
  `{{SECTION}}`, `{{READ|SKIM|MECHANICAL}}` and `{{PRIMARY|SUPPORTING|SECONDARY}}` — a shape the page
  stopped carrying. Nothing catches it: `data-path` is on the first cell, so `coverage-gate.sh` still
  passes, and the placeholders ship in the evidence foot of a page that passed its own gate.

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
- **Lint the finished page, and act on what it prints.** After the banner and every marker are gone
  and the gate has passed, from inside the repository under review like the gate:

  ```sh
  <skill base directory>/scripts/page-lint.sh <page.html> --repo . --base BASE --head HEAD
  ```

  Shell and awk, nothing else, so it runs wherever the skill does. It prints `PASS`, `WARN`, `FAIL`
  and `SKIP` lines and exits 1 only on a FAIL. **The one FAIL is a placeholder** — `{{…}}` left on
  the page is the template copied and not filled in — and it is fixed before the final publish.
  **The WARNs are read one by one**: each names a sentence whose evidence tier disagrees with the
  diff — a sentence citing a file outside the diff with no tier, a `from unchanged code` with nothing
  cited beside it, a `from unchanged code` on a sentence whose only citations are files in the diff
  (`references/report-format.md` § *Evidence tiers*). Where the script is right, fix the sentence —
  cite the line, add the tier, drop the label — as a correction that replaces (step 8), never as a
  note about the page's own drafting; where it is wrong about this page, leave the sentence and say
  so in chat. Re-run after the fixes; `Edit` the sentence the WARN quotes rather than re-reading the
  page whole. **Run the gate, the lint and a grep for leftover markers in one call, fix everything
  they print in one turn of side-by-side `Edit`s, then re-run that one call** — a fix per turn
  re-bills the whole context for every sentence. A fix can raise a WARN of its own, so keep going
  until the call prints nothing you have not already fixed or answered in chat; it is usually one
  more round. Nothing about the lint reaches the page, which carries no account of how it was
  checked.
- Publish the final state to the same path — or, with `--output`, simply leave the finished file at
  `<dir>/index.html`; there is nothing to publish and nothing to remember. Report that it is complete,
  what the change does in two or three lines, and anything you could not verify. Mention the project's
  own review command if it has one.
- On a re-run for the same PR, the path is the **same one step 1 derives**, so the previous page is
  found without remembering where the last run put it. `--update` edits that page and keeps its
  link; whether a fresh run publishes over an earlier link is the host reference's rule, and in
  Claude Code it does not.
- **The inventory and this gate are in full on an update too**: the block regenerated whole, never
  patched with the delta's rows, and the gate over `BASE...HEAD` — `references/update.md`
  § *Finishing*.

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

## Working in a worktree

Worktrees are among this skill's most common targets, and a worktree-isolated session sandboxes shell
commands: compound one-liners that chain `git` with `grep`, `&&`, or a redirect are refused as
unverifiable. Run those as separate plain commands. Budget a few extra turns for it rather than
fighting the sandbox with quoting.

## How big should the page be?

Short by design and long by exception, and the two are governed differently.

**Prose is governed by guidance**, in `references/report-format.md` § *The agenda budget*: 80 to 160
words for *What changed*, 50 to 140 a checkpoint, and a page total that is those parts summed — about
700 to 1,500 visible words at four checkpoints on a small or medium PR.

**A hundred-file diff legitimately runs past those numbers, and what it buys depends on why it is
big.** If the bulk is one change — a rename, a codemod, one behaviour reaching a long way — it buys
more *Look at* entries per checkpoint, the impact figure's third card, and an inventory that grows
with the diff at no cost to anyone, because it is collapsed. **The agenda does not move**: eighty
files of one transform is one judgment. If the PR instead ships genuinely independent changes, *What
changed* says so in a bullet each, and the agenda grows with them — three to five per delta, under
the ceiling the Production bucket sets: seven, nine or eleven (step 7e). Step 7e has both conditions
on going past the fifth.

The ceiling is a stop because past it section 04 can no longer be a route: every stop has been spent
naming a checkpoint, and the reading order has become an index of the agenda. It rises with the
application code because more of it is more to route through — and a page that cannot route every
checkpoint through three to seven stops is wider than it carries, whatever its tier.

**A mentor page is that budget plus its primers**, each 90–200 words and at most three of them,
counted separately for the reason § *The agenda budget* gives: folded in, a run would buy a lesson by
dropping a judgment. Nothing else about the length changes, and the flag is never a reason to write a
longer explanation, a sixth checkpoint or an extra *Look at* entry.

**Trim only content that fails its own test** — a chain whose explanation walks its nodes, a *Look at*
entry with no clause or with a title that only repeats its own citation, an explanation that restates
*What changed*, a checkpoint that turns out to be a category. Never trim toward an imagined length, and **never trim a checkpoint out**. A page that
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
- **Never carry a claim across revisions without saying so on the page.** An update
  (`references/update.md`) leaves parts that were analysed at an earlier head, and a page describing
  an earlier revision while looking current is the one failure a reader cannot detect from the
  inside.
  The masthead names both revisions and *What changed* carries one sentence; the wording is
  `report-format.md` § *Build state* § *An updated page* and it is not composed per run.
- **Never mark a checkpoint by its recency.** No *new*, no *updated*, no *carried*, no count of how
  many were re-derived, and a checkpoint the change has since answered is deleted rather than
  ticked. Three ordered states beside a question is a severity scale wearing different words, and
  an update is the one thing in this procedure that makes writing one feel like helpfulness.
- **Never invent a URL, and never invent output.** Documentation links come from the catalogue the
  stack detected in step 2 — `references/rails-docs.md`, `references/elixir-docs.md`,
  `references/rust-docs.md` or `references/react-docs.md` — and from
  nowhere else, including when that catalogue is closed and the answer is no link at all. Console
  probes are proposed unrun, with no transcript beneath them. The page never shows the result of
  running anything, because the run never booted the application, and a fabricated `=> …` is the most
  concrete-looking thing on the page and the one part of it that is fiction.

  **One exception, and the whole of its safety is the receiver.** At `--mentor` a `pre.demo` inside a
  primer may carry a result line, because it quotes documented framework behaviour on a class **this
  repository does not have** — the manual states results, and quoting the manual is not reporting a
  run. Name one of this application's constants in a demo and it becomes exactly the fiction above,
  with this rule switched off. Nothing else on the page carries output, at any flag, and a `pre.demo`
  outside an `aside.primer` is a general-purpose hole for the same lie.
- **The page must read completely with every collapsed block closed.** Three components collapse — a
  source excerpt beside the entry it confirms, `details.searched`, and `details.evidence`, the foot
  that is section 06 — and the rule is the same for all three: they confirm a claim the prose already
  made, and never carry one. A claim that exists only inside a collapsed block is hidden content
  wearing the clothes of progressive disclosure. Judge this **entry by entry**: a citation that
  appears elsewhere on the page does not rescue a *Look at* entry whose only `file:line` is inside the
  block a reader has not opened.

  For the search record the trap is the empty result: "no other caller" is a finding and belongs in
  the open; the grep proving it is what collapses. For the foot the trap is **promotion by omission** —
  lower-priority affected code and the recorded searches may live there because they are provenance,
  but nothing a reviewer acts on may live *only* there. If an entry in the foot is a judgment they
  have to make, it is a checkpoint that was mis-filed.
- **Never imply the page found everything, and never write a disclaimer saying so.** It did not find
  everything, and measurably so: three independent analyses of the same 109-file diff produced eight
  distinct headline findings between them, with only *one* appearing in all three. Explanation is
  reproducible; defect discovery is sampling. That fact is true of every Review Map rather than of
  this one, so it is stated **once for the tool** in `README.md` § *What a Review Map cannot do* and
  **never on the page** — a standing caveat under a heading is boilerplate the second time a reviewer
  sees it, and it teaches them to skim the line beneath it. What the page owes instead is silence
  about its own coverage: no *no issues found*, no *the change is safe*, no *nothing else reads this*
  that a search did not establish, no summary claiming the diff was fully covered, and nothing
  anywhere that reads as a clean bill of health. Where a reviewer needs assurance rather than
  orientation, point them at a dedicated review pass.
- **Never draw an `<svg>`.** The page's figures are components — the vertical labelled chain, the
  three topology figures and the `dl.ba` pair — assembled from the template. A drawing derived per run spends the run's attention
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
  word — and its agents go out in a single message, up to the host's concurrency limit, and are not
  waited on, so the run keeps drafting while they read; their results are collected before the final
  publish. Nothing else spawns anything, at any effort level, and a run that reaches for an
  `Explore` agent to help with step 5 has broken this rule whatever flag it was given.
