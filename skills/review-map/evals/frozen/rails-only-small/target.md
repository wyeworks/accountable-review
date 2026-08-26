# Target — rails-only-small

Resolved as step 1 resolves it.

| | |
|---|---|
| Target | current branch, no PR |
| Base ref | `HEAD~1` (`760138c`, "base") |
| Head | `d70e5a7`, "Add project archival" |
| Working tree | clean |
| `gh` | no PR exists for this repo |
| Remote | **none configured** |

`git branch -r --contains HEAD` is empty, and there is no remote to be reachable on.

**Deep-link rung 4: plain text.** Every citation is `path:line` as text. A permalink here
would 404, and rung 4 is why a source excerpt is the only followable evidence the page can
offer — which raises what excerpts are worth in this fixture rather than lowering it.

## Project shape, as step 2 discovers it

- Rails root at the repository root (`config/application.rb`), `config.api_only = true`.
- RSpec (`spec/`, `rspec-rails` in the Gemfile). No Minitest.
- **No frontend.** No `package.json` anywhere. There is no client half of the contract to
  cover, and nothing for the boundary material inside a flow to be built from.
- No serializer library, no authorization library, no background job adapter, no
  `strong_migrations`.
- No `CLAUDE.md`, `AGENTS.md`, `docs/` or `CONTRIBUTING.md`. House style has to come from
  adjacent unchanged code.
