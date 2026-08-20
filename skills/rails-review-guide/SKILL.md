---
name: rails-review-guide
description: Builds a published HTML walkthrough of a Rails pull request, organized by framework layer, so a reviewer can understand the change before judging it. Invoke with /rails-review-guide, optionally passing a PR number, URL, branch, or diff range.
---

# Rails Review Guide

Turns a Rails diff into one published page that teaches the change: schema as a diagram, endpoints
as a contract, domain logic as cohesive groups, and the decisions worth a human's attention.

**The goal is comprehension, not verdicts.** A PR approved without being understood was waved
through, and the debt lands on whoever touches it next. Verification comes after understanding, so
explanation is the bulk of the page and flags are a section within it.

You are not a code reviewer here. If the project has a review command, say so at the end and let it
do that job. Do not post comments on the PR.

## 1. Resolve the target

- Argument may be a PR number, a PR URL, a branch, or a diff range. With no argument, use the
  current branch against its base.
- Find the base *ref*: the PR's base if there is one, else the default branch
  (`git symbolic-ref refs/remotes/origin/HEAD`, falling back to `main`, then `master`). This gives
  you a ref, not a merge point — do not compute a merge-base yourself. The three-dot diff below
  already resolves it, and hand-rolling one is how you end up diffing against a moved base.
- Use three-dot diffs throughout (`git diff BASE...HEAD`) so you see the branch's own work and not
  unrelated commits from the base.
- **Check the working tree** with `git status --porcelain`. Three-dot diffs ignore it entirely, so
  uncommitted edits mean the guide can describe code that differs from what the reviewer has checked
  out. Say so in the page and cover the committed state only. If the uncommitted changes are
  substantial enough that the guide would be misleading, stop and say why instead.
- If there is a GitHub PR, capture `owner`, `repo`, number, head SHA, title, author, body via
  `gh pr view <target> --json number,title,author,body,headRefOid,headRefName,baseRefName,url`.
  Record the head SHA — deep links depend on it.
- If `gh` is missing or there is no PR, continue anyway with the local branch. This is a normal
  case, not an error.
- **Fix the deep-link mode now, not at render time.** Check whether the head SHA is even reachable
  on a remote — `git branch -r --contains <HEAD_SHA>`, where empty output means it was never pushed
  and every permalink to it would 404. Unpushed branches and worktrees are among the most common
  targets for this skill, so expect this. Pick one mode from the ladder in
  `references/guide-outline.md` and use it for every citation.

## 2. Discover the project

Assume nothing about layout or conventions — this skill travels between repos.

- Locate the Rails root by finding `config/application.rb`. It may be at the repo root, under a
  subdirectory such as `api/`, or there may be several (engines, monorepo). If more than one is
  touched by the diff, ask which to cover.
- Detect, don't assume: RSpec vs Minitest; API-only (`config.api_only`) vs server-rendered;
  the authorization library, if any; the background job adapter; whether `strong_migrations` is
  present.
- Look for the project's own conventions in `CLAUDE.md`, `docs/`, `README`, `CONTRIBUTING.md`. If
  found, check the PR against them. If not, infer the house style from adjacent unchanged code of
  the same kind — often more accurate than a stale document.

## 3. Take the layer inventory

- `git diff --name-status BASE...HEAD` is the source of truth for what changed.
- Bucket every path into a layer: migrations/schema, models, routes/controllers/serializers/views,
  services/POROs/jobs/mailers, config/dependencies, tests, non-Ruby.
- Count changed files per layer. The counts drive section depth — see
  `references/guide-outline.md`.
- **Keep the full file list.** Every path must appear in the finished page. This is a hard
  invariant, checked in step 7.
- If the whole diff is trivial (a few files, no migration, no new behaviour), say so and offer to
  stop rather than generate ceremony. A guide nobody needs is worse than no guide.

## 4. Read the change

- Spawn parallel `Explore` agents for anything beyond a handful of files. Ask each for structured
  findings with exact `file:line` citations, not prose.
- **Size the agents by work, not by layer.** One-per-layer sounds tidy but the layers are wildly
  unequal — a diff can put 2 files in schema and 26 in services. Split a large layer along a
  semantic seam (and say what seam you chose); merge small adjacent layers. Aim for comparable
  reading loads, roughly 4–8 files each.
- Read `references/rails-lenses.md` first and pass the relevant lenses to each agent. They are what
  makes this a Rails review rather than a diff summary.
- **Tell each agent not to rank.** Their brief should say: report what you found with a citation;
  do not assign severity — ranking happens after verification. Without this, agents inflate
  everything to "blocking" and the calibration burden lands entirely on step 5.

  **You** rank, in step 5, on this three-level scale (the template implements it as
  `.chip-block` / `.chip-watch` / `.chip-good`):

  | Level | Means |
  |---|---|
  | **Blocking** | Merging this leaves the repo or a deploy broken. Reserve it; most PRs have none. |
  | **Watch** | Real, worth a decision before merge, but the author may reasonably accept it. |
  | **Good** | A strength worth naming, so the page reads as judgment rather than nitpicking. |
