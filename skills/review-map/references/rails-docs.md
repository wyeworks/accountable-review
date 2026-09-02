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
asymmetry is why this file prefers a **page-level URL it is certain of** to a deeper link it is not.
Precision is worth having; it is not worth a dead link.

There used to be a `†` mark here for a row whose fragment nobody had opened. It is gone, and its
absence is a claim: `evals/verify-catalogue.sh` opens **every** fragment in this file, in every series,
so "unverified anchor" is no longer a state a row can be in. Retiring the mark is only honest as long
as that script keeps running — see § *Version*.

Two shapes, and only these two hosts, for Rails itself. These are the **paths this file stores**; the
version segment is added at emit time, so no row below carries one — § *Pinning* has the emitted form:

```
guides.rubyonrails.org/<page>.html[#<section>]
api.rubyonrails.org/classes/<Namespace>/<Class>.html[#method-i-<name>]
```

`#method-i-` is the instance-method anchor and `#method-c-` the class-method one. The trap: methods
that read like class methods — `has_many`, `after_commit`, `perform_later` — are usually documented as
**instance** methods of a `ClassMethods` module, so they take `#method-i-`. Getting that wrong is
harmless (see above), getting the class wrong is not.

But *usually* is doing real work in that sentence, and the pattern is not a rule you can derive a row
from. `disable_ddl_transaction!` really is `#method-c-`. `insert_all` is not on a `ClassMethods` page
at all — Rails documents it on `ActiveRecord::Relation`, and this file asserted
`Persistence/ClassMethods.html#method-i-insert_all` for a while, which returns 200 and lands the
reader on a real page that does not mention the method. That is worse than a 404, because nothing
about it looks wrong. **A row comes from a page someone opened, never from this pattern.**

A gem is a third shape, and it takes a **tag**, never a branch:

```
https://github.com/<owner>/<repo>/tree/v{version}[#<readme-section>]
```

`{version}` is substituted from `Gemfile.lock` at emit time — see § *Pinning*. A tag was chosen over
`rubydoc.info/gems/<gem>/<version>`, which also pins, for one reason: rubydoc re-renders the README
with YARD anchors (`#Adding_an_index_non_concurrently`), so every fragment in this file would need
re-deriving and re-verifying in a second dialect, and rubydoc's coverage varies per gem. GitHub keeps
the anchors this file already carries, and it shows the tag on the page, which is what lets a reader
confirm the version themselves.

**Never `blob/`, `pull/` or `compare/`, even for a gem's docs.** `evals/checks/page-invariants.sh` § 5
greps the page for `github.com/.../(blob|pull|compare)/` and fails a page that emits one when the head
commit is unpushed, because those are the shapes a dead permalink takes. `tree/<tag>` does not match
it — deliberately, and it is the only `github.com` shape a doc link may take.

## Pinning

**Every URL in this file is a path, not a link. The run pins it to the app's own version before it
reaches the page.** The paths below carry no version segment; the run inserts one:

```
guides   https://guides.rubyonrails.org/v{series}/<page>.html[#<section>]
api      https://api.rubyonrails.org/v{series}/classes/<Namespace>/<Class>.html[#method-i-<name>]
gem      https://github.com/<owner>/<repo>/tree/v{version}[#<readme-section>]
```

`{series}` is the Rails `major.minor` from the `rails (x.y.z)` line in `Gemfile.lock`, recorded in
step 2 — `rails (8.0.2)` gives `v8.0`. `{version}` is the gem's exact locked version. Both hosts serve
a series path and resolve it to the newest patch in that series, so a patch number is never needed
and never guessed.

**This is unconditional.** Not only for rows whose behaviour moved — every row, including the ones
that have meant the same thing for a decade. Two reasons, and the second is the one that matters:

- A reviewer working on a 7.1 app should land on 7.1 documentation even for a concept that never
  changed, because the page they read then matches the code in front of them.
