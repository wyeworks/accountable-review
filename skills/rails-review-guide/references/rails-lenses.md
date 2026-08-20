# Rails lenses

What to look for, per layer. This is the knowledge a senior Rails reviewer applies from memory and
that cannot be inferred from a diff — it is what makes the guide a Rails review rather than a
change summary.

**Apply these as lenses while reading, never as a checklist in the output.** The page reports what
was actually found, with `file:line`. It never says "we checked for N+1" as reassurance — an absent
finding is reported by absence, not by a green tick.

---

## Migrations

- Reversible? Does `change` contain anything irreversible, and is there a `down`?
- Does it lock a table for a meaningful time — adding a column with a default on a large table,
  adding an index non-concurrently, changing a column type?
- Index added without `algorithm: :concurrently` (Postgres), and is `disable_ddl_transaction!` set
  where required?
- `NOT NULL` added to an existing column, or a default backfilled into existing rows?
- A data backfill in the same migration as the schema change — usually wants separating, so a slow
  backfill does not hold a DDL transaction.
- Destructive: dropping a column or table, especially one the running code still references. The
  safe order is deploy-then-drop, and a single migration cannot do both.
- Is `strong_migrations` installed? If so, what would it say — and if a check is skipped with
  `safety_assured`, is the reasoning recorded?

## Schema

- Does the committed schema file match what the migrations actually produce? A mismatch means
  `db:migrate` and `db:schema:load` disagree, and it is often a merge artifact or a leak from
  another branch's development database.
- Foreign keys without a supporting index.
- Foreign keys without an `on_delete` — deletion then depends entirely on Rails' `dependent:`.
- Constraints enforced only in Ruby where the database could enforce them: uniqueness without a
  unique index, enum-ish string columns without a check constraint.
- Column types: money as float; timestamps as `date` where time matters, or the reverse; JSON blobs
  with no schema and no validation.

## Models

- `default_scope` added — rarely benign, and it surprises every future query.
- Callbacks doing I/O, sending mail, enqueuing jobs, or touching other aggregates. `after_commit`
  versus `after_save` matters, and the difference is usually a bug when chosen carelessly.
- `dependent:` on new associations — chosen deliberately, or omitted by accident? `:destroy` on a
  large association is a performance question too.
- `update_all` / `delete_all` / `update_column` bypassing validations, callbacks, and timestamps.
  Sometimes correct, always worth naming.
- Validation with no database constraint behind it, where concurrent requests can defeat it —
  uniqueness above all.
- STI or polymorphic associations added; counter caches added without a backfill.
- Business logic on the record that belongs in a service, and vice versa.
- Enum or status columns: is the transition legal set enforced anywhere, or can any caller write any
  value?

## Controllers, routes, serialization

- Strong params complete, and no `permit!`.
- N+1 introduced. Does the project use `bullet` or a query-count assertion that would have caught
  it?
- Unbounded collections without pagination or a limit.
- A `before_action` chain whose order changed, or a new action that misses a filter the others have.
- Authorization on every new action — check the project's library rather than assuming, and watch
  for an action added to a controller whose other actions are all gated.
- Routes that do not match the project's existing style (custom actions where the codebase uses
  `resources`, or a verb that differs from how sibling state transitions are spelled).
- **Serialization changes are breaking changes no compiler catches**: a renamed or removed field, a
  type that changed, a key that became conditionally absent.
- Long-running or external work inside the request cycle, and whether it belongs in a job.
- Error responses: do they follow the shape the rest of the API uses, and does the status code match
  the semantics (409 for a conflict, not 422)?

## Services, jobs, and background work

- External calls inside a database transaction — the transaction holds locks while the network is
  slow, and a rollback cannot undo the call.
- A job enqueued inside a transaction that has not committed: the worker can start before the row
  exists. `after_commit` or an outbox is the fix.
- Retries without idempotency. If the job runs twice, what happens?
- Failure mode: what happens on the last retry, and does anything observe it?
- Transaction boundaries and `requires_new` — a nested transaction that silently joins its parent
  will not roll back what the author expects.
- Locking: `with_lock` / `lock!` present where two requests can race, and does the lock actually do
  anything on this database?
- Unbounded queries or loops that scale with user data.
- God objects: a service that grew past coherent responsibility, and where the natural seam is.

## Time, money, and data types

- `Time.now` / `Date.today` instead of `Time.current` / `Date.current` — wrong in any app with a
  configured zone.
- Naive date arithmetic across zones or DST.
- Floats for money where the project uses integers or `BigDecimal`.
- Timestamps stored without a zone, or a `date` column where an instant was meant.

## Dependencies and configuration

- A new gem for something the stdlib, Rails, or an existing dependency already does.
- Version constraints: why is it pinned, and what does the pin block?
- New env vars: is there a default, and what happens when it is unset? Does the app fail loudly at
  boot or silently at the first request?
- Secrets or credentials committed, or logged.
- Logging that includes personal data, especially anything on by default.

## Tests

- New behaviour with no test, or a test that asserts the mock rather than the behaviour.
- Error paths and authorization failures left uncovered — the most commonly missed cases.
- External calls not stubbed, making the suite dependent on the network.
- Time-dependent tests without freezing time.
- A factory changed in a way that affects unrelated specs.
- Tests deleted or skipped as part of the change, which deserves an explicit note either way.
