# The report format

What sections exist, when each appears, how deep it goes, and the primitives the page is built from —
the review checkpoint, the chain, the evidence tier, the source excerpt, and the rule that each fact
has one home.

**Five sections, and the second one is the product.** *What changed* orients, *What needs your
attention* carries three to five judgments the reviewer has to make, *Read the code in this order*
routes them into the code, *Impact outside the diff* shows what the change reaches outside the lines
it touched, and a collapsed evidence foot accounts for the rest. A section the diff does not earn is
**omitted**, never filled with generic content and never left as an "N/A" placeholder.

**The page is short because of how it is organised, not because anything was cut.** The run traces
consumers across the whole diff, reads the tests, follows values across the boundary and attacks its
own conclusions; what reaches the reader is the part they have to act on. Every section below is a
place where a distinct kind of thing lives exactly once. If you find yourself explaining something a
second time, the structure is telling you the explanation is in the wrong section — move it, do not
duplicate it.

---

## One page shape

There is one page and no flag chooses it. `--full` and `--review` stop the run as not implemented in
this version; `--brief` and `--light` are accepted and change nothing. `SKILL.md` § *Two levels are
not implemented in this version* has the wording, and § *A future full mode* at the foot of this file
records what a later level would pick back up.

What the page carries is not a length setting. It is the answer to one question — *what does a
competent reviewer have to judge before approving this, and where do they look to judge it?* — and
everything in this file is in service of answering that in as few words as the answer needs.

**Effort is not a level, and this file has nothing else to say about it.** `--effort high` (the
default) and `--effort low` decide how hard the run works to be right — at `high`, `SKILL.md` step 6
sends an adversarial pass at the run's own analysis notes before any of it reaches the page, and
step 8 folds the challenges in. That produces no section, no marker, no chip and no sentence: the page
is the same *shape*, built to the same specs, at either effort, and a reader cannot tell which
produced the page in front of them. Deliberately so. A page that announced having been checked would
be asserting the assurance the format refuses to give — § *Evidence tiers* labels how a claim is
known, never how hard someone looked, and *findings are a sample, not an audit* is the rule that
would break first.

**The stack is not a level either, and it is invisible for the same reason.** Rails and Phoenix change
which lens file and which catalogue the run reads (`SKILL.md` step 2), what a chain's nodes are
called, and what a probe's command looks like. They change **no section, no field, no tier, no
component and no marker.** There is no stack chip and no "reviewed as a Phoenix app" line: two pages of
equivalent changes in the two stacks differ in their content and not in their shape. What the stack is
belongs in the sentences that cite this repository, which say it by naming real files.

---

## Contents

**Primitives and rules** — read these before writing anything.

- *One page shape* — above: no level, and what effort and stack do not change
- *The review checkpoint* — the page's primitive: one judgment, framed as a question
- *Chains* — the one figure vocabulary, in two places with two jobs
- *Evidence tiers* — five tiers, and the rule that only four of them get a label
- *Framework anchors* — the doc link and the runtime probe, and why neither is evidence
- *Source excerpts* — the collapsed code quotation, which is also the page's shortest way to say
  what code does, and the syntax tint that unchanged code gets and a hunk does not
- *Impact paths* — section 04's figure: directed chains from changed code, through the unchanged code
  that gives the change its consequence, to an observable behaviour
- *One canonical home* — every fact explained once, referenced from everywhere else
- *The agenda budget* — how much prose each part may spend, what it never counts, and the one number
  it never touches
- *The completeness invariant* — why every diff path appears, and why the check is one-directional
- *What was searched* — the collapsed record, and why the finding is never left inside it
- *Build state* — the banner and pending markers that keep a staged page honest while it fills in
- *A future full mode* — what this page put down, and where the rules would return

**The five sections, in order** — each with what triggers it.

| | Section | Appears | Owns |
|---|---|---|---|
| 01 | What changed | always | The masthead, the semantic delta, intent and its tier |
| 02 | What needs your attention | always | Three to five checkpoints, and the one sampling caveat |
| 03 | Read the code in this order | always | The route through the code: 3–7 stops, each pointing at a checkpoint |
| 04 | Impact outside the diff | when a consequence crosses into unchanged code | 1–3 impact paths, and the affected entries they run through |
| 05 | Evidence & diff coverage | always, collapsed | The inventory, the recorded searches, the affected code no checkpoint turns on. No findings |

The order is the reviewer's path, and each section assumes the ones before it. § 02 teaches the
judgments; § 03 is the moment the reviewer opens the code, holding §§ 01–02; § 04 is a second pass over
the same change through one lens, so it can point at a checkpoint instead of re-explaining it. § 05 is
not a section at all — no number, no rail entry, shut — and it is the only part of the page a reader
is never expected to open.

**Citations** — *Deep links*, the two URL forms and which lines each one can address, and *Choosing a
mode*, the four-rung degradation ladder. Settle the rung once, in step 1 of the procedure; the form
then follows the line, not the run's taste. A documentation link is not one of those forms and the
ladder does not reach it: see *Framework anchors*, and take the URL from the catalogue the stack
selected — `references/rails-docs.md` or `references/elixir-docs.md`.

---

## The review checkpoint

The page's primitive. Where the reviewer's attention goes is expressed as three to five of these
under *What needs your attention*, and each is **one judgment** the reviewer has to make — framed as
a question, explained in a few sentences, and anchored to the exact lines that let them make it.

It replaced a seven-field review unit, and the reason is worth keeping because the unit looked
thorough. Every meaningful change got the same grid — implementation, tests, affected code, things to
understand, validation, questions — whether or not each row had anything to say, and a reviewer read
seven labelled rows per flow to find the one that mattered. The fields were right as *analysis*; as a
reading obligation they were a form. So the fields are now facets a checkpoint draws on when they
change the judgment, and the page carries the judgment.

**The shape, in this order:**

