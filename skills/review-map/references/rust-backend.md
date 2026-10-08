# Rust backend lenses

The second layer for a Rust crate that serves requests — an HTTP API on `axum`, `actix-web`, `rocket`,
`warp` or `poem`, a gRPC service on `tonic`, with a database behind it through `sqlx`, `diesel` or
`sea-orm`. **Read `references/rust.md` first; this file is what that one does not cover.** Ownership,
`unsafe`, features, panics, serde attributes, async cancellation and the public-API lens are there and
are not restated here — a backend is a crate, and a second copy of those sections would be the
duplication `report-format.md` § *One canonical home* exists to prevent. What this file adds is the
part a server has and a library does not: routes, middleware, a wire contract, a schema, and a request
whose lifetime ends when the client hangs up.

Where a lens turns on a framework behaviour the reader might reasonably not know, the canonical URL for
it is in `references/rust-docs.md`, and `report-format.md` § *Framework anchors* says when a claim has
earned a link. Do not construct one from memory. **Read that file's § *Version* first**: while the
catalogue is unverified it yields no links at all, and the anchor a Rust run actually gets is the
probe.

**Two seams carry most of the findings, and neither has a compiler across it.** The first is the
**wire**: a struct's serde attributes on one side and whatever reads the JSON on the other — a
separate client, another service, a stored payload. The second is the **schema**: a migration on one
side and every query that assumed the old one on the other, which in this stack is sharpest where the
queries are *compile-time checked*, because a check run against stale data passes. Everything is still
discovered, never assumed: which framework, which database layer, whether there is a client at all.

**Apply these as lenses while reading, never as a checklist in the output.** The page reports what
was actually found, with `file:line`. It never says "we checked every route for auth" as reassurance —
an absent finding is reported by absence, not by a green tick.

---

## Migrations

- **Reversible?** A `sqlx` migration is reversible only if it was created as an `.up.sql` and
  `.down.sql` pair; a single `.sql` file has no down. In `diesel`, `down.sql` exists by construction
  and is easy to leave as a stub. Whether rollback matters is the team's call; whether this one has
  one is a fact.
- **An already-applied migration edited in place.** `sqlx` stores a checksum of every migration it has
  run and refuses to continue when a file it already applied has changed; `diesel` runs it again
  nowhere and the environments that applied the old version silently differ from the ones that apply
  the new. Either way, a diff that modifies an existing migration rather than adding one is worth a
  sentence.
- Does it lock a table for a meaningful time — a column with a non-constant default on a large table,
  a type change, an index built without `CONCURRENTLY` on Postgres? And if it is built concurrently:
  a concurrent index cannot be built inside a transaction, so check how this project's runner wraps a
  migration and how this one opts out.
- Is the migration safe to run **before** the new code deploys, while the old code is still serving?
  Dropping or renaming a column the running binary still selects is the classic outage, and a Rust
  binary selecting by column name fails at the first query rather than at boot.
- Backfills: batched, idempotent, and kept out of the schema migration if the table is large.
- Migrations embedded in the binary (`sqlx::migrate!()`, `diesel_migrations::embed_migrations!()`)
  run at startup, so a slow one is a slow deploy and a failing one is a crash loop.

## The schema and the queries that assume it

- **Compile-time checked queries are checked against something, and it may be stale.** `sqlx::query!`
  and `query_as!` are verified at build time against a live database or, offline, against the
  per-query JSON under `.sqlx/` that `cargo sqlx prepare` wrote. A migration that changes a column's
  type or nullability, with a `.sqlx/` that was not regenerated, leaves every **unchanged** query on
  that column compiling against the old schema. That is this stack's sharpest piece of
  affected-but-unchanged code: the diff shows a migration, the build is green, and the code that will
  fail at runtime is a query nobody touched. Check whether `.sqlx/` moved in the same diff, and whether
  CI builds with `SQLX_OFFLINE`.
- **`sqlx::query(...)` without the `!` is a string**, checked by nothing until it runs. A renamed
  column reaches it only through a search.
- **`diesel`'s `schema.rs` is generated**, and a migration without a regenerated `schema.rs` is a
  compile error — or, if someone edited `schema.rs` by hand to match, a schema file that agrees with
  the code and not with the database.
