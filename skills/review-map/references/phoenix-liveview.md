# Phoenix and LiveView lenses

What to look for, per layer, plus two sets of recipes for reaching past the diff: the **runtime
probes** that ask the application what its code amounts to, and the **search recipes** that find the
code the diff did not touch. This is the knowledge a senior reviewer applies from memory and that
cannot be inferred from a diff — it is what makes the page a review map rather than a change summary.

Where a lens turns on a Phoenix, LiveView or Ecto behaviour the reader might reasonably not know, the
canonical URL for it is in `references/elixir-docs.md`, and `report-format.md` § *Framework anchors*
says when a claim has earned a link. Do not construct one from memory. **Read that file's § *Version*
first**: while the catalogue is unverified it yields no links at all — and so no primer callouts
either, since a primer is what a link escalates into — and the anchor an Elixir run actually gets is
the probe.

Two app shapes are covered, and a repo is often both. A **LiveView app** has its sharpest seam between
a `.heex` template and the `handle_event/3` clause it names — no compiler crosses it, and § *LiveView*
below is mostly about that seam. A **Phoenix JSON API with a separate client** has the same seam every
JSON API has, and the client half of it is not written twice: see § *When the client is a separate JS
app* at the end. Everything is still discovered, never assumed.

**Apply these as lenses while reading, never as a checklist in the output.** The page reports what
was actually found, with `file:line`. It never says "we checked for N+1" as reassurance — an absent
finding is reported by absence, not by a green tick.

---

## Migrations

- Reversible? A `change` containing `execute/1` has no inverse, and Ecto raises on rollback rather
  than guessing. `execute/2` — up and down — or a separate `up`/`down` pair is the fix.
- Does it lock a table for a meaningful time — adding a column with a default on a large table
  (Postgres 11+ makes a constant default cheap, an expression default not), changing a column type,
  adding an index without `concurrently`?
- `create index(:table, [:col], concurrently: true)` requires `@disable_ddl_transaction true` in the
  same module. One without the other is either a migration that fails outright or one that quietly
  takes the lock it was written to avoid.
- `NOT NULL` added to a populated column, or a default backfilled into existing rows.
- A data backfill in the same migration as the schema change — usually wants separating, so a slow
  backfill does not hold the DDL transaction. `Repo` calls inside a migration also run against the
  migration's connection, which is not the pool the app uses.
- Destructive: dropping a column or table the running code still references. The safe order is
  deploy-then-drop, and a single migration cannot do both.
- `references(:table, on_delete: …)` — this is the **database's** foreign key action, and it is a
  different mechanism from `has_many … on_delete:` in the schema, which Ecto applies in Elixir.
  A migration and a schema can disagree about deletion and both look correct in isolation.

## Schema and structure

- Does the committed `structure.sql` match what the migrations produce? A mismatch means
  `ecto.migrate` and `ecto.load` disagree, and it is often a merge artifact.
- Foreign keys without a supporting index — `references/1` creates the constraint, never the index.
- Constraints enforced only in Elixir where the database could enforce them. `unique_constraint/3`
  in a changeset does **nothing** unless a unique index exists: it converts the database's error into
  a changeset error, it does not create the guarantee.
- Column types: money as float rather than `:decimal`; `:naive_datetime` where an instant was meant;
  `:utc_datetime` against `DateTime.utc_now/0`, whose microseconds do not fit and raise on insert
  unless truncated.
- `:map` / `:jsonb` columns with no embedded schema and no validation.

## Schemas and changesets

- **`cast/3`'s field list is the write allowlist**, and it is the strong-parameters question of this
  stack. A field added to the schema but not to `cast` is silently unwritable; a field added to `cast`
  is writable by any caller of that changeset, including a controller that passes params straight
  through.
- A field castable but never validated — `cast` without a matching `validate_required/2`,
  `validate_inclusion/3` or `validate_number/3` is a column that accepts whatever arrives.
