# AGENTS.md

Working rules for this repository live in [`.claude/CLAUDE.md`](.claude/CLAUDE.md). **Read it in
full before editing anything here.** It is the canonical home for every rule that spans files —
what the two skills are, the invariants several files have to agree on, and the register to write
in — and this file deliberately restates none of it.

That is the point rather than an economy. `CLAUDE.md` § *One canonical home* is the page's rule and
that file's own, and the thing it warns about has already happened here once: an `AGENTS.md`
existed as a whole copy of `CLAUDE.md` with `Claude` replaced by `Codex` throughout. It fell two
hundred lines behind, lost `carry-plan.sh` and `--update` entirely, and rendered
`claude plugin validate --strict` as a command that does not exist. A pointer cannot go stale that
way.

## What is different when you work here from Codex

Three facts `CLAUDE.md` cannot state, because it is written for the host that has the Claude CLI.

- **`bin/evals offline` cannot come back fully clean without `claude` on `PATH`.** Its `manifest`
  suite is `claude plugin validate . --strict`, gated on the binary being there, and a suite that
  did not run is reported as `SKIP` and makes the run unclean on purpose — not a pass. Everything
  else in the suite is shell and Ruby and runs anywhere. CI runs the whole thing on every push, so
  a skipped manifest locally is a deferred check rather than a missing one.
- **`skills/setup-ci/` and `ci/` generate and run a workflow that invokes Claude**, with Anthropic
  credentials. Codex does not run them yet. Editing that half from Codex is fine; the deterministic
  tests under `skills/setup-ci/tests/` cover it without a model.
- **Whole-page evals need a model**, so the same split applies: `bin/evals offline` is the part you
  can always run, and `bin/evals page <id>` prints a recipe rather than running one.

The product's own Codex support — installing `review-map` into a Codex skills directory — is a
different subject, and [`docs/codex.md`](docs/codex.md) owns it.

[`CONTRIBUTING.md`](CONTRIBUTING.md) is how to run things. `CLAUDE.md` is why the rules exist.
