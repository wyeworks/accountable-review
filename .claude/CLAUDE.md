# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

There is no application code here. The repository is the `accountable-review` Claude Code plugin. It
ships a single skill — `skills/review-map/` — that turns a pull request into a published HTML review
map: what the change is for, what it can break, what the API and its client now agree on, and where
the decisions live. The first target stack is a Rails API with a Next.js client.

Installed, it is invoked as `/accountable-review:review-map`: plugin skills are always namespaced by
the plugin name, so the manifest name and the skill directory name together decide the public
command. It takes a target and a **detail level** — `--brief` (the default), `--full`, `--review` —
parsed in step 1 as prose, because `argument-hint` and `arguments` are not in the Agent Skills
frontmatter allowlist and `claude plugin validate --strict` rejects an unknown key. The "source" is
prose that another Claude instance executes, so the unit of quality is instruction clarity, not
compilation.

There is no build, no test suite, and no linter. Changes are verified by running the skill against a
real PR and reading the page it produces. `claude plugin validate . --strict` checks the manifest,
not the prose, which is the part that matters here.

## Working on the skill

Run a Rails project against this checkout — no install, and `/reload-plugins` picks up edits without
restarting:

```bash
cd /path/to/app && claude --plugin-dir /path/to/accountable-review
```

Then: `/accountable-review:review-map <PR number | PR URL | branch | ""> `.

Before pushing, `claude plugin validate . --strict` must pass — CI runs the same check, and so does
the community-marketplace review pipeline.

Because defect discovery is sampling rather than a deterministic function of the diff, a single run
is weak evidence. When judging whether a wording change improved things, run the same target more
than once, or the same wording against several PRs of different shapes (a 4-file bugfix, a migration,
a 100-file feature spanning both sides of the API) — small PRs and large ones exercise opposite
failure modes.

Two checks are worth making on every run, because they are where this version is most likely to be
wrong: open two entries from *affected but unchanged* and confirm the cited file really consumes the
changed thing, and confirm no sentence anywhere grades the PR.

Run both levels. They fail differently: `--full` strains the context and duplicates across seven
sections, `--brief` compresses four kinds of material into one section and its characteristic defect
is a tail that has quietly become a list of four things with the blast radius as one item. A wording
change judged at one level says little about the other.

`skills/review-map/evals/` is where that judging happens, at three scopes.
`fixtures/make-fixtures.sh` builds four repositories whose interesting findings sit deliberately
*outside* the diff, so there is a written right answer to check against. A **page** case is a whole
run, graded on what only a whole page carries. A **section** case produces one fragment from the
hand-authored upstream in `frozen/` and grades that — which is what makes "run it three times"
affordable, and three runs is the smallest sample that separates a wording change from noise. A
**component** check runs on a script's output or on one `<svg>`.

`./run.sh behaviour-flows -n 3 --judge` then `./report.sh` is the loop; results carry the skill's git
sha, so a pass rate is attributable to a version of the prose. `--judge` adds the other half: one
model pass per fragment over the written expectations, anchored by running inside the fixture with
the frozen upstream, its counts under their own keys and never summed with the mechanical ones.

Every second of that loop is the model — the fixtures build in under a second and `check.sh` in under
two tenths — so `run.sh` takes `-j N` to run the repetitions at once and `--fast` (`--model sonnet
--effort low`) to read each one more cheaply. The first is free; the second is not, and the price is
comparability, which is why the model and effort land on every result line and `report.sh` makes them
part of the group key. Shape a wording change on the fast loop, then re-measure on the shipping model
before quoting a number. `--fast` leaves the judge alone deliberately: the producer is what is under
test, the judge is the measurement, and a cheap measurement is not a faster loop.

When the question is where the minutes went rather than whether the page was right,
`evals/profile.sh` reads the transcript of a run — an eval repetition or a real PR — and splits its
wall clock into tool execution, streaming, and the wait before each request produces its first token.
On the run it was built against, that last part was 58% of the total and tool execution was 6%. Split
that 58% before concluding anything from it: most of it is thinking, and only about **2.5s per request
is fixed** — 95 requests paid roughly 240s of that for nothing, while tripling the context cost 0.8s.
So the one lever is **fewer requests**, which is why § *Fewer turns, same work* and its pointers in
steps 2, 5 and 9 exist, and why context reduction is not worth prose. Two `Write`s of the page
accounted for 329 of the 457 seconds of streaming. It infers nothing the transcript does not carry:
publish stages are mechanical, the ten steps are **not** —
`ledger-rows.sh` fires at minute four and again at minute thirteen — and steps 4, 6 and 8 leave no
trace at all, so they get no row. Read `evals/README.md` § *Where the time goes* and § *Profiling one
run* before quoting one of its numbers.

