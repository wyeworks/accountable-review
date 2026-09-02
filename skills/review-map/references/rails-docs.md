# Rails documentation catalogue

The URLs the page is allowed to cite. **A doc link that is not in this file does not go on the page** —
not a guessed anchor, not an "obvious" API path, not a URL you are fairly sure of. The run cannot
check a URL: there is no fetch step in the procedure, and the sandboxes this skill commonly runs in
block egress to these hosts outright. So a link is either something a human opened once and wrote
down here, or it is a 404 the reader discovers on your behalf — and one dead link costs the same
trust as one invented rake task.

`references/report-format.md` § *Framework anchors* owns what a doc link is *for*, when a claim earns
one, and the budget. This file is only the lookup: concept in, URL out.

## Why a bad anchor is survivable and a bad path is not

A fragment a page does not have is ignored by every browser — `…/active_record_querying.html#nope`
still lands the reader on Active Record Querying. A wrong page or a wrong class name is a 404. That
asymmetry is why this file prefers a **page-level URL it is certain of** to a deeper link it is not,
and why rows carrying an unverified fragment are marked †. Precision is worth having; it is not worth
a dead link.

Two shapes, and only these two hosts, for Rails itself:

```
https://guides.rubyonrails.org/<page>.html[#<section>]
https://api.rubyonrails.org/classes/<Namespace>/<Class>.html[#method-i-<name>]
```

`#method-i-` is the instance-method anchor and `#method-c-` the class-method one. The trap: methods
that read like class methods — `has_many`, `insert_all`, `after_commit`, `perform_later` — are
documented as **instance** methods of a `ClassMethods` module, so they take `#method-i-`. Getting
that wrong is harmless (see above), getting the class wrong is not.

**Never a `github.com/…/blob/…` URL, even for a gem's docs.** `evals/checks/page-invariants.sh` § 5
greps the page for `github.com/.../(blob|pull|compare)/` and fails a page that emits one when the head
commit is unpushed, because those are the shapes a dead permalink takes. A gem's README is linked at
its repository root (`…/strong_migrations#adding-an-index-non-concurrently`), which does not match.

## Version

**Verified against Rails 8.0.** The URLs are unversioned, so they track current stable and cannot rot
into a `/v7.1/` path nobody re-checks.

Discover the app's Rails version in step 2 (`Gemfile.lock`, the `rails (x.y.z)` line). Where it is
older than the line above **and** the row is marked ‡ version-sensitive, say so in the sentence — *"on
Rails 7.1 this raises rather than warns"* — rather than pinning a URL you cannot open. A pinned path
is a second thing to verify and the run has no way to verify the first.

---

## Persistence and bulk writes

| Concept the reviewer meets | Guide | API |
|---|---|---|
| `update_all` writes SQL directly: no validations, no callbacks, no `updated_at` | `active_record_callbacks.html#skipping-callbacks` † | `ActiveRecord/Relation.html#method-i-update_all` |
| `delete_all` skips `dependent:` and `destroy` callbacks | — | `ActiveRecord/Relation.html#method-i-delete_all` |
| `insert_all` / `upsert_all` never instantiate a model | `active_record_querying.html` | `ActiveRecord/Persistence/ClassMethods.html#method-i-insert_all` |
| `update_column` skips validations, callbacks and timestamps | — | `ActiveRecord/Persistence.html#method-i-update_column` |
| `touch` and `record_timestamps` | — | `ActiveRecord/Persistence.html#method-i-touch` |
| Which attribute changed, before or after save | `active_record_callbacks.html` | `ActiveRecord/AttributeMethods/Dirty.html` |

## Callbacks and transactions

