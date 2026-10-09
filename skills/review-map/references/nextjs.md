# Next.js lenses

The second layer for a React application built on Next.js — the App Router, the Pages Router, or both
in one app — whether it is a frontend for an API somewhere else or the whole application with its own
route handlers, server actions and database. **Read `references/react.md` first; this file is what
that one does not cover.** Components, state, keys, effects, memoisation, data-fetching caches,
client routing and the client tests are there and are not restated here — a Next.js app is a React
tree, and a second copy of those sections would be the duplication `report-format.md` § *One
canonical home* exists to prevent. What this file adds is the part a framework with a server has and
a single-page app does not: code that runs on the server, a boundary between server and client inside
one file tree, a cache with several layers, and endpoints that have no route file.

**`references/rails-nextjs.md` § *Next.js* is the short form of this file**, written for a Next.js
client in front of a Rails API, and it stays where it is because a Rails run reads it there. When
Next.js *is* the stack, read that section too — its seven boundary bullets are the summary, and the
sections below are the depth behind each. Nothing here is a second copy of a bullet there.

Where a lens turns on a framework behaviour the reader might reasonably not know, the canonical URL
for it is in `references/react-docs.md`, and `report-format.md` § *Framework anchors* says when a
claim has earned a link. Do not construct one from memory. **Read that file's § *Version* first**:
while the catalogue is unverified it yields no links at all, and the anchor a Next.js run actually
gets is the probe.

**The version and the router decide what half of this file means, so read them before anything
else.** Step 2 recorded the locked `next` version and which router the changed files live under —
`app/` (the App Router), `pages/` (the Pages Router), or both, each possibly under `src/`. Next.js
changed its defaults inside the supported range more than any other framework this skill covers:
`fetch` stopped caching by default in 15, request APIs such as `cookies()`, `headers()`, `params` and
`searchParams` became asynchronous in 15, `middleware` was renamed `proxy` in 16, and the caching model
gained `"use cache"` beside the older `unstable_cache` and route segment options. **A sentence about
caching or request APIs that does not name the version is a sentence that is wrong for some app**, so
those claims route to a probe or to the setting that decides them, never to an assertion.

**Two seams carry most of the findings, and neither has a compiler across it.** The first is the
**server/client boundary**: what crosses from a server component into a client one, and what a
`"use client"` file drags into the browser bundle. The second is the **cache**: what a page was
rendered with, how long it is reused, and whether the mutation that changed its data tells it so.
Both fail silently — a secret in a bundle, a stale page, another user's data served from a shared
cache — and both are invisible in the diff of the line that caused them.

**Apply these as lenses while reading, never as a checklist in the output.** The page reports what
was actually found, with `file:line`. It never says "we checked every action for authorization" as
reassurance — an absent finding is reported by absence, not by a green tick.

---

## Server and client components

- **`"use client"` marks a boundary, not a component.** Everything the file imports becomes client
  code too, so adding the directive to a shared module pulls its whole import subtree into the
  browser bundle; removing it from a component that uses state or an effect is a build error, but
  removing it from one whose only client behaviour was an event handler passed down is not.
- **Whatever crosses the boundary is serialised.** Props a server component passes to a client
  component must be serialisable: a `Date` becomes a string in some versions and throws in others, a
  class instance loses its methods, a function is refused unless it is a server action. **And it is
  sent to the browser** — a server component that passes a whole user record to a client component
  has published every field of it, including the ones the client component never renders.
- **A server-only module imported from client code** is the leak this boundary exists to prevent.
  `import "server-only"` at the top of a module makes the leak a build error; a module that reads a
  secret or the database without it relies on nobody importing it from the wrong side. Search which
  modules the diff's new client components import, transitively.
- **Environment variables are split by prefix.** `NEXT_PUBLIC_*` is inlined into the client bundle at
  **build** time — public, permanent, and fixed until the next build, so changing it in a deployment
  without rebuilding changes nothing. Every other variable is server-only and reads as `undefined` in
  client code, which is a silent `undefined` rather than an error.
