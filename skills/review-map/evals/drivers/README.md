# drivers

A driver produces **one section**, from the frozen upstream, so that section can be graded on
its own. It is eval-only harness: the skill gains no runtime surface from it, and nothing here
ships to a user.

A driver carries four things and no fifth:

1. which fixture, and that the shell is already inside it;
2. the frozen upstream to treat as given, and explicitly not to re-derive;
3. which step of `SKILL.md` and which § of `report-format.md` to read;
4. the output contract — one fragment, at one path, and nothing published.

**A driver must not restate a rule from `SKILL.md` or `report-format.md`.** Restating is how
two copies of a rule drift, which has already happened once in this project to the excerpt
budget, within a single run. The driver pins the inputs; the skill still owns the
instructions, because the instructions are what is being measured. A driver that starts
explaining the review unit is measuring itself.

`{{DOUBLE_BRACED}}` names are substituted by `../run.sh`: `SKILL_DIR`, `FIXTURE_DIR`,
`FROZEN`, `BASE`, `LEVEL`, `OUT`.

`LEVEL` is the skill's detail level, which a case file declares and `--level` overrides. It is
substituted rather than hard-coded for the usual reason: a driver naming its level in prose
would be a second copy of what the case file already says, and the run's result line records
the one the harness actually used.