```html
<section class="cp" id="cp-a">
  <h3>Does the new Project filter preserve the intended scope?</h3>
  <p>Two to four sentences: what changed here, what follows from it, and what the reviewer has
     to decide <span class="tier">from unchanged code</span>.</p>
  <figure class="chain">…</figure>                       <!-- optional: mechanism inside the change -->
  <ul class="lookat">
    <li><a class="path" href="…">app/models/project.rb:41-52</a>
        <span>the guard, and the branch the filter now skips</span>
        <details class="excerpt excerpt--diff">…</details></li>
  </ul>
  <p class="open"><b>Open question</b> Whether archived projects should still appear in
     historical reports; no test pins it.</p>            <!-- optional -->
</section>
```

- **The question, as the `h3`.** A judgment, never a category. *Controller changes* names a
  directory; *Does the new filter preserve the intended scope?* names something a reviewer can get
  wrong. The test: could a reviewer answer it by looking at the code? If the honest answer is "there
  is nothing to decide here", it is an explanation and belongs in a sentence somewhere else.
- **The explanation, one `<p>`.** Meaning, consequence, judgment — in that order and in two to four
  sentences. What the change does here, what follows from it in code the reader may not have opened,
  and what they are being asked to decide. Evidence tiers sit against the clause they qualify. This
  paragraph is the checkpoint's canonical home for its finding; every other mention on the page is a
  clause pointing here.
- **The chain, `figure.chain`, optional.** Earned when the judgment turns on a mechanism the reader
  cannot hold from prose — a guard order, a value derived across three or more hops, a request path
  with a branch. It shows mechanism **inside the change** and holds no affected-unchanged node;
  § *Chains* owns the component and the rule that sends a crossing chain to *Impact outside the
  diff*. A chain followed by a paragraph that names each node again is the defect: the figure says
  how the value gets there, the paragraph says what to judge about it.
- **Look at, `ul.lookat`, one to four entries.** Each is a deep link and a clause saying what to see
  there. An entry with no clause is a bare citation, and a bare citation is a location the reader has
  to open to learn why it is on the list — the deleted-field defect wearing a link. A collapsed
  excerpt sits beside the entry it confirms when the citation is load-bearing for the judgment;
  § *Source excerpts* owns the budget. The entry has to read complete with the block shut.
- **Open question, `p.open`, optional.** One line, labelled **Open question** and nothing else. What
  only the author can settle, or what the run could not establish and what would settle it. The label
  is fixed: *Watch* and *Blocking* are severity by another name, and `evals/checks/page-invariants.rb`
  warns on both.

**Facets, not rows.** Tests appear inside a checkpoint when they change how the reviewer judges it —
*"the spec at `:88` pins the admin branch and leaves the invitee branch open"* is part of the
judgment; a list of the specs that touch the file is not. A validation command or a `pre.probe`
appears when running it would settle the question, after the explanation, with any setup beside it.
An author question appears as the open line. Anything that would have been a row with nothing in it is
not written, and no label is left behind to say so.

**Ordered by consequence if misunderstood, and the order is not a scale.** The first checkpoint is the
one a reviewer would most regret getting wrong; the last is still a judgment or it would not be on the
page. No severity word, no *high* or *low*, no *blocking*, no *watch*, no chip. The rail and the
reading path refer to a checkpoint by its question, and section 02's intro says in one sentence that
the order is the order to think about them.

**Three to five, fewer for a small PR.** A sixth is merged or named in a clause of the nearest
checkpoint; `SKILL.md` step 7e has the selection rule. A finding that does not become a checkpoint
keeps its entry in *Impact outside the diff* or in the evidence foot, so nothing found is lost — only
its promotion to a judgment, and the caveat under the heading is what makes that honest.

**The sampling caveat lives here, once.** *These are what this pass surfaced, not an audit: repeated
runs over the same diff surface overlapping but different sets.* Under the section heading, before the
first checkpoint, and nowhere else on the page.

**Where checkpoints come from.** Most come from the flows step 6 clustered: a scope whose population
changed, a default a consumer does not handle, a guard whose order moved. Some hide outside any one
flow, and a flow-by-flow reading is exactly what misses them. Ask about each of these at `SKILL.md`
step 7b:

- **Migration safety** — reversible, locks a table, `NOT NULL` with a default on an existing table, a
  backfill in the same migration, a destructive drop, rolling-deploy compatibility, and whether the
  committed schema matches what the migrations produce.
- **An application invariant with no database counterpart** — `validates uniqueness` at
  `project.rb:22` and no unique index at `schema.rb:141`. The gap between the two is invisible in a
  diff that touches one of them.
- **The authorization model** — who can now reach what, across every endpoint the change touches.
- **Deploy ordering**, when two sides ship separately: what breaks in the window.
- **Test infrastructure that changes how other specs behave** — a moved factory default alters specs
  nobody opened.
- **Agentic and developer tooling** — `CLAUDE.md`, hooks, MCP config, CI scripts. No runtime impact
  and easy to wave through, which is why it is on this list.
- **Background jobs** — safe to run twice, in-flight jobs carrying the old argument shape. Feature
  flags and their default. An environment variable, and **what happens when it is unset**. External
  calls, and whether they block a request. Transaction boundaries, and what sits outside them.

Each is a checkpoint only if it is a judgment for *this* diff. The list is a prompt, not a form.

**Assembled whole in `page-template.html`**, one checkpoint with every optional part present, one
without, and a pending stub. Copy the composition rather than the description: a checkpoint is
borderless, so one that spills its *Look at* list beside the `<section>` rather than inside it looks
very nearly right.

---

## Chains

The page's one figure vocabulary, and its second figure primitive beside `dl.ba`. A chain is a
vertical list of labelled nodes where every node past the first carries the relation that reaches it.
It appears in two places with two jobs: as `figure.impact` in *Impact outside the diff*, where
§ *Impact paths* owns the lanes, the card and the caps; and as `figure.chain` inside a checkpoint.
This section owns what the two share, and the rule that decides which one a given chain is.

