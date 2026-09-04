---
name: setup-ci
description: Configures a repository so Accountable Review generates a Review Map automatically in CI — a GitHub Actions workflow that runs when a pull request becomes ready for review, regenerates on every push after that, skips drafts, cancels superseded runs, and uploads the resulting static HTML as a build artifact the whole team can open. Use this when someone wants review maps generated automatically rather than by hand, asks to add Accountable Review to CI or to GitHub Actions, wants the review map shared with their team instead of published from one laptop, or asks how to run this on every PR. Invoke with /accountable-review:setup-ci. It inspects the repository before writing anything, prefers a dedicated workflow, never modifies unrelated CI, and is safe to run twice. Not for generating a review map — that is review-map — and not for posting anything to GitHub.
---

# Set up CI

Turns "someone runs the review map by hand, sometimes" into "every review-ready pull request has one,
and the whole team can open it."

The result is one workflow file. When a pull request leaves draft, GitHub Actions generates a Review
Map for that exact revision and uploads it as a build artifact; a push to a ready pull request
regenerates it and cancels the run that is now describing the wrong commit. Drafts cost nothing.

**Everything you write here is a file in the repository the user is working in.** This skill posts
nothing, enables nothing on GitHub, and creates no secret. Where a credential is needed it says so
and stops short of pretending it is there.

## The one thing not to do

**Do not write a workflow into a repository you have not looked at.** A generic file dropped into
`.github/workflows/` is how this command becomes something a team deletes: it duplicates a job they
already have, ignores a reusable-workflow convention that every other workflow follows, or replaces a
Claude Code integration they set up last month. Step 1 exists because the inspection is the part that
makes the write safe.

The second is smaller and just as damaging: **do not turn this into a wizard.** Running it with no
arguments must produce a good setup. The defaults in § *What it configures* are opinions, and the
user gets them without being asked five questions first.

## What is bundled

| File | Read at | For |
|---|---|---|
| `references/workflow.md` | step 3 | What the generated workflow contains, and why each part is the way it is — triggers, the draft guard, concurrency, permissions, checkout depth, the credential |
| `references/config.md` | step 4 | `.accountable-review.yml` — the whole schema, the precedence rule, and when writing one is worth it |
| `references/delivery.md` | step 5, or when asked about anything but artifacts | The delivery abstraction: the contract, the providers that exist, and how a team adds one |
| `scripts/inspect-repo.sh` | step 1 | Reports what the repository already has |
| `scripts/render-workflow.sh` | step 3 | Renders the workflow. Deterministic — same flags, same bytes |
| `scripts/install-workflow.sh` | step 3 | Writes it, idempotently, and refuses to clobber a hand-edited one |
| `scripts/read-config.sh` | step 4 | Reads the config file. Also what the CI scripts use at run time |
| `templates/workflow.yml` | — | The workflow itself. Edit this, not a copy in your head |

Paths are relative to the base directory named at the top of this skill when it loads.
`$CLAUDE_PLUGIN_ROOT` is not set in the shell.

## 1. Look at the repository first

```sh
<skill base directory>/scripts/inspect-repo.sh
```

It prints `key=value` lines and decides nothing. Read them, then **open the files they name** — a
count of workflows is not knowledge of them. What you are looking for:

- **Is this a git repository with a GitHub remote?** `git_repo=no` stops the run: say so plainly and
  offer nothing else. `remote_github=no` is worth naming — the workflow will be written but nothing
  will run it until the repo is on GitHub.
- **Is GitHub Actions already in use, and how?** A repository whose every workflow is three lines
  calling a reusable one from a platform repo has a convention, and a standalone workflow ignoring it
  is the wrong shape even though it works.
- **Is Accountable Review already set up?** `accountable_workflow` names it. That is the idempotent
  path — step 3 handles it, and the answer is often "nothing to do".
- **Is Claude Code already running in CI?** `claude_workflows` and `anthropic_secret_used` together
  tell you whether the credential question is already answered. A repository that already runs
  `claude-code-action` has the secret; say which one you found rather than asking for a new one.
