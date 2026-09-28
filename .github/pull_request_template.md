## What changed and why

<!-- The prose is the source. Describe the change in the same terms CLAUDE.md and CONTRIBUTING.md
use: which file(s) own the thing you touched, and what was wrong or missing before. -->

## Verification

There is no build and no linter. Check the boxes that apply to this change.

- [ ] `claude plugin validate . --strict` passes
- [ ] Edited a script under `skills/*/scripts/`, `ci/`, or its tests — ran `bin/evals offline`
- [ ] Edited prose (`SKILL.md`, a `references/*.md`, `page-template.html`) — ran the skill against a
      real PR and read the page it produced (link the target and note what changed on the page)
- [ ] Bumped `.claude-plugin/plugin.json`'s `version` in this commit (required if this change should
      reach existing installs)
- [ ] Checked `.claude/CLAUDE.md`'s "Invariants that span files" for any bullet this change touches,
      and updated every file it lists

## Related issue

<!-- Closes #123, or "none" -->
