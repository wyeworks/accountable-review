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

**When a Review Map is generated** — the push trigger and the bot authors. Each decides whether a
model run happens at all, which is why neither can wait until one is already running.

How big a change has to be is *not* among them, though it decides the same thing, and § *The
application-code gate* has the reason: the counts that settle it are over application paths, which
the event payload cannot express. Those numbers are ordinary run-time configuration.

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

**Size is not decided here**, and `--min-files`, `--min-lines`, `--size-gate` and `--no-size-gate`
are accepted and render nothing. They are kept rather than removed because a workflow generated by
0.28.0 carries them in its `# Decisions:` line, and `install-workflow.sh` feeds that line back on the
next upgrade — rejecting them would turn "move the version pin" into a hard failure on exactly the
repositories that had set a threshold. The renderer says so on stderr and points at the config keys.

## Two ways to write that expression that GitHub rejects

Both shipped, in a real repository, and each cost a pull request to undo. Neither is visible to a
YAML parse — the file parses locally and is rejected upstream, with no job created and an error
naming neither the line nor the reason — which is why `tests/run.sh` asserts both structurally and
why the template carries the warning inline.

**There is no arithmetic in a GitHub Actions expression.** The grammar is `()`, `[]`, `.`, `!`, the
comparisons, `==`, `!=`, `&&` and `||`. `(additions + deletions) > 50` is an invalid-file error, not
a sum. That expression is no longer in the guard — the counts moved to a step, where shell can add —
but the rule is what makes putting them back here impossible rather than merely wrong, and
`tests/run.sh` still asserts it against whatever the expression holds. `tests/self-test.sh` injects
the arithmetic to prove the assertion fires.

**In a folded scalar (`>-`), a more-indented line is not folded.** Its newline survives into the
expression string and invalidates the file. Every line of the expression sits at exactly six spaces,
and the operators lead their lines partly to remove the thing anyone would be tempted to align. The
guard has no parentheses to align today; the indentation rule is what keeps that true of whatever
clause is added next.

## The line that records the decisions

```yaml
# Decisions: --no-regenerate-on-push --skip-authors dependabot[bot] --pr-comment
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

## The previous map

Only with `--regenerate-on-push`, and only because that flag creates the thing this needs: a second
run over the same pull request.

```yaml
      - name: Restore the previous Review Map
        uses: actions/cache/restore@v4
        with:
          path: ${{ runner.temp }}/review-map
          key: accountable-review-map-${{ …number }}-${{ …head.sha }}
          restore-keys: accountable-review-map-${{ …number }}-
```

and, after delivery, an `actions/cache/save@v4` under the same key.

**What it is for.** With the previous page sitting where the run is about to write,
`ci/generate-review-map.sh` passes `--update` and the skill re-reads only the commits since that
page's revision instead of rebuilding it — `review-map`'s § *Re-running over new commits*. Without
the restore that flag reaches nothing in CI, because `$RUNNER_TEMP` dies with the runner and a
second run starts from an empty directory.

**A miss is not a failure, and nothing here is load-bearing for correctness.** The whole flag is a
saving with a cost — claims nobody re-read — so every way it can go wrong has to lead to the page
that has no cost. A cold cache, an evicted entry, a first run: all of them regenerate in full, which
is the better page.

**Two existing rules are what make restoring a page safe**, and neither was added for this:

- A half-written page restored here carries a pending marker, and `carry-plan.sh`'s preconditions
  refuse to update from one.
- A run that dies *after* the restore leaves a page still naming the old head — because
  `SKILL.md` step 9 makes the `Revision` cell the last edit of an update — and the generate step
  already refuses to deliver a page that does not contain the current short head SHA. So the
  failure mode that would matter most, shipping an old map as a current one, is caught by a check
  that predates the cache.

**Why not download the previous artifact.** It needs `actions: read`, a new standing permission on
a workflow whose permission design is an invariant, and it would make this file a second thing that
knows the map is an artifact — the delivery seam unpicked, and broken the moment a team sets
`provider:` to a static host. The previous map has to be restored by something that does not know
where the map goes. The cache API rides the default token and asks for no scope at all.

**The key is a run-time expression, which is what keeps the file idempotent.** `${{ }}` is
evaluated by Actions, not by `render-workflow.sh`, so two renders of the same request are the same
bytes — the rule § *The line that records the decisions* draws for the `# Decisions:` line, applied
to a value nobody would think of as configuration. A date in that key, reached for to expire an
entry, would make every second setup run report drift.

