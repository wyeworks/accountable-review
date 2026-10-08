# Rust lenses

What to look for in Rust code of any kind, plus two sets of recipes for reaching past the diff: the
**runtime probes** that ask the build what the code amounts to, and the **search recipes** that find
the code the diff did not touch. This is the knowledge a senior reviewer applies from memory and that
cannot be inferred from a diff — it is what makes the page a review map rather than a change summary.

**This file is read by every Rust run, and it is the whole lens for one of the two Rust stacks.**
Step 2 tells them apart: a crate that serves requests — an HTTP or gRPC server, with its routes, its
database and its wire contract — is a **Rust backend**, and that run reads
`references/rust-backend.md` *after* this file, as a second layer on top of it. Everything else — a
library, a CLI, an embedded target, a WASM module, a workspace of crates that serves nothing — is
**Rust in general**, and this file is all of it. The split is deliberate rather than tidy: a backend
is still a crate, so everything below applies to it, and nothing in the backend file is restated here.

Where a lens turns on a language, Cargo or crate behaviour the reader might reasonably not know, the
canonical URL for it is in `references/rust-docs.md`, and `report-format.md` § *Framework anchors*
says when a claim has earned a link. Do not construct one from memory. **Read that file's § *Version*
first**: while the catalogue is unverified it yields no links at all, and the anchor a Rust run
actually gets is the probe.

**The compiler is on the reviewer's side, and that moves where the findings are.** A Rust diff that
reached review compiles, so the type errors, the borrow errors and the missing `match` arm on an
exhaustive match are already gone. What is left is what the compiler was *told not to check* — a
wildcard arm, an `unwrap`, an `unsafe` block, a `pub` item a downstream crate depends on, a feature
combination nobody builds, a serde attribute, a value persisted in an old shape — and what it *cannot*
see, which is every consumer outside the crates in this build. Spend the run there. A finding the
compiler would have produced is not a finding.

**Apply these as lenses while reading, never as a checklist in the output.** The page reports what
was actually found, with `file:line`. It never says "we checked for `unsafe`" as reassurance — an
absent finding is reported by absence, not by a green tick.

---

## The public API and its consumers

- **Who can see it decides who it breaks.** A `pub` item in a library crate is a contract with every
  downstream crate, none of which is in this diff and most of which are not in this repository. A
  `pub(crate)` item's consumers are all in this crate and all findable. Read the visibility before
  deciding how far step 5 has to look — and read the re-exports, because a `pub use` in `lib.rs` makes
  a private-looking module path public.
- **The breaking changes the compiler does not flag here, because they break somebody else's build**:
  - a new variant on a `pub enum` without `#[non_exhaustive]` — every downstream exhaustive `match`
    stops compiling;
  - a new `pub` field on a struct whose fields were all `pub` — every downstream struct literal and
    exhaustive destructuring stops compiling;
  - a new trait method without a default — every downstream `impl` stops compiling;
  - a tightened generic bound, a removed `impl`, a removed or renamed feature;
  - **a type that silently stopped being `Send` or `Sync`** — an `Rc`, a `RefCell` or a raw pointer
    added as a field. Auto traits are inferred from fields, so the diff of the struct is the whole
    change and nothing at the definition says what was lost. The caller holding it across a thread or
    an `.await` is where it fails.

  Whether the crate is published, and at what version, decides whether any of this is a question:
  `publish = false` in the manifest, or a workspace-internal crate whose every consumer is in the
  diff, makes it a refactor rather than a release.
- **Adding `#[non_exhaustive]` is itself breaking** — downstream matches now need a wildcard — and is
  the right change to make exactly once, at a major version.
- A version bump in the manifest that does not match the change: a breaking change shipped as a minor
  or patch release is the one a downstream `cargo update` delivers without asking.

## Workspaces, features and Cargo

- **Features are unified across the build.** Two crates enabling different features of a shared
  dependency get one copy with the union, so a feature has to be **additive** — a feature that
  *removes* behaviour, or two that are mutually exclusive, works in isolation and breaks the first
  time another crate in the graph enables the other one. `cargo tree -e features -i <crate>` shows who
  turned what on.
