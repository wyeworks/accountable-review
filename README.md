# accountable-review 🧭

> [!NOTE]
> **Beta — early stages.** This is still under active development, and things may change or
> break between commits. We plan to have a ready-to-use version in the coming days.

> **AI-assisted code review for teams that want to move faster with coding agents without losing control of their codebase.**

`accountable-review` turns a pull request into a **Review Map**: a published HTML page that guides a
reviewer through what changed, how the new behaviour works, what existing code is affected, and what
to understand before merge.

It ships two skills: **`review-map`**, which produces the page for a Rails or an Elixir/Phoenix
codebase, with or without a separate client such as Next.js; and **`setup-ci`**, which arranges for
one to be produced automatically on every review-ready pull request.

Built by **WyeWorks**.

---

## Why? ⚡

AI coding tools can produce large changes much faster than teams can absorb them.

Tests can pass.
AI reviewers can find issues.
Coding agents can fix those issues.

And still:

> **Do you understand how the system works now?**

That is the problem `accountable-review` focuses on.

When code enters the codebase faster than the team understands it, short-term speed can become
long-term loss of control. That gap has a name —
[comprehension debt](https://addyosmani.com/blog/comprehension-debt/) — and it comes due the first
time someone has to change the code nobody read.

---

## AI code review ≠ AI-assisted code review 🤖 + 👩‍💻

**AI code review** is great at asking:

- Is there a bug here?
- Is this implementation suspicious?
- What should be fixed?

`accountable-review` helps the human reviewer ask:

- What behaviour now exists?
- Why was it introduced?
- How do the pieces work together?
- What existing assumptions now matter?
- What should I remember when maintaining this later?

The plugin does **not** approve the PR for you.

> **It helps a competent reviewer understand the change well enough to decide.**

No approval verdict.
No severity score.
No fake confidence badge.

Human judgment stays final. A page good enough to approve from without reading the code would be a
failure — the reviewer would be holding a verdict instead of a mental model.

---

## Diffs are necessary. They are no longer sufficient. 🔍

Diffs are excellent for reviewing code line by line.

```text
Is this condition correct?
Is this query efficient?
Did this line introduce a regression?
```

But modern AI-assisted development also pushes review to a higher level:

```text
What behaviour changed?
How does this work across the system?
What must the team understand to maintain it?
```

A **Review Map** adds that layer.

---

## Review behaviours, not file lists 🗺️

A diff is organized by files.

A Rails or Phoenix feature is not.

One behaviour may cross:

```text
routes
  ↓
controller
  ↓
model / service
  ↓
policy
  ↓
job
  ↓
serializer
  ↓
frontend contract
```

On Phoenix the hops are different — router, controller or LiveView, context, changeset, `Repo`,
worker, template — and the point is the same: no directory contains the behaviour.

`accountable-review` traces the PR around the **behaviour being implemented**, not the order of
files in the diff — and then publishes the part of that work you have to act on: the handful of
judgments the change asks of you, and where to look to make each one. Persistence, the endpoint
contract and the frontend boundary get no sections of their own, on purpose: one behaviour crosses
all three, and giving each its own section means describing that behaviour three times.

---

## The most important code may not have changed 👀

A PR can change the meaning of code without changing its lines.

Examples:

- an existing policy now controls a new flow,
- an existing model invariant becomes load-bearing,
- an unchanged serializer gains new meaning,
- an existing query gets a new caller,
- a TypeScript type now participates in a changed backend contract.

A normal diff cannot show those relationships.

A Review Map can.

> **The lines stayed the same. The system around them did not.**

Finding that code is the expensive half of the work, so the page also **records what was searched**.
An empty result reads as evidence rather than as omission, and every recorded search is a command you
can re-run.

---

## What is a Review Map? 🧭

A Review Map is a **review agenda**: the smallest set of things you have to judge before you can
approve a change, with the code that settles each one attached.

Four parts, and a shut evidence block at the foot:

```text
What changed                    one paragraph: what is now true that was not
What needs your attention       3-5 checkpoints per independent change the PR makes, 7 at the
                                outside; each one judgment, framed as a question
Read the code in this order     3-7 stops, in the order that builds understanding
Impact outside the diff         1-3 chains, from changed code into code it gives new meaning to,
                                each node linked to the file it lives in
▸ Evidence & diff coverage      every changed path, the searches run, the rest of what was found
```

A **checkpoint** is the primitive. Not a category — *ProjectSearcher implementation* names a file —
but a judgment you could get wrong. Most are about what the change now does; **at most one per page
is about how it was built** — where a class was put, what kind of object it is, which existing
abstraction it went around — and that one only ever appears when the page can point at the place your
codebase already answers the same question, so it reads as *why is this one different?* rather than as
a style guide. It asks; it does not answer.

```text
Is nil → cross_facility an intentional semantic default?

  The constructor now defaults a missing facility rather than raising, and two searchers
  read that value. On /transactions the current facility is nil, so the fallback decides
  what the page scopes to.                                    from unchanged code

  Look at

    The nil default
    where a missing facility becomes cross_facility instead of raising
    BaseSearcher#initialize:14-19

    The consumer that widens with it
    reads the value without checking which facility it came from
    ProjectSearcher#options:31

  Open question  Whether cross-facility scope is intended there, or an artefact of the
                 constructor change.
```

Claims about unchanged code come with the code attached: a collapsed excerpt of the real source,
quoted by a script rather than retyped, that you open when you are ready to check that particular
claim. The page reads completely with every excerpt closed — the sentence carries the consequence,
the excerpt carries the proof.

The Review Map does **not** replace the diff.

It helps the diff make sense.

📖 Full anatomy of the page — every section, the checkpoint, the staging behaviour, the excerpt and
framework-anchor rules — is in [`docs/review-map.md`](docs/review-map.md).

---

## Evidence over confidence 🔬

The tool separates what is known from what is inferred.

A statement may come from:

- changed code,
- unchanged repository code,
- tests,
- inference,
- or uncertain intent.

A claim the diff shows directly carries no label. Everything else is marked — *from unchanged code*,
*inferred from tests*, *inferred*, *uncertain* — so an inference can never pass as a fact. Where the
tool cannot establish intent, it says so:

> It is unclear whether existing time entries stay editable after archival. No test covers it.

Every claim also carries a `file:line` into your repository, and by default a second reader attacks
those claims before the page is finished (see [Usage](#usage-) → *effort*).

Nor does the page claim to have found everything — see
[What a Review Map cannot do](#what-a-review-map-cannot-do-) below. It never reads as a clean bill of
health, and it never carries a boilerplate disclaimer saying so either: the limits are the same on
every Review Map, so they are written down once, here, rather than reprinted under a heading you have
already read a dozen times.

The goal is not to sound confident.

The goal is to help the reviewer investigate the change.

---

## What a Review Map cannot do 🌫️

A Review Map is written by a model reading your repository. That is what lets it trace a consequence
into code the diff never opened, and it is also the honest limit on the page.

- **It is a pass, not an audit.** Three passes over the same 109-file diff produced eight headline
  findings between them, only one of which appeared in all three. Explanation is reproducible; defect
  discovery is sampling.
- **It has blind spots, and they are not random.** Behaviour living in configuration, in data, in a
  queue, in another service or in the gap between two deploys is harder to reach from a diff than
  behaviour living in a method — so those are the regions a map is quietest about, and quiet is not
  the same as clear. On a very large diff it also runs out of room before it runs out of diff, and
  says which region it skimmed.
- **Some of it can simply be wrong** — a misread method, a framework default that does not hold for
  your version, a consequence prevented somewhere the run never looked. Every claim is labelled by
  how it is known and carries a `file:line`, so open the citation for anything you would act on.
- **It never decides anything.** A map that says nothing about a file is not telling you the file is
  fine, only that this pass surfaced no judgment there.

**And it depends on the model behind it.** We develop and test with Claude Opus 5 most of the time, and that
is what the page's depth is calibrated against. Other models will trade cost for reach differently —
try a few against your own codebase and keep the one whose maps you actually trust.

---

## Rails-first ❤️‍🔥

The plugin is optimized and most heavily tested for Rails applications. That matters because Rails
behaviour often emerges from several pieces working together:

- routes
- controllers
- Active Record models
- validations and callbacks
- policies
- jobs
- serializers
- service objects
- tests
- frontend clients

The plugin is designed to help reviewers understand those relationships as a system, and it knows
where the framework's own rules bite: `update_all` at a call site the diff never opened skips the
validation this PR adds, a uniqueness validation is not a unique index, `--sandbox` rolls back so
`after_commit` never fires there.

It also reads the app for **what your team already decided**. A value object in `app/models` is
ordinary; a value object in `app/models` when four of its kind live in `app/services` is a choice
someone made, and the page will ask whether it was deliberate — with the four siblings cited, because
without them there is nothing to ask. That question is never a recommendation, never appears more than
once, and never takes a slot from a judgment about behaviour.

**Elixir/Phoenix is the second stack** — a LiveView app or a JSON API — with its own lens for the same
job: `Repo.update_all` builds no changeset, a `unique_constraint` does nothing without the index
behind it, and a `phx-click` renamed in a template without its `handle_event` clause crashes the
LiveView the first time someone clicks it. Which of the two you get is detected from the repository, a
`Gemfile` against a `mix.exs`, not configured; a repo holding both asks which to cover.

Where a reviewer needs the framework rule itself, the page anchors it two ways: a documentation link
**pinned to the versions in your own lock file** — the Rails series and gem versions from
`Gemfile.lock`, each package's exact version from `mix.lock` — and a read-only console probe to run
against your own application. Probes are proposed, never run: the skill does not boot your app, so no
output on the page is ever invented.

One asymmetry worth knowing rather than discovering: the Elixir documentation catalogue ships
complete but **unverified**, and until its verification run happens it withholds every link. An
Elixir page anchors with probes and prose and emits no documentation URL — a narrower page, not a
broken one, and the same fail-closed rule the Rails catalogue applies per row.

---

## Philosophy ✨

```text
More AI productivity
        +
More reviewer understanding
        =
More speed without losing control
```

Our goal is simple:

> **Move faster with AI. Stay in control.**

---

## Installation ⚙️

### Claude Code

While this is in beta, point Claude Code at a checkout. Clone the repository:

```bash
git clone https://github.com/wyeworks/accountable-review.git
```

Then start Claude Code from the repository you want to review, passing the checkout with
`--plugin-dir`:

```bash
cd /path/to/your/app
claude --plugin-dir /path/to/accountable-review
```

The skills are available as `/accountable-review:review-map` and `/accountable-review:setup-ci` for
that session. Nothing is installed, so `git pull` in the checkout is how you update.

Installation from the Claude Code plugin marketplace — one `/plugin install`, no checkout to keep
around — is coming soon.

### Codex

Not supported yet. The skill is packaged as a Claude Code plugin and depends on that harness — the
subagent it spawns, and the artifact it publishes to.

---

## Usage 🚀

Run it from inside the repository you are reviewing:

```text
/accountable-review:review-map              # current branch against its base
/accountable-review:review-map 412          # a PR number
/accountable-review:review-map https://github.com/org/repo/pull/412
/accountable-review:review-map feature/some-branch
```

You get back a URL. The page is a private Claude Artifact until you share it, and re-running for the
same PR republishes to the same URL — so the Review Map tracks the PR across pushes instead of
scattering links.

It publishes early and fills in as parts complete: open it at minute two, watch it arrive, start
reading the moment the part you need lands. The checkpoints arrive one at a time, and their
*questions* arrive first — so you know what the change is asking you to judge well before the
explanations land. While it is unfinished it says so in a banner, and every part still coming is
marked pending, so a half-written page can never be mistaken for a finished one.

To have one generated for every pull request instead of by hand, see
[CI integration](#ci-integration-) below.

### One page shape

There is one page, and no flag chooses it:

```text
/accountable-review:review-map 412
```

`--brief` and `--light` are accepted and change nothing — an invocation kept in a script is not a
typo. `--full` and `--review` stop the run and say they are not implemented in this version, rather
than quietly handing back something else under a name that used to mean seven sections.

The page used to have two shapes and a word budget to tell them apart. What a reviewer wants is not a
length setting: it is an answer to *what do I have to judge here, and where do I look?* The analysis
underneath is unchanged and deep — the run traces consumers across the whole diff, reads the tests,
follows values across the boundary and attacks its own conclusions. What reaches the page is the part
you have to act on, which on a small or medium PR is usually 700 to 1,500 words.

Short is not thin. No finding, no citation, no evidence tier and no figure comes out to make a page
shorter, the number of checkpoints is never traded against a word count, and every changed file is
still accounted for.

### How hard it works

A separate axis, orthogonal to the one above:

```text
/accountable-review:review-map 412                 # --effort high, the default
/accountable-review:review-map 412 --effort low    # opt out of the falsification pass
```

Everything the skill writes rests on claims it checked itself — and the context that wrote a claim is
the one least able to see what it assumed. **`--effort high`**, the default, adds a second reader that
does not share that context. The run writes its analysis down first, one note per behaviour, and
sends a read-only `claim-falsifier` subagent at each note **before any of it reaches the page**, with
a single mandate: assume this is wrong in ways that matter, and find evidence in the repository that
contradicts it. It rewrites nothing; it returns challenges, each anchored in a line it opened. The run
then opens the cited file itself and corrects, downgrades or drops the claim. A challenge it cannot
confirm is dropped, exactly as an unconfirmed finding is.

It is on by default because it is very nearly free and it changes what the page finds: on a 28-file
pull request the whole pass cost 23 seconds of waiting, under 1% of the run, and the same change
reviewed without it missed five things the falsified page carried. `--effort low` turns it off, which
is worth doing when the diff is small enough that a second reader has nothing to find.

**The page looks exactly the same either way.** No badge, no marker, no count of what was corrected —
a stamp saying how hard someone looked is the clean bill of health this page must never read as. What
changed is reported to you in the terminal, not to whoever opens the link.

### Onboarding a reviewer into the stack

A third axis, and the only one that puts anything on the page:

```text
/accountable-review:review-map 412 --mentor          # add framework primers
/accountable-review:review-map 412 --mentor rails    # the same, naming the stack
```

A Review Map normally assumes you know the framework and are meeting *this change* for the first
time. `--mentor` is for the other case — a reviewer new to Rails or to Phoenix, on their first
pull requests in an unfamiliar codebase. Where a judgment turns on a framework rule they may not
know, the page stops linking to the manual and states the rule: a short **primer** inside that
checkpoint, with the API named, the behaviour explained, a worked example on a generic class, the
line in *your* repository that made it relevant, and the pinned documentation link it came from.

**It adds primers and it changes nothing else.** Same sections, the same checkpoints in the same
order, same reading path, same impact section, same budget on every other part. Delete the
primers from a mentor page and you have the ordinary page back — which is exactly why it is a flag
rather than a second document, and why there is no "mentor mode" badge on the page: you can see
which one you got.

At most one primer per checkpoint and three per page. A judgment every developer in the stack
already understands earns none, and a run that finds nothing worth teaching writes none — the flag
is not an instruction to explain the framework. If you name a stack it is checked against the
repository rather than believed, so `--mentor rails` in a Phoenix checkout stops the run instead of
applying the wrong lens.

> **Phoenix today:** a primer is gated on the documentation link it escalates from, and the Elixir
> catalogue ships closed until a verification run has opened every row in it. So `--mentor` on a
> Phoenix project currently produces no primers and says so. That is the fail-closed rule doing its
> job — a page with no primer is narrower, a page with an invented link is wrong.

---

## Example Review Map 🖼️

No public example is linked yet — the pages produced so far are private artifacts of real client
pull requests. The fastest way to see one is to run the skill against a branch of your own; a
four-file bugfix produces a one-screen page in a couple of minutes.

What a good example shows:

- a handful of checkpoints, each a question you could answer wrongly, in the order you would most
  regret getting wrong — and nothing anywhere that reads as a severity or a verdict
- affected-but-unchanged code, drawn as chains from the change to what someone would observe, with
  the searches that found it recorded and re-runnable
- evidence vs. inference, labelled per claim
- collapsed source excerpts, quoted verbatim from your repository
- a reading order that builds understanding rather than following the diff
- open questions only the author can answer

---

## CI integration 🔁

One command turns "someone runs the review map by hand, sometimes" into "every review-ready pull
request has one, and the whole team can open it":

```text
/accountable-review:setup-ci
```

```text
pull request marked ready for review
        ↓
Review Map generated for that exact revision
        ↓
uploaded as a GitHub Actions artifact
        ↓
available to everyone who can see the repository
```

Every reviewer opens the same artifact instead of independently reconstructing the same context, and
it is there from the moment the pull request becomes reviewable.

Setup looks at the repository first — what CI you already have, whether Claude Code already runs in
it, what conventions your workflows follow — and then writes one file,
`.github/workflows/accountable-review.yml`. It touches nothing else, and running it twice is safe:
the second run compares what it would write against what is there and says *unchanged*.

### What you get

| | |
| --- | --- |
| Triggers | `opened`, `ready_for_review`, `reopened` — one map per pull request |
| Draft pull requests | Ignored — pushing to a draft costs nothing |
| Fork pull requests | Skipped: a `pull_request` run from a fork gets no secrets |
| Bot pull requests | Skipped: a dependency bump has no judgments to stage |
| Pull requests changing no application code | Skipped — the run says what changed and why none of it earned a map |
| Trivial application changes | Skipped — 2 files **and** 20 lines or fewer of application code; both configurable |
| Delivery | GitHub Actions artifact, kept 30 days |
| The link | One comment on the pull request, updated in place, naming the revision |
| Concurrency | One run per pull request; superseded runs cancelled |
| Permissions | `contents: read`, plus `pull-requests: write` for that one comment |

**Setup shows you those before it writes anything**, because each decides either when a model run
happens on your account or what the job is allowed to do, and asks once. Change any of them there and
the workflow is rendered your way — and re-running setup later to move the version pin reads your
answers back out of the file rather than reverting them.

The comment is the whole of the write scope. The job cannot push, cannot touch your code, cannot
approve and sets no check — and `--no-pr-comment` drops the step and the scope together. There is no
"Review Map: passed" status, and there will not be one: a passing check is a verdict, and this page
does not carry verdicts.

One thing is left for you: **the credential.** Add one of two repository secrets. `ANTHROPIC_API_KEY`
is an API key from the Anthropic Console, billed to that API account. `CLAUDE_CODE_OAUTH_TOKEN` is
what `claude setup-token` prints — run it once on a machine where Claude Code is already signed in,
paste the token in under that name, and the runs bill against that account's Claude subscription
instead of API credit. That is usually what a team already paying for Claude Code wants, and it is
the option the workflow file cannot tell you about, since it names the variable and not where the
value comes from. The token is personal and long-lived rather than permanent: re-run the command and
replace the value when it expires. Setup cannot see your secrets either way, so it says outright that
this is outstanding rather than implying everything is ready.

A pull request that only touches documentation, tests, tooling or a lockfile gets no Review Map —
there is nothing for one to explain. Neither does a trivial application change: two files **and**
twenty lines or fewer, both, so a change that is large by either measurement still earns one. The
counts are over application code only, so a lockfile's five thousand lines do not make a three-line
model change look substantial. Both numbers live in `.accountable-review.yml`, and either at `0`
gives you a map for every change that touches code. `docs/ci.md` has the rule and the trade.

One cost worth knowing, and it is quiet: **a push does not regenerate the map**, so on a branch that
keeps moving it describes an earlier revision while looking current — the revision in its masthead is
how you tell, and `--regenerate-on-push` is how you change it. A skipped pull request is not the same
kind of quiet: the run still happens and its summary says which rule skipped it and what it counted,
so "too small for a map" never looks like a broken workflow.

The workflow is analysis-only, and its entire effect on your repository is that one comment. It never
pushes, never approves, never merges, never labels, sets no check and no status, and it never boots
your application: no migrations, no database service, no scripts from the pull request. That is the
same principle the page itself follows — validation commands are shown to a reviewer, never run on
their behalf.

🚚 Artifacts are the default, not the contract: a Review Map is portable static HTML, and generation
is separated from delivery so a team can send it somewhere browsable instead. See
[`docs/ci.md`](docs/ci.md) for the delivery seam and how to add a provider.

---

## Technical overview 🧩

| | |
| --- | --- |
| **Supported agents** | Claude Code. Two skills — `review-map`, which produces the page, and `setup-ci`, which configures CI — plus one subagent, `claim-falsifier`, sent at each of the run's own analysis notes at `--effort high`. Deliberately single-context otherwise: an earlier version fanned work out to helper agents and paid 41% of its wall clock in a single stalled turn. |
| **Repository analysis** | `git` for the diff, the base and head SHAs, and the searches; `gh` when present, for PR metadata and deep links. Nothing else is required. |
| **Stack detection** | A `Gemfile` or `config/application.rb` selects the Rails lens and catalogue; a `mix.exs` selects the Phoenix pair. A repo with both asks; a repo with neither says so and covers the diff with the stack-independent parts of the page rather than applying a Rails lens to something that is not Rails. |
| **Rails discovery** | Rails root (repo root, a subdirectory, an engine), API-only vs server-rendered, the authorization library, and the Rails series and gem versions from `Gemfile.lock`, which is what documentation links are pinned to. |
| **Phoenix discovery** | The Mix project and OTP app name from `mix.exs`, `lib/<app>` against `lib/<app>_web`, LiveView vs JSON API, and each package's exact version from `mix.lock` — hexdocs serves exact versions, so there is no series. |
| **Frontend discovery** | Whether a separate client exists at all, and where its API client and types live. Contract judgments need both sides in the diff; with no client, or a PR that does not touch one, none is raised rather than raised emptily. A LiveView app has no separate client by design, so the same material goes to the seam it actually has: the `phx-*` attribute and the callback that answers it. |
| **Test frameworks** | RSpec, Minitest and ExUnit, detected rather than assumed. Tests are read as evidence of intent, and the test gap is named per behaviour. |
| **Review Map generation** | Ten ordered steps, from resolving the target to the completeness gate. The diff is traced and clustered by behaviour, then a synthesis step turns that analysis into a ranked agenda of checkpoints; affected-but-unchanged code comes from search recipes per artifact kind; every claim is anchored to a `file:line`. |
| **Output format** | One self-contained HTML page — its own design system, light and dark, with collapsed source excerpts, figures built from components rather than drawn per run, and deep links chosen from a four-rung ladder depending on whether the head SHA is reachable on a remote. On an unpushed branch it degrades to plain text rather than emitting permalinks that would 404. |
| **Publishing** | Interactively, a Claude Artifact — private until you share it, republished to the same path per PR. `--output <dir>` makes the run non-interactive and writes `<dir>/index.html` as portable static HTML instead, which is how CI generates one. The page is never written into the repository under review; scratch files go to a work directory under `$TMPDIR`, derived from the repo and the target. It never posts to GitHub. |
| **Completeness** | One mechanical check at the final publish: set equality between the page's own inventory and `git diff --name-only`. A file cannot be silently dropped. |
| **CI execution** | GitHub Actions, via `setup-ci`: one workflow, superseded runs cancelled, delivery through a provider seam that defaults to a build artifact, and one upserted comment linking the map on the pull request — the only write the job can do, and the only reason it holds `pull-requests: write`. The triggers, the guard that skips drafts, forks and bots, and whether it comments are confirmed with you at setup, rendered from flags, and recorded in the file so a later upgrade does not revert them. Whether a given pull request is worth a map is decided after checkout by `ci/application-code.sh` — no application code, or too little of it — and a skipped run says which rule fired and what it counted. |

---

## Configuration 🛠️

Nothing is required, and that is deliberate: every setting is a thing that can go stale against the
repository it describes.

What you choose per run:

| | |
| --- | --- |
| **Target** | PR number, PR URL, branch, diff range, or nothing for the current branch against its base. |
| **Effort** | `--effort high` (default) or `--effort low`. |
| **Mentor** | Off by default; `--mentor` (optionally `--mentor <stack>`) adds framework primers for a reviewer new to the stack. |
| **Output** | A published artifact by default; `--output <dir>` writes static HTML instead. |

In CI, the same choices live in an optional `.accountable-review.yml` — the whole schema, every key
optional:

```yaml
review_map:
  effort: high           # high | low
  mentor: false          # true | false | rails | elixir | phoenix
  delivery:
    provider: github-artifact
    retention_days: 14
```

`mode` is still read and still validated, and it decides nothing: `brief` and `light` are the same
page, and `full` is rejected rather than silently downgraded.

Precedence is `explicit flags > .accountable-review.yml > defaults`, and it is implemented rather
than aspirational: the config reader emits a line only for a key the file actually contains, so
"configured to the default" is distinguishable from "not configured". `setup-ci` will not write a
file that only restates the defaults — a file nobody chose is one more thing to keep in sync, and a
later reader treats `retention_days: 30` as load-bearing when nobody picked it.

Everything else is discovered instead of configured: which stack this is, the Rails root or the Mix
project, the test framework, whether the app is API-only or LiveView, how authorization is attached,
the frontend location, the framework and package versions, and the project's own conventions. Where
a project documents conventions — `CLAUDE.md`, a style guide — the skill reads them; where it does
not, house style is inferred from adjacent unchanged code, which is usually more accurate than a
stale document anyway.

Repository-specific guidance is therefore expressed the way the rest of your tooling already
expresses it: in the repo's own convention docs, not in a config file belonging to this plugin.
Adding an assumption about project layout would be a regression, so if the skill guesses your layout
wrong, that is a bug worth reporting.

---

## Contributing 🤝

Issues and pull requests are welcome. To run the plugin from a checkout without installing it:

```bash
cd /path/to/your/rails-app
claude --plugin-dir /path/to/accountable-review
```

`/reload-plugins` picks up edits without restarting. There is no build and no test suite in the usual
sense — the "source" is prose that another Claude instance executes, so changes are verified by
running the skill against a real PR and reading the page it produces, plus an eval harness for
judging a wording change against planted findings.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the layout, the eval loop and the release process.

---

## License 📄

[MIT](LICENSE).

---

## About WyeWorks

`accountable-review` is an open-source project by **WyeWorks**.

We build software and help teams adopt AI-assisted development practices without giving up the
engineering understanding required to operate and evolve what they build.

**AI can help us produce more code. The challenge is making sure our teams continue to understand it.**
