# The report format

What parts exist, when each appears, how deep it goes, and the two primitives the page is built
from — the review unit and the evidence tier.

The order below is the default review path, not a mould. Derive the actual order from the PR's own
goals: if the change is a client-side refactor with one new field behind it, the contract section
leads and persistence is a paragraph. A part the diff does not earn is **omitted**, never filled with
generic content and never left as an "N/A" placeholder.

---

## Contents

**Primitives and rules** — read these before writing anything.

- *The review unit* — the seven fields every meaningful change gets
- *Evidence tiers* — five tiers, and the rule that only four of them get a label
- *Depth rules* — how much treatment a part earns, and the diagram budget
- *The completeness invariant* — why every diff path appears, and why the check is one-directional
- *Build state* — the banner and pending markers that keep a staged page honest while it fills in

**The parts, in default order** — each with what triggers it.

| | Part | Appears |
|---|---|---|
| 0 | Masthead | always |
| 1 | Goal and behavioural change | always |
| 2 | Review map | always — the blast radius, and the highest-value screen |
| 3 | State and persistence | migrations, schema or models changed |
| 4 | API surface | routes, controllers, serializers or views changed |
| 5 | Backend ↔ frontend contract | the diff touches either side |
| 6 | Behaviour cohorts | the bulk — one review unit per cohort |
| 7 | Cross-cutting concerns | any apply |
| 8 | Test harness | test *infrastructure* changed |
| 9 | Agentic and developer tooling | it changed |
| 10 | Primary, supporting and secondary | the split is non-trivial |
| 11 | Comprehension checkpoint | always |
| 12 | Coverage ledger | always |

**Citations** — *Deep links*, the two URL forms, and *Choosing a mode*, the four-rung degradation
ladder. Settle the mode once, in step 1 of the procedure.

---

## The review unit

The page's reusable primitive. Every meaningful change — usually one per behaviour cohort, sometimes
one per significant standalone change — renders as a unit with these seven fields, in this order:

| Field | Carries |
|---|---|
| **Why this exists** | One or two sentences of purpose, in behavioural terms |
| **Implementation** | The `file:line` citations that make up the change, in reading order |
| **Relevant tests** | The specs that pin this behaviour, cited the same way, plus what they leave open |
| **Affected but unchanged** | Code the change gives new meaning to, with a citation and a clause on why it is affected |
| **Things to understand** | The invariants, defaults and decisions a reader would not have guessed from the diff |
| **How to validate** | Numbered, pasteable steps against this repository |
| **Reviewer questions** | Open questions, phrased as questions |

Rules that keep units from becoming ceremony:

- **A unit needs a non-obvious *things to understand*.** If the field can only be filled with
  restatements of the diff, this change is not a unit — it is a ledger row.
- **Fields may be omitted, but never faked.** No *affected but unchanged* code found, after a search
  worth reporting? Say what you searched and that nothing consumes it. That sentence is the finding.
- **Validation steps must exist in this repo.** The real rake task, the real route, the real factory.
  One invented command spends the reader's trust in the entire page.
- Render as `article.unit` with `.ep-row` field rows — see `page-template.html`.

## Evidence tiers

The page's second primitive, and what separates it from a plausible-sounding summary.

| Tier | Means | Rendered |
|---|---|---|
| Explicitly changed | The diff shows it | **No label.** Silence means this tier |
| Evidenced by unchanged code | A file outside the diff proves it, and is cited | `<span class="tier">from unchanged code</span>` |
| Inferred from tests | The expectation implies the intent | `<span class="tier">inferred from tests</span>` |
| Inferred from naming or architecture | The weakest defensible inference | `<span class="tier">inferred</span>` |
| Uncertain | Could not be established | `<span class="tier">uncertain</span>` + say what would settle it |

**Place the label against the claim, not between sentences.** A tier that lands after a full stop
reads as a footnote marker and the reader has to work out what it refers to. Put it at the end of the
clause it qualifies — *"…on the /my-day and /my-week screens `inferred`. The diff adds…"*, not
*"…screens. `inferred` — the diff adds…"*.

