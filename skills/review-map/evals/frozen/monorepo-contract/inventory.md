# Inventory — monorepo-contract

`git diff --name-status HEAD~1`, bucketed as step 3 buckets it. Seven paths across both sides.

| Status | Path | Bucket |
|---|---|---|
| M | `api/app/controllers/projects_controller.rb` | routes, controllers, serializers |
| M | `api/app/models/project.rb` | models |
| M | `api/app/serializers/project_serializer.rb` | routes, controllers, serializers |
| A | `api/db/migrate/20260101000000_add_archived_at_to_projects.rb` | migrations and schema |
| M | `api/spec/requests/projects_spec.rb` | backend tests |
| M | `web/src/hooks/useProjects.ts` | frontend source |
| M | `web/src/types/project.ts` | frontend types and API client |

Metric strip: 7 files, 1 commit. Four backend production files, one backend spec, two
frontend files, no generated files, no frontend tests.

**There is no `api/db/schema.rb` in this repository.** The migration adds a column and
nothing records the resulting schema, so there is no committed artefact to compare the
migration against — the schema-versus-migration consistency question has no answer here, and
that is the answer.

Also absent: any frontend test, any route file, and any factory definition (the specs call
`create(:project)` against a factory that does not exist in the repository).
