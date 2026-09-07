# Delivery

Where a finished Review Map goes, and why that is a separate question from how it is made.

```
Review Map generation
        │
        ▼
Portable static output          review-map/index.html
        │
        ▼
Delivery provider               github-artifact | command | …
```

**Generation must not know about the destination.** That is the whole point of the seam, and it is
what makes GitHub Actions artifacts a sensible default rather than a commitment: a team that later
puts Review Maps on a static host changes one line of configuration, and nothing about how the page
is produced changes at all. The long-term contract is the static directory in the middle, not the
provider under it.

## The contract

```
deliver(review_map_path, repository, pull_request_number, base_sha, head_sha) -> DeliveryResult
```

In practice `ci/delivery/deliver.sh`, which prints a DeliveryResult as JSON:

```json
{
  "provider": "github-artifact",
  "location": "accountable-review-pr-412-a93bd21",
  "browsable": false,
  "stable_url": null
}
```

| Field | Meaning |
|---|---|
| `provider` | Which provider handled it |
| `location` | Where it went, in whatever form that provider uses — an artifact name, a URL, a bucket key |
| `browsable` | Whether a human can open it as a web page, or has to download and extract first |
| `stable_url` | A URL that stays valid after the run, or `null` |

`browsable` is the field a caller acts on, and it is the honest expression of what the default costs:
`false` means a reviewer downloads a zip before they can read anything.

A static host would return:

```json
{
  "provider": "static",
  "location": "https://reviews.example.com/acme/app/pr/412/",
  "browsable": true,
  "stable_url": "https://reviews.example.com/acme/app/pr/412/"
}
```

## Writing a provider

A provider is one file, `ci/delivery/<name>.sh`, executable. It reads `AR_*` from the environment —
`AR_DIR`, `AR_REPOSITORY`, `AR_PR`, `AR_BASE_SHA`, `AR_HEAD_SHA`, `AR_RETENTION_DAYS`, `AR_COMMAND` —
and prints `key=value` lines. `location` is required; `browsable` and `stable_url` are optional;
anything else it prints is carried into the result and into `$GITHUB_OUTPUT`, which is how
`github-artifact` hands the workflow an artifact name and a retention.

That is the entire interface, and it should stay this thin. **Do not overengineer this.** The
abstraction exists to stop generation depending on GitHub artifacts — not to model every hosting
provider in the world.

## Who moves the bytes

Some providers move them; `github-artifact` does not. Uploading from a step script means
reimplementing the Actions artifact protocol, so it names the destination and the workflow's
`actions/upload-artifact` step performs the standard upload using the name and retention the provider
returned. The seam is unaffected either way: generation still does not know which of the two happened,
and a different provider makes the upload step stand aside via
`if: steps.delivery.outputs.provider == 'github-artifact'`.

## What exists

| Provider | State |
|---|---|
| `github-artifact` | **The default.** No infrastructure, no extra credential, no external service, no manual sharing step — available to everyone who can already see the repository. Not browsable in place |
| `command` | Implemented. Runs a command the team owns with the Review Map directory as its argument and takes the last URL it prints. The escape hatch that makes the rest unnecessary |
| `claude-artifact` | Designed for, not built. Conceptually an excellent destination — the interactive skill publishes there — but automatic organisation-wide sharing is not a reliable zero-configuration path today, so it must not be the CI default and nothing may depend on it |
| `s3`, `r2`, `static-host` | Designed for, not built. Each is a `<name>.sh` away, and each belongs to whoever needs it |

Adding one of the last four changes nothing in `review-map`, nothing in the workflow, and nothing in
`generate-review-map.sh`. If a change to any of those turns out to be needed, the seam is in the
wrong place — fix the seam rather than threading a destination through generation.

## The `command` provider is opt-in in CI, on purpose

```yaml
review_map:
  delivery:
    provider: command
    command: ./bin/publish-review-map
```

The Review Map directory is passed as the first argument; the last line of output matching
`http(s)://` becomes the URL, and a command that prints none still delivers — it is simply not
browsable.

It refuses to run unless `ACCOUNTABLE_REVIEW_ALLOW_COMMAND=1` is set, and the generated workflow does
not set it. The reason is specific rather than general caution: the workflow checks out the pull
request, so `.accountable-review.yml` at that moment is a file the pull request's author can edit, and
a provider that ran a command named in it would turn "open a pull request" into "run this on our
runner". Locally, and in a workflow a team has deliberately edited, the opt-in costs one line.
