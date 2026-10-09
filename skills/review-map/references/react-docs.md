# React and Next.js documentation catalogue

The URLs the page is allowed to cite for a React or a Next.js application. **A doc link that is not in
this file does not go on the page** — not a guessed anchor, not an "obvious" reference path, not a URL
you are fairly sure of. The run cannot check a URL: there is no fetch step in the procedure, and the
sandboxes this skill commonly runs in block egress to these hosts outright. So a link is either
something a human opened once and wrote down here, or it is a 404 the reader discovers on your behalf
— and one dead link costs the same trust as one invented npm script.

`references/report-format.md` § *Framework anchors* owns what a doc link is *for*, when a claim earns
one, and the budget. This file is only the lookup: concept in, URL out.

**Read § *Version* before using this file.** It is not yet verified, and until it is, the answer this
file returns for every concept is *no link*.

## Version

**Not yet verified. No row in this file has been opened.**

Until a dated verification line appears in this section, **emit no link from this catalogue.** Explain
the mechanism in prose, cite the repo line, and propose a probe from `references/react.md` § *Runtime
probes* or `references/nextjs.md` § *Runtime probes*.

**That also costs the primer callout, which is easy to miss.** An `aside.primer` is what a doc link
escalates into, so it cannot exist without one — `report-format.md` § *Mentor mode* and
`evals/checks/rails-anchors.rb` § 8 both say so. While this file is closed, `--mentor` on a React or a
Next.js project therefore produces **no primer at all**, not merely no inline links, and the flag is
worth saying so about in chat rather than on the page. When it opens, the callout's frame is the open
question `report-format.md` § *Mentor mode* records for every new stack: a variant class, never a
colour a run types.

This is the fail-closed rule of `rails-docs.md` § *Pinning* applied to a whole file rather than to a
single row, and for the same reason `elixir-docs.md` is closed: every row below was written from
knowledge of the two sites' naming schemes, which is how `active_record_nested_attributes.html` — a
plausible URL constructed once, admitted, and never a page in any series — got into the Rails file.
`rust-docs.md` shipped closed the same way, and the sweep that opened it found one defect of each kind
that habit produces. Expect the same here.

**The sweep has one question to settle before any row, and it decides § *Pinning*.** Both hosts
publish their *current* major unversioned and archive older ones; whether each also answers a
versioned address **for the current major** is not something this file knows. § *Pinning* writes the
form the page needs — a version in every URL, for the reason every catalogue pins — and if the sweep
finds the current major unaddressable on a host, the answer for that host's current major is *no
link*, and this section and `evals/checks/rails-anchors.rb`'s React arm change together in the commit
that records it.

What lifts it:

```sh
evals/verify-catalogue.sh --catalogue references/react-docs.md
```

A clean run prints a dated line; that line replaces this section's first paragraph, and the links go
live in the same commit. A run with failures is the more likely outcome and is the point of running it.

**The probe is unaffected, and it is the better anchor anyway.** A probe interrogates the installed
code instead of describing it, so it cannot be out of date and it cannot 404 — and in this stack,
where the defaults moved more inside the supported range than anywhere else, that matters more than
it does in Rails. While this catalogue is closed it is the whole of what a React or Next.js run
offers. That is a narrower page, not a broken one.

**The floor these rows are written against**, and below which no link is emitted even once the file
opens: `react` 18, `next` 14. Below either, explain in prose and propose a probe.

## Shapes

Two hosts, and only these two. **Every stored path keeps its host**, as `rust-docs.md`'s do, because
two hosts share no namespace and the host is the only thing that says which documentation a path
belongs to:

```
react.dev/reference/<package>/<api>[#<anchor>]
react.dev/learn/<page>[#<anchor>]
nextjs.org/docs/<router>/api-reference/<kind>/<name>[#<anchor>]
nextjs.org/docs/<router>/<guide path>[#<anchor>]
```

These are the **paths this file stores**, and no row below carries a version — § *Pinning* has the
emitted form.

**The router is part of a Next.js path and is the easiest thing to get wrong.** `docs/app/…` documents
the App Router and `docs/pages/…` the Pages Router; the same function name often has a page under
both, documenting different behaviour — `redirect` in a server action is not `redirect` in
`getServerSideProps`. A row stores one router. A path that is right about the API and wrong about the
router is a page that resolves and describes code this repository does not run, which is worse than
a 404, because nothing tells the reader. Step 2 recorded which router the changed files live under;
cite only rows under that router.

