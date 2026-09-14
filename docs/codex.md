# Review Maps in Codex

Codex runs the shared `review-map` skill locally. The review procedure, Rails/Phoenix lenses,
template, source excerpts, and coverage gate are the same files Claude Code uses. The host
adapter changes how independent readers are launched and where the HTML is delivered.

## Install from a checkout

Clone this repository, enter it, and run:

```sh
bin/install-codex-skill
```

The installer creates a symlink at `~/.agents/skills/review-map`. It does not modify Codex
configuration, choose a model, install a CLI, or install `setup-ci`. Repeating it against
the same checkout succeeds without changing the link. An existing file, directory, or
different symlink is reported and preserved. Keep the checkout at its installed path;
`git pull` updates the skill. If you move the checkout, remove the old link and reinstall.

For a project-only installation, pass that project's discovery directory explicitly:

```sh
bin/install-codex-skill --skills-dir /path/to/app/.agents/skills
```

That creates a local absolute symlink, not a portable installation to commit for teammates.
To uninstall, remove only the `review-map` symlink from the directory you chose. The source
checkout remains intact. Restart Codex if a newly installed skill does not appear.

Codex's [skill documentation](https://learn.chatgpt.com/docs/build-skills) describes discovery
and explicit invocation. This first integration uses local skills, not a Codex marketplace package.

## Use

Start Codex in the application repository and invoke, for example:

```text
$review-map
$review-map 123
$review-map --effort low --output /tmp/my-review-map
```

There is one page shape and no flag chooses it; `--effort high` is the default. With no
output argument, Codex saves the staged page
under the skill's derived temporary work directory and returns an absolute file link.
With `--output`, it writes `<dir>/index.html`. Open the file in a browser or the available
local preview. Neither mode uploads the page or promises a hosted URL. Both keep the HTML
outside the repository under review, and temporary files are not durable hosting.

High effort explicitly delegates independent readers using the session's subagent tools.
The shared mandate is bundled inside the skill, so installation does not need a separate
named Codex agent or a particular model. Workers inherit the configured model and effort;
Claude's `sonnet` setting does not apply to them. Concurrency is bounded by the host, with
at most six selected analysis notes across the whole run. The parent continues drafting and
then collects the readers' results before completing the page.

The reader is instructed to do read-only work; enforcement depends on the host's worker
sandbox options. If delegation is disabled or unavailable, the skill reports that high
effort cannot run and offers low effort. A failed reader is not counted as a finished pass.
See the official [subagent documentation](https://learn.chatgpt.com/docs/agent-configuration/subagents)
for host settings. The installer never changes those settings.

## Verify a local change

Run `bin/evals offline` for the existing mechanical suites, manifest validation, and
installer tests. The installer test uses a temporary directory, verifies resources through
the link, and checks that repeat installs and conflicting installations preserve data.

For a behavioral smoke test, build the existing fixtures in a disposable directory:

```sh
bin/evals fixtures /tmp/review-map-codex-fixtures
```

The fixture builder replaces that directory. Open its `rails-only-small` repository in
Codex and run `$review-map --effort high --output /tmp/review-map-codex-output`.
Verify that the readers actually returned results, the parent checked their evidence,
the HTML completes without a publishing call, and the fixture working tree remains clean.
Repeat at `--effort low` to exercise the other arm. Check
the artifact against the existing page cases; a valid installation alone does not establish
review quality or quality parity between models.

## Current boundary

Only local review generation is supported here. `setup-ci`, `ci/generate-review-map.sh`,
and model-driven evaluation runners still invoke Claude. Codex CI execution and evaluation
automation are separate work. Existing shell/Ruby checks can inspect either host's HTML.