- **A pinned Rails doc page states its own version in its header** — "Ruby on Rails 8.0.5.1" — and a
  GitHub tag shows the tag. So the reader can check the pin against their own lock file at a glance.
  That is the whole difference between a link they have to trust and one they can verify. An
  unpinned link offers nothing to check.

**Above the verified ceiling, pin anyway.** If the app runs a series newer than § *Version* was last
verified against, the run still pins to it. The path shapes are structurally stable, so the link
almost certainly resolves; and because the page self-identifies, a reader sees any mismatch that
survives. Running `evals/verify-catalogue.sh` with the new series in its floor is what closes it
properly. Falling back to unpinned current stable would be worse: it would hide the staleness behind a
link that looks the same as every other.

**Below the floor, or where a row has no verified path for that series, emit no link.** Explain the
mechanism in prose, cite the repo line, and propose a probe. An unlinked explanation is never
misleading; a link to the wrong version is. Failing closed is the point — see § *Rows that differ by
series*.

## Version

**Verified 2026-09-02 against series 7.1, 7.2, 8.0 and 8.1** by `evals/verify-catalogue.sh`: 92 paths
across 57 rows, which is 322 pinned URLs once each is expanded per series and the gem rows resolved to
a release. Every fragment opened, in every series.

**The path cannot rot; the anchor and the class can, and that is the failure this file has actually
had.** Tracking current stable means a row silently starts describing a newer Rails than the app
under review. The first re-check, with `evals/verify-catalogue.sh`, found **8 defects in the 88 URLs it then held**, in
three classes that want three different fixes:

- **Drift.** 7.2 moved `insert_all` off `Persistence::ClassMethods` to `Relation` and pluralised the
  validations guide's `#conditional-validation`; the controller guide renamed *Filters* twice, to
  `#action-callbacks` in 7.2 and `#controller-callbacks` in 8.0. Every one of these returned 200.
- **Never existed.** `active_record_nested_attributes.html` 404s in every series back to 6.1. That is
  not rot — it is a plausible URL constructed once and then admitted to the allowlist, which is the
  exact thing the top of this file forbids. Reading carefully is what catches this one; nothing else
  does.
- **The host changed underneath.** `#readme` is no longer an anchor GitHub emits, so three gem rows
  pointed at a fragment that does nothing. Harmless — the repository root shows the README anyway —
  and the fix is the one this file already prescribes: drop the fragment.

The first two classes are why this file pins now. An unversioned path is not a neutral default: it
silently means *current stable*, so the reader of a 7.1 app is handed 8.1 documentation and given
nothing on the page to notice it with. Pinning does not make the file more correct — it makes the
mismatch **visible**, because the page then states which Rails it is describing.

One-time human verification is the wrong shape for the rest. `evals/verify-catalogue.sh` is the shape
that fits: every row, every series in the floor, dated.

## Rows that differ by series

Three rows out of 57 do not resolve to the same path in every series. Each carries its override
inline, in the cell, as `· <series>: <path>` — right where a run is already looking, rather than in a
cross-referenced table it has to remember to consult. The run takes the override when the app's series
matches, and the bare path otherwise.

| Row | Bare path applies | Override |
|---|---|---|
| `insert_all` / `upsert_all` | 7.2 and up | 7.1 documents it on `Persistence::ClassMethods` |
| `before_action` order | 8.0 and up | 7.2 calls the section `#action-callbacks`, 7.1 `#filters` |
| Conditional validation | 7.2 and up | 7.1 uses the singular `#conditional-validation` |

A row with no override for the app's series yields **no link**, per § *Pinning*.

## What the marks mean

`†` is gone (§ *Why a bad anchor is survivable*). One mark remains, and it is about the **sentence**,
never the link — pinning has taken the link's version problem away entirely, so a mark here says
nothing about which URL to emit. It says what the page is allowed to claim.

| Mark | Means | The run must |
|---|---|---|
| *(none)* | The behaviour has not changed across the verified series | State it, link it, move on |
| `‡ probe` | The behaviour **changed** inside the range, so no single sentence is true of every app | Not assert it. Ask the app: propose a probe, and name the setting that decides it |
| `‡ since X` | Surface was added in X; the default this row describes still holds | State it *as the default*, and name X where a reader could meet the new surface |

