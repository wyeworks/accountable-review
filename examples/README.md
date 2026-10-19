# Example Review Maps

Two pages produced by `review-map` against real pull requests in public Rails codebases, published
to GitHub Pages so the README can link something a reader can open:

**https://wyeworks.github.io/accountable-review/**

Public repositories were chosen for one reason: every `file:line` citation on these pages resolves
for anyone. A map of a private PR is a page of dead links to everyone but the team that owns it,
which is most of what makes an example worth reading.

## What is here

<!-- examples:begin table — written by bin/examples render; do not edit by hand -->
| Path | Pull request | Revision (head → base) | Shape |
|---|---|---|---|
| `discourse-43845/` | [discourse/discourse#43845](https://github.com/discourse/discourse/pull/43845) | `320f173` → `64358ac` | 36 files · 3 context entries · 6 checkpoints · 1 lifecycle figure · 2 impact paths |
| `rubygems-6699/` | [rubygems/rubygems.org#6699](https://github.com/rubygems/rubygems.org/pull/6699) | `4199bcb` → `e9b5a3e` | 11 files · 3 context entries · 4 checkpoints · 1 converge figure · 2 impact paths |

- `discourse-43845/`: generated on **2026-10-19** by **`accountable-review` 1.3.0** from plugin commit `92e31bd`, at `--effort high`, `--mentor off`, `--context auto`; coverage gate: pass.
- `rubygems-6699/`: generated on **2026-10-19** by **`accountable-review` 1.3.0** from plugin commit `92e31bd`, at `--effort high`, `--mentor off`, `--context auto`; coverage gate: pass.
<!-- examples:end -->

Each directory is one run's whole output: the page and the `manifest.json` written beside it. The
manifest is the pin — repository, pull request, base and head — and the provenance: plugin version
and commit, date, settings, coverage gate. The table and the list above are rendered from the
manifests and the pages by `bin/examples render`, and so is the foot of `index.html`, so nothing
said here about a page is typed.

`index.html` is the front door to the pages. It is not a Review Map and follows none of the page
rules — it borrows the design language and the theme rule, and nothing else.

Each pull request is mapped at the revision its manifest pins, so two versions of a page differ
only by what the skill does. A pull request that is still open may move on past its pin. The pin
holds until the head it names is gone from the pull ref, and then a person re-pins or replaces the
example — never the script.

No page is edited after the run produced it. That is the point of keeping them: a hand-tuned
example demonstrates what someone could write, not what the skill does.

## Regenerated every release

The page format moves between releases — a component is added, a section is merged away, a rule
about what may appear changes. A linked example rendering a format two releases old is exactly the
kind of drift this project is careful about everywhere else, and it is quiet: nothing about a stale
page announces that it is stale. So every release regenerates them, and `bin/examples check`, part
of `bin/evals offline`, fails while any manifest names a version other than `plugin.json`'s.

```bash
export CLAUDE_CODE_OAUTH_TOKEN=$(claude setup-token)   # or ANTHROPIC_API_KEY
bin/examples regen                 # every example, or name one: bin/examples regen discourse-43845
```

It runs the skill exactly as CI does: `ci/generate-review-map.sh --output` from a detached
worktree of the pinned head, with the settings the manifest records. It then runs `check.rb --final`
on the page, and only if that passes does it copy the page and its manifest here and re-render the
provenance.

Then **read each page** before committing it, against the four questions `.claude/CLAUDE.md` asks
of every run: is every checkpoint a judgment, did the merge happen, does the impact panel cite code
that really consumes the change, and does any sentence grade the pull request. Finding defects is
sampling, so a regenerated page can come out worse than the one it replaces. A worse page is
re-run, never edited.

To add an example, write its `manifest.json` by hand — `regen` reads the revision block and the
settings — and run `bin/examples regen <id>`. The repository must be public.

## Why these two

They fail in opposite directions, which is what a pair is for.

**RubyGems** is eleven files that all look safe. It is the first slice of a larger change: a new
table, the callbacks that keep it in step with the live one, and a backfill task. Nothing reads the
new table yet, and every line of it is an addition. So what a reviewer has to decide is almost
entirely about code the diff never opened: every path that starts or ends an ownership — the
callbacks, a re-push that disowns a gem without running them, an organization onboarding that moves
ownerships under it, an account deletion — has to keep one rule, an open history row exactly while
a confirmed ownership exists.

**Discourse** is the case for a large diff. Thirty-six files, and most of what a reviewer has to
decide is not in any of them: whether every request that creates an account still passes the
CAPTCHA, and what the new signup step does for a visitor who is not logged in yet. It is also the
case for *Context*: the change moves which request creates the account, and a reader has to see
that move, and meet the CAPTCHA plugin and *approval signup*, before a checkpoint can rely on them.

Neither page grades its pull request, and this directory does not rank the two.
