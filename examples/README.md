# Example Review Maps

Two pages produced by `review-map` against real pull requests in public Rails codebases, published
to GitHub Pages so the README can link something a reader can open:

**https://wyeworks.github.io/accountable-review/**

Public repositories were chosen for one reason: every `file:line` citation on these pages resolves
for anyone. A map of a private PR is a page of dead links to everyone but the team that owns it,
which is most of what makes an example worth reading.

## What is here

| Path | Pull request | Revision (head → base) | Shape |
|---|---|---|---|
| `rubygems-6699/` | [rubygems/rubygems.org#6699](https://github.com/rubygems/rubygems.org/pull/6699) — *Add HistoricalOwnership foundation for tracking gem ownership history* | `4199bcb` → `e9b5a3e` | 11 files · no context · 4 checkpoints · 1 converge and 1 structure figure · 2 impact paths |
| `discourse-43845/` | [discourse/discourse#43845](https://github.com/discourse/discourse/pull/43845) — *FIX: Separate email-code signup details from completion* | `320f173` → `64358ac` | 36 files · 2 context entries and the before-and-after figure · 6 checkpoints · 1 converge and 1 chain figure · 1 impact path |

`index.html` is the front door to the two. It is not a Review Map and follows none of the page
rules — it borrows the design language and the theme rule, and nothing else.

## Provenance

Both pages were generated on **2026-10-08** by **`accountable-review` 1.2.0**, at the default
`--effort high` and without `--mentor`: RubyGems from plugin checkout `3c282aa`, the one that adds
*Context*'s before-and-after figure, and Discourse from `c1ddb13`, which makes that figure's
citations name the lines they link. The second commit touches only that figure, which the RubyGems
page does not earn.

Neither run could read its pull request's title or description — `gh` had no access to either
repository from the machine that ran them — so both pages say so in *What changed* and take intent
from the code, the tests and the commit messages.

Both pull requests are mapped at the revisions in the table, the same ones the previous versions of
these pages described, so the two versions differ only by what the skill does. Discourse's is
merged, so its revision is final; RubyGems' is still open, and may have moved on since.

Neither page was edited after the run produced it. That is the point of keeping them: a hand-tuned
example demonstrates what someone could write, not what the skill does.

## Why the version is recorded

The page format moves between releases — a component is added, a section is merged away, a rule
about what may appear changes. A linked example rendering a format two releases old is exactly the
kind of drift this project is careful about everywhere else, and it is quiet: nothing about a stale
page announces that it is stale.

So the version is written down rather than implied, here and in the foot of `index.html`. It is the
same reason an eval result line carries the skill's git sha — a page is attributable to a version of
the prose, or it is evidence of nothing in particular.

**When the format changes in a way these pages no longer show, regenerate them rather than editing
them.** From a checkout of the target repository:

```bash
cd /path/to/discourse
claude --plugin-dir /path/to/accountable-review
/accountable-review:review-map 43845 --output /tmp/example
```

Then copy `/tmp/example/index.html` over the page here and update this file's table, the date and
the version above, and the foot of `index.html`. `--output` is what makes the run non-interactive
and writes portable static HTML; it changes where the bytes land and nothing else about the page.

## Why these two

They fail in opposite directions, which is what a pair is for.

**RubyGems** is eleven files that all look safe. It is the first slice of a larger change: a new
table, the callbacks that keep it in step with the live one, and a backfill task — nothing reads
the new table yet, and every line of it is an addition. What a reviewer has to decide is therefore
almost entirely about code the diff never opened, and the page's converge figure is that question
drawn: every path that starts or ends an ownership — the callbacks, a re-push that disowns a gem
without running them, an organization onboarding that moves ownerships under them, an account
deletion — converging on the one rule they must all keep, an open history row exactly while a
confirmed ownership exists. It earns **no** *Context*: every checkpoint is followable by someone who
knows Rails and has never opened this repository, which is the section being earned rather than
always on. Its two impact paths are the crossings the diff cannot show: owner removal now writes a
second table inside its own transaction, and contributors demoted in bulk keep `owner` in their
history row, because nothing on that path lowers the role it recorded.

**Discourse** is the case for a large diff. Thirty-six files, and most of what a reviewer has to
decide is not in any of them: whether every request that creates an account still passes the
CAPTCHA — drawn as the verify requests converging on that rule — and what the new signup step does
for a visitor who is not logged in yet. Its *Context* section is the one this format added for
pages like it: the request sequence drawn before and after, with the account-creating request
moving one step later and the cases that run differently listed beneath it, then the CAPTCHA plugin
and *approval signup* introduced before any checkpoint relies on them.

Neither page grades its pull request, and this directory does not rank the two.
