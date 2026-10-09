# Review Maps in Codex

Codex runs the shared `review-map` skill locally. The review procedure, Rails, Phoenix and Rust lenses,
template, source excerpts, and coverage gate are the same files Claude Code uses. The host
adapter changes how independent readers are launched and where the HTML is delivered.

## Install from the marketplace

This repository is its own Codex marketplace: `.agents/plugins/marketplace.json` lists one plugin,
and `.codex-plugin/plugin.json` describes it. From a terminal:

```sh
codex plugin marketplace add wyeworks/accountable-review
codex plugin add accountable-review@accountable-review
```

Codex copies the plugin into `~/.codex/plugins/cache/accountable-review/accountable-review/<version>/`
and the skill appears as `accountable-review:review-map`, the name Claude Code gives it. Restart
Codex if it does not appear. The plugin ships `review-map` alone — `setup-ci` writes a workflow
that runs Claude, so it stays out of a Codex install (see *Current boundary*).

`codex plugin marketplace upgrade accountable-review` fetches the latest catalogue. A release
reaches you when the manifest's `version` moves, which is the same pin Claude Code uses: the two
manifests carry one version, and `skills/review-map/tests/codex-plugin.rb` fails if they disagree.
`codex plugin remove accountable-review@accountable-review` uninstalls it, and
`codex plugin marketplace remove accountable-review` forgets the catalogue.

To pin a release or try a branch, add the ref: `codex plugin marketplace add
wyeworks/accountable-review --ref <tag-or-branch>`.

## Link from a checkout

To work on the skill, link it into Codex's skills directory so edits apply without reinstalling.
From the root of a clone of this repository:

```sh
mkdir -p ~/.agents/skills
ln -s "$PWD/skills/review-map" ~/.agents/skills/review-map
```

That is a standalone skill invoked as `$review-map`; `setup-ci` is not linked. Keep the checkout
at that path, since the link points into it, and `git pull` updates the skill. Use this **or** the
marketplace, not both, or Codex lists the skill under both names. To unlink,
`rm ~/.agents/skills/review-map`, which removes the link and leaves the checkout alone. Restart
Codex if a newly linked skill does not appear.

Without a checkout, the cross-agent [`skills`](https://github.com/vercel-labs/skills) CLI copies
the skill into `~/.agents/skills` instead of linking it:
`npx skills add wyeworks/accountable-review -g --skill review-map -a codex`. `npx skills update`
takes new commits and `npx skills remove review-map` uninstalls; the README's *Skills CLI*
section has the rest.

Codex's [skill documentation](https://learn.chatgpt.com/docs/build-skills) describes discovery
and explicit invocation.

## Use

Start Codex in the application repository and invoke, for example:

```text
$accountable-review:review-map
$accountable-review:review-map 123
$accountable-review:review-map --effort low --output /tmp/my-review-map
```

Installed from a checkout or by the skills CLI, the same invocations start with `$review-map`.

There is one page shape and no flag chooses it; `--effort high` is the default. With no
output argument, Codex saves the staged page
under the skill's derived temporary work directory and returns an absolute file link.
With `--output`, it writes `<dir>/index.html`. Open the file in a browser or the available
local preview. Neither mode uploads the page or promises a hosted URL. Both keep the HTML
outside the repository under review, and temporary files are not durable hosting.

High effort explicitly delegates independent readers using the session's subagent tools.
The shared mandate is bundled inside the skill, so installation does not need a separate
named Codex agent or a particular model. Workers inherit the parent model and effort unless
the Codex agent configuration overrides them; Claude's `sonnet` setting does not apply.
Concurrency is bounded by the host, with
at most six selected analysis notes across the whole run. The parent continues drafting and
then collects the readers' results before completing the page.

The reader is instructed to do read-only work; enforcement depends on the host's worker
sandbox options. If delegation is disabled or unavailable, the skill reports that high
effort cannot run and offers low effort. A failed reader is not counted as a finished pass.
See the official [subagent documentation](https://learn.chatgpt.com/docs/agent-configuration/subagents)
for host settings. Installing the plugin never changes those settings.

## Verify a local change

Run `bin/evals offline` for the existing mechanical suites, manifest validation, and the Codex
manifest check.

For a behavioral smoke test, check out the eval pull request pinned in
`skills/review-map/evals/e2e/prs.yml` in a disposable directory:

```sh
git clone --filter=blob:none https://github.com/discourse/discourse.git /tmp/discourse
git -C /tmp/discourse fetch origin +refs/pull/44196/head:refs/remotes/origin/pr/44196
git -C /tmp/discourse checkout --detach 01ba1cbb0e8e827ef5de9efbf36ff2430106b52c
```

To exercise the plugin path rather than the link, `codex plugin marketplace add
/path/to/accountable-review` registers the checkout as a local marketplace and `codex plugin add`
copies the working tree as it stands, so remove and re-add the plugin after an edit.

Open `/tmp/discourse` in Codex and run `$accountable-review:review-map 44196 --repository
discourse/discourse --base-sha 74c44fbebe39131151e5eaff480c7ab423a9b807 --head-sha
01ba1cbb0e8e827ef5de9efbf36ff2430106b52c --effort high --output /tmp/review-map-codex-output`
(`$review-map` if you linked the skill instead).
Verify that the readers actually returned results, the parent checked their evidence,
the HTML completes without a publishing call, and the checkout's working tree remains clean.
Repeat at `--effort low` to exercise the other arm. Then run the mechanical checks:

```sh
skills/review-map/evals/check.rb --final --page /tmp/review-map-codex-output/index.html \
  --repo /tmp/discourse --base 74c44fbebe39131151e5eaff480c7ab423a9b807
```

A valid installation and a clean check do not establish review quality or quality parity
between models.

## Current boundary

Only local review generation is supported here. `setup-ci`, `ci/generate-review-map.sh`,
and model-driven evaluation runners still invoke Claude. Codex CI execution and evaluation
automation are separate work. Existing shell/Ruby checks can inspect either host's HTML.