**React's own reference splits by package.** Hooks and components from `react` are under
`reference/react/`, the DOM ones under `reference/react-dom/` (and `react-dom/client`,
`react-dom/server`), and the server-component directives under `reference/rsc/`. A hook at the wrong
package path is a 404 that reads as correct.

**A bad anchor is survivable and a bad path is not.** A fragment a page does not have is ignored by
every browser; a wrong path is a 404. That asymmetry is why this file prefers a **page-level URL it is
certain of** to a deeper link it is not, and why most rows below are page-level on purpose.

**Never a `github.com/.../blob|pull|compare/` URL**, here as anywhere: `evals/checks/page-invariants.rb`
§ 5 fails a page that emits one when the head commit is unpushed. This catalogue offers neither React's
nor Next.js's repository, so the question does not arise from these rows.

## Pinning

**Every URL in this file is a path, not a link. The run pins it to the app's own major version before
it reaches the page.**

```
https://<major>.react.dev/<rest of the stored path>
https://nextjs.org/docs/<major>/<rest of the stored path after docs/>
```

`<major>` is the **major version of the package the row documents**, read from the lock file in step 2
— `react` at `18.3.1` gives `https://18.react.dev/reference/react/useEffect`, `next` at `15.5.4` gives
`https://nextjs.org/docs/15/app/api-reference/functions/cookies`. A `react.dev` row pins to `react`, a
`nextjs.org` row to `next`, so **a correct Next.js page carries two different version segments** —
Next.js 15 and React 19 is the ordinary combination — and that is not a defect, for the reason
`elixir-docs.md` § *Pinning* gives about per-package pins. `evals/checks/rails-anchors.rb` requires
every link on either host to carry a major, and does not require them to agree.

**A major, not an exact version, and that is the hosts' choice rather than ours.** Neither site
publishes documentation per minor or per patch: each serves one page per API per major. That makes
this the coarsest pin any catalogue here carries, and it is why § *What the marks mean* carries more
`‡ probe` rows than any other catalogue — a behaviour that moved inside a major (Next.js changed its
caching defaults in minors more than once) cannot be told apart by the link, so the sentence has to
stop asserting and route to a probe.

**This is unconditional.** Every row, not only the ones whose behaviour moved: a pinned page names its
major, so the reader can hold the link against their own `package.json` at a glance. The unversioned
`https://react.dev/…` or `https://nextjs.org/docs/…` silently means *the newest major*, which is how a
page ends up explaining Next.js 16's `proxy` to a Next.js 14 app in a tone of complete confidence.

**Below the floor in § *Version*, or where a row has no page for that major at all, emit no link.**
The React Server Components pages and the React 19 hooks have no page under React 18, and the
`‡ since X` mark says which rows those are.

## What the marks mean

Two marks, and both are about the **sentence**, never the link. They say what the page is allowed to
claim. Identical in meaning to `rails-docs.md` § *What the marks mean*, so that file's reasoning for
keeping them distinct applies here unchanged.

| Mark | Means | The run must |
|---|---|---|
| *(none)* | The behaviour has not changed across the supported range | State it, link it, move on |
| `‡ probe` | The behaviour **changed** inside the range, so no single sentence is true of every app | Not assert it. Ask the app: propose a probe, and name the setting or version that decides it |
| `‡ since X` | Surface was added in X; the default this row describes still holds | State it *as the default*, and name X where a reader could meet the new surface. Below X the row has no page, so no link |

**The marks below were reasoned from knowledge of the libraries, not from a CHANGELOG audit.** The
Rails file's marks came from reading the framework's CHANGELOGs across three series, and that audit
found the previous single mark was catching about a quarter of what it existed to catch. No such audit
has been done for React or Next.js. Next.js is where it is most owed: its caching defaults, its
request APIs and its middleware all moved between 14 and 16, and some moved in a minor. Until then,
prefer the probe wherever a sentence would have to be version-specific.

---

## Rendering, state and identity · `react.dev`

