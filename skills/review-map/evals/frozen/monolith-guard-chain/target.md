# Target — monolith-guard-chain

Resolved as step 1 resolves it.

| | |
|---|---|
| Target | current branch `fix/steward-redirect-loop`, no PR |
| Base ref | `HEAD~1` ("base") |
| Head | `HEAD`, "Stop chapter stewards from looping between / and /steward" |
| Working tree | clean |
| `gh` | no PR exists for this repo |
| Remote | `https://github.com/acme/commons.git`, **nothing pushed** |

Commit SHAs are assigned when `make-fixtures.sh` runs, so do not cite them: refer to
`HEAD~1` and `HEAD`, which are stable.

`git branch -r --contains HEAD` is empty, and `acme/commons` does not exist on GitHub.

**Deep-link rung 3: plain text, plus a stated reason.** Every citation is `path:line` as
text, and the page has to say once why nothing is clickable. Same rung as `monorepo-contract`
— rung coverage is not what this fixture is for.

An earlier version of this file claimed rung 2, and it was wrong in a way worth recording.
The fixture used to push the branch to a local bare repository and then rewrite the remote
URL to this GitHub one, so that `git branch -r --contains HEAD` would report the head as
reachable without a network. The first live run against the fixture ran `gh` anyway, got
`Could not resolve to a Repository`, and emitted plain text — correctly, because a permalink
to a repository that does not exist 404s no matter what `refs/remotes` says. **Rung 2 is not
reachable with a fictional remote**, and the trick also punched a hole in
`checks/page-invariants.rb` § 5, which greenlights dead permalinks whenever `refs/remotes` is
populated. The push is gone; do not reintroduce it.

## Project shape, as step 2 discovers it

- Rails root at the repository root (`config/application.rb`), `load_defaults 8.1`, **not**
  `api_only`.
- **Minitest**, not RSpec: `test/`, `test/test_helper.rb`, `test/fixtures/*.yml`. No `spec/`
  and no `rspec-rails`.
- **Server-rendered.** ERB under `app/views/`, `turbo-rails` and `stimulus-rails` in the
  Gemfile, no `package.json` and no `next.config.*` anywhere. There is no separate client
  package, so the client of these redirects is the browser and the ERB views themselves.
  That is a different absence from `rails-only-small`'s: there the change had no client at
  all, here it has one and it is in this repository.
- Devise for authentication (`devise_for :users`, a `Users::RegistrationsController`
  subclass). Flipper for feature flags.
- **No authorization library.** No Pundit, no CanCan. Every rule is a hand-written predicate
  on `User` or `Chapter` — which is the reason two definitions of "steward" could disagree
  with nothing to flag it.
- `CLAUDE.md` exists and carries house style: Minitest via `bin/rails test`, `bin/rubocop`
  (Rails Omakase) required before merge. `bin/` holds `rails`, `setup`, `rubocop` and `dev`,
  so validation steps naming them are real commands rather than invented ones.
- `config/routes.rb` exists, unlike `rails-only-small`. Routes may be cited as fact.