- **Context, state and effects exist only on the client.** A provider must be a client component, so
  wrapping the root layout in one makes a client boundary at the top of the tree; the server
  components below it are still server components, passed through as `children`.
- **Hydration mismatch is the boundary failing at runtime.** A server render and the first client
  render that disagree — a date formatted in the server's time zone, `typeof window` branching, a
  random id — warn in development and patch the DOM, or throw, in production. `suppressHydrationWarning`
  added in the diff is the author silencing one.

## Server actions and route handlers

- **A server action is a public POST endpoint with no route file.** Any function in a `"use server"`
  module, or marked `"use server"` inline, can be called by anyone who can reach the app with
  arguments of their choosing — the form it was written for is not the only caller. **Authorization
  inside every action** is the question, because there is no controller chain or layout to inherit it
  from: a layout that checks the session does not run before an action invoked from its page.
- **Arguments are untrusted input** even when TypeScript types them: the type is erased at the
  boundary, so an action that takes `id: string` receives whatever the caller sends. Validation (Zod or
  similar) at the top of the action is the server-side half of the form's schema.
- **Values captured by an inline action's closure are sent to the client** — encrypted, but sent — and
  come back with every call. A closure over a secret, or over a value the server assumed it alone
  decided, is a question.
- **A mutation must invalidate what it changed.** An action or a route handler that writes data and
  calls neither `revalidatePath` nor `revalidateTag` (nor `refresh` or `updateTag` where the version
  has them) leaves every cached page showing the old data — and the bug is invisible in the action's
  own diff, because the stale page is somewhere else. Read which paths and tags the action
  revalidates against which pages read the data it wrote.
- **`redirect()` and `notFound()` work by throwing.** Called inside a `try` whose `catch` swallows
  everything, they are caught and the redirect never happens. A `try/catch` added around code that
  redirects is the place to look.
- **Route handlers (`route.ts`) are a second backend.** A `GET` handler's caching default changed
  across versions, so whether one is cached depends on the version and on what it reads; a handler
  that duplicates logic an API elsewhere owns raises which one is authoritative. Each exported method
  is its own endpoint, and one added beside an authenticated sibling does not inherit its check.
- **Pages Router API routes (`pages/api/*`)** are the same lens for the older router: each file is an
  endpoint, every method arrives at one function, and the method check is the handler's own job.

## Rendering mode and caching

- **Whether a route is static or dynamic is decided by what it reads, not by what it says.** In the
  App Router a page that reads `cookies()`, `headers()`, `searchParams`, an uncached `fetch` or
  `connection()` is rendered per request; one that reads none of them may be rendered once at build
  and served to everyone. **A diff that adds a `cookies()` read deep in a shared component flips every
  route that renders it to dynamic** — a performance change — and a diff that removes the last one
  flips them back, which is a correctness change if the page shows per-user data.
- **Per-user data in a cached response is the sharpest finding in this stack.** A page, a `fetch`, an
  `unstable_cache` or a `"use cache"` function whose result depends on the user but whose cache key
  does not include them serves one user's data to the next. Read every new cache boundary for what it
  closes over.
- **Route segment config overrides the inference.** `export const dynamic`, `revalidate`, `fetchCache`
  and `runtime` in a page or layout apply to the whole segment below it, and a value set in a layout
  reaches pages the diff did not touch. `dynamic = "force-static"` makes `cookies()` return empty
  rather than fail.
- **`fetch` caching is version-dependent and per call.** Whether a bare `fetch` in a server component
  is cached, and for how long, moved between versions; `cache`, `next.revalidate` and `next.tags`
  options on the call decide it explicitly. A tag a mutation revalidates and no `fetch` declares is a
  revalidation that does nothing.
- **`generateStaticParams` decides which pages exist at build.** With `dynamicParams = false` an id not
  returned there is a 404; with it true, a new id renders on demand. A change to what it returns, or
  to that flag, changes which URLs work.