The two are not severities, they are different actions, and collapsing them would cost something in
both directions. `‡ probe` on a row that only gained an option would push a probe onto a page that
did not need one — the tutorial-with-a-diff-attached regression, arriving as diligence. `‡ since` on a
row whose assertion is flatly false for some supported version would leave the page asserting it.

The audit that produced these marks read the Active Record, Active Job, Action Pack and Active Support
CHANGELOGs for 7.2, 8.0 and 8.1. It is re-run when the floor gains a series, and it is the half of
this file no script can check: `verify-catalogue.sh` proves a URL resolves, never that the sentence
above it is true of the version it resolves to.

---

## Persistence and bulk writes

| Concept the reviewer meets | Guide | API |
|---|---|---|
| `update_all` writes SQL directly: no validations, no callbacks, no `updated_at` | `active_record_callbacks.html#skipping-callbacks` | `ActiveRecord/Relation.html#method-i-update_all` |
| `delete_all` skips `dependent:` and `destroy` callbacks | — | `ActiveRecord/Relation.html#method-i-delete_all` |
| `insert_all` / `upsert_all` never instantiate a model | `active_record_querying.html` | `ActiveRecord/Relation.html#method-i-insert_all` · 7.1: `ActiveRecord/Persistence/ClassMethods.html#method-i-insert_all` |
| `update_column` skips validations, callbacks and timestamps ‡ since 8.1 | — | `ActiveRecord/Persistence.html#method-i-update_column` |
| `touch` and `record_timestamps` | — | `ActiveRecord/Persistence.html#method-i-touch` |
| Which attribute changed, before or after save | `active_record_callbacks.html` | `ActiveRecord/AttributeMethods/Dirty.html` |

## Callbacks and transactions

| Concept | Guide | API |
|---|---|---|
| Callback order, and which ones a bulk write bypasses | `active_record_callbacks.html` | `ActiveRecord/Callbacks.html` |
| `after_commit` vs `after_save` — what has actually been written | `active_record_callbacks.html#transaction-callbacks` | `ActiveRecord/Transactions/ClassMethods.html#method-i-after_commit` |
| A nested `transaction` joins its parent unless `requires_new: true` | — | `ActiveRecord/Transactions/ClassMethods.html#method-i-transaction` |
| `after_rollback`, and what it can and cannot observe | — | `ActiveRecord/Transactions/ClassMethods.html#method-i-after_rollback` |
| Row locks: `lock!` and `with_lock` | `active_record_querying.html#pessimistic-locking` | `ActiveRecord/Locking/Pessimistic.html#method-i-with_lock` |
| Optimistic locking and `lock_version` | — | `ActiveRecord/Locking/Optimistic.html` |

## Validations and constraints

| Concept | Guide | API |
|---|---|---|
| A uniqueness validation is not a unique index, and races defeat it | `active_record_validations.html#uniqueness` | `ActiveRecord/Validations/ClassMethods.html#method-i-validates_uniqueness_of` |
| Which validators are actually on an attribute | `active_record_validations.html` | `ActiveModel/Validations/ClassMethods.html` |
| `save` vs `save!` vs `update` — what each returns and raises | `active_record_validations.html` | `ActiveRecord/Persistence.html#method-i-save` |
| Conditional validation with `:if` / `:on` | `active_record_validations.html#conditional-validations` · 7.1: `active_record_validations.html#conditional-validation` | — |

## Associations, scopes and queries

