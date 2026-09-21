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
| `rubygems-6699/` | [rubygems/rubygems.org#6699](https://github.com/rubygems/rubygems.org/pull/6699) — *Add HistoricalOwnership foundation for tracking gem ownership history* | `b637b16` → `9d5892f` | 11 files · 5 checkpoints · 2 impact paths |
| `discourse-43845/` | [discourse/discourse#43845](https://github.com/discourse/discourse/pull/43845) — *FIX: Separate email-code signup details from completion* | `0f717c7` → `64358ac` | 34 files · 5 checkpoints · 3 impact paths |

`index.html` is the front door to the two. It is not a Review Map and follows none of the page
rules — it borrows the design language and the theme rule, and nothing else.

## Provenance

Both pages were generated on **2026-09-21** with **`accountable-review` 1.0.1**, at the default
`--effort high` and without `--mentor`. The plugin checkout was at or after `5633c47`, which is the
last commit before that date to touch `page-template.html`.

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
table, four callbacks that keep it in step with the live one, and a backfill task — nothing reads
the new table yet, and every line of it is an addition. What a reviewer has to decide is therefore
almost entirely about code the diff never opened: which existing paths destroy an ownership without
running a callback, which of them now close a tenure for someone whose access continues anyway, and
whether a failed history write should take the push down with it. It also carries the one checkpoint
per page that may judge how a change was built rather than what it now does — and it earns the slot
the only way that is allowed, by pointing at where this codebase already answered the same question.

**Discourse** is the case for a large diff. Thirty-four files, and most of what a reviewer has to
decide is not in any of them: whether the site's username rules still bind a server-generated name,
whether the CAPTCHA still gates the request that creates the account. A diff cannot show either.

Neither page grades its pull request, and this directory does not rank the two.
