# Goal and use cases — monorepo-contract

## What it is for

A project can be archived from the client. The backend stamps `projects.archived_at`, refuses
archival while a timer is running, serializes the timestamp, and returns 422 on refusal. The
client gains a mutation hook and a field on its `Project` type.

Evidence, ranked as step 4 ranks it:

| Source | What it establishes |
|---|---|
| `api/spec/requests/projects_spec.rb:9-13` | The happy path returns 200. That is all it pins — the 422 branch is untested |
| `api/app/models/project.rb:4-12` | What actually happens: refuse while running, else stamp. `ArchiveError` is defined here |
| `api/app/serializers/project_serializer.rb:7-12` | The wire shape, and a comment saying the field is `nil` for a project never archived |
| Commit `13b3fcd` "Archive projects, backend and client" | Confirms both sides were intended in one change |
| PR description | None exists |

## Use cases

```
Use case A — A user archives a project from the picker
Refused while a timer is running; otherwise the timestamp is stamped and returned.

useArchiveProject → POST /api/projects/:id/archive → ProjectsController#archive
  → Project#archive! → projects.archived_at
  → ProjectSerializer → { archived_at: "…" | null } → Project.archivedAt
```

```
Use case B — A user picks a project from the list
Unchanged client code decides what the list contains, and archival changes what it means.

ProjectSelector → useProjects → GET /api/projects → ProjectsController#index
  → selectableProjects(data) → filter on p.name.length > 0
```

**No `routes.rb` exists in `api/`.** The path `/api/projects/:id/archive` is not declared
anywhere in the backend; it is asserted by the request spec and constructed by
`useProjects.ts`. Two sides agreeing on a string that no route file defines is worth stating
as what it is, rather than presenting the URL as established.

## Stated gaps

- **`archive!` calls `time_entries.running`, and `Project` declares no `has_many
  :time_entries`.** No `TimeEntry` model exists in the repository. As committed, the guard
  raises `NoMethodError`, not `ArchiveError`. Uncertain whether the association is missing or
  the fixture of a larger app — either way the reviewer needs it named.
- **The wire key never matches the declared one.** `archived_at` on the wire, `archivedAt` in
  `web/src/types/project.ts`, and nothing in either tree transforms case. Distinct from the
  nullability mismatch and strictly worse: the property is absent rather than null.
- **The 422 branch is untested and unhandled.** The spec covers 200 only; the client throws a
  generic `Error("failed to archive project")` for every non-ok response, so the message the
  backend takes care to build never reaches a user.
- **Nothing prevents new time entries against an archived project.** Implied by the feature,
  absent from the diff.