- `unique_constraint/3` and `foreign_key_constraint/3` need the constraint to exist by name. A
  renamed index turns a friendly changeset error back into a raised `Ecto.ConstraintError`.
- `on_replace:` on an association or embed — `:raise` is the default, and adding
  `cast_assoc`/`cast_embed` without choosing one is a runtime error waiting for the first update.
- `prepare_changes/2` runs inside the transaction, `Repo.insert`'s return value does not tell you it
  ran, and a changeset built in one place and inserted in another can lose it.
- `Ecto.Enum` — is the legal transition set enforced anywhere, or can any caller write any member?
  Adding a member is a breaking change for every exhaustive `case` on it, on both sides.
- Multiple changeset functions on one schema (`changeset/2`, `admin_changeset/2`,
  `registration_changeset/2`): a new field added to one and not the others is the common defect, and
  which one a given write path uses is not visible from the schema.

## Contexts, `Repo` and `Multi`

- `Repo.update_all` / `insert_all` / `delete_all` bypass changesets entirely: no casting, no
  validation, no `unique_constraint` translation, no `autogenerate` timestamps. Sometimes correct,
  always worth naming — and if this change's invariant lives in a changeset, every one of these is a
  path where it does not hold.
- `Ecto.Multi` step order is the transaction's order, and a step that returns `{:error, _}` rolls the
  whole thing back and hands the failing step's name to the caller. A caller matching only
  `{:error, changeset}` will not match `{:error, :step_name, changeset, changes_so_far}`.
- `Repo.transaction/2` nesting: an inner transaction joins the outer one, so an inner
  `Repo.rollback/1` aborts everything. There is no `requires_new`; savepoints are opted into.
- Side effects inside a transaction — an HTTP call, a `Phoenix.PubSub.broadcast`, an email. The
  transaction holds locks while the network is slow, and a rollback cannot undo the call. A broadcast
  inside a transaction can reach a subscriber that then reads a row which is about to disappear.
- `Repo.preload/3` after the fact versus `preload:` in the query — one extra query per call site
  versus a join, and an N+1 usually arrives as a `preload` that moved out of the query.
- Unbounded queries: a context function with no `limit` that a new caller now runs over a large table.
- Context boundaries: is the web layer reaching past the context into `Repo` or a schema directly?
  That is where the invariant this PR adds stops being enforced.

## Controllers, plugs and JSON

- The router pipeline a `scope` inherits — a new scope that omits `pipe_through` inherits **nothing**,
  including the auth plug every sibling has. This is the API half of the highest-yield check below.
- Plug order in a pipeline: a plug that assigns something a later plug reads is order-dependent, and
  reordering is invisible in a diff of the plug itself.
- `action_fallback` — which errors it translates, and whether a newly returned error tuple has a
  clause. An unmatched fallback return is a 500 that reads as a bug in the controller.
- Params matched in the function head raise `FunctionClauseError` (500) when absent; params read from
  a map do not. Which of the two a new required param uses decides whether a missing one is a 400 or
  a 500.
- **`@derive {Jason.Encoder, only: [...]}` is the wire contract, and no compiler checks it.** A field
  added to the schema is not exposed; a field added to `only:` is. A renamed or removed key, a value
  that became conditionally absent, a struct that gained an association that is sometimes
  `%Ecto.Association.NotLoaded{}` — each is a breaking change for a client and none of them fails a
  build. The same applies to a hand-written `MyAppWeb.ThingJSON` render module.
- Status semantics: `409` for a conflict rather than `422`, and whether the code matches what
  `action_fallback` actually returns.
- Long-running or external work inside the request, and whether it belongs in a job.

## LiveView

The seam with no compiler behind it, which is why it gets the sharpest lenses here. A LiveView app
has no serializer and no generated type, but it has a contract just the same — between a template's
`phx-*` attributes and the callback clauses that answer them, and between what `render` reads and
what the socket actually holds.