- **Code behind a `#[cfg(feature = "…")]` that CI never builds.** A change to a feature-gated function
  is checked only in the combinations someone runs. Ask which combinations the workflow builds —
  `--all-features`, `--no-default-features`, a matrix — and whether the changed code sits in one of
  them. A crate that has never been built with `--no-default-features` usually does not compile that
  way, and the diff will not say so.
- `default-features = false` on a dependency, added or removed: it turns off behaviour the code may
  have been relying on implicitly — TLS, a runtime, `std`.
- **Version requirements are caret by default.** `foo = "1.2"` means `>=1.2.0, <2.0.0`; a minimum
  raised in the manifest without a matching use of the new surface is noise, and a new use of a
  surface without raising the minimum works only because `Cargo.lock` happens to hold a newer one.
- `Cargo.lock` in the diff: which crates moved, whether a major version of anything moved, and
  whether two versions of the same crate now coexist (`cargo tree -d`) — two `serde`s or two `http`s
  make types that look identical and do not unify, which surfaces as a confusing error somewhere far
  from the bump.
- **`build.rs` runs arbitrary code at build time, and what it generates is not in the diff.** Code
  `include!`d from `OUT_DIR` — protobuf, bindings, a version string — changes when its input changes,
  and its input may be a file this diff touches. Without a `cargo::rerun-if-changed` line, the script
  reruns on any change in the package; with the wrong one, it does not rerun when it should.
- `rust-version` (the MSRV) and `rust-toolchain.toml`: a new language or `std` feature used by code
  that claims an older MSRV compiles on the author's toolchain and fails for every consumer pinned at
  the claimed one. An edition change in the manifest changes the meaning of existing code in small,
  documented ways.
- `[patch]` and `[replace]` sections, and git dependencies: a dependency pinned to a branch moves
  under everyone the next time the lock file is regenerated.

## Types, traits and generics

- **Trait impls are global.** A new `impl` — especially a blanket `impl<T: Bound> Trait for T` —
  can change which method a call resolves to, or make an existing call ambiguous, in code the diff
  never touched. A new `impl From<X> for E` makes every `?` on a `Result<_, X>` convert silently, which
  is the point and also how a caller's error starts arriving as a variant it never matched on.
- **Derived ordering is declaration order.** `#[derive(PartialOrd, Ord)]` compares a struct's fields
  in the order they are written and an enum's variants in the order they are declared. Reordering
  fields or variants for tidiness changes every sort, every `BTreeMap` iteration and every `max()` that
  relies on it — and the diff reads as a cosmetic move. The same reordering changes an enum's implicit
  discriminants, so anything that casts it with `as` or persists it as an integer now reads a
  different variant.
- **`Eq` and `Hash` must agree.** A hand-written `PartialEq` beside a derived `Hash` (or the reverse)
  breaks every `HashMap` keyed on the type, without a panic, by putting equal keys in different
  buckets.
- `Deref` to a type with methods of the same name shadows or reveals them; `Default` derived on a type
  that gained a field picks that field's default, which is a behaviour change for every
  `..Default::default()`.
- **`#[derive(Debug)]` on a type holding a secret** prints it wherever the type is logged, formatted
  into an error, or captured by a tracing span — none of which is in the diff that added the field.
- Generic code monomorphised for a new type: a bound loosened from `Copy` to `Clone`, or a `'static`
  bound added, changes what callers can pass, and a bound added to a trait object type changes what
  the vtable has to carry.

## Ownership, lifetimes and `unsafe`

- **A `.clone()` added to satisfy the borrow checker** changes semantics as well as cost. On an `Rc`
  or an `Arc` it shares; on a `Vec`, a `String` or a struct of them it copies, so a write through the
  clone is no longer seen by the original. Which one the author expected is the judgment.
- **The soundness of an `unsafe` block depends on code outside it.** The invariant an `unsafe` block
  relies on — a length, an alignment, an initialisation, a pointer's validity — is usually maintained
  by *safe* code in the same module, which is why the module is the unit to read. A diff that touches
  only safe code in a module containing `unsafe` can still break it, and that is the
  affected-but-unchanged case this stack has in its sharpest form. Look for the `// SAFETY:` comment,
  ask whether it still holds after the change, and say when there is none.