**The restore sits ABOVE the step that decides the verdict, and carries no guard.** It used to sit
below, guarded on `verdict == 'generate'`, which was right while the only thing it fed was
generation. It now also feeds the second half of the decision itself — see § *The application-code
gate* — so it has to run first, and a guard on the verdict it is consulted for would be circular.
Restoring ~80 KB unconditionally is cheaper than the model run it is deciding about, and on a cold
cache it is a no-op.

**ripgrep is installed on demand, and only when a previous map came back.** Both halves of
reusing a map — `carry-plan.sh`'s P6 and, through it, `map-still-current.sh` — replay the page's
own recorded searches, and every search recipe in the lens files is written with `rg`, which a
GitHub-hosted runner does not have. Without the package each recorded search hits P6's
tool-not-installed branch and refuses, so the run rebuilds the page: correct, and the whole saving
gone. The guard is `steps.previous.outputs.cache-matched-key != ''` rather than `cache-hit`,
because the key carries the head SHA and the restore-key prefix is what actually matches — a
`cache-hit` guard would be false on exactly the runs this step exists for.

**It cannot fail the job, and that is the polarity rather than defensiveness.** The install is an
optimisation; when it does not work the page is rebuilt, which is the answer that costs more and
is never wrong. A step that could turn a Review Map into a red job to save a few minutes has this
backwards, so the block ends in an `|| echo` and a run with no ripgrep says so in its log.

**The save carries `if: success()`.** Correctness does not depend on it, per the rules above; it
keeps the cache holding pages that actually shipped rather than whatever was in the directory when
a step died.

**And the concurrency group above changes what this sees.** A cancelled run saves nothing, so a
burst of pushes leaves one entry from the last completed run and the next update works over a
bigger delta. That is the right direction: a bigger delta is a fuller re-read, and past half the
diff `carry-plan.sh` refuses the update and the run regenerates.

Whether updating happens at all is `review_map.update` in `.accountable-review.yml`, read at run
time like every other setting about the map. It is deliberately not a flag here: it changes what
the map is, not *when* a map is generated, which is this file's one settings axis.

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

### Where each one comes from

The workflow names the variables and not their source, which is the half a team has to be told.

**`ANTHROPIC_API_KEY`** is an API key created in the Anthropic Console. The run is billed to that
organisation's API account.

**`CLAUDE_CODE_OAUTH_TOKEN`** is what `claude setup-token` prints. Run it once, on a machine where
Claude Code is already signed in:

```bash
claude setup-token
```

It runs the OAuth flow and prints a single token; that string is the whole value of the secret, and
it goes into Settings → Secrets and variables → Actions → New repository secret under exactly that
name. The run is then billed against that account's **Claude subscription** rather than API credit,
which is the reason to choose it: a team already paying for Claude Code needs no second billing
relationship to generate Review Maps.

Three things about that token before choosing it over an API key.

It is **personal**. The token carries one person's account, so every Review Map in the repository is
generated as them, under their limits.

It is **long-lived rather than permanent**. A workflow green for months can start failing on
authentication with nothing in the repository having changed. The fix is `claude setup-token` again
and a new value in the same secret; nothing about the workflow moves.

It is **still only a secret**, so the fork rule is unchanged — a `pull_request` run from a fork gets
neither variable, which is why that case is skipped rather than made to work.

And the boundary that does not move either way: **setup writes the workflow and never the secret.**
`claude setup-token` runs on your machine and its output goes to GitHub's secret store; nothing in
this plugin reads it, at setup or at run time.