- **`mount/3` runs twice**: once for the dead HTTP render, once again when the socket connects.
  Anything expensive, anything with a side effect, and anything that subscribes belongs behind
  `if connected?(socket)`. Work added to `mount` is work done twice, and a subscription made in the
  dead render is a subscription from a process that is about to exit.
- **An event with no matching `handle_event/3` clause crashes the LiveView process.** The user sees a
  reconnect and loses their form state; the server sees a `FunctionClauseError`. So renaming a
  `phx-click`, `phx-submit` or `phx-change` value in a `.heex` template without renaming its clause —
  or the reverse — is the defining piece of affected-but-unchanged code in this stack. No diff view
  shows the two together, and there is no compile-time link between them. **Search both directions**
  (§ *Search recipes*), and treat the template as part of the change even when the diff only touched
  the callback.
- **A `live` route outside the `live_session` that carries its `on_mount` hook is unauthenticated.**
  `on_mount {MyAppWeb.UserAuth, :ensure_authenticated}` is attached to a `live_session` block, so a
  new `live "/…"` added just past the closing `end` compiles, routes, renders, and checks nothing.
  This is the direct analogue of a new controller action added among gated siblings, and it is the
  **highest-yield single check in this list**. Read the router, not the diff hunk: the hunk shows the
  route, the file shows which block it landed in.
- **`stream/4` items are not in assigns.** After a move to streams, `@items` is empty and code that
  read it renders nothing; `stream_insert` and `stream_delete` are the only ways to change the list,
  and a full re-`assign` does not. Conversely `temporary_assigns` are reset to their default after
  the render that used them, so anything reading them in a later callback gets the default.
- **Form field names must match the changeset's `cast` list.** `to_form/2` names inputs from the
  changeset's data, and an input whose name is not cast is submitted and silently dropped. A
  `phx-change` handler that builds a changeset with `action: :validate` is what makes errors appear
  at all — without it a form validates only on submit.
- `push_patch` re-enters the same LiveView through `handle_params/3` (no remount, assigns kept);
  `push_navigate` mounts a different LiveView (assigns lost); `redirect` leaves LiveView entirely.
  Changing which one a flow uses changes what survives, and the diff of the call site does not say so.
- `live_action` comes from the router's third argument, and `handle_params/3` is where it is read. A
  new action added to the router with no clause for it in `handle_params` renders the default.
- `assign_new/3` exists so a parent's assign is not recomputed in the child; a plain `assign` in a
  `LiveComponent` overwrites what the parent passed on every update.
- `LiveComponent`: `update/2` runs per `send_update` and per parent render, `preload/1` batches across
  siblings, and state in a component is lost if its `id` changes. A component that gained an
  expensive `update/2` gained it once per parent render.
- `handle_info/2` clauses versus the payloads actually broadcast. A broadcast whose message shape
  changed meets a clause that no longer matches, and the process crashes — the PubSub version of the
  event-name problem above.
- `allow_upload/3` constraints (`max_entries`, `max_file_size`, `accept`) are the only validation an
  upload gets; `consume_uploaded_entries` is where the file becomes real.
- **`phx-hook` plus `pushEvent` is the one place a LiveView app still has a JS boundary**, and it
  fails exactly like a JSON contract: the hook pushes an event name and a payload, and a
  `handle_event` clause has to match both. A renamed hook, a changed payload key, or a hook attached
  to an element without an `id` all break at runtime only.

## Processes, jobs and PubSub

- `Task.async`/`Task.start` without a supervisor — work that dies with the request and is never
  retried, and a `Task.async` never awaited leaks a message into the caller's mailbox.
- A job enqueued in the same transaction as the row it operates on: with Oban that is correct
  (the insert is transactional), with anything that enqueues out-of-band the worker can start before
  the row exists.
