# Target — monorepo-contract

Resolved as step 1 resolves it.

| | |
|---|---|
| Target | current branch, no PR |
| Base ref | `HEAD~1` (`b8cc661`, "base") |
| Head | `13b3fcd`, "Archive projects, backend and client" |
| Working tree | clean |
| `gh` | no PR exists |
| Remote | `origin https://github.com/acme/timesheet.git`, **nothing pushed** |

`git branch -r --contains HEAD` is empty: the remote exists, the commit is not on it.

**Deep-link rung 3.** A remote is configured, so `owner/repo` is known — but the head SHA is
on no remote, so a blob permalink to it 404s. Citations are plain text. The presence of a
remote is the trap here: it makes a permalink look constructible, and the reachability check
in step 1 exists because it is not.

## Project shape, as step 2 discovers it

- Rails root at `api/` (`api/config/application.rb`), `config.api_only = true`. RSpec.
- Next.js client at `web/` (`web/package.json`, `web/next.config.js`), `src/` layout.
- The seam:
  - fetch calls are inline in `web/src/hooks/useProjects.ts` — **no API client wrapper**, no
    single place where base URLs or error handling live;
  - `web/src/types/project.ts` is **hand-written**. Nothing generates it from the backend, so
    drift between the serializer and the type is silent and appears at runtime, not build
    time. This is the case worth hunting, and this fixture is it;
  - **no runtime validation** at the boundary — no Zod, no parser. `res.json()` is trusted
    as `Project[]`;
  - data fetching is React Query (`@tanstack/react-query`).
- No serializer library: `ProjectSerializer` is a plain class. No authorization library, no
  job adapter, no `strong_migrations`.
- No `CLAUDE.md`, `AGENTS.md` or `docs/`.