- **The client router has its own cache.** Navigations reuse previously rendered segments for a time
  that also moved between versions, so a page can show stale data after a mutation even when the
  server cache was revalidated — `router.refresh()` is the client-side half.

## Routing and the file tree

- **The file tree is the router, so a renamed folder is a renamed URL.** Every `<Link href>`,
  `router.push`, `redirect()`, `revalidatePath` and external link to the old path breaks, and none of
  them is in the folder the diff renamed. Route groups `(name)` and private folders `_name` change the
  tree without changing the URL; a dynamic segment `[id]`, a catch-all `[...slug]` and an optional
  catch-all `[[...slug]]` each match differently.
- **A layout persists across navigation and does not re-render.** State in a layout survives moving
  between its pages, and a layout that reads `searchParams` cannot — it is not passed them. Data a
  layout fetched is not refetched when the page below it changes; `template.tsx` is the file that
  remounts per navigation.
- **`loading.tsx`, `error.tsx` and `not-found.tsx` are boundaries by position.** Each wraps the
  segment it sits in and everything below; one added or removed changes what renders while every page
  under it is pending or failing. `error.tsx` must be a client component and does not catch errors
  thrown in the layout beside it — `global-error.tsx` does.
- **Parallel (`@slot`) and intercepting (`(.)photo`) routes** render a different component for the
  same URL depending on how the user arrived. A change to one is tested by navigating *and* by loading
  the URL directly, which are two different renders.
- **Redirects and rewrites in `next.config.*`, and in `proxy`/`middleware`, run before the route
  file.** A path the config rewrites never reaches the page the diff changed.

## Middleware, or proxy

- **It runs before every request its `matcher` selects, and no other.** A new route outside the
  matcher skips it — which is the finding when the middleware is where the app checks the session.
  Read the `config.matcher` against the routes the diff added.
- **Middleware is a redirect, not an authorization layer.** A check there decides where an anonymous
  user lands; the data a page or an action reads has to be authorized again where it is read, because
  an action is called directly, a route handler is fetched directly, and middleware has been bypassed
  before (CVE-2025-29927 bypassed it with one header on unpatched versions). An auth change that lives
  only in middleware is the question.
- **Its runtime is limited.** It ran only on the Edge runtime before Node.js middleware landed, so
  what it can import — a database client, `fs`, most SDKs — depends on the version and the configured
  runtime. Renamed `proxy` in 16; a file still called `middleware.ts` on 16 is the deprecated form.

## Configuration, images and the build

- **`next.config.*` changes reach every route.** `images.remotePatterns` decides which hosts the image
  optimiser will fetch from — widened to `**`, it is an open proxy; `headers()` sets security headers
  for the matched paths; `output: "standalone"` or `"export"` changes what is deployable and which
  features exist at all (`"export"` has no server, so no actions, no route handlers, no middleware).
- **`experimental` flags are behaviour.** A flag turned on in the config — the React Compiler, partial
  prerendering, `cacheComponents`, `dynamicIO` — changes rendering for every route, and its name moves
  between versions.
- **The deployment platform is part of the runtime.** Serverless functions have timeouts, a cold start
  and no shared memory between requests: a module-level cache or connection that works under
  `next start` is per-invocation on a serverless host, and per-region on an edge one.

## When the app has a database

A Next.js app that is its own backend usually reaches a database through Prisma or Drizzle, and those
are the same seams any backend has: a migration on one side, every query that assumed the old schema
on the other.

- **The schema file and the migration have to agree.** `prisma/schema.prisma` and the generated SQL
  under `prisma/migrations/`, or a Drizzle schema module and the files `drizzle-kit` generated: a
  schema change with no migration ships a client that expects a column the database does not have,
  and a hand-edited migration that diverges from the schema is drift the next `migrate dev` will
  notice and production will not.