| Concept | Path |
|---|---|
| State belongs to a position in the tree, and a `key` resets it | `react.dev/learn/preserving-and-resetting-state` |
| Keys in a list, and why an index is the wrong one | `react.dev/learn/rendering-lists#keeping-list-items-in-order-with-key` |
| Updates are batched and read a snapshot | `react.dev/learn/queueing-a-series-of-state-updates` |
| `useState`, its updater form and its initializer | `react.dev/reference/react/useState` |
| Render must be pure | `react.dev/reference/rules/components-and-hooks-must-be-pure` |
| The rules of hooks | `react.dev/reference/rules/rules-of-hooks` |
| `useReducer` | `react.dev/reference/react/useReducer` |
| `useContext`, and why a new value re-renders every consumer | `react.dev/reference/react/useContext` |

## Effects · `react.dev`

| Concept | Path |
|---|---|
| `useEffect`, its dependencies and its cleanup | `react.dev/reference/react/useEffect` |
| An effect that only derives data does not need to be one | `react.dev/learn/you-might-not-need-an-effect` |
| Every reactive value an effect reads is a dependency | `react.dev/learn/lifecycle-of-reactive-effects` |
| Fetching in an effect, and the race a missing ignore flag allows | `react.dev/learn/synchronizing-with-effects#fetching-data` |
| `useLayoutEffect` blocks paint | `react.dev/reference/react/useLayoutEffect` |
| Strict Mode runs effects twice in development | `react.dev/reference/react/StrictMode` |
| `useSyncExternalStore` for a store outside React | `react.dev/reference/react/useSyncExternalStore` |

## Memoisation and refs · `react.dev`

| Concept | Path |
|---|---|
| `memo` compares props by identity | `react.dev/reference/react/memo` |
| `useMemo` | `react.dev/reference/react/useMemo` |
| `useCallback` | `react.dev/reference/react/useCallback` |
| `useRef`, and that changing it does not re-render | `react.dev/reference/react/useRef` |
| `forwardRef`, and `ref` as a prop ‡ probe | `react.dev/reference/react/forwardRef` |
| The React Compiler memoises automatically ‡ probe | `react.dev/learn/react-compiler` |

## Async rendering and errors · `react.dev`

| Concept | Path |
|---|---|
| `Suspense` and what renders while pending | `react.dev/reference/react/Suspense` |
| `useTransition` and non-blocking updates | `react.dev/reference/react/useTransition` |
| An error boundary catches render errors, not event-handler errors | `react.dev/reference/react/Component#catching-rendering-errors-with-an-error-boundary` |
| `use` reads a promise or a context ‡ since 19 | `react.dev/reference/react/use` |
| `useActionState` ‡ since 19 | `react.dev/reference/react/useActionState` |
| `useOptimistic` ‡ since 19 | `react.dev/reference/react/useOptimistic` |

## The DOM · `react.dev`

| Concept | Path |
|---|---|
| `dangerouslySetInnerHTML` is the one place React stops escaping | `react.dev/reference/react-dom/components/common#dangerously-setting-the-inner-html` |
| Controlled and uncontrolled inputs | `react.dev/reference/react-dom/components/input#controlling-an-input-with-a-state-variable` |
| `<form>` and its `action` ‡ since 19 | `react.dev/reference/react-dom/components/form` |
| Hydration, and what a mismatch does | `react.dev/reference/react-dom/client/hydrateRoot` |
| `useId` for ids that match on server and client | `react.dev/reference/react/useId` |

## Server components and directives · `react.dev`

| Concept | Path |
|---|---|
| Server components ‡ since 19 | `react.dev/reference/rsc/server-components` |
| `"use client"` marks a boundary, and everything it imports crosses it ‡ since 19 | `react.dev/reference/rsc/use-client` |
| `"use server"` makes a function callable from the client ‡ since 19 | `react.dev/reference/rsc/use-server` |
| Server functions, and that their arguments are untrusted ‡ since 19 | `react.dev/reference/rsc/server-functions` |

## Server and client components · `nextjs.org`

| Concept | Path |
|---|---|
| The `"use client"` directive in Next.js | `nextjs.org/docs/app/api-reference/directives/use-client` |
| The `"use server"` directive in Next.js | `nextjs.org/docs/app/api-reference/directives/use-server` |
| Environment variables, and `NEXT_PUBLIC_` inlined at build ‡ probe | `nextjs.org/docs/app/guides/environment-variables` |

