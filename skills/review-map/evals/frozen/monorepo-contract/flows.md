# Flow split — monorepo-contract

Grouping principle: **one flow per field crossing the boundary, plus one per behaviour that
reads what the field changed.** Following a single field end to end teaches more than
reviewing the two sides as separate file trees, and it is the only grouping under which the
serializer, the type and the hook appear in the same paragraph.

```
Flow A — Archiving a project, end to end   primary
Flow B — Listing selectable projects       primary, and entirely outside the diff
```

## Flow A carries

- the write path: hook → route → controller → `archive!` → column;
- the endpoint contract: 200 with the serialized project, 422 with `{ error }`, and the
  side-effects row a diff cannot answer — it writes, it is not idempotent in effect (a second
  call re-stamps), it calls nothing external;
- the boundary chain (a .pipe, not an SVG) for `archived_at`: `ProjectSerializer` → JSON → `Project.archivedAt` →
  `useProjects` → `ProjectSelector`, and the three mismatches on it:
  - **the key is renamed and nothing renames it.** The wire carries `archived_at`; the type declares
    `archivedAt`; there is no API client, no case transform and no runtime parse between them
    (`rg -i 'camel|snake|humps|decamel' api web` is empty). So `p.archivedAt` is `undefined` for
    every project, archived or not, while the type promises a `string`. This is the sharper of the
    two type findings and it was **not** in the first version of this file — the first section run
    found it, which is the argument for running one three times;
  - the serializer emits `nil` for a project never archived, while the same declaration is non-null.
    Under the backend's own key this is still a mismatch, and it is the one the author's comment in
    the serializer points at;
  - the 422 the controller can return reaches a client that discards its body;
- the tests, and the branch they leave open.

## Flow B carries

`web/src/queries/selectableProjects.ts` — unchanged, in the diff nowhere, used by every
project picker, and filtering on `p.name.length > 0` in full ignorance of archival. After
this PR an archived project is still selectable. Nothing in the diff says so.

Leftover, not a flow:

| | Label | Why |
|---|---|---|
| `api/db/migrate/…add_archived_at…` | supporting | The column Flow A writes; covered inside it |
| `api/spec/requests/projects_spec.rb` | supporting | Belongs to Flow A's tests field |

Cross-cutting, for § 5: deploy ordering, because the two sides ship separately and the
client's non-null `archivedAt` breaks against a backend that has not deployed the serializer
change — name the safe order. Migration safety is a bare `add_column`, no index, no backfill.
