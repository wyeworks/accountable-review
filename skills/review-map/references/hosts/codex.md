# Codex host

Read this before step 1. The shared procedure still owns the page, its one shape, the evidence
rules and the completeness gate. These are the Codex mechanics for that procedure.

## Local delivery

Without `--output`, use the derived `$W/page.html` from step 1. Save every stage there and
return an absolute Markdown file link at stage 1 and completion. Offer the host's local
HTML preview when available; a file link works without a preview tool. This is a local
file, not a hosted URL. Do not call Claude's `Artifact` tool, install a publishing skill,
or upload the repository or page to make a URL.

With `--output`, use `<dir>/index.html` and the shared non-interactive save-point rules.
Both destinations must resolve outside the reviewed checkout, including through symlinks.
Use an allowed temporary directory for scratch; if the requested destination is not writable,
report the permission limitation rather than writing into the checkout or changing permissions.
Patch existing sections with the available editing tool; the shared `Write`/`Edit` wording
does not require tools with those exact names.

## Independent falsification

At `--effort high`, explicitly spawn one independent subagent per selected analysis note. Use
the Codex session's available subagent tools, not Claude's named agent registry. No custom
agent installation or model override is required: inherit the configured model and effort.
Give each reader the absolute path to `references/claim-falsifier.md` (relative to the skill
base, not this host reference), the repository path, BASE and HEAD, and the path of its one
note under `$W/analysis/`. Ask it to read that mandate first and return its specified two
lists. Never send the page: at step 6c it does not exist yet, and that is the point.

Start with a fresh context when the tool supports it; do not fork the parent's whole
conversation or send the whole page. The worker must only read source and run read-only
searches. Do not run the application, edit files, post externally, or delegate again.
Use a read-only worker sandbox when the host exposes that option; otherwise these are
worker instructions, not a claim that the host enforces read-only access.

Launch up to the available concurrency and keep drafting — step 7, then step 9's stages.
Queue any remaining notes within the shared six-note total cap; do not change user
configuration to raise concurrency. Collect results before the final publish, release
completed workers when the host supports it, and verify their cited lines yourself before
changing the page.

Check delegation availability before starting a high-effort run. If it is unavailable,
explain that high effort needs independent subagents and ask whether to proceed at low
effort. If a worker fails later, retry that note once when possible. If it still cannot
finish, report in chat which note was not checked;
do not advertise a completed high-effort run. A user-authorized switch to low effort may
finish through the normal completeness gate. This limitation belongs in chat, not as an
assurance badge or a falsification tally on the page.

## Scope

This integration supports local `review-map` generation. The bundled `setup-ci` skill and
CI runner still use Claude Code and Anthropic credentials; they do not run Codex yet.
