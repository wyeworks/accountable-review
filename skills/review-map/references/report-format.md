# The report format

What sections exist, when each appears, how deep it goes, and the primitives the page is built from —
the review unit, the evidence tier, the source excerpt, and the rule that each fact has one home.

Seven sections at `--full`, four at the default `--brief` — see § *Detail levels* — and the order
below is the default review path rather than a mould. Derive the actual
order from the PR's own goals: if the change is a client-side refactor with one new field behind it,
the boundary leads and persistence is a sentence. A section the diff does not earn is **omitted**,
never filled with generic content and never left as an "N/A" placeholder.

**The page is short because of how it is organised, not because anything was cut.** Every section
below is a place where a distinct kind of thing lives exactly once. If you find yourself explaining
something a second time, the structure is telling you the explanation is in the wrong section — move
it, do not duplicate it.

---

## Detail levels

How much page the run produces. Settled once, in step 1 of the procedure, from the flag on the
invocation; there is no per-section renegotiation of it.

| Level | Flag | Shape |
|---|---|---|
| **brief** | `--brief`, or no flag | §§ 1–3 as written below, written to the word budget in § *The brief budget*. §§ 4–7 collapse into **one** section, § *Section 4 at brief* |
| **full** | `--full` | The seven sections below, exactly as written |
| **review** | `--review` | Full, plus a code-review pass threaded through it. **Not implemented** — the skill stops and says so |

**The level changes how many sections there are and how many words they may spend; it never
changes what a section teaches.** That distinction is the whole of it, and it is finer than the one
this file used to draw. §§ 1–3 exist at both levels with the same depth rules, the same excerpt
budget, the same review unit and the same rules about what a flow owns — and at `--brief` they are
written **shorter**, to the caps in § *The brief budget*. Saying a claim in fewer words is not
teaching less. Dropping the claim is, and the level never does that: no finding, no citation, no
evidence tier, no field the flow has material for, and **no figure** comes out for the level's sake.
What `--brief` also does is decline to spend four section shells on material that is often one
screen — it merges, it drops the ranking, and it drops the comprehension checkpoint. It does not
summarise § 2.

**An earlier version of this paragraph said §§ 1–3 were byte-for-byte the same spec at both levels,
and the price of that was a default page nobody had costed.** `--brief` bought 35% fewer words than
`--full` by merging four sections, which left the bulk — § 2 — running at full length on the page
almost every reader gets. The budget is what closed that, and it closed it on prose rather than on
material, because the alternative reading of "shorter" is the one that loses findings.

So the three things that scale a page are **orthogonal**, and confusing them is the way to get this
wrong: § *Depth rules* scales each section by what the diff puts into it, at either level; the level
decides how many sections there are to scale; and § *The brief budget* caps what the scaling may
spend at the default level.

**One thing is level-independent, deliberately:** every path in the diff still appears in the page,
and the coverage gate still runs. § *The completeness invariant* says why, and what changes is only
**where** the paths sit — § 7's classified ledger at `--full`, a shut `details.coverage-foot` below
the last section at `--brief`. Neither is § 4: the inventory left that section at both levels,
because § 4 is about consequences and a list of every changed path is not one.

**Effort is not a level, and this file has nothing else to say about it.** `--effort high` (the
default) and `--effort low` decide how hard the run works to be right — at `high`, `SKILL.md`
step 8 sends an adversarial pass at the behaviour flows before the page is finished. That produces no section, no
marker, no chip and no sentence: the page is the same *shape*, built to the same specs, at either
effort, and a reader cannot tell which produced the page in front of them. Deliberately so. A page
that announced having been checked would be asserting the assurance the format refuses to give —
§ *Evidence tiers* labels how a claim is known, never how hard someone looked, and *findings are a
sample, not an audit* is the rule that would break first.

**The stack is not a level either, and it is invisible for the same reason.** Rails and Phoenix change
which lens file and which catalogue the run reads (`SKILL.md` step 2), what a `.pipe` chain's nodes are
called, and what a probe's command looks like. They change **no section, no field, no tier, no
component and no marker.** There is no stack chip and no "reviewed as a Phoenix app" line: two pages of
equivalent changes in the two stacks differ in their content and not in their shape. What the stack is
belongs in the sentences that cite this repository, which say it by naming real files.

---

## The brief budget

`--brief` is the default, so this is what almost every real page costs. § *Detail levels* says how
many sections it has. This says how much prose, and it is the one number in this file that is a
budget rather than a depth rule — § *Depth rules* scales a section by what the diff puts into it,
and this caps how many words that scaling may spend.

**The target is about half the prose the same diff would get written to §§ 1–7's uncapped specs,
with nothing removed that a reviewer acts on.** Halving a page by dropping a finding is trivial and
worthless, and it is the failure this section is most likely to cause. What comes out is explanation
the reader did not need twice, ceremony the components already carry, and three concepts that belong
to `--full`. What stays is every finding, every citation, every evidence tier, **every figure**, and
the completeness gate.

### The ceiling

Counted in **visible words**: what a reader reads with the page as it arrives. The exemptions below
are most of the reason that is a fair measure.

| Part | Budget | Made of |
|---|---|---|
| § 1 | 260 | Masthead and metric strip ~55, intent ≤ 65, the `dl.ba` pair ~50, five use cases at ~15 |
| § 3 | 300 | Six entries at ~35, plus the grouping sentence and the sampling caveat at ~45 each. Eight entries is the cap's own upper end and spends the whole 300 |
| Merged tail | 400 | The panel's prose ~40, the affected list at ~30 an entry, cross-cutting rows at ~25, approving items at ~18 |
| Each behaviour flow | 440 | `.mech` ≤ 45, seven fields at ~35 with *understand* at ~60, the endpoint rows ~50, one or two decisions at ~45 |

**Ceiling: 950 words, plus 440 per behaviour flow.** Three flows is 2,270; six is 3,590. Past it
`evals/checks/brief-budget.rb` warns, and the warning names the part that overspent.

**The caps do the cutting; the ceiling is the backstop.** That order matters when reading this
section, because the ceiling is the number that gets quoted and the caps are what actually halve a
page: a field written at 70 words and capped at 35 is the whole 50%, repeated seven times a flow,
and the ceiling only catches what has no cap on it — § 1's intent, the endpoint rows, the notes and
the approving items, each of which can grow without any single cap firing while the page as a whole
stops being readable in twenty minutes. A page inside every cap is normally well inside the ceiling.

**Those numbers are a first calibration and they are stated so they can be argued with.** They were
derived from the component budgets above rather than measured on a corpus of published pages, because
the corpus did not exist when the budget was written — the honest way to move them is
`bin/evals page` over a fixture, three runs, and a number that came out of a page. Expect the ceiling
to be the loose one: a well-written single-flow page lands far enough under it that the caps are what
the run is really working against.

### Six files have to agree

This section owns the budget **alone**, and everything else points at it. `SKILL.md` step 1 reads it
with the level, step 7 writes the fields to their caps, step 9 says to draft to the budget rather than
edit down to it, and § *How big should the page be?* says it is still not the answer to a diff that
will not fit. `page-template.html` marks the two components it drops as `--full` only, in place, where
a run copying an assembled flow is looking. `evals/checks/brief-budget.rb` carries the numbers, the
exemptions, the split verdicts and the floor, with `golden/brief-*.html` and the `self-test.rb` rows
proving each rule fires. `evals/cases/brief-flows.json` and page case 7 in `evals/evals.json` ask the
half no script can. And `docs/review-map.md` and `README.md` are the public restatement, which own
nothing — where they disagree with this section, they are the ones that are wrong.

### What the ceiling does not count

A budget that counted these would be a budget against the page's own evidence, and it would be
satisfied fastest by deleting the best content on it.

- **Everything inside an `<svg>`, its `figcaption`, and its `.legend`.** A figure is not prose and
  is not shortened here. Every drawing keeps the spec, the geometry, the caps and the labels
  § *Depth rules* gives it, at both levels: `--brief` removes no figure, trims no figure, and
  a flow's boundary chain or guard fork is drawn exactly as it is at `--full`. The one figure rule
  the level has ever carried is that § 5's two kinds do not appear, which is a consequence of § 5
  not existing and not a cut.
- **The `.pipe` spine's node labels and the `.impact` panel's box text.** Labels, capped already by
  § *Impact paths* and § *Depth rules*, and both components are figures by the criterion in
  § *Depth rules* even though neither is a drawing.
- **Anything inside `<code>` or `<pre>`.** A command and a quotation are bytes. Shortening a
  validation step is inventing one.
- **Anything inside a collapsed `<details>`** — a source excerpt, and the `details.searched`
  record. Neither is reading length: both are shut when the page arrives, and counting them would
  charge the page for the two components that exist to carry provenance. The rule that makes this
  safe is already in `SKILL.md`: the page reads complete with every collapsed block closed, so
  nothing the budget stops counting is anything a reader needs.

### The per-component caps

Warnings, not failures, and the direction of that choice is deliberate: a hard failure on length
teaches a run to drop a claim, which is the one outcome worse than a long page. Shape is a FAIL
below; verbosity is a WARN.

| Component | Cap | Note |
|---|---|---|
| `.mech` | 45 words | The mechanism, not its history. Two sentences reaches this comfortably |
| A field `<dd>` | 35 words | Per § *The review unit*'s seven, and the claim plus its clause fits |
| *Understand* `<dd>` | 60 words | The highest-value field on the page gets the largest field budget |
| A `.decision` | 45 words | The decision, where it lives, the tradeoff. The narrative around it is what goes |
| An `ol.begin` entry | 40 words | Where to go, and why here |
| § 1's intent | 65 words | What was possible, what is now, what is prevented |
| A cross-cutting row | 30 words | It is a row at this level, per § *Section 4 at brief* |

### The floor, which is the half that matters

**No field may be compressed into its own label.** A `<dd>` carrying fewer than four visible words
is not a terse field, it is a deleted one with the `<dt>` left behind — and it reads, in the 132px
gutter, exactly like a field that was filled in. `brief-budget.rb` **fails** on one, and that is the
rule the rest of this section is measured against: every cap above is a cap on how a claim is
written, never on whether it is there.

The rules that already say this from other directions all still hold at `--brief`, unchanged and
uncapped: a unit needs a non-obvious *things to understand*; fields may be omitted but never faked;
every flow shows the hunk its behaviour turns on; a search that found nothing is recorded as a
search; the sampling caveat is carried once.

### The three concepts `--brief` drops

Each is a whole component or field that comes out, rather than prose that gets shorter, and each
loses no finding — which is the test a fourth candidate has to pass before it joins them.

- **The framework primer.** `aside.primer` is the heaviest component on the page carrying no
  evidence of its own, and § *The primer callout* already caps it at one per flow with most flows
  earning none. At `--brief` it earns none: the flow explains the mechanism in its own prose against
  its `file:line` and keeps the pinned `a.doc` link, which is what the primer escalates *from*. The
  link survives, the lesson does not. **This shape is already proven rather than invented** — it is
  exactly where a Phoenix page stands today while `elixir-docs.md` § *Version* withholds every link,
  and it needs no exemption in `evals/checks/rails-anchors.rb` for the same reason: a page that emits
  no primer has no primer to fail.
- **The flow's own `dl.ba` pair.** § 1 carries the change's before and after, as two rows, and at
  `--brief` that is the page's one transition block. A flow states its own transition inside the
  `.mech`, where the mechanism it belongs to already is. On a single-flow PR the two were the same
  pair twice.
- **The endpoint's full error list.** What the diff **adds, moves or removes** — with statuses —
  plus a count of the ones it leaves alone. The params, the success body and the side-effects row
  are unchanged: the side-effects row is the reviewer's actual question and no diff answers it. The
  inventory of untouched error cases is the part a reviewer can read off the code, and this is the
  same trade § *Section 4 at brief* makes with the ledger — the level declines to *inventory*, never
  to account.

**§ 3's entries lose a sub-part rather than a concept**, so it is not a fourth: *what remains
uncertain* folds into the *why* clause with its evidence tier intact, rather than standing as its own
line. The tier is the load-bearing half and it survives.

**What is emphatically not on this list**, because each would look like thrift and cost the page its
product: any figure; the `--diff` excerpt floor; `details.searched`; the coverage foot or its gate;
any of the seven fields the flow has material for; the evidence tiers; the sampling caveat. And
nothing here licenses a thinner § 2 — see § *Detail levels* on what the level may and may not do to
a flow.

---

## Contents

**Primitives and rules** — read these before writing anything.

- *Detail levels* — brief, full and review, and what the level does and does not change
- *The review unit* — the seven fields every meaningful change gets
- *Evidence tiers* — five tiers, and the rule that only four of them get a label
- *Framework anchors* — the doc link, the runtime probe, the primer callout a link escalates
  into, and why none of the three is evidence
- *Source excerpts* — the collapsed code quotation, which is also the page's shortest way to say
  what code does, and the syntax tint that unchanged code gets and a hunk does not
- *Impact paths* — the § 4 figure: directed chains from changed code, through the unchanged code
  that gives the change its consequence, to an observable behaviour
- *One canonical home* — every fact explained once, referenced from everywhere else
- *Depth rules* — how much treatment a section earns, and the diagram budget
- *The completeness invariant* — why every diff path appears, and why the check is one-directional
- *The brief budget* — how much prose the default level may spend, what it never counts, and the
  three concepts it drops
- *Build state* — the banner and pending markers that keep a staged page honest while it fills in