**Why a component and nothing else.** The page used to carry four SVG layouts — a boundary chain, a
guard fork, an ER fragment and a lifecycle — worked out to scale in the template so a run filled in
text rather than deriving geometry. They cost more than they carried. An `<svg>` is the most expensive
thing on a page to type, so the characteristic failure was never a wrong drawing but **no drawing**:
two real pages published nine flows and zero figures with the layouts sitting readable in the template
the whole time. A component has the opposite failure profile. It reflows on a phone, has no canvas to
overflow, and cannot be drawn wrong — the only thing a run can get wrong is whether the edges are
true, which is the thing worth its attention. So there is no `<svg>` on this page at all, and a run
that wants to draw a fork, a schema or a state machine writes the chain that shows the one path the
judgment turns on and says the rest in the explanation.

**The markup is § *Impact paths*'s `ol.ip-path`**, with four node kinds:

| Kind | Class | Means | Legal in |
|---|---|---|---|
| Changed by this PR | `.ip-n.ip-chg` | code the diff touches | both figures |
| Affected, not changed | `.ip-n.ip-aff` | unchanged code whose meaning the change altered — a finding | `figure.impact` only |
| Step | `.ip-n.ip-step` | a hop the value passes through that claims nothing about the diff — a framework layer, an unchanged pass-through, the browser | `figure.chain` only |
| Outcome | `.ip-n.ip-out` | what a user or an operator sees; last, exactly once | both figures |

Every node past the first carries `<span class="ip-rel"><i></i>verb</span>`, from the causal
vocabulary in § *Impact paths* — one list for both figures, extended in that section and in
`evals/checks/impact-paths.rb`'s `CAUSAL` together. A label reads from the node above to the node
below. `<b>` is an identifier, `.ip-d` a few words, and no `file:line` sits inside a figure: citations
belong to the *Look at* list or to the affected entries beside the panel.

**The canonical-home rule between the two figures.** A chain that crosses from changed code into
unchanged code whose meaning the change altered **is an impact path**: it lives in *Impact outside the
diff*, once, and a checkpoint that turns on it says so in a clause — *"the path from `archived_at` to
the selector is drawn in Impact"* — and does not redraw it. A chain drawn inside a checkpoint shows
mechanism **within the change**: the request path, how a value is derived, the order guards run in. It
therefore contains no `.ip-aff`.

That is the whole test, and it is mechanical. An `.ip-aff` inside `figure.chain` is a chain in the
wrong section; an `.ip-step` inside `figure.impact` is a hop that carried nothing, so collapse it. The
rule exists because the alternative is the same consequence drawn twice at conversational distance,
which reads as thoroughness.

**A checkpoint chain has no lanes, no legend and no card header.** It is one column; the kinds are
told apart by border, and the `figcaption` says in one line what the chain shows. Three to five nodes:
fewer is a sentence, more is listing layers instead of following a value — a fetch wrapper that passes
a field through unaltered is not a hop, and collapsing to the hops where the value changes shape, is
renamed or is dropped is the honest chain. At most one per checkpoint, and most checkpoints earn none.

**State the trigger affirmatively.** "Most earn none" was once said of a figure whose trigger was
actually common, and the section that held it drew nothing for two whole pages as a result. So: **if the explanation would
otherwise have to name three hops in sequence, draw them.** The two excuses that hold are that you
could not read one end of the path, and that nothing interesting happens at any hop.

**A chain has one successor per node, so it cannot draw a fork.** Where the change makes two request
classes part at a guard, draw the diverted class's chain — the class the finding is about, ending
where it lands — and say in the explanation where the other class goes. If both destinations are
judgments, that is two checkpoints. Drawing a population the code does not distinguish is worse than
drawing neither.

**Labels, not sentences.** A node carries an identifier and a few words; a relation carries a verb.
Searches, caveats and conclusions go in the explanation or the `figcaption`, never in a node — a chain
of clauses is not a figure, and it is the shape the box grid this component replaced kept collapsing
into. **A figure that restates a list is worse than no figure**, because it costs the reader time and
teaches nothing.

**Diagram and prose have different jobs.** The chain shows mechanism; the explanation states the
judgment. A paragraph that walks the chain — *first the controller reads the param, then it passes it
to the scope, then…* — after the chain has shown exactly that is the defect this section exists to
name. It doubles the length, teaches nothing twice, and it is the form a run reaches for when it is
unsure the figure landed. If the chain needs narrating, the chain is wrong; if the paragraph needs the
chain to be understood, the paragraph is.

**`dl.ba` is the other figure** — two rows, *Before* the state that no longer holds and *After* the
one that does. It appears in *What changed* when a workflow fundamentally changes, and nowhere else.
§ *Section 1* has its rule.

---

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

Two ways to anchor a claim that rests on the framework behaving as the framework rather than on
anything this diff contains. Neither is an evidence tier, and neither changes one.

| Anchor | Is | Renders as |
|---|---|---|
| **Documentation link** | Provenance: where the framework's rule is written down | `<a class="doc" href="…">` around the concept, from the catalogue |
| **Runtime probe** | A question to the reviewer's own application, which they run | `<pre class="probe">`, one command |

A third once existed — a primer callout, for the case where the reviewer could not decide without
knowing the framework rule itself. § *A future full mode* records what it was. It is not in force,
and a page emits none.

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

**Routing.** One anchor per claim, never two:

| The claim needs | Goes in | Because |
|---|---|---|
| Running something to be believed | The checkpoint it settles — `pre.probe` after the explanation, with any setup beside it | It is an action the reviewer takes, and there is no separate validations section to send it to |
| A mechanism made legible | A clause in the checkpoint's explanation, with `a.doc` on the concept | It deepens the judgment; a link is an aside, not a step |
| The framework's general rule | The sentence that states the consequence | Same |

Prefer the probe where this application's own configuration decides the answer — a real
`dependent:`, a real scope's SQL, the indexes that actually exist. Prefer the doc link where the
framework's rule is the whole point and this app cannot vary it.

**Earned by a decision the reviewer has to make.** The same test the excerpt budget uses, and for the
same reason: a behaviour every developer in that stack already knows earns nothing, and a page that
links each one has become a tutorial with a diff attached. **At most one doc link per checkpoint**,
and a page carrying more links than judgments has stopped selecting. Probes are scarcer still: a
checkpoint earns one where its judgment is framework-shaped — ActiveRecord in Rails, a changeset, a
query, an association or an `on_mount` chain in Elixir — and a second wants a reason.

