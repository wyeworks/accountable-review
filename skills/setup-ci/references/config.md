# `.accountable-review.yml`

The repository's configuration for Accountable Review. Optional, small, and meant to stay that way.

```yaml
review_map:
  effort: high           # high | low
  mentor: rails          # true | false | rails | elixir | phoenix
  update: true           # re-read only the new commits on a second run
  trivial_files: 2       # skip when application files <= this AND
  trivial_lines: 20      #   application lines <= this; either at 0 disables it

  delivery:
    provider: github-artifact
    retention_days: 30
    command: ./bin/publish-review-map   # provider: command only
```

That is the whole schema. Every key is optional; a file may set one of them.

## The keys

| Key | Default | Meaning |
|---|---|---|
| `review_map.effort` | `high` | How hard the run works to be right. `high` sends an adversarial pass at the run's own analysis before the page is written, and changes nothing about the page's shape; `low` skips it. `normal` is accepted as the old name for `low` |
| `review_map.mentor` | `false` | The one key that changes what is **on** the page, for a team onboarding reviewers into the stack: a framework primer inside the checkpoints that earn one, and nothing else. Everything else about the page is what a run without it writes, so a mentor page with its primers deleted is the ordinary page. A stack name is a claim the run **checks** against the repository rather than an override — the run stops if they disagree — and while a stack's documentation catalogue is closed the flag produces no primers at all and says so in the log |
| `review_map.trivial_files` | `2` | With `trivial_lines`, the size below which a pull request gets no Review Map. Both are compared with **and**, so a change that is large by either measurement earns one: 900 lines in one file, or 9 lines across six. Counted over **application paths only** — a lockfile's five thousand lines are not in the total. `0` here or on `trivial_lines` switches the rule off, since nothing containing application code has zero of either |
| `review_map.trivial_lines` | `20` | The line half of the same rule, added plus deleted. The numbers are a first calibration rather than a measurement, and the trade is stated in `workflow.md` § *The application-code gate*: what a change *reaches* predicts a map's value better than its size does, so a small edit with wide consequences is what this discards first. Lower it, or set it to 0, if a team finds it has lost one it wanted |
| `review_map.update` | `true` | Whether a second run over the same pull request re-reads only the commits since the previous map and edits it in place, instead of rebuilding it. It reaches nothing unless the workflow regenerates on push, since a pull request that gets one map has no second run — and nothing unless the previous page was restored, which is the workflow's cache step. What it buys is most of a run; what it costs is that a judgment the new commits did not reach was not verified again, which the page says in its masthead and in one sentence. Every way an update can refuse — a force-push, a moved base, a delta past half the diff — falls back to a full generation, so `false` is for a team that wants that unconditionally |
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
  says. That is harmless for an effort level or a retention period. It is not harmless for
  `provider: command`, which is why that provider refuses to run unless
  `ACCOUNTABLE_REVIEW_ALLOW_COMMAND=1` is set in the environment — and the generated workflow does not
  set it. See `delivery.md`.

## What does not belong here: when a Review Map is generated

The triggers, the draft and fork guards and the bot authors are **not** config keys and must not
become them. They are the workflow's `on:` and `if:` — there is nothing for a run-time read to
change, because by the time anything reads this file GitHub has already decided whether to create the
job. They are edited in the workflow or re-confirmed by re-running setup, and `install-workflow.sh`
recovers them rather than reverting them, so a re-run is cheap. See `workflow.md` §§ *Triggers* and
*The line that records the decisions*.

**`trivial_files` and `trivial_lines` are the exception, and the line between them is worth stating
because it is not where it looks.** They decide the same thing the guard decides — whether a model
run happens — so the instinct is that they belong beside it. They do not, because what they count is
application paths, and `changed_files`, `additions` and `deletions` in the event payload are the
whole diff with no file list attached. A threshold written into the `if:` could only measure the
wrong thing. So the decision is made after the checkout, by `ci/application-code.sh`, reading the
real diff — and once it is made there it is an ordinary run-time read like every other key here.

That is also why the earlier answer to "can we tune the thresholds without re-running setup" has
changed to yes. `workflow.md` § *The application-code gate* owns the rule.

## An unknown key is an error

`read-config.sh` fails on a key it does not recognise, rather than ignoring it. A misspelled
`retention_day` that parsed as nothing would give a team the default retention while their file said
otherwise, and nothing would ever tell them. Failing loudly is the only version of this that is
honest.

The same rule keeps the schema small: adding an option means adding it to the parser, to this table,
and to whatever reads it — three places, on purpose, so a configuration surface cannot grow by
accident. Do not add a key for something that does not exist yet.