**The seven sections, in default order** — each with what triggers it, and what becomes of it at
`--brief`.

| | Section | Appears | At `--brief` | Owns |
|---|---|---|---|---|
| 1 | What changed | always | unchanged | Intent, scope, the metric strip, the use cases named |
| 2 | Behaviour flows | the bulk | unchanged | One flow per behaviour, canonically — the mechanism, and the findings inside it |
| 3 | Start here | always | unchanged | One prioritized list: where to go in the code, in the order to go there |
| 4 | What this change reaches | always | **the merged section** | Where consequences leave the diff, seen across every flow at once |
| 5 | Cross-cutting consequences | anything genuinely spans flows | folded in, consequential rows only | Schema structure, authorization, jobs, deploy order, test infrastructure |
| 6 | Before approving | always | folded in, questions and validations | Author questions, validations, test gaps, a ≤5-question checkpoint |
| 7 | Coverage | always | moves to the page foot, unclassified | The ledger. No findings |

The order is the reviewer's path, and each section assumes the ones before it. § 2 teaches the
mechanisms; § 3 is the moment the reviewer opens the code, holding §§ 1–2; § 4 is a second pass over
the same change through one lens, so it can point at a flow instead of re-explaining it.

*Section 4 at brief* follows § 7, since it is built out of all four of §§ 4–7 and only reads once they
have been read.

*Where the old per-layer material goes* maps the previous twelve-part format onto these, since
persistence, API surface and contract no longer have sections of their own — they are covered inside
the behaviour they serve.

**Citations** — *Deep links*, the two URL forms and which lines each one can address, and *Choosing a
mode*, the four-rung degradation ladder. Settle the rung once, in step 1 of the procedure; the form
then follows the line, not the run's taste. A documentation link is not one of those forms and the
ladder does not reach it: see *Framework anchors*, and take the URL from the catalogue the stack
selected — `references/rails-docs.md` or `references/elixir-docs.md`.

---

## The review unit

The page's reusable primitive. Every meaningful change — usually one per behaviour flow, sometimes
one per significant standalone change — renders as a unit with these seven fields, in this order:

| Field | `<dt>` | Carries |
|---|---|---|
| **Why this exists** | — | One or two sentences of purpose, in behavioural terms |
| **Implementation** | `Implementation` | The `file:line` citations that make up the change, in reading order |
| **Relevant tests** | `Tests` | The specs that pin this behaviour, cited the same way, plus what they leave open |
| **Affected but unchanged** | `Affected, unchanged` | Code the change gives new meaning to, with a citation and a clause on why it is affected |
| **Things to understand** | `Understand` | The invariants, defaults and decisions a reader would not have guessed from the diff |
| **How to validate** | `Validate` | Numbered, pasteable steps against this repository |
| **Reviewer questions** | `Questions` | Open questions, phrased as questions |

The middle column is the label text, **verbatim**, and it is deliberately shorter than the field
name: the label column is 132px wide, and a label that wraps to two lines turns the gutter into
noise. It is a column rather than an inference because the two drifted the moment the mapping was
only implied — this file said *relevant tests* and *things to understand* while the template emitted
`Tests` and `Understand`, and a run reading both wrote `Understand` in one flow and `Things to
understand` in the next, leaving the reader to work out whether they were the same field. *Why this
exists* has no label at all: it renders as the `.mech` block, above the field rows.

Rules that keep units from becoming ceremony:

- **A unit needs a non-obvious *things to understand*.** If the field can only be filled with
  restatements of the diff, this change is not a unit — it is a ledger row.
- **Fields may be omitted, but never faked.** No *affected but unchanged* code found, after a search
  worth reporting? Say that nothing consumes it, in the open prose — that sentence is the finding.
  The grep behind it goes in the collapsed record, which is provenance and never the finding itself.
- **Validation steps must exist in this repo.** The real rake or mix task, the real route, the real
  factory or fixture, the real scope or context function inside a console probe. One invented command
  spends the reader's trust in the entire page. For a change to persistence, the runtime probes in the
  lens file the stack selected — `references/rails-nextjs.md` or `references/phoenix-liveview.md` —
  are usually the most precise step available; § *Framework anchors* says which field one lands in.
- **Render as a `.mech` block followed by one `dl.rows`, and render the fields nowhere else.**
  The seven fields are `<dt>`/`<dd>` pairs inside that single `dl`; loose in a section they lose the
  row hairlines, the 132px label gutter and every `.rows`-scoped rule. `.decisions` goes *after* the
  closing `</dl>`, never inside it.
  Take the composition from the assembled behaviour flow in `page-template.html` rather than from
  this sentence — a run that had only the sentence flattened all three of its flows.
  **This shape is more fragile than the card it replaced, not less.** The unit used to be a bordered
  `article.unit`, so a flattened flow visibly lost its box. A `.mech` plus a hairline grid is
  borderless by design, so a flow that spills its rows straight into the `<section>` looks very
  nearly correct. `evals/checks/behaviour-flows.rb` therefore checks the *pairing* — one `.mech` per
  `dl.rows` — and counts field labels inside grids rather than inside units, because a flattened flow
  keeps its `.mech` and a census taken over units counts loose fields as housed.
- Three of the fields may carry a collapsed source excerpt: *implementation*, *affected but unchanged*
  and *things to understand*. See § *Source excerpts* for the budget and for the rule that the field
  still has to read complete with the excerpt closed.
- **At `--brief` the fields are capped, not culled.** 35 words a `<dd>`, 60 for *understand*, 45 for
  the `.mech` — § *The brief budget* owns the numbers. The seven fields, their order, their labels and
  the two rules above are the same at both levels, and a `<dd>` compressed below four words is a
  deleted field wearing its own label, which that section fails rather than warns on.

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

## Framework anchors

Three ways to anchor a claim that rests on the framework behaving as the framework rather than on
anything this diff contains. None is an evidence tier, and none changes one.

| Anchor | Is | Renders as |
|---|---|---|
| **Documentation link** | Provenance: where the framework's rule is written down | `<a class="doc" href="…">` around the concept, from the catalogue |
| **Runtime probe** | A question to the reviewer's own application, which they run | `<pre class="probe">`, one command |
| **Primer callout** | What a link escalates into when the reviewer has to *understand* the rule to decide | `<aside class="primer">`, inside the flow it explains |

**A doc link is provenance, not evidence.** "`update_all` skips callbacks" is a property of Rails,
and "`insert_all` never builds a struct, so nothing it writes is cast" is a property of Ecto; the
claim the page is making is that *this call site* now bypasses the validation this PR adds, and that
claim rests on the citation to the call site, at whatever tier it already carried — usually
`from unchanged code`. The link explains why the consequence follows. So:

- **Never a doc link on a claim with no `file:line`**, and never one instead of a `file:line`. A link
  to the Rails guides or to hexdocs says nothing about this repository, and a claim anchored only
  there is an unevidenced claim wearing a citation.
- **Never inside a collapsed excerpt.** The page reads complete with every excerpt closed, and a link
  the reader has to open a block to find is not part of the page they read.
- **Never a verdict by reference.** "See the security guide" is not a finding. If the change has a
  security consequence, state it, cite the line, and let the link explain the mechanism.

**Cite only from the catalogue the stack selected** — `references/rails-docs.md` for Rails,
`references/elixir-docs.md` for Elixir, and never the other one. That file is the allowlist, and the
reason is that the run cannot check a URL: there is no fetch step, and egress to those hosts is
commonly blocked. A concept the catalogue does not carry gets explained in prose with a repo citation,
which is the ordinary case and not a degraded one. Constructing a plausible URL is the failure this
rule exists to prevent: it looks like diligence and it lands the reader on a 404.

**A catalogue can be closed as a whole, and then it yields nothing.** `elixir-docs.md` § *Version*
currently withholds every link in it until a verification run has opened its rows, so an Elixir run
anchors with probes and prose and emits no doc link at all. That is the same fail-closed rule applied
at file scope rather than at row scope, and the page is shorter rather than wrong. Read the
catalogue's § *Version* before reaching for a link from it.

**Every doc link is pinned to the version this app runs.** Both catalogues store paths without a
version segment; the run inserts one from the versions recorded in step 2. The mechanics, the
placeholder forms, the overrides and what to do above the verified ceiling are each catalogue's
§ *Pinning*, **and live there only** — what belongs here is why the page cares: a pinned Rails doc page
states its own version in its header, and a pinned hexdocs page states its own in its version picker,
so the reader can check the link against their own lock file. An unpinned link silently means *current
stable* and offers nothing to check, which is how a page ends up explaining 8.1 behaviour to a 7.1 app
in a tone of complete confidence.

**What gets pinned differs by stack, and one page-level rule differs with it.** Rails has a single
series for the whole framework, so a page mixing `/v7.1/` and `/v8.0/` has pinned from something other
than this repo's lock file — one app, one series. An Elixir app pins **each package independently**
from `mix.lock`, and hexdocs serves exact versions rather than a series prefix, so **a correct Elixir
page carries several different version segments** and that is not a defect.
`evals/checks/rails-anchors.rb` encodes both: every doc link must carry a version segment in either
stack, and only the Rails links must agree on one series.

**A row with no verified path for this app's version yields no link.** Not a nearest-neighbour link,
not the unpinned one. Explain the mechanism in prose and cite the repo line; the page reads complete
without it, exactly as it does with every excerpt closed. Failing closed is the whole guarantee: an
unlinked explanation is never misleading, and a link to the wrong version is.

**Two marks in the catalogue constrain the sentence, not the link.** In `rails-docs.md` they are the
outcome of an audit of the Rails CHANGELOGs across the supported series; in `elixir-docs.md` they are
a first pass that no such audit has yet confirmed, which that file says of itself. Each catalogue's
§ *What the marks mean* owns their definitions:

- `‡ probe` — the behaviour changed inside the supported range, so **no sentence about it is true of
  every app**. The page may not assert it. Route to a probe and name the setting that decides it:
  *"whether this enqueue waits for the commit is decided by `enqueue_after_transaction_commit`, which
  this app sets at `config/application.rb:41`"* — never *"`perform_later` enqueues immediately"*. This
  is the one place a probe is not rationed by the budget below: the alternative is not a shorter page,
  it is a wrong one.
- `‡ since X` — surface was added in X and the default this row describes still holds. State it **as
  the default** and name X. A probe here would be over-citation, which is the failure mode the budget
  exists to prevent.

**A probe is a question, never an answer.** The skill does not boot the application under review, so
the page shows a command and never its output. No `=>` line, no `{:ok, %Project{}}`, no SQL presented
as what the query printed, no invented row count. The § *Runtime probes* section of whichever lens file
step 2 selected has the probes and the rule for running them safely — in Rails, `runner` versus
`console --sandbox` and why a sandbox session cannot see `after_commit`; in Elixir, `mix run -e` versus
`iex -S mix`, and that there is **no sandbox console at all**, so a write is wrapped in
`Repo.transaction(fn -> …; Repo.rollback(:probe) end)` or it is not proposed. Every constant, scope,
context and module a probe names must exist in this repository — the same rule as *validation steps
must exist in this repo*, and it fails the same way when broken.

### The primer callout

A doc link says *where the rule is written down*. A primer is for the narrower case where the
reviewer cannot make the decision in front of them **without** the rule — where the framework
behaviour is not an aside to the finding, it is the finding's mechanism. It renders as an
`aside.primer`, assembled in `page-template.html`: a header naming the API, one or two paragraphs,
the citation that earned it, the pinned link, and a short `pre.demo` beside them.

**It sits between the flow's `.mech` and its `dl.rows`.** The reader meets the unfamiliar API
immediately after the mechanism that uses it and before the fields that cite it. It is not a field, it
carries no `<dt>`, and it never appears outside a behaviour flow: a primer in § 4 or § 6 is a lesson
with no behaviour attached to it.

**At most one per behaviour flow, and most flows earn none.** An inline `a.doc` is what a citation
normally looks like; the primer is the exception, taken when a decision turns on the mechanism. A flow
that wants two is a flow explaining Rails rather than explaining its own change — and the page that
results reads as more thorough while getting less navigable, which is the failure mode this budget
exists for. The escalation test is the same one the excerpt budget uses: not *is this interesting*, but
*would the reviewer decide differently not knowing it*.

**It is `--full` only, and that is the second of two gates rather than a new kind of rule.** At
`--brief` no flow earns one: the callout is the heaviest component on the page carrying no evidence
of its own, and § *The brief budget* spends that weight elsewhere. The flow keeps the pinned `a.doc`
link the primer would have escalated from, and explains the mechanism in its own prose against its
`file:line`. Like the gate below it, this needs no exemption in `evals/checks/rails-anchors.rb` —
a page that emits no primer has no primer to fail — which is why `rails-anchors.rb` still must not
read `LEVEL`.

**A primer is gated on its doc link, so a closed catalogue means no primers for that stack.** It is
what a link escalates *into*, and `evals/checks/rails-anchors.rb` fails one that carries none — so the
two rules meeting leave no room: while `elixir-docs.md` § *Version* withholds every link, a Phoenix
page carries no primer at all. Explain the mechanism in the flow's own prose against its `file:line`
and propose a probe, which is the anchor that stack has. Narrower, not wrong — the same trade the
withhold already makes, arriving at the heaviest component rather than the lightest.

