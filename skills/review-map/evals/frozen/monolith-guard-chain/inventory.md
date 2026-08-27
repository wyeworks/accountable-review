# Inventory — monolith-guard-chain

`git diff --name-status HEAD~1`, bucketed as step 3 buckets it. Seven paths, 118 insertions,
7 deletions.

| Status | Path | Bucket | Lines |
|---|---|---|---|
| M | `app/controllers/application_controller.rb` | routes, controllers, serializers | +5 −1 |
| M | `app/controllers/steward_invites_controller.rb` | routes, controllers, serializers | +2 −1 |
| M | `app/controllers/users/registrations_controller.rb` | routes, controllers, serializers | +5 −2 |
| M | `app/models/chapter.rb` | models | +5 −1 |
| M | `test/controllers/steward_invites_controller_test.rb` | backend tests | +3 −1 |
| A | `test/controllers/steward_section_redirect_test.rb` | backend tests | +68 |
| M | `test/models/chapter_test.rb` | backend tests | +30 −1 |

Metric strip: 7 files, 1 commit. **Production +17 −5, test +101 −2**, generated 0, docs 0.

That split is the fact the page has to lead with. Four production lines carry the entire
change, and 85% of the diff is test. Everything a reviewer needs to think hard about is in
files that are not in this table.

- No migration, no `db/schema.rb` change, no new column. `db/schema.rb` is untouched and is
  therefore **evidence**, not review surface.
- No `config/routes.rb` change: no route added or removed. Three of the four production
  changes only alter where an existing action sends the browser.
- No new dependency, no generated file, no lockfile, no docs, no i18n key added or removed —
  `t(".success")` and its `chapter_name` interpolation are reused unchanged.
- No frontend source, because there is no frontend package. The ERB views are untouched.
