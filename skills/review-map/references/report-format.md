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
| **brief** | `--brief`, or no flag | §§ 1–3 as written below. §§ 4–7 collapse into **one** section, § *Section 4 at brief* |
| **full** | `--full` | The seven sections below, exactly as written |
| **review** | `--review` | Full, plus a code-review pass threaded through it. **Not implemented** — the skill stops and says so |

**The level changes what the tail of the page is; it never changes what a section teaches.**
§§ 1–3 are identical at both levels — same depth rules, same excerpt budget, same review unit, same
rules about what a flow owns. The behaviour flows are the product, and a level that thinned them
would be selling the thing the page exists for. What `--brief` does is decline to spend four section
shells on material that is often one screen: it merges, it drops the ranking, and it drops the
comprehension checkpoint. It does not summarise § 2.

So the two things that scale a page are **orthogonal**, and confusing them is the way to get this
wrong: § *Depth rules* scales each section by what the diff puts into it, at either level, and the
level decides how many sections there are to scale.

**One thing is level-independent, deliberately:** every path in the diff still appears in the page,
and the coverage gate still runs. § *The completeness invariant* says why, and what changes is only
which component carries the paths.

**Effort is not a level, and this file has nothing else to say about it.** `--effort normal` and
`--effort high` decide how hard the run works to be right — at `high`, `SKILL.md` step 8 sends an
adversarial pass at the behaviour flows before the page is finished. That produces no section, no
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

## Contents

**Primitives and rules** — read these before writing anything.

- *Detail levels* — brief, full and review, and what the level does and does not change
- *The review unit* — the seven fields every meaningful change gets
- *Evidence tiers* — five tiers, and the rule that only four of them get a label
- *Framework anchors* — the doc link, the runtime probe, the primer callout a link escalates
  into, and why none of the three is evidence
- *Source excerpts* — the collapsed code quotation, which is also the page's shortest way to say
  what code does, and the syntax tint that unchanged code gets and a hunk does not
- *One canonical home* — every fact explained once, referenced from everywhere else
- *Depth rules* — how much treatment a section earns, and the diagram budget
- *The completeness invariant* — why every diff path appears, and why the check is one-directional
- *Build state* — the banner and pending markers that keep a staged page honest while it fills in

**The seven sections, in default order** — each with what triggers it, and what becomes of it at
`--brief`.

| | Section | Appears | At `--brief` | Owns |
|---|---|---|---|---|
| 1 | What changed | always | unchanged | Intent, scope, the metric strip, the use cases named |
| 2 | Behaviour flows | the bulk | unchanged | One flow per behaviour, canonically — the mechanism, and the findings inside it |
| 3 | Start here | always | unchanged | One prioritized list: where to go in the code, in the order to go there |
| 4 | Blast radius | always | **the merged section** | Where consequences leave the diff, seen across every flow at once |
| 5 | Cross-cutting consequences | anything genuinely spans flows | folded in, consequential rows only | Schema structure, authorization, jobs, deploy order, test infrastructure |
| 6 | Before approving | always | folded in, questions and validations | Author questions, validations, test gaps, a ≤5-question checkpoint |
| 7 | Coverage | always | folded in as paths, unclassified | The ledger. No findings |

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
  nearly correct. `evals/checks/behaviour-flows.sh` therefore checks the *pairing* — one `.mech` per
  `dl.rows` — and counts field labels inside grids rather than inside units, because a flattened flow
  keeps its `.mech` and a census taken over units counts loose fields as housed.
- Three of the fields may carry a collapsed source excerpt: *implementation*, *affected but unchanged*
  and *things to understand*. See § *Source excerpts* for the budget and for the rule that the field
  still has to read complete with the excerpt closed.

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
`evals/checks/rails-anchors.sh` encodes both: every doc link must carry a version segment in either
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

**A primer is gated on its doc link, so a closed catalogue means no primers for that stack.** It is
what a link escalates *into*, and `evals/checks/rails-anchors.sh` fails one that carries none — so the
two rules meeting leave no room: while `elixir-docs.md` § *Version* withholds every link, a Phoenix
page carries no primer at all. Explain the mechanism in the flow's own prose against its `file:line`
and propose a probe, which is the anchor that stack has. Narrower, not wrong — the same trade the
withhold already makes, arriving at the heaviest component rather than the lightest.