- Mine the decisions section from: comments explaining *why* rather than *what*, commit messages,
  named constants, transaction and lock boundaries, `rescue` clauses, and anything the code
  deliberately refuses to do. Quote the code's own comments where they carry rationale.
- Note strengths as well as problems. A page that only criticizes reads as nitpicking; naming what
  the change gets right is what makes the criticism land.

## 5. Verify before asserting

- Every claim that reaches the "Start here" block must be **independently confirmed by reading the
  file yourself.** Never promote a subagent's finding without checking it. This is the single
  difference between a page that can be trusted and one that cannot.
- Where you could not confirm something, say so in the page as an open question. Do not round
  uncertainty up to a fact.
- Drop any finding that does not survive the check, and do not backfill it with something weaker.

## 6. Write the page

- Follow `references/guide-outline.md` for what sections exist, when they appear, and how deep they
  go. Follow `references/page-template.html` for the design system, layout, and diagram styles.
- **The template is the design system — do not load `artifact-design` to re-derive one.** That skill
  exists to choose a palette and pair typefaces; those decisions are already made here, and its own
  first instruction is to apply an existing system when one exists. Loading it costs a turn and
  yields nothing. Load it only if you have a deliberate reason to depart from the template, and
  `artifact-diagramming` only for a diagram the template's vocabulary cannot express.
- Diagrams are hand-authored inline SVG using the template's classes, so they work in a local file
  as well as when published. A diagram must show a mechanism a table cannot; delete any that merely
  restates a list.
- Render citations in the mode chosen in step 1. Prefer blob permalinks over diff anchors where
  linking is possible: many of the best citations point at unchanged lines, which a diff anchor
  cannot address. If the mode is plain text, say once in the masthead why nothing is clickable.
- Write the file to a scratch location, not into the repo. The guide must never become part of the
  diff it describes.

## 7. Check, publish, report

- **Completeness gate.** Generate the coverage-ledger rows programmatically from
  `git diff --name-status BASE...HEAD` — never by transcription — then assert that the **set of
  ledger path cells equals the set of diff paths**, compared as whole strings.

  Do not implement this as a substring search over the rendered page. That is theatre: `api/Gemfile`
  matches inside `api/Gemfile.lock`, so the check passes on truncated or wrong paths. Compare sets,
  exactly:

  ```sh
  git diff --name-only BASE...HEAD | sort -u > /tmp/diff-paths
  # extract the ledger's path cells to /tmp/ledger-paths, one per line
  diff /tmp/diff-paths /tmp/ledger-paths && echo "gate: pass"
  ```

  Prose elsewhere in the page may cite whatever it needs, including unchanged files — the gate
  governs the ledger only, which is why the ledger has to be machine-generated.
- Confirm the page renders: no horizontal overflow on `body`, diagrams fit or scroll in their own
  container, and all three theme states resolve (`data-theme="dark"`, `data-theme="light"`, and the
  unstamped `prefers-color-scheme` default most viewers get).
- Publish with the `Artifact` tool. Title is the PR title, or `<Branch> Review` with no PR. Give it
  a stable favicon and a one-sentence description.
- Report the URL, the headline findings in two or three lines, and anything you could not verify.
  Mention the project's own review command if it has one.
- On a re-run for the same PR, republish the **same file path** so the URL stays put and the guide
  tracks the PR across pushes.

## Working in a worktree

Worktrees are among this skill's most common targets, and a worktree-isolated session sandboxes
shell commands: compound one-liners that chain `git` with `grep`, `&&`, or a redirect are refused as
unverifiable. Run those as separate plain commands. Budget a few extra turns for it rather than
fighting the sandbox with quoting.

## How big should the page be?

Adaptivity trims ceremony on small PRs; it does not cap large ones. A hundred-file diff legitimately
produces a long reference document — the run this guidance came from wrote ~135 KB and that was
right. The pressure while writing is always to cut, so: **do not trim a large page toward some
imagined ideal length.** Trim only content that fails its own test — a diagram that restates a
table, a paragraph without a citation, a section the diff did not earn.

## Hard rules

- Every claim carries a `file:line`, linked when a link is possible.
- Never invent severity. A clean PR is allowed to read as clean.
- **Never imply the flag list is exhaustive.** It is not, and measurably so: three independent
  analyses of the same 109-file diff produced eight distinct headline findings between them, with
  only *one* appearing in all three. Explanation is reproducible; defect discovery is sampling. The
  page must say plainly that the flags are what this pass surfaced, not a complete defect list, and
  must never read as a clean bill of health. Where a reviewer needs assurance rather than
  orientation, point them at a dedicated review pass.
- Never drop a file from the page to keep it tidy.
- Never post to GitHub, Linear, or anywhere outside the artifact.
- Never commit the guide into the repo under review.