**The deep-link ladder governs neither.** The four rungs are about `file:line` citations into a git
remote, so a doc link stays clickable at rung 3 and rung 4 where every repo citation is plain text —
exactly as an in-page `href="#cp-b"` does. A probe has no href at all.

## Source excerpts

The page's third primitive. A verbatim quotation of code, collapsed until the reader decides to check
the claim it supports.

It exists because of two things a deep link cannot fix.

The first is an asymmetry. A citation to an *unchanged* line sends the reader into an unfamiliar file
with no context, and the ones who do not go take the finding **on faith**. Faith is what this page is
built to remove, so the lines come to the reader instead.

The second is this page's own ordering. § 02 comes *before* § 03, and § 03 is the moment the reviewer
opens the code — so while they are reading the checkpoints they do not have the diff in front of
them. An earlier version of this section assumed they did — *"a citation to a changed line is cheap
to follow, the reviewer has the diff open anyway"* — and rationed `--diff` excerpts on that basis.
What it produced was sections whose only quoted code was code the PR never touched. The shortest way
to make a judgment possible is often to show the lines it turns on, changed or not.

Two variants:

| Variant | Shows | Used for |
|---|---|---|
| `.excerpt--source` | Lines as they stand at one rev, no signs | Unchanged code, which has no diff to show. The variant that carries the product — and committed code a hunk cannot show whole. Its state tag says which |
| `.excerpt--diff` | A hunk with `+`/`−` gutters | Changed code, where *what moved* is the reviewer's question. The variant that lets a judgment be made with no diff open |

**An excerpt sits beside the claim or the entry it confirms, and nowhere else.** Never in a block of
its own, and never in the evidence foot — the foot is provenance a reader is not expected to open,
and a quotation that makes a judgment possible is not provenance.

| Location | Variant |
|---|---|
| § 02 · a *Look at* entry pointing at unchanged code | `--source` |
| § 02 · a *Look at* entry pointing at a changed hunk the judgment turns on | `--diff` |
| § 02 · a claim in a checkpoint's explanation that a reader would otherwise take on faith | Either, whichever fits the claim |
| § 03 · a reading-path stop whose reason is not already excerpted in its checkpoint | Either |
| § 04 · an affected entry beside the panel | `--source` |

Not in the inventory: an inventory cell is a checklist entry, not a claim, and a hundred collapsed
hunks is a page nobody can load.

The `--source` variant is the one that carries the product, and the sharpest case for it is a
committed line inside a generated file: *"no unique index on `projects.slug`, `db/schema.rb:141`"* is
one line in a file twelve hundred lines long, and no reviewer opens that file to check it. The
general rule against excerpting `db/schema.rb` is about **churn** — do not quote a migration's
regenerated diff. It was never about quoting one committed line that a claim turns on.

### The rules

- **The page must read completely with every excerpt closed.** No claim, no evidence tier and no
  citation may live only inside one. An excerpt *confirms* what the prose already said; it never
  *carries* it. This is the whole difference between progressive disclosure and hidden content, and it
  is the rule to check first when reviewing a page that uses them.
- **There is no per-section floor.** A checkpoint quotes the guard because the judgment turns on it,
  not because a rule says every part of the page shows its diff. The old floor existed because a
  behaviour flow that described its change without showing it was asking to be believed; a
  checkpoint asks a question instead, and the answer is sometimes in unchanged code alone.
- **The closed summary says what the reader will see and why to open it** — `path:lines`, a state
  tag, then the clause, all inside the `<summary>`. `View diff`
  and `Show code` are not summaries: a closed excerpt has to be informative, because most of them
  stay closed. The clause lives in the summary rather than at the top of the body **because of the
  closed-page rule above** — a why the reader has to open the block to see is exactly the hidden
  content the rule forbids. `excerpt.sh` emits it there; do not move it.
- **Verbatim, generated, never typed.** Run `scripts/excerpt.sh`. A mistyped inventory cell fails the
  coverage gate loudly; a paraphrased quotation is a *false* quotation and the reader has no way to
  catch it. This is the strongest version of the argument that produced `ledger-rows.sh`.