- Oban worker `args` are serialized to JSON in the database. A changed argument shape meets
  **yesterday's queued payload**, and a worker whose `perform/1` pattern-matches the new shape crashes
  on every old job. Atoms become strings across that boundary.
- `unique:` on a worker, and whether retries are idempotent. If the job runs twice, what happens?
- Failure mode: `max_attempts` reached — does anything observe it, or does it land in `discarded` and
  stay there?
- PubSub topics constructed by string interpolation: the producer and the consumer have to agree, and
  nothing checks that they do. A changed topic silently delivers to nobody.
- `GenServer` state added or reshaped: what happens to a running process holding the old state during
  a deploy, and is there a `code_change`?

## Time, money and data types

- `DateTime.utc_now/0` into a `:utc_datetime` column raises on the microseconds —
  `DateTime.utc_now(:second)` or `truncate/2` is the fix, and which one the codebase uses is a
  convention worth matching.
- `NaiveDateTime` where a zone matters, or `Date` arithmetic across DST.
- Floats for money where the project uses `Decimal` or integer cents. `Decimal` comparison with `==`
  is a bug: `Decimal.equal?/2` and `Decimal.compare/2` exist because `1.0` and `1.00` are different
  terms.
- `String.to_atom/1` on user input — the atom table is not garbage collected.
  `String.to_existing_atom/1` is the safe form and it raises, which is usually what you want.

## Dependencies and configuration

- A new dependency for something the stdlib, Elixir, or an existing dep already does.
- `mix.exs` version constraints: why is it pinned, and what does the pin block?
- **`config/config.exs` is compile time; `config/runtime.exs` is boot time.** A secret or a URL read
  in the former is baked into the release and cannot be changed by the environment. This is the
  single most common configuration defect in a Phoenix deploy.
- New env vars: `System.get_env/1` returns `nil` and fails at first use;
  `System.fetch_env!/1` fails loudly at boot. Which one is chosen decides whether a missing variable
  is a 500 an hour later or a deploy that does not start.
- Secrets or credentials committed, or logged. `Logger` metadata and `inspect/2` on a struct holding
  a token both leak by default.

## Tests

- New behaviour with no test, or a test that asserts the mock rather than the behaviour.
- `async: true` on a case that touches a shared resource — a named process, an ETS table, the
  application env, or `Ecto.Adapters.SQL.Sandbox` in `:shared` mode. The failure is intermittent and
  lands on someone else's PR.
- Sandbox ownership: a spawned process (a `Task`, a LiveView, an Oban job run inline) needs
  `allow/3` or it cannot see the test's data.
- `Phoenix.LiveViewTest` — is there a test that actually fires the event
  (`render_click`, `render_submit`, `render_change`)? That is the only automated thing that catches a
  missing `handle_event` clause.
- `Mox` expectations without `verify_on_exit!` assert nothing.
- Error paths and authorization failures left uncovered — the most commonly missed cases.
- Time-dependent tests without freezing time; external calls not stubbed.
- Tests deleted or skipped as part of the change, which deserves an explicit note either way.

## When the client is a separate JS app

For a Phoenix JSON API with its own frontend, the client half of the contract is **not written twice**.
Three sections of `references/rails-nextjs.md` are about the client and the wire rather than about
Rails, and they apply here unchanged: § *The boundary: serializers to types*, § *Next.js*, and
§ *TypeScript and the client*. Read those for the client side and read `@derive {Jason.Encoder, …}` or
the `…JSON` render module as the backend end of the same chain.

The file's name is Rails-shaped and its client sections are not; restating them here would be a second
canonical home for the same material, which is the duplication `report-format.md` § *One canonical
home* exists to prevent. Renaming that file is a larger change than this one.

---

## Runtime probes