When that catalogue opens, **Elixir takes `.primer--lib`**, never the branded variant. Ecto, Phoenix
and LiveView are libraries in exactly the sense the variant was built for: the mark on a primer says
who wrote the thing it explains, and the Rails Foundation did not write Ecto.

**It carries a `file:line` from this repository, like every other doc link.** Two paragraphs of
framework prose read as self-justifying, which is exactly why the rule is easiest to lose here. The
citation names the line the callout was earned by, and `evals/checks/rails-anchors.sh` judges the
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
`evals/checks/rails-anchors.sh` enforces both halves.

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
  touch"* — which is where it can be said precisely anyway. `evals/checks/excerpts.sh` holds both
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
  block shut had nothing to click. Judge the rule field by field, not page-wide. `check.sh` cannot
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
| A high-value finding | The flow it belongs to | *Start here*, as one prioritized entry; *Blast radius*, in one clause |
| Unchanged code one flow gives new meaning to | That flow's *affected but unchanged* | *Blast radius*, as a named pointer |
| Unchanged code no single flow owns | *Blast radius* | The flows it touches, in one clause |
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

The one place a second is routinely earned is persistence: an ER diagram shows *structure*, a
lifecycle diagram shows *behaviour over time*, and no single figure shows both. If the diff adds a
status column or state machine on top of new tables, draw both. Elsewhere, if you find yourself
wanting a second diagram, the honest question is whether the first one is doing its job — and a
transition table with a `file:line` per row is often better than a second figure anyway. Never exceed
two in one section.

**Four kinds, and which section each belongs to — but only two are SVG.** Two of these outgrew
being drawings: what they carry is membership of a set and order along a chain, and a component
shows both as well as geometry did, reflows on a phone, and cannot be drawn wrong. The two that
stayed SVG are the ones where the information genuinely *is* geometry.

| Kind | Rendered as | Home |
|---|---|---|
| Blast radius | `.blast` box grid + `.legend` | § 4, on almost every PR |
| Boundary chain | `.pipe` numbered spine | § 2, inside the flow that owns the field, never a section of its own |
| ER fragment | **SVG**, from the catalogue | § 5, if the schema moved |
| Lifecycle | **SVG**, from the catalogue | § 5, and only if a status column, enum or state machine changed |

The last row is the one that gets abused: a nullable timestamp is not a state machine, and drawing one
invents states the code does not have.

The SVG layouts are worked out in `page-template.html` — complete, to scale, and to be filled in
rather than re-derived, because a layout invented per run makes two pages from this skill
incomparable for no gain.

**What the box grid cannot do, and what to do instead.** `.blast` shows two sets — solid border
changed, dashed unchanged-and-affected — and convergence, by spanning a box across columns. It
cannot show a *directed edge*. So when the finding is "the shared error code stops being produced at
this hop", adjacency will not say it: put it in the note under the panel, in words. The legend is not
optional either — a dashed box with nothing explaining it reads as *deleted*, which is the opposite
of *unchanged, and therefore worth reading*.

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

**The detail level is a different axis, and the two multiply rather than substitute.** Everything
above applies unchanged at `--brief`; what the level decides is how many sections there are to weigh,
not how heavily each one is weighed. Two consequences for diagrams specifically: `--brief` draws no
§ 5 figures at all (no ER fragment, no lifecycle — migration safety is a row there), so its merged
tail section holds the `.blast` panel and nothing else that could compete for the budget. And a run
at `--brief` must not read the shorter page as licence to skimp on a flow's diagram, which is the
one figure § 2 earns.

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
§ 7's classified ledger. At `--brief` they live in the merged section's `Changed` list, generated by
`ledger-rows.sh --paths-only` — one `.gt-paths` cell each, still carrying `data-path`, so
`coverage-gate.sh` greps them page-wide and asserts the same equality it always did. That is the whole
reason the brief carrier is a grid cell rather than a list item, and it is why a shorter page is
legitimate rather than a silent gap: what `--brief` declines to do is *classify* the diff, never
account for it. `data-path` stays reserved to whichever of the two carries it — an excerpt using it
would register as a surplus path at either level.

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
reader who finds a blast panel and no *before approving* has to be able to tell that one is coming
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
comes before the route through the code and before the blast radius because both of those are easier
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
  that the two are rows and never one sentence.
