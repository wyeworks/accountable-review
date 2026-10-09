# React lenses

What to look for in a React codebase of any kind, plus two sets of recipes for reaching past the diff:
the **runtime probes** that ask the toolchain what the code amounts to, and the **search recipes**
that find the code the diff did not touch. This is the knowledge a senior reviewer applies from memory
and that cannot be inferred from a diff — it is what makes the page a review map rather than a change
summary.

**This file is read by every React run, and it is the whole lens for one of the two React stacks.**
Step 2 tells them apart: an application whose changed package depends on `next` is a **Next.js app**,
and that run reads `references/nextjs.md` *after* this file, as a second layer on top of it.
Everything else — a Vite or Create React App single-page app, a component library, a design system, a
React Router or TanStack Router app, the React half of an Electron or React Native codebase — is
**React in general**, and this file is all of it. The split is the Rust one for the Rust reason: a
Next.js app is still a React tree, so everything below applies to it, and nothing in the Next.js file
is restated here.

Where a lens turns on a React behaviour the reader might reasonably not know, the canonical URL for it
is in `references/react-docs.md`, and `report-format.md` § *Framework anchors* says when a claim has
earned a link. Do not construct one from memory. **Read that file's § *Version* first**: while the
catalogue is unverified it yields no links at all, and the anchor a React run actually gets is the
probe.

**TypeScript is on the reviewer's side about shapes and silent about time.** A React diff that reached
review usually type-checks, so the missing prop and the misspelt field are already gone — where the
project uses TypeScript at all, which step 2 records, and where nothing at the boundary is `any`. What
is left is what no type expresses: **when** code runs (an effect's dependencies, a cleanup that never
happens, a render that runs twice), **which instance** a piece of state belongs to (a key, a component
moved in the tree), **whose identity** a memo compares (an object rebuilt every render), and every
consumer of a component, a hook or a context that sits outside the files the diff touched. Spend the
run there. A finding `tsc` would have produced is not a finding.

**Apply these as lenses while reading, never as a checklist in the output.** The page reports what
was actually found, with `file:line`. It never says "we checked every effect's dependencies" as
reassurance — an absent finding is reported by absence, not by a green tick.

---

## Components and their props

- **A component is an API, and its consumers are every file that renders it.** A renamed prop, a prop
  that became required, a default that changed, a callback whose arguments moved — each reaches every
  `<Component …>` in the codebase, and in a component library every consumer outside it. TypeScript
  catches a missing required prop; it does not catch a **default that changed meaning** (`size="md"`
  now renders differently), a prop that is still accepted and now ignored, or a callback that is now
  called at a different moment.
- **Spread props hide the contract.** `{...props}` or `{...rest}` forwarded to a DOM element or a child
  means a prop the parent stopped handling is still passed through — to an `<input>` as an unknown
  attribute, or to a child that interprets it. A new explicit prop with the same name as one that used
  to travel in `rest` silently stops forwarding it.
- **`children` and render props change the timing contract.** Switching from `children` to a function
  child, or from an element prop to a component prop (`icon={<Icon/>}` versus `icon={Icon}`), changes
  who renders it and with what props.
- **A component library's public surface is its exports**, not its files: `index.ts` barrels and the
  `exports` map in `package.json` decide what a consumer can import. A component moved between files
  is a refactor; one dropped from the barrel or the `exports` map is a breaking release, and the
  version in `package.json` says whether it was shipped as one.
- **`ref` is part of the API.** A component that used to forward a ref and no longer does breaks every
  consumer that focuses, measures or scrolls it — at runtime, as a `null`. In React 19 `ref` is an
  ordinary prop and `forwardRef` is unnecessary; which one the codebase is on decides what a removed
  `forwardRef` means.

## State, keys and identity