A search finds code. A probe asks the running application what that code amounts to — and for an Ecto
or LiveView change that is a different and better question, because the behaviour is assembled at
compile time from things the diff cannot show you together: the schema, its `@derive` attributes, the
changeset functions spread across a context, the router's `live_session` blocks, and whatever a macro
generated. `MyApp.Project.__schema__(:fields)` answers *what this struct actually has now*, including
the field a macro added. `Ecto.Adapters.SQL.to_sql/3` shows a query as the database will see it, with
every composed filter applied.

So for a change to a changeset, a query, an association, a schema field or a route, **reach for a probe
before reaching for a paragraph.** Where a probe would settle a claim the page is making, it belongs
in *how to validate*; where it makes a mechanism legible that the page has already established, it
belongs in *things to understand*. `references/report-format.md` § *Framework anchors* owns that
routing rule and the budget.

**These are proposed, never run.** This skill does not boot the application under review, which means
the page shows the command and never its output. A fabricated `{:ok, %Project{}}`, or an invented line
of SQL presented as what the probe printed, is the console form of an invented mix task: it reads as
the most concrete thing on the page and it is the one part of it that is fiction.

Three rules make a probe safe to paste, and they matter more than the list below:

- **Read-only reflection under `mix run -e '…'`; `iex -S mix` where a session is wanted.** Both boot
  the application, so both start the repo, the endpoint and every supervised process. Say which one a
  snippet needs.
- **There is no sandbox console.** Rails has `bin/rails console --sandbox`; Elixir has nothing
  equivalent, and this is the one rule that does not carry over. Anything that writes has to wrap
  itself: `MyApp.Repo.transaction(fn -> …; MyApp.Repo.rollback(:probe) end)` returns
  `{:error, :probe}` and leaves the database as it was. The page must say so explicitly, because a
  reviewer who pastes a bare `Repo.insert!` into `iex` has changed their database and the page told
  them to.
- **A rolled-back transaction never commits**, so nothing hanging off the commit happens: a broadcast
  or an Oban job inserted in the same `Multi` is rolled back with everything else, and a subscriber
  that would have reacted does not. When the behaviour under review *is* what happens after the
  commit, say that this probe cannot see it and name what would — a `Phoenix.LiveViewTest` case, or
  the worker's own test.
- **Prefer a probe that answers on an empty database.** `__schema__/1`, `to_sql/3`, a changeset built
  from a bare struct, and `mix phx.routes` all need no rows, so they work in a fresh checkout and
  expose no real data. A probe that needs seeded records is a validation step with a setup cost: it
  goes in section 6 beside the seed command, not inside a flow.

Never propose a snippet with `MIX_ENV=prod`, and never one whose output would print personal data.
Substitute the project's real module names throughout — a probe naming a context this repository does
not have is an invented command, and the rule against those is not softened by the fact that this one
looks like Elixir.

**The schema, as the database actually has it**

```sh
mix ecto.migrations | tail -5
mix run -e 'MyApp.Repo.query!("select indexname, indexdef from pg_indexes where tablename = $1", ["projects"]).rows |> IO.inspect(limit: :infinity)'
mix run -e 'IO.inspect MyApp.Project.__schema__(:type, :archived_at)'
mix run -e 'IO.inspect MyApp.Project.__schema__(:fields)'
```

The first says whether this checkout has run the migration at all, which is the usual explanation for
a reviewer seeing different behaviour from the author. The second is how a `unique_constraint` with no
unique index behind it becomes visible in one line — the constraint only translates an error the
database raises, so without the index it never fires.

**What the schema and its associations actually declare**

```sh
mix run -e 'IO.inspect MyApp.Project.__schema__(:associations)'
mix run -e 'IO.inspect MyApp.Project.__schema__(:association, :time_entries)'
mix run -e 'IO.inspect MyApp.Project.__schema__(:redact_fields)'
mix run -e 'IO.inspect MyApp.Project.__struct__() |> Map.keys()'
```

The second returns the full `%Ecto.Association.Has{}`, including the `on_delete` and `on_replace`
**actually in force** rather than the one written on the line you are reading — and it is the half
that Ecto applies in Elixir, which the database's own foreign key action does not know about.

