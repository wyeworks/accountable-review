# accountable-review 🧭

> **AI-assisted code review for teams that want to move faster with coding agents without losing control of their codebase.**

`accountable-review` turns a pull request into a **Review Map**: a published HTML page that guides a
reviewer through what changed, how the new behaviour works, what existing code is affected, and what
to understand before merge.

Built by **WyeWorks**.
Rails-first. Open source. A [Claude Code](https://claude.com/claude-code) plugin.

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

A Rails feature is not.

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

`accountable-review` reorganizes the PR around the **behaviour being implemented**, not just the
order of files in the diff. Persistence, the endpoint contract and the frontend boundary get no
sections of their own, on purpose: one behaviour crosses all three, and giving each its own section
means describing that behaviour three times.

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

A Review Map is a guided path through the PR.

It helps the reviewer understand:

1. **What is this change for?**
2. **What behaviours were added or modified?**
3. **How does each behaviour work?**
4. **What existing code is affected?**
5. **What should I pay attention to?**
6. **How can I validate important assumptions?**
7. **What questions still need human judgment?**

For each meaningful behaviour, the map can include:

```text
why this exists
implementation
relevant tests
affected but unchanged code
things to understand
how to validate
reviewer questions
```

Claims about unchanged code come with the code attached: a collapsed excerpt of the real source,
quoted by a script rather than retyped, that you open when you are ready to check that particular
claim. The page reads completely with every excerpt closed — the sentence carries the consequence,
the excerpt carries the proof.

The Review Map does **not** replace the diff.

It helps the diff make sense.

📖 Full anatomy of the page — every section, the staging behaviour, the excerpt and Rails-anchor
rules — is in [`docs/review-map.md`](docs/review-map.md).

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

Nor does the page claim to have found everything. Three independent passes over the same 109-file
diff produced eight distinct headline findings between them, with only one appearing in all three.
Explanation is reproducible; defect discovery is sampling. The page says so, and never reads as a
clean bill of health.

The goal is not to sound confident.

The goal is to help the reviewer investigate the change.

---

## Rails-first ❤️‍🔥

The first versions are optimized and tested for Rails applications.

That matters because Rails behaviour often emerges from several pieces working together:

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

The plugin is designed to help reviewers understand those relationships as a system. It also anchors
framework behaviour where a reviewer needs the rule itself: a documentation link **pinned to the Rails
and gem versions in your `Gemfile.lock`**, and a read-only console probe to run against your own
application. Probes are proposed, never run — the skill does not boot your app, so no output on the
page is ever invented.

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

Inside Claude Code — register the marketplace, then install the plugin:

```text
/plugin marketplace add wyeworks/claude-plugins
/plugin install accountable-review@wyeworks
```

Or non-interactively, from a terminal:

```bash
claude plugin marketplace add wyeworks/claude-plugins
claude plugin install accountable-review@wyeworks
```

For a team that wants it enabled for everyone working on a repository, install at project scope so
the plugin is declared in the repo's settings rather than your own:

```bash
claude plugin marketplace add wyeworks/claude-plugins --scope project
claude plugin install accountable-review@wyeworks --scope project
```

Scopes are `user` (default, every project), `project` (checked in, shared with collaborators), and
`local` (this machine, this project, uncommitted).

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
reading the moment the part you need lands. While it is unfinished it says so in a banner, and every
part still coming is marked pending, so a half-written page can never be mistaken for a finished one.

### How much page

```text
/accountable-review:review-map 412              # --brief, the default
/accountable-review:review-map 412 --full
```

**`--brief`** merges the tail of the page — blast radius, cross-cutting consequences, before
approving, coverage — into one section built around the blast radius. Four sections instead of seven.

**`--full`** writes all seven. Reach for it on a diff you are going to live inside for an hour — a
migration, a change spanning both sides of the API, someone else's hundred-file feature.

The level changes how many sections there are, never how deeply the behaviour flows are explained:
the first three sections are identical at both levels, and every changed file appears either way.

**`--review`** — a code-review pass threaded into the map — is declared but not implemented. Passing
it stops the run and says so, rather than producing a page that quietly leaves it out.

### How hard it works

A separate axis, orthogonal to the one above:

```text
/accountable-review:review-map 412                 # --effort high, the default
/accountable-review:review-map 412 --effort low    # opt out of the falsification pass
```

Everything the skill writes rests on claims it checked itself — and the context that wrote a claim is
the one least able to see what it assumed. **`--effort high`**, the default, adds a second reader that
does not share that context: once the behaviour flows are written, one read-only `claim-falsifier`
subagent is sent at each of them, with a single mandate — assume this flow is wrong in ways that
matter, and find evidence in the repository that contradicts it. It rewrites nothing; it returns
challenges, each anchored in a line it opened. The run then opens the cited file itself and corrects,
downgrades or drops the claim. A challenge it cannot confirm is dropped, exactly as an unconfirmed
finding is.

It is on by default because it is very nearly free and it changes what the page finds: on a 28-file
pull request the whole pass cost 23 seconds of waiting, under 1% of the run, and the same change
reviewed without it missed five things the falsified page carried. `--effort low` turns it off, which
is worth doing when the diff is small enough that a second reader has nothing to find.

**The page looks exactly the same either way.** No badge, no marker, no count of what was corrected —
a stamp saying how hard someone looked is the clean bill of health this page must never read as. What
changed is reported to you in the terminal, not to whoever opens the link.

---

## Example Review Map 🖼️

No public example is linked yet — the pages produced so far are private artifacts of real client
pull requests. The fastest way to see one is to run the skill against a branch of your own; a
four-file bugfix produces a one-screen page in a couple of minutes.

What a good example shows:

- behaviour-oriented navigation, with a contents rail that fills in as the page is written
- affected-but-unchanged code, with the searches that found it recorded and re-runnable
- evidence vs. inference, labelled per claim
- collapsed source excerpts, quoted verbatim from your repository
- validation steps as real commands against your app
- reviewer questions only the author can answer

---

## CI integration 🔁

Not shipped yet, and not recommended as a hand-rolled workflow.

The goal is worth stating, because it is what the page is designed around:

```text
PR ready for review
        ↓
Generate shared Review Map
        ↓
Publish once
        ↓
Every reviewer uses the same artifact
```

Half of that already works today without CI: the page republishes to the same URL for the same PR, so
whoever generates it first produces the artifact everyone else reads, and re-running after a push
updates it in place rather than scattering links. What is missing is the unattended half — a runner
identity, a durable place to publish that is not one person's private artifact, and a comment or
check linking the PR to it. Until that is designed, running the skill locally and sharing the URL is
the supported path.

---

## Technical overview 🧩

| | |
| --- | --- |
| **Supported agents** | Claude Code. One skill, `review-map`, plus one subagent, `claim-falsifier`, spawned per behaviour flow at `--effort high`. Deliberately single-context otherwise — an earlier version fanned work out to helper agents and paid 41% of its wall clock in a single stalled turn. |
| **Repository analysis** | `git` for the diff, the base and head SHAs, and the searches; `gh` when present, for PR metadata and deep links. Nothing else is required. |
| **Rails discovery** | Rails root (repo root, a subdirectory, an engine), API-only vs server-rendered, the authorization library, and the Rails and gem versions from `Gemfile.lock`, which are what documentation links are pinned to. |
| **Frontend discovery** | Whether a client exists at all, and where its API client and types live. The frontend sections need both sides in the diff; with no client, or a PR that does not touch one, they are omitted rather than filled in. |
| **Test frameworks** | RSpec and Minitest, detected rather than assumed. Tests are read as evidence of intent, and the test gap is named per behaviour. |
| **Review Map generation** | Ten ordered steps, from resolving the target to the completeness gate. Behaviour flows are found by grouping the diff by behaviour; affected-but-unchanged code is found by search recipes per artifact kind; every claim is anchored to a `file:line`. |
| **Output format** | One self-contained HTML page — its own design system, light and dark, with collapsed source excerpts, inline SVG diagrams from a fixed catalogue, and deep links chosen from a four-rung ladder depending on whether the head SHA is reachable on a remote. On an unpushed branch it degrades to plain text rather than emitting permalinks that would 404. |
| **Publishing** | Published as a Claude Artifact, private until you share it, republished to the same path per PR. The page is never written into the repository under review — scratch files go to a work directory under `$TMPDIR`, derived from the repo and the target. It never posts to GitHub. |
| **Completeness** | One mechanical check at the final publish: set equality between the page's coverage ledger and `git diff --name-only`. A file cannot be silently dropped. |
| **CI execution** | Not supported yet — see [CI integration](#ci-integration-). |

---

## Configuration 🛠️

There is nothing to configure, and that is deliberate: every setting is a thing that can go stale
against the repository it describes.

What you choose per run:

| | |
| --- | --- |
| **Target** | PR number, PR URL, branch, diff range, or nothing for the current branch against its base. |
| **Detail level** | `--brief` (default) or `--full`. |
| **Effort** | `--effort high` (default) or `--effort low`. |

What is discovered instead of configured: the Rails root, the test framework, whether the app is
API-only, the authorization library, the frontend location, the Rails and gem versions, and the
project's own conventions. Where a project documents conventions — `CLAUDE.md`, `.cursorrules`, a
style guide — the skill reads them; where it does not, house style is inferred from adjacent
unchanged code, which is usually more accurate than a stale document anyway.

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
