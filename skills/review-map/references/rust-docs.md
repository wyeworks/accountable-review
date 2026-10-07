# Rust documentation catalogue

The URLs the page is allowed to cite for a Rust codebase — either Rust stack, general or backend.
**A doc link that is not in this file does not go on the page** — not a guessed item path, not an
"obvious" `docs.rs` URL, not a page you are fairly sure of. The run cannot check a URL: there is no
fetch step in the procedure, and the sandboxes this skill commonly runs in block egress to these hosts
outright. So a link is either something a human opened once and wrote down here, or it is a 404 the
reader discovers on your behalf — and one dead link costs the same trust as one invented command.

`references/report-format.md` § *Framework anchors* owns what a doc link is *for*, when a claim earns
one, and the budget. This file is only the lookup: concept in, URL out.

**Read § *Version* before using this file.** It is not yet verified, and until it is, the answer this
file returns for every concept is *no link*.

## Version

**Not yet verified. No row in this file has been opened.**

Until a dated verification line appears in this section, **emit no link from this catalogue.** Explain
the mechanism in prose, cite the repo line, and propose a probe from `references/rust.md`
§ *Runtime probes* (or `references/rust-backend.md` § *Runtime probes*, on a backend).

**That also costs the primer callout.** An `aside.primer` is what a doc link escalates into, so it
cannot exist without one — `report-format.md` § *Mentor mode* and `evals/checks/rails-anchors.rb` § 8
both say so. While this file is closed, `--mentor` on a Rust project produces **no primer at all**,
and the flag is worth saying so about in chat rather than on the page. When it opens, the primer's
header names the stack in words — *Understanding Rust* — and nothing about the callout's shape changes.

This is the fail-closed rule of `rails-docs.md` § *Pinning* applied to a whole file, for the reason
`elixir-docs.md` § *Version* gives at length: the Rails catalogue's worst defect was a plausible URL
constructed once and admitted to the allowlist, the one class of defect no script catches and no care
while writing prevents. Every row below was written that way — from knowledge of rustdoc's naming
scheme and of the books' layout, on a machine that could not reach either host. So they are held
closed until a machine with egress has opened them.

What lifts it:

```sh
evals/verify-catalogue.sh --catalogue references/rust-docs.md
```

A clean run prints a dated line with every crate's version and the toolchain's; that line replaces
this section's first paragraph, and the links go live in the same commit. A run with failures is the
more likely outcome and is the point of running it.

**The probe is unaffected, and it is the better anchor anyway.** `cargo tree` and `cargo metadata`
interrogate the resolved build instead of describing it, so they cannot be out of date and they cannot
404. While this catalogue is closed they are the whole of what a Rust run offers. That is a narrower
page, not a broken one.

**The floor these rows are written against**, and below which no link is emitted even once the file
opens: Rust 1.70, `tokio` 1.28, `axum` 0.7, `actix-web` 4.0, `tower` 0.4, `sqlx` 0.7, `diesel` 2.0,
`anyhow` 1.0, `thiserror` 1.0, `tracing` 0.1. Below any of those, explain in prose and propose a probe.

## Shapes

Two hosts, and only these two:

```
docs.rs/<crate>/<version>/<crate_ident>/<module path>/<item>.html[#<anchor>]
doc.rust-lang.org/<toolchain version>/<book or library>/<page>.html[#<anchor>]
```

The first is every published crate's API documentation. The second is the toolchain's own: the
standard library (`std`), and the books that ship with each release — the Reference (`reference`), the
Cargo book (`cargo`), the Rustonomicon (`nomicon`) and the rustdoc book (`rustdoc`).

**These are the paths this file stores, and each one keeps its host** — `docs.rs/axum/axum/…`,
`doc.rust-lang.org/std/…` — with no version segment. § *Pinning* has the emitted form. Keeping the
host is what tells the two kinds apart without guessing: `cargo` is a crate on docs.rs *and* a book on
doc.rust-lang.org, and `std/…` would otherwise read as a crate path.

