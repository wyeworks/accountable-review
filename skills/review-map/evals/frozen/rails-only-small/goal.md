# Goal and use cases — rails-only-small

## What it is for

A project can be archived: `projects.archived_at` is stamped, an `archived` scope is added,
and a controller action exposes it. Historical time entries are preserved — the model keeps
`dependent: :restrict_with_error` on `has_many :time_entries`, and a spec asserts an entry
still belongs to its project after archival.

Evidence, ranked as step 4 ranks it:

| Source | What it establishes |
|---|---|
| `spec/models/project_spec.rb:8-19` | Archival stamps `archived_at`; historical entries survive it. The best statement of intent here |
| `app/models/project.rb:5-12` | What actually happens: `update!`, an `archived` scope, and a slug uniqueness validation added in the same hunk |
| Commit `d70e5a7` "Add project archival" | Confirms the subject, adds no *why* |
| PR description | None exists |

## Use cases

```
Use case A — A workspace admin archives a project
Archival stamps a timestamp; historical time entries are preserved.

(no route defined) → ProjectsController#archive → Project#archive!
  → projects.archived_at
```

**There is no `config/routes.rb` in this repository.** `ProjectsController#archive` is
reachable by nothing the code shows, and the verb and path a reader would write down are an
inference from the action name. Say so rather than inventing `POST /projects/:id/archive`;
an invented route is the kind of detail a reviewer pastes into a client and loses an hour to.

```
Use case B — Anyone lists projects to choose from
Unchanged code decides what that list contains, and archival changes what it should mean.

(no route defined) → ProjectsController#index → ActiveProjects#call
  → Project.where(discarded_at: nil).order(:name)
```

## Stated gaps

- **Nothing prevents archiving twice.** `archive!` re-stamps `archived_at` on an already
  archived project. No test covers it, and no code refuses it.
- **Nothing prevents new time entries against an archived project.** The goal implies it;
  no code or test in this diff does it. Inferred from naming, and it is the kind of gap one
  question to the author settles.
- **The slug uniqueness validation is unrelated to archival.** It arrives in the same hunk.
  Secondary work, reviewable on its own, and neutrality is the register — not a complaint
  about bundling.
