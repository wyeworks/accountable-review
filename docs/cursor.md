# Review Maps in Cursor

Cursor runs the shared `review-map` skill locally, as a Cursor plugin. The review procedure,
Rails/Phoenix lenses, template, source excerpts, and coverage gate are the same files Claude
Code and Codex use. The host adapter, `skills/review-map/references/hosts/cursor.md`, changes
only how the independent readers are launched and where the HTML is delivered.

## Install from a checkout

Clone this repository, enter it, and run:

```sh
bin/install-cursor-plugin
```

The installer creates a symlink at `~/.cursor/plugins/local/accountable-review` pointing at the
checkout. Cursor reads `.cursor-plugin/plugin.json` from there, which exposes two things:

- the `review-map` skill, and
- `review-map-falsifier`, the read-only subagent `--effort high` sends at each analysis note
  (`cursor/agents/review-map-falsifier.md`).

It does not expose `setup-ci`, change Cursor settings, or choose a model. Repeating it against
the same checkout succeeds without changing the link. An existing file, directory, or different
symlink is reported and preserved. Keep the checkout at its installed path; `git pull` updates
the plugin. Restart Cursor, or reload the window, if the skill does not appear. To uninstall,
remove only the `accountable-review` symlink.

Pass `--plugins-dir DIR` to link somewhere else, for example a temporary directory when testing.

**Skill only.** Cursor also discovers plain skills in `~/.agents/skills`, so a machine that ran
`bin/install-codex-skill` already has `review-map` in Cursor without the plugin. That works, with
one difference: the `review-map-falsifier` agent is not registered, and the host reference falls
back to a read-only general-purpose subagent carrying the same mandate.

## Use

Open the application repository in Cursor and ask the agent, for example:

```text
/review-map
/review-map 123
/review-map --effort low --output /tmp/my-review-map
```

There is one page shape and no flag chooses it; `--effort high` is the default. With no output
argument, the page is saved under the skill's derived temporary work directory and the agent
returns an absolute file link, which Cursor's built-in browser can open. With `--output`, it
writes `<dir>/index.html`. Neither mode uploads the page or promises a hosted URL, and both keep
the HTML outside the repository under review.

High effort launches one background Task per analysis note, read-only, inheriting the parent's
model — Claude's `sonnet` pin in `agents/claim-falsifier.md` does not apply here. The parent keeps
drafting and collects the readers' results before completing the page. If subagents are
unavailable, the skill says high effort cannot run and offers low effort; a failed reader is not
counted as a finished pass.

## Verify a local change

`bin/evals offline` runs `skills/review-map/tests/cursor-plugin.sh`, which checks that the Cursor
manifest uses only keys Cursor's schema accepts, carries the same `name` and `version` as
`.claude-plugin/plugin.json`, names only paths that exist, exposes `review-map` alone, and that the
installer links and refuses exactly as described above.

What it cannot check is Cursor itself. For a behavioural smoke test, build the fixtures:

```sh
bin/evals fixtures /tmp/review-map-cursor-fixtures
```

Open its `rails-only-small` repository in Cursor and run
`/review-map --effort high --output /tmp/review-map-cursor-output`. Verify that the readers ran
in the background while the parent drafted, that they returned results, that the HTML completes
without a publishing call, and that the fixture working tree remains clean. Repeat at
`--effort low`.

## Current boundary

Only local review generation is supported. `setup-ci`, `ci/generate-review-map.sh`, and the
model-driven evaluation runners still invoke Claude. A published Cursor Marketplace listing is
separate work; the manifest is the part it would ship.