**What a changeset casts, requires and rejects**

```sh
mix run -e 'cs = MyApp.Project.changeset(%MyApp.Project{}, %{}); IO.inspect({cs.errors, cs.required})'
mix run -e 'cs = MyApp.Project.changeset(%MyApp.Project{}, %{"name" => "x", "admin" => true}); IO.inspect(cs.changes)'
mix run -e 'IO.inspect MyApp.Project.changeset(%MyApp.Project{}, %{}).constraints'
```

The first names every validation now in force on an empty struct, including one added in a shared
helper nobody touched. The second is the `cast` allowlist demonstrated rather than described: a key
absent from `changes` was dropped. The third lists the constraint names the changeset expects the
database to have, which is exactly what a renamed index breaks.

**What a query compiles to**

```sh
mix run -e 'IO.inspect Ecto.Adapters.SQL.to_sql(:all, MyApp.Repo, MyApp.Projects.archived_query())'
mix run -e 'IO.puts elem(Ecto.Adapters.SQL.to_sql(:all, MyApp.Repo, MyApp.Project), 0)'
mix run -e 'IO.inspect MyApp.Repo.explain(:all, MyApp.Projects.archived_query())'
```

`explain` shows whether the index the migration added is the one the query plans to use. It is
read-only, though on a large table it is not instant.

**The wire shape, without touching a row**

```sh
mix run -e 'IO.puts Jason.encode!(%MyApp.Project{})'
mix run -e 'IO.inspect MyAppWeb.ProjectJSON.data(%MyApp.Project{})'
```

An empty struct is enough to see which keys cross the boundary and which are absent, which is the
backend half of the contract the client's type claims to match. A struct with an unloaded association
raises here, and that raise is itself the finding.

**Routing, LiveView and authorization**

```sh
mix phx.routes
mix phx.routes | grep -i project
mix run -e 'IO.inspect MyAppWeb.Router.__routes__() |> Enum.filter(& &1.plug == Phoenix.LiveView.Plug) |> Enum.map(&{&1.path, &1.metadata[:phoenix_live_view]})'
```

The third is the one that answers the highest-yield question in § *LiveView*: the `phoenix_live_view`
metadata carries the `live_session` name and its `on_mount` hooks, so a `live` route that landed
outside the authenticated block is visible as a route whose session differs from its siblings'. The
router file shows the same thing to a careful reader; this shows it to a reader in a hurry.

**Jobs**

```sh
mix run -e 'IO.inspect MyApp.Workers.ArchiveProject.new(%{project_id: 1}) |> Ecto.Changeset.apply_changes() |> Map.take([:queue, :args, :max_attempts])'
```

The `args` map is the payload shape a worker will deserialize — the thing that breaks when a job's
arguments change and yesterday's queue is still full. Building the job is pure; inserting it is not.

**Writes, and only inside a rollback**

```sh
iex -S mix
```

```elixir
MyApp.Repo.transaction(fn ->
  {:ok, p} = MyApp.Projects.create_project(%{name: "probe"})
  {:ok, p} = MyApp.Projects.archive_project(p)
  IO.inspect(Map.take(p, [:archived_at, :status]))
  MyApp.Repo.rollback(:probe)
end)
```

Everything is rolled back on exit, and nothing that depends on the commit ran — per the rule above.
When the behaviour under review *is* the post-commit effect, say that this probe cannot see it and
name what would.

## Search recipes for affected-but-unchanged code

Step 5 of the procedure lives or dies on these. Run the search, then **record it** — an empty result
is a finding only if the reader can see what was looked for.

Adjust paths to the project layout discovered in step 2; `rg` is assumed, `grep -rn` works the same.
`lib/<app>` is the domain, `lib/<app>_web` the web layer, and both matter.

**A changed context function**