- **A destructive migration** — a dropped column, a narrowed type, a `NOT NULL` with no default on a
  populated table — and whether the deployed code that still reads the old shape is running while it
  applies.
- **Connections in a serverless runtime** are opened per invocation; a new direct client without the
  pooler the rest of the app uses exhausts the database under load.
- **A query moved from a route handler into a server component** now runs during render, possibly at
  build, possibly cached — which is § *Rendering mode and caching* again, and the reason that section
  comes first.

## Coding decisions, against this codebase's own answers

`references/react.md` § *Coding decisions* owns the rule, the register and why there is no stack
convention list yet — one per departure, *is it deliberate that X, given Y?* What a Next.js app adds
is shapes to look for:

- **A server action where the codebase uses route handlers for mutations, or the reverse.**
- **A client-side fetch in a codebase that fetches in server components**, or a new API route that
  exists only so a client component can call it, where siblings pass the data down as props.
- **A page under the Pages Router in an app that is migrating to the App Router**, or the reverse —
  which direction the codebase is moving is the `Y`, and its newest sibling pages show it.
- **Authorization checked somewhere new** — in a component, in middleware alone, inline in one action
  — where the codebase has a data-access layer or a helper every sibling calls.
- **A second data layer** — a raw SQL client beside Prisma, a `fetch` to the app's own route handler
  from a server component where siblings call the function directly.

```sh
ls app src/app pages src/pages 2>/dev/null                      # which routers this app uses, and where
rg -l '^["\x27]use server["\x27]' -g '*.{ts,tsx,js,jsx}'          # where actions live
rg -l 'export (async )?function (GET|POST|PUT|PATCH|DELETE)' -g 'route.{ts,js}'   # where route handlers live
rg -n 'auth\(\)|getServerSession|currentUser\(|verifySession' -g '*.{ts,tsx}' | head   # how siblings check the session
```

## Tests

- **Server components and server actions are hard to unit test**, so most of what this file is about
  is covered — if at all — by end-to-end tests. Is there a Playwright or Cypress test that drives the
  action the diff changed, and does it run against a build (`next build && next start`) or against the
  development server, which caches differently?
- **Mocks of `next/navigation`, `next/headers` and `next/cache`** in unit tests replace exactly the
  behaviour this file says to look at. A test that mocks `revalidatePath` asserts that it was called,
  not that the page it should refresh reads the path it was called with.
- **A test that passes in development and a page that fails in production** is usually the cache:
  development renders dynamically and production does not.
- Everything in `references/react.md` § *Tests* applies too: mocked responses, queries by role,
  snapshots, stories.

---

## Runtime probes

`references/react.md` § *Runtime probes* owns the four rules — the project's package manager and never
an install, `--no-install` on every `npx`, say when a command runs the project's configuration and what
it writes, and no console — and they apply here unchanged. Next.js adds the one probe a single-page
app does not have, because its build decides things no file states.

**What each route rendered as**

```sh
npx --no-install next build                                     # runs the config, compiles every route; writes .next/
```

The route table it prints marks each route static, dynamic or prerendered with its revalidation
time, which answers *did this change make the route dynamic, or make it cacheable* in one line —
the question § *Rendering mode and caching* says the diff cannot answer. **It fails the fresh-checkout
earning test more often than any other probe here**: it needs the environment variables the app reads
at build, and it may fetch from the APIs and the database a static page renders with. Say so in the
label, and prefer it only where the judgment is exactly that question.

**The installed Next.js and React, as Next.js sees them**

```sh
npx --no-install next info                                      # versions of next, react, react-dom and the platform; reads only
```

**Whether the schema and the migrations agree**

```sh
npx --no-install prisma migrate diff --from-migrations prisma/migrations --to-schema-datamodel prisma/schema.prisma --shadow-database-url "$SHADOW_DATABASE_URL"
npx --no-install prisma migrate status                          # needs DATABASE_URL; which migrations this database has run
npx --no-install drizzle-kit check                              # Drizzle's own consistency check over its migrations folder
```