- **`#[derive(Queryable)]` maps columns by position, not by name.** Reordering a struct's fields, or
  adding a column in the middle of a `select`, swaps values between same-typed fields with no error.
  `#[derive(Selectable)]` with `as_select()` maps by name; which one each changed model uses decides
  whether a field reorder is cosmetic.
- Nullability: a column made nullable in a migration has to become `Option<T>` in Rust; a query
  reading it into a `T` fails at runtime on the first `NULL`, which no test with seeded data produces.
- Indexes and constraints the code relies on: a uniqueness the code assumes and the database does not
  enforce holds until two requests race. An `ON CONFLICT` clause names the constraint it expects to
  exist.
- `sea-orm` entities are generated from the schema or written by hand; which one this project does
  decides whether a migration without an entity change is an omission.

## Transactions and writes

- **A transaction dropped without `commit()` rolls back.** That makes `?` inside one safe, and it makes
  a transaction passed down a call chain and committed by nobody a silent no-op.
- **Side effects inside a transaction are not rolled back with it.** An HTTP call, a message published,
  an email sent or a job enqueued to an external queue before `commit()` has happened even when the
  transaction then fails. The order of the commit and the side effect is the judgment.
- **Several writes outside a transaction**, in a handler — combined with cancellation (below), this is
  how a request that the client abandoned leaves half its writes behind.
- Holding a pooled connection or a transaction across a slow `.await` — an outbound HTTP call, a lock —
  takes it from every other request for that long; under load it is pool exhaustion.

## Routes, extractors and middleware

- **Middleware order is the reverse of how it reads, in two of the three idioms.** `axum`'s
  `Router::layer` and `actix-web`'s `App::wrap` each wrap everything registered so far, so the layer
  added *last* runs *first* on the request. `tower::ServiceBuilder` reads the other way: the first
  layer added is the outermost. A diff that adds a layer in the right order for one idiom inside the
  other is the bug, and the line reads correctly either way.
- **In `axum`, `Router::layer` covers only the routes added before it.** A route added after the auth
  layer in the builder chain is not behind it. `route_layer` applies to matched routes only, which
  changes an unauthenticated request to an unknown path from a 401 to a 404. A nested or merged router
  carries its own layers and not its parent's later ones. **This is the highest-yield single check in
  an `axum` app** — the Rust form of the Phoenix scope that forgot its `pipe_through`.
- **Authentication as an extractor is per handler.** Where the app guards routes with an extractor —
  an `AuthUser` or `Claims` argument in the handler's signature — a new handler without it compiles
  and is public. Where it guards with a layer, see above. An app may do both; which one a sibling
  handler uses is the `Y` to cite.
- **Shared state that is checked, and shared state that is not.** `axum`'s `State<T>` is checked at
  compile time against the router's state type. `Extension<T>` and `actix-web`'s `web::Data<T>` are
  not: a handler extracting one that was never added to the app compiles, and fails every request at
  runtime with a 500.
- **The extractor's rejection is part of the contract.** A request body extractor rejects malformed
  input with a status the client sees — in `axum`, `Json` distinguishes a missing content type, a
  syntax error and a body that does not match the type, with different codes. A field made required in
  the request struct turns yesterday's valid request into today's rejection, and the handler body
  never runs to log it.
- **Path parameters**: the route's parameter count and the `Path<…>` type have to agree, and the route
  syntax itself moved between `axum` versions — which form this app's routes use is a fact of its
  lock file, not something to assert.
- **Error to status.** A handler returning `Result<T, AppError>` with an `IntoResponse` (or
  `ResponseError`) impl maps each error variant to a status. A new variant, a new `From` conversion
  into the error type, or a `?` that now routes a lower-level error into the catch-all arm changes the
  status a client sees — usually to a 500 — without the handler changing. Read the impl, not only the
  handler.
- Long-running or external work inside the request, and whether it belongs in a task or a queue.
- Request size limits and timeouts set as layers: a new endpoint that accepts uploads under a global
  body limit set for JSON.

## The wire contract

