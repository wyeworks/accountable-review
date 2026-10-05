# Claude Code host

Invoke `/accountable-review:review-map` when installed as the plugin, or `/review-map` when
installed as a standalone skill (for example by `npx skills add`). Resolve scripts and references
from the loaded skill's base directory; `$CLAUDE_PLUGIN_ROOT` need not be set in the shell.

Without `--output`, publish with `Artifact` at each shared milestone, reusing the same
`$W/page.html` path so the URL stays stable. With `--output`, save `<dir>/index.html`
and skip every publishing call. The shared staging and completeness rules apply to both.

At high effort, spawn the registered `accountable-review:claim-falsifier` agent in the
background for each selected analysis note, up to the shared cap and available concurrency,
all in a single message. Supply the absolute path to the shared `references/claim-falsifier.md`
mandate with the task inputs from step 6c. The agent's tools and model are configured in
`agents/claim-falsifier.md` at the plugin root; the parent need not read that wrapper.

A standalone install has no plugin root, so that agent is not registered — the skill was loaded
under the bare name `review-map`, or the agent type is missing from the ones you can spawn. Then
spawn a `general-purpose` agent instead, in the background, with the same inputs, `model: sonnet`
where the tool accepts one, and a prompt that opens: read the mandate at the supplied path first
and follow it; you are read-only — do not write, edit or create any file. Do not fall back to
`Explore`: its own instructions are to read excerpts, and the mandate needs whole files opened. That
is still an independent reader in a fresh context, which is all step 6c needs; nothing else changes.

Keep drafting while the readers work — step 7, then step 9's stages — and collect their
results before the final publish. If delegation is unavailable, explain that high effort
needs independent readers and ask whether to proceed at low effort. Retry a failed reader
once when possible; if it still fails, report in chat which note went unchecked. Do not
silently report high effort as completed. A user-authorized switch to low effort can finish
through the normal completeness gate. None of this reaches the page.
