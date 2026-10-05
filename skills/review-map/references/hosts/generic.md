# Every host other than Claude Code

Read this before step 1. The shared procedure still owns the page, its one shape, the evidence
rules and the completeness gate. These are the mechanics for that procedure in **any agent that is
not Claude Code** and loaded this skill from an Agent Skills directory — Codex and Pi being the
primary examples. Nothing below needs more than a shell, file reads and edits, and nothing names a
host's tool: use whatever your host offers for each job, and where it offers nothing, the rule for
an unavailable capability applies. A local file is the delivery that works everywhere, which is
why this reference, not Claude's, is the default.

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

At `--effort high`, each selected analysis note gets one independent reader in a context of its
own. What makes it independent is the fresh context, not the tool that provides it, so before the
run starts, work down this ladder and take the **first rung your host can actually climb**. Decide
once, before step 6c, and use the same rung for every note.

1. **The host's own subagent tool**, started with a fresh context — Codex has one. Not Claude's
   named agent registry. No custom agent installation or model override is required: inherit the
   configured model and effort.
2. **A fresh non-interactive run of this same agent's CLI**, as a background process — only when
   that CLI can be started **read-only**: a tool allowlist limited to reading and searching, or a
   read-only sandbox. The reader runs over a contributor's branch, so an unrestricted process is a
   different security posture rather than a fallback, and this rung does not exist without the
   restriction. Details below.
3. **Neither.** Delegation is unavailable, and the last paragraph of this section applies.

Never climb sideways: do not start a *different* vendor's agent, which would send the repository
somewhere the user did not choose, and do not run the pass in your own context, which is the run
re-reading its own analysis while reporting a check it did not get.

Whichever rung, give each reader the absolute path to `references/claim-falsifier.md` (relative to
the skill base, not this host reference), the repository path, BASE and HEAD, and the path of its
one note under `$W/analysis/`. Ask it to read that mandate first and return its specified two
lists. Never send the page: at step 6c it does not exist yet, and that is the point. Do not fork
the parent's whole conversation. The reader must only read source and run read-only searches. Do
not let it run the application, edit files, post externally, or delegate again. Use a read-only
worker sandbox when the host exposes that option; otherwise these are worker instructions, not a
claim that the host enforces read-only access.

**Rung 2, the separate process.** Find the agent's own CLI on `PATH` and read its `--help` for the
flags this needs rather than recalling them: a non-interactive (print) mode, a way to restrict
tools to reading and searching or to sandbox the process read-only, and, where it has one, a way
to start without saving a session. If `--help` does not show a read-only restriction, this rung is
unavailable — go to rung 3; never start the process without it. Launch every selected reader in
**one** shell call, each in the background from the repository root with stdin closed, its prompt
carrying the four inputs above, and its output captured under `$W/challenges/`: `<id>.md` for
stdout, `<id>.err` for stderr and `<id>.exit` for the exit status once it finishes. Do not wait on
them. At each later stage boundary, check which `.exit` files exist and read the finished ones; a
reader whose exit status is not 0, or whose output lacks the mandate's two lists, has failed.

Launch up to the available concurrency and keep drafting — step 7, then step 9's stages.
Queue any remaining notes within the shared six-note total cap; do not change user
configuration to raise concurrency. Collect results before the final publish, release
completed workers when the host supports it, and verify their cited lines yourself before
changing the page.

Check delegation availability before starting a high-effort run. If the ladder ends at rung 3,
explain that high effort needs independent readers and ask whether to proceed at low
effort. If a worker fails later, retry that note once when possible. If it still cannot
finish, report in chat which note was not checked;
do not advertise a completed high-effort run. A user-authorized switch to low effort may
finish through the normal completeness gate. This limitation belongs in chat, not as an
assurance badge or a falsification tally on the page.

## Scope

This integration supports local `review-map` generation. The bundled `setup-ci` skill and
CI runner still use Claude Code and Anthropic credentials; they do not run in any other host yet.