## The application-code gate

```yaml
- name: Does this pull request change application code?
  id: scope
```

Every step after it is guarded by `if: steps.scope.outputs.verdict == 'generate'`. Two questions,
asked in that order by `ci/application-code.sh`:

1. **Does it change application code at all?** A lockfile bump, a README fix, a workflow tweak, a
   batch of new specs — there is nothing for a map to explain.
2. **Is what it changes more than trivial?** Skipped when the application files are at or under
   `trivial_files` **and** the application lines are at or under `trivial_lines`. Defaults: 2 and
   20.

The verdict and which rule produced it are on stdout and in the step outputs, and the job summary
prints both along with every path and its line count.

### AND, and the polarity that makes it look wrong

A skip needs **both** measurements small. So a 900-line change in one file is generated, and so is a
9-line change across six files — each clears one threshold and not the other. Read from the
generating side that is an OR, which is the same rule seen from the other end; both halves are in
`tests/run.sh` as `bulky` and `spread`, and `self-test.sh` breaks the `&&` into a `||` to prove they
fire.

The reason for AND rather than OR is the asymmetry of being wrong. A map generated for a change that
did not need one costs a model run somebody ignores. A map *not* generated is invisible — nobody
notices the document they did not receive — so the predicate that suppresses one should be hard to
satisfy, not easy.

### The counts are over application paths only

This is what makes them mean anything, and it is the whole reason the gate cannot be a condition on
the job. A three-line model change beside a five-thousand-line lockfile is a three-line change here.
The `pull_request` event payload offers `additions`, `deletions` and `changed_files` over the entire
diff, so a threshold written there would call that pull request enormous — and with the lockfile
counted, the trivial rule would essentially never fire. `tests/run.sh` has that case as `masked`.

The payload also has no file list, so the first rule could not live there either. Hence a step, after
the checkout, with the plugin clone moved ahead of the Node install so a pull request that turns out
to need no Review Map never installs a toolchain.

### The thresholds are configuration, not design

Unlike the triggers and the guards, these are numbers a team should own. They live in
`.accountable-review.yml` as `review_map.trivial_files` and `review_map.trivial_lines`, read from the
checkout at **run** time, so changing one never means regenerating the workflow — and there is no
number in the rendered YAML to edit. `tests/run.sh` asserts the absence of both the payload fields
and the flag names.

**Either at `0` switches the second rule off**, because no change containing application code has
zero application files or lines. That is the opt-out for a team that wants a map for every change to
code, and it needs no third key to spell it.

0.28.0 shipped these as render flags on the job's condition instead. § *The guard* has what happened
to `--min-files` and the other three, and why they are still accepted.

### What the default costs, said plainly

The numbers are a first calibration, not a measurement: two files and twenty lines is roughly where a
change stops being a rename or a log line. The honest caveat is that a Review Map's value tracks what
a change *reaches* more closely than how big it is — the unchanged code whose meaning it alters — and
a three-line edit to a constructor default or a serializer reaches further than most large diffs.
Those are the changes the second rule discards first, and a team that finds it has lost one it wanted
should lower `trivial_lines` or set it to 0 rather than work around it.

### Fail open, and what is not excluded

A path is application code unless the script recognises it as not: tests, documentation, repository
tooling, and the generated files, binaries and lockfiles `diff-render.sh` already identifies.
Anything unanticipated counts as code. The exclusion list is deliberately narrow, and narrowness is
cheap for the first rule — a skip needs *every* path excluded, so one file misfiled as a test changes
nothing unless the whole diff is. It matters more for the second, where a misfiled path also drops
its lines from the count.

Note what is **not** excluded. `config/` is where a Rails app keeps its routes and its initializers;
a Dockerfile and a compose file describe how the thing runs. Those are application code here, and a
directory-name exclusion that swept them up would take a routing change with them.

