# Inventory — rails-only-small

`git diff --name-status HEAD~1`, bucketed as step 3 buckets it. Five paths, 38 insertions,
2 deletions.

| Status | Path | Bucket | Lines |
|---|---|---|---|
| M | `app/controllers/projects_controller.rb` | routes, controllers, serializers | +6 −1 |
| M | `app/models/project.rb` | models | +8 |
| A | `db/migrate/20260101000000_add_archived_at_to_projects.rb` | migrations and schema | +6 |
| M | `db/schema.rb` | generated | +3 −1 |
| M | `spec/models/project_spec.rb` | backend tests | +15 |

Metric strip: 5 files, 1 commit. Production 14, test 15, generated 3, docs 0 — the split
matters here, because `db/schema.rb` is checked-in output of the migration and not review
surface of its own.

No frontend source, no frontend types, no tooling, no config or dependency changes.