- **The serde attributes on a response type are the API**, and `references/rust.md`
  § *Serialization and persisted formats* says how each one changes the bytes. What a backend adds is
  who is reading them: a separate client, a mobile app pinned to last month's release, another
  service. A renamed field, a `rename_all` added to a type that had none, an `Option` that is now
  skipped instead of `null`, an enum that became `#[serde(tag = "…")]` — each is a breaking change for
  every consumer and none fails a build.
- **The same struct for the request and the response** couples them: a field added for one is
  accepted or exposed by the other. A response type that derives `Serialize` from a database model
  exposes every column the model gains — including the next one that should not be public.
- **Request types**: `#[serde(default)]` decides whether an old client that omits a new field still
  works; `deny_unknown_fields` decides whether a new client sending a field this server does not know
  yet is rejected.
- Status semantics: `409` for a conflict rather than `422`, `404` for something the caller may not
  see rather than `403`, and whether the code matches what the error mapping actually returns.
- **gRPC**: in a `.proto` file the **field number** is the contract and the name is not. Renumbering a
  field, reusing a removed field's number, or changing a field's type breaks every client on the old
  definition; renaming a field breaks only JSON transcoding. The Rust code is generated from it by
  `build.rs` into `OUT_DIR` and is not in the diff — the `.proto` is the whole visible change.

## Async and the request lifecycle

- **A request handler is a future, and it is dropped when the client goes away.** Whether the server
  cancels a disconnected request's handler depends on the framework and its configuration, and where
  it does, any code after the next `.await` does not run. Two writes in a handler with an `.await`
  between them and no transaction is one write for every client that timed out. `references/rust.md`
  § *Concurrency and async* has the general rule; this is where it costs data.
- **`tokio::spawn` from a handler** detaches the work from the request: it survives the disconnect,
  but nothing awaits it, its error is dropped, and a graceful shutdown that does not track it kills it
  half done.
- Blocking calls in a handler — synchronous database drivers, `std::fs`, password hashing, image
  processing — stall every request on that worker. `spawn_blocking` is the usual answer; whether the
  call is actually slow is the judgment.
- Shared caches behind `Arc<Mutex<…>>` or `Arc<RwLock<…>>` in application state: contention under
  load, and a guard held across an `.await`.

## Background work and messaging

- **A job's payload is persisted in the shape it had when it was enqueued.** Whatever the queue — a
  table polled by the app, `apalis`, a broker — a deployed change to the payload struct meets the
  payloads already queued, and serde decides whether that is an error, a default or a silently
  dropped field. Ask what happens to the jobs in flight when this deploys.
- Retries: an operation retried after a partial success has to be idempotent, and a new side effect
  inside a retried job usually is not.
- Message topics, queue names and event type strings are contracts between producers and consumers
  that no compiler sees, exactly like a serialized field name.
- Fire-and-forget work spawned at startup — a cache warmer, a poller — lives as long as the runtime
  and is lost on shutdown unless something tracks it.

## Configuration and startup

- **A new required setting fails every environment that does not have it.** Configuration read at
  startup — `std::env::var`, `envy`, the `config` crate, `figment`, `clap`'s `env` attribute — that is
  newly required without a default is a crash on boot in every deployment not updated alongside the
  code. Whether that is the intent (fail fast) or an omission is the judgment.
- Settings read lazily, inside a handler, fail on first use instead — later and less visibly.
- Secrets in configuration types that derive `Debug`: a startup log line that prints the config prints
  them. `references/rust.md` § *Types, traits and generics* has the general form.
- `tracing::instrument` records every argument with its `Debug` impl unless told to `skip` it, so a
  handler instrumented with a password, a token or a full request body logs it.

## Coding decisions, against this codebase's own answers

`references/rust.md` § *Coding decisions* owns the rule, the register and the closed list of stack
conventions — one per departure, *is it deliberate that X, given Y?* What a backend adds is shapes to
look for:

- **A handler that reaches past the layer its siblings go through** — straight to the pool or the
  query builder where every other handler calls a service or repository function.
- **A second error-to-response mapping** — a handler building its own status code and body where the
  app has one `IntoResponse` impl for its error type.
- **A second authentication mechanism** — an extractor on one handler in an app that guards with a
  layer, or the reverse.
- **Raw `sqlx::query` in an app that otherwise uses `query!`**, or SQL strings in a `diesel` app: the
  change opts out of the compile-time check its siblings have.
