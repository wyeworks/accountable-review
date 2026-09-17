# Review Maps in CI

`/accountable-review:setup-ci` writes one GitHub Actions workflow so every review-ready pull request
gets a Review Map the whole team can open. The [README](../README.md#ci-integration-) covers what you
get; this is the part underneath — where the page ends up, and how to send it somewhere else.

## Not every pull request gets one

A Review Map explains application code — what a change means, and what it reaches in code it did not
touch. Two kinds of pull request get none, and the run says which in its job summary rather than
finishing silently.

**It changes no application code.** Documentation, tests, repository tooling, lockfiles, generated
files and binaries are the things that do not count. If that is all a pull request touches, there is
nothing for a map to explain.

**Its application change is trivial.** Two files or fewer *and* twenty lines or fewer — both, not
either. A 900-line change in one file earns a map; so does a nine-line change across six. Only a
change that is small by *both* measurements is skipped.

Everything is counted over application paths only, which is what makes the numbers mean anything: a
three-line model change beside a five-thousand-line lockfile is a three-line change.

```yaml
review_map:
  trivial_files: 2
  trivial_lines: 20
```

Both are read from `.accountable-review.yml` when the workflow runs, so changing one takes effect on
the next pull request with no setup to re-run. **Setting either to `0` turns the trivial rule off**
and gives you a map for every change that touches application code.

The defaults are a starting point rather than a measurement, and the trade is worth knowing: a map's
value tracks what a change *reaches* more closely than how big it is, and a three-line edit to a
constructor default can reach further than a large rename. Those are the changes the threshold
discards first. If you find you have lost a map you wanted, lower `trivial_lines`.

The list of what is not application code is deliberately narrow, and anything it does not recognise
counts as code — so an unusual layout costs you a map you did not need rather than losing one you
did. The job summary lists every path it discounted and why, so a wrong call is something you can
see.

## A second run reuses the first

By default a pull request gets one Review Map, at the moment it becomes reviewable. Set the workflow
up with `--regenerate-on-push` and it gets one per push instead — and from that point the runs reuse
each other: the workflow caches the map it produced, the next run restores it, and the skill re-reads
only the commits since that page's revision rather than rebuilding the whole thing.

**What it costs is stated on the page.** A judgment the new commits did not reach was not verified
again, so the masthead names both revisions — `head → base · updated from <earlier head>` — and one
sentence under *What changed* says which parts still describe the earlier one.

**If you want the fuller read, ask for a map from scratch.** That is what `review_map.update: false`
does, unconditionally, and it is the right setting before a final review pass on a branch that has
moved a lot. A map generated in one pass describes one revision throughout.

It also refuses on its own and regenerates in full, saying which reason it hit: a force-push or
rebase, a base branch that moved underneath, a delta covering more than half the diff, a dependency
lock file bump, a cache that expired, or one of the page's own recorded searches now finding the
changed code. Every one of those leads to the page that has no cost, which is why a cold cache is
not something to worry about.

## Artifacts are the default, not the contract

**Review Maps are portable static HTML.** The default setup stores them as GitHub Actions artifacts
because that needs no hosting, no extra credential, no external service and no manual step to share
them. The cost is honest and worth naming: an artifact has to be downloaded and extracted before
anyone can read it.

**The workflow comments the link on the pull request**, which is the answer to the other half of the
problem — a map nobody can find is a map nobody reads, and nobody opens a workflow run to check
whether there is one. One comment, updated in place rather than repeated, naming the revision the map
describes. That is the only thing the job writes anywhere, and the only reason it holds
`pull-requests: write`; it sets no check and no status, because a passing check is a verdict and this
page does not carry verdicts.

The comment reads the DeliveryResult below rather than knowing about artifacts, so a team that moves
to a browsable provider gets a clickable link in the comment without changing the comment.

Claude Artifacts are deliberately *not* the CI default. They are an excellent destination — it is
where the interactive skill publishes — but automatic organisation-wide sharing is not a reliable
zero-configuration path today, so nothing in the architecture depends on them.

## Generation and delivery are separate

```text
Review Map generation  →  review-map/index.html  →  delivery provider
```

Generation writes a static directory and knows nothing about where it ends up. That seam is what
makes artifacts a sensible default rather than a commitment: a team that later puts Review Maps on a
static host changes one line of configuration, and nothing about how the page is produced changes.
The long-term contract is the static directory in the middle, not the provider under it.

A provider is one script that says where it went:

```json
{ "provider": "github-artifact",
  "location": "accountable-review-pr-412-a93bd21",
  "browsable": false,
  "stable_url": null }
```

| Field | Meaning |
| --- | --- |
| `provider` | Which provider handled it |
| `location` | Where it went, in whatever form that provider uses — an artifact name, a URL, a bucket key |
| `browsable` | Whether a human can open it as a web page, or has to download and extract first |
| `stable_url` | A URL that stays valid after the run, or `null` |

`browsable` is the field a caller acts on, and it is the honest expression of what the default costs:
`false` means a reviewer downloads a zip before they can read anything. A static host returns
`browsable: true` and a URL people can click.

Adding one — S3, R2, an internal static host, a Claude Artifact — changes nothing about how the page
is produced, which is the whole point of the seam. A generic `command` provider is already there for
teams that would rather write four lines of their own shell than wait for an adapter.

## Writing a provider

A provider is one executable file, `ci/delivery/<name>.sh`. It reads `AR_*` from the environment —
`AR_DIR`, `AR_REPOSITORY`, `AR_PR`, `AR_BASE_SHA`, `AR_HEAD_SHA`, `AR_RETENTION_DAYS`, `AR_COMMAND` —
and prints `key=value` lines. `location` is required; `browsable` and `stable_url` are optional.

That is the entire interface, and it should stay this thin. The abstraction exists to stop generation
depending on GitHub artifacts, not to model every hosting provider in the world.

`skills/setup-ci/references/delivery.md` is the full contract, `references/workflow.md` explains
every part of the generated workflow, and `references/config.md` has the whole
`.accountable-review.yml` schema and its precedence rule.