- `unsafe impl Send` or `unsafe impl Sync` is a claim about every field of the type, including fields
  added later by someone who never saw the impl.
- `transmute`, `from_raw_parts`, `get_unchecked`, `set_len`, `MaybeUninit::assume_init` and FFI calls
  are the usual sites; `#![forbid(unsafe_code)]` at the crate root, if present, means none of this
  applies and is worth knowing.
- Lifetimes added to a public signature are a contract like any other bound — an elided lifetime that
  became explicit can tie an output to a different input than before.

## Errors and panics

- **Every way a call can panic is a way the function's contract changed**: `unwrap()`, `expect()`,
  indexing `v[i]`, slicing, integer division, `RefCell::borrow_mut`, a `todo!()` or `unreachable!()`
  that is reachable. In a library a panic is an abort for whoever calls it; in a server it is a dropped
  request or a poisoned lock. Ask whether the input that triggers it can arrive.
- **A discarded `Result`.** `let _ = fallible();` and `.ok();` throw the error away on purpose, and
  `#[must_use]` warnings silenced that way are invisible in review because the line looks deliberate.
- **`let _ = guard;` and `let _guard = guard;` are different programs.** The wildcard pattern does
  not bind, so a lock guard, a span guard or a temporary file assigned to `_` is dropped on that line,
  not at the end of the scope.
- An error enum that gained a variant is a breaking change for every caller that matches on it
  exhaustively (see above), and a wildcard arm in one of those matches silently absorbs it.
- `?` with a `From` conversion erases context: the caller receives the converted error with nothing
  saying where it came from. `anyhow::Context` or a `thiserror` `#[source]` is how it is kept.
- `anyhow::Error` returned from a library's public API hands callers an error they cannot match on.
- Panics across an FFI boundary or out of a spawned thread: the first is undefined behaviour unless
  caught, the second is lost unless something joins the thread.
- **Drop order is declaration order, reversed for locals and forward for fields.** A struct field
  reordered for tidiness changes which resource is released first.

## Concurrency and async

- **A type has to be `Send` to cross a thread or a `tokio::spawn`**, and the compiler enforces it —
  so the finding is not the error, it is the workaround: an `Arc<Mutex<…>>` added around something
  that did not need sharing, or a `spawn_local` that changes which thread the work runs on.
- **`std::sync::Mutex` poisons on panic.** Every `lock().unwrap()` after a panicked holder panics in
  turn; that is usually the right behaviour and is worth knowing when a new panic path is added inside
  a critical section.
- **Blocking inside `async`** — `std::thread::sleep`, synchronous file or network I/O, a CPU-heavy
  loop, `std::sync::Mutex::lock` on a contended lock — stalls every other task on that worker thread.
  It compiles, it passes tests with one request in flight, and it shows up under load. `spawn_blocking`
  or an async equivalent is the fix; whether the call is actually slow is the judgment.
- **Holding a lock guard across `.await`.** A `std` guard makes the future `!Send`, which the compiler
  catches if the future is spawned; an async mutex guard held across an `.await` compiles everywhere
  and is how a deadlock or a long stall gets in.
- **Cancellation.** A future can be dropped at any `.await` — by `select!`, by a timeout, by a caller
  that went away — and the code after that point never runs. A function that does two writes with an
  `.await` between them is a function that can do one. `tokio::select!` documents which operations are
  cancellation-safe; a branch built on one that is not loses data when another branch wins.
- **A detached task.** A `JoinHandle` dropped without being awaited detaches the task: it keeps
  running, and its panic or its error goes nowhere. The same for `std::thread::spawn`.
- Atomics with `Ordering::Relaxed` used to publish data another thread then reads: the ordering is the
  whole correctness argument, and it is the one line a reviewer has to reason about rather than read.

## Serialization and persisted formats

- **A serde attribute is a contract, and no compiler checks the other side.** `rename_all`, `rename`,
  `alias`, `default`, `skip_serializing_if`, `flatten`, `tag`, `untagged` each change what bytes a type
  reads and writes. A field renamed in Rust without a `#[serde(rename = "…")]` renames it on the wire
  and in every stored document.
