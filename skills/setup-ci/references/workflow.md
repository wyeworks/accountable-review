# The generated workflow

What is in `.github/workflows/accountable-review.yml`, and why each part is the way it is. The file
itself is `templates/workflow.yml` — this explains it, and the two must not drift: a decision
described here and absent there is a decision nobody made.

Most of it is not configurable, deliberately. The concurrency group, the permissions, the checkout
and the steps are the design rather than settings, and what a team configures **about the map** lives
in `.accountable-review.yml` and is read at **run** time, so changing it never means regenerating
this file. See `config.md`.

The exception is two sets of decisions that cannot be run-time settings, because they are the
workflow's own structure. They are rendered from flags, defaulted to the answers below, confirmed
with the user in `SKILL.md` step 3, and recorded in the file's own `# Decisions:` line so that a
later run moving the version pin does not revert them.

**When a Review Map is generated** — the push trigger, the bot authors, the size gate and its two
numbers. Each decides whether a model run happens.

**Whether the link is commented on the pull request** — the one decision that changes what the job is
*permitted* to do, since the comment is the whole of `pull-requests: write`.

That is the test any further knob has to pass: it decides whether a run happens, or what the job may
do. A knob on the draft guard or on `contents: read` buys a user nothing and is a way to end up
generating Review Maps for draft pull requests, or carrying a write scope for a step that is not
there.

## Triggers

```yaml
on:
  pull_request:
    types: [opened, ready_for_review, reopened]
```

Three types, not the default set, and `synchronize` deliberately absent. The behaviour that follows:

| What happens | Result |
|---|---|
| A draft pull request is opened | Nothing |
| Commits are pushed while it is a draft | Nothing |
| It is opened already ready for review | A Review Map |
| It is marked ready for review | A Review Map |
| It is reopened | A Review Map |
| A commit is pushed to a ready pull request | **Nothing.** The map is not regenerated |

**A pull request gets one Review Map, at the moment it first becomes reviewable.** That is the
default because the map is a reading aid for the review that is about to start, and the review starts
once. Regenerating on every push means a model run per commit, on branches that routinely take five
or ten after review opens.

**The cost is real and it is quiet: the map describes the revision that made the pull request
reviewable, so on a branch that keeps moving it goes stale without saying so.** Nothing on the page
announces that the code changed under it — the revision in the masthead is the only way to tell,
which is exactly why that is a page invariant rather than a nicety. Say it during setup.

`--regenerate-on-push` adds `synchronize` and inverts the trade: the map always describes the current
head, and the concurrency group keeps a burst of pushes costing one run rather than one per commit.
Nothing else moves — the draft guard below already covers `synchronize` firing for pushes to drafts.
It is the right answer for a team whose branches keep moving through review, and the wrong one for a
team that pushes fixup commits all afternoon.

`labeled`, `edited`, `assigned` and the rest are absent for a firmer reason than either: none of them
changes the code under review. A Review Map describes a revision, and an event that produces no new
revision has nothing to regenerate.

## The guard

```yaml
if: >-
  github.event.pull_request.draft == false
  && github.event.pull_request.head.repo.full_name == github.repository
  && github.event.pull_request.user.login != 'dependabot[bot]'
  && (github.event.pull_request.changed_files > 2
  || github.event.pull_request.additions > 50
  || github.event.pull_request.deletions > 50)
```

**Drafts.** `opened` fires for a pull request opened as a draft, so without this clause every draft
would cost a model run the moment it was opened. It is also what keeps `--regenerate-on-push`
affordable, since `synchronize` fires for pushes to drafts too.

**Forks**, and this one is a security boundary rather than a preference. A `pull_request` run from a
fork gets no secrets, so the job would fail at the credential check on every external contribution —
noise that reads as a broken pipeline. The fix that suggests itself, `pull_request_target`, is the
one to refuse: it runs with this repository's secrets in the context of a branch the contributor
controls. A tool that reads a pull request's code is exactly the wrong place for that. For a
repository whose contributions are mostly from forks, this is a stated limit; say it during setup
rather than letting them discover it.

