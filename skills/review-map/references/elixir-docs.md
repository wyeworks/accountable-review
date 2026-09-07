# Elixir, Phoenix and LiveView documentation catalogue

The URLs the page is allowed to cite for an Elixir application. **A doc link that is not in this file
does not go on the page** — not a guessed anchor, not an "obvious" module path, not a URL you are
fairly sure of. The run cannot check a URL: there is no fetch step in the procedure, and the sandboxes
this skill commonly runs in block egress to these hosts outright. So a link is either something a
human opened once and wrote down here, or it is a 404 the reader discovers on your behalf — and one
dead link costs the same trust as one invented mix task.

`references/report-format.md` § *Framework anchors* owns what a doc link is *for*, when a claim earns
one, and the budget. This file is only the lookup: concept in, URL out.

**Read § *Version* before using this file.** It is not yet verified, and until it is, the answer this
file returns for every concept is *no link*.

## Version

**Not yet verified. No row in this file has been opened.**

Until a dated verification line appears in this section, **emit no link from this catalogue.** Explain
the mechanism in prose, cite the repo line, and propose a probe from
`references/phoenix-liveview.md` § *Runtime probes*.

**That also costs the primer callout, which is easy to miss.** An `aside.primer` is what a doc link
escalates into, so it cannot exist without one — `report-format.md` § *The primer callout* and
`evals/checks/rails-anchors.rb` both say so. While this file is closed, a Phoenix page therefore
carries **no primer at all**, not merely no inline links. When it opens, an Elixir primer is a
`.primer--lib`: the branded variant's mark names whoever wrote the API, and that is not the Rails
Foundation.

This is the fail-closed rule of `rails-docs.md` § *Pinning* applied to a whole file rather than to a
single row, and for the same reason. An unlinked explanation is never misleading; a link nobody opened
is. The Rails catalogue's first sweep found that its worst defect was not rot but
`active_record_nested_attributes.html` — *"a plausible URL constructed once and then admitted to the
allowlist"*, a page that has never existed in any series, and the one class of defect no script
catches and no amount of care while writing prevents. Every row below was written the same way that
one was. So they are held closed until a machine with egress has opened them.

What lifts it:

```sh
evals/verify-catalogue.sh --catalogue references/elixir-docs.md
```

A clean run prints a dated line; that line replaces this section's first paragraph, and the links go
live in the same commit. A run with failures is the more likely outcome and is the point of running it.

**The probe is unaffected, and it is the better anchor anyway.** A probe interrogates the installed
code instead of describing it, so it cannot be out of date and it cannot 404. `rails-docs.md`
§ *Pinning* already argues this — *"The probe is the version-proof anchor"* — and while this catalogue
is closed it is the whole of what an Elixir run offers. That is a narrower page, not a broken one.

**The floor these rows are written against**, and below which no link is emitted even once the file
opens: `elixir` 1.14, `phoenix` 1.7, `phoenix_live_view` 0.20, `ecto` / `ecto_sql` 3.10, `oban` 2.15.
Below any of those, explain in prose and propose a probe.

## Shapes

One host, and only this host:

```
hexdocs.pm/<package>/<version>/<Module>.html[#<anchor>]
hexdocs.pm/<package>/<version>/<guide-page>.html[#<section>]
```

These are the **paths this file stores**, and no row below carries a version segment — § *Pinning* has
the emitted form. A stored path always begins with the package name, because on hexdocs the package is
part of the path and each one pins separately.

The anchor dialect is `#name/arity`:

| Anchor | Means | Example |
|---|---|---|
| `#cast/4` | a public function | `Ecto.Changeset.cast/4` |
| `#c:mount/3` | a **callback** | `Phoenix.LiveView.mount/3` |
| `#t:t/0` | a type | |
| `#module-<slug>` | a section of the module doc | |

**The trap is the callback prefix.** Everything a LiveView or a `Repo` implements — `mount/3`,
`handle_event/3`, `handle_params/3`, `update_all/3`, `transaction/2` — is documented as a *callback*
and takes `#c:`. Everything a caller invokes — `cast/4`, `assign_new/3`, `stream/4` — does not.
Getting that wrong is harmless; getting the module path wrong is not, for the reason below.

**A bad anchor is survivable and a bad path is not.** A fragment a page does not have is ignored by
every browser — `…/Ecto.Changeset.html#nope` still lands the reader on `Ecto.Changeset`. A wrong
module or a wrong package is a 404. That asymmetry is why this file prefers a **page-level URL it is
certain of** to a deeper link it is not, and why several rows below are page-level on purpose.