Two known limits, both failing towards a missing map. A repository whose product *is* prose has
application changes under `*.md` that this counts as documentation. And a team with an unusual layout
can keep code under a directory named in the exclusion list. The job summary is what surfaces either:
it lists every discounted path with its reason.

### Asked again, over the commits since the map we already have

The gate above measures `BASE...HEAD`. With `--regenerate-on-push` that is the wrong range for the
second and every later run: a README-only push to a branch that changed application code earlier
still answers `generate`, because the pull request contains application code and nothing in that
range can see that *this push* did not. The map that comes out says what the last one said.

So the question is asked a second time, over `<previous head>..<head>`, by
`ci/map-still-current.sh`. It adds no rule of its own — it composes `application-code.sh` over the
delta with `carry-plan.sh` over the restored page — and it **downgrades the scope step's own
verdict** rather than introducing a second one. That is why no guard below it moved: every later
step already stands aside on `verdict != 'generate'`, and § *The steps, in order*'s skip-explaining
step already fires on `verdict == 'skip'`.

**Only `no-application-code` counts, never `trivial`.** Those are one answer to the gate's own
question — is this worth a model run — and two different answers to this one. A trivially small
application change is still a change to the code the map describes, and one line in a file a
checkpoint cites is exactly where a page has quietly stopped being true.

**The second half is not belt and braces.** `application-code.sh` classifies tests as not
application code, so a test-only push satisfies the first half alone — while a checkpoint citing
`spec/models/project_spec.rb:12` may now point at a moved line, and a reader following that citation
lands somewhere else. `carry-plan.sh` already answers *did the delta touch anything this page
cites*, so the hole closes by composition rather than by a new rule.

**What it does not do is rewrite the page**, and that is a decision rather than an omission. A
docs-only push changes the diff's file count and its inventory, not just the head SHA, so refreshing
the masthead means editing model-authored HTML — the metric cells, the foot's `all N changed paths`,
the inventory block — where a pattern that misses leaves a stale number on a page that still looks
current. That is the one failure this product cannot tolerate, bought with a cosmetic gain. The map
stands at the revision it names, the PR comment already names that revision, and the reader can hold
the two SHAs against each other.

The skip says which rule fired and the counts behind it, like every other skip here, because a
wrong one has to be reportable rather than invisible.

## The steps, in order

1. **Check out the pull request** at its head SHA, full history, no credentials persisted.
2. **Clone Accountable Review** at its release tag, outside the workspace.
3. **Restore the previous Review Map**, when the workflow regenerates on push, and install ripgrep
   if something came back. The restore is unguarded and sits above the verdict it helps decide,
   because the step below consults it; the install is guarded on the restore having matched, and
   cannot fail the job. Both in § *The previous map*.
4. **Decide whether there is anything worth explaining** — `ci/application-code.sh`, above: no
   application code, or too little of it. On a re-run `ci/map-still-current.sh` asks the same
   question again over the commits since the restored map, and may downgrade the same verdict. Every
   step below is guarded on it, and a skip writes a job summary naming which rule fired and the
   numbers it judged against.
5. **Set up Node and install Claude Code**, pinned to a major version.
6. **Generate the Review Map** — `ci/generate-review-map.sh`, which runs the `review-map` skill
   non-interactively and writes a static directory to `$RUNNER_TEMP/review-map`, outside the
   repository. It then checks the three things a person would have noticed by looking: that the page
   exists and is a page, that it no longer says it is still being written, and that it names the
   revision it describes.
7. **Resolve delivery** — `ci/delivery/deliver.sh`, which asks the configured provider where the map
   goes and returns a DeliveryResult. See `delivery.md`.
8. **Upload the artifact**, guarded by `if: steps.delivery.outputs.provider == 'github-artifact'`, so
   a team that switches provider does not have to edit this step out. The name and the retention come
   from the provider's outputs rather than being repeated in YAML.
9. **Write the job summary**, so the run itself says where the Review Map went and what it is for —
   or, on a skip, which rule skipped it and what it counted.
10. **Comment the link on the pull request**, when that decision is on. Below.

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