Section files are named by slug, never by number: `report-format.md`'s numbering is already the
source of order, and a filename repeating it only makes the reader look the number up. Read
`evals/README.md` before adding a case. Two things there are worth preserving above the rest — the
split between mechanical and judged expectations, and the plainly stated limit that a section eval
cannot see whether the page repeats itself.

## How the documents divide the work

Each reference owns one axis; keep them from bleeding into each other.

| File | Owns |
|---|---|
| `SKILL.md` | The procedure — ten ordered steps from resolving the target to publishing — plus the product principle and the hard rules |
| `references/report-format.md` | Page structure — the detail levels and which sections each produces, what triggers each section, the review unit, the evidence tiers, source excerpts, the canonical-home rule, depth rules and the deep-link ladder |
| `references/rails-nextjs.md` | Domain knowledge — what a senior reviewer of this stack looks for, per layer, plus the search recipes for affected-but-unchanged code |
| `references/page-template.html` | Design system — tokens (light and a dark half of our own), component classes, the SVG vocabulary, the two-layout diagram catalogue, and the page's one small script |
| `scripts/excerpt.sh` | Generates the collapsed source excerpts, so the quotation is the real bytes |
| `scripts/ledger-rows.sh` | Generates the ledger rows and their deep links, so the gate checks classification rather than typing. `--paths-only` emits the brief level's unclassified carrier |
| `scripts/coverage-gate.sh` | The one mechanical check — set equality between the ledger and the diff |
| `evals/` | Fixtures with planted findings, the frozen upstream, the drivers, the cases, `checks/`, and `profile.sh`, which measures what a run *cost* rather than whether it was right. Not loaded at runtime; see `evals/README.md` |
| `evals/checks/` | One script per rule family, dispatched by `check.sh`; `self-test.sh` proves they still fire |

`SKILL.md` is the only file loaded up front; the references are read on demand at the step that needs
them. That is why `SKILL.md` says *when* to load each one, and why detail belongs in the reference
rather than inlined into the procedure.

The one exception is the product principle and the hard rules, which stay in `SKILL.md` even though
they read like a reference. A rule that can be skipped is not a rule, and the always-loaded file is
the only place skipping is impossible.

## Invariants that span files

Editing one of these means checking the others still agree.

- **Two page shapes, and one of them is the default.** `--brief` merges §§ 4–7 into one section;
  `--full` writes all seven; `--review` stops. The level is settled in `SKILL.md` step 1 beside the
  target and the link rung, and `report-format.md` § *Detail levels* and § *Section 4 at brief* own
  what it produces — **and own it alone.** Every other file points at them.

  Two rules make the level cheap instead of a second product. **It changes how many sections there
  are, never what a section teaches**: §§ 1–3 are byte-for-byte the same spec at both levels, and a
  run reading a shorter page as licence to explain less has misread the option. And **the merged
  section keeps the anchors**: `id="blast"` on the `<section>`, `id="approving"` on its last `<h3>`,
  the `Changed` / `Affected, not changed` `<dt>` labels verbatim, and `<ul>` rather than
  `<ol class="begin">` in the approving part. That is why exactly one check knows the level —
  `evals/checks/before-approving.sh`, for the checkpoint — while `blast-radius.sh`, `searches.sh` and
  `page-invariants.sh` read the merged shape unchanged.

  That second rule is markup, so it is breakable by accident and invisible when broken: with the
  anchor gone, `before-approving.sh` prints a **SKIP**, which reads as verified.
  `golden/approving-brief-clean.html` plus the `self-test.sh` rows running `blast-radius.sh` and
  `page-invariants.sh` over it exist for the day someone moves one.

  `--brief` is the default, so it is what almost every real page will be. Judge it first.
- **The page never grades the change.** No severity scale, no risk score, no confidence percentage,
  no approval language. Stated as the product principle at the top of `SKILL.md`, repeated in its hard
  rules, and enforced structurally: the template has no chip that expresses a verdict, and
  `page-template.html` says so in its header comment. Reintroducing a severity vocabulary is the
  single easiest way to undo this iteration.