- **The state tag is read off the diff, never chosen.** `excerpt.sh --at` needs `--base` and
  computes it: `Unchanged` when the path is outside the diff, and `Added`, `Removed`, `At head` or
  `Before the change` when it is inside. A `--diff` hunk is `Changed`. That is the whole vocabulary,
  and it is closed because it is computed. The script used to hard-code `Unchanged` on every
  `--source` block, and a run published `db/structure.sql:304-313` tagged Unchanged on a page whose
  own inventory listed that file as changed: verbatim bytes under a false label, which is the one defect
  in this component a reader has no way to catch — the excerpt looks *more* trustworthy the closer
  they read it. Two things follow.

  **Quoting a changed file at one rev is legitimate**, and sometimes the only way to show what the
  committed code now permits: a hunk of an 18,000-line `structure.sql` cannot show that a table has
  **no** `CHECK` constraint, and an invariant checkpoint is built on exactly that reading. It was the
  label that was wrong, never the excerpt — so the fix is the tag, not a rule against the quotation.

  **And a path the diff touches is never tagged `Unchanged`, even where the quoted lines are
  untouched**, because section 04 and the evidence foot split changed from affected-not-changed **by file**. Two senses of
  one word on one page, and nothing tells the reader which is meant. Where the range is the point,
  the prose says it — *"the pre-existing unique index at `:18682`, which this change does not
  touch"* — which is where it can be said precisely anyway. `evals/checks/excerpts.rb` holds both
  halves: every `Unchanged` tag against the changed set (from a repo when it has one, otherwise from
  the page's own inventory, which the completeness invariant guarantees is the whole diff), and every
  tag against the vocabulary, for the inputs where there is nothing to compare against.
- **An excerpt is evidence for one claim, not coverage of a file.** Never a whole file, never every
  hunk. Completeness belongs to the inventory.
- **The field carries its own citation, not one from elsewhere on the page.** The closed-page rule is
  easy to satisfy globally and still fail locally: a run wrote *"an unchanged trait in
  `spec/factories/projects.rb` stamps `archived_at`"* with the path as bare prose, the only `file:line`
  for it being the excerpt's own footer. The same citation did appear linked in § 04 and in § 03's
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
- **`data-path` is reserved to inventory cells.** Excerpts carry `data-src`. `scripts/coverage-gate.sh`
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
so under that reading every one of them earns an excerpt automatically, three checkpoints produce three
without a decision being made, and a large PR produces dozens. A cap that is always
reached is not a cap.

**The test that does work: is the citation load-bearing for a decision the reviewer has to make?**
Not merely unchanged, not merely interesting — load-bearing. A finding they will act on, ask the
author about, or have to weigh. Most *affected but unchanged* entries are context; a few are the
reason the section exists, and those are the ones that get the lines brought to them. This test came
out of a run that hit the circularity above and had to invent something to escape it.

**The test rations, and nothing is exempt from it — including a changed hunk.** A checkpoint quotes
the guard because its judgment turns on seeing that guard; where the judgment does not turn on the
bytes, a deep link is the whole answer. The rule this replaced said every behaviour flow showed its
own change, which was right for a component that had to be readable with no diff open and is one rule
too many for a component that asks a question. What the old rule was defending against is still real
— pages that quoted unchanged code well and never once showed the change — and the defence now is
that seeing a changed hunk is very often exactly what a judgment turns on.

Then the mechanical limits:

- **One excerpt per entry or claim**, never two.
- **Never twice for the same lines.** If a *Look at* entry and the reading-path stop pointing at it rest on the
  same citation, the excerpt goes in **one** of them — the checkpoint, which is where the judgment is
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
  or test boilerplate — inventory cells by definition, and an excerpt of one teaches nothing. `db/schema.rb`
  is the one nuanced case; see the note under the location table.
- **A page-wide sense of scale**, since the per-field cap alone does not bound the total: the count
  grows with the number of checkpoints and the number of load-bearing findings, never with the file count,
  which is a far slower curve. One or two per checkpoint is the ordinary shape — the hunk the judgment
  turns on, plus the one unchanged citation it rests on — and a third wants a reason. **Count per
  checkpoint, not per section, inside § 02**: a section-wide limit of two there is a limit of two
  across the bulk of the page, which is how this format once ended up under-quoting the diff.
  Outside § 02, more than two
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

Section 04's figure, and one of the page's two chain figures — § *Chains* has what it shares with a
checkpoint's own `figure.chain`, and the rule that decides which one a given chain is. A **path** is
a directed chain that runs from code this PR changed, through the affected-but-unchanged code that
gives the change its consequence, to an **observable behaviour** — what a user or an operator would
see. Rendered as `.impact`, assembled whole in `page-template.html`.

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

**Budget: 1–3 paths, 3–5 nodes each.** These are the paths a reviewer has to *hold*, and three is
already the outer edge of that — wanting a fourth is the signal that the three you have are not
doing their job, which is the same question § *Depth rules* asks about a second diagram. The fourth
consequence is not lost by being left out: *affected, not changed* below carries its entry, and the
checkpoint that turns on it carries its explanation. It was five, and five is where a real page put them; on
that page the panel had become a section to scroll rather than a figure to read.

And a change with no nameable edge earns **no panel at all**: the affected list carries the entries
either way, and a figure that cannot say what reaches what is the thing this component exists to
stop.

The panel **is** section 04's one figure — one `.impact` group, whatever its card count — so § 04 earns no
second, at either level.

Two things the panel is not. It is not a dependency graph: it is 2–3 curated paths chosen because a
reviewer has to hold them, and completeness here would destroy the thing that makes it readable. And
it is not SVG. Nothing on this page is (§ *Chains*) —
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
| The semantic delta, and intent | *What changed* | Nowhere else — a checkpoint assumes it |
| A judgment the reviewer has to make | Its checkpoint's explanation | The reading path, as one stop's why; *Impact outside the diff*, in one clause |
| Mechanism inside the change | That checkpoint's `figure.chain`, or its explanation | Nowhere else |
| A consequence that crosses into unchanged code | *Impact outside the diff* — the figure, and the affected entry beside it | The checkpoint that turns on it, in one clause |
| Unchanged code the change reaches that no checkpoint turns on | The affected entries beside the panel, or the evidence foot's list | Nowhere else |
| An open question for the author | The checkpoint's `p.open` line | Nowhere else |
| A validation step or a probe | The checkpoint it settles | Not the foot |
| What was searched | `details.searched`, in the evidence foot | The finding it supports, stated in the open prose above |
| Every changed path | The inventory, in the evidence foot | Nowhere else |

**Where the old per-layer material went.** Persistence, the endpoint contract and the frontend
boundary never had sections, and now neither do behaviour flows: a flow's material becomes a
checkpoint where it needed a judgment, an impact path where it crossed into unchanged code, and a
foot entry otherwise. The reading order became section 03 pointing at checkpoints. Cross-cutting
consequences became a checkpoint wherever they are a judgment for this diff and nothing otherwise.
Author questions became the `p.open` line and validations moved inside the checkpoint they settle;
the comprehension checkpoint is gone entirely, because the checkpoint's own question is the question.
The coverage ledger became the foot's unclassified inventory.

**The checkpoint owns the explanation, and the sections after it point back.** That is what the
ordering buys: §§ 03 and 04 both come after § 02, so neither has to re-explain a judgment to be
readable. A section that finds itself explaining a checkpoint's finding a second time is in the wrong
section.

The reference form is one sentence, no re-explanation:

> The `ActiveProjects` consequence is what checkpoint 2 turns on.

Not a summary of that consequence, not its citation again, not its tier label again.

**Two consequences worth stating plainly.** A caveat belongs in the page once — *"these findings are a
pass, not an audit"* is said under *What needs your attention* and nowhere else. And a `file:line` is not repeated every
time its fact is mentioned; it sits with the canonical explanation, and later references point at the
section, not the file.

**Where synthesis beats deletion.** When two sections hold overlapping but non-identical facts, merge
them into one sentence that carries both rather than keeping the better one:

> Because archival writes `archived_at` and leaves `discarded_at` untouched, archived projects stay
> inside `ActiveProjects`, so every selectable-project list keeps offering them. Whether that is
> intended is an author question.

Three separate paragraphs — one for the write, one for the scope, one for the lists — say less than
that, at four times the length.

## The completeness invariant

**Every file in the diff appears somewhere in the page.** A reviewer who wants to read all of it must
be able to, and must never wonder whether something was quietly skipped.

The depth rules govern *how much treatment* a file gets, never *whether it is accounted for*. Files
needing no discussion are still listed, batched into a compact table with a one-clause reason
("regenerated by the migration", "import path updated", "factory for the new model"). Renames and
pure moves get a line saying so, which is itself useful.

**The invariant is one-directional.** Every path in the diff must appear in the page. The reverse does
*not* hold: the page cites unchanged files everywhere by design — that is what § 04 and every
*Look at* entry pointing outside the diff are for. So the check is a subset test, never set equality:

```
set(diff paths) ⊆ set(paths cited in page)     ✅ the invariant
set(paths cited in page) == set(diff paths)    ❌ impossible by construction
```

The one place equality *is* asserted is the inventory in the evidence foot, which is
machine-generated from the diff for exactly that reason. Never "fix" a surplus elsewhere by deleting
a citation to unchanged code.

**The carrier is `div.gt.gt-paths` inside `details.evidence`**, generated by
`ledger-rows.sh --paths-only`, one `.gt-paths` cell per path, each carrying `data-path` — which is
what `coverage-gate.sh` greps page-wide to assert that equality. That is the whole reason the carrier
is a grid cell rather than a list item, and `data-path` is **reserved** to it: an excerpt using the
attribute would register as a surplus path. Excerpts carry `data-src`.

**The carrier is not section 04, and that is a change from an earlier version of this format.** § 04
used to hold the whole diff as well, which put a list of every changed path in the middle of the
section whose own spec says *completeness here is about consequences, not paths*. On a 24-file PR it
rendered as 24 links above a caption explaining that the eight worth opening were ranked elsewhere.

**The foot is provenance, and collapsing it is legal for that reason.** The hard rule is that the
page reads complete with every collapsed block shut, and an inventory of paths passes that test where
a *finding* never would. So nothing a reviewer has to act on may be put in there — the same split
§ *What was searched* draws between a finding in the open prose and the grep behind it. Collapsed is
not optional, and neither is the gate: `SKILL.md` step 10 runs it against the finished page whatever
the inventory looks like.

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
denominator stopped being true once the checkpoint became the unit of staging: the number of
arrivals now depends on how many checkpoints the diff earns, so a run would have to commit to a total before
it knows one. A count of parts still pending needs no total, and it is the number the reader wanted
anyway — *how much is still coming*, not *how far through its own plan the run is*.

**Pending in the rail** so the reader can see the shape of what is coming:

```html
<a class="sub" data-rail="cp-b" href="#cp-b">Is nil the intended default? <span class="pending">pending</span></a>
```

**Pending in place**, where the section will go, so someone scrolling does not skip past a gap:

```html
<section class="cp" id="cp-b">
  <span class="lbl lbl-wide">Checkpoint B</span>
  <h3>Is nil the intended default here? <span class="pending">pending</span></h3>
  <p class="note">Two consumers and one guard, across BaseSearcher and the transactions
  controller; being written.</p>
</section>
```

One line of substance in the stub — which files, what it turns on — turns a placeholder into
information. "Coming soon" does not. And for a checkpoint the `<h3>` is doing the real work: the
question is legible before the explanation exists, which is why stage 3 opens with the stubs.

Note that the stub is a whole `<section>` with its own `id`, which makes it a unique anchor a later
stage can `Edit` in place. That is deliberate and worth keeping: it is what lets a stage write only
what is new instead of re-emitting the document, which `SKILL.md` step 9 requires and which a profile
found to be the largest single cost in a run.

**The evidence foot's summary says *partial*** until the final publish, because the gate has not run.
Say so in the summary rather than letting a short inventory imply a short diff.

**A run that stops early is a third state, not a draft that never finished.** Same components,
different words: the banner states what was covered and that the run stopped, every marker changes
from *pending* to *not written*, and the foot's summary says the gate never ran. The distinction is the
whole point — *pending* is a promise, *not written* is a fact, and a page left promising work that is
not coming is the one outcome worse than publishing late. `SKILL.md` § *When a run stops early* has
the wording.

**Pending attaches to whatever a reader could mistake for finished**, which means two granularities,
not one.

A **section**, which is the stub above.

A **checkpoint**, because § 02 is delivered one at a time (`SKILL.md` step 9). An unwritten checkpoint
is a whole `<section class="cp" id="cp-x">` stub — assembled in `page-template.html` beside the
pending section, and copied from there rather than rebuilt — and § 02's rail entry keeps a marker
until every checkpoint under it is written. **A checkpoint stub's line of substance is its
question**: that is what lets the agenda be read before any of it is written, and it is the reason
opening stage 3 is worth a publish of its own. A reader who learns what the three judgments are has
most of what they came for, ten minutes before the explanations arrive.

The second case needs **no markup of its own**: the rail already carries a per-checkpoint marker and
each checkpoint is already its own `<section>`. A parallel mechanism for it is a regression, not an
addition.

**Omitted and pending must stay distinguishable, and section 04 is where that bites.** A diff whose
consequences all stay inside it earns no impact section: remove the section and its rail entry, and
do not leave a stub saying nothing reaches unchanged code. A section that says that is a clean bill
of health with a marker on it.

**At the final publish, all of it goes**: banner, rail markers, stubs. A finished page still saying
"2 parts still pending" undersells completed work and leaves the reader unable to tell whether the run
stopped early. If a section genuinely was left unwritten — the diff was too large, a region got skimmed
— that is a sentence of prose stating the limit, not a pending marker. The two mean different things:
pending is a promise, a stated limit is a fact.

## What was searched

Where a search came up empty, say so and say what it was. Unrecorded, absence and omission look
identical, and the reviewer has to redo the work to tell which it was. This is what makes the
affected-but-unchanged claim honest rather than an assertion.

**It is collapsed, and it is provenance rather than a claim.** `details.searched`, shut by default,
inside the evidence foot, holding `ul.sr-list` and one short *Out of reach* paragraph. It obeys the
same hard rule as a source excerpt: **the page reads complete with it closed.** So a finding that
rests on an empty result is *stated in the open prose* — "nothing else reads this column" — and the
grep that establishes it goes inside. A run that leaves the finding to be inferred from an empty row
has hidden it, not disclosed it.

Why it is collapsed: open, it was the longest block in the section that held it, and a reviewer
meeting a PR for the first time reads it as noise before they have any reason to care. Shut, it
becomes what it always was — the thing you open when you want to check the page's work, which is the
reviewer's own due diligence rather than a substitute for it.

**One row per search, and a row is a command and a clause.** `<code>` for the command, then what it
returned in a few words: *"two callers"*, *"no hits"*, *"every reader of the column by name"*. Not a
sentence, and never three. The block used to be one run-on `<div>` and real pages filled it with
paragraph-long re-explanations of entries the reader had just read two inches above — the same
restatement § *One canonical home* forbids everywhere else, arriving as provenance. If a row needs a
sentence to say *why* the result matters, that sentence belongs in the checkpoint the search
supports.

*Out of reach* is one short paragraph, not a list: what a name-based pass cannot see at all — dynamic
dispatch, a string-built template, another repository. Keep it. It is the page telling the reviewer
where their own checking is owed, which is the opposite of padding.

**A recorded search has to reproduce the entries it is offered for.** This is the half that decays
quietly. A run listed `rg -n 'account_type' app test` and claimed it returned every reader of the
column — but the two guards it had just cited read the column through an enum predicate, `steward?`,
which that pattern does not match. The search was real, the entries were right, and the provenance
was still false. Where one pattern does not reach an entry, record the one that did; where a search's
coverage has a hole, name the hole.

**Record the working search as the search, not as a correction of one that failed.** A caveat the
reader needs in order to re-run it — `git grep` defaults to basic regex, so an alternation needs `-E`
and a word boundary needs `-P` — belongs on the line as a caveat. What an earlier pattern returned
before you fixed it does not belong on the page at all. That is `SKILL.md` step 8's correction rule,
and it surfaces here more than anywhere else, because a recorded search is where a run is most
tempted to show its working.

---

## A future full mode

This page put four things down, and they are recorded here so a later mode picks them up from a
written rule rather than rediscovering them. None of them is in force.

- **The seven-field review unit** — why this exists · implementation · relevant tests · affected but
  unchanged · things to understand · how to validate · reviewer questions, rendered as a `.mech`
  block and one `dl.rows`. It was right as analysis and wrong as a reading obligation; a full mode
  wanting it back should hang it *beneath* a checkpoint rather than in place of one.
- **The classified ledger** — every changed path with the section covering it, an attention level and
  a group. `scripts/ledger-rows.sh` still emits that form without `--paths-only`.
- **The comprehension checkpoint** — at most five questions, each answerable from the page but not by
  copying one sentence out of it, rendered as inverted tiles.
- **The framework primer** — `aside.primer`, one per flow at most and most flows earning none, gated
  on the doc link it escalated from, carrying a `file:line` from this repository and a `pre.demo`
  that may show a result line only because its receiver is a class this application does not have.

**The invariant a full mode has to hold: it keeps the agenda and adds depth beneath it.** The
reviewer reaches *What needs your attention* at the same point in the page either way. A mode that
makes them read supporting evidence before the useful overview is a different product, and it is the
one this page replaced.

---

## Section 1 · What changed — always

The masthead plus the semantic delta. It orients; it does not teach.

**The masthead** carries the PR title and number, the branch against its base, the author, and the
linked ticket if the branch name or description names one.

**The exact revision, as two short SHAs**: head → base, in the masthead's `Revision` cell beside the
branch names. Not conditional on there being a PR, and not something the reader has to derive. A
branch name goes stale the moment someone pushes, and a page describing an earlier revision while
looking current is the one failure a reader cannot detect from the inside — which is exactly what
regenerating per push creates, several pages that differ only by the revision they describe.

**Change shape** — a chip naming what kind of change this is: feature · refactor · bugfix ·
migration · dependency bump · mixed. One word, and it is a category, never a grade.

**A metric strip** of commits, files and a line split. Bucket the files rather than reporting one
total, because a 40-file PR that is 8 production files and 32 fixtures is a different review from one
that is 40 production files:

| Bucket | Holds |
|---|---|
| Production | Application code the change is about |
| Test | Specs, factories, fixtures, test helpers |
| Generated | Lockfiles, schema dumps, compiled assets, generated types |
| Docs | Markdown, comments-only changes |

**Then one paragraph, 80 to 160 words, and at most a handful of bullets.** What problem this solves,
what is now true that was not, who is affected. Derived from the code, the tests and the commits —
the PR description is a claim and is attributed when it is used, per `SKILL.md` step 4. Carry an
evidence tier on the intent itself if it is inferred rather than stated.

Bullets only when the PR contains genuinely independent changes, and then one line each as an actor
plus a behaviour. **Not an execution path**: a path is a chain's job, and a list of them here is the
use-case inventory this section stopped carrying, which spent the reader's first screen on material
the checkpoints then said again.

**Optionally `dl.ba`, and most pages do not earn it.** Before and after are two rows, never one
paragraph, and the pair is for a workflow that fundamentally changed rather than for every PR. One
evidence tier for the pair, on the *After* row. An addition rather than a replacement earns none.

**A stated limit goes here and only here.** A region you had to skim, a dirty working tree, a client
you could not read: one sentence, in the same voice as anything else on the page. `SKILL.md` § *How
big should the page be?* is what decides when one is owed.

---

## Section 2 · What needs your attention — always

The page's core, and the one section a reader who has time for nothing else should read. Three to
five checkpoints; § *The review checkpoint* owns every rule about them.

The section itself carries only a heading, one sentence saying what these turn on and that the order
is the order to think about them, and the sampling caveat. Then the checkpoints, in ranked order.

---

## Section 3 · Read the code in this order — always

A route through the code, in the order that builds understanding. Render as `ol.begin`.

Each entry carries three things, and one of them is a pointer rather than an explanation:

- **Where to go** — a file, a method or a region, with its citation.
- **Why here** — one sentence in a `span.why`. What this file establishes that the next one needs, or
  what on it needs judgment. Its evidence tier if the reason rests on something the diff does not
  show.
- **Which checkpoint it belongs to** — `href="#cp-x"`, which never re-explains the judgment and never
  repeats the checkpoint's own citation or tier.

**Order by conceptual dependency, not by the diff.** Schema before the code that trusts it; the
smallest complete example before the bulk; irreversible code last, so it is read twice. Alphabetical,
diff, layer and commit order are all wrong unless one of them happens to produce the best conceptual
sequence.

**Three to seven stops, and never one per changed file.** The question this section answers is: *if I
have fifteen minutes and now understand the important questions, where do I start reading?* Every
other file is accounted for in the evidence foot, which is the whole reason a short route here is
honest rather than a gap.

Never a grade, never a severity chip. Where attention goes is expressed by what is on this list and
in what order, which is the only form of ranking this page has.

---

## Section 4 · Impact outside the diff — when a consequence crosses into unchanged code

Affected-but-unchanged code is what this page is for, and this is where the whole set is seen at
once. One to three impact paths, each starting in changed code, passing through at least one
unchanged consumer, and ending at something a user or an operator would see. § *Impact paths* owns the
figure; § *Chains* owns what it shares with a checkpoint's own chain and the rule that decides which
is which.

**Below the figure, the affected entries the paths run through**, under the eyebrow *Affected, not
changed* — that label verbatim, because `evals/checks/searches.rb` opens its scope on it. One
citation and one clause each, and a pointer at the checkpoint that turns on it rather than a second
explanation:

> `app/queries/active_projects.rb:8` — scopes on `discarded_at` and never learns about archival.
> Checkpoint 2.

Not a summary of checkpoint 2. Not its citation again, not its tier again.

**What stays here and what goes to the foot.** The entries a path runs through and the entries a
checkpoint turns on stay. Everything else the pass found — real, cited, and not something the reviewer
has to decide about — goes in the evidence foot. That split is what keeps this section a set of
consequences rather than an inventory of discoveries.

**Omit the whole section, and its rail entry, when nothing crosses.** A section saying that nothing
reaches unchanged code is worse than no section: omitted and pending have to stay distinguishable, and
an empty one reads as a clean bill of health. The foot's search record is where an empty result is
disclosed.

**No list of changed paths, here or anywhere outside the foot.** Completeness in this section is about
*consequences*, not files. A run that lists the diff here has built the second inventory this section
is told not to become — on a real page that was 24 links above a caption explaining that the eight
worth opening were ranked elsewhere.

---

## Section 5 · Evidence & diff coverage — always, collapsed

One `details.evidence` below the last section, shut. **Not a section**: no number, no rail entry, no
eyebrow, no `<h2>`. Its summary says what it holds and how many paths, and says *partial* until the
gate has run at the final publish.

Inside, in this order:

1. **The inventory** — `div.gt.gt-paths` holding one `div.c[data-path]` per changed path, generated by
   `scripts/ledger-rows.sh --paths-only`. § *The completeness invariant* owns it.
2. **What was searched** — `details.searched`, shut inside the shut block. § *What was searched* owns
   the form.
3. **The affected code no checkpoint turns on and no impact path runs through** — under the same
   verbatim *Affected, not changed* eyebrow, one citation and a clause each.

**Everything in here is provenance**, which is what makes collapsing it legal under the hard rule that
the page reads complete with every collapsed block shut. An inventory, a record of searches and a list
of real-but-secondary consequences all qualify where a finding never would.

**Nothing a reviewer acts on goes in here.** If an entry below is a judgment they have to make, it is
a checkpoint that was mis-filed. That is the rule this section is most likely to break, because
moving something down here is the easiest way to make the page shorter and the hardest to notice.

No findings, no attention level, no group, and no ranking of any kind.

---

## The agenda budget

Guidance, not limits. Every number here is a WARN in the same sense the excerpt budget is: a page
outside one of them is a page to read again, not a page that is wrong.

| Part | Words |
|---|---|
| § 01's paragraph | 80–160 |
| A checkpoint — question, explanation, *Look at* clauses, open line | 50–140 |
| A reading-path stop's `span.why` | ≤ 40 |
| An affected entry's clause | ≤ 30 |
| **The page, visible prose, on a small or medium PR** | **700–1,500** |

**What is never counted:** anything inside a chain — node labels, `.ip-d` details, `.ip-rel` verbs,
lane labels, the legend, a `figcaption`; anything inside `<code>` or `<pre>`, which includes every
probe and every command; anything inside a collapsed `<details>`; and the masthead. A page is never
over budget by a figure or a quotation.

**The one number this budget never touches is the checkpoint count.** A page that came in under the
ceiling by losing a judgment has done the one thing the budget forbids. Fewer checkpoints is
legitimate only when two merged into one question (`SKILL.md` step 7c) or when the PR is small enough
that three would be padding (step 7e) — never because a number said so.

**And the floor is a rule rather than a number.** A *Look at* entry has a clause; a checkpoint has an
explanation of at least two sentences. A field compressed into its own label reads exactly like a
filled one and is the compression that deletes rather than tightens. Omitting a part is honest;
stubbing it is not.

These numbers are a **first calibration**, derived from the component budgets rather than measured on
published pages. The way to move them is three runs and a number that came out of a page, not an
argument.

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