- **State belongs to a position in the tree, not to a component name.** A component rendered at the
  same place with the same type keeps its state across renders, even when its props say it is
  "another" item; one moved to a different place, wrapped in a new element, or given a new `key`
  starts empty. A diff that adds a wrapper `<div>` or a conditional around a stateful component resets
  its state on every toggle — form input lost, scroll position lost, an animation restarted — and
  nothing in the diff says so.
- **Keys are identity.** An array index as `key` on a list that can reorder, insert or delete attaches
  each item's state to the wrong row; a key built from a value that is not unique drops or duplicates
  rows; a key that changes on every render (`key={Math.random()}`, a new id per render) remounts the
  row every time. A key **changed deliberately** to reset a subtree is a legitimate technique — ask
  whether it was the intent.
- **State derived from props goes stale.** `useState(props.value)` reads the prop once, at mount; a
  parent that later passes a different value is ignored. Copying a prop into state, or computing in an
  effect what could be computed during render, is the usual source of a UI that shows the previous
  item's data after navigation.
- **Lifting state up, or pushing it down, changes who re-renders and who resets.** State moved into a
  parent survives the child unmounting; state moved into a child is lost when it unmounts. Read which
  component now owns it, and which of its siblings now re-render on every change.
- **Updates are batched and read a snapshot.** `setCount(count + 1)` twice in one handler adds one;
  the updater form `setCount(c => c + 1)` adds two. A handler that sets state and then reads it on the
  next line reads the old value. Code that reads state inside a timeout, an interval or a subscription
  callback reads the value from the render that created it.
- **Global state stores have their own identity rules.** A Redux selector, a Zustand selector or a
  Jotai atom that returns a new object or array on every call re-renders every subscriber on every
  store change; one that is memoised on the wrong inputs returns stale data. A store shape change
  reaches every selector that reads the old path.

## Effects and hooks

- **An effect's dependency array is a claim about what it reads.** A value used inside and missing
  from the array is read from the render that created the effect — a stale closure, the most common
  React bug that passes every type check. A `// eslint-disable-next-line react-hooks/exhaustive-deps`
  added in the diff is the place to look first: it is the author telling the linter to stop checking
  exactly this.
- **An object or function in the dependency array that is rebuilt every render makes the effect run
  every render.** With a `fetch` inside, that is a request per render; with a `setState` inside, it is
  an infinite loop the first time the state changes.
- **Cleanup is the half that is missing.** A subscription, a listener, an interval, a WebSocket or an
  `AbortController` opened in an effect and never closed leaks per mount; a fetch whose result is set
  into state with no cancellation or ignore flag lets a slow response for the previous id overwrite
  the fast one for the current id. Read the return value of every new effect.
- **Strict Mode mounts twice in development.** Effects run, clean up and run again, so an effect that
  is not idempotent — one that posts analytics, creates a resource, or appends to a list — misbehaves
  in development and is the author's evidence that something is wrong. Whether `<StrictMode>` wraps
  the tree is worth one search before a double-firing report is read as a bug.
- **An effect that only derives data is a render-time computation in the wrong place**, and it costs a
  second render with the stale value showing in between. An effect that responds to an event the user
  caused belongs in that event's handler.
- **The rules of hooks are a contract the runtime enforces by order.** A hook called conditionally,
  inside a loop, after an early `return`, or from a function that is not a component or a hook keeps
  working until the condition flips — then React reads the wrong state for every hook after it. The
  lint rule catches most; a hook wrapped in a helper whose name does not start with `use` escapes it.
- **A custom hook is shared code with many callers.** A changed return shape, a new required argument,
  or a hook that now subscribes, fetches or sets state on mount reaches every component that calls it
  — search the callers, not the file.
- **`useLayoutEffect` blocks paint; `useEffect` does not.** Moving work between them changes whether
  the user sees a flicker, and `useLayoutEffect` warns or no-ops during server rendering.

## Rendering, memoisation and context

