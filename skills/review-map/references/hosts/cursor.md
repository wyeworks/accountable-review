# Cursor host

Read this before step 1. The shared procedure still owns the page, its one shape, the evidence
rules and the completeness gate. These are the Cursor mechanics for that procedure.

## Local delivery

Cursor has no publishing tool, so delivery is the Codex rule: without `--output`, use the
derived `$W/page.html` from step 1, save every stage there, and return an absolute Markdown
file link at stage 1 and at completion. Offer to open it in Cursor's built-in browser when
that tool is available; the file link works without it. This is a local file, not a hosted
URL. Do not call Claude's `Artifact` tool, install a publishing extension, or upload the
repository or the page to make a URL.

With `--output`, use `<dir>/index.html` and the shared non-interactive save-point rules.
Both destinations must resolve outside the reviewed checkout, including through symlinks.
If the requested destination is not writable, report the permission limitation rather than
writing into the checkout or changing permissions. Patch existing sections with the available
editing tool; the shared `Write`/`Edit` wording does not require tools with those exact names.

Run the bundled scripts from the terminal tool. They are POSIX shell and need only `git`;
resolve them relative to this skill's `SKILL.md`, never the repository being reviewed.

## Independent falsification

At `--effort high`, launch one independent reader per selected analysis note with the Task
tool, **all in one message and with `run_in_background: true`**. Use `subagent_type:
review-map-falsifier` when the plugin registered it — its wrapper sets `readonly` and inherits
the parent's model. When the skill was installed without the plugin, that agent does not exist:
use `subagent_type: generalPurpose` with `readonly: true` instead. Leave `model` unset in both
cases; this host has no model override for the reader.

Give each reader the absolute path to `references/claim-falsifier.md` (relative to the skill
base, not this host reference), the repository path, BASE and HEAD, and the path of its one
note under `$W/analysis/`. Ask it to read that mandate first and return its two lists. Never
send the page: at step 6c it does not exist yet, and that is the point. The reader only reads
source and runs read-only searches — it does not run the application, edit files, post
externally, or delegate again.

Then keep drafting — step 7, then step 9's stages — and collect the results before the final
publish, verifying every cited line yourself before changing the page. A Task call that blocks
until its reader returns has lost the reason the pass is the default: if background launch is
unavailable, say so in chat once and launch them anyway in one message, so the run stalls once
for the slowest rather than once per reader.

If the Task tool is unavailable, explain that high effort needs independent readers and ask
whether to proceed at low effort. If a reader fails, retry that note once. If it still cannot
finish, report in chat which note was not checked; do not advertise a completed high-effort
run. A user-authorized switch to low effort may finish through the normal completeness gate.
None of this reaches the page.

## Scope

This integration supports local `review-map` generation. The `setup-ci` skill and the CI
runner still use Claude Code and Anthropic credentials, and the Cursor plugin does not ship them.