When that catalogue opens, **Elixir takes `.primer--lib`**, never the branded variant. Ecto, Phoenix
and LiveView are libraries in exactly the sense the variant was built for: the mark on a primer says
who wrote the thing it explains, and the Rails Foundation did not write Ecto.

**It carries a `file:line` from this repository, like every other doc link.** Two paragraphs of
framework prose read as self-justifying, which is exactly why the rule is easiest to lose here. The
citation names the line the callout was earned by, and `evals/checks/rails-anchors.rb` judges the
whole aside as one block so it can neither omit its own citation nor borrow the one above it.

**`pre.demo` is not `pre.probe`, and the difference is the receiver.** A demo quotes documented
framework behaviour on a class **this repository does not have**, so it may show a `# =>` line: it is
a quotation of the manual, and the manual states results. A probe asks *this* application and may
never show one, because the run did not boot it. Name an application class in a demo and the block
becomes precisely the fiction the probe rule exists to prevent, with the rule switched off — so a
demo lives only inside a primer, and nowhere else on the page.

**A `‡ probe` row may not be a primer's subject.** Those behaviours changed inside the supported
Rails range, so no paragraph about them is true of every app, and a primer's whole form is
explanatory prose. Route those to a probe and name the setting that decides it, per
`rails-docs.md` § *What the marks mean*.

**It is not Rails-only.** The catalogue carries gems and client libraries too, and the same callout
serves them as `aside.primer.primer--lib`: no mark, no trademark line, and a neutral rule instead of
the red one. Three things differ and nothing else does — the demo rule, the citation rule and the
budget all apply unchanged. Reach for the variant whenever the link is not a `rubyonrails.org` one,
because the artwork is an **attribution**: the Rails logotype on a Pundit explanation says the Rails
Foundation wrote Pundit, and it looks entirely correct on the page. The mark also never appears
without `.pr-tm` beneath it, which is the notice saying whose mark it is;
`evals/checks/rails-anchors.rb` enforces both halves.

**Nothing about the primer changes with the detail level.** It lives inside a behaviour flow, and
§§ 1–3 are the same spec at `--brief` and `--full`.

**Routing.** One anchor per claim, never two:

| The claim needs | Goes in | Because |
|---|---|---|
| Running something to be believed | *How to validate*, or § 6 *Validations worth running* if it needs setup | It is an action the reviewer takes |
| A mechanism made legible | *Things to understand* | It deepens what the page established |
| The framework's general rule | The sentence that states the consequence | The link is an aside, not a step |

Prefer the probe where this application's own configuration decides the answer — a real
`dependent:`, a real scope's SQL, the indexes that actually exist. Prefer the doc link where the
framework's rule is the whole point and this app cannot vary it.

**Earned by a decision the reviewer has to make.** The same test the excerpt budget uses, and for the
same reason: a behaviour every developer in that stack already knows earns nothing, and a page that
links each one has become a tutorial with a diff attached. **At most one doc link per field**, and a
section where most fields carry one has stopped selecting. Probes are scarcer still: a flow earns one
where its change is framework-shaped — ActiveRecord in Rails, a changeset, a query, an association or
an `on_mount` chain in Elixir — and a second wants a reason. Primers are the scarcest of the three —
one per flow is the ceiling and none is the common case.

**The deep-link ladder governs none of the three.** The four rungs are about `file:line` citations
into a git remote, so a doc link stays clickable at rung 3 and rung 4 where every repo citation is
plain text — exactly as an in-page `href="#flow-b"` does. A probe has no href at all, and a primer's
own citation follows the rung like any other.

## Source excerpts

The page's third primitive. A verbatim quotation of code, collapsed until the reader decides to check
the claim it supports.

It exists because of two things a deep link cannot fix.

The first is an asymmetry. A citation to an *unchanged* line sends the reader into an unfamiliar file
with no context, and the ones who do not go take the finding **on faith**. Faith is what this page is
built to remove, so the lines come to the reader instead.

The second is this page's own ordering. § 2 comes *before* § 3, and § 3 is the moment the reviewer
opens the code — so while they are reading the flows they do not have the diff in front of them. An
earlier version of this section assumed they did — *"a citation to a changed line is cheap to follow,
the reviewer has the diff open anyway"* — and rationed `--diff` excerpts on that basis. What it
produced was flows whose only quoted code was code the PR never touched. A flow teaches a mechanism,
and the shortest way to teach a mechanism is to show the lines that make it, so changed lines belong
in the flows too.

Two variants:

| Variant | Shows | Used for |
|---|---|---|
| `.excerpt--source` | Lines as they stand at one rev, no signs | Unchanged code, which has no diff to show. The variant that carries the product — and committed code a hunk cannot show whole. Its state tag says which |
| `.excerpt--diff` | A hunk with `+`/`−` gutters | Changed code, where *what moved* is the reviewer's question. The variant that lets a flow be read with no diff open |

**Where they may appear.** Not in the coverage ledger — a ledger row is a checklist entry, not a
claim, and a hundred collapsed hunks is a page nobody can load. Everywhere else on this list, subject
to the test below.

| Location | Variant |
|---|---|
| § 2 · a flow's *affected but unchanged* | `--source` |
| § 2 · a flow's *implementation* | `--diff`, the hunk the behaviour turns on. Expected on every flow with changed code — a floor, not a ration |
| § 2 · a flow's *things to understand* | Either, whichever fits the claim |
| § 3 · *start here*, an entry whose finding is not already excerpted in its flow | Either |
| § 4 · *changed vs affected-not-changed*, the affected list | `--source` |
| § 5 · the application-vs-database invariants block | `--source` |

The last two were added after a run showed the original list barred excerpts from the two densest
concentrations of unchanged-code claims a server-rendered Rails PR or a LiveView PR produces. § 5 is
the sharper case: *"no unique index on `projects.slug`, `db/schema.rb:141`"* is one line inside a
generated file
twelve hundred lines long, and no reviewer opens that file to check it. The general rule
against excerpting `db/schema.rb` is about **churn** — do not quote a migration's regenerated diff. It
was never about quoting one committed line that a claim turns on.

### The rules

- **The page must read completely with every excerpt closed.** No claim, no evidence tier and no
  citation may live only inside one. An excerpt *confirms* what the prose already said; it never
  *carries* it. This is the whole difference between progressive disclosure and hidden content, and it
  is the rule to check first when reviewing a page that uses them.
- **Every flow shows the change itself.** A behaviour flow whose only excerpts are `--source` has
  explained everything except the change. The *implementation* field carries the hunk the behaviour
  turns on — the guard, the new branch, the changed default — as a `--diff` excerpt. If a flow's
  implementation is one import or one rename, it was a ledger row and not a flow. This is a floor;
  the budget below rations what sits on top of it, never the hunk itself.
- **The closed summary says what the reader will see and why to open it** — `path:lines`, a state
  tag, then the clause, all inside the `<summary>`. `View diff`
  and `Show code` are not summaries: a closed excerpt has to be informative, because most of them
  stay closed. The clause lives in the summary rather than at the top of the body **because of the
  closed-page rule above** — a why the reader has to open the block to see is exactly the hidden
  content the rule forbids. `excerpt.sh` emits it there; do not move it.
- **Verbatim, generated, never typed.** Run `scripts/excerpt.sh`. A mistyped ledger row fails the
  coverage gate loudly; a paraphrased quotation is a *false* quotation and the reader has no way to
  catch it. This is the strongest version of the argument that produced `ledger-rows.sh`.