- **`memo`, `useMemo` and `useCallback` compare by identity.** A memoised child receiving an inline
  object, array or arrow function re-renders every time anyway, so a `memo` added in the diff may do
  nothing. The inverse is the correctness case: a `useMemo` or `useCallback` with a dependency missing
  returns a stale value, which is the stale-closure bug in a different hook.
- **A context value re-renders every consumer when its identity changes.** A provider passing
  `value={{ user, setUser }}` builds a new object on every render of the provider, so every
  `useContext` below re-renders on every render of the provider. A new field added to a widely
  consumed context, or a context split in two, changes how much of the tree re-renders on every
  change.
- **A consumer outside its provider gets the default**, not an error, unless the hook throws on
  `undefined` deliberately. A component moved out from under a provider renders with the context's
  default value and looks fine in a story.
- **The React Compiler changes the answer to everything above.** Where it is enabled
  (`babel-plugin-react-compiler`, or `reactCompiler` in a Next.js config) components and hooks are
  memoised automatically, manual `useMemo` is mostly redundant, and code that mutates props or state
  in render becomes a correctness problem rather than a performance one. Step 2 records whether it is
  on; do not reason about memoisation without knowing.
- **Render must be pure.** Reading `Date.now()`, `Math.random()`, `window` or a mutable module-level
  variable during render gives a different output on the server and the client — a hydration mismatch
  where there is server rendering, and an unstable output under Strict Mode where there is not.

## Data fetching and server state

- **A cache key is a contract between the code that reads and the code that invalidates.** With React
  Query, SWR, RTK Query or Apollo, a mutation that does not invalidate every key whose data it changed
  leaves a stale screen; a key that omits a parameter the query depends on serves one user's or one
  filter's data for another. A renamed key without its invalidations is invisible in the diff of the
  query.
- **Optimistic updates assume a success shape.** An `onMutate` that writes a guessed result into the
  cache, and an `onError` that does not roll it back, shows data the server refused.
- **Loading, error and empty are three states**, and a diff that adds a fetch usually handles one of
  them. What renders while pending, what renders on a 500, and what renders on an empty list are each
  a question — "the error boundary catches it" is an answer, no answer is a finding.
- **Where the data comes from across the wire is the client half of a contract**, and it is not
  written twice: § *When there is an API across the wire* below says where it lives.

## Forms, events and the DOM

- **Controlled versus uncontrolled is one decision per input.** An input whose `value` goes from
  `undefined` to a string switches modes and React warns; one with `value` and no `onChange` is
  read-only. A form library (React Hook Form, Formik, TanStack Form) owns registration and default
  values, and a field renamed in the JSX but not in the schema or the default values submits nothing.
- **Validation lives in at least two places** — the client schema (Zod, Yup) and whatever receives the
  submission. A rule tightened on one side only is a form that submits and is rejected, or one that
  refuses input the server would take.
- **A `<button>` inside a `<form>` submits it** unless its `type` says otherwise, and `Enter` in an
  input submits too. A new button in an existing form is a second submit path.
- **Event handlers that call `preventDefault` or `stopPropagation`** change what every ancestor
  handler sees — a click that no longer closes a menu, a link that no longer navigates.
- **Accessibility is behaviour.** An interactive `div` with `onClick` and no role, no `tabIndex` and no
  key handler is unreachable by keyboard; an input whose `<label>` lost its `htmlFor` is unnamed to a
  screen reader; a focus trap with no escape strands the user. These are facts about who can use the
  change, not style, and they are found by reading the JSX the diff changed.

## Routing on the client

- **A route path is a string both the router and every link have to agree on.** A renamed path in
  React Router, TanStack Router or Wouter breaks every `<Link to="…">`, every `navigate("…")` and every
  URL built by concatenation — none of which the router's definition change touches, and only the
  typed routers catch at build time.
- **Route params and search params are strings, and optional.** A component that reads
  `useParams().id` as a number, or assumes a search param is present, fails on a hand-typed URL.
- **A loader or route-level guard is authorization only on the client.** Hiding a route stops a click,
  not a request: whatever the route renders must be authorized again by whatever serves its data.