**Label only the tiers that are not "explicitly changed."** Labelling everything is noise, and noise
gets skipped, which defeats the purpose. Labelling nothing lets inference pass as fact, which is
worse than being wrong loudly.

The PR description is never evidence. Where the page reports intent from it, attribute it —
*"the description says …"* — so a stale description cannot masquerade as a property of the code.

## Depth rules

Depth scales with how much the diff puts into a part, on the same shape as before:

| Weight of the part | Treatment |
|---|---|
| Nothing | Omitted entirely |
| One small thing | A paragraph, or a row in a shared "also changed" table |
| A handful | Its own subsection with a table |
| Substantial | Subsection, plus grouping or units, plus a diagram if one is earned |

For behaviour cohorts, weight is the number of cohorts and how far each reaches, not the file count —
a two-file cohort spanning a serializer and a TS type can need more explanation than an eight-file
one that is a single rename.

File count sets *prose* depth. It does not set diagram count — **diagrams are earned by mechanism
complexity, which is a different axis.** A six-file migration introducing a state machine can need
two figures; a twenty-six-file layer that is one linear pipeline needs one. Judge on how many
distinct mechanisms a reader has to hold, not on how many files carry them.

**Diagram budget: one per part, and a second only for a genuinely different mechanism.** Each must
show something a table cannot. A diagram that restates a list is worse than no diagram, because it
costs the reader time and teaches nothing.

The one place a second is routinely earned is persistence: an ER diagram shows *structure*, a
lifecycle diagram shows *behaviour over time*, and no single figure shows both. If the diff adds a
status column or state machine on top of new tables, draw both. Elsewhere, if you find yourself
wanting a second diagram, the honest question is whether the first one is doing its job — and a
transition table with a `file:line` per row is often better than a second figure anyway. Never exceed
two in one part.

Adaptivity trims ceremony on small PRs. It never trims teaching on a large one — on a big change,
explanation is the whole product.

## The completeness invariant

**Every file in the diff appears somewhere in the page.** A reviewer who wants to read all of it must
be able to, and must never wonder whether something was quietly skipped.

The depth rules govern *how much treatment* a file gets, never *whether it is accounted for*. Files
needing no discussion are still listed, batched into a compact table with a one-clause reason
("regenerated by the migration", "import path updated", "factory for the new model"). Renames and
pure moves get a line saying so, which is itself useful.

**The invariant is one-directional.** Every path in the diff must appear in the page. The reverse does
*not* hold: the page cites unchanged files everywhere by design — that is what part 2 and the
*affected but unchanged* field are for. So the check is a subset test, never set equality:

```
set(diff paths) ⊆ set(paths cited in page)     ✅ the invariant
set(paths cited in page) == set(diff paths)    ❌ impossible by construction
```

The one place equality *is* asserted is the coverage ledger, which is machine-generated from the diff
for exactly that reason. Never "fix" a surplus elsewhere by deleting a citation to unchanged code.

---

## Build state

The page ships in stages and fills in at one URL (`SKILL.md` step 9). That only works if a
half-written page cannot be mistaken for a finished one, so the page carries its own build state
until the moment it is complete.

**Three states, and they must not look alike.** The confusion this prevents is a reader seeing no
contract part, concluding the change has no contract implications, and being wrong.

| State | Means | Rendered |
|---|---|---|
| **Written** | The part is there | Normally |
| **Pending** | This diff earns the part; it is not written yet | An explicit marker, in the rail *and* in place |
| **Omitted** | The diff does not earn it | Nothing at all. Never an "N/A" row, never an empty section |

**The banner** sits above the masthead until the final publish:

```html
<div class="buildstate">
  <strong>Still being written</strong> — stage 2 of 3, updated 14:32.
  Parts marked pending below are not yet written. Their absence is not a finding.
</div>
```