- **Evidence tiers.** Five of them, listed in `report-format.md` § *Evidence tiers*, rendered as
  `span.tier`. A claim the diff shows directly carries **no** label — silence is the first tier. That
  asymmetry is deliberate: labelling everything is noise, and noise gets skipped.
- **The review unit** is the page's primitive: seven fields, fixed order, defined in
  `report-format.md` and rendered as a `.mech` block followed by one `dl.rows` — **and rendered
  nowhere else.** A behaviour flow's body *is* a unit; the path, the diagram and the decisions block
  sit beside it inside the flow section, with decisions after the closing `</dl>`. There is no
  endpoint card: the contract is the flow's own material and lives in its `.pipe` and its field rows.
  Two guards keep the unit from becoming ceremony — a unit needs a non-obvious *things to
  understand*, and fields may be omitted but never faked.

  Four files have to agree: `page-template.html` holds one behaviour flow **assembled whole** and
  the `<dt>` labels, `report-format.md` § *The review unit* holds those labels in a column of their
  own plus § 2's split between what the unit carries and what sits beside it,
  `evals/checks/behaviour-flows.sh` checks the `.mech`-per-`dl.rows` pairing and counts field labels
  outside a grid, and `evals/golden/flows-clean.html` is the reference markup.

  Two subtleties the check has to keep. It takes **two extractions, not one**: unit regions anchored
  on `.mech` for the per-unit guards and for naming, and the grids alone for the housing census — a
  flattened flow keeps its `.mech`, so a census over unit regions counts loose fields as housed and
  misreports the defect as something else. And `dl.rows` is **shared** with § 4, which renders
  Changed / Affected-not-changed with the same grid, so the check narrows to `id="flow-"` *before*
  counting; `evals/golden/flows-blast-rows.html` pins that. It replaced
  `flows-endpoint-rows.html`, which pinned the same class of false positive when `.ep-row` was
  shared with `article.endpoint` — the sharing moved, the trap did not go away.

  The reason this is an invariant and not a convention: the template used to show the section
  shell, the unit and the decisions block as three *detached* siblings, with the composition stated
  only in prose. A run read the prose, copied the markup as shown, and flattened all three flows
  into loose field blocks parented to the `<section>` — losing the card, handing field spacing
  to `section > * + *`, un-scoping every `.unit ...` rule, and dropping one flow's *things to
  understand* entirely when a decisions block took its slot. Nothing errored and no check fired.
  **A composition that is described but never shown assembled does not survive a weaker reader** —
  the same reasoning that puts diagram geometry in a catalogue instead of deriving it per run.

  **This is now more fragile, not less.** The unit used to be a bordered card, so a flattened flow
  visibly lost its box. A `.mech` plus a hairline grid is borderless by design: a flow that spills
  its rows into the `<section>` looks very nearly correct, which is why the pairing is checked rather
  than the presence of a wrapper.
- **Affected-but-unchanged code is the product.** Step 5 of `SKILL.md` finds it, the search recipes in
  `rails-nextjs.md` are how, and it surfaces twice, at different depths: the review-unit field inside
  the flow that owns it **explains** it, and § 4 *Blast radius* shows the whole set at once, pointing
  at that flow in a clause rather than restating it. Code no single flow owns is explained in § 4
  instead — that is what makes it a section rather than an index. The rule that makes the whole thing
  honest: **record what was searched**, so an empty result reads as evidence rather than as omission.
- **Completeness, and the one mechanical check. It has no detail level.** Every path in the diff
  appears in the page, at every level, and the gate runs at every level. What the level changes is the
  *carrier*: § 7's classified ledger at `--full`, the merged section's `Changed` list at `--brief`,
  generated by `ledger-rows.sh --paths-only` as `.gt-paths` cells that still carry `data-path`. That is
  the whole reason the brief carrier is a grid cell rather than a list item — `coverage-gate.sh` greps
  `data-path` page-wide and `page-invariants.sh` § 4 requires it on a `div class="c"`, so a `.filelist`
  would have cost the gate. `--brief` declines to *classify* the diff; it never declines to account for
  it, and a run that skipped the gate for want of a § 7 has turned a shorter page into one that may
  have dropped a file. Stated
  in `SKILL.md` step 3, explained in `report-format.md` § *The completeness invariant*, and enforced in
  step 10 by `scripts/coverage-gate.sh`. Four files have to agree for that check to work: the script
  reads a `data-path` attribute, the template emits it on the ledger's grid cell
  (`<div class="c" data-path="…">`, not a `<td>` — the ledger is a CSS grid now), `report-format.md`
  § 7 requires it, and `SKILL.md` step 10 runs the script. Break any one and the gate stops
  checking. Note the asymmetry in the invariant itself: the page-wide rule is a subset test (the page
  cites unchanged files everywhere by design), while the gate is exact set equality against
  `git diff --name-only`, compared as whole strings — never substring matching, because `api/Gemfile`
  matches inside `api/Gemfile.lock`.