## Security in the browser

- **`dangerouslySetInnerHTML` is the one place React stops escaping.** Every new use, and every new
  source of the string it receives, is a question: where does that HTML come from, and who sanitises it
  (DOMPurify or similar) before it arrives?
- **`href` and `src` are not escaped for scheme.** A user-controlled URL rendered into `<a href>` can be
  `javascript:`; React warns about it and still renders it in versions before the block lands.
- **Build-time environment variables are public.** `VITE_*`, `REACT_APP_*` and `NEXT_PUBLIC_*` values
  are inlined into the bundle every visitor downloads. A new one is a decision to publish its value,
  permanently.
- **Tokens in `localStorage` are readable by any script on the page**, which is the question an
  authentication change that moves where a token lives has to answer.

## Dependencies and the build

- **A React major moves the runtime under every component.** 17 → 18 changed batching and Strict
  Mode's double-mount; 18 → 19 removed legacy APIs, made `ref` a prop and changed how errors are
  reported. A lock file change that moves `react` or `react-dom` is a behaviour change for code the
  diff did not touch, and `react` and `react-dom` must move together.
- **Two copies of React in one bundle break hooks** ("invalid hook call"), and a dependency that pins
  its own `react` instead of declaring a peer dependency is how it happens. A library's
  `peerDependencies` range is its contract with its consumers.
- **A new dependency is code that runs in every visitor's browser** — its size, its licence, its
  maintenance, and whether it duplicates something the project already has.
- **Bundler configuration decides what ships.** A changed alias, a new `define`, a plugin added to
  `vite.config.*` or `webpack.config.*`, or a `browserslist` that dropped a target changes the output
  for files the diff never touched.
- **For a library, `package.json` is the release.** `exports`, `main`, `module`, `types` and
  `sideEffects` decide what a consumer resolves and what their bundler may drop; a field removed there
  breaks a consumer's import without changing a line of source.

## Coding decisions, against this codebase's own answers

Every other section here asks what the change *does*; this one asks how it was built, and its evidence
is always a component, a directory or a convention doc the diff never touched. `report-format.md`
§ *Coding decisions* owns when this becomes a checkpoint — one per departure, ranked last, never
displacing a behavioural judgment, and **never without a citation**.

**There is no stack-convention list for React yet, and that is the catalogue's state rather than an
oversight.** The second source `report-format.md` admits — a convention React itself documents, cited
through its catalogue row — exists only where the catalogue is open, and `react-docs.md` is closed
until a verification run opens it. Until then the `Y` is this repository's own, exactly as for
Phoenix: a line in a convention doc, else a sibling file or a populated directory.

- **A second way to fetch.** A `useEffect` with `fetch` in a codebase whose every other screen uses
  React Query or SWR, or a new query client beside the existing one. The cost is the cache, the retry
  policy and the invalidation everything else shares.
- **A second state store**, or global state where the codebase keeps it local: a Zustand store beside
  a Redux one, a context created for what one component's state would hold.
- **A second styling system** — inline styles, a CSS module, a styled component or a Tailwind class
  string in a codebase that settled on one of them.
- **A component placed outside the structure its siblings follow** — a feature component in a shared
  `components/` directory, a one-screen component in the design system, a hook defined inside a
  component file where the codebase has a `hooks/` directory.
- **A hand-rolled primitive beside the design system's** — a modal, a button or a form field built
  from scratch where the codebase has one, which also forfeits the accessibility work in the original.

**Ask; never answer**: *is it deliberate that X, given Y?* and never *X should be Y*. The reviewer
knows why their codebase is shaped as it is; you know only that this file is shaped differently from
its neighbours.

Finding the `Y` is one listing and three searches:

```sh
ls src src/components src/features src/hooks 2>/dev/null          # what kinds this codebase has a home for
rg -l 'useQuery|useSWR|createApi' -g '*.{ts,tsx,js,jsx}' | head   # which fetching layer siblings use
rg -l 'create\(|configureStore|createContext' -g '*.{ts,tsx,js,jsx}' | head   # where state lives
rg -n '"(styled-components|@emotion/react|tailwindcss|@vanilla-extract/css)"' package.json
```

## Tests

- **New behaviour with no test**, or a test that asserts the mock rather than the behaviour.
- **A mocked response that no longer matches the API** is the most common way a contract break passes
  CI on both sides. MSW handlers, `jest.mock`/`vi.mock` factories and fixture JSON are hand-written
  copies of the server's shape; when the shape moves, find them.
- **How a test finds an element is what it can see.** Queries by role and label (`getByRole`,
  `getByLabelText`) fail when accessibility breaks; queries by test id or class pass through it. A test
  rewritten from one to the other changed what it protects.
- **An updated snapshot is an approved behaviour change.** A `.snap` file or an inline snapshot in the
  diff *is* the new expected output, and accepting it is the moment a reviewer agrees the rendering
  changed. Read it as a behaviour diff, not as test churn.
- **`act` warnings and `waitFor` timeouts** are how async state that was never awaited shows up; a
  test that passes only with a longer timeout is waiting on something real.
- **Fake timers and real effects disagree.** A test using fake timers that never advances them, or one
  that depends on `Date.now()`, passes or fails by the clock.
- **Where the tests run decides what they cover**: jsdom or happy-dom do no layout, no real
  navigation and no CSS; Playwright or Cypress do. A layout or focus behaviour asserted only in jsdom
  was not asserted.
- **Stories are consumers too.** A Storybook story that renders a component with props the change
  removed still builds where the stories are untyped, and Chromatic or a visual snapshot of it is the
  only thing that would notice.
- Tests deleted, skipped (`it.skip`, `xit`, `test.todo`) or `.only`-ed as part of the change, which
  deserves an explicit note either way.

## When there is an API across the wire

The client half of a contract with a backend is **not written twice**. Two sections of
`references/rails-nextjs.md` are about the client and the wire rather than about Rails, and they
apply to any React client unchanged: § *The boundary: serializers to types* and § *TypeScript and
the client*. Read those for a React app that talks to an API, whoever serves it — and read the API's
own types, its OpenAPI document or its GraphQL schema as the far end of the same chain.

One question decides how much of that applies: **are the client's types generated from the server's?**
`openapi-typescript`, `orval`, GraphQL Code Generator, tRPC's inferred types and a shared workspace
package each make the boundary drift loudly at build time, *if* the generation runs in CI and its
output is checked. Hand-written response types drift silently, which is the case worth hunting.

---

## Runtime probes

A search finds code. A probe asks the toolchain what the code amounts to — and in a JavaScript
codebase that is a different and better question for anything assembled from parts the diff cannot
show together: the dependency versions the lock file actually resolved, whether one package now
exists at two versions, what the type checker or the hooks linter says about the changed files, which
tests the runner actually collects. `npm ls react` answers *how many copies of React are installed*,
which no file in the repository states.

So for a change to a dependency, a hook's dependencies, a type at the boundary or a test, **reach for a
probe before reaching for a paragraph.** Where a probe would settle the judgment a checkpoint asks
for, it goes inside that checkpoint, after its explanation; where it would only make a mechanism
legible, a clause in the explanation does the job and the probe is not earned.
`references/report-format.md` § *Framework anchors* owns that routing rule and the budget.

**These are proposed, never run.** This skill does not install, build or start the code under review,
which means the page shows the command and never its output. A fabricated dependency tree, or an
invented lint error presented as what the probe printed, is the console form of an invented command:
it reads as the most concrete thing on the page and it is the one part of it that is fiction.

Four rules make a probe safe to paste, and they matter more than the list below:

- **Use the project's package manager, and never one that installs.** Step 2 recorded it from the
  lock file — `package-lock.json` is npm, `pnpm-lock.yaml` pnpm, `yarn.lock` Yarn, `bun.lock` Bun —
  and a probe in another one's syntax fails or, worse, writes a second lock file. **`npx` without
  `--no-install` downloads and runs a package it does not find**, which turns a typo in a probe into
  remote code execution, so every `npx` carries it (`pnpm exec`, `yarn` and `bunx --no-install` are
  the equivalents). Never propose `npm install`, `npm update` or anything that rewrites the lock file.
- **A command that builds or loads configuration runs code.** `tsc` reads only types, but `vite
  build`, `next build`, `jest` and `vitest` execute the project's config files, plugins and test setup,
  including the ones this pull request changed. That is the same trust as running the branch at all —
  but the label says *runs the config*, so nobody pastes it believing it only reads. `npm ls` and `tsc
  --noEmit` execute nothing of the project's and are the first ones to reach for.
- **Say what it writes.** A production build writes `dist/`, `build/` or `.next/`; a test run may
  write snapshots when told to update them, and a probe never tells it to (`-u` is never in a probe).
- **There is no console.** A probe that would need to *call* the changed component or hook is a test,
  not a one-liner: name the existing test that exercises it, or propose running that test by name.
  Never propose writing a scratch file into the reviewer's checkout, and never one that prints the
  environment.

**Answering in a fresh checkout is the earning test**, and `references/report-format.md`
§ *Framework anchors* owns it. What is JavaScript-specific is that almost nothing answers in a checkout
with no `node_modules`: every probe below assumes the reviewer has installed the branch's dependencies
the way they normally do, and the label says so where it matters. `npm ls`, `tsc --noEmit` and a test
runner's *list* mode need no network, no database and no environment variables; reach for those first.

Substitute the project's real package and file names throughout — in a workspace, the package's
`name` from its own `package.json`, which is not always its directory.

**The dependency graph, as the lock file resolved it**

```sh
npm ls react react-dom                                         # every installed copy, and who pulled each in
pnpm why react                                                 # the same question in a pnpm workspace
yarn why react                                                 # and in a Yarn one
node -p "require('react/package.json').version"                # the version the app actually resolves
```

The first is how a duplicate React becomes visible before the "invalid hook call" it causes, and how a
peer-dependency range a library declares meets the version the app installed.

**What the type checker says about the change**

```sh
npx --no-install tsc --noEmit -p .                             # type-checks the project; writes nothing
npx --no-install tsc --noEmit -p packages/web                  # one package of a workspace
```

Most useful where the diff touched a type at the boundary and the claim is that something else still
compiles — or where the project's CI does not run `tsc`, which is worth knowing before trusting a type
as evidence.

**What the hooks linter says about one file**

```sh
npx --no-install eslint --rule 'react-hooks/exhaustive-deps: error' src/features/projects/ProjectList.tsx
npx --no-install eslint --no-inline-config src/features/projects/ProjectList.tsx   # with every eslint-disable ignored
```

Loads the project's ESLint configuration, so it runs its plugins. The second is how an
`eslint-disable` added in the diff becomes visible as the warning it suppressed.

**Which tests exist, without running them**

```sh
npx --no-install vitest list src/features/projects             # loads the Vitest config; collects, runs nothing
npx --no-install jest --listTests src/features/projects        # loads the Jest config; lists test files
npx --no-install playwright test --list                        # every end-to-end test, by title
```

The first answers *is there a test for this* faster than a search does, and by the runner's own
collection rules rather than by a guess at its glob.

**Running the one test that exercises the change**

```sh
npx --no-install vitest run src/features/projects/ProjectList.test.tsx   # runs one file; loads the config
```

Earned only where the judgment turns on whether that test passes against this branch — which is the
case for a test the diff changed alongside the code it covers.

## Search recipes for affected-but-unchanged code

Step 5 of the procedure lives or dies on these. Run the search, then **record it** — an empty result
is a finding only if the reader can see what was looked for.