**Bots.** A dependency bump is not a change a Review Map helps with: there is no judgment to stage
and no reading order to give. Dependabot opens its pull requests ready for review rather than as
drafts, and a daily schedule across two ecosystems at ten open pull requests each is a lot of model
runs for changes nobody reads a map of. The clause tests the pull request **author**, not
`github.actor`, because a human who reopens or marks ready a bot's pull request becomes the actor
while the bot stays the author. `--skip-authors` takes a comma-separated list, one clause each;
`--no-skip-authors` drops it.

**Size.** A two-file, fifty-line change does not ask for enough judgments to be worth a model run.
The gate runs when the change is big on **any** axis, so a one-file rewrite and a twenty-file rename
are both still covered. `--min-files` and `--min-lines` move the numbers; `--no-size-gate` removes it.

Two things about the size gate a team should hear once. A line count cannot see what makes a change
hard — a twenty-line change to an authorization check is subtle and gets skipped, while a lockfile
churn sails past the threshold — so the numbers are worth replaying against a repository's own recent
pull requests rather than trusting. And **a skipped pull request produces no run at all**, so "too
small for a map" and "the workflow is broken" look identical from the outside. That silence is what
makes the gate cheap and it is also its whole cost.

## Two ways to write that expression that GitHub rejects

Both shipped, in a real repository, and each cost a pull request to undo. Neither is visible to a
YAML parse — the file parses locally and is rejected upstream, with no job created and an error
naming neither the line nor the reason — which is why `tests/run.sh` asserts both structurally and
why the template carries the warning inline.

**There is no arithmetic in a GitHub Actions expression.** The grammar is `()`, `[]`, `.`, `!`, the
comparisons, `==`, `!=`, `&&` and `||`. `(additions + deletions) > 50` is an invalid-file error, not
a sum, which is why the two line counts are compared separately against the same number. The two
forms are not identical — separate comparisons let through a change with both counts between 26 and
50 — but they select the same pull requests in practice, and the sum is not available at any price.

**In a folded scalar (`>-`), a more-indented line is not folded.** Its newline survives into the
expression string and invalidates the file. Every line of the expression sits at exactly six spaces,
and the operators lead their lines partly to remove the thing anyone would be tempted to align. Do
not align the parentheses.

## The line that records the decisions

```yaml
# Decisions: --no-regenerate-on-push --skip-authors dependabot[bot] --min-files 2 --min-lines 50 --pr-comment
```

The canonical, complete form of every confirmed decision, in the flags setup takes them as, written
into the file's header. `install-workflow.sh` reads it back and passes it to the renderer ahead of
whatever the current call asked for, so the current call's flags still win and everything else
survives.

**It is there because the ordinary reason to run setup twice is to move the version pin**, and
without the read-back that run would report every confirmed decision as drift and then revert them
all under `--update` — setup reverting a team's decision while claiming to upgrade them, which is the
worst thing this command can do and the thing the drift rule exists to prevent. With it, the upgrade
diff is three lines: the pin, in the comment, the step name and the env.

It carries every decision rather than only the ones that differ from the defaults, so that reading it
requires no knowledge of what the defaults were the day it was written. And it is a pure function of
the flags — no date, no run id, nothing that varies between two renders — because idempotency is
decided by comparing bytes, and anything that varied would make every second run report drift.

A file with no such line recovers nothing and is compared against the defaults. That is the honest
answer rather than a guess: nothing recorded what was chosen, so nothing can be preserved. When the
line is missing, `SKILL.md` step 3 confirms again rather than assuming — which matters most for the
comment decision, where guessing wrong either re-adds a step a team removed or silently drops a scope
they agreed to.

## Concurrency

```yaml
concurrency:
  group: accountable-review-${{ github.event.pull_request.number }}
  cancel-in-progress: true
```