- **The path**, as `.pipe`: UI → request → controller → operation → model → column, and the
  response path back if it carries anything interesting. The numbered spine fills its terminal node,
  so put the thing the chain arrives at last. In a Phoenix LiveView flow the same chain is
  event in `.heex` → `handle_event/3` → context → changeset → `Repo` → column, with the return leg
  assigns → re-render → diff over the socket.
- **The field crossing the boundary**, if it does, as a second chain — serializer → JSON → type → hook →
  component. Following one field teaches more than reviewing both sides as separate file trees. The
  mismatches worth hunting: nullable backend field typed non-null, backend enum value missing from the
  frontend union, a new error status nothing handles, a required param the client never sends. If the
  client is in another repository or simply absent, say which and build the backend half only — do not
  guess at code you cannot read.

  **A LiveView app has this chain too, and it is a different seam.** There is no serializer and no
  generated type, but there is still a contract with no compiler behind it: the `phx-*` attribute value
  and the `handle_event/3` clause that answers it, a form input name and the changeset's `cast` list,
  `stream_insert` versus an assign the template still reads, and `pushEvent` from a `phx-hook`. Build
  the second chain from those instead. The mismatches worth hunting are the same shape — an event with
  no clause (which crashes the process rather than rendering wrong), an input the changeset drops, a
  broadcast payload no `handle_info` matches.
- **The endpoint** it goes through, if the diff changed one: params with required/optional and where
  they are coerced, a real success body, the **full** error list with statuses, and a side-effects row
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
  none; § *Framework anchors* owns that and everything else about it.
- **A diagram**, where one shows a mechanism a list cannot. Layout from the catalogue in
  `page-template.html`; which kind and how many, per § *Depth rules*.
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
- **What remains uncertain**, if anything, with its evidence tier and what would settle it.
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

## Section 4 · Blast radius — always

**This spec has two consumers.** It is § 4 at `--full`, and it is the spine of the merged section at
`--brief` — so a change here lands in both, and § *Section 4 at brief* says only what differs. Where
consequences extend beyond the diff. This is the section a diff cannot produce at all, and by
this point in the page it is a **second pass**: the reader has been through the flows one at a time,
and now sees the same change as one system, with the edges that leave it.

- **Blast-radius panel** — the primary flow end to end, secondary effects beside it, as a `.blast`
  box grid. Changed boxes solid (`.bx-on`), affected-but-unchanged dashed (`.bx-off`), `.legend`
  required. Span a box across columns to show convergence. The one figure that earns its place on
  almost every PR. Arriving after § 2, it is a synthesis view: it shows flows the page explained
  separately reaching the same unchanged code. It is not an SVG — see § *Depth rules* for why, and
  for the one thing adjacency cannot say that the note underneath has to.
- **Changed vs potentially affected**, two lists across the whole diff, stacked and each the full
  measure — not columns. Both run on paths and inline code, which wrap mid-token at half width, and
  the affected list carries the excerpts. They are read one after the other, not compared row against
  row. The second is the point: every entry carries a citation and a clause on *why* it is affected.
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

Completeness in this section is about consequences, not paths. § 7 is what accounts for every file,
and this must not become a second ledger. What it owes the reader is that every consequence the page
found has a place in the affected column — as a pointer where a flow explained it, as its own
paragraph where nothing did.

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

**Each row carries its path in a `data-path` attribute** on the path cell:
`<div class="c" data-path="app/models/project.rb">`. That attribute is the whole interface to the gate — it is
what lets the check compare sets exactly instead of searching the rendered page, where `api/Gemfile`
matches inside `api/Gemfile.lock`. Omit it and the gate fails loudly, which is intended: a check that
cannot run must not report a pass.