The first needs a disposable shadow database and prints the SQL the schema implies that the
migrations do not contain; the label names that requirement. Never propose one against a production
`DATABASE_URL`, never `migrate dev` or `migrate reset` — both write — and never `db push`.

**Which tests exercise a route, without running them** — `npx --no-install playwright test --list`
and the runners' list modes in `references/react.md` are the same question asked of this app.

## Search recipes for affected-but-unchanged code

Step 5 of the procedure lives or dies on these, and `references/react.md` § *Search recipes* has the
component-level ones — renders, hooks, contexts, query keys, client routes. Run those too. Run each
search, then **record it** — an empty result is a finding only if the reader can see what was looked
for.

**A changed or renamed route**

```sh
rg -n "['\"\`]/projects" -g '*.{ts,tsx,js,jsx}'                 # every Link, push, redirect and revalidatePath to it
rg -n "/projects" next.config.* middleware.* proxy.* src/middleware.* src/proxy.* 2>/dev/null   # rewrites, redirects, matchers
```

**A changed server action**

```sh
rg -n '\barchiveProject\b' -g '*.{ts,tsx,js,jsx}'               # every form action=, every call, every import
rg -n 'revalidatePath|revalidateTag|updateTag|refresh\(' <the action's file>   # what it invalidates
```

Read the second against the pages that render the data the action writes: a page that reads it and is
not on that list is the stale page.

**A changed cache tag or cached function**

```sh
rg -n "tags: *\[[^]]*['\"]projects" -g '*.{ts,tsx,js,jsx}'      # every fetch that declares the tag
rg -n "revalidateTag\(['\"]projects|updateTag\(['\"]projects" -g '*.{ts,tsx,js,jsx}'   # every mutation that revalidates it
rg -n 'unstable_cache|["\x27]use cache["\x27]|cacheTag\(|cacheLife\(' -g '*.{ts,tsx,js,jsx}'
```

A tag declared and never revalidated, or revalidated and never declared, is the finding. This is the
search a `figure.converge` is earned by when every writer of the data has to revalidate the same tag —
each action is one of its paths, and the one that forgets is the unchanged path it exists to show.
`report-format.md` § *Topology figures* owns the rest.

**A new request-time read in shared code**

```sh
rg -l 'cookies\(\)|headers\(\)|searchParams|connection\(\)' -g '*.{ts,tsx}'   # what already makes routes dynamic
rg -n '\bProjectHeader\b' -g 'app/**/{page,layout}.{ts,tsx}' -g 'src/app/**/{page,layout}.{ts,tsx}'   # which routes render the changed component
```

**A component that gained or lost `"use client"`**

```sh
rg -n "from ['\"](@/|\.\.?/).*ProjectCard['\"]" -g '*.{ts,tsx}'  # who imports it, server components among them
rg -l "server-only|process\.env\.[A-Z_]+|prisma|db\." <the files it imports>   # server-only code it would drag into the bundle
```

**Middleware coverage**

```sh
rg -n 'matcher' middleware.* proxy.* src/middleware.* src/proxy.* 2>/dev/null
ls app src/app 2>/dev/null                                     # the top-level segments the matcher has to cover
```

**A changed `NEXT_PUBLIC_` or server environment variable**

```sh
rg -n 'NEXT_PUBLIC_API_URL|DATABASE_URL' -g '!node_modules' -g '!.next'   # code, .env examples, CI and deploy config
```

**A changed Prisma model or column**

```sh
rg -n '\barchivedAt\b' -g '*.{ts,tsx}' -g '*.prisma' -g '*.sql'  # every query, select and migration that names it
rg -n 'prisma\.project\.' -g '*.{ts,tsx}'                       # every query on the model
rg -n '\$queryRaw|\$executeRaw|sql`' -g '*.{ts,tsx}'            # raw queries, which a rename reaches silently
```

Search the **old** name as well as the new one. The stale reader is the finding; the updated one is
already in the diff.