- **`#[serde(untagged)]` tries variants in declaration order** and takes the first that fits, so
  reordering variants, or adding one that also fits, changes what existing input deserializes to.
- `deny_unknown_fields` on a type read from somewhere another version writes: the first writer that
  adds a field breaks every reader still on this one. Its absence is the opposite trade — an old
  reader silently drops what a new writer sent.
- `Option<T>` with `skip_serializing_if = "Option::is_none"` writes no key; without it, `null`. A
  reader that distinguishes the two is a consumer of that line.
- **Non-self-describing formats encode position, not names.** In `bincode`, `postcard` and similar,
  reordering fields, inserting one in the middle, or reordering enum variants changes how every
  existing byte is read — with no error, if the types happen to line up. Anything persisted in one —
  a cache, a file on disk, a message on a queue — is the data still in the old shape when this
  deploys.
- Config files deserialized with serde are the same contract with a human on the other end: a newly
  required key fails every deployment whose file does not have it.

## Macros and generated code

- **What a derive or an attribute macro produces is not in the diff.** A field added to a struct with
  `#[derive(Serialize)]`, `#[derive(Builder)]`, `#[derive(clap::Parser)]` or an ORM derive changes
  generated code the reader never sees; the change to the field is the whole visible diff and the
  behaviour lives in the expansion. `cargo expand` shows it, where installed.
- A `macro_rules!` body changed: every call site is a consumer, and they are found by searching for
  `name!(`, which no "find references" in an editor reliably does.
- A procedural macro crate in the workspace: its consumers are every crate that derives from it.

## Numbers, time and data types

- **Integer overflow panics in debug and wraps in release**, unless the profile sets
  `overflow-checks`. A test suite run in debug that never overflows proves nothing about the release
  build that does; `checked_*`, `saturating_*` or `wrapping_*` say which behaviour was meant.
- **`as` between numeric types truncates or saturates silently.** `u64 as u32` drops the high bits,
  `i64 as usize` turns a negative into a huge index, `f64 as i32` saturates. `try_from` is the checked
  form, and a new `as` on a value that came from outside the program is worth a sentence.
- Floats compared with `==`, or used as a sort key without `total_cmp`.
- `Instant` is monotonic and `SystemTime` is not; a duration computed from two `SystemTime`s can be
  negative and returns an error. `chrono` and `time` disagree on more than their names; a crate using
  both converts somewhere, and the conversion is the place to look.
- Money in `f64`. A decimal crate (`rust_decimal`) is the usual answer, and its absence is worth a
  clause where the code does arithmetic on currency.

## Coding decisions, against this codebase's own answers

Every other section here asks what the change *does*; this one asks how it was built, and its evidence
is always a module, a crate or a convention doc the diff never touched. `report-format.md`
§ *Coding decisions* owns when this becomes a checkpoint — one per departure, ranked last, never
displacing a behavioural judgment, and **never without a citation**.

**Stack conventions — the closed list.** These hold across Rust codebases because the toolchain or the
crate documents them, which is what admits them as a source when the repository is silent. Nothing
outside this list qualifies; adding to it means adding the catalogue row that documents it, through
`evals/verify-catalogue.sh`, never a URL written from memory. The row named is `rust-docs.md`'s, and
it is the checkpoint's one doc link. The Rust API Guidelines are the source a Rust reviewer would
reach for first and are not on the list, because they live on neither catalogue host and are not
versioned.

| Convention | The PR departs when it… | Catalogue row |
|---|---|---|
| Cargo features are additive | adds a feature that turns behaviour *off*, or two features that cannot both be enabled — a `compile_error!` on the pair, or a `cfg(not(feature = …))` path the other feature replaces | *Mutually exclusive features, and why features must be additive* |
| A published crate's breaking change moves the major version — the minor, below 1.0 | changes or removes a `pub` item, adds a required trait method or a field to an exhaustive public struct, and leaves the version where it was | *Which changes are breaking for a published crate* |
| Blocking work in async code goes to `spawn_blocking` | calls `std::fs`, a synchronous client or a long CPU loop straight inside an `async fn` that runs on the tokio runtime | *`spawn_blocking` for work that would stall the runtime* |
| A lock not held across an `.await` is a `std` mutex | introduces `tokio::sync::Mutex` for data whose guard never crosses an await, or the reverse — a `std::sync::Mutex` guard held across one | *Which mutex to hold across an `.await`* |
| Application state reaches an `axum` handler through `State` | adds an `Extension` layer for state the router could pass with `with_state`, trading a compile error for a runtime 500 | *Sharing state with handlers — `State` preferred, as the more type safe* |