- **Conventions worth preserving.** Workflow naming, whether jobs pin actions by sha, a shared
  `runs-on` label, a `CONTRIBUTING.md` that says how CI is organised. Match them where you can.

## 2. Decide where it goes

**Prefer a dedicated workflow.** `.github/workflows/accountable-review.yml`, doing one thing, easy to
read, easy to delete. It is a separate concern from the test suite: it takes minutes, it costs model
tokens, and it must not become a reason a required check is red.

Integrate into an existing workflow **only when it is obviously cleaner** — and the bar is genuinely
high, because integration means editing a file that other people's work depends on. The case where it
is right: the repository has exactly one pull-request workflow, every job in it is added there by
convention, and adding a file would be the odd one out. Even then, add a **job**, never a step inside
someone else's job, and change nothing else in the file.

Two things settle it against integration on their own: the existing workflow has `permissions:` wider
than `contents: read` (this job must not inherit them), or it has no `concurrency` (a Review Map job
without one wastes tokens on superseded runs, and adding one to a shared workflow changes how their
tests behave).

If you integrate, everything in `references/workflow.md` still applies to the job you add — the same
guard, the same permissions block on the job, the same steps.

## 3. Write the workflow

Read `references/workflow.md` now. It explains every part of the file, and you will be asked about
the triggers by the next person who reads it.

```sh
<skill base directory>/scripts/install-workflow.sh --repo-dir . --print-diff
```

It renders and writes, and prints one status line:

| `status=` | What happened | What to do |
|---|---|---|
| `created` | The file did not exist | Report it in step 6 |
| `unchanged` | It was already exactly this | Say so. **This is a success, not a no-op to apologise for** |
| `drift` | It exists and differs | Below |
| `updated` | It was rewritten because you passed `--update` | Say what changed |

**Drift is the interesting case and it is not an error.** Someone edited the workflow — tightened a
timeout, pinned an action by sha, changed the runner. The script prints the diff and writes nothing.
Show the user what would change, in a sentence or two rather than a wall of YAML, and let them choose;
re-run with `--update` only if they say so. Silently reverting a team's edit is the worst thing this
command can do, which is why the script cannot do it by accident.

The rendered file is deterministic — no date, no run id, nothing random — which is what makes running
this twice safe: the second run compares bytes and finds nothing to do. Do not add a timestamp
comment to the workflow for any reason.

**Do not hand-write the YAML**, and do not paste an edited copy of the template. `templates/workflow.yml`
is the source; a run that types its own version produces a file that no longer matches what
`install-workflow.sh` renders, so the next run reports drift against setup's own output.

## 4. Write a config file only if it would say something

Read `references/config.md`. `.accountable-review.yml` is optional and usually unnecessary:

```yaml
review_map:
  delivery:
    retention_days: 14
```

**Write one only when a value differs from the default.** A file whose entire content restates the
defaults is a file the team has to maintain that carries no information, and worse, it reads as
configuration someone chose. If the user asked for nothing unusual, write nothing, and say that the
defaults are in effect rather than leaving them wondering where the settings live.

The config is read **at run time**, by the CI scripts, from the repository — so changing it later
does not mean regenerating the workflow. That is worth telling the user in step 6.

## 5. Delivery is already decided, unless they ask

The default provider is `github-artifact` and it is what the workflow ships with. It needs no
hosting, no credential and no extra service, and it is shared with everyone who can see the
repository the moment the run finishes. The cost is that a Review Map has to be downloaded and
extracted before it can be read.

If the user asks for anything else — a static host, an S3 bucket, a URL people can click — read
`references/delivery.md`. The short version: generation writes a portable static directory, delivery
is one script, and adding a provider changes nothing about how the page is produced. Do not build one
unless they asked for it.

## 6. Say exactly what happened, and what has not

Report in this shape:

```
Accountable Review CI configured.

Created:
  .github/workflows/accountable-review.yml

Review Maps will be generated when:
  - a pull request becomes ready for review
  - new commits are pushed to a non-draft pull request
  - a pull request is reopened

Delivery:
  GitHub Actions artifact, retained 30 days

Draft pull requests are ignored. Superseded runs are cancelled automatically.

Still to do:
  Add ANTHROPIC_API_KEY as a repository secret
  (Settings → Secrets and variables → Actions → New repository secret).
  Until then the workflow will run and fail at the generation step.
```

**The last part is not optional and never gets rounded up.** If the credential is not configured, say
it is not configured. You cannot check a repository's secrets from here, so unless step 1 found a
workflow already reading `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`, list it as outstanding and
say plainly that you could not verify it. A setup message claiming everything is ready, followed by a
red run on someone's first pull request, spends the trust this command needs.

Name the other limits in the same breath, briefly, where they apply:

- **Pull requests from forks are skipped.** They get no secrets, so the job could not authenticate.
  Say so for a repository that takes outside contributions — it is the difference between a
  documented boundary and a feature that mysteriously never fires.
- **A pull request opened directly as ready for review gets its first Review Map on its next push.**
  The triggers are `ready_for_review`, `synchronize` and `reopened`; `opened` is not among them.
  Say this to a team that does not start work as drafts — otherwise their first impression is that
  the setup does not work — and tell them adding `opened` to the trigger list is a one-line change.
  `references/workflow.md` § *Triggers* has the trade.
- **The workflow pins a plugin version**, and setup cannot check that the tag exists — it has no
  network. Review Maps stay attributable to a version of this plugin, and re-running this command
  after an upgrade moves the pin. If you are running from a development checkout rather than an
  installed release, say that the pinned tag may not be published yet: the failure otherwise lands on
  someone's pull request as a clone error.

Then stop. Do not offer to open a pull request, do not commit, and do not push — the files are in the
working tree and the user decides what happens to them. If they ask you to commit, commit only the
files this command created.

## What it configures

Defaults, chosen so that running this with no arguments is the right answer. Every one of them is
explained in `references/workflow.md`.

| | |
|---|---|
| CI platform | GitHub Actions |
| Triggers | `ready_for_review`, `synchronize`, `reopened` |
| Draft pull requests | Skipped |
| Fork pull requests | Skipped — no secrets are available to them |
| Detail level | `brief` |
| Effort | `normal` |
| Delivery | `github-artifact` |
| Retention | 30 days |
| Concurrency | One run per pull request; superseded runs cancelled |
| Permissions | `contents: read`, and nothing else |
| Timeout | 30 minutes |

## Hard rules

- **Never modify a workflow this command did not create**, except for the one deliberate integration
  case in step 2 — and there, add a job and change nothing else. Do not rename files, do not
  reorganise jobs, do not "tidy" YAML, do not touch test configuration, and do not change
  repository-wide permissions.
- **Never overwrite a hand-edited Accountable Review workflow without being asked.** `drift` is
  reported and shown, never resolved silently.
- **Never claim a credential is configured.** You cannot see repository secrets. Say what you found
  and what you could not check.
- **Never request permissions the job does not use.** `contents: read` is the whole of it. A Review
  Map job that could write to the repository is a different risk profile for no benefit — and
  `pull_request_target`, which would hand this job the repository's secrets on a branch a stranger
  controls, is not an option to weigh.
- **Never make the generated workflow run the application under review.** No `bundle exec`, no
  migrations, no database service, no `docker compose`. The Review Map is built by reading source and
  tests; that is a property of the product, not an optimisation. `review-map` proposes validation
  commands for a human to run and never runs them, and CI must not quietly become the place that
  does.
- **Never post to GitHub.** No comments, no checks, no reviews, no labels. The workflow run is where
  the artifact is discoverable, and that is enough for the first version.
- Never write the plugin's own files into the repository being set up. The workflow clones the plugin
  at a pinned tag; it does not vendor it.