- **A response type that is the database model** in an app whose other endpoints have separate DTOs.

```sh
rg -n 'async fn \w+\(' -g '*.rs' <the handlers directory>     # what sibling handlers take, and so what they go through
rg -n 'impl +IntoResponse +for|impl +ResponseError +for' -g '*.rs'
rg -n 'sqlx::query\(|sqlx::query_as\(' -g '*.rs'              # unchecked queries, against the checked ones
```

## Tests

- **`#[sqlx::test]` gives each test its own database**, with migrations applied, and drops it after.
  A test that passes there may depend on data a migration seeds; a test written without it may share a
  database with its neighbours and pass only in order.
- **A router tested without a server** — `tower::ServiceExt::oneshot` on the `Router`, or the
  framework's own test helpers — is the only automated thing that catches a route outside its auth
  layer or a missing `Extension`. Is there one that sends the request this change affects?
- **Tests that build their own router** rather than the application's: they pass with a layer stack
  that is not the one deployed.
- Tests against a real database through `testcontainers` or a CI service: what CI provides decides
  whether they run at all, and an `#[ignore]` on them is common.
- Error paths and authorization failures left uncovered — the most commonly missed cases.
- Everything in `references/rust.md` § *Tests* applies too: doc tests and nextest, snapshots, features.

## When the client is a separate app

For a Rust API with its own frontend, the client half of the contract is **not written twice**. Three
sections of `references/rails-nextjs.md` are about the client and the wire rather than about Rails, and
they apply here unchanged: § *The boundary: serializers to types*, § *Next.js*, and § *TypeScript and
the client*. Read those for the client side, and read the response type's serde attributes as the
backend end of the same chain.

One question is Rust-specific and decides how much of that applies: **are the client's types
generated from the Rust ones?** `ts-rs`, `specta`, `typeshare`, or an OpenAPI document produced by
`utoipa` or `aide` and fed to a client generator each make the boundary drift loudly at build time,
*if* the generation step runs in CI and the output is committed or checked. Where the client's types
are hand-written, the boundary drifts silently, which is the case worth hunting.

---

## Runtime probes

`references/rust.md` § *Runtime probes* owns the four rules — `--locked` on every Cargo command, say
when a command compiles, name a tool that is not part of Cargo, and no console — and they apply here
unchanged. A backend adds the one thing a library does not have: a database, and so probes that answer
only where one is reachable. **Those fail the fresh-checkout earning test** unless the reviewer has a
migrated local database, so prefer the ones that need none and say which ones do.

Never propose a probe against a production `DATABASE_URL`, never one that prints rows of real data,
and never one that writes. A write that has to be observed is a test — `#[sqlx::test]` gives it a
throwaway database — not a command.

**Whether the checked queries were checked against this schema**

```sh
cargo sqlx prepare --check                                    # separate install; needs DATABASE_URL on a migrated database
git diff --stat <base sha> -- .sqlx                           # did the offline query data move with the migration?
```

The first regenerates the offline query data in memory and fails if it differs from what is
committed, which is the stale-`.sqlx/` case from § *The schema and the queries that assume it* made
visible in one line. The second needs nothing and answers half of it.

**Which migrations this checkout has run**

```sh
cargo sqlx migrate info                                       # separate install; needs DATABASE_URL
diesel migration list                                         # separate install; needs DATABASE_URL
```

The usual explanation for a reviewer seeing different behaviour from the author.

**The schema, as diesel derives it**

```sh
diesel print-schema                                           # separate install; reads the database, writes only to stdout
```

Set beside the committed `schema.rs`, this shows whether the two agree.

**Which tests exercise a route, without running them**

```sh
cargo test --locked -p api -- --list | rg -i project          # compiles the test binaries; lists, runs nothing
```

**The dependency and feature graph** — `cargo tree --locked -e features -i sqlx` shows which database
drivers and runtime features are compiled in, which decides whether a query that works locally on
SQLite says anything about Postgres. `references/rust.md` has the rest of that family.

## Search recipes for affected-but-unchanged code

Step 5 of the procedure lives or dies on these, and `references/rust.md` § *Search recipes* has the
language-level ones — callers, implementors, enum arms, serde names, features. Run those too. Run each
search, then **record it** — an empty result is a finding only if the reader can see what was looked
for.