A row applies only where its stack is in the build: the two `tokio` rows where `tokio` is, the `axum`
row where `axum` is, the SemVer row only for a crate this repository publishes — `publish = false`, or
no release history, and it is not a question.

**Look for a written decision first.** Step 2 read the project's convention docs; a line there that
names the choice is the strongest `Y` there is, and a doc that blesses the PR's choice closes the
question whatever the list above says. Otherwise the `Y` is this repository's own: a sibling module,
crate or populated directory.

- **A second error strategy in a crate that has one.** A `Box<dyn Error>` or `anyhow::Result` in a
  library whose every other function returns its own `thiserror` enum, or a hand-written `Display`
  beside a crate full of derived ones. The cost is callers who can no longer match on the error.
- **A new crate in the workspace, or a module where the workspace would have put a crate.** A
  workspace that splits by crate is a decision about compile times and visibility; a module that opts
  out of it, or a crate that opts into it for one type, is a choice someone made.
- **A `utils` or `helpers` module** in a crate whose code is otherwise organised by domain.
- **A second way to do a job the codebase already does one way** — a hand-rolled retry loop beside a
  retry crate, a `lazy_static!` beside `std::sync::OnceLock`, a manual builder beside a derived one,
  `log` macros in a crate that otherwise uses `tracing`.
- **`unwrap()` in a crate whose siblings propagate**, or the reverse: a crate that treats panics as
  bugs and one function that treats them as control flow.

**Ask; never answer**, exactly as in the other stacks: *is it deliberate that X, given Y?* and never
*X should be Y*. The reviewer knows why their workspace is shaped as it is; you know only that this
file is shaped differently from its neighbours.

Finding the `Y` is one listing and three searches:

```sh
ls src crates 2>/dev/null                                        # what kinds this workspace has a home for
rg -n '^members|^\[workspace' -g Cargo.toml                      # how it is split into crates
rg -l 'thiserror|anyhow' -g Cargo.toml                           # which crates settled on which error style
rg -n 'pub enum \w*Error' -g '*.rs'                              # the error types siblings return
```

## Tests

- **New behaviour with no test**, or a test that asserts the mock rather than the behaviour.
- **Where the tests are decides who runs them.** Unit tests sit in the same file under
  `#[cfg(test)] mod tests` — a diff can add one without any file under `tests/` changing.
  Integration tests in `tests/` see only the crate's public API. **Doc tests run under `cargo test`
  and not under `cargo nextest`**, so a project on nextest may never have run an example that the
  change just broke; check what CI invokes.
- Tests gated behind a feature, or behind `#[ignore]`, run only where someone asks for them.
- **A changed snapshot is an approved behaviour change.** With `insta` or `expect-test`, the `.snap`
  file or the inline string in the diff *is* the new expected output, and accepting it is the moment
  a reviewer agrees the behaviour changed. Read the snapshot diff as a behaviour diff, not as test
  churn.
- Property tests (`proptest`, `quickcheck`) with a regressions file: a deleted or emptied
  `proptest-regressions` file throws away the counterexamples it was keeping.
- Tests that depend on wall-clock time, thread scheduling, or a port being free; `#[tokio::test]`
  defaults to a current-thread runtime, so a test that passes there can hide a `Send` or a blocking
  problem a multi-threaded runtime would show.
- Error paths and boundary values left uncovered — the most commonly missed cases.
- Tests deleted or marked `#[ignore]` as part of the change, which deserves an explicit note either
  way.

---

## Runtime probes

A search finds code. A probe asks the build what that code amounts to — and in Rust that is a
different and better question for anything assembled from parts the diff cannot show together: the
feature set Cargo actually resolved, the dependency versions the lock file actually holds, the
expansion of a derive, the public API as rustdoc sees it. `cargo tree -e features -i serde` answers
*which crate turned this feature on*, which no file in the repository states.