| Concept | Guide | API |
|---|---|---|
| `dependent:` options, and what each does to children | `association_basics.html` | `ActiveRecord/Associations/ClassMethods.html#method-i-has_many` |
| `inverse_of`, and when Rails cannot infer it | `association_basics.html` | `ActiveRecord/Associations/ClassMethods.html#method-i-belongs_to` |
| `default_scope` applies to `new` and `create`, not only to reads | `active_record_querying.html#scopes` | `ActiveRecord/Scoping/Default/ClassMethods.html#method-i-default_scope` |
| A scope is composable and lazy; a class method may not be | `active_record_querying.html#scopes` | `ActiveRecord/Scoping/Named/ClassMethods.html#method-i-scope` |
| `includes` vs `preload` vs `eager_load` | `active_record_querying.html#eager-loading-associations` | `ActiveRecord/QueryMethods.html#method-i-includes` |
| `find_each` batches, and overrides your `order` | `active_record_querying.html#retrieving-multiple-objects-in-batches` | `ActiveRecord/Batches.html#method-i-find_each` |
| An explicit `select` list omits columns, and reading one raises | `active_record_querying.html#selecting-specific-fields` | `ActiveRecord/QueryMethods.html#method-i-select` |
| Counter caches drift unless backfilled | — | `ActiveRecord/CounterCache/ClassMethods.html#method-i-reset_counters` |
| `enum` generates predicates, scopes and a values map ‡ probe | — | `ActiveRecord/Enum.html` |
| Nested attributes, and what `_destroy` permits | — | `ActiveRecord/NestedAttributes/ClassMethods.html` |
| Interpolating into SQL, and what sanitises it | `security.html#sql-injection` | `ActiveRecord/Sanitization/ClassMethods.html` |

## Migrations and schema

| Concept | Guide | API |
|---|---|---|
| Reversibility, and what `change` cannot undo ‡ since 8.0 | `active_record_migrations.html` | `ActiveRecord/Migration.html` |
| `add_index`, and `algorithm: :concurrently` on Postgres | `active_record_migrations.html` | `ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-add_index` |
| `disable_ddl_transaction!`, and why a concurrent index needs it | — | `ActiveRecord/Migration.html#method-c-disable_ddl_transaction-21` |
| Adding `NOT NULL` to a populated column | `active_record_migrations.html` | `ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-change_column_null` |
| `schema.rb` vs `structure.sql`, and what each loses | `active_record_migrations.html#schema-dumping-and-you` | — |
| Postgres specifics: types, indexes, exclusion constraints | `active_record_postgresql.html` | — |

## Controllers, routing, serialization

| Concept | Guide | API |
|---|---|---|
| Strong parameters, and what `permit!` gives up ‡ probe | `action_controller_overview.html#strong-parameters` | `ActionController/Parameters.html` |
| `before_action` order, `only`/`except`, and `skip_before_action` | `action_controller_overview.html#controller-callbacks` · 7.2: `action_controller_overview.html#action-callbacks` · 7.1: `action_controller_overview.html#filters` | `AbstractController/Callbacks/ClassMethods.html#method-i-before_action` |
| Routing: `resources`, member and collection routes | `routing.html` | `ActionDispatch/Routing/Mapper/Resources.html` |
| What an API-only app leaves out of the middleware stack | `api_app.html` | — |
| Rendering a status code, and which symbol maps to which number | `action_controller_overview.html` | `ActionController/Renderers.html` |

## Jobs and background work

| Concept | Guide | API |
|---|---|---|
| `perform_later` enqueue timing is decided by `enqueue_after_transaction_commit` ‡ probe | `active_job_basics.html` | `ActiveJob/Enqueuing/ClassMethods.html#method-i-perform_later` |
| Arguments are serialized, so a deployed change can meet an old payload ‡ since 7.2 | `active_job_basics.html#supported-types-for-arguments` | `ActiveJob/Serializers.html` |
| `retry_on` / `discard_on`, and what happens on the last attempt ‡ since 7.2 | `active_job_basics.html#exceptions` | `ActiveJob/Exceptions/ClassMethods.html#method-i-retry_on` |
| Testing enqueues rather than running them | `testing.html#testing-jobs` | `ActiveJob/TestHelper.html` |

## Time, zones and types

| Concept | Guide | API |
|---|---|---|
| `Time.current` / `Date.current` respect the app zone; `Time.now` does not | `configuring.html` | `ActiveSupport/TimeWithZone.html` |
| `time_zone_aware_attributes`, and which column types it covers | `configuring.html` | — |
| Duration arithmetic across DST | — | `ActiveSupport/Duration.html` |