**The package is part of the path and is easy to get wrong across a family.** `Ecto.Changeset` is in
`ecto`; `Ecto.Migration` and `Ecto.Adapters.SQL` are in `ecto_sql`. `Logger` is in `logger`, not in
`elixir`. `Phoenix.Component` and `Phoenix.LiveViewTest` are in `phoenix_live_view`, not in `phoenix`.
A path that is right about the module and wrong about the package is a 404 that reads as correct.

**Never a `github.com/.../blob|pull|compare/` URL**, here as anywhere: `evals/checks/page-invariants.rb`
§ 5 fails a page that emits one when the head commit is unpushed, because those are the shapes a dead
permalink takes. This catalogue offers only hexdocs, so the question does not arise from these rows —
it arises when a run reaches past them.

## Pinning

**Every URL in this file is a path, not a link. The run pins it to the app's own version before it
reaches the page.**

```
https://hexdocs.pm/<package>/<version>/<rest of the stored path>
```

`<version>` is that package's **exact locked version**, read from `mix.lock` in step 2 — `phoenix` at
`1.7.20` gives `https://hexdocs.pm/phoenix/1.7.20/routing.html`. For the `elixir` package it is the
Elixir version the project targets (`.tool-versions`, `mix.exs`'s `elixir:` requirement, or
`System.version/0`).

**"One app, one series" has no Elixir analogue, and this is the one pinning rule that does not carry
over from Rails.** Rails has a single `major.minor` for the whole framework, so a page mixing `/v7.1/`
and `/v8.0/` has pinned from something other than the lock file. An Elixir app pins `ecto`, `phoenix`,
`phoenix_live_view`, `oban` and `elixir` itself independently, so **a correct Elixir page carries
several different version segments** — one per package — and that is not a defect.
`evals/checks/rails-anchors.rb` encodes the distinction: it requires every hexdocs link to carry a
version segment, and it does not require them to agree.

**hexdocs serves exact versions, not a series prefix.** There is no `major.minor` shortcut that
resolves to the newest patch the way `guides.rubyonrails.org/v8.0/` does, so the patch number is never
optional and never guessed — it comes from the lock file or the link is not emitted.

**This is unconditional.** Not only for rows whose behaviour moved — every row. A pinned hexdocs page
prints its version in its header and in its version picker, so the reader can hold the link against
their own `mix.lock` at a glance. That is the whole difference between a link they have to trust and
one they can verify.

**Above the floor but past what a verification run covered, pin anyway**, for the reason
`rails-docs.md` § *Pinning* gives: the path shapes are structurally stable and the page self-identifies,
so a mismatch that survives is visible to the reader. **Below the floor in § *Version*, or where a row
has no path for that package at all, emit no link.**

## What the marks mean

Two marks, and both are about the **sentence**, never the link — pinning takes the link's version
problem away entirely. They say what the page is allowed to claim. Identical in meaning to
`rails-docs.md` § *What the marks mean*, so that file's reasoning for keeping them distinct applies
here unchanged.

| Mark | Means | The run must |
|---|---|---|
| *(none)* | The behaviour has not changed across the supported range | State it, link it, move on |
| `‡ probe` | The behaviour **changed** inside the range, so no single sentence is true of every app | Not assert it. Ask the app: propose a probe, and name the setting or version that decides it |
| `‡ since X` | Surface was added in X; the default this row describes still holds | State it *as the default*, and name X where a reader could meet the new surface |

**The marks below were reasoned from knowledge of the libraries, not from a CHANGELOG audit.** The
Rails file's marks came from reading the Active Record, Active Job, Action Pack and Active Support
CHANGELOGs across three series, and that audit found the previous single mark was catching about a
quarter of what it existed to catch. No equivalent audit has been done for Ecto, Phoenix, LiveView or
Oban. So these marks are a first pass and are owed the same treatment — most sharply across the
LiveView `0.20 → 1.x` range, which moved more surface than any other library here. Until then, prefer
the probe wherever a sentence would have to be version-specific: it is the anchor that cannot be
wrong about a version.

---

## Changesets and validation · `ecto`

| Concept the reviewer meets | Path |
|---|---|
| `cast/3,4`'s field list is the write allowlist — a field not cast is silently dropped | `ecto/Ecto.Changeset.html#cast/4` |
| `validate_required/3`, and what counts as present | `ecto/Ecto.Changeset.html#validate_required/3` |
| `unique_constraint/3` translates a database error; it does not create the guarantee | `ecto/Ecto.Changeset.html#unique_constraint/3` |
| `foreign_key_constraint/3`, and the constraint name it expects to exist | `ecto/Ecto.Changeset.html#foreign_key_constraint/3` |
| `cast_assoc/3` and `on_replace:` — `:raise` is the default | `ecto/Ecto.Changeset.html#cast_assoc/3` |
| `cast_embed/3` | `ecto/Ecto.Changeset.html#cast_embed/3` |
| `prepare_changes/2` runs inside the transaction | `ecto/Ecto.Changeset.html#prepare_changes/2` |
| What a changeset carries: `changes`, `errors`, `required`, `constraints` | `ecto/Ecto.Changeset.html` |
| `Ecto.Enum`, and whether the member set is enforced anywhere | `ecto/Ecto.Enum.html` |

