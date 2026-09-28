# Review Maps in Pi

[Pi](https://github.com/earendil-works/pi) runs the shared `review-map` skill locally. The review
procedure, Rails/Phoenix lenses, template, source excerpts and coverage gate are the same files
Claude Code and Codex use. The host adapter, `skills/review-map/references/hosts/pi.md`, changes
how independent readers are launched and where the HTML is delivered.

## Install

From npm, from the repository, or from a checkout:

```sh
pi install npm:@wyeworks/accountable-review                # personal
pi install -l npm:@wyeworks/accountable-review             # this project's .pi/settings.json
pi install git:github.com/wyeworks/accountable-review      # the latest commit instead
pi install /path/to/accountable-review                     # a checkout; git pull updates it
```

## One skill, with a prefixed name

**Pi has no per-package namespace.** A skill's name is its frontmatter `name`, and when two share
one, Pi keeps the first it discovered and warns. Claude Code namespaces plugin skills
(`/accountable-review:review-map`), but in Pi a bare `review-map` or `setup-ci` is a name any
other package can take.

So the root `package.json` carries a `pi` manifest that loads **`pi/skills/accountable-review-map/`**
and nothing else. That skill holds no procedure. It names `skills/review-map/SKILL.md` by a
relative path and tells the model to read and follow it, with this command's arguments and
`references/hosts/pi.md`. The procedure keeps one home. `skills/review-map/tests/frontmatter.rb`
fails if the pointer stops resolving or either description passes the Agent Skills limit of
1,024 characters, over which Pi warns on every start.

`setup-ci` is left out of the manifest because the workflow it writes runs Claude, not Pi. Pi
ignores the Claude-only `.claude-plugin/` and `agents/`. The npm package carries only the entry
skill and `review-map`'s `SKILL.md`, `references/` and `scripts/`, and publishing it with the
`pi-package` keyword is what lists it in [Pi's gallery](https://pi.dev/packages).

`bin/install-codex-skill` also works: Pi reads `~/.agents/skills`, so the symlink Codex uses reaches
Pi, and [Codex support](codex.md) covers its flags and removal. That route bypasses the manifest,
so the skill appears under the bare name `review-map`. Run `/reload` after editing a checkout.

**Pi drops a skill whose frontmatter is not strict YAML**, and says nothing about it in print mode.
`skills/review-map/tests/frontmatter.rb` exists because the plugin once shipped a description that
Claude Code accepted and Pi rejected.

## Use

```text
/skill:accountable-review-map
/skill:accountable-review-map 123
/skill:accountable-review-map --effort low --output /tmp/my-review-map
```

Arguments after the skill name reach step 1 unchanged. Without `--output` the page is saved under
the skill's derived temporary work directory and its path is given in the response. With `--output`
it is `<dir>/index.html`. Neither uploads anything. Pi's `/share` publishes the session, not the page.

## How the readers work

Pi deliberately has no subagents. At `--effort high` the parent starts one background
`pi -p` process per selected analysis note (at most six), in a single `bash` call, and keeps
drafting. Each reader:

- runs with `--tools read,grep,find,ls`, which Pi **enforces**, so a reader cannot run a shell or
  write a file;
- gets the shared mandate through `--append-system-prompt`, and the note, repository, BASE and
  HEAD in its prompt;
- runs with `--no-skills`, `--no-approve` and `--no-session`, so it cannot start a review map of its
  own, loads nothing project-local from the branch under review, and leaves no session behind;
- has stdin closed. `pi -p` waits forever on an open non-terminal stdin;
- writes its challenges to `$W/challenges/<id>.md` and its exit status to `<id>.exit` last.

Pi sends no notification when a background process ends, so the parent checks those `.exit`
files at each stage boundary. A reader that fails is retried once. One still running after about
fifteen minutes is killed. Either way the note is reported as unchecked in chat, never on the page.
Readers run your configured default model unless you name one for the run.

## Verify a local change

`bin/evals offline` covers everything here that has a right answer, including the frontmatter
check. For a behavioural smoke test, build the fixtures and run against one:

```sh
bin/evals fixtures /tmp/review-map-pi-fixtures
cd /tmp/review-map-pi-fixtures/rails-only-small
pi -e /path/to/accountable-review        # or: pi install /path/to/accountable-review
# then: /skill:accountable-review-map --output /tmp/review-map-pi-output
```

Check that `$W/challenges/` holds one `.md` and one `.exit` per selected note, that the parent
folded in only challenges whose cited lines it opened, that the page completes and passes the
gate, and that the fixture's working tree is still clean. Repeat at `--effort low`. A valid
installation does not establish review quality or parity between models.

## Current boundary

Only local review generation is supported. `setup-ci`, `ci/generate-review-map.sh` and the
model-driven evaluation runners still invoke Claude.