So for a change to a manifest, a feature, a derive, a public signature or a dependency, **reach for a
probe before reaching for a paragraph.** Where a probe would settle the judgment a checkpoint asks for,
it goes inside that checkpoint, after its explanation; where it would only make a mechanism legible, a
clause in the explanation does the job and the probe is not earned.
`references/report-format.md` § *Framework anchors* owns that routing rule and the budget.

**These are proposed, never run.** This skill does not build the code under review, which means the
page shows the command and never its output. A fabricated dependency tree, or an invented compiler
error presented as what the probe printed, is the console form of an invented command: it reads as the
most concrete thing on the page and it is the one part of it that is fiction.

Four rules make a probe safe to paste, and they matter more than the list below:

- **Every Cargo command carries `--locked`.** Without it, a command that resolves dependencies may
  rewrite `Cargo.lock` to match the manifest, and a reviewer who pasted a read-only-looking probe has
  changed a file in their checkout. With it, a lock file that does not match fails loudly instead —
  which is itself a finding.
- **A command that compiles runs code.** `cargo check`, `cargo test` and `cargo build` execute every
  build script and procedural macro in the graph, including the ones this pull request changed. That
  is the same trust as building the branch at all, and the reviewer is about to do that anyway — but
  the label says *compiles*, so nobody pastes it believing it only reads. `cargo tree` and
  `cargo metadata` compile nothing and are the first ones to reach for.
- **Say when a tool is not part of Cargo.** `cargo expand`, `cargo semver-checks`, `cargo nextest`,
  `cargo insta` and `cargo sqlx` are separate installs, and a probe that fails for want of one is an
  invented command by another route. The label names the install; `cargo expand` also needs a nightly
  toolchain present.
- **There is no console.** Rails has `console --sandbox` and Elixir has `iex`; Rust has neither, so a
  probe that would need to *call* the changed code is a test, not a one-liner: name the existing test
  that exercises it, or propose `cargo test --locked -p <crate> <name>` against one. Never propose
  writing a scratch `main.rs` into the reviewer's checkout.

**Answering in a fresh checkout is the earning test**, and `references/report-format.md`
§ *Framework anchors* owns it. What is Rust-specific is which commands pass it: `cargo tree`,
`cargo metadata` and `cargo test -- --list` need no database, no network beyond the registry index,
and no environment, so they answer anywhere the branch builds. Reach for those first.

Substitute the project's real package names throughout — `-p` takes the `name` from the crate's
manifest, which is not always its directory — and never propose a probe whose output would print
secrets, such as `env` or a config dump.

**The dependency graph, as Cargo resolved it**

```sh
cargo tree --locked -p mycrate -e features -i serde           # which crate turned on which serde feature
cargo tree --locked -d                                        # crates that now exist at two versions
cargo tree --locked -i tokio --depth 1                        # who depends on this directly
cargo metadata --locked --format-version 1 --no-deps | jq -r '.packages[] | "\(.name) \(.version) \(.rust_version)"'
```

The first is how a non-additive feature becomes visible: it names the crate that enabled the feature
the code did not expect. The second is how two copies of a type that do not unify become visible
before the error they cause.

**Which feature combinations still compile**

```sh
cargo check --locked -p mycrate --no-default-features
cargo check --locked -p mycrate --all-features
cargo check --locked -p mycrate --no-default-features --features serde
```

Compiles the crate, so it runs build scripts and macros. A combination that fails here and that CI
never builds is a finding the diff could not show.

**What the tests are, without running them**

```sh
cargo test --locked -p mycrate -- --list                     # every test the harness knows, by path
cargo test --locked -p mycrate --doc                         # the doc tests nextest never runs
```

The first compiles the test binaries and lists their tests without running one, which answers *is
there a test for this* faster than a search does.

**What a derive or a macro expands to**

```sh
cargo expand --locked -p mycrate path::to::module            # separate install; needs a nightly toolchain present
```

**What the public API now promises**

```sh
cargo semver-checks --baseline-rev <base sha> -p mycrate     # separate install; builds both revisions' rustdoc
```