- **A staged page must never look finished.** The page publishes early and fills in at one URL
  (`SKILL.md` step 9) at both levels — the three milestones are cuts through the procedure, not through
  the section list. What the level moves is where a marker attaches: a section at `--full`, an `<h3>`
  sub-part at `--brief`, where the tail is one section written in pieces and the hazard is its first
  part making the whole thing read as done. Staging is only safe because an unfinished page says so: a build banner while it
  is being written, an explicit *pending* marker for every part that is coming, and both removed at
  the final publish. Four states have to stay distinguishable — written, pending, *not written*
  because the run stopped, and omitted because the diff did not earn it — since the whole risk is a
  reader taking any of the last three for "nothing to say here". A stopped run is the one that needs a
  deliberate edit: pending is a promise, and leaving one behind is worse than publishing late. The form lives in `report-format.md` § *Build state*, the components are
  `.buildstate` and `.pending`, and `evals/check.sh --draft` / `--final` check both ends of it.

  The pending marker earns a second keep, found by profiling rather than by reading: it is the
  **anchor a later stage edits**, which is what keeps staging from costing the whole document per
  stage. A run that instead re-`Write`s the file pays for every already-written section again — one
  did, producing its finished 82 KB page as a single 35,000-token write that re-emitted the staged
  23 KB byte for byte, 56% of everything that run spent streaming. Staging is only cheap if a stage
  writes what is new, so `SKILL.md` step 9 says fill in with `Edit`, never rewrite.
- **Findings are a sample, not an audit.** The page must never read as a clean bill of health. This is
  load-bearing, not hedging: the skill explains, and explanation is reproducible, but defect discovery
  is not.
- **Deep-link mode is chosen once**, in step 1, from the four-rung ladder in `report-format.md` —
  driven by whether the head SHA is reachable on a remote. Unpushed branches are the common case, and
  the correct behaviour there is plain text, not a permalink that 404s.

  The rung decides whether anything is clickable. It does **not** decide the form, and the form is not
  a taste: a line inside the diff links to the diff page — `pull/{n}/files` at rung 1,
  `compare/{base}...{head}` at rung 2 — because that is the page the reviewer is working in and a blob
  at head shows the new line with no trace of what it replaced. A line outside the diff links to a
  blob at the commit that line exists at: head for unchanged code, the diff's left side for code the
  change removed or for behaviour cited as it was. Neither form is the fallback; *affected but
  unchanged* is the page's product and no diff view can address it. Three files have to agree —
  `report-format.md` § *Deep links* owns both forms and the ladder, `SKILL.md` steps 1, 9 and 10 point
  at them and record both SHAs, and `ledger-rows.sh` takes `--pr`, `--compare` or `--blob` so a run
  never types an href into the `<td>` the coverage gate reads.
- **Seven sections at `--full`, four at `--brief`, and each fact has one home either way.** The format
  is deliberately *not* one section per
  architectural layer. It was, and that guaranteed restatement: one behaviour crosses persistence, the
  API, the boundary and its cohort, so it got described four times, and three further parts existed
  only to restate — findings surfaced in *start here* and re-explained inside a cohort, cross-cutting
  concerns retelling behaviours, a checkpoint quizzing the reader on the paragraph above. A 21-page
  page condensed to 9 with nothing of value removed, which measures the duplication at about half the
  document. So persistence, endpoint contracts and the backend/frontend boundary have **no sections of
  their own** — they are covered inside the behaviour flow they serve, and only what genuinely spans
  flows goes in § 5. `report-format.md` § *One canonical home* carries the routing table and the
  one-sentence reference form; § *Where the old per-layer material goes* maps the old twelve parts onto
  the seven. Reintroducing a per-layer section is how this regression comes back, and it will look like
  an improvement when it does.

  **The merged tail section is a second way for it to come back**, and a subtler one, because merging
  four sections is not the same as merging four *kinds of thing*. At `--brief` the routing table still
  applies with fewer destinations, and the failure to watch for is a section carrying both a flow's
  explanation and the pointer back to it two paragraphs apart — duplication at conversational distance,
  which reads as thoroughness. A section eval cannot see it; `evals.json` case 6 can.