That last sentence is the load-bearing one. Keep it.

**Pending in the rail** so the reader can see the shape of what is coming:

```html
<li><a href="#contract">Backend ↔ frontend contract <span class="pending">pending</span></a></li>
```

**Pending in place**, where the part will go, so someone scrolling does not skip past a gap:

```html
<section id="contract">
  <div class="layer-head"><p class="eyebrow">Contract</p><h2>Backend ↔ frontend contract</h2></div>
  <p class="note"><span class="pending">pending</span> Seven files touch both sides; this part is
  being written.</p>
</section>
```

One line of substance in the stub — how many files, what it will cover — turns a placeholder into
information. "Coming soon" does not.

**The coverage ledger is marked partial** until the final publish, because the gate has not run. Say
so above the table rather than letting a short ledger imply a short diff.

**A run that stops early is a third state, not a draft that never finished.** Same components,
different words: the banner states what was covered and that the run stopped, every marker changes
from *pending* to *not written*, and the ledger note says the gate never ran. The distinction is the
whole point — *pending* is a promise, *not written* is a fact, and a page left promising work that is
not coming is the one outcome worse than publishing late. `SKILL.md` § *When a run stops early* has
the wording.

**At the final publish, all of it goes**: banner, rail markers, stubs. A finished page still saying
"stage 2 of 3" undersells completed work and leaves the reader unable to tell whether the run
stopped early. If a part genuinely was left unwritten — the diff was too large, a region got skimmed
— that is a sentence of prose stating the limit, not a pending marker. The two mean different things:
pending is a promise, a stated limit is a fact.

## Part 0 · Masthead — always

- PR title and number, branch → base, author, linked ticket if the project uses one.
- Metric strip, restricted to metrics that change a reviewer's behaviour: commits, files, and a line
  split. A PR that is 70% specs is a different animal from one that is 70% new controllers.

  The buckets are fixed, so numbers stay comparable between runs:

  | Bucket | What lands in it |
  |---|---|
  | Production | Application code a human wrote and a human must review |
  | Test | Specs, test support, factories, fixtures, VCR cassettes |
  | Generated | `db/schema.rb`, `db/structure.sql`, lockfiles, generated API types, compiled or vendored assets |
  | Docs | Markdown and other prose |

  Count generated and docs separately rather than folding them into production — a 150-line
  `schema.rb` churn is not 150 lines of review surface, and reporting it as such makes every large
  migration look terrifying.
- **Change shape** chip: feature / refactor / bugfix / migration / dependency bump / mixed. Reading
  strategy differs per shape; naming it sets expectations.
- One paragraph on what the PR does, in plain language, **derived from the code and commits — not
  copied from the PR description.**

## Part 1 · Goal and behavioural change — always

What the change is *for*, before any mechanism. One block per use case:

- **Actor and behaviour** as a sentence — "a workspace admin can archive an active project".
- **Before / after**: what was possible, what is now possible, what is now prevented.
- **Main path** as a chain, rendered with `ol.steps`: UI → request → controller → operation → model →
  column, and the response path back if it carries anything interesting.
- **Evidence tier** on the intent itself. Behaviour pinned by a test is not the same claim as
  behaviour inferred from a service class's name, and the reviewer's next move differs.

Where intent cannot be established, state the gap as a gap: *"whether existing entries stay editable
after archival is not settled by any test."*

## Part 2 · Review map — always

The highest-value screen, and where the work from step 5 lands.

- **Blast-radius diagram** — the primary flow end to end, with secondary effects branching off it.
  Changed nodes solid, affected-but-unchanged nodes dashed (`.node-dead`), legend required. This is
  the one diagram that earns its place on almost every PR, because it is the only view of the change
  that a diff cannot produce at all.
- **Changed vs potentially affected** — two lists, side by side. The second is the point of the page:
  every entry carries a citation and a clause on *why* it is affected. If the search came up empty,
  say what was searched.
