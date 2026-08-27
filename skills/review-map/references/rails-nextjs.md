# Rails and Next.js lenses

What to look for, per layer, plus the search recipes for finding code the diff did not touch. This is
the knowledge a senior reviewer applies from memory and that cannot be inferred from a diff — it is
what makes the page a review map rather than a change summary.

The first target stack is a Rails API with a Next.js client, and the boundary between them gets the
sharpest lenses here because it is the one seam with no compiler behind it. Everything is still
discovered, never assumed: a Rails-only repo simply never reaches those lenses.

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

## The boundary: serializers to types

This is the one place in the stack with no compiler and no test that spans it, which is why the page
follows one field across it end to end — inside the flow that owns the field, not as a section of
its own. What to look for:

- A **nullable backend field typed non-null** on the client. The Ruby side returns `nil` on some path;
  the TS side declares `string`. Nothing fails until that path runs in production.
- A **backend enum value missing from the frontend union**. Adding a status is a breaking change for
  any client that switches exhaustively on it — and a silent one for any client that does not.
- A **new error status nothing handles**. If the endpoint can now return 409 or 422, find the client
  code that would receive it. "The generic error toast catches it" is an answer; no answer is a
  finding.
- **Response shape changed, stale reader left behind.** A renamed or removed key, a value that became
  conditionally absent, an array that became paginated. Grep the old key name across the client
  before believing it is unused.
- **A required param the client never sends**, or sends under a different case convention. Watch the
  camelCase/snake_case transform: whether it is applied by the API client, the serializer, or nowhere.
- **Date and money formats.** ISO 8601 with a zone versus without; integer cents versus a decimal
  string. Both sides can be individually correct and still disagree.
- **Identifier types.** A backend integer id serialized as a number and typed as `string`, or a UUID
  where the client assumed sequential.
- **Deploy ordering.** If the two sides ship independently, what breaks in the window where one is
  updated and the other is not — and which order is safe. An additive backend change deployed first
  is usually fine; a rename never is.
- **Generated versus hand-written types.** Generated types drift loudly, at build time. Hand-written
  ones drift silently. Know which this project uses before trusting the type as evidence of the
  response shape.
- **Runtime validation at the boundary.** If Zod or similar guards responses, a backend change can
  turn into a *client-side throw* rather than a wrong render — a different failure mode and a
  different blast radius. Check whether the schema was updated alongside the serializer, and whether
  validation is applied to every response or only some.

## Next.js

- **Server/client component boundary.** A `"use client"` added or removed changes where code runs,
  what it can reach, and what ships to the browser. A server-only import pulled into a client
  component is a build error; a secret read in one is a leak.
- **Env vars exposed to the client.** `NEXT_PUBLIC_` prefixed values are public, permanently. Check
  every new one.
- **Caching and revalidation.** `fetch` cache options, `revalidate`, `cache: "no-store"`, tag-based
  revalidation. A mutation that does not invalidate what it changed shows stale data; an over-broad
  invalidation costs performance. Both are invisible in the diff of the mutation itself.
- **Server actions.** They are POST endpoints with no route file: check authorization explicitly,
  because there is no `before_action` chain to inherit it from. Validate inputs the same way the API
  would.
- **Route handlers** (`route.ts`) as a second backend: does one duplicate logic the Rails API already
  owns, and which is now authoritative?
- **SSR versus client fetching.** Moving a fetch across that line changes who holds credentials, what
  the user sees first, and whether the request appears in the browser's network tab at all.
- **Suspense and loading boundaries** added or moved: what renders while data is pending, and what
  happens on error.

## TypeScript and the client

- `any`, `as`, or a non-null assertion introduced at the boundary — each one is a place the type
  system stopped checking, usually right where the backend contract lives.
- **Optional chaining hiding a contract change.** `data?.project?.name` compiles against anything;
  it is often the fix applied when a response shape changed, and it converts a type error into a
  blank space in the UI.