- **The order is the reviewer's path, and the flow owns the explanation.** § 2 *Behaviour flows*
  teaches the mechanisms; § 3 *Start here* is the moment they open the code; § 4 *Blast radius* is a
  second pass over the same change through one lens. Everything after § 2 therefore **points back**
  at it — a flow never defers an explanation forward, and §§ 3 and 4 never re-explain one. The
  earlier ordering put the blast radius and a findings list before the flows, which forced both to
  carry enough mechanism to stand alone, and that was the page's main source of duplication. § 3 is
  **one list**: what most needs judgment and what to read first are the same question, and answering
  it twice is the shape to watch for coming back. Where the attention goes is expressed by what is on
  that list; every other file is accounted for by § 7's attention column.
- **The comprehension checkpoint is capped at five questions**, and each must be answerable from the
  page but **not by copying one sentence out of it**. A question whose verbatim answer sits in a
  paragraph above is restatement wearing a question mark. It lives inside § 6 *Before approving*
  alongside the author questions, validations and test gaps, not as a section of its own — the old
  standalone part overlapped all three.
- **Source excerpts are quotations, and the page reads complete without them.** The third page
  primitive: a collapsed `details.excerpt` holding verbatim code, in two variants — `--diff` for
  changed lines, `--source` for unchanged ones, which is the variant that carries the product because
  no diff view can address an unchanged line. Three things have to stay true together. The page must
  read completely with **every excerpt closed** — an excerpt confirms a claim, never carries one, and
  that is the whole difference between progressive disclosure and hidden content; the hard rule is in
  `SKILL.md`, the form and budget in `report-format.md` § *Source excerpts*, and the shape in
  `page-template.html`. The quotation is **generated by `scripts/excerpt.sh`, never typed** — a
  mistyped ledger row fails the gate loudly, whereas a paraphrased quotation is a false quotation the
  reader cannot catch. And **`data-path` is reserved to ledger rows**: `coverage-gate.sh` greps it
  page-wide, so an excerpt using it would register as a surplus path, most reliably when quoting
  unchanged code — the gate would fail on the page's best content. Excerpts carry `data-src`.
  `evals/check.sh` holds the mechanical half of all three; whether the prose survives with the blocks
  shut is a judged expectation, because no script can tell.
  **The tint is applied, never authored.** `--source` excerpts are syntax-coloured at read time and
  `--diff` excerpts are not, and the asymmetry is the same one that produced the two variants: a hunk
  is not one lexical stream (a removed line and its replacement are alternate realities, and a lexer
  fed both mis-reads everything after the first unbalanced quote), and its rows already spend colour
  on *added* and *removed*. Four files agree: `excerpt.sh` puts a `data-lang` on the `--at` block and
  nothing else, `page-template.html` holds the `--syn-*` tokens, the `.hljs-*` rules and the script
  that does it, `report-format.md` § *Syntax tint* owns the rule, and `evals/checks/excerpts.sh`
  fails a page that ships `hljs-` classes in its markup — a hand-coloured quotation is a quotation
  someone edited. The script verifies its own reconstruction character by character before touching
  the DOM and leaves the line alone on any mismatch, which is the only reason a script may touch a
  quotation at all. Everything about it degrades to the untinted page: no script, no network, a
  blocked CDN or an unknown language each leave the block in one ink.

  A third thing, added after a run whose flows quoted only unchanged code: the `--diff` excerpt is a
  **floor, not a ration**. Each behaviour flow shows the hunk its behaviour turns on, because § 2 is
  read before the reviewer opens the diff in § 3; the load-bearing test rations everything on top of
  that. The old framing ("a changed line is cheap to follow, the reviewer has the diff open anyway")
  plus a section-wide cap of two is what suppressed it, so the cap now counts per flow inside § 2.
  `evals/checks/behaviour-flows.sh` warns when every excerpt in the flows is `--source`.

  Two things the first live run changed, both worth keeping stated. The closed-page rule is judged
  **field by field**: a citation elsewhere on the page does not rescue a field whose only `file:line`
  sits inside the collapsed block, and `check.sh` cannot see that. And the budget's test is that the
  citation is **load-bearing for a decision the reviewer must make** — the obvious phrasing, "one per
  field that earns one", is circular, because *affected but unchanged* is by definition nothing but
  claims a reader would take on faith, so every such field earns one automatically and the cap bounds
  nothing. The budget, the permitted locations and the rung adjustment live in `report-format.md`
  **only**; `SKILL.md` points at them. An earlier version restated the cap in slightly different words
  and the two drifted apart within one run — hence the rule that this one has a single home.