This one compares the head's public API against the base revision and names every change that breaks
a semver guarantee, which is the whole of § *The public API and its consumers* asked of rustdoc
instead of of a reader. It builds documentation for both revisions, so it is slow, and it is earned
only where the crate has downstream consumers outside this workspace.

## Search recipes for affected-but-unchanged code

Step 5 of the procedure lives or dies on these. Run the search, then **record it** — an empty result
is a finding only if the reader can see what was looked for.

Adjust paths to the layout step 2 discovered — a single crate keeps code in `src/`, a workspace in
`crates/*/src` or wherever its `members` say. `rg` is assumed, `grep -rn` works the same. **Search
the whole workspace, not the crate that changed**: the consumers of a crate are the other members.

**A changed function or method**

```sh
rg -n '\barchive_project\b' -g '*.rs'                         # call sites, and calls through a re-export
rg -n 'pub use .*archive_project|pub use .*projects::' -g '*.rs'   # where it is re-exported under another path
rg -n 'archive_project' -g '*.md' -g '*.rs' --glob '!target'  # doc examples, which are doc tests
```

**A changed type, trait or trait method**

```sh
rg -n 'impl(<[^>]*>)? +Archive +for' -g '*.rs'               # every implementor of the trait
rg -n 'impl(<[^>]*>)? +\w+ +for +Project\b' -g '*.rs'         # every trait this type implements
rg -n ': *Archive\b|dyn +Archive|impl +Archive' -g '*.rs'     # bounds and trait objects that rely on it
```

A blanket `impl<T: Bound> Trait for T` does not name the type it applies to, so the second search
misses it. Search the trait's name as well as the type's.

**A changed enum — the arms that will not tell you**

```sh
rg -n 'Status::' -g '*.rs'                                    # every construction and every arm
rg -n '_ *=>' -g '*.rs' <files that match on Status>          # wildcard arms that absorb a new variant
rg -n 'Status::\w+ as |as u8|as i32' -g '*.rs'                # casts to an integer, which reordering moves
```

The compiler reports a new variant only where a `match` is exhaustive. **A wildcard arm is where the
new variant goes silently**, and it is the finding; the arms the compiler flagged are already fixed in
the diff. This is the search a `figure.lifecycle` is earned by, when the enum is a state with guarded
transitions between its values — `report-format.md` § *Topology figures* owns the rest.

**A changed struct field, or a serde attribute**

```sh
rg -n '\barchived_at\b' -g '*.rs'                             # every reader and writer
rg -n 'archivedAt|"archived_at"' -g '!target'                 # the serialized name, in fixtures, JSON and other languages
rg -n 'Project *\{' -g '*.rs'                                 # struct literals, which a new pub field breaks
```

Search the **old** name as well as the new one. The stale reader is the finding; the updated one is
already in the diff.

**A changed feature**

```sh
rg -n 'feature *= *"serde"|cfg\(feature *= *"serde"' -g '*.rs'
rg -n 'features *= *\[[^]]*"serde"' -g Cargo.toml             # who enables it, inside this workspace
rg -n 'all-features|no-default-features|--features' .github   # which combinations CI builds
```

**A changed `unsafe` block, or safe code in a module that has one**

```sh
rg -n 'unsafe' <the module's file>                            # every block whose invariant this module keeps
rg -n 'SAFETY' <the module's file>                            # the comments stating those invariants
```

The search is per module rather than per symbol, because the invariant is kept by the module.

**A changed macro**

```sh
rg -n '\barchive_all!' -g '*.rs'                              # every call site of a macro_rules! macro
rg -n 'derive\([^)]*\bArchive\b' -g '*.rs'                    # every type deriving a proc macro
```

**A changed manifest or dependency**

```sh
rg -n '^mycrate *=|^mycrate *= *\{|mycrate *= *\{ *path' -g Cargo.toml   # workspace members that depend on it
rg -n 'build *= *|links *= *' -g Cargo.toml                   # build scripts, and native libraries linked
```

**A changed panic path**

```sh
rg -n '\.unwrap\(\)|\.expect\(|panic!\(|unreachable!\(|todo!\(' <changed files>
```

Run it over the changed files only: across the whole workspace it is a census, not a finding. A new
panic is worth a sentence only where the input that triggers it can arrive.