- Data-fetching cache keys: does a mutation invalidate every query whose data it invalidated?
  React Query and SWR both fail quietly here.
- Optimistic updates that assume a success shape the server no longer returns.
- Error handling in the API client: does a non-2xx reject, or resolve with a body the caller treats as
  data?
- Frontend tests: mocked responses that no longer match the serializer are the most common way a
  contract break passes CI on both sides.

## Tests

- New behaviour with no test, or a test that asserts the mock rather than the behaviour.
- Error paths and authorization failures left uncovered — the most commonly missed cases.
- External calls not stubbed, making the suite dependent on the network.
- Time-dependent tests without freezing time.
- A factory changed in a way that affects unrelated specs.
- Tests deleted or skipped as part of the change, which deserves an explicit note either way.

---

## Search recipes for affected-but-unchanged code

Step 5 of the procedure lives or dies on these. Run the search, then **record it** — an empty result
is a finding only if the reader can see what was looked for.

Adjust paths to the project layout discovered in step 2; `rg` is assumed, `grep -rn` works the same.

**A changed method or class**

```sh
rg -n '\bProjects::Archive\b' app lib spec        # callers and specs
rg -n 'archive[!?]?\(' app lib                    # the message being sent
rg -n 'include Archivable|< Project\b' app        # mixers and subclasses
```

**A changed or added column**

```sh
rg -n 'archived_at' app lib spec db/seeds.rb      # every reader and writer
rg -n 'archived_at' app/serializers app/views     # does it cross the boundary?
rg -n 'archived_at' --glob '*.ts' --glob '*.tsx'  # does the client know?
rg -n 'select\(|pluck\(|group\(' app/queries      # explicit column lists that now miss it
```

A column added to a table whose serializer uses an explicit attribute list is *not* exposed; one
serialized with `attributes` on the whole record is. That distinction decides whether part 5 applies
at all.

**A changed validation, callback, or default**

```sh
rg -n 'update_all|insert_all|upsert_all|update_column|delete_all' app lib
rg -n 'Project\.new|Project\.create|projects\.create' app lib spec
```

Bulk writes bypass validations and callbacks entirely. If the change relies on a callback, every hit
in the first search is a path where the new invariant does not hold.

**A changed enum or status value**

```sh
rg -n 'status ==|status:|\.active\?|\.archived\?' app lib
rg -n "'active'|\"active\"|:active" app lib spec
rg -n "'active'|\"active\"" --glob '*.ts' --glob '*.tsx'
```

**A changed JSON key or response shape**

```sh
rg -n 'archivedAt|archived_at' --glob '*.ts' --glob '*.tsx' --glob '*.json'
rg -n 'api/projects' --glob '*.ts' --glob '*.tsx'      # every caller of the endpoint
rg -n 'ProjectDTO|ProjectResponse|type Project\b' --glob '*.ts'
```

Search the **old** name as well as the new one. The stale reader is the finding; the updated one is
already in the diff.

**A changed route**

```sh
rg -n 'projects_path|project_url|/api/projects' app spec --glob '*.ts' --glob '*.tsx'
bin/rails routes | rg projects            # what the router actually exposes now
```

**A changed job or its arguments**

```sh
rg -n 'ArchiveProjectJob' app lib spec
rg -n 'perform_later|perform_async|enqueue' app lib | rg -i project
```

Also ask what happens to jobs **already queued** with the old argument shape when this deploys. A
worker deserializing yesterday's payload against today's signature is a failure no test covers.

**Factories and fixtures**

```sh
rg -n 'factory :project|projects:' spec/factories test/fixtures
```

A changed factory default reaches every spec in the suite, including ones nobody in this PR opened.

**Authorization**

```sh
rg -n 'class ProjectPolicy|authorize|can\?' app
```

New action added to a controller whose siblings are all gated? That is the highest-yield single check
in this list.