- **Diagram layouts come from the catalogue, not from the run — and only two kinds are drawings.**
  Blast radius is a `.blast` box grid and boundary chain is a `.pipe` spine: both carry membership of
  a set and order along a chain, which a component shows as well as geometry did, reflows on a phone,
  and cannot be drawn wrong. ER fragment and lifecycle stay as inline SVG, worked out complete and to
  scale in `page-template.html`, with the grid stated in a comment above each.

  Four files have to agree: the template holds the geometry and the SVG class vocabulary,
  `report-format.md` § *Depth rules* holds which kind belongs to which section and the budget (and
  holds them **only** — the template does not restate the budget), `SKILL.md` step 9 points at the
  catalogue and says which two are components, and `evals/checks/diagram.sh` carries the class
  vocabulary the template defines. A class added to one and not the other is either unstyled or
  reported as invented. `legend` and `box-json` were removed from that vocabulary deliberately, not
  renamed: a run drawing a blast radius as SVG should be told to use the component instead.

  `--brief` draws no § 5 figures at all — no ER fragment, no lifecycle; migration safety is a row
  there — so its merged section holds the `.blast` panel and nothing that could compete for the
  budget, and `diagram.sh`'s per-`<section>` count needs no level awareness. What it must not become is
  a reason to skip the one figure a *flow* earns.

  The reason this is an invariant rather than a nicety: a diagram is the one component with no
  generator behind it, so a layout derived per run spends the run's attention on geometry instead of
  on whether the edges are true — and makes two pages from this skill incomparable. What a script
  can check is conformance; crowding, overlap and an arrowhead landing beside its box need eyes,
  which is what `checks/diagram-shot.sh --visual` and a judged expectation are for. Both defects in
  that sentence were found in diagrams the script had just called clean.

  Two rules no check can enforce, so they live in `report-format.md` § *Depth rules*: a box grid
  cannot express a **directed edge** (when the finding is "the code stops being produced at this
  hop", the note under the panel has to say it), and **a diagram carries labels, not sentences** —
  prose in an 880-wide scroller cannot reflow, so searches and caveats go in the `figcaption`.

  **No current fixture earns either surviving kind.** `rails-only-small` adds one nullable column and
  `monorepo-contract` has no state machine, so `evals/cases/diagrams.json` now tests that a run
  reaches for the *components* rather than SVG. Covering ER and lifecycle properly needs a new
  fixture with a migration and a status enum; until then those two catalogue layouts are checked by
  `diagram.sh` against the template itself and by nothing else.
- **Theme tokens.** Every colour is defined on bare `:root` *and* redefined in both dark blocks
  (`prefers-color-scheme` and `[data-theme="dark"]`). A colour declared only inside a media query is
  the classic unreadable-artifact bug. `evals/checks/page-invariants.sh` § 6 enforces the three
  states and `excerpts.sh` enforces it for the excerpt tints specifically, which are the newest
  colours and so the likeliest to be forgotten in two of the three.

  The `--syn-*` syntax tints are the newest of these and the easiest to half-declare, because nothing
  on the page depends on them to be readable — a set missing from the dark blocks is invisible until
  someone opens an excerpt with the OS in dark mode.

  Worth knowing when editing: the source design is **light-only**, and the dark half is ours. So the
  pairs that invert — `.checkpoint`, `.att-read`, `.pipe`'s terminal node, `.bx-on` — are written
  against tokens rather than literals precisely so they keep inverting *relative to the page* rather
  than flipping to an unreadable combination in one theme.

## Deliberately single-context

The skill runs in one context. It spawns no subagents, and that is a choice, not an omission — an
earlier iteration fanned out to `Explore` agents per layer, and it came out.

`SKILL.md`'s hard rules now say so outright, which they did not before: a real run reached for one
`Explore` agent and stalled the parent for 997 seconds — 41% of its wall clock — in a single blocked
turn. A boundary stated only here is a boundary the skill has never been told about.

The reason is that the decomposition is the *next* thing to get right, not something to inherit
half-specified. Two of this version's steps span the whole diff by nature: step 5 traces consumers
across both sides of the stack, and step 6 groups behaviour that no single layer contains. Splitting
those by layer is exactly the mistake the page exists to correct — it would move comprehension
fragmentation from the human to the agents, and the synthesis step would have to reassemble what the
split threw away.

So a very large diff will strain this version. That is the signal the next iteration is meant to act
on, which is why `SKILL.md` tells the skill to *report* the strain (say which region it skimmed)
rather than quietly skim. When specialists do arrive, the seam is per-flow, not per-layer, and the
orchestrator's job is reconnecting them into end-to-end behaviours.

### The unsolved half: how to sample a diff too large to read

`SKILL.md` says to report the strain. It does not say how to *choose* what to skim, and that gap is
the one thing a 112-file run exposed that has not been fixed. Naming it here so the next iteration
starts from the real question rather than rediscovering it.

The run in question — 112 files, 14.8k insertions, a Rails API and a Next.js client in one diff — got
through the goal, the blast radius and five verified affected-but-unchanged findings, and would have
needed several times that budget to finish the behaviour flows and a 112-row ledger. Nothing about it
failed. It simply ran out of room, in a way the procedure has no policy for.

**`--brief` is not the answer to this, and it will be reached for as though it were.** It reduces the
number of sections; the 112-file run did not run out of room writing section shells, it ran out
tracing consumers and explaining flows, and `--brief` changes neither. A strained run at `--brief` owes
the same statement of which region it skimmed.

What makes this hard is that the honest sampling strategy runs against the skill's own instincts:

- **The completeness invariant is not the same as reading everything.** Every path must appear in the
  page; the depth rules already say most appear as a ledger row. So the question is not "which files
  do I cover" but "which files do I *open*", and the ledger is what makes a shallow pass on the rest
  legitimate rather than a silent gap.
- **Cheap signals exist and are unused.** Line counts per file, the status letter, whether a file has
  a matching spec, whether it is named in a commit message, whether anything outside the diff
  references it. `ledger-rows.sh` already prints the first two. A defensible sampling rule could be
  built from them without opening anything.
- **The sections are not equally compressible.** Persistence and the API contract are small and
  load-bearing, and skimping there is what makes a page wrong. Behaviour flows are where the volume
  is, and a flow read at half depth still teaches the shape. So the budget should be spent
  unevenly, and the skill currently gives no basis for that.
- **Whatever is skipped has to be visible.** A skimmed region must say so in place, in the same voice
  as a stated limit, not in a footnote nobody reads. The build states already carry the vocabulary for
  this — a fifth shape alongside written, pending, not written and omitted.

Decomposition may dissolve some of this: a per-flow agent has its own context, so the aggregate
budget grows. It does not dissolve all of it — the orchestrator still has to decide how many flows
are worth an agent, and that is the same question one level up.

## The other unsolved half: `--review`

`--review` is declared, parsed, and stops. `SKILL.md` § *The review level is not implemented yet* has
the runtime behaviour; this is the design brief, written down so the next iteration starts from the
real question. It is meant to run the project's code-review pass as well and thread its findings
through the map.

**It is not "run `/code-review` and paste the output", and the reason is the product principle.** A
code-review pass produces graded findings — severity, confidence, a ranked list. This page carries no
verdict, structurally: the template has no chip that expresses one, and reintroducing a severity
vocabulary is named above as the single easiest way to undo this iteration. So the naive
implementation breaks the invariant the whole format is built to hold, and it will look like a feature
while doing it.

**The seam that resolves it, and the reason this level is worth building at all:** a review finding
enters the page as a **claim to verify**, never as a finding to display. Two steps already do that
work. Step 8 says read the file yourself before any claim reaches the page, and drop what does not
survive. Step 5 routes a consequence to the code it reaches. So a verified finding lands in the flow
that owns it — in *things to understand*, or *reviewer questions*, or *affected but unchanged* — in
the page's own voice, with the review's severity label stripped. An unverified one is dropped, by a
rule that already exists. The review pass becomes a *search strategy* feeding step 5, which is
exactly where this skill is weakest, rather than a section of imported conclusions.

Four things to settle before writing it:

- **It probably needs a sixth evidence tier**, something like *reported by the review pass, verified
  against the file*. Five tiers are an invariant four files agree on (`report-format.md`, the
  template's `span.tier`, `page-invariants.sh` § 3, and the cases), and the asymmetry that only four
  of them carry a label is deliberate. Adding one is a real change, not a footnote — and the
  alternative is defensible: a verified finding is just *evidenced by unchanged code* or *explicitly
  changed* like any other, and where the claim came from is provenance rather than evidence.
- **It is the first place the skill depends on something outside itself.** Everything else assumes
  only Claude Code plus a git repo. `/code-review` ships with the CLI, but a project may have its own,
  and the boundary against assuming project layout applies here too: discover the review command,
  do not assume it. A repo with none should degrade to `--full`, saying so.
- **Findings and flows do not line up one to one.** A review comments per hunk; this page is organised
  per behaviour. A finding spanning two flows, or landing in a file no flow owns, needs the same
  routing decision § *One canonical home* already answers — which is encouraging, because it means the
  rule exists, and it means the mapping has to be written down rather than left to the run.
- **The hard rule against posting anywhere is not relaxed.** A page that now contains review material
  is still a page, and still never a comment on the PR.

One thing not to do: publish a page and mark the review part *pending*. Pending is a promise, and
nothing is writing it.

## Boundaries the skill must keep

These are deliberate scope limits, not omissions — do not "improve" the skill past them.

- **It helps a reviewer decide; it does not decide.** The page carries evidence, relationships,
  invariants, uncertainty and validation steps. It never carries a verdict. `/code-review` is a
  different tool answering a different question — and `--review`, when it exists, will not change
  that: it borrows the review's *search*, not its conclusions. See § *The other unsolved half*.
- It never posts to GitHub or anywhere outside the artifact.
- It never writes the page into the repository under review — a work directory under `$TMPDIR` only,
  **derived** in step 1 from the repo and the target rather than chosen per run.
- It re-publishes to the same file path on a re-run, so one PR keeps one URL across pushes. That is
  the reason the path is derived and not picked: a session-scoped scratch directory is a different
  directory next session, so "the same path again" needs a rule, not a memory. Profiling a run that
  had no rule found nine calls and seventy seconds spent re-establishing a path and moving excerpt
  files that had been written somewhere else first.
- It assumes only Claude Code plus a git repo containing a Rails app. Everything else — Rails root
  location, RSpec vs Minitest, API-only vs server-rendered, auth library, whether a frontend exists
  and where its client and types live — is discovered, never assumed. Adding an assumption about
  project layout is a regression.
- The frontend is a first-class half of the contract, not a frontend review. The page follows fields
  and error cases across the boundary; it does not critique component design.

## Editing style

The skill's prose carries its own reasoning: rules state *why*, and several include the observation
that produced them. Preserve that when editing — a rule stripped to an imperative loses the thing
that makes a model follow it under pressure. Match the existing register: direct, specific, no filler.
Documentation-only changes still belong in the same voice as `README.md`, which is the public face of
the project.

## Publishing

`.claude-plugin/plugin.json` is the plugin manifest. Its `version` is the update pin: users only
receive a change once that field moves, so bump it in the same commit as the change and tag the
release.

```bash
claude plugin validate . --strict
claude plugin tag --push          # creates accountable-review--v<version>
```

The marketplace catalogue lives in a separate repository, `wyeworks/claude-plugins`, whose
`.claude-plugin/marketplace.json` is named `wyeworks` and points at this repo:

```json
{
  "name": "accountable-review",
  "source": { "source": "github", "repo": "wyeworks/accountable-review" },
  "description": "Turns a pull request into a published review map a reviewer can read before judging the change."
}
```

Keep `version` out of that entry — `plugin.json` wins when both are set, and one source of truth is
less to forget. A catalogue entry may pin `ref` or `sha` instead if a release needs holding back.

Two things do not belong at the plugin root: a `CLAUDE.md` (it ships to every install but is never
loaded as project context, which is why this file lives in `.claude/`), and any component directory
inside `.claude-plugin/` — only the manifest goes there.
