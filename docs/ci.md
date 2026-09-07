# Review Maps in CI

`/accountable-review:setup-ci` writes one GitHub Actions workflow so every review-ready pull request
gets a Review Map the whole team can open. The [README](../README.md#ci-integration-) covers what you
get; this is the part underneath — where the page ends up, and how to send it somewhere else.

## Artifacts are the default, not the contract

**Review Maps are portable static HTML.** The default setup stores them as GitHub Actions artifacts
because that needs no hosting, no extra credential, no external service and no manual step to share
them. The cost is honest and worth naming: an artifact has to be downloaded and extracted before
anyone can read it.

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
