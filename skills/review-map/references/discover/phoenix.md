# Discovering a Phoenix project

Read at `SKILL.md` step 2, once, right after the stack is detected — this file and no other stack's.
It says what to find out about the repository before any tracing, and which versions the
documentation links will be pinned to. The lens, `references/phoenix-liveview.md`, is still read at
step 5.

## The application

Locate the Mix project by finding `mix.exs`, and read the OTP app name from it — that is what
`lib/<app>` (the domain) and `lib/<app>_web` (the web layer) are named after, and the split is where
the context boundary lives. Detect, don't assume: the `Repo` module and its adapter; **whether this
is a LiveView app, a JSON API, or both** (`live "…"` in the router versus `json` responses,
`@derive {Jason.Encoder, …}` or a `…JSON` render module); how authentication is attached (`on_mount`
inside a `live_session`, or a plug in a `pipe_through` pipeline) — the two are different mechanisms
and a route can miss either; whether Oban, Broadway or bare `Task` does background work; whether
`assets/` holds JS hooks; and whether a separate frontend application exists at all.

## Versions

Record the **exact locked version of each package** from `mix.lock` (`phoenix`, `phoenix_live_view`,
`ecto`, `ecto_sql`, `plug`, `oban`), plus the Elixir version from `.tool-versions` or `mix.exs`.
There is **no series**: hexdocs serves exact versions, each package pins independently, and a page
carrying several different version segments is correct rather than broken. The catalogue carries a
few packages beyond that list; if step 7 asks for one of them, `grep` its line out of `mix.lock`
then — opening the catalogue here to find out which names to look for is the read this step is
trying not to do.

## The frontend

If the stack is Phoenix LiveView with no separate client application, the frontend is the `.heex`
templates and whatever sits in `assets/` — there is no second application and no generated type to
reconcile, so skip `SKILL.md` step 2's client seam and let the lens file's § *LiveView* carry this
one. A LiveView app's boundary is the `phx-*` attribute and the callback that answers it, not a JSON
contract.
