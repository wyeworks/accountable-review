# Pi host

Read this before step 1. The shared procedure still owns the page, its one shape, the evidence
rules and the completeness gate. These are the Pi mechanics for that procedure.

## Local delivery

Pi has no publishing tool, so this is Codex's delivery. Without `--output`, use the derived
`$W/page.html` from step 1. Save every stage there and give its absolute path at stage 1 and at
completion: a local file, not a hosted URL. Do not upload the repository or the page to make one;
`/share` publishes the *session*, not the page, and is not a substitute.

With `--output`, use `<dir>/index.html` and the shared non-interactive save-point rules.
Both destinations must resolve outside the reviewed checkout, including through symlinks.
Patch existing sections with `edit`; the shared `Write`/`Edit` wording names Pi's `write` and
`edit`.

## Independent falsification

Pi has no subagents, by design, so at `--effort high` each reader is **a separate `pi` process**,
started from `bash` in the background. That is still an independent reader in a fresh context,
which is the only property step 6c needs from a subagent.

Check first: `command -v pi` must succeed. If it does not, delegation is unavailable — say so
and ask whether to proceed at `--effort low`, exactly as the shared rule for an unavailable host
says.

For each selected note `<id>` (the shared six-note cap applies), launch one reader with the
exact shape below, all of them in **one** `bash` call, from the repository root:

```sh
C="$W/challenges"; mkdir -p "$C"
( pi -p --no-session --no-skills --no-approve \
     --tools read,grep,find,ls \
     --append-system-prompt "<skill base>/references/claim-falsifier.md" \
     "Falsify the analysis note at $W/analysis/<id>.md. Repository: <repo root>. BASE <base sha>, HEAD <head sha>. Where the note records a shell search, re-run it with the grep and find tools. Return the two lists the mandate specifies." \
     </dev/null >"$C/<id>.md" 2>"$C/<id>.err"; echo $? >"$C/<id>.exit" ) &
echo $! >"$C/<id>.pid"
```

Each part is load-bearing:

- **`--tools read,grep,find,ls`** is what makes the reader read-only, and Pi enforces it: a reader
  asking for `bash`, `edit` or `write` gets *tool not found*. That is stronger than the Codex
  host's instruction-only promise, and it is why recorded shell searches are re-run with `grep`
  rather than `rg`.
- **`--append-system-prompt`** puts the mandate in the reader's system prompt, so it is read before
  the note rather than on request. Give the absolute path: the mandate is resolved against the
  skill base, not this host reference and not the repository.
- **`</dev/null`** is not decoration. `pi -p` reads a non-terminal stdin before it starts and
  waits forever on one that never closes.
- **`--no-skills`** keeps this skill out of the reader's prompt, so it attacks a note rather than
  starting a review map of its own. **`--no-approve`** loads nothing project-local from the branch
  under review, which is a contributor's code. **`--no-session`** leaves no session files behind.
- **The `.exit` file is written last**, so its presence is what "finished" means. `<id>.md` alone is
  not: it exists from the moment the reader starts.

Do not choose a model. Readers run the user's configured default. Pass `--model` or `--thinking`
only when the user named one for this run.

The call returns at once. **Keep drafting** — step 7, then step 9's stages. Pi sends no
notification when a reader finishes, so at each stage boundary check which `$C/*.exit` files
exist (one `ls`) and fold in the ones that have landed, per step 8. Never sleep between stages to
wait for them.

Before the final publish, account for every reader. Once only waiting on readers remains, poll in
bounded `bash` calls of a minute or two. A reader with a non-zero `.exit` has failed; its `.err`
says why. Retry it once. A reader still running about fifteen minutes after launch counts as
failed too: `kill` its `.pid` and do not retry it. A note whose reader failed twice or was killed
is unchecked. Report in chat which note went unchecked, and do not describe the run as a completed
high-effort run. A user-authorized switch to low effort may finish through the normal completeness
gate. Nothing about any of this reaches the page.

If the run stops early, `kill` every `.pid` whose `.exit` is missing, so no reader outlives the run.

## Scope

This integration supports local `review-map` generation. The bundled `setup-ci` skill and the CI
runner still use Claude Code and Anthropic credentials; they do not run Pi.