**No findings here.** The group column is where the primary / supporting / secondary split lives, which
is all that split was ever worth — it tells a reviewer which changes they may hold as a separate mental
model. Neutrally framed: "appears unrelated to archival; review independently" is the whole register,
never a criticism of the author for bundling.

## Section 4 at brief · Blast radius and what to check — replaces §§ 4–7

At `--brief` there is no § 5, § 6 or § 7. Sections 4 to 7 above are **one** section, whose spine is
§ 4 unchanged and whose tail is the part of §§ 5–7 a reviewer acts on. Take it from the assembled
block in `page-template.html` — it is a novel composition of five components that each came from a
different section, which is exactly the shape a run flattens when it is only described.

**The parts, in this order.** § 4's own three come first and keep their specs verbatim; the folded-in
material sits after them and must not dilute them.

| Part | From | At this level |
|---|---|---|
| The `.blast` panel, `.legend`, and the note under it | § 4 | Unchanged, including what adjacency cannot say |
| `Changed` | § 7 | **Every path in the diff**, generated by `ledger-rows.sh --paths-only`, as `.gt-paths` cells |
| `Affected, not changed`, and the `details.searched` block | § 4 | Unchanged, pointers and all — collapsed at both levels |
| `<h3 id="crosscutting">` | § 5 | Rows, and only what is both flow-spanning **and** consequential. Omitted outright if nothing is |
| `<h3 id="approving">` | § 6 | Author questions and validations. **Last in the section** |

**What `--brief` drops, and what it does not.**

- **The ranking goes; the coverage does not.** `Changed` carries the whole diff, so the section still
  accounts for every path and `coverage-gate.sh` still passes. What is lost is the attention level and
  the primary / supporting / secondary group — a ledger row's three judgements, which are ranking. § 3
  is still where the page says where the attention goes, and it says it by what is on that list.
- **No figures beyond the panel.** The ER fragment and the lifecycle belong to `--full`. Migration
  *safety* is a row here; schema *structure* is not.
- **No comprehension checkpoint.** It is a comprehension test rather than something to weigh before
  approving, and it is § 6's most expensive item to write well. `--full` is where it lives.
- **Test gaps are not gathered.** Each flow already carries its own in *relevant tests*; collecting
  them in one place was § 6's job, and there is no § 6.
- **Nothing about §§ 1–3 changes**, and nothing here summarises § 2. A finding a flow explains is a
  pointer here, in the pointer shape § 4 defines, exactly as at `--full`.

**Three things the markup has to keep, because a check reads each of them.** Every one of these is
why the merge costs the eval harness almost nothing:

- `id="blast"` on the `<section>`, and `id="approving"` on the **last** `<h3>`.
  `evals/checks/blast-radius.sh` takes its region from the first anchor to the next `<section`, and
  `before-approving.sh` from the second anchor onward. Lose them and `before-approving.sh` prints a
  SKIP, which reads as verified.
- The approving part is `<ul class="actions">`, **never** `<ol class="begin">`. An `ol.begin` inside
  the region is how `blast-radius.sh` recognises the format's old ordering, where the reading list
  came before the flows it depends on, and it fails on one.
- The two `<dt>` labels stay `Changed` and `Affected, not changed`, verbatim. `evals/checks/searches.sh`
  scopes by those markers rather than by any section id.

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
```

The fragment is the SHA-256 of the path *as the diff spells it* — for a rename, the new path. `R`
selects the right side of the hunk (the line after the change), `L` the left (the line before).

Land the reviewer where the reviewing happens. A blob link takes them out of the diff and into the
file at head, where the change is invisible: the new code is there, but nothing marks what it
replaced, the hunk around it is gone, and so are the comment box and the *viewed* checkbox they are
working through. A diff anchor puts the cited line in front of them with its before and after side by
side, on the page they were going to type their comments into anyway. So every citation that *can* be
a diff anchor is one.

**One limitation, and it degrades gently.** GitHub loads a large Files tab incrementally and keeps
very large or generated files behind *Load diff*, so an anchor into one of those lands on the right
diff but not on the line. That is a worse landing, not a dead link, and it is no reason to go back to
blob links — it is a reason the collapsed excerpt beside the claim keeps earning its place.

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