- **Start here** — the two to five things most needing human judgment. Each is a *statement about the
  code* plus why it is load-bearing plus a link to its unit — never a grade. No severity chips, no
  approval language. If nothing rises to that level, say so plainly rather than manufacturing
  concerns.

  Carry one line of honesty with this block: these are what this pass surfaced, not an exhaustive
  list. Repeated runs over the same diff surface overlapping but different sets — the explanation is
  stable, the findings are a sample.
- **Reading order** — a numbered path through the files, each with a one-line *why this before that*.
  Good defaults: schema before the code that uses it; the smallest complete example before the bulk;
  irreversible code last, read twice.
- **Where the attention goes** — which handful of files carry the design, and which are mechanical. A
  71-file PR where 6 files matter should say so on the first screen. This ranks the work; it excuses
  nothing from coverage.

## Part 3 · State and persistence — if migrations, schema, or models changed

Early, because it establishes the vocabulary every later part uses.

- **ER diagram** of touched tables plus immediate neighbours only, never the whole schema.
  Distinguish new, modified, and untouched-but-adjacent tables. Draw absent relationships when the
  absence is the point (a write with no foreign key back to its origin, for instance).
- **Migration safety table** — the Rails knowledge a diff view cannot give you: reversible? locks a
  table? index added concurrently? `NOT NULL` plus default on an existing table? backfill in the same
  migration as the schema change? destructive drop? Deployment compatibility between old and new
  application versions during a rolling deploy.
- **Invariants, split by where they are enforced.** Application invariants and database invariants
  side by side:

  ```
  Application   Project#slug validates uniqueness          app/models/project.rb:22
  Database      no unique index on projects.slug           db/schema.rb:141
  ```

  The gap between the two columns is reliably where the interesting problems live, and it is
  invisible in a diff that touches only one of them.
- **Lifecycle diagram** — only if a status column, enum, or state machine is added or changed. Label
  every transition with the `file:line` that performs it; that is what reveals whether transitions
  are guarded at all, or whether any caller can move a record anywhere.
- Callbacks, validations and scopes added; data backfills and their rollback story.
- **Schema consistency check** — does the committed schema match what the migrations produce? Cheap
  to check, and a real source of blocking-grade problems (which the page reports as a fact and its
  consequence, not as a grade).

## Part 4 · API surface — if routes, controllers, serializers, or views changed

Reconstruct the *interface*, do not list the controllers. The reviewer should be able to answer "what
are we now exposing?" before reading any implementation.

**API mode**
- Route table: verb, expanded URL, `controller#action`.
- Per-endpoint contract cards (`article.endpoint`) carrying: purpose; params with required/optional
  and where they are coerced; a real success body; the **full** error list with statuses; delegated
  services; and a **side-effects row** — reads only / writes / calls an external service / idempotent
  or not. That last row is the reviewer's actual question and no diff answers it.

**Server-rendered mode**
- User flow diagram: page → action → redirect or render.
- Forms and permitted params, flash and error states, per-action authorization.

Both modes also get an **authorization matrix** (who can reach what), and a sequence diagram only
when a request involves three or more participants.

**Contract conformance.** If the project documents its conventions, check against them. If not, infer
the house style from adjacent unchanged controllers and note whether the new code is internally
consistent with its neighbours — the portable move, and often more accurate than a stale document.

## Part 5 · Backend ↔ frontend contract — if the diff touches either side of it

First-class, because this boundary has no compiler and no test that spans it.

- **The chain**, rendered as one figure or `ol.steps`, per field or endpoint that changed:

  ```
  ProjectSerializer#archived_at → GET /api/projects → Project.archivedAt
    → useProjects() → ProjectSelector
  ```

  Following one field across the boundary teaches more than reviewing both sides as separate file
  trees, which is what a diff already offers.
- **Mismatch table** — the failure modes worth hunting, one row each, with both citations:
  nullable backend field typed non-null; backend enum value missing from the frontend union; a new
  error status nothing in the UI handles; response shape changed with stale client code still reading
  the old one; a required param the client never sends.