## Instrumentation and caching

| Concept | Guide | API |
|---|---|---|
| Subscribing to `sql.active_record` to count queries ‡ since 8.1 | `active_support_instrumentation.html` | `ActiveSupport/Notifications.html` |
| Cache keys, and what `cache_key_with_version` includes | `caching_with_rails.html` | `ActiveRecord/Integration.html#method-i-cache_key` |

## Gems

Only gems this skill's lenses already reason about. Add a row when a lens needs it, not speculatively.

| Gem | Concept | URL |
|---|---|---|
| strong_migrations | Why a non-concurrent index is refused | `https://github.com/ankane/strong_migrations/tree/v{version}#adding-an-index-non-concurrently` |
| strong_migrations | Backfilling in its own migration | `https://github.com/ankane/strong_migrations/tree/v{version}#backfilling-data` |
| strong_migrations | `safety_assured`, and what it silences | `https://github.com/ankane/strong_migrations/tree/v{version}#assuring-safety` |
| Pundit | Policy lookup, and `authorize` raising | `https://github.com/varvet/pundit/tree/v{version}#policies` |
| Pundit | `verify_authorized`, so a new action cannot skip the check | `https://github.com/varvet/pundit/tree/v{version}#ensuring-policies-and-scopes-are-used` |
| Sidekiq | Idempotency and retries | `https://github.com/sidekiq/sidekiq/wiki/Best-Practices` |
| Sidekiq | What happens after the last retry | `https://github.com/sidekiq/sidekiq/wiki/Error-Handling` |
| Devise | Which modules a model includes, and what each adds | `https://github.com/heartcombo/devise/tree/v{version}` |
| RSpec Rails | Spec types and what each loads | `https://github.com/rspec/rspec-rails/tree/v{version}` |
| FactoryBot | A changed default reaches every spec | `https://github.com/thoughtbot/factory_bot/tree/v{version}` |

Three things about these rows that the Rails rows do not have to deal with.

**The `v` prefix is data, not a convention you may derive.** All five tagged gems above use `v8.0.4`
and 404 on `8.0.4`, which was checked — but plenty of gems tag without it, so a new gem row's tag form
is verified when the row is added, exactly like its anchor.

**Pundit's `#ensuring-policies-and-scopes-are-used` exists from 2.0.** Pundit 1.x has no such section,
so an app locked to 1.x gets no link on that row — the fail-closed rule in § *Pinning*, arriving from
the gem axis instead of the Rails one.

**The two Sidekiq rows cannot be pinned at all**, because a GitHub wiki has no tags. They are kept
because idempotency-and-retries is advice no Sidekiq version has reversed, and that is the whole
condition on using them: **a wiki row may only carry a claim that no version turns on.** Anything
version-specific about Sidekiq needs its CHANGELOG, which means a new row pointing at a tag.

---

`· <series>: <path>` in a cell is a per-series override — take it when the app's series matches,
the bare path otherwise, and no link at all when neither applies. § *Rows that differ by series*.

`‡ probe` and `‡ since X` are about the sentence, never the link. § *What the marks mean*.

## Adding a row

Open the URL. Not "recall" it, not derive it from the naming pattern — open it, confirm the page
documents the concept in the row, and confirm the fragment scrolls somewhere sensible. For a gem, that
includes the tag form: `v2.8.0` and `2.8.0` are not interchangeable and only one of them exists.

Then run `evals/verify-catalogue.sh`, which is the mechanical half of the same sentence: it will tell
you the page resolves and the fragment exists, in every series. It cannot tell you the page documents
the concept in the row — that is why the paragraph above comes first and is not replaceable by the
script. The one defect the first sweep found that no script would have caught was a guide page that
had never existed for a concept the row described accurately.

A concept nobody has verified a URL for is still usable: explain it in prose and cite the repo line
it applies to. That is the normal case, not a degraded one — the page's job is to explain *this*
change, and a link is only ever an aid to that.