**The crate name and the crate's identifier are different strings, and the path holds both.** A crate
published as `actix-web` is imported as `actix_web`, and docs.rs serves it at
`docs.rs/actix-web/<version>/actix_web/…`. The first segment is the name from `Cargo.toml`, with its
hyphens; the third is the Rust identifier, with underscores. `docs.rs/actix-web/4.9.0/actix-web/…` is
a 404 that reads as correct, and it is the Rust form of the package trap `elixir-docs.md` warns about.

Rustdoc's file names say what kind of item a page documents, and the prefix is part of the path:

| Item | File | Anchor for a member |
|---|---|---|
| a struct | `struct.Router.html` | `#method.layer` |
| an enum | `enum.Ordering.html` | `#variant.Less` |
| a trait | `trait.IntoResponse.html` | `#tymethod.into_response` (required), `#method.…` (provided) |
| a function | `fn.spawn.html` | |
| a macro | `macro.select.html` | |
| an attribute macro | `attr.test.html` | |
| a derive macro | `derive.Error.html` | |
| a module | `<module>/index.html` | |
| a section of any page | | `#<heading-slug>` |

**The traps are the item kind and the re-export.** A trait documented at `struct.Foo.html` is a 404.
And a crate that re-exports an item documents it at its **defining** path, which is not the path users
import it by: `axum::Json` is `docs.rs/axum/<v>/axum/struct.Json.html`, while an item re-exported from
a dependency may live under that dependency's crate. Where unsure, the module's `index.html` is a page
this file can be certain of.

**A bad anchor is survivable and a bad path is not.** A fragment a page does not have is ignored by
every browser — the reader lands at the top of the right page. A wrong crate, a wrong identifier, a
wrong item kind or a wrong module is a 404. That asymmetry is why this file prefers a **page-level URL
it is certain of** to a deeper link it is not.

**No `latest`, no `stable`.** `docs.rs/<crate>/latest/…` and `doc.rust-lang.org/stable/…` both resolve
— to whatever is newest the day the reader clicks. Neither is a pinned form, and § *Pinning* says why
that matters.

**Never a `github.com/.../blob|pull|compare/` URL**, here as anywhere: `evals/checks/page-invariants.rb`
§ 5 fails a page that emits one when the head commit is unpushed. And **no other host**, including the
ones a Rust reader knows best: `serde.rs` documents serde's attributes and is not versioned, so serde
attribute behaviour is explained in prose and probed rather than linked — see § *Serialization*.

## Pinning

**Every URL in this file is a path, not a link. The run pins it to the codebase's own versions before
it reaches the page.**

```
https://docs.rs/<crate>/<version>/<rest of the stored path after the crate>
https://doc.rust-lang.org/<toolchain version>/<rest of the stored path after the host>
```

**A crate pins to its exact locked version**, read from `Cargo.lock` in step 2 — `axum` locked at
`0.7.9` gives `https://docs.rs/axum/0.7.9/axum/struct.Router.html`. Two traps, both specific to Cargo:

- **`Cargo.lock` can hold the same crate at two versions**, when two dependents require incompatible
  ones. Pin to the version the crate under review actually depends on — the one `cargo tree -i <crate>`
  shows under it, or the one its manifest's requirement admits — and when that cannot be told from the
  lock file alone, emit no link.
- **A workspace's own crates are not on docs.rs** unless they are published, and a published one is
  documented at its released version rather than at this branch. Never link to a crate in this
  repository; cite its source line instead.

**The toolchain pins to an exact release**, `major.minor.patch`: the `channel` in `rust-toolchain.toml`
or `rust-toolchain` when it names a version; otherwise the `rust-version` in the manifest (the MSRV,
which documents what the code may rely on); otherwise **no link** — a toolchain file saying `stable`,
or none at all, names no version, and guessing one is the unpinned link by another route. A
`rust-version` written as `1.75` pins as `1.75.0`.

