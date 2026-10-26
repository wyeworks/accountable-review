# Discovering a Rails project

Read at `SKILL.md` step 2, once, right after the stack is detected — this file and no other stack's.
It says what to find out about the repository before any tracing, and which versions the
documentation links will be pinned to. The lens, `references/rails-nextjs.md`, is still read at step
5.

## The application

Locate the Rails root by finding `config/application.rb`. It may be at the repo root, under a
subdirectory such as `api/`, or there may be several (engines, monorepo). Detect, don't assume:
RSpec vs Minitest; API-only (`config.api_only`) vs server-rendered; the authorization library, if
any; the serializer library; the background job adapter; whether `strong_migrations` is present.

## Versions

Record the Rails version and its *series* from the `rails (x.y.z)` line in `Gemfile.lock`
(`rails (8.0.2)` gives `8.0`), plus the exact locked versions of the gems above, which pin to a tag.
One series covers the whole framework.