## Request APIs · `nextjs.org`

| Concept | Path |
|---|---|
| `cookies()` — reading it makes the route dynamic ‡ probe | `nextjs.org/docs/app/api-reference/functions/cookies` |
| `headers()` ‡ probe | `nextjs.org/docs/app/api-reference/functions/headers` |
| `redirect()` works by throwing | `nextjs.org/docs/app/api-reference/functions/redirect` |
| `notFound()` works by throwing | `nextjs.org/docs/app/api-reference/functions/not-found` |
| `after()` runs work once the response is sent ‡ since 15 | `nextjs.org/docs/app/api-reference/functions/after` |

## Caching and revalidation · `nextjs.org`

| Concept | Path |
|---|---|
| `fetch` caching options in a server component ‡ probe | `nextjs.org/docs/app/api-reference/functions/fetch` |
| `revalidatePath` | `nextjs.org/docs/app/api-reference/functions/revalidatePath` |
| `revalidateTag` ‡ probe | `nextjs.org/docs/app/api-reference/functions/revalidateTag` |
| `unstable_cache` ‡ probe | `nextjs.org/docs/app/api-reference/functions/unstable_cache` |
| `"use cache"` ‡ probe | `nextjs.org/docs/app/api-reference/directives/use-cache` |
| Route segment config — `dynamic`, `revalidate`, `runtime` ‡ probe | `nextjs.org/docs/app/api-reference/file-conventions/route-segment-config` |
| `generateStaticParams` and `dynamicParams` | `nextjs.org/docs/app/api-reference/functions/generate-static-params` |

## Files and routing · `nextjs.org`

| Concept | Path |
|---|---|
| `page`, and its `params` and `searchParams` ‡ probe | `nextjs.org/docs/app/api-reference/file-conventions/page` |
| `layout` persists across navigation | `nextjs.org/docs/app/api-reference/file-conventions/layout` |
| `loading` wraps its segment in a Suspense boundary | `nextjs.org/docs/app/api-reference/file-conventions/loading` |
| `error` must be a client component, and misses its own layout | `nextjs.org/docs/app/api-reference/file-conventions/error` |
| Route handlers, and which are cached ‡ probe | `nextjs.org/docs/app/api-reference/file-conventions/route` |
| Middleware, its `matcher` and its runtime ‡ probe | `nextjs.org/docs/app/api-reference/file-conventions/middleware` |
| `Link`, and prefetching | `nextjs.org/docs/app/api-reference/components/link` |
| `Image` and `remotePatterns` | `nextjs.org/docs/app/api-reference/components/image` |

## Pages Router · `nextjs.org`

| Concept | Path |
|---|---|
| `getServerSideProps` runs per request | `nextjs.org/docs/pages/api-reference/functions/get-server-side-props` |
| `getStaticProps` and `revalidate` | `nextjs.org/docs/pages/api-reference/functions/get-static-props` |
| API routes, and that the method check is the handler's job | `nextjs.org/docs/pages/building-your-application/routing/api-routes` |

---

`‡ probe` and `‡ since X` are about the sentence, never the link. § *What the marks mean*.

Every path above is stored **without** a version and **with** its host. § *Pinning* has the emitted
form, and § *Version* is why none of them is emitted yet.

## Adding a row

Open the URL — not "recall" it, not derive it from the naming scheme — at the major the row will be
pinned to, confirm the page documents the concept in the row, and confirm the fragment scrolls
somewhere sensible. For a `nextjs.org` row, check the **router** as carefully as the name: the same
function under `docs/pages/` and `docs/app/` is two pages about two behaviours, and both resolve.

Then run `evals/verify-catalogue.sh --catalogue references/react-docs.md`, which is the mechanical
half of the same sentence: it will tell you the page resolves and the fragment exists, at the major it
is pinned to. It cannot tell you the page documents the concept in the row — that is why the paragraph
above comes first and is not replaceable by the script.

A concept nobody has verified a URL for is still usable: explain it in prose, cite the repo line it
applies to, and propose a probe. That is the normal case, not a degraded one — and while § *Version*
holds this file closed, it is the **only** case.