**A changed route or handler**

```sh
rg -n '"/projects' -g '*.rs'                                  # every route registration and every URL built in Rust
rg -n '\barchive_project\b' -g '*.rs'                         # where the handler is mounted, and its tests
rg -n '/projects' -g '!target' -g '!*.rs'                     # clients, fixtures and docs that construct the URL
```

**A changed or added layer, guard or extractor**

```sh
rg -n '\.layer\(|\.route_layer\(|\.wrap\(|ServiceBuilder' -g '*.rs'
rg -n '\.route\(|\.nest\(|\.merge\(|\.service\(' -g '*.rs'   # what is registered before and after it
rg -n 'AuthUser|Claims|RequireAuth' -g '*.rs'                # handlers carrying the auth extractor, against those that do not
```

Read the two lists together: the first says where the layer sits in the builder chain, the second
which routes come before it. A route registered after the auth layer, or a handler without the
extractor its siblings carry, is the finding. Substitute this app's own extractor names — the ones
above are placeholders, and a search for a name the app does not use returns nothing and proves
nothing.

**Application state**

```sh
rg -n 'Extension<|web::Data<|\.app_data\(|\.data\(|Extension\(' -g '*.rs'   # every unchecked lookup, against every insertion
```

**A changed column or table**

```sh
rg -n '\barchived_at\b' -g '*.rs' -g '*.sql'                  # queries, models and migrations
rg -l 'archived_at' .sqlx 2>/dev/null                         # the offline query data that names it
rg -n 'query(_as|_scalar)?!\(' -g '*.rs' <files that name the table>   # checked queries on the table
rg -n 'sqlx::query(_as|_scalar)?\(' -g '*.rs'                 # unchecked ones, which a rename reaches silently
rg -n 'table! *\{|#\[diesel\(table_name' -g '*.rs'            # diesel's schema and the models mapped onto it
```

This is the search a `figure.converge` is earned by when the change relies on an invariant every
writer has to keep — each query that writes the table is one of its paths, and the raw one that skips
the check is the unchanged path it exists to show. `report-format.md` § *Topology figures* owns the
rest; a status column with guarded transitions is its `figure.lifecycle`, a new table and its foreign
keys its `figure.structure`.

**A changed error variant or error mapping**

```sh
rg -n 'AppError::' -g '*.rs'                                  # every construction, and every arm of the mapping
rg -n 'impl +From<[^>]+> +for +AppError' -g '*.rs'            # every error a ? converts into it
```

**A changed request or response type**

```sh
rg -n '\bProjectResponse\b' -g '*.rs'                         # every handler returning it
rg -n 'archivedAt|archived_at' -g '*.ts' -g '*.tsx' -g '*.js' # the client's reading of the serialized name
rg -n 'ts\(export|derive\([^)]*(TS|Type|ToSchema)' -g '*.rs'  # whether the client types are generated from it
```

Search the **old** name as well as the new one. The stale reader is the finding; the updated one is
already in the diff.

**A changed `.proto`**

```sh
rg -n '= *[0-9]+;' <the .proto file>                          # the field numbers, which are the contract
rg -n 'reserved' <the .proto file>                            # numbers retired so they cannot be reused
rg -n 'tonic::include_proto!|include!\(concat!\(env!\("OUT_DIR"' -g '*.rs'
```

**A changed job, message or event**

```sh
rg -n 'ArchiveProjectJob|"archive_project"' -g '*.rs'         # every producer and every consumer
rg -n 'topic|queue|subject' -g '*.rs' | rg -i project         # names both sides have to agree on
```

Also ask what happens to messages **already queued** with the old shape when this deploys. A consumer
deserializing today's struct from yesterday's payload is a failure no test covers.

**Configuration**

```sh
rg -n 'env::var\("|#\[serde\(rename *= *"[A-Z_]+"|env *= *"' -g '*.rs'
rg -n 'DATABASE_URL|APP_[A-Z_]+' -g '!target' -g '!*.rs'     # where deployments set them: compose files, manifests, .env examples
```

A new required variable that appears in the code and in none of the deployment files is the finding.