## Persistence, queries and bulk writes · `ecto`

| Concept | Path |
|---|---|
| `update_all` writes SQL directly: no changeset, no validation, no timestamps | `ecto/Ecto.Repo.html#c:update_all/3` |
| `insert_all` never builds a struct, so nothing it writes is cast | `ecto/Ecto.Repo.html#c:insert_all/3` |
| `delete_all` skips `on_delete:` in the schema and every changeset | `ecto/Ecto.Repo.html#c:delete_all/2` |
| `Repo.transaction/2`: an inner transaction joins the outer one | `ecto/Ecto.Repo.html#c:transaction/2` |
| `Repo.rollback/1` — the only sanctioned way to probe a write | `ecto/Ecto.Repo.html#c:rollback/1` |
| `Ecto.Multi` step order, and what a failed step returns to the caller | `ecto/Ecto.Multi.html` |
| `Repo.preload/3` after the fact versus `preload:` in the query | `ecto/Ecto.Repo.html#c:preload/3` |
| `preload` in a query, and when it becomes a join | `ecto/Ecto.Query.html#preload/3` |
| An explicit `select:` list omits fields, and reading one raises | `ecto/Ecto.Query.html#select/3` |
| Composable queries, and what composes into what | `ecto/Ecto.Query.html` |
| `has_many`/`belongs_to` `on_delete:` is applied in Elixir, not by the database | `ecto/Ecto.Schema.html#has_many/3` |
| What a schema actually declares, after macros | `ecto/Ecto.Schema.html` |
| `__schema__/1` reflection, which is what the probes read | `ecto/Ecto.Schema.html#module-reflection` |

## Migrations and SQL · `ecto_sql`

| Concept | Path |
|---|---|
| Reversibility, and what `change` cannot undo | `ecto_sql/Ecto.Migration.html` |
| `index/3` and `concurrently: true` on Postgres | `ecto_sql/Ecto.Migration.html#index/3` |
| `@disable_ddl_transaction`, and why a concurrent index needs it | `ecto_sql/Ecto.Migration.html#module-transaction-configuration` |
| `references/2`, and the database's own `on_delete` | `ecto_sql/Ecto.Migration.html#references/2` |
| `execute/2` — up and down, because `execute/1` has no inverse | `ecto_sql/Ecto.Migration.html#execute/2` |
| Compiling a query to SQL without running it | `ecto_sql/Ecto.Adapters.SQL.html#to_sql/3` |
| `explain`, and reading a plan | `ecto_sql/Ecto.Adapters.SQL.html#explain/4` |
| Sandbox ownership, and why a spawned process cannot see the test's data | `ecto_sql/Ecto.Adapters.SQL.Sandbox.html` |

## LiveView · `phoenix_live_view`

| Concept | Path |
|---|---|
| `mount/3` runs twice — dead render, then connected | `phoenix_live_view/Phoenix.LiveView.html#c:mount/3` |
| `connected?/1`, and what belongs behind it | `phoenix_live_view/Phoenix.LiveView.html#connected?/1` |
| `handle_event/3` — an event with no clause crashes the process | `phoenix_live_view/Phoenix.LiveView.html#c:handle_event/3` |
| `handle_params/3`, and `live_action` from the router | `phoenix_live_view/Phoenix.LiveView.html#c:handle_params/3` |
| `handle_info/2`, and a broadcast payload that no longer matches | `phoenix_live_view/Phoenix.LiveView.html#c:handle_info/2` |
| Which bindings exist, and what each sends ‡ probe | `phoenix_live_view/bindings.html` |
| `stream/4` — stream items are not in assigns ‡ probe | `phoenix_live_view/Phoenix.LiveView.html#stream/4` |
| `assign_new/3`, so a parent's assign is not recomputed | `phoenix_live_view/Phoenix.LiveView.html#assign_new/3` |
| `push_patch/2` keeps the LiveView; `push_navigate/2` remounts it ‡ probe | `phoenix_live_view/Phoenix.LiveView.html#push_patch/2` |
| `live_session/3` and `on_mount` — the hook a route inherits, or does not | `phoenix_live_view/Phoenix.LiveView.Router.html#live_session/3` |
| What LiveView guarantees about authorization, and what it does not | `phoenix_live_view/security-model.html` |
| `allow_upload/3` constraints, and `consume_uploaded_entries` | `phoenix_live_view/Phoenix.LiveView.html#allow_upload/3` |
| `LiveComponent`: `update/2` per render, state lost when `id` changes | `phoenix_live_view/Phoenix.LiveComponent.html` |
| `to_form/2`, and how input names come from the changeset ‡ since 0.20 | `phoenix_live_view/Phoenix.Component.html#to_form/2` |
| Form bindings: `phx-change`, `phx-submit`, and validation on change | `phoenix_live_view/form-bindings.html` |
| `phx-hook` and `pushEvent` — the JS boundary a LiveView app still has | `phoenix_live_view/js-interop.html` |
| Testing an event, which is what catches a missing clause | `phoenix_live_view/Phoenix.LiveViewTest.html` |