Scoped to the pull request, so two pull requests never block each other, and superseded runs are
cancelled rather than finished. Push A, B and C in a minute and only C's Review Map survives — the
other two would describe revisions nobody is reviewing, and each one costs a model run.

This is the single cheapest thing in the file and the one most often left out. It does most of its
work under `--regenerate-on-push`, and it stays in the file either way: with pushes off it still
covers a pull request toggled ready/draft/ready or reopened in quick succession, and it is what keeps
the cost of turning pushes back on to one run per burst rather than one per commit.

## Permissions

```yaml
permissions:
  contents: read
  pull-requests: write   # only when the comment step is rendered
```

Declared at the workflow level, so no job in it can quietly acquire more. `contents: read` covers
reading a pull request and writing a document. `pull-requests: write` covers exactly one thing, the
comment below, and is rendered **only** when that step is — `--no-pr-comment` removes both together,
because a repository carrying a write scope for a step that is not there is a standing grant nobody
can account for.

Even with it, the token cannot push, cannot touch contents, cannot approve, cannot merge, cannot
label and cannot set a check.

**Actions has no per-step permissions, so the scope is the job.** What keeps it away from the step
that runs a model over a contributor's branch is a different mechanism: Actions injects
`GITHUB_TOKEN` into no step that does not name it, and only the comment step puts it in its `env`.
`tests/run.sh` asserts that exactly one step in the whole file names the token, because that
containment is the reason the scope is acceptable and it is one careless `env:` away from gone.

Treat the checked-out pull request as untrusted input, because it is: a contributor's branch can
contain anything. Two habits in the file follow from that, and both are easy to lose in an edit:

- **Event data goes through `env:`, never into the text of a `run:` block.** A `${{ github.event.pull_request.title }}`
  interpolated into shell is how a branch gets to run commands on the runner. The values this workflow
  uses are numbers and SHAs, which are safe by shape — passing them through the environment anyway is
  what keeps the pattern intact when someone adds a field that is not.
- **`persist-credentials: false` on the checkout.** Nothing in the job uses git authentication, so
  leaving a token in `.git/config` next to code from a pull request buys nothing.

## Checkout depth

```yaml
with:
  ref: ${{ github.event.pull_request.head.sha }}
  fetch-depth: 0
```

Explicitly the head SHA, so the Review Map describes the revision that triggered the run rather than
a merge commit GitHub synthesised, which is what `pull_request` checks out by default and which
matches no commit either side can see.

`fetch-depth: 0` because the Review Map is built from `BASE...HEAD` and its most valuable material is
the code the diff did **not** touch — callers, serializers, queries, tests. A shallow clone does not
make that fail loudly; it makes it quietly wrong, which is worse. The generation script checks that
both SHAs are present and refuses to spend a model run if they are not.

## Installing the plugin

```yaml
run: |
  git clone --quiet --depth 1 --branch "$PLUGIN_REF" \
    "https://github.com/$PLUGIN_REPO" "$RUNNER_TEMP/accountable-review"
```

A clone at a tag, rather than `claude plugin install`, for one reason: **`claude plugin install` takes
no version.** A marketplace install resolves to whatever the catalogue points at the day it runs, so
two runs a month apart could produce Review Maps from different versions of this skill with nothing
in either to say so. The release tag `claude plugin tag` creates is a real pin, and the workflow
records it in a comment at the top of the file and in the step name.

It clones into `$RUNNER_TEMP`, outside the workspace, so the plugin never appears in the diff under
review — `review-map` inspects the working tree and would report the clone as uncommitted changes.

`render-workflow.sh` defaults the ref to the version of the plugin that generated the file. Upgrading
means re-running `/accountable-review:setup-ci`, which reports the change as a diff.

**The tag has to exist.** Setup cannot check — it has no network — so a workflow generated from an
unreleased checkout pins a tag nothing resolves, and the failure arrives later, on someone's pull
request, as a clone error. If you are running from a checkout rather than an installed release, say
so, or pass `--plugin-ref` a ref that exists.