| Concept | Guide | API |
|---|---|---|
| Callback order, and which ones a bulk write bypasses | `active_record_callbacks.html` | `ActiveRecord/Callbacks.html` |
| `after_commit` vs `after_save` — what has actually been written | `active_record_callbacks.html#transaction-callbacks` † | `ActiveRecord/Transactions/ClassMethods.html#method-i-after_commit` |
| A nested `transaction` joins its parent unless `requires_new: true` ‡ | — | `ActiveRecord/Transactions/ClassMethods.html#method-i-transaction` |
| `after_rollback`, and what it can and cannot observe | — | `ActiveRecord/Transactions/ClassMethods.html#method-i-after_rollback` |
| Row locks: `lock!` and `with_lock` | `active_record_querying.html#pessimistic-locking` † | `ActiveRecord/Locking/Pessimistic.html#method-i-with_lock` |
| Optimistic locking and `lock_version` | — | `ActiveRecord/Locking/Optimistic.html` |

## Validations and constraints

| Concept | Guide | API |
|---|---|---|
| A uniqueness validation is not a unique index, and races defeat it | `active_record_validations.html#uniqueness` † | `ActiveRecord/Validations/ClassMethods.html#method-i-validates_uniqueness_of` |
| Which validators are actually on an attribute | `active_record_validations.html` | `ActiveModel/Validations/ClassMethods.html` |
| `save` vs `save!` vs `update` — what each returns and raises | `active_record_validations.html` | `ActiveRecord/Persistence.html#method-i-save` |
| Conditional validation with `:if` / `:on` | `active_record_validations.html#conditional-validation` † | — |

## Associations, scopes and queries

| Concept | Guide | API |
|---|---|---|
| `dependent:` options, and what each does to children | `association_basics.html` | `ActiveRecord/Associations/ClassMethods.html#method-i-has_many` |
| `inverse_of`, and when Rails cannot infer it | `association_basics.html` | `ActiveRecord/Associations/ClassMethods.html#method-i-belongs_to` |
| `default_scope` applies to `new` and `create`, not only to reads | `active_record_querying.html#scopes` † | `ActiveRecord/Scoping/Default/ClassMethods.html#method-i-default_scope` |
| A scope is composable and lazy; a class method may not be | `active_record_querying.html#scopes` † | `ActiveRecord/Scoping/Named/ClassMethods.html#method-i-scope` |
| `includes` vs `preload` vs `eager_load` | `active_record_querying.html#eager-loading-associations` † | `ActiveRecord/QueryMethods.html#method-i-includes` |
| `find_each` batches, and overrides your `order` | `active_record_querying.html#retrieving-multiple-objects-in-batches` † | `ActiveRecord/Batches.html#method-i-find_each` |
| An explicit `select` list omits columns, and reading one raises | `active_record_querying.html#selecting-specific-fields` † | `ActiveRecord/QueryMethods.html#method-i-select` |
| Counter caches drift unless backfilled | — | `ActiveRecord/CounterCache/ClassMethods.html#method-i-reset_counters` |
| `enum` generates predicates, scopes and a values map ‡ | — | `ActiveRecord/Enum.html` |
| Nested attributes, and what `_destroy` permits | `active_record_nested_attributes.html` | `ActiveRecord/NestedAttributes/ClassMethods.html` |
| Interpolating into SQL, and what sanitises it | `security.html#sql-injection` † | `ActiveRecord/Sanitization/ClassMethods.html` |

## Migrations and schema

| Concept | Guide | API |
|---|---|---|
| Reversibility, and what `change` cannot undo | `active_record_migrations.html` | `ActiveRecord/Migration.html` |
| `add_index`, and `algorithm: :concurrently` on Postgres | `active_record_migrations.html` | `ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-add_index` |
| `disable_ddl_transaction!`, and why a concurrent index needs it | — | `ActiveRecord/Migration.html#method-i-disable_ddl_transaction-21` † |
| Adding `NOT NULL` to a populated column | `active_record_migrations.html` | `ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-change_column_null` |
| `schema.rb` vs `structure.sql`, and what each loses | `active_record_migrations.html#schema-dumping-and-you` † | — |
| Postgres specifics: types, indexes, exclusion constraints | `active_record_postgresql.html` | — |

## Controllers, routing, serialization