- **Deploy ordering** — if the two sides ship separately, what breaks in the window where one is
  updated and the other is not. Name the safe order.
- If the frontend is in a different repository, or simply not in this diff, build the backend half and
  say so: what a consumer must change, marked as unverifiable from here. Do not guess at client code
  you cannot read.

## Part 6 · Behaviour cohorts — the bulk

One review unit per cohort, grouped as decided in step 6 and **never by directory**. State the
grouping principle before the units.

Inside a cohort, beyond the seven fields, cover what the behaviour actually depends on: the trigger,
the happy path, the branches that matter, side effects, the data touched, and both ends of the
implementation. Where a cohort has a non-trivial call chain, draw it as an ordered sequence of
classes.

**Decisions to pay attention to** live here — the least automatable and highest-value content in the
page. Each entry: the decision, where it lives, why it matters, and the tradeoff accepted. Mine them
from comments explaining *why*, commit messages, named constants and magic numbers, transaction
boundaries, `rescue` clauses, and anything the code deliberately refuses to do. Quote the code's own
comments where they carry rationale.

## Part 7 · Cross-cutting concerns — if any apply

One subsection per concern the diff actually touches, and no filler: "no meaningful cross-cutting
changes detected" is an acceptable and useful whole section.

Candidates: authorization and authentication; feature flags and their default state; background jobs
(queue, retries, idempotency, ordering, failure mode, safe to run twice?); transaction and locking
boundaries, and what sits outside the transaction; concurrency; caching and revalidation;
observability; environment variables and secrets — including **what happens when unset**, often the
most useful row in the table, because it describes how the feature degrades; new dependencies and why
the version is pinned; external calls with timeout, retry, failure mode and whether they block a
request; performance and N+1; rate limits; server/client boundaries in Next.js and server actions.

## Part 8 · Test harness — if test infrastructure changed

**Infrastructure only.** Tests for a behaviour belong beside that behaviour, in its unit's *relevant
tests* field. This part is for changes to the machinery: factories, fixtures, helpers, shared
contexts, Playwright or Cypress config, mocking infrastructure, database setup, global configuration,
changed testing conventions.

The question here is different from "is this tested?" — it is "does this change how every other test
in the suite behaves?" A factory default that moved can alter specs nobody in this PR looked at.

If the PR adds behaviour with no tests at all, that belongs in the affected units and in *Start here*,
not here.

## Part 9 · Agentic and developer tooling — if it changed

`CLAUDE.md`, `AGENTS.md`, `.claude/`, skills, commands, agents, hooks, MCP configuration,
agent-facing scripts, CI scripts, developer tooling. No runtime impact, and easy to wave through,
which is exactly why it gets a section: these files change how every human *and every agent* works in
the repository from here on.

Per change: what behaviour changed, who or what consumes it, whether it is scoped correctly, whether
a command or hook it introduces is safe and deterministic, whether it influences code generation or
repository operations, and how to validate it.

## Part 10 · Primary, supporting and secondary — always, when the split is non-trivial

Three groups, neutrally framed, each entry pointing at its cohort or ledger rows:

- **Primary** — directly implements the stated use cases.
- **Supporting** — refactors or infrastructure the primary behaviour needed.
- **Secondary** — appears unrelated; independently reviewable.

The purpose is to tell the reviewer which changes they may hold as a separate mental model. It is not
to criticize the author for bundling them, and the page must not read that way.

## Part 11 · Comprehension checkpoint — always

The page's closing move against comprehension debt: several **PR-specific** questions the reviewer
should be able to answer before approving. Rendered as `ol.firstlook`.

```
Before approving, you should be able to explain:
1. What is the authoritative representation of an archived project?
2. What prevents creating a time entry for one?
3. Which existing entries are affected at the moment of archival?
4. How does the client learn a project became archived?
5. Which authorization rule controls the operation?
6. What happens if the two sides deploy at different times?
```

