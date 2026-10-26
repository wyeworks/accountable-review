# Discovering a Rust project

Read at `SKILL.md` step 2, once, right after the stack is detected — this file and no other stack's.
It says what to find out about the repository before any tracing, and which versions the
documentation links will be pinned to. The lens, `references/rust.md` with
`references/rust-backend.md` on a backend, is still read at step 5.

## The workspace

Read the root `Cargo.toml` first: a `[workspace]` table and its `members` say where the crates are,
and each member's own manifest says what it is — a `[lib]`, one or more `[[bin]]`s, a
`proc-macro = true`. Record each crate's **package name**, because that is what `-p` and every probe
takes and it is not always the directory's. Detect, don't assume: the edition and `rust-version`;
whether `rust-toolchain.toml` pins a toolchain; the features each changed crate declares and its
`default` set; whether a crate is published (`publish = false` says it is not, and an unpublished
crate's public API has no consumers outside this workspace); whether there is a `build.rs`; the test
runner CI invokes — `cargo test` or `cargo nextest`, which skips doc tests — and the feature
combinations it builds; and whether the crate root carries `#![forbid(unsafe_code)]`.

## Backend

On a **Rust backend**, also find the server framework and its version; the database layer — `sqlx`
(and whether `.sqlx/` holds offline query data), `diesel` (and where `schema.rs` lives), `sea-orm`,
or none; where migrations live and whether they are embedded in the binary; how authentication is
attached — a layer on the router, an extractor in the handler signature, or both, which are
different mechanisms and a route can miss either; the async runtime; and whether a separate frontend
exists, and if so whether its types are generated from the Rust ones (`ts-rs`, `specta`,
`typeshare`, or an OpenAPI document from `utoipa` or `aide`).

## Versions

Record the **exact locked version of each crate** the changed code uses from the framework layer
(`tokio`, and on a backend the server framework, `tower`, `sqlx` or `diesel`), read from
`Cargo.lock`'s `[[package]]` entries; plus the **toolchain version**: the `channel` in
`rust-toolchain.toml` when it names a release, otherwise the manifest's `rust-version`, otherwise
none. There is no series, and two traps are Cargo's own: `Cargo.lock` can hold the same crate at two
versions, and a `stable` channel names no version at all. `references/rust-docs.md` § *Pinning* says
what to do with each — in both cases the answer can be *no link*.

## The frontend

**Rust in general has no frontend to find** — a library's boundary is its public API, which
`references/rust.md` covers — so skip `SKILL.md` step 2's client seam. A Rust backend may have one,
and `references/rust-backend.md` § *When the client is a separate app* says how much of that seam
applies.