**"One app, one series" has no Rust analogue.** Like Elixir's packages, every crate pins
independently, and the toolchain pins separately again, so **a correct Rust page carries several
different version segments** — `tokio` at one, `axum` at another, `std` at a third — and that is not a
defect. `evals/checks/rails-anchors.rb` encodes it: every `docs.rs` and `doc.rust-lang.org` link must
carry a version segment, and nothing requires them to agree.

**This is unconditional.** Not only for rows whose behaviour moved — every row. A pinned docs.rs page
prints its crate and version in its header, and a pinned doc.rust-lang.org page lives under its
release number, so the reader can hold the link against their own `Cargo.lock` at a glance.

**Above the floor but past what a verification run covered, pin anyway**: rustdoc's file naming is
stable across releases and the page self-identifies, so a mismatch that survives is visible to the
reader. **Below the floor in § *Version*, or where a row has no path for that crate at all, emit no
link.**

## What the marks mean

Two marks, and both are about the **sentence**, never the link — pinning takes the link's version
problem away entirely. They say what the page is allowed to claim. Identical in meaning to
`rails-docs.md` § *What the marks mean*, so that file's reasoning for keeping them distinct applies
here unchanged.

| Mark | Means | The run must |
|---|---|---|
| *(none)* | The behaviour has not changed across the supported range | State it, link it, move on |
| `‡ probe` | The behaviour **changed** inside the range, so no single sentence is true of every codebase | Not assert it. Ask the build: propose a probe, and name the setting or version that decides it |
| `‡ since X` | Surface was added in X; the default this row describes still holds | State it *as the default*, and name X where a reader could meet the new surface |

**The marks below were reasoned from knowledge of the crates, not from a CHANGELOG audit.** The Rails
file's came from reading the CHANGELOGs across three series; no equivalent audit has been done for any
crate here. So these marks are a first pass and are owed the same treatment — most sharply across
`axum` `0.7 → 0.8`, which changed the route syntax, and `sqlx` `0.7 → 0.8`. Until then, prefer the
probe wherever a sentence would have to be version-specific.

---

## The language · `std`, the Reference

| Concept the reviewer meets | Path |
|---|---|
| Integer overflow: a panic in debug, wrapping in release | `doc.rust-lang.org/reference/expressions/operator-expr.html#overflow` |
| `as` casts truncate and saturate rather than fail | `doc.rust-lang.org/reference/expressions/operator-expr.html#type-cast-expressions` |
| The `?` operator, and the `From` conversion it applies | `doc.rust-lang.org/reference/expressions/operator-expr.html#the-question-mark-operator` |
| `let _ =` binds nothing, so the value drops on that line | `doc.rust-lang.org/reference/patterns.html#wildcard-pattern` |
| Drop order: locals in reverse, fields in declaration order | `doc.rust-lang.org/reference/destructors.html` |
| `#[non_exhaustive]`, and what it requires of downstream matches | `doc.rust-lang.org/reference/attributes/type_system.html#the-non_exhaustive-attribute` |
| `#[must_use]`, and what silences it | `doc.rust-lang.org/reference/attributes/diagnostics.html#the-must_use-attribute` |
| What counts as undefined behaviour | `doc.rust-lang.org/reference/behavior-considered-undefined.html` |
| Derived `Ord` compares in declaration order | `doc.rust-lang.org/std/cmp/trait.Ord.html#derivable` |
| `Hash` and `Eq` must agree | `doc.rust-lang.org/std/hash/trait.Hash.html#hash-and-eq` |
| `From`, and the conversions `?` inherits from it | `doc.rust-lang.org/std/convert/trait.From.html` |
| `Send`, and what makes a type lose it | `doc.rust-lang.org/std/marker/trait.Send.html` |
| `Sync` | `doc.rust-lang.org/std/marker/trait.Sync.html` |
| `Mutex` poisoning after a panic | `doc.rust-lang.org/std/sync/struct.Mutex.html#poisoning` |
| A dropped `JoinHandle` detaches the thread | `doc.rust-lang.org/std/thread/fn.spawn.html` |
| `Instant` is monotonic | `doc.rust-lang.org/std/time/struct.Instant.html` |
| `SystemTime` is not, and its differences can fail | `doc.rust-lang.org/std/time/struct.SystemTime.html` |
| `OnceLock` for a lazily initialised global ‡ since 1.70 | `doc.rust-lang.org/std/sync/struct.OnceLock.html` |
| `std::env::var`, and the error for a missing variable | `doc.rust-lang.org/std/env/fn.var.html` |