- **The state tag is read off the diff, never chosen.** `excerpt.sh --at` needs `--base` and
  computes it: `Unchanged` when the path is outside the diff, and `Added`, `Removed`, `At head` or
  `Before the change` when it is inside. A `--diff` hunk is `Changed`. That is the whole vocabulary,
  and it is closed because it is computed. The script used to hard-code `Unchanged` on every
  `--source` block, and a run published `db/structure.sql:304-313` tagged Unchanged on a page whose
  own ledger listed that file as changed: verbatim bytes under a false label, which is the one defect
  in this component a reader has no way to catch — the excerpt looks *more* trustworthy the closer
  they read it. Two things follow.

  **Quoting a changed file at one rev is legitimate**, and sometimes the only way to show what the
  committed code now permits: a hunk of an 18,000-line `structure.sql` cannot show that a table has
  **no** `CHECK` constraint, and § 5's invariants block is built on exactly that reading. It was the
  label that was wrong, never the excerpt — so the fix is the tag, not a rule against the quotation.

  **And a path the diff touches is never tagged `Unchanged`, even where the quoted lines are
  untouched**, because §§ 4 and 7 split changed from affected-not-changed **by file**. Two senses of
  one word on one page, and nothing tells the reader which is meant. Where the range is the point,
  the prose says it — *"the pre-existing unique index at `:18682`, which this change does not
  touch"* — which is where it can be said precisely anyway. `evals/checks/excerpts.rb` holds both
  halves: every `Unchanged` tag against the changed set (from a repo when it has one, otherwise from
  the page's own ledger, which the completeness invariant guarantees is the whole diff), and every
  tag against the vocabulary, for the inputs where there is nothing to compare against.
- **An excerpt is evidence for one claim, not coverage of a file.** Never a whole file, never every
  hunk. Completeness belongs to the ledger.
- **The field carries its own citation, not one from elsewhere on the page.** The closed-page rule is
  easy to satisfy globally and still fail locally: a run wrote *"an unchanged trait in
  `spec/factories/projects.rb` stamps `archived_at`"* with the path as bare prose, the only `file:line`
  for it being the excerpt's own footer. The same citation did appear linked in § 4 and in § 3's
  reading order, so the page as a whole was fine — but a reader working through that field with the
  block shut had nothing to click. Judge the rule field by field, not page-wide. `check.rb` cannot
  catch this: it checks summaries and collapse state, never whether a citation survives the block
  closing.
- **The excerpt does not replace the link.** It deliberately omits the surrounding context, so the
  citation stays in the body for a reader who needs more than the quoted lines.
- **Next to a `--diff` excerpt, say which range you mean.** The script labels the block with the
  hunk's new-side span, which is rarely the range the prose wants to cite — the method, or the one
  changed line. All three are correct and on screen together they read as an inconsistency. Leave the
  script's label alone and make the prose citation explicit about what it points at (*"the guard at
  `:128`"*, *"the method at `:121-134`"*), so the reader knows the summary is describing the hunk.
- **`data-path` is reserved to ledger rows.** Excerpts carry `data-src`. `scripts/coverage-gate.sh`
  greps `data-path` across the whole page and compares it to the diff as a set, so an excerpt using it
  would register as a surplus path — and would do so most reliably when citing unchanged code, which
  is to say on the page's best content.
- **The tint is applied to the quotation, never written into it.** `--source` excerpts are
  syntax-coloured; `--diff` excerpts are not. See § *Syntax tint* below for why the two differ. An
  `hljs-` class in the HTML a run writes is a defect whichever variant it is on: the colouring is the
  page script's job at read time, so the bytes on the page stay the bytes `git` produced.

### Syntax tint

`excerpt.sh --at` puts a `data-lang` on the `<pre>`, guessed from the path (`--lang` overrides it,
`--lang none` suppresses it). The page's script reads that attribute and colours the block with
highlight.js, loaded from cdnjs — the one script host a published artifact may load. Its *stylesheets*
are not loadable, so the theme for it is ours, defined as `--syn-*` tokens in all three theme states
like every other colour on the page.

Three properties make this safe to do to a quotation, and they are the reason it is worth stating
here rather than leaving as template detail:

- **It degrades to today's page.** No script, no network, a blocked CDN, a language outside the
  library — each of those leaves the excerpt rendering in one ink, exactly as it did before the tint
  existed. Nothing on the page depends on colour to be understood.
- **It cannot alter the quotation.** The script highlights the slice as one stream, splits the result
  back onto the generator's lines, and compares the reconstruction to the original character by
  character before touching the DOM. Any mismatch and the line is left alone. It sets no weight and no
  background either: bold code reads as an emphasis the author never wrote.
- **`--diff` is deliberately excluded.** A hunk is not one lexical stream — a removed line and the
  line replacing it are alternate realities, and a lexer fed both mis-reads everything after the first
  unbalanced quote. Its rows already use colour to mean *added* and *removed*, and a second colour
  system on top of that makes both harder to read.

The reason to have it at all is the same asymmetry that produced the `--source` variant: unchanged
code arrives with no diff view and no familiarity behind it, so anything that lets the reader find the
one line the claim rests on is doing the component's job.

### Budget

Same shape as the diagram budget, and for the same reason: the constraint is what keeps the component
meaning something. But it needs a sharper test than the diagram budget does, because the obvious
phrasing is circular.

**"One per field that earns one" is not a budget.** *Affected but unchanged* is by definition nothing
but claims a reader would otherwise take on faith — that is the field's stated reason for existing —
so under that reading every one of them earns an excerpt automatically, three flows produce three
without a decision being made, and a twenty-flow PR produces twenty-plus. A cap that is always
reached is not a cap.

**The test that does work: is the citation load-bearing for a decision the reviewer has to make?**
Not merely unchanged, not merely interesting — load-bearing. A finding they will act on, ask the
author about, or have to weigh. Most *affected but unchanged* entries are context; a few are the
reason the section exists, and those are the ones that get the lines brought to them. This test came
out of a run that hit the circularity above and had to invent something to escape it.

**The test rations; it does not gate the floor.** A flow's own `--diff` hunk is not competing under
it — that hunk *is* what the flow explains. Applying the test uniformly is what produced the failure
this section was rewritten to fix: pages that quoted unchanged code well and never once showed the
change. Apply it to everything beyond one hunk per flow.

Then the mechanical limits:

- **One excerpt per field or entry**, never two.
- **Never twice for the same lines.** If a flow field and the § 3 entry pointing at it rest on the
  same citation, the excerpt goes in **one** of them — the flow, which is where the finding is
  explained — and the other cites in prose. Do not solve the duplication by
  quoting a *neighbouring* range instead: a run did exactly that, and the near-identical second
  excerpt was the one excerpt it regretted.
- **Never a near-duplicate.** Two excerpts of structurally identical code — the same guard chain, the
  same shape of method, ninety lines apart — teach once and cost twice. The second is a prose citation.
- **Past about 24 lines the prose is not pointing precisely enough.** For `--source`, tighten the
  range. For `--diff` the range is the hunk's and you cannot trim it, so the answer is different:
  drop to `--at` on the decisive lines, or cite in prose. `excerpt.sh` warns at that length and still
  emits, because it is a generator and not a gate.
- **Never excerpt** lockfiles, generated API types, compiled assets, pure renames, import-only edits
  or test boilerplate — ledger rows by definition, and an excerpt of one teaches nothing. `db/schema.rb`
  is the one nuanced case; see the note under the location table.
- **A page-wide sense of scale**, since the per-field cap alone does not bound the total: the count
  grows with the number of flows and the number of load-bearing findings, never with the file count,
  which is a far slower curve. Two per flow is the ordinary shape — the hunk the behaviour turns on,
  plus the one unchanged citation the flow rests on — and a third wants a reason. **Count per flow,
  not per section, inside § 2**: a section-wide limit of two there is a limit of two across the bulk
  of the page, which is how this format ended up under-quoting the diff. Outside § 2, more than two
  in a section is still the sign that the prose is not doing its job.

**Link rung changes the budget, in one direction only.** At rungs 3 and 4 nothing is clickable, so an
excerpt is the only followable evidence there is: lean towards more. At rungs 1 and 2 the budget above
applies as written — clickable citations are not a reason to cut it, because the reason a reader does
not click is the cost of arriving in an unfamiliar file, and a working link does not lower that cost.

One file at a time, rungs 1 and 2 have the same condition: where GitHub will not render a file's
diff, its citations link the file instead and lose the before-and-after, so those earn the `--diff`
excerpt the same way a rung-3 citation earns any excerpt. § *When the diff will not render* is where
that lives; this is the paragraph it adjusts.

### Excerpts are also the shortest way to say what code does

The budget above rations excerpts against prose, which is right when the excerpt is *additional*. It is
the wrong frame when the excerpt **replaces** prose, and that is the more valuable use.

A paragraph describing what a guard does is longer than the guard, less precise, and unverifiable. So
where you are about to write prose that narrates code, show the code and write one sentence of
**implication** instead:

> Before — 65 words narrating the method:
>
> *"The guard first returns early when the project is already archived, then again when the caller is a
> workspace admin, then checks whether any time entries are still open. Previously the admin branch
> skipped the open-entry check entirely, which meant an admin could archive a project underneath
> entries still being edited, and those entries would then fail to save against a project no selector
> offers."*
>
> After — 23 words plus the excerpt:
>
> *"Archival now runs the open-entry check for everyone; the admin bypass is gone, which is what
> prevents entries stranded against an archived project."* ▸ `projects_controller.rb:41-52`

Shorter, checkable, and the reader who trusts it can move on without opening the block.

**The guard is unchanged and matters more here, not less.** The sentence must still stand on its own
with the excerpt closed — it states the *implication*, which is the thing the code does not say. What
you are removing is narration of the mechanism, never the consequence. A page whose prose collapses
into "see the code below" has failed both rules at once.

Two corollaries:

- **Prefer the excerpt to the paragraph, then re-check the budget.** Replacing prose does not exempt an
  excerpt from being load-bearing; it means a load-bearing citation should more often arrive as lines
  than as description.
- **Never narrate an excerpt after showing it.** Restating in prose what the reader can now see is the
  duplication this whole format exists to remove, and it undoes the saving that justified the excerpt.

## Impact paths

The § 4 figure, and the page's fourth primitive. A **path** is a directed chain that runs from code
this PR changed, through the affected-but-unchanged code that gives the change its consequence, to an
**observable behaviour** — what a user or an operator would see. Rendered as `.impact`, assembled
whole in `page-template.html`.

It replaced a box grid, and the reason is worth keeping because the box grid looked reasonable. Its
only encoding was border style, solid for changed and dashed for affected, so it carried membership
of two sets and nothing else. Set beside each other, a changed function and an unchanged consumer say
only that both are on the page; what a reviewer needs is *what the first does to the second*. Real
pages then filled each box with a clause to supply the missing relation, and the figure became a grid
of sentences with no edges — the layout arguing with its own content. So the edge is now the component's
first-class part, and adjacency is not asked to imply anything.

**The three node kinds, and the boundary.**

| Kind | Class | Reads as |
|---|---|---|
| Changed by this PR | `.ip-chg` | solid border, page ground |
| Affected, not changed | `.ip-aff` | dashed border |
| Behaviour / outcome | `.ip-out` | filled, ink ground — the terminal treatment `.pipe`'s last node uses |

`.legend` is required and names all three. The lane a node sits in — *changed by this PR* on the
left, *the existing system* on the right, with a **dotted** rule between them — is **derived from
the kind and never authored**: `.ip-chg` left, `.ip-aff` right, `.ip-out` spanning both, since an
observable behaviour belongs to neither half. So the boundary the reader sees is structurally true,
and there is no lane class for a run to put on the wrong node.

**Solid hairlines flow, dashes bound.** The lane divider is dotted and the connectors are solid,
and that split is load-bearing rather than decorative: the divider began as a 1px solid hairline in
the connectors' own ink, so the one line on the figure carrying no direction looked exactly like
the lines that do, and a path crossing it read as joining it. Dashes are already how `.ip-aff` says
*the existing system*, so anything drawn solid is now part of a chain and nothing else is.

**One path per `.ip-card`, and the card is the frame.** `.impact` is a group, not a box: it carries
the label, the one `.legend` for every card, and the note. Each card holds its own `.ip-hd` naming
the behaviour, its own `.ip-lanes`, and one `ol.ip-path`.

The first version stacked every path inside one bordered panel under a run of `.ip-hd` headers, and
on a real page that meant five chains in one frame. At that length they stop being read as diagrams:
the reader on the third chain has the first one's geometry behind them, a gap is the only thing
saying where one path ends, and a shared frame invites a sixth. Separating them is also what makes
the cap below enforceable as a *count of figures* rather than a count of headings inside one.

**The lane labels repeat in every card**, which is both the price of separating them and the reason
to. A card is a whole figure; a reader arriving at the third one must not scroll back to learn what
its two columns mean.

**The lane crossing draws itself too**, so there is nothing to add when a path changes side: a change
of lane *is* a change of kind, and the stylesheet draws the elbow from it. Mark the kinds and leave
the connectors alone — no extra element, no inline style, no `<svg>`.

**Every node past a path's first carries its incoming relation**, as `<span class="ip-rel"><i></i>…`.
An unlabelled edge is therefore a *missing element* rather than an empty one, which is what makes it
checkable.

**A label reads from the node above to the node below.** *`render_summary/4` — reads —
`context.learning_objectives`* means the first reads the second. Get this backwards and the figure
is still well-formed and says the opposite thing, which no check can catch.

The relation is the causal verb, and this is the vocabulary:

> calls · reads · writes · passes · returns · defaults to · falls back to · falls through to ·
> filters · filtered out by · scopes · renders · builds · produces · serializes as · receives ·
> enqueues · broadcasts · causes · read by · called by · rendered by · subscribed by ·
> **ignored by**

**The passive forms are in it deliberately**, and they are what keeps the direction rule above
affordable. Half the edges on this page run producer to consumer — a changed column and the
unchanged query underneath it — where the honest verb is *read by*, not *reads*. Without a passive
a run has to invert the pair to find an active verb, which puts the consumer above the thing it
consumes and reverses the figure to satisfy the vocabulary.

**`subscribed by` earned its place from a real Phoenix page**, where a changed gate decides whether
anything subscribes to a trigger topic — so the consequence travels from the topic to the process
that is *not* listening, and the honest label is passive. It is in the list for the reason the other
passives are: the active form would have put the subscriber above the topic and reversed the figure.
The active direction, *subscribes to*, is **not** in the list, because nothing has needed it yet and
a vocabulary grown ahead of its edges is a list nobody checks against.

**`ignored by` is the one to know**, because it labels the commonest finding this page carries: a
consumer that does *not* account for what changed. Nothing happens, and that is the causal step —
*`projects.archived_at` — ignored by — `ActiveProjects#call`* is the whole bug in one edge. The
alternative is what the box grid did: put the omission in a clause and leave the reader to infer
the relation.

A verb outside the list is a **warning, not a failure**: a stack legitimately names relations this
list lacks, and failing hard would teach a run to mislabel an edge to satisfy the check. Extend the
list here and `CAUSAL` in `evals/checks/impact-paths.rb` together — the rule
`evals/checks/diagram.rb` already states for its class vocabulary.

**Shape rules. Each one is the difference between an impact path and something that merely looks
like one.**

- **Every path sits alone in its own `.ip-card`, with that card's `.ip-hd` and `.ip-lanes`.** Two
  paths in one card is the stacked panel this replaced, and it looks very nearly right — which is
  why `evals/checks/impact-paths.rb` checks the card-to-path pairing rather than the presence of a
  card.
- **A path starts at `.ip-chg` and ends at exactly one `.ip-out`, which is last.** A chain that stops
  at a function has not reached a consequence, and the consequence is the reason the figure exists.
- **Every path holds at least one `.ip-aff`.** A path with no unchanged node is a call stack inside
  the diff — true, and visible in the diff already. Unchanged-but-affected code is what this page is
  for, so a path that does not pass through any is not earning its place.
- **At most two lane crossings.** The point is the one or two interactions that carry the
  consequence, not every hop between them.
- **Labels, never sentences, and no citations inside the panel.** `<b>` is an identifier;
  `.ip-d` is a few words at most. The `file:line` belongs to *affected, not changed* below, which
  keeps one canonical home and is what stops the panel becoming the grid of sentences it replaced.

**Budget: 2–3 paths, 3–5 nodes each.** These are the paths a reviewer has to *hold*, and three is
already the outer edge of that — wanting a fourth is the signal that the three you have are not
doing their job, which is the same question § *Depth rules* asks about a second diagram. The fourth
consequence is not lost by being left out: *affected, not changed* below carries its entry, and the
flow that owns it carries its explanation. It was five, and five is where a real page put them; on
that page the panel had become a section to scroll rather than a figure to read.

And a change with no nameable edge earns **no panel at all**: the affected list carries the entries
either way, and a figure that cannot say what reaches what is the thing this component exists to
stop.

The panel **is** § 4's one figure — one `.impact` group, whatever its card count — so § 4 earns no
second, at either level.

Two things the panel is not. It is not a dependency graph: it is 2–3 curated paths chosen because a
reviewer has to hold them, and completeness here would destroy the thing that makes it readable. And
it is not SVG. Not because a figure cannot be pre-laid-out — both of § 2's are, on fixed canvases —
but because *this* figure has two lanes, an elbow that draws itself from a class change, cards that
stack as the path count varies, and a breakpoint at 780px where the lanes collapse. There is no
canvas that survives all four, so a drawing would mean coordinates derived per run, which
§ *Depth rules* rules out for making two pages from this skill incomparable.

## One canonical home

Every fact, finding, risk, uncertainty and reviewer action has **exactly one place** in the page that
explains it. Everywhere else refers to it in a sentence and moves on.

This is a structural rule, not an editing tip, and it is the reason the sections below are shaped the
way they are. An earlier version of this format had twelve parts, three of which existed to restate
material from the others — findings surfaced in *start here* and then re-explained in full inside a
cohort, cross-cutting concerns retelling behaviours, a checkpoint quizzing the reader on the paragraph
above it. A 21-page page became 9 pages with nothing of value removed, which means roughly half of it
was the same content arriving repeatedly. A reviewer who thinks *"I have read this already"* stops
reading, and everything after that point is wasted regardless of how good it is.

**Assign the home by where the reader first needs it**, then reference from later sections:

| The concept | Lives in | Referenced from |
|---|---|---|
| A high-value finding | The flow it belongs to | *Start here*, as one prioritized entry; *What this change reaches*, in one clause |
| Unchanged code one flow gives new meaning to | That flow's *affected but unchanged* | *What this change reaches*, as a named pointer |
| Unchanged code no single flow owns | *What this change reaches* | The flows it touches, in one clause |
| A consequence spanning flows | *Cross-cutting consequences* | Each flow it touches, in one clause |
| Behaviour specific to one flow | That flow | Nowhere else |
| An open question for the author | *Before approving* | The flow that raised it, if the reader needs it there |
| A validation step | The flow it validates, or *Before approving* if it is setup | Not both |

**The flow owns the explanation, and the sections after it point back.** That is what the ordering
buys: §§ 3 and 4 both come after § 2, so neither has to re-explain a mechanism to be readable. A
section that finds itself explaining a flow's finding a second time is in the wrong section.

The reference form is one sentence, no re-explanation:

> The `ActiveProjects` consequence is explained in Flow B.

Not a summary of that consequence, not its citation again, not its tier label again.

**At `--brief` the routing has fewer destinations, and the rule is unchanged.** Rows 3, 4, 6 and 7
above all name a section that does not exist at that level; each resolves to the merged § 4, and the
concept keeps exactly one home there. The one that needs care is row 4: a consequence spanning flows
lands under the merged section's `<h3 id="crosscutting">`, still explained once, still referenced from
each flow it touches in one clause. Fewer sections is not licence to explain something twice because
the second place is now the same place — a merged section that carries both a flow's explanation and
the pointer back to it has restated it at a distance of two paragraphs, which is the worst version.

**Two consequences worth stating plainly.** A caveat belongs in the page once — *"these findings are a
pass, not an audit"* is said in *start here* and nowhere else. And a `file:line` is not repeated every
time its fact is mentioned; it sits with the canonical explanation, and later references point at the
section, not the file.

**Where synthesis beats deletion.** When two sections hold overlapping but non-identical facts, merge
them into one sentence that carries both rather than keeping the better one:

> Because archival writes `archived_at` and leaves `discarded_at` untouched, archived projects stay
> inside `ActiveProjects`, so every selectable-project list keeps offering them. Whether that is
> intended is an author question.

Three separate paragraphs — one for the write, one for the scope, one for the lists — say less than
that, at four times the length.

## Depth rules

Depth scales with how much the diff puts into a section, on the same shape as before:

| Weight of the section | Treatment |
|---|---|
| Nothing | Omitted entirely |
| One small thing | A paragraph, or a row in a shared "also changed" table |
| A handful | Its own subsection with a table |
| Substantial | Subsection, plus grouping or units, plus a diagram if one is earned |

For behaviour flows, weight is the number of flows and how far each reaches, not the file count —
a two-file flow spanning a serializer and a TS type can need more explanation than an eight-file
one that is a single rename.

File count sets *prose* depth. It does not set diagram count — **diagrams are earned by mechanism
complexity, which is a different axis.** A six-file migration introducing a state machine can need
two figures; a twenty-six-file layer that is one linear pipeline needs one. Judge on how many
distinct mechanisms a reader has to hold, not on how many files carry them.

**Diagram budget: one per section, and a second only for a genuinely different mechanism.** Each must
show something a table cannot. A diagram that restates a list is worse than no diagram, because it
costs the reader time and teaches nothing.

**A behaviour flow is its own `<section>`, so in § 2 that budget is one figure per flow — and most
flows earn none.** The escape hatch below is about § 5 and does not apply here: a flow's figure is a
boundary chain *or* a guard fork, never both, because the two answer different questions about one
behaviour and a flow that genuinely earns both is **two flows**. `evals/checks/diagram.rb` says the
same thing from the other side, and says it as a failure rather than a warning.

The one place a second is routinely earned is persistence: an ER diagram shows *structure*, a
lifecycle diagram shows *behaviour over time*, and no single figure shows both. If the diff adds a
status column or state machine on top of new tables, draw both. Elsewhere, if you find yourself
wanting a second diagram, the honest question is whether the first one is doing its job — and a
transition table with a `file:line` per row is often better than a second figure anyway. Never exceed
two in one section.

**Six kinds, and which section each belongs to — four of them drawings.** The criterion is not how
big the mechanism is, it is **whose length is load-bearing: a kind is a component when the *diff*
sets its size, and a drawing when the *claim* does.** An impact path is 3–5 nodes and a PR earns 2–3
of them; a path is as long as the call chain it follows. Neither has a canvas that survives, so both
are components, and a component reflows on a phone and cannot be drawn wrong. The four drawings are
the ones whose finding is attached to an **edge** or to a **position** — a hop where two sides stop
agreeing, a gate a request never reaches, a foreign key nothing declares, a transition nothing
guards — and a component has no addressable edge.

**That distinction is worth stating carefully, because getting it wrong cost this format a figure
once already.** The boundary chain spent a design generation as a `.pipe`, on the argument that a
chain "carries order along a chain, which a component shows as well as geometry did." It does. What
it cannot show is *which hop*, so real pages supplied the missing relation by writing the mismatch
into a node — which is exactly the box-grid failure described below, arriving in the vocabulary that
had just replaced it. **Size is a constraint on a drawing, not the reason for one:** the chain is
capped at five stops because a sixth does not fit the canvas, and that cap is what lets the geometry
be worked out once.

| Kind | Rendered as | Home |
|---|---|---|
| Impact paths | `.impact` — one `.ip-card` per path + one `.legend`, see § *Impact paths* | § 4, on almost every PR |
| The path | `.pipe` numbered spine | § 2, in every flow — the call or guard chain the behaviour runs through |
| Boundary chain | **SVG**, catalogue 1 of 4 | § 2, inside the flow that owns the field, never a section of its own |
| Guard fork | **SVG**, catalogue 2 of 4 | § 2, inside the flow whose behaviour is gated, and only when the change makes two request classes take different routes through one guard chain |
| ER fragment | **SVG**, catalogue 3 of 4 | § 5, if the schema moved |
| Lifecycle | **SVG**, catalogue 4 of 4 | § 5, and only if a status column, enum or state machine changed |

**The boundary chain is capped at five stops, and the cap is the canvas rather than a rule.** The
catalogue fixes the box at 148×54 and the pitch at 178 on an 880-wide canvas, and ships the left
margin for three, four and five stops; six boxes need 1038px, so the sixth fails
`evals/checks/diagram.rb`'s bounds test with no new number to keep in sync. Six stops means the chain
has **listed layers instead of following a field** — a fetch wrapper or a cache that passes the value
through unaltered is a stop on *the path*, not on the crossing. Collapse to the hops where the field
changes shape, is renamed, or is dropped; if it is genuinely longer, the drawing is not earned and a
second `.pipe` is the honest form, because a spine grows down the page and reflows. And **never
narrow the canvas to fit a short chain**: the scroller's child is `min-width:880px` with
`height:auto`, so a 524-wide viewBox renders at 1.68× and every glyph in the figure comes out larger
than the rest of the page. Three stops sit centred in 880, and that whitespace is honest.

**The guard fork is capped at three gate rails and two request-class tracks, and it is the one kind
with a three-part trigger.** Draw it only when the diff changes a **gate's condition** rather than
appending a gate; that change sends **two nameable request classes** down different routes through
the same chain; and the finding is **where the diverted class lands** — a gate it never reaches, or a
destination that sends it back. Miss the third and there is no figure: a class that gets a 403 where
a 403 is the intent is a field row, and *a guard that returns early for one class is not a fork —
drawing one invents a population the code does not distinguish.* A longer real chain does not make a
taller figure: draw only the gates at which the two classes differ, plus the one gate never reached,
and leave the rest to the `.pipe` and the field rows. A third class is a figure in the flow that owns
it, never a third track. Wanting a fourth rail is the signal that the three you have are not the ones
the finding turns on.

Two things the fork can say that no numbered spine can, and they are why it is a drawing. A `.pipe`
is an ordered list — exactly one successor per node — so a request that leaves the chain at step 2
has **no position in it at all**. And when the diverted class re-enters the chain the finding is a
**loop**, which has no last node, so the component's filled terminal asserts an arrival that never
happens: the one ink it spends on emphasis would state the opposite of the finding.

The last row is the one that gets abused: a nullable timestamp is not a state machine, and drawing one
invents states the code does not have.

All four SVG layouts are worked out in `page-template.html` — complete, to scale, and to be filled in
rather than re-derived, because a layout invented per run makes two pages from this skill
incomparable for no gain. The two § 2 kinds are assembled **inside the flows** there rather than in
the § 5 catalogue block, because a flow figure's placement among six siblings is half of what a run
has to copy, and a composition described but never shown assembled does not survive a weaker reader.

**The § 4 figure carries directed edges, and that is why it is not a box grid.** It used to be one:
`.blast` encoded membership of two sets in its border style and could express nothing else. So when
the finding was "the shared error code stops being produced at this hop", adjacency could not say it
and the rule was to put it in the note underneath, in words — a figure with a footnote explaining
what the figure could not draw. § *Impact paths* replaced it, the edge label is now a first-class
part of the component, and that footnote rule is **gone** rather than inherited. The legend is not
optional either: a dashed node with nothing explaining it reads as *deleted*, which is the opposite
of *unchanged, and therefore worth reading*.

Its budget and caps live in § *Impact paths*, the way an excerpt's live in § *Source excerpts*.

**§ 2's missing relations could not be fixed the same way, and that is what its two drawings are
for.** § 4's gap was a missing *edge*, and the answer was to make the edge a first-class part of the
component — `.ip-rel` carries a causal verb, so the panel says what the box grid could not. A flow's
gaps are a missing **hop** and a missing **branch**: a `.pipe` connector is a bare hairline with
nothing to dash and nowhere to put a label, and a numbered list has exactly one successor per node,
so a request that leaves a gate chain partway has no position in it and a loop has no last node. A
component part can be added for a label; it cannot be added for a topology. So the boundary chain and
the guard fork are drawings, on canvases that cap them.

**A diagram carries labels, not sentences.** Prose inside an 880-wide scroller cannot reflow, so a
reader on a phone scrolls sideways to read it, and it is set in whatever size the diagram's own type
scale allows rather than the page's. Searches, caveats and conclusions go in the `figcaption`. This
is the one rule the diagram checks cannot enforce, because a `<text>` element carrying a sentence is
structurally identical to one carrying a label.

Excerpts have their own budget, in § *Source excerpts*. Keep the two apart when judging a section: a
diagram is earned by mechanism complexity, an excerpt by a claim the reader would otherwise have to
take on faith. Neither is earned by file count.

Adaptivity trims ceremony on small PRs. It never trims teaching on a large one — on a big change,
explanation is the whole product.

**The detail level is a different axis, and the three multiply rather than substitute.** Everything
above applies unchanged at `--brief` — what the level decides is how many sections there are to
weigh, not how heavily each one is weighed, and § *The brief budget* then caps the **prose** a
weighed section may spend. Two consequences for diagrams specifically: `--brief` draws no § 5 figures
at all (no ER fragment, no lifecycle — migration safety is a row there), so its merged tail section
holds the `.impact` panel and nothing else that could compete for the budget. And a run at `--brief`
must not read the shorter page as licence to skimp on a flow's diagram, which is the one figure
**a flow** earns.

**The word budget reaches no figure, in either direction.** It does not remove one, does not trim
one, and does not count one: every `<svg>`, its `figcaption`, its `.legend`, the `.pipe` spine's
labels and the `.impact` panel's box text are exempt from it by name. A run that answered a
length warning by dropping a drawing has read the budget backwards — the geometry here is worked
out once precisely so it is not the thing a run negotiates.

Both § 2 kinds are therefore **level-independent**: §§ 1–3 have the same spec at both levels and the
budget exempts every figure from its count, so a `--brief` page carries a flow's drawing where it
carries no other, and `evals/checks/diagram.rb` still needs no level awareness to count them.

**The primer used to be the companion example here and no longer is**, which is worth stating rather
than quietly dropping: it is `--full` only now (§ *The brief budget*), so the two things that share a
flow's slot either side of the `.mech` are governed differently — the figure is level-independent, the
callout is not. `diagram.rb` still needs no level awareness and `rails-anchors.rb` still must not read
the level, for the same reason in both cases: a page that emits no primer has no primer to fail.

## The completeness invariant

**Every file in the diff appears somewhere in the page.** A reviewer who wants to read all of it must
be able to, and must never wonder whether something was quietly skipped.

The depth rules govern *how much treatment* a file gets, never *whether it is accounted for*. Files
needing no discussion are still listed, batched into a compact table with a one-clause reason
("regenerated by the migration", "import path updated", "factory for the new model"). Renames and
pure moves get a line saying so, which is itself useful.

**The invariant is one-directional.** Every path in the diff must appear in the page. The reverse does
*not* hold: the page cites unchanged files everywhere by design — that is what § 4 and the
*affected but unchanged* field are for. So the check is a subset test, never set equality:

```
set(diff paths) ⊆ set(paths cited in page)     ✅ the invariant
set(paths cited in page) == set(diff paths)    ❌ impossible by construction
```

The one place equality *is* asserted is the coverage ledger, which is machine-generated from the diff
for exactly that reason. Never "fix" a surplus elsewhere by deleting a citation to unchanged code.

**The invariant does not have a detail level; only its carrier does.** At `--full` the paths live in
§ 7's classified ledger. At `--brief` they live in `details.coverage-foot`, a shut disclosure below
the last section — generated by `ledger-rows.sh --paths-only`, one `.gt-paths` cell each, still
carrying `data-path`, so `coverage-gate.sh` greps them page-wide and asserts the same equality it
always did. That is the whole reason the carrier is a grid cell rather than a list item, and it is
why a shorter page is legitimate rather than a silent gap: what `--brief` declines to do is
*classify* the diff, never account for it. `data-path` stays reserved to whichever of the two
carries it — an excerpt using it would register as a surplus path at either level.

**Neither carrier is § 4, and that is a change from an earlier version of this format.** § 4 used to
hold the whole diff as well — a `.filelist` at `--full`, `.gt-paths` cells at `--brief` — which put a
list of every changed path in the middle of the section whose own spec says *completeness here is
about consequences, not paths*. On a 24-file PR it rendered as 24 links above a caption explaining
that the eight worth opening were ranked in § 3. It accounted for nothing § 7 was not already
accounting for, so it is gone at both levels.

**The foot disclosure is provenance, and collapsing it is legal for that reason.** The hard rule is
that the page reads complete with every collapsed block shut, and an inventory of paths passes that
test where a *finding* never would. So nothing a reviewer has to act on may be put in there — the
same split § *What was searched* draws between a finding in the open prose and the grep behind it.

---

## Build state

The page ships in stages and fills in at one URL (`SKILL.md` step 9). That only works if a
half-written page cannot be mistaken for a finished one, so the page carries its own build state
until the moment it is complete.

**Three states, and they must not look alike.** The confusion this prevents is a reader seeing no
boundary material, concluding the change has no contract implications, and being wrong.

| State | Means | Rendered |
|---|---|---|
| **Written** | The section is there | Normally |
| **Pending** | This diff earns the section; it is not written yet | An explicit marker, in the rail *and* in place |
| **Omitted** | The diff does not earn it | Nothing at all. Never an "N/A" row, never an empty section |

**The banner** sits above the masthead until the final publish:

```html
<div class="buildstate">
  <strong>Still being written</strong> — 3 parts still pending, updated 14:32.
  Parts marked pending below are not yet written. Their absence is not a finding.
</div>
```

That last sentence is the load-bearing one. Keep it.

**It counts what is pending, not which stage this is.** The banner used to read *stage 2 of 3*, and the
denominator stopped being true once the behaviour flow became the unit of staging: the number of
arrivals now depends on how many flows the diff earns, so a run would have to commit to a total before
it knows one. A count of parts still pending needs no total, and it is the number the reader wanted
anyway — *how much is still coming*, not *how far through its own plan the run is*.

**Pending in the rail** so the reader can see the shape of what is coming:

```html
<li><a href="#flows">Behaviour flows <span class="pending">pending</span></a></li>
```

**Pending in place**, where the section will go, so someone scrolling does not skip past a gap:

```html
<section id="flows">
  <div class="eyebrow"><span class="lbl lbl-a">Flows</span><i></i></div>
  <h2>Behaviour flows</h2>
  <p class="note"><span class="pending">pending</span> Three flows across seven files; this section is
  being written.</p>
</section>
```

One line of substance in the stub — how many files, what it will cover — turns a placeholder into
information. "Coming soon" does not.

Note that the stub is a whole `<section>` with its own `id`, which makes it a unique anchor a later
stage can `Edit` in place. That is deliberate and worth keeping: it is what lets a stage write only
what is new instead of re-emitting the document, which `SKILL.md` step 9 requires and which a profile
found to be the largest single cost in a run.

**The coverage ledger is marked partial** until the final publish, because the gate has not run. Say
so above the table rather than letting a short ledger imply a short diff.

**A run that stops early is a third state, not a draft that never finished.** Same components,
different words: the banner states what was covered and that the run stopped, every marker changes
from *pending* to *not written*, and the ledger note says the gate never ran. The distinction is the
whole point — *pending* is a promise, *not written* is a fact, and a page left promising work that is
not coming is the one outcome worse than publishing late. `SKILL.md` § *When a run stops early* has
the wording.

**Pending attaches to whatever a reader could mistake for finished**, which means three
granularities, not one.

A **section**, which is the stub above, and the case at `--full`.

A **`<h3>` sub-part**, at `--brief`, where the tail is one section written in parts: a half-written § 4
marks its sub-parts pending in place, and the rail's one `04` entry carries a marker until all of them
are written. The mistake to avoid is the section reading as complete because its first part is — a
reader who finds an impact panel and no *before approving* has to be able to tell that one is coming
from that the diff earned nothing there.

A **behaviour flow**, at both levels, because § 2 is delivered one flow at a time
(`SKILL.md` step 9). An un-written flow is a whole `<section id="flow-x">` stub carrying the same
`.subhead` a written flow has — assembled in `page-template.html` beside the pending section, and
copied from there rather than rebuilt — and § 2's rail entry keeps a marker until every flow is
written, exactly as the `--brief` `04` entry does. A flow stub's line of substance is the flow's
**name and what it covers**: that is what lets the split be read before any flow exists, and it is
the reason opening stage 3 is worth a publish of its own.

The third case needs **no markup of its own**: the rail already carries a per-flow marker and each
flow is already its own `<section>`. A parallel mechanism for it is a regression, not an addition.

**At the final publish, all of it goes**: banner, rail markers, stubs. A finished page still saying
"2 parts still pending" undersells completed work and leaves the reader unable to tell whether the run
stopped early. If a section genuinely was left unwritten — the diff was too large, a region got skimmed
— that is a sentence of prose stating the limit, not a pending marker. The two mean different things:
pending is a promise, a stated limit is a fact.

## Where the old per-layer material goes

This format used to have a section per architectural layer — persistence, API surface, contract, then
cohorts. That guaranteed restatement, because one behaviour crosses all four and got described in each.
The layers are still covered; they are covered **inside the behaviour they serve**. Two things stay
global, because they genuinely are:

| Material | Now lives in |
|---|---|
| Schema structure: ER diagram, migration safety, schema-vs-migration consistency | § 5, once for the whole diff |
| Persistence detail for one behaviour: the column it writes, the callback it fires | § 2, in that flow |
| One endpoint's contract: params, response, errors, side effects | § 2, in the flow that calls it |
| The authorization matrix across endpoints | § 5, once |
| One field crossing the backend/frontend boundary | § 2, in its flow |
| Deploy-ordering hazard between the two sides | § 5, once |
| Test *infrastructure* that changes how other specs behave | § 5, once |
| Tests for one behaviour, and its test gap | § 2, in that flow |
| Primary / supporting / secondary classification | § 7, the ledger's group column — it was never worth a section |

## Section 1 · What changed — always

The masthead and the goal, merged: a reviewer orienting themselves reads one screen, not two that
overlap.

- PR title and number, branch → base, author, linked ticket if the project uses one.
- **The exact revision, as two short SHAs**: head → base, in the masthead's `Revision` cell beside the
  branch names. Branch names go stale the moment someone pushes, and a page that describes an earlier
  revision while looking current is the one failure a reader cannot detect from the inside. Both SHAs
  are already recorded in step 1 — the head, and the left side of the diff — so this costs nothing and
  is not conditional on there being a PR. It matters most where the page is regenerated automatically:
  a run per push means several pages exist, and the SHA is what tells them apart.
- **Change shape** chip: feature / refactor / bugfix / migration / dependency bump / mixed. Reading
  strategy differs per shape.
- Metric strip, restricted to metrics that change a reviewer's behaviour: commits, files, and a line
  split. A PR that is 70% specs is a different animal from one that is 70% new controllers. Buckets are
  fixed so numbers stay comparable between runs:

  | Bucket | What lands in it |
  |---|---|
  | Production | Application code a human wrote and a human must review |
  | Test | Specs, test support, factories, fixtures, cassettes |
  | Generated | `db/schema.rb`, lockfiles, generated API types, compiled or vendored assets |
  | Docs | Markdown and other prose |

  Count generated and docs separately rather than folding them into production — a 150-line
  `schema.rb` churn is not 150 lines of review surface, and reporting it as such makes every migration
  look terrifying.
- **What it is for, and what changes**, in a few sentences derived from the code, tests and commits —
  65 words at `--brief`, per § *The brief budget* —
  **not** copied from the PR description. What was possible before, what is possible now, what is now
  prevented. Then the use cases, one line each, as actor plus behaviour:

  ```
  A workspace admin archives a project — new time entries are prevented, historical ones preserved.
  ```

  The **execution path** for each belongs to that behaviour's flow in § 2, not here. Naming the use
  case is what § 1 owes the reader; tracing it is § 2's job.
- **Before and after are two rows, never one paragraph.** Rendered as `dl.ba`: a *Before* row for the
  state that no longer holds, an *After* row for the one that does. Written as a sentence — *"…was
  possible. After: it is not"* — the second clause reads as a subordinate aside and gets skipped, and
  it is the half the reviewer came for. Where the behaviour is new rather than changed, drop the pair
  and state what is now possible; *"before: this did not exist"* is filler. One evidence tier for the
  pair, on the *After* row: the claim is the transition, so labelling both rows states the same
  evidence twice.
- **Evidence tier on the intent itself.** Behaviour pinned by a test is a different claim from
  behaviour inferred from a service class's name, and the reviewer's next move differs. Where intent
  cannot be established, state the gap as a gap.

## Section 2 · Behaviour flows — the bulk

The reader's way into the change, and the **canonical home** for everything one behaviour owns. It
comes before the route through the code and before § 4 because both of those are easier
to write, and far easier to read, once the mechanisms are known.

One flow per behaviour or user cohort, grouped as decided in step 6 of the procedure and **never by
directory**. `Services / Models / Hooks / Components` is the repository's structure, not the change's,
and a reviewer who reads it still has to assemble the behaviour themselves. State the grouping
principle before the flows — the split *is* the insight.

Each flow carries **only what is specific to that behaviour**. Its **body is a review unit** (see
§ *The review unit*) — a `.mech` block stating the mechanism, then the seven fields as `<dt>`/`<dd>`
pairs in one `dl.rows` — and everything else the flow needs sits *beside* that unit, inside the flow
section. Which side of the boundary a
part falls on is settled here rather than per run, because a run given the list without the split
put the fields loose in the section and a decisions block in the middle of them.

**Beside the unit, in this order.** Take what the flow needs and omit the rest:

- **Before / after** — what was possible, what is now, what is now prevented. `dl.ba`, per § 1's rule
  that the two are rows and never one sentence. **At `--brief` the flow does not carry this block**:
  § 1's pair is the page's one transition block and the flow states its own transition inside the
  `.mech`. See § *The brief budget*.
- **The path**, as `.pipe`: UI → request → controller → operation → model → column, and the
  response path back if it carries anything interesting. The numbered spine fills its terminal node,
  so put the thing the chain arrives at last. In a Phoenix LiveView flow the same chain is
  event in `.heex` → `handle_event/3` → context → changeset → `Repo` → column, with the return leg
  assigns → re-render → diff over the socket.
- **The field crossing the boundary**, if it does, **as the flow's one drawing** — serializer → JSON →
  type → hook → component. Layout from the catalogue in `page-template.html`, 1 of 4, assembled inside
  flow A there: take the stop grid for the length you actually have and fill in the text. It goes after
  the `.pipe` and before the `.mech`, not out here in list order, because it answers the question the
  spine raises and cannot settle. Following one field teaches more than reviewing both sides as
  separate file trees.

  **It is a drawing rather than a second `.pipe` for one reason: the finding is *which hop* the two
  sides stop agreeing at.** Mark that hop with `.edge-dash` and label it above the row. A numbered
  spine has no edge to mark, so a run given the component wrote the mismatch into a node instead —
  and a chain of clauses is not a figure. Three, four and five stops each have a left margin in the
  catalogue; six is refused by the canvas, and § *Depth rules* has both rules and the reason.

  The mismatches worth hunting: nullable backend field typed non-null, a key renamed with nothing
  renaming it, backend enum value missing from the frontend union, a new error status nothing handles,
  a required param the client never sends. If the
  client is in another repository or simply absent, say which and build the backend half only — do not
  guess at code you cannot read, and draw no chain for a crossing you could not trace.

  **A LiveView app has this chain too, and it is a different seam.** There is no serializer and no
  generated type, but there is still a contract with no compiler behind it: the `phx-*` attribute value
  and the `handle_event/3` clause that answers it, a form input name and the changeset's `cast` list,
  `stream_insert` versus an assign the template still reads, and `pushEvent` from a `phx-hook`. Build
  the second chain from those instead. The mismatches worth hunting are the same shape — an event with
  no clause (which crashes the process rather than rendering wrong), an input the changeset drops, a
  broadcast payload no `handle_info` matches. That crossing is a **4-stop** chain — `phx-*` value →
  `handle_event/3` clause → changeset `cast` → assign the template reads — and a form-input-name →
  permitted-params → column crossing in a server-rendered monolith is a **3-stop** one, which is why
  the catalogue ships those margins rather than only the five-stop case.
- **The endpoint** it goes through, if the diff changed one: params with required/optional and where
  they are coerced, a real success body, the **full** error list with statuses — at `--brief`, the
  errors the diff adds, moves or removes, plus a count of the rest — and a side-effects row
  — reads only / writes / calls an external service / idempotent or not. That last row is the
  reviewer's actual question and no diff answers it. There is **no endpoint card**: the contract is
  the flow's own material, so it goes in the `.pipe` chain and the field rows that already exist.
  A separate card was a second home for the same facts, and § *One canonical home* is the rule it
  broke. Server-rendered instead? Then the flow is page → action → redirect or render, with forms,
  permitted params and flash states. A LiveView flow has no endpoint at all: what takes its place is
  the route and the `live_session` it sits in, the events the template can fire, the assigns the
  template reads, and the same side-effects row — which is the reviewer's actual question in any
  shape.
- **A framework primer**, where the decision turns on a framework behaviour the reviewer may not know.
  It goes between the `.mech` and the grid rather than out here with the rest of this list, because
  it explains the mechanism the `.mech` has just stated. One per flow at most, and most flows earn
  none; § *Framework anchors* owns that and everything else about it. **`--full` only** — at
  `--brief` a flow keeps the pinned `a.doc` link and explains the mechanism in its own prose, per
  § *The brief budget*.
- **The gate chain, as a guard fork**, when the change makes two request classes take different
  routes through it. Layout from the catalogue, 2 of 4, assembled inside flow B in
  `page-template.html`, and it sits in the same slot as the chain — after the `.pipe`, before the
  `.mech`. Three gate rails, two tracks, and **all three of these must hold or there is no figure**:
  the diff changes a gate's *condition* rather than appending a gate; two *nameable* request classes
  part at it; and the finding is *where the diverted class lands* — a gate it never reaches, or a
  destination that sends it back. A class that gets a 403 where a 403 is the intent is a field row.
  § *Depth rules* owns the caps and the overflow rule.

  **A flow draws at most one figure — the chain or the fork, never both.** They answer different
  questions about one behaviour, and a flow that genuinely earns both is two flows. Most flows earn
  neither, and a flow with no figure is the normal case rather than a gap.
- **Decisions to pay attention to** — the least automatable, highest-value content in the page. The
  decision, where it lives, why it matters, the tradeoff accepted. Mine them from comments explaining
  *why*, commit messages, named constants, transaction boundaries, `rescue` clauses, and anything the
  code deliberately refuses to do.

  **Last in the flow, after the unit's closing tag.** `.decision` has no card of its own — a
  border-top and a number in a 44px gutter — so it needs the unit's edge to read against; between two
  fields it becomes a full-width rule with a number hanging in a margin the field labels do not share,
  and it reads as a new section starting mid-flow.

  And writing decisions here does **not** discharge *things to understand*. That field is defined to
  carry decisions too, so a flow that moves them out here and leaves the field empty has turned itself
  into a ledger row — which is how one run lost the best finding on its page.

**Inside the unit, as its fields:**

- **Persistence for this behaviour** — the column written, the callback fired, the validation added,
  the state transition performed — cited in *implementation*, with whatever a reader would not have
  guessed in *things to understand*. Schema-wide structure is § 5's.
- **Affected but unchanged**, for this behaviour, with the clause on why. This is where such a
  finding is *explained*; § 4 points back at it rather than restating it.
- **Tests, and the gap**, in *relevant tests*. Which behaviour they pin, which branch they leave open.
  One sentence per test capturing its behavioural guarantee — never a walk through its assertions.
- **Validation** for this behaviour, if it needs its own, in *how to validate*. Setup and seeds go
  to § 6.

**A flow shows the code it is about.** The *implementation* field carries the hunk the behaviour
turns on as a `--diff` excerpt — a floor rather than something the budget rations, per § *Source
excerpts*. The reader has not opened the diff yet; § 3 is where they do that, and until then a flow
that only describes its change is asking to be believed.

**A flow explains; it does not defer.** Nothing here is held back for § 3 or § 4 to say properly —
those sections come after this one and point at it. The only forward reference a flow makes is to
§ 5, for a consequence that genuinely spans flows, and that is one clause.

## Section 3 · Start here — always

Where the reviewer stops reading and opens the code. They arrive holding § 1's intent and § 2's
mechanisms; what they still lack is a route through the diff. This section is that route, and it is
**one list** — what most needs judgment and what to read first are the same question, and answering
it twice is what used to make this section restate the rest of the page.

Render as `ol.begin`. Each entry carries:

- **Where to go** — the file, the method or the flow, with its citation.
- **Why here**, in a `span.why` — why this before the next thing, or what makes it worth judgment. A
  reason, never a restatement of the filename.
- **What remains uncertain**, if anything, with its evidence tier and what would settle it. At
  `--brief` this folds into the `span.why` rather than standing as its own line, tier and all — the
  tier is the load-bearing half and it survives. § *The brief budget* has the entry's 40-word cap.
- **Which flow explains it** — a link into § 2. The entry *names* the finding and says why it
  matters; it never re-explains it, and it does not repeat the flow's citation or tier.

Ordering defaults worth keeping: schema before the code that uses it; the smallest complete example
before the bulk; irreversible code last, read twice.

**Roughly five to eight entries, and never one per changed file.** An entry earns its place by being
somewhere the reviewer must *go*, not by being a file that changed. The list is also how the page
says where the attention goes — a 71-file PR whose six load-bearing files are the only ones on it
has said so, without a second list ranking the rest. Every other file is still accounted for, in
§ 7, with its own attention level of read, skim or mechanical. Ranking excuses nothing from coverage.

Never a grade. No severity chips, no approval language. If nothing rises to the level of judgment,
say so plainly rather than manufacturing concerns — the route through the code stands on its own.

Carry the sampling caveat here, once, and nowhere else in the page: these are what this pass
surfaced, not an exhaustive list. Repeated runs over the same diff surface overlapping but different
sets — the explanation is stable, the findings are a sample.

## Section 4 · What this change reaches — always

**This spec has two consumers.** It is § 4 at `--full`, and it is the spine of the merged section at
`--brief` — so a change here lands in both, and § *Section 4 at brief* says only what differs. Where
consequences extend beyond the diff. This is the section a diff cannot produce at all, and by
this point in the page it is a **second pass**: the reader has been through the flows one at a time,
and now sees the same change as one system, with the edges that leave it.

- **The impact-paths panel** — 2–3 directed chains, one per `.ip-card`, each running from changed
  code through the unchanged code that gives the change its consequence to an observable behaviour.
  § *Impact paths* owns the
  component, the causal vocabulary, the shape rules and the budget, **and owns them alone**. The one
  figure that earns its place on almost every PR. Arriving after § 2, it is a synthesis view: it
  shows the flows the page explained separately reaching the same unchanged code, and says what each
  one does to it.
- **Affected, not changed** — one list, the full measure, running on paths and inline code, which
  wrap mid-token at half width. It carries the excerpts. Every entry carries a citation and a clause
  on *why* it is affected, and that is the point of the section: the panel shows the shape, the list
  is where each entry is answered for.

  **There is no `Changed` list here, at either level.** There was, and it was the whole diff — so
  § 4 restated § 7 a few sections early, in a section whose own closing rule is that completeness
  here is about consequences rather than paths. See § *The completeness invariant* for where the
  inventory lives now.
- **One clause where a flow already owns it.** Most affected code belongs to exactly one behaviour,
  and that flow's *affected but unchanged* field has explained it. Here it is a named pointer —
  *"`ActiveProjects` scopes the selectable list — Flow B"* — and nothing more. What this section
  explains canonically is what no single flow owns: unchanged code several flows reach, or that none
  of them do.

  **A pointer has a shape, because "nothing more" is not self-enforcing.** A run produced a
  150-word paragraph with eight citations under a *"— Flow C"* heading and read it as a pointer.
  So: one clause naming what the code is and why the change reaches it, **one** citation, and a
  link to the flow. No second citation, no tier — the flow carried both. If you are writing the
  mechanism again, it is not a pointer, and the test is whether a reader who skipped § 2 would
  learn the finding here. They should not: they should learn that it exists and where it lives.

  **The link is an in-page anchor, and the deep-link rung does not govern it.** `href="#flow-b"`
  works at every rung — the ladder is about `file:line` citations into a remote, and a run at rung
  3 emitted a section with no `<a>` at all, pointers included.
- **What was searched, and what that search could not have found.** Where a search came up empty,
  say so and say what it was — unrecorded, absence and omission look identical, and the reviewer has
  to redo the work to tell which it was.

  **It is collapsed, and it is provenance rather than a claim.** `details.searched`, shut by
  default, holding `ul.sr-list` and one short *Out of reach* paragraph. It is the second component
  on the page a reader has to open, and it obeys the same hard rule as a source excerpt: **the page
  reads complete with it closed.** So a finding that rests on an empty result is *stated in the open
  prose* — "nothing else reads this column" — and the grep that establishes it goes inside. A run
  that leaves the finding to be inferred from an empty row has hidden it, not disclosed it.

  Why it was collapsed: open, it was the longest block in § 4, and a reviewer meeting a PR for the
  first time reads it as noise before they have any reason to care. Shut, it becomes what it always
  was — the thing you open when you want to check the page's work, which is the reviewer's own due
  diligence rather than a substitute for it.

  **One row per search, and a row is a command and a clause.** `<code>` for the command, then what
  it returned in a few words: *"two callers"*, *"no hits"*, *"every reader of the column by name"*.
  Not a sentence, and never three. The block used to be one run-on `<div>` and real pages filled it
  with paragraph-long re-explanations of entries the reader had just read two inches above — the
  same restatement § *One canonical home* forbids everywhere else, arriving as provenance. If a row
  needs a sentence to say *why* the result matters, that sentence belongs in the entry above it.

  *Out of reach* is one short paragraph, not a list: what a name-based pass cannot see at all —
  dynamic dispatch, a string-built template, another repository. Keep it, at both levels. It is the
  page telling the reviewer where their own checking is owed, which is the opposite of padding.

  **A recorded search has to reproduce the entries it is offered for.** This is the half that
  decays quietly. A run listed `rg -n 'account_type' app test` and claimed it returned every reader
  of the column — but the two guards it had just cited read the column through an enum predicate,
  `steward?`, which that pattern does not match. The search was real, the entries were right, and
  the provenance was still false. Where one pattern does not reach an entry, record the one that
  did; where a search's coverage has a hole, name the hole.

  **Record the working search as the search, not as a correction of one that failed.** A caveat the
  reader needs in order to re-run it — `git grep` defaults to basic regex, so an alternation needs
  `-E` and a word boundary needs `-P` — belongs on the line as a caveat. What an earlier pattern
  returned before you fixed it does not belong on the page at all. That is `SKILL.md` step 8's
  correction rule, and it surfaces here more than anywhere else, because a recorded search is where
  a run is most tempted to show its working.

The prose here explains what the diagram *implies*. It does not transcribe the diagram — if a paragraph
lists the same nodes and edges the figure already shows, delete the paragraph, not the figure.

Completeness in this section is about consequences, not paths. § 7 accounts for every file at
`--full` and `details.coverage-foot` does at `--brief`; **this section must not become a second
ledger**, which is the rule that removed its `Changed` list. What it owes the reader is that every
consequence the page found has a place in the affected list — as a pointer where a flow explained
it, as its own paragraph where nothing did.

## Section 5 · Cross-cutting consequences — only what genuinely spans flows

The test for inclusion: **does this reach more than one behaviour, or the whole repository?** If it
belongs to one flow, it goes in that flow. This section is not a recap, and "no meaningful
cross-cutting changes" is an acceptable and useful whole section.

- **Schema structure**, once for the diff: ER diagram of touched tables plus immediate neighbours only,
  never the whole schema, distinguishing new / modified / untouched-but-adjacent. Draw absent
  relationships where the absence is the point. Migration safety — reversible? locks a table? index
  added concurrently? `NOT NULL` plus default on an existing table? backfill in the same migration?
  destructive drop? rolling-deploy compatibility. Whether the committed schema matches what the
  migrations produce. A lifecycle diagram **only** if a status column, enum or state machine changed,
  with the `file:line` performing each transition — that is what reveals whether transitions are
  guarded at all.
- **Persistence invariants**, application beside database, because the gap between the two columns is
  reliably where the interesting problems live and is invisible in a diff touching only one:

  ```
  Application   Project#slug validates uniqueness          app/models/project.rb:22
  Database      no unique index on projects.slug           db/schema.rb:141
  ```
- **The authorization model** — the matrix of who can reach what, once, rather than per endpoint.
- **Deploy ordering**, if the two sides ship separately: what breaks in the window where one is updated
  and the other is not. Name the safe order.
- **Test infrastructure** that changes how other specs behave — factories, fixtures, shared helpers,
  global config. The question is not "is this tested?" but "does this change how every other test in
  the suite behaves?" A moved factory default can alter specs nobody in this PR opened. Tests for one
  behaviour belong to its flow.
- **Agentic and developer tooling** — `CLAUDE.md`, `AGENTS.md`, `.claude/`, skills, hooks, MCP config,
  CI scripts. No runtime impact and easy to wave through, which is exactly why it is here: these files
  change how every human *and every agent* works in the repository from here on.
- Whatever else genuinely spans: feature flags and their default state; background jobs (queue,
  retries, idempotency, ordering, failure mode, safe to run twice?); transaction and locking
  boundaries, and what sits outside the transaction; concurrency; caching; observability; environment
  variables — including **what happens when unset**, often the most useful row, because it describes
  how the feature degrades; new dependencies and why the version is pinned; external calls with
  timeout, retry and whether they block a request; performance and N+1; rate limits.

## Section 6 · Before approving — always

The reviewer's action list. Compact, and nothing here restates an explanation from above.

- **Questions for the author** — phrased as questions, and only those that *only the author* can
  answer. Distinct from uncertainty the page has already recorded: this is what no amount of reading
  will settle.
- **Validations worth running** — real commands against this repository: the actual rake task, the
  actual route, the actual factory. Plus setup and seeds, so a reviewer can get to a state where the
  per-flow validations can be run at all. One invented command spends the reader's trust in the whole
  page. This is where a runtime probe that needs seeded data belongs, beside the command that seeds
  it — a probe that answers on an empty database stays in the flow instead.
- **Test gaps** that matter, gathered from the flows in one place so a reviewer sees the shape of what
  is unproven.
- **Production and data checks**, if the change touches existing rows or deploy order.
- **Comprehension checkpoint** — **at most five** questions, rendered as `.checkpoint` tiles, that a reviewer
  should be able to answer before approving.

  The rule that keeps these from being a quiz: **answerable from the page, but not by copying one
  sentence out of it.** A question whose verbatim answer is a paragraph above is restatement wearing a
  question mark, and it is the single easiest way to bloat this page. A good one forces the reader to
  join two things the page established separately:

  ```
  1. Which query decides whether a project can still be selected now, and which callers reach it
     through the scope this PR did not change?
  2. What happens to a time entry submitted against a project archived between page load and submit?
  ```

  If the page cannot lead a reader to the answer at all, that is a gap in the page, not a challenge for
  the reader. Never a mechanical checklist (`[x] read the models`) — that is ceremony and teaches
  nothing.

## Section 7 · Coverage — always

Every changed file, the section covering it, its attention level (read / skim / mechanical), its group
(primary / supporting / secondary) and a deep link. Machine-generated from the diff by
`scripts/ledger-rows.sh`, gated by `scripts/coverage-gate.sh`. Doubles as a checklist for a reviewer
working through the whole diff.

**This is the only place the diff is inventoried at `--full`.** § 4 does not list paths — see
§ *The completeness invariant*. At `--brief` there is no § 7 and the same generated cells sit in
`details.coverage-foot` below the last section, unclassified.

**Each row carries its path in a `data-path` attribute** on the path cell:
`<div class="c" data-path="app/models/project.rb">`. That attribute is the whole interface to the gate — it is
what lets the check compare sets exactly instead of searching the rendered page, where `api/Gemfile`
matches inside `api/Gemfile.lock`. Omit it and the gate fails loudly, which is intended: a check that
cannot run must not report a pass.

**No findings here.** The group column is where the primary / supporting / secondary split lives, which
is all that split was ever worth — it tells a reviewer which changes they may hold as a separate mental
model. Neutrally framed: "appears unrelated to archival; review independently" is the whole register,
never a criticism of the author for bundling.

## Section 4 at brief · Reach & checks — replaces §§ 4–7

At `--brief` there is no § 5, § 6 or § 7. Sections 4 to 7 above are **one** section, whose spine is
§ 4 unchanged and whose tail is the part of §§ 5–7 a reviewer acts on. Take it from the assembled
block in `page-template.html` — it is a novel composition of five components that each came from a
different section, which is exactly the shape a run flattens when it is only described.

**The parts, in this order.** § 4's own two come first and keep their specs verbatim; the folded-in
material sits after them and must not dilute them.

| Part | From | At this level |
|---|---|---|
| The `.impact` panel, `.legend`, and the note under it | § 4 | Unchanged — same paths, same caps, same causal vocabulary |
| `Affected, not changed`, and the `details.searched` block | § 4 | Unchanged, pointers and all — collapsed at both levels |
| `<h3 id="crosscutting">` | § 5 | Rows, and only what is both flow-spanning **and** consequential. Omitted outright if nothing is |
| `<h3 id="approving">` | § 6 | Author questions and validations. **Last in the section** |

**What `--brief` drops, and what it does not.**

- **The ranking goes; the coverage does not.** `details.coverage-foot`, below the last section,
  carries the whole diff, so the page still accounts for every path and `coverage-gate.sh` still
  passes. What is lost is the attention level and the primary / supporting / secondary group — a
  ledger row's three judgements, which are ranking. § 3 is still where the page says where the
  attention goes, and it says it by what is on that list.

  **It is not part of this section, and that is deliberate.** The inventory used to be a `Changed`
  list inside it, which put 24 links in the middle of the material a reviewer came for. § 4 is about
  consequences at both levels; the foot disclosure is where the accounting goes.
- **No figures beyond the panel.** The ER fragment and the lifecycle belong to `--full`. Migration
  *safety* is a row here; schema *structure* is not.
- **No comprehension checkpoint.** It is a comprehension test rather than something to weigh before
  approving, and it is § 6's most expensive item to write well. `--full` is where it lives.
- **Test gaps are not gathered.** Each flow already carries its own in *relevant tests*; collecting
  them in one place was § 6's job, and there is no § 6.
- **Nothing about §§ 1–3 changes in kind**, and nothing here summarises § 2. A finding a flow
  explains is a pointer here, in the pointer shape § 4 defines, exactly as at `--full`. What does
  change across the whole page is how many words each part may spend — § *The brief budget*, which
  caps this section's rows at 30 words and its approving items at 18, and drops three concepts from
  the flows above without dropping anything they found.

**Three things the markup has to keep, because a check reads each of them.** Every one of these is
why the merge costs the eval harness almost nothing:

- `id="reach"` on the `<section>`, and `id="approving"` on the **last** `<h3>`.
  `evals/checks/reach.rb` takes its region from the first anchor to the next `<section`, and
  `before-approving.rb` from the second anchor onward. Lose them and `before-approving.rb` prints a
  SKIP, which reads as verified.
- The approving part is `<ul class="actions">`, **never** `<ol class="begin">`. An `ol.begin` inside
  the region is how `reach.rb` recognises the format's old ordering, where the reading list came
  before the flows it depends on, and it fails on one.
- The `<dt>` label stays `Affected, not changed`, verbatim — `evals/checks/searches.rb` **opens** its
  scope on that marker. An earlier version of this list also named `Changed` as load-bearing for that
  check; it never was. `searches.rb` treats a `Changed` `<dt>` only as a scope *reset*, and in the
  template's order it preceded `Affected`, so it never fired. The label is gone and the check is
  unaffected.

**Build state inside one section.** With one tail section rather than four, *pending* attaches to the
`<h3>` sub-parts rather than to the section — see § *Build state*.

---

## Deep links

Every `file:line` should be clickable, so a reader goes from claim to source in one click. There are
two URL forms, and **which one a citation uses is not a preference — it follows from the line.** A
line the diff contains links into the diff. A line the diff does not contain links into the file.

**Primary form — the diff anchor, for any line inside the diff:**

```
https://github.com/{owner}/{repo}/pull/{n}/files#diff-{sha256(path)}R{line}
https://github.com/{owner}/{repo}/pull/{n}/files#diff-{sha256(path)}L{line}
https://github.com/{owner}/{repo}/pull/{n}/files#diff-{sha256(path)}R{start}-R{end}
```

The fragment is the SHA-256 of the path *as the diff spells it* — for a rename, the new path. `R`
selects the right side of the hunk (the line after the change), `L` the left (the line before).

**A citation that names a range links a range**, which is the third form and not an optional
flourish. `redirect_by_attempt_state_test.exs:51-72` under an href ending at `R51` selects one line
of twenty-two, and the disagreement is invisible: the text promises a span, the link delivers a
line, and nothing on the page says which to believe. Repeat the side letter on both ends —
`R51-R72`, `L51-L72` — and keep both ends on the same side, because a range that starts left and
ends right is not addressable; cite the side the sentence is about. A renderer that does not honour
the range lands the reader at its start, which is exactly what the one-line anchor does today, so
the form costs nothing where it is not supported.

Keep writing `/pull/{n}/files`. GitHub redirects it to `/pull/{n}/changes` where the newer review
experience is enabled and carries the `#diff-` fragment across, so the path needs no updating and
the redirect is not a defect to chase.

Land the reviewer where the reviewing happens. A blob link takes them out of the diff and into the
file at head, where the change is invisible: the new code is there, but nothing marks what it
replaced, the hunk around it is gone, and so are the comment box and the *viewed* checkbox they are
working through. A diff anchor puts the cited line in front of them with its before and after side by
side, on the page they were going to type their comments into anyway. So every citation that *can* be
a diff anchor is one.

**One limitation, and it is a rule rather than a caveat** — see § *When the diff will not render*
below. GitHub keeps some files behind *Load diff*, and an anchor into one of those lands on the file
with the cited line nowhere in the page. That is the one case where a line inside the diff does not
get a diff anchor.

**Second form — the blob permalink, for the lines a diff cannot address:**

```
https://github.com/{owner}/{repo}/blob/{sha}/{path}#L{line}
https://github.com/{owner}/{repo}/blob/{sha}/{path}#L{start}-L{end}
```

This is not a fallback for when the first form is unavailable. It is the only form that can address
two kinds of line this page cites constantly, and both of them are the product:

- **Unchanged code — pin the head SHA.** A diff anchor addresses a line in a hunk and nothing else,
  and the *affected but unchanged* field consists of nothing but lines outside every hunk. No diff
  view can point at them, which is exactly why they are the part of the page a reviewer cannot get
  anywhere else.
- **Code as it was — pin the base SHA.** A line this change deleted, or a file it removed, does not
  exist at head: a blob permalink there 404s, or worse resolves to an unrelated line that happens to
  carry that number. Inside the diff, the `L` anchor covers this and is better. Outside it — when a
  sentence explains how a file behaved before, and the file is not in the diff — pin the base SHA and
  **say in the sentence that the citation is pre-change**, because a line number that is only true at
  some other commit is one the reader mis-reads without ever noticing.

Pin a SHA rather than a branch in either form, so links stay correct after later pushes.

### When the diff will not render

GitHub does not render every diff, and an anchor into one it withholds lands on a *Load diff* stub
with the cited line nowhere in the page. **A line inside the diff, in a file GitHub will not render,
takes the blob form** — head for a line that still exists, the diff's left side for one the change
removed. It is the only form that can address the line at all, and it is chosen per file, from a
verdict, not per citation from an impression: by eye every path looks renderable.

`scripts/diff-render.sh BASE HEAD` prints that verdict per path, and `--path <p>` answers about one.
It reads four signals — the repo's `.gitattributes` (`linguist-generated`, `-diff`), whether git
calls the file binary, a short list of lockfile names, and the size of the file's own diff against
GitHub's documented thresholds of **400 lines or 20 KB** to be loaded automatically and **20,000
lines or 500 KB** to be shown at all. Its header carries the source and what it cannot know. Two
of those are worth understanding here rather than in the script:

- **The size rule is not the whole rule.** A one-line change to a generated file is small by every
  measurement and GitHub collapses it regardless — a `db/structure.sql` under
  `linguist-generated=true`, a lockfile bumping one version. Those are ordinary Rails citations, and
  they are the ones a size threshold alone waves through.
- **Being wrong is asymmetric, so lean towards the diff anchor.** A blob link where the diff would
  have rendered still lands on the line and only loses the red and the green; an anchor into a
  collapsed file loses the line and tells the reader nothing. But the anchor is what the reviewer
  wants when it works — the comment box and the *viewed* checkbox are on that page — so the verdict
  decides, and prose does not hedge it.

**The excerpt is what carries the loss, and for these files it is the `--diff` variant.** A blob link
shows the new line with nothing marking what it replaced, which is precisely what the reader needed;
`excerpt.sh --diff` beside the claim shows the hunk instead. So a collapsed file behaves like a local
rung 3: its citations earn more excerpt than the budget would otherwise allow, for the reason
§ *Choosing a mode* gives at rungs 3 and 4 — when the link gives less, the page carries more. The
budget itself stays where it is owned; see § *Source excerpts*.

Three things not to do. **Do not emit both links** for one citation: one citation, one href, and a
second link beside it is ornament the format keeps refusing. **Do not put it on the page as a
notice** — no badge, no "GitHub cannot render this" caption; the reader is not being told about
GitHub, they are being taken to the code. And **do not move the page's rung**: the rung is a property
of the run, this is a property of a file, and the two do not interact.

Two limits belong to the whole diff rather than to any path — **300 files** in a diff and **1 MB** of
diff data — and past either, GitHub withholds files that are individually small. `diff-render.sh`
reports both in its trailing summary. Say it once in prose where the page accounts for the diff, the
way any other stated limit is said; do not guess per citation which paths fell off the end.

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
| 1 | GitHub PR exists | Diff anchors into `pull/{n}/files` for lines in the diff, blob permalinks for the rest |
| 2 | No PR, GitHub remote, **head SHA reachable on a remote** | Diff anchors into `compare/{base}...{head}` if the base SHA is reachable too, blob permalinks for the rest |
| 3 | GitHub remote, **head SHA not pushed** | Plain text, plus the note below |
| 4 | No GitHub remote, or no remote at all | Plain text |

Resolve remote, PR, and reachability once up front and pick one rung; never re-decide the rung per
citation. Choosing *between the two forms* is different, and is decided per citation because it is
not a judgement: ask whether the line is in a hunk.

Rung 2 has no PR page, but a pushed head still has a diff page —
`https://github.com/{owner}/{repo}/compare/{base_sha}...{head_sha}`, whose line anchors take the same
`#diff-{sha256(path)}R{line}` form. It needs both SHAs on the remote, so check the base the same way
you checked the head; if it is not there, rung 2 is blob permalinks throughout.

At rung 3, say so once in the masthead rather than leaving the reader wondering why nothing is
clickable — one line is enough: *"Citations are plain text: this branch is not pushed, so there is no
permalink target."* Do not emit hrefs you know are dead, and do not silently fall back to linking
against the default branch, where the cited line numbers will not match.

**Rungs 3 and 4 are where source excerpts matter most.** With nothing clickable, a collapsed excerpt
is the only way a reader can follow a citation without leaving the page — so on those rungs the
excerpt budget goes *up*, not down. This is the opposite of the instinct to do less when the tooling
gives you less. See § *Source excerpts*.

A force-push after publishing can also orphan a rung-1 or rung-2 SHA, and it rewrites the diff a
rung-1 anchor points into: the fragment survives, the line numbers behind it may not. GitHub keeps
orphaned commits reachable by SHA for a while, so this degrades slowly rather than breaking at once —
but it is a reason to prefer republishing the page over treating an old URL as permanent.
