# `.accountable-review.yml`

The repository's configuration for Accountable Review. Optional, small, and meant to stay that way.

```yaml
review_map:
  mode: brief            # brief | light
  effort: high           # high | low

  delivery:
    provider: github-artifact
    retention_days: 30
    command: ./bin/publish-review-map   # provider: command only
```

That is the whole schema. Every key is optional; a file may set one of them.

## The keys

| Key | Default | Meaning |
|---|---|---|
| `review_map.mode` | `brief` | Vestigial, and kept so an existing file keeps working. The Review Map has one shape, so `brief` and `light` mean the same page and neither reaches the run. `full` and `review` are rejected rather than silently downgraded — `full` used to mean a seven-section page, and handing back the agenda under that name is a setting that changed meaning without saying so |
| `review_map.effort` | `high` | How hard the run works to be right. `high` sends an adversarial pass at the run's own analysis before the page is written, and changes nothing about the page's shape; `low` skips it. `normal` is accepted as the old name for `low` |
| `review_map.delivery.provider` | `github-artifact` | Where the finished map goes. See `delivery.md` |
| `review_map.delivery.retention_days` | `30` | How long the artifact is kept, 1–90. GitHub's own repository setting still caps it |
| `review_map.delivery.command` | — | The command the `command` provider runs. Meaningless for any other provider |

## Precedence

```
explicit flags  >  .accountable-review.yml  >  defaults
```

Implemented, not aspirational: `read-config.sh` emits a line only for a key the file actually
contains, so a caller distinguishes "configured to the default" from "not configured" and its own
flag wins over both. Every consumer applies its defaults with `${CFG_x:-default}` after that.

## When to write one

**Only when a value differs from the default.** A file that restates them is one more thing to keep
in sync, and it reads as a decision someone made — so a later reader treats `retention_days: 30` as
load-bearing when nobody chose it.

If a team wants nothing unusual, the right outcome of `/accountable-review:setup-ci` is a workflow and
no config file at all.

## It is read at run time

The workflow does not bake these values in. `generate-review-map.sh` and `deliver.sh` read the file
out of the checkout when they run, which has two consequences worth knowing:

- **Changing the config does not mean regenerating the workflow.** Edit the file, and the next run
  respects it.
- **The file comes from the pull request's checkout**, so on a pull request it is whatever that branch
  says. That is harmless for a detail level or a retention period. It is not harmless for
  `provider: command`, which is why that provider refuses to run unless
  `ACCOUNTABLE_REVIEW_ALLOW_COMMAND=1` is set in the environment — and the generated workflow does not
  set it. See `delivery.md`.

## An unknown key is an error

`read-config.sh` fails on a key it does not recognise, rather than ignoring it. A misspelled
`retention_day` that parsed as nothing would give a team the default retention while their file said
otherwise, and nothing would ever tell them. Failing loudly is the only version of this that is
honest.

The same rule keeps the schema small: adding an option means adding it to the parser, to this table,
and to whatever reads it — three places, on purpose, so a configuration surface cannot grow by
accident. Do not add a key for something that does not exist yet.