## `unsafe` · the Rustonomicon

| Concept | Path |
|---|---|
| An `unsafe` block's soundness depends on the module around it | `doc.rust-lang.org/nomicon/working-with-unsafe.html` |
| `unsafe impl Send` and `Sync` | `doc.rust-lang.org/nomicon/send-and-sync.html` |

## Cargo · the Cargo book

| Concept | Path |
|---|---|
| Features are unified across the build | `doc.rust-lang.org/cargo/reference/features.html#feature-unification` |
| Mutually exclusive features, and why features must be additive | `doc.rust-lang.org/cargo/reference/features.html#mutually-exclusive-features` |
| Which changes are breaking for a published crate | `doc.rust-lang.org/cargo/reference/semver.html` |
| Caret requirements are the default | `doc.rust-lang.org/cargo/reference/specifying-dependencies.html#caret-requirements` |
| `rust-version`, the declared minimum toolchain | `doc.rust-lang.org/cargo/reference/manifest.html#the-rust-version-field` |
| Build scripts, and when they rerun | `doc.rust-lang.org/cargo/reference/build-scripts.html#rerun-if-changed` |
| `overflow-checks` per profile | `doc.rust-lang.org/cargo/reference/profiles.html#overflow-checks` |
| Workspaces, members and shared dependencies | `doc.rust-lang.org/cargo/reference/workspaces.html` |
| `cargo tree`, and inverting it with `-i` | `doc.rust-lang.org/cargo/commands/cargo-tree.html` |
| Doc tests, and what runs them | `doc.rust-lang.org/rustdoc/write-documentation/documentation-tests.html` |

## Async runtime · `tokio`

| Concept | Path |
|---|---|
| `select!` drops the losing branches — cancellation safety | `docs.rs/tokio/tokio/macro.select.html#cancellation-safety` |
| `spawn`, and a dropped handle that detaches the task | `docs.rs/tokio/tokio/task/fn.spawn.html` |
| `spawn_blocking` for work that would stall the runtime | `docs.rs/tokio/tokio/task/fn.spawn_blocking.html` |
| Which mutex to hold across an `.await` | `docs.rs/tokio/tokio/sync/struct.Mutex.html#which-kind-of-mutex-should-you-use` |
| `#[tokio::test]` runs on a current-thread runtime by default | `docs.rs/tokio/tokio/attr.test.html` |

## HTTP · `axum`, `tower`, `actix-web`

| Concept | Path |
|---|---|
| `Router::layer` wraps only the routes added before it | `docs.rs/axum/axum/struct.Router.html#method.layer` |
| `route_layer` applies to matched routes only | `docs.rs/axum/axum/struct.Router.html#method.route_layer` |
| Middleware ordering in `axum` | `docs.rs/axum/axum/middleware/index.html#ordering` |
| Extractor order — the body extractor comes last | `docs.rs/axum/axum/extract/index.html#the-order-of-extractors` |
| `State`, checked at compile time | `docs.rs/axum/axum/extract/struct.State.html` |
| `Extension`, which is not | `docs.rs/axum/axum/struct.Extension.html` |
| `Json` as an extractor, and the statuses it rejects with | `docs.rs/axum/axum/struct.Json.html` |
| `IntoResponse`, which is where an error becomes a status | `docs.rs/axum/axum/response/trait.IntoResponse.html` |
| Error handling, and why a handler cannot fail the service | `docs.rs/axum/axum/error_handling/index.html` |
| Route path syntax ‡ probe | `docs.rs/axum/axum/struct.Router.html#method.route` |
| `ServiceBuilder` applies layers top to bottom | `docs.rs/tower/tower/struct.ServiceBuilder.html#order` |
| `App::wrap` — the last registered runs first | `docs.rs/actix-web/actix_web/struct.App.html#method.wrap` |
| `web::Data`, and the runtime error when it was never added | `docs.rs/actix-web/actix_web/web/struct.Data.html` |
| `ResponseError`, where an error becomes a status | `docs.rs/actix-web/actix_web/trait.ResponseError.html` |

