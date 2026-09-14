# Rails and Next.js lenses

What to look for, per layer, plus two sets of recipes for reaching past the diff: the **runtime
probes** that ask the application what its code amounts to, and the **search recipes** that find the
code the diff did not touch. This is the knowledge a senior reviewer applies from memory and that
cannot be inferred from a diff — it is what makes the page a review map rather than a change summary.

Where a lens turns on a Rails behaviour the reader might reasonably not know, the canonical URL for it
is in `references/rails-docs.md`, and `report-format.md` § *Framework anchors* says when a claim has
earned a link. Do not construct one from memory.

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
follows one field across it end to end — as an impact path when a hop lands in unchanged code, as
the chain inside the checkpoint that turns on it when it does not, and never as a section of
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
  different reach. Check whether the schema was updated alongside the serializer, and whether
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

## Runtime probes

A search finds code. A probe asks the running application what that code amounts to — and for an
ActiveRecord change that is a different and better question, because ActiveRecord's behaviour is
assembled at boot from things the diff cannot show you together: the class, its concerns, its
superclass, the schema, and whatever a `default_scope` quietly adds. `Project.validators_on(:slug)`
answers *what validates this now*, including the validation in a concern nobody touched.
`Project.archived.to_sql` shows the scope as the database will see it. `reflect_on_association`
shows the `dependent:` actually in force rather than the one written on the line you are reading.

So for a change to a scope, a validation, an association, a callback or a column, **reach for a probe
before reaching for a paragraph.** Where a probe would settle the judgment a checkpoint asks for, it
goes inside that checkpoint, after its explanation; where it would only make a mechanism legible, a
clause in the explanation does the job and the probe is not earned.
`references/report-format.md` § *Framework anchors* owns that routing rule and the budget.

**These are proposed, never run.** This skill does not boot the application under review, which means
the page shows the command and never its output. A fabricated `=> true`, or an invented line of SQL
presented as what the probe printed, is the console form of an invented rake task: it reads as the
most concrete thing on the page and it is the one part of it that is fiction.

Three rules make a probe safe to paste, and they matter more than the list below:

- **Read-only reflection under `bin/rails runner`; anything that writes under
  `bin/rails console --sandbox`**, which wraps the session in a transaction and rolls it back when
  you exit. Say which one a snippet needs — a reviewer who pastes a `create!` into a plain console
  has changed their database, and the page told them to.
- **`--sandbox` never commits, so `after_commit` never fires there.** That is usually the callback an
  archival or state-transition change turns on, so a sandbox session is the wrong instrument for it
  and the page should say so rather than let a reviewer conclude the callback is broken. Enqueued
  jobs, mailers and cache invalidation hanging off commit are all invisible for the same reason.
- **Prefer a probe that answers on an empty database.** `Model.new`, `.to_sql` and class-level
  reflection need no rows, so they work in a fresh checkout and expose no real data. A probe that
  needs seeded records is a validation step with a setup cost: it goes inside the checkpoint it
  settles, with the seed command beside it — there is no separate validations section to send it to —
  and a probe that answers on an empty database is the one to prefer.

Never propose a snippet with `RAILS_ENV=production`, and never one whose output would print personal
data. Substitute the project's real constants throughout — a probe naming a scope this repository does
not have is an invented command, and the rule against those is not softened by the fact that this one
looks like Ruby.

**The schema, as the database actually has it**

```sh
bin/rails db:migrate:status | tail -5
bin/rails runner 'pp ActiveRecord::Base.connection.indexes(:projects).map { |i| [i.name, i.columns, i.unique] }'
bin/rails runner 'c = ActiveRecord::Base.connection.columns_hash["projects"]["archived_at"]; pp [c.type, c.null, c.default]'
bin/rails runner 'pp ActiveRecord::Base.connection.foreign_keys(:time_entries).map { |k| [k.to_table, k.on_delete] }'
```

The first says whether this checkout has run the migration at all, which is the usual explanation for
a reviewer seeing different behaviour from the author. The second is how a uniqueness validation with
no unique index behind it becomes visible in one line. The fourth separates what the database enforces
from what `dependent:` does in Ruby.

**What the model actually declares, after concerns and inheritance**

```sh
bin/rails runner 'pp Project.validators_on(:slug).map { |v| [v.class, v.options] }'
bin/rails runner 'pp Project.reflect_on_association(:time_entries).options'
bin/rails runner 'pp Project.reflect_on_all_associations.map { |a| [a.macro, a.name, a.options[:dependent]] }'
bin/rails runner 'pp Project.defined_enums'
bin/rails runner 'pp Project._commit_callbacks.map(&:filter)'
```

Each of these is the answer to a question the diff makes a reviewer ask and cannot settle: which
validations exist now, what `dependent:` is really set to across every association, which enum values
the app admits, what runs on commit. The last reads a private-ish API and can change between Rails
versions — offer it as an aid, not as authority.

**What a scope compiles to**

```sh
bin/rails runner 'puts Project.archived.to_sql'
bin/rails runner 'puts Project.all.to_sql'
bin/rails runner 'puts Project.archived.explain'
```

The second is how a `default_scope` reveals itself: if `Project.all` carries a `WHERE`, every query in
the change inherits it. `explain` shows whether the index the migration added is the one the query
plans to use, and it is read-only, though on a large table it is not instant.

**The wire shape, without touching a row**

```sh
bin/rails runner 'puts JSON.pretty_generate(ProjectSerializer.new(Project.new).as_json)'
bin/rails runner 'pp Project.new.as_json.keys'
```

An unsaved record is enough to see which keys cross the boundary and which are absent, which is the
backend half of the contract the client's type claims to match. Substitute the project's real
serializer; if serialization needs a persisted record, this becomes a sandbox probe.

**Routing and authorization**

```sh
bin/rails routes -g projects
bin/rails routes -c projects
bin/rails runner 'pp Rails.application.routes.recognize_path("/api/projects/1", method: :patch)'
bin/rails runner 'pp ProjectPolicy.instance_methods(false)'
```

`recognize_path` answers which controller action a URL the client constructs actually reaches, which
is the one question a route diff leaves open. The last names the policy methods that exist, so an
action gated by one that does not is visible.

**Jobs**

```sh
bin/rails runner 'pp [ArchiveProjectJob.queue_name, ArchiveProjectJob.new.serialize.keys]'
```

The serialized keys are the payload shape a worker will deserialize — the thing that breaks when a
job's arguments change and yesterday's queue is still full. A job whose arguments include a record
needs a persisted one, so that variant is a sandbox probe.

**Writes, and only in the sandbox**

```sh
bin/rails console --sandbox
```

```ruby
p = Project.create!(name: "probe")
p.archive!
p.reload.attributes.slice("archived_at", "status")
```

Everything is rolled back on exit — and `after_commit` did not run, per the rule above. When the
behaviour under review *is* the commit hook, say that this probe cannot see it and name what would:
a request spec, or the job's own test.

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
