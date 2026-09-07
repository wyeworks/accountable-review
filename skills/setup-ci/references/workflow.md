# The generated workflow

What is in `.github/workflows/accountable-review.yml`, and why each part is the way it is. The file
itself is `templates/workflow.yml` — this explains it, and the two must not drift: a decision
described here and absent there is a decision nobody made.

Almost nothing in it is configurable, deliberately. The triggers, the draft guard, the concurrency
group and the permissions are the design rather than settings — a knob on each is a way to end up
with a setup that generates Review Maps for draft pull requests, which is the thing this is for.
What a team does configure lives in `.accountable-review.yml` and is read at **run** time, so
changing it never means regenerating this file. See `config.md`.

## Triggers

```yaml
on:
  pull_request:
    types: [ready_for_review, synchronize, reopened]
```

Three types, not the default set and not `[opened, ...]`. The behaviour that follows:

| What happens | Result |
|---|---|
| A draft pull request is opened | Nothing |
| Commits are pushed while it is a draft | Nothing |
| It is marked ready for review | A Review Map |
| A commit is pushed after that | The Review Map is regenerated |
| It is reopened | A Review Map |

**`opened` is absent, and that leaves one real gap: a pull request opened directly as ready for
review fires only `opened`, so it gets its first Review Map on its next push.** The three types above
are the intended set — they describe a workflow where work starts as a draft and becomes reviewable —
and the gap is the price. Say it during setup for a team that opens pull requests ready, because they
will otherwise conclude the setup is broken. Adding `opened` to the list is a one-line change and the
draft guard below still holds, so nothing else has to move; what it costs is a Review Map for every
pull request opened ready and then pushed to twice in the next ten minutes.

`labeled`, `edited`, `assigned` and the rest are absent for a different and firmer reason: none of
them changes the code under review. A Review Map describes a revision, and an event that produces no
new revision has nothing to regenerate.

## The draft guard

```yaml
if: >-
  github.event.pull_request.draft == false &&
  github.event.pull_request.head.repo.full_name == github.repository
```

The first clause is what makes `synchronize` affordable: that event fires for pushes to draft pull
requests too, and without the guard every commit of an in-progress branch would spend a model run on
a description nobody has asked for yet.

The second skips pull requests from forks, and it is a security boundary rather than a preference.
A `pull_request` run from a fork gets no secrets, so the job would fail at the credential check on
every external contribution — noise that reads as a broken pipeline. The fix that suggests itself,
`pull_request_target`, is the one to refuse: it runs with this repository's secrets in the context of
a branch the contributor controls. A tool that reads a pull request's code is exactly the wrong place
for that.

For a repository whose contributions are mostly from forks, this is a stated limit. Say it during
setup rather than letting them discover it.

## Concurrency

```yaml
concurrency:
  group: accountable-review-${{ github.event.pull_request.number }}
  cancel-in-progress: true
```

Scoped to the pull request, so two pull requests never block each other, and superseded runs are
cancelled rather than finished. Push A, B and C in a minute and only C's Review Map survives — the
other two would describe revisions nobody is reviewing, and each one costs a model run.

This is the single cheapest thing in the file and the one most often left out.

## Permissions

```yaml
permissions:
  contents: read
```

Declared at the workflow level, so no job in it can quietly acquire more. The job reads a pull request
and writes a document; `contents: read` is all of that. It never pushes, never comments, never
approves, never merges, never labels.

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

## What the workflow must never do

- Run the application under review: no `bundle exec`, no migrations, no database service, no
  `docker compose`, no scripts from the pull request. The Review Map is built from source and tests.
  This is a property of the product — `review-map` proposes validation commands and never runs them —
  and CI must not become the place that quietly does.
- Write to the repository, comment, approve, merge, or set a check with a verdict in it.
- Use `pull_request_target`.
- Carry any secret beyond the model credential.