## Router, controllers and plugs · `phoenix`, `plug`

| Concept | Path |
|---|---|
| `pipe_through`, and what a scope inherits — or does not | `phoenix/Phoenix.Router.html` |
| Routing, scopes and pipelines, as a guide | `phoenix/routing.html` |
| `action_fallback`, and which returns it translates | `phoenix/Phoenix.Controller.html#action_fallback/1` |
| Rendering a status, and which atom maps to which number | `phoenix/Phoenix.Controller.html` |
| `Plug.Conn` — assigns, halting, and what a halted conn skips | `plug/Plug.Conn.html` |
| Plug order in a pipeline | `plug/Plug.Builder.html` |
| `~p` verified routes are checked at compile time ‡ since 1.7 | `phoenix/Phoenix.VerifiedRoutes.html` |
| Compile-time `config.exs` versus boot-time `runtime.exs` | `phoenix/releases.html` |

## Serialization · `jason`

| Concept | Path |
|---|---|
| `@derive {Jason.Encoder, only: […]}` is the wire contract, and no compiler checks it | `jason/Jason.Encoder.html` |

## Background work · `oban`

| Concept | Path |
|---|---|
| Worker `args` are JSON in the database, so a deployed change meets an old payload | `oban/Oban.Worker.html` |
| Uniqueness, and what it does and does not deduplicate ‡ probe | `oban/Oban.html` |
| Retries, `max_attempts`, and what happens after the last one | `oban/Oban.Worker.html` |
| Testing that a job was enqueued rather than running it | `oban/Oban.Testing.html` |

## Processes and PubSub · `elixir`, `phoenix_pubsub`

| Concept | Path |
|---|---|
| `Task.async` without a supervisor, and an un-awaited task | `elixir/Task.html` |
| Supervised tasks that survive the caller | `elixir/Task.Supervisor.html` |
| `GenServer` state across a deploy | `elixir/GenServer.html` |
| A topic is a string both sides have to agree on | `phoenix_pubsub/Phoenix.PubSub.html` |

## Time, types and safety · `elixir`, `decimal`, `logger`

| Concept | Path |
|---|---|
| `DateTime.utc_now/1`, and truncation against a `:utc_datetime` column ‡ since 1.15 | `elixir/DateTime.html#utc_now/1` |
| `NaiveDateTime` carries no zone | `elixir/NaiveDateTime.html` |
| `String.to_atom/1` grows a table that is never collected | `elixir/String.html#to_existing_atom/1` |
| `Decimal` comparison — `==` on two decimals is not equality of value | `decimal/Decimal.html#equal?/2` |
| Logger metadata, and what `inspect/2` prints from a struct | `logger/Logger.html` |

## Tests · `ex_unit`, `mox`

| Concept | Path |
|---|---|
| `async: true`, and what makes a case unsafe to run concurrently | `ex_unit/ExUnit.Case.html` |
| `verify_on_exit!`, without which an expectation asserts nothing | `mox/Mox.html` |

---

`‡ probe` and `‡ since X` are about the sentence, never the link. § *What the marks mean*.

Every path above is stored **without** a version segment and **with** its package. § *Pinning* has the
emitted form, and § *Version* is why none of them is emitted yet.

## Adding a row

Open the URL. Not "recall" it, not derive it from the naming pattern — open it, confirm the page
documents the concept in the row, and confirm the fragment scrolls somewhere sensible. Check the
**package** as carefully as the module: `Ecto.Migration` under `ecto` is a 404, and it looks right.

Then run `evals/verify-catalogue.sh --catalogue references/elixir-docs.md`, which is the mechanical
half of the same sentence: it will tell you the page resolves and the fragment exists, at the version
it is pinned to. It cannot tell you the page documents the concept in the row — that is why the
paragraph above comes first and is not replaceable by the script.

A concept nobody has verified a URL for is still usable: explain it in prose and cite the repo line it
applies to, and propose a probe. That is the normal case, not a degraded one — and while § *Version*
holds this file closed, it is the **only** case.