Each question must be answerable from the page plus the code it links to — a question the page cannot
lead the reader to is a gap in the page, not a challenge for the reader. Never a mechanical checklist
(`[x] read the models`); that is ceremony, and it teaches nothing.

Two more closing blocks:

- **Run it yourself** — setup, seeds, and the commands to get the change exercised locally. Per-unit
  validation steps cover the individual behaviours; this covers getting to a state where they can be
  run at all.
- **Open questions for the author** — distinct from the checkpoint, and phrased as questions rather
  than accusations. The checkpoint asks what the *reviewer* should understand; this asks what only the
  *author* can answer. That is what turns the page into a conversation rather than a verdict.

## Part 12 · Coverage ledger — always

Every changed file, the part covering it, its attention level (read / skim / mechanical), which group
it belongs to (primary / supporting / secondary) and a deep link. Machine-generated from the diff, per
the gate in `SKILL.md` step 10. Doubles as a checklist for a reviewer working through the entire diff.

**Each row carries its path in a `data-path` attribute** on the path cell, as the template does:
`<td data-path="app/models/project.rb">`. That attribute is the whole interface to
`scripts/coverage-gate.sh` — it is what lets the check compare sets exactly instead of searching the
rendered page, where `api/Gemfile` matches inside `api/Gemfile.lock`. Omit it and the gate fails
loudly, which is the intended behaviour: a check that cannot run must not report a pass.

---

## Deep links

Every `file:line` should be clickable, so a reader goes from claim to source in one click.

**Primary form — blob permalink at the head SHA:**

```
https://github.com/{owner}/{repo}/blob/{head_sha}/{path}#L{line}
https://github.com/{owner}/{repo}/blob/{head_sha}/{path}#L{start}-L{end}
```

Pin the SHA rather than the branch, so links stay correct after later pushes.

This is the primary form, not the diff anchor, for a reason: **many of the most valuable citations in
this page point at lines that are not in the diff at all** — the *affected but unchanged* field
consists of nothing else. A diff anchor cannot address an unchanged line. Blob permalinks mean every
citation links, not only the ones that happen to fall inside a hunk.

**Secondary form — the Files-tab anchor**, for lines genuinely inside the diff:

```
https://github.com/{owner}/{repo}/pull/{n}/files#diff-{sha256(path)}R{line}
```

The hash is the SHA-256 of the file path as it appears in the diff; `R` and `L` select the right and
left side. Worth using in the coverage ledger and wherever landing in review context beats landing in
the file.

### Choosing a mode — check reachability first

**A permalink to a commit that was never pushed 404s.** Local branches, worktrees, and
work-in-progress are exactly the cases this skill runs on most, so this is the common path, not an
edge case. Before choosing a link mode, confirm the head SHA actually exists on the remote:

```sh
git branch -r --contains <HEAD_SHA>     # empty output ⇒ the commit is on no remote
```

**Degradation, in order:**

| # | Condition | Citations render as |
|---|---|---|
| 1 | GitHub PR exists | Diff anchors in the ledger, blob permalinks elsewhere |
| 2 | No PR, GitHub remote, **head SHA reachable on a remote** | Blob permalinks at the head SHA |
| 3 | GitHub remote, **head SHA not pushed** | Plain text, plus the note below |
| 4 | No GitHub remote, or no remote at all | Plain text |

Resolve remote, PR, and reachability once up front and pick one mode; never decide per citation.

At rung 3, say so once in the masthead rather than leaving the reader wondering why nothing is
clickable — one line is enough: *"Citations are plain text: this branch is not pushed, so there is no
permalink target."* Do not emit hrefs you know are dead, and do not silently fall back to linking
against the default branch, where the cited line numbers will not match.

A force-push after publishing can also orphan a rung-1 or rung-2 SHA. GitHub keeps orphaned commits
reachable by SHA for a while, so this degrades slowly rather than breaking at once — but it is a
reason to prefer republishing the page over treating an old URL as permanent.