## The credential

```yaml
env:
  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

Either one. A repository already running Claude Code in CI usually has one of them, which is why
setup looks for it before asking for a new one. Both are absent from every other step in the file:
the delivery and upload steps do not need a model.

`generate-review-map.sh` fails immediately, with a message naming the two variables, when neither is
set. That failure is deliberately distinguishable from a failed run — nothing was generated and
nothing was spent.

## The steps, in order

1. **Check out the pull request** at its head SHA, full history, no credentials persisted.
2. **Set up Node and install Claude Code**, pinned to a major version.
3. **Clone Accountable Review** at its release tag, outside the workspace.
4. **Generate the Review Map** — `ci/generate-review-map.sh`, which runs the `review-map` skill
   non-interactively and writes a static directory to `$RUNNER_TEMP/review-map`, outside the
   repository. It then checks the three things a person would have noticed by looking: that the page
   exists and is a page, that it no longer says it is still being written, and that it names the
   revision it describes.
5. **Resolve delivery** — `ci/delivery/deliver.sh`, which asks the configured provider where the map
   goes and returns a DeliveryResult. See `delivery.md`.
6. **Upload the artifact**, guarded by `if: steps.delivery.outputs.provider == 'github-artifact'`, so
   a team that switches provider does not have to edit this step out. The name and the retention come
   from the provider's outputs rather than being repeated in YAML.
7. **Write the job summary**, so the run itself says where the Review Map went and what it is for.
8. **Comment the link on the pull request**, when that decision is on. Below.

## The comment

The last step, and the only thing this job does to the repository.

```yaml
- name: Link the Review Map on the pull request
  if: steps.upload.outputs.artifact-url != '' || steps.delivery.outputs.browsable == 'true'
```

**Why it exists.** The job summary already said where the map went, and nobody opens a workflow run
to find out whether there is something worth opening. A map that is generated, uploaded and unread is
the failure this whole skill exists to prevent, and the earlier rule — that the workflow posts
nothing at all — was producing it. The link goes where the reviewer already is.

**It links what delivery said, not an artifact.** A provider returning a browsable URL gets that URL
commented as a page; the artifact provider has none, so the artifact's own download link is used and
the wording says it is a zip to extract. Reading the DeliveryResult rather than reaching past it is
what keeps this step from becoming a second thing that knows where the map goes — see `delivery.md`.

**It is upserted, not appended**, against the hidden marker `<!-- accountable-review -->`. The job
runs once per pull request by default, but a ready/draft/ready toggle or a reopen runs it again, and
three identical comments teach people to scroll past all of them. Only the first match is edited, so
a race that somehow produced two leaves the spare visible rather than silently orphaned.

**It names the head SHA.** That is the one defence against the staleness a workflow without
`synchronize` accepts: a reviewer who sees a SHA that is not the tip knows the map is behind. It is
the same fact the page's masthead carries, put where someone will actually meet it.

**What it must never become.** A check run, a status, a review, a label, an approval — and nothing in
the comment that grades the change. A link is where the reviewer is; a green "Review Map" check is
the product principle undone, because a passing check is a verdict whatever it is named. That request
will come, phrased as making the map visible in the status list, and the comment is already the
answer to it.

## What the workflow must never do

- Run the application under review: no `bundle exec`, no migrations, no database service, no
  `docker compose`, no scripts from the pull request. The Review Map is built from source and tests.
  This is a property of the product — `review-map` proposes validation commands and never runs them —
  and CI must not become the place that quietly does.
- Write to the repository's contents, approve, merge, label, or set a check or status of any kind.
  One comment carrying a link and a revision is the entire write surface.
- Put `GITHUB_TOKEN` in any step but the comment step.
- Use `pull_request_target`.
- Carry any secret beyond the model credential and that token.