Adjust paths to the layout step 2 discovered — a single app keeps code in `src/`, a workspace in
`apps/*` and `packages/*` or wherever its `workspaces` field says. `rg` is assumed, `grep -rn` works
the same. **Search the whole workspace, not the package that changed**: the consumers of a shared
package are the apps that import it.

**A changed component or its props**

```sh
rg -n '<ProjectCard\b' -g '*.{tsx,jsx,mdx}'                    # every place it is rendered
rg -n '\bProjectCard\b' -g '*.{ts,tsx,js,jsx}' -g '!*.test.*'  # imports, re-exports, lazy() and HOCs
rg -n 'export .*ProjectCard|export \* from' -g 'index.{ts,tsx,js}'   # the barrels that publish it
rg -n 'ProjectCard' -g '*.stories.*' -g '*.test.*' -g '*.spec.*'     # stories and tests that render it
```

For a changed prop, search its **old** name as well as the new one, as a JSX attribute
(`rg -n '\bvariant=' -g '*.tsx'`) — the caller still passing the old one is the finding, and the
updated one is already in the diff. A component rendered through a map (`components[type]`) or a
`lazy(() => import(…))` does not appear as `<ProjectCard`, which is why the second search is not
optional.

**A changed hook**

```sh
rg -n '\buseProjectFilters\(' -g '*.{ts,tsx,js,jsx}'           # every caller
rg -n 'useProjectFilters' -g '*.{ts,tsx,js,jsx}' | rg -v 'use[A-Z]\w* *=|function use'   # callers through destructuring
```

Read each caller for the part of the return value it uses. A hook whose return shape changed reaches
exactly the callers that destructure the moved field.

**A changed context**

```sh
rg -n 'ProjectContext' -g '*.{ts,tsx,js,jsx}'                  # the provider, every useContext and every helper hook
rg -n '<ProjectProvider\b|ProjectContext.Provider' -g '*.{tsx,jsx}'   # where the tree is wrapped — and so where it is not
```

A consumer rendered outside every provider gets the default value; the second search is how you find
which subtrees have none.

**A changed query key, cache tag or store slice**

```sh
rg -n "\[['\"]projects['\"]" -g '*.{ts,tsx,js,jsx}'           # every useQuery and invalidateQueries on that key
rg -n 'invalidateQueries|mutate\(|revalidate' -g '*.{ts,tsx,js,jsx}' | rg -i project
rg -n 'state\.projects\b|selectProjects' -g '*.{ts,tsx,js,jsx}'      # every selector reading the slice
```

A mutation that changes project data and invalidates no key naming projects is the finding.

**A changed route path**

```sh
rg -n "['\"\`]/projects" -g '*.{ts,tsx,js,jsx}'                # every link, navigate() and URL built from it
rg -n 'path: *["\x27]projects|<Route[^>]*projects' -g '*.{ts,tsx,js,jsx}'
```

**A changed API call or response type**

```sh
rg -n '/api/projects' -g '*.{ts,tsx,js,jsx}'                   # every client call to the endpoint
rg -n 'archivedAt|archived_at' -g '*.{ts,tsx,js,jsx,json}'     # readers of the field, fixtures and mock handlers included
rg -n "http\.(get|post|put|patch|delete)\(['\"].*projects" -g '*.{ts,tsx,js}'   # MSW handlers that copy its shape
```

**A changed dependency**

```sh
rg -n "from ['\"]some-lib['\"]|require\(['\"]some-lib" -g '*.{ts,tsx,js,jsx,mjs,cjs}'
rg -n '"some-lib"' -g 'package.json'                           # every workspace package that declares it, and at which range
```

**A changed environment variable**

```sh
rg -n 'VITE_API_URL|REACT_APP_API_URL' -g '!node_modules' -g '!dist' -g '!build'   # code, .env examples, CI and deploy config
```

A variable read in the code and set in none of the deployment files is the finding.