```sh
rg -n '\bProjects\.archive_project\b' lib test          # callers and tests
rg -n 'Projects\.' lib/my_app_web                       # what the web layer reaches for
rg -n 'use MyApp\.|import MyApp\.Projects' lib          # importers, which hide the call site
```

**A changed or added schema field**

```sh
rg -n 'archived_at' lib test priv/repo                  # every reader and writer
rg -n 'archived_at' lib/my_app_web                      # does it cross into the web layer?
rg -n ':archived_at' lib/my_app/projects                # cast lists, queries, selects
rg -n 'select:|Repo\.pluck|Ecto\.Query\.select' lib     # explicit column lists that now miss it
```

A field added to a schema whose JSON encoding uses `@derive {Jason.Encoder, only: […]}` is **not**
exposed; one encoded from the whole struct is. That distinction decides whether the boundary material
applies at all.

**A changed changeset, validation or default**

```sh
rg -n 'update_all|insert_all|upsert_all|delete_all' lib
rg -n 'changeset\(' lib/my_app                          # every changeset function on this schema
rg -n '%MyApp\.Project\{' lib test                      # struct literals that skip the changeset
```

Bulk writes bypass changesets entirely. If the change relies on a validation, every hit in the first
search is a path where the new invariant does not hold.

**A changed LiveView event — search both directions**

```sh
rg -n 'handle_event\("archive"' lib                     # the clause
rg -n 'phx-click="archive"|phx-submit="archive"|phx-change="archive"' lib   # every template that fires it
rg -n 'pushEvent\("archive"' assets                     # and every JS hook that pushes it
```

This is the one search that must run in both directions, because either half can be the stale one.
A callback with no template and a template with no callback are different findings and neither shows
up in a diff of the other.

**A changed enum or status value**

```sh
rg -n ':archived|"archived"' lib test
rg -n 'Ecto\.Enum' lib/my_app                           # where the member list is declared
rg -n 'case .*status|when .*status' lib                 # every exhaustive match on it
```

**A changed JSON key or response shape**

```sh
rg -n 'Jason\.Encoder' lib/my_app                       # the derive lists
rg -n 'archivedAt|archived_at' assets --glob '*.ts' --glob '*.tsx' --glob '*.js'
rg -n '/api/projects' assets lib/my_app_web
```

Search the **old** name as well as the new one. The stale reader is the finding; the updated one is
already in the diff.

**A changed route**

```sh
rg -n '~p"/projects|Routes\.project' lib test           # verified routes and legacy helpers
rg -n 'live "/projects' lib/my_app_web/router.ex        # and which live_session block holds it
mix phx.routes | rg project                             # what the router actually exposes now
```

`~p` sigils are verified at compile time, so a broken one is a build error rather than a finding —
which makes the *unverified* constructions (a string built at runtime, a URL in JS, a link in an
email template) the ones worth searching for.

**A changed job or its arguments**

```sh
rg -n 'ArchiveProject' lib test
rg -n 'Oban\.insert|new\(%\{' lib | rg -i project
```

Also ask what happens to jobs **already queued** with the old argument shape when this deploys. A
worker pattern-matching today's shape against yesterday's payload is a failure no test covers.

**PubSub topics**

```sh
rg -n 'subscribe\(|broadcast\(' lib
rg -n 'handle_info\(' lib/my_app_web                    # the clauses that must match the payload
```

A producer and a consumer agreeing on a topic string is a contract nothing checks.

**Fixtures and factories**

```sh
rg -n 'def project_fixture|factory' test
```

A changed fixture default reaches every test in the suite, including ones nobody in this PR opened.

**Authorization**

```sh
rg -n 'live_session|on_mount' lib/my_app_web/router.ex
rg -n 'pipe_through' lib/my_app_web/router.ex
rg -n 'plug :require_|authorize|can\?' lib/my_app_web
```

A new `live` route outside the authenticated `live_session`, or a new `scope` with no `pipe_through`?
That is the highest-yield single check in this list.