## Persistence · `sqlx`, `diesel`

| Concept | Path |
|---|---|
| `query!` is checked at compile time — against a database or offline data ‡ probe | `docs.rs/sqlx/sqlx/macro.query.html` |
| `query` without the `!` is checked by nothing | `docs.rs/sqlx/sqlx/fn.query.html` |
| `migrate!` embeds migrations in the binary | `docs.rs/sqlx/sqlx/macro.migrate.html` |
| A `Transaction` dropped without `commit` rolls back | `docs.rs/sqlx/sqlx/struct.Transaction.html` |
| `#[sqlx::test]` gives each test its own database | `docs.rs/sqlx/sqlx/attr.test.html` |
| `Queryable` maps columns by position | `docs.rs/diesel/diesel/deserialize/trait.Queryable.html` |

## Errors and diagnostics · `anyhow`, `thiserror`, `tracing`

| Concept | Path |
|---|---|
| `Context`, which keeps the "where" an error lost | `docs.rs/anyhow/anyhow/trait.Context.html` |
| `thiserror`'s derive: `#[from]`, `#[source]`, `#[error(transparent)]` | `docs.rs/thiserror/thiserror/index.html` |
| `#[instrument]` records every argument unless told to `skip` | `docs.rs/tracing/tracing/attr.instrument.html` |

## Serialization · `serde`

| Concept | Path |
|---|---|
| `Serialize`, the trait a derive implements | `docs.rs/serde/serde/trait.Serialize.html` |
| `Deserialize` | `docs.rs/serde/serde/trait.Deserialize.html` |

That is all, and it is deliberate. What a reviewer needs from serde is its **attributes** —
`rename_all`, `default`, `untagged`, `deny_unknown_fields`, `skip_serializing_if` — and those are
documented on `serde.rs`, which is not versioned and is not docs.rs. A link there could not be pinned,
so it is not a link this page may carry. Explain the attribute in prose, cite the line it sits on, and
where the question is what bytes a type actually produces, point at the test or the fixture that
pins them.

---

`‡ probe` and `‡ since X` are about the sentence, never the link. § *What the marks mean*.

Every path above is stored **without** a version segment and **with** its host and, for docs.rs, its
crate name. § *Pinning* has the emitted form, and § *Version* is why none of them is emitted yet.

## Adding a row

Open the URL. Not "recall" it, not derive it from rustdoc's naming scheme — open it, confirm the page
documents the concept in the row, and confirm the fragment scrolls somewhere sensible. Check the
**crate name against the identifier** and the **item kind** as carefully as the item: a trait at
`struct.…`, or `actix-web` where `actix_web` belongs, is a 404 that looks right.

Then run `evals/verify-catalogue.sh --catalogue references/rust-docs.md`, which is the mechanical half
of the same sentence: it will tell you the page resolves and the fragment exists, at the version it is
pinned to. It cannot tell you the page documents the concept in the row — that is why the paragraph
above comes first and is not replaceable by the script.

A concept nobody has verified a URL for is still usable: explain it in prose, cite the repo line it
applies to, and propose a probe. That is the normal case, not a degraded one — and while § *Version*
holds this file closed, it is the **only** case.