| Concept | Guide | API |
|---|---|---|
| Strong parameters, and what `permit!` gives up | `action_controller_overview.html#strong-parameters` † | `ActionController/Parameters.html` |
| `before_action` order, `only`/`except`, and `skip_before_action` | `action_controller_overview.html#filters` † | `AbstractController/Callbacks/ClassMethods.html#method-i-before_action` |
| Routing: `resources`, member and collection routes | `routing.html` | `ActionDispatch/Routing/Mapper/Resources.html` |
| What an API-only app leaves out of the middleware stack | `api_app.html` | — |
| Rendering a status code, and which symbol maps to which number | `action_controller_overview.html` | `ActionController/Renderers.html` |

## Jobs and background work

| Concept | Guide | API |
|---|---|---|
| `perform_later` enqueues immediately — before the transaction commits ‡ | `active_job_basics.html` | `ActiveJob/Enqueuing/ClassMethods.html#method-i-perform_later` |
| Arguments are serialized, so a deployed change can meet an old payload | `active_job_basics.html#supported-types-for-arguments` † | `ActiveJob/Serializers.html` |
| `retry_on` / `discard_on`, and what happens on the last attempt | `active_job_basics.html#exceptions` † | `ActiveJob/Exceptions/ClassMethods.html#method-i-retry_on` |
| Testing enqueues rather than running them | `testing.html#testing-jobs` † | `ActiveJob/TestHelper.html` |

## Time, zones and types

| Concept | Guide | API |
|---|---|---|
| `Time.current` / `Date.current` respect the app zone; `Time.now` does not | `configuring.html` | `ActiveSupport/TimeWithZone.html` |
| `time_zone_aware_attributes`, and which column types it covers | `configuring.html` | — |
| Duration arithmetic across DST | — | `ActiveSupport/Duration.html` |

## Instrumentation and caching

| Concept | Guide | API |
|---|---|---|
| Subscribing to `sql.active_record` to count queries | `active_support_instrumentation.html` | `ActiveSupport/Notifications.html` |
| Cache keys, and what `cache_key_with_version` includes | `caching_with_rails.html` | `ActiveRecord/Integration.html#method-i-cache_key` |

## Gems

Only gems this skill's lenses already reason about. Add a row when a lens needs it, not speculatively.

| Gem | Concept | URL |
|---|---|---|
| strong_migrations | Why a non-concurrent index is refused | `https://github.com/ankane/strong_migrations#adding-an-index-non-concurrently` † |
| strong_migrations | Backfilling in its own migration | `https://github.com/ankane/strong_migrations#backfilling-data` † |
| strong_migrations | `safety_assured`, and what it silences | `https://github.com/ankane/strong_migrations#assuring-safety` † |
| Pundit | Policy lookup, and `authorize` raising | `https://github.com/varvet/pundit#policies` † |
| Pundit | `verify_authorized`, so a new action cannot skip the check | `https://github.com/varvet/pundit#ensuring-policies-and-scopes-are-used` † |
| Sidekiq | Idempotency and retries | `https://github.com/sidekiq/sidekiq/wiki/Best-Practices` |
| Sidekiq | What happens after the last retry | `https://github.com/sidekiq/sidekiq/wiki/Error-Handling` |
| Devise | Which modules a model includes, and what each adds | `https://github.com/heartcombo/devise#readme` |
| RSpec Rails | Spec types and what each loads | `https://github.com/rspec/rspec-rails#readme` |
| FactoryBot | A changed default reaches every spec | `https://github.com/thoughtbot/factory_bot#readme` |

---

† the fragment is unverified: the page or class is certain, the `#anchor` is not. Drop the fragment
rather than guess a different one — landing at the top of the right page is a good outcome.

‡ version-sensitive: check the app's Rails version before stating the behaviour, and say which
version you are describing.

## Adding a row

Open the URL. Not "recall" it, not derive it from the naming pattern — open it, confirm the page
documents the concept in the row, and confirm the fragment scrolls somewhere sensible. Then add the
row, and drop the `†` if you checked the anchor.

A concept nobody has verified a URL for is still usable: explain it in prose and cite the repo line
it applies to. That is the normal case, not a degraded one — the page's job is to explain *this*
change, and a link is only ever an aid to that.
