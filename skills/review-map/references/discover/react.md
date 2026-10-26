# Discovering a React project

Read at `SKILL.md` step 2, once, right after the stack is detected — this file and no other stack's.
It says what to find out about the repository before any tracing, and which versions the
documentation links will be pinned to. The lens, `references/react.md` with `references/nextjs.md`
on a Next.js app, is still read at step 5.

## The package

Find the `package.json` the changed files belong to, and the root one if this is a workspace: its
`workspaces` field, `pnpm-workspace.yaml`, or a `turbo.json` or `nx.json` says where the packages
are, and each package's own `name` is what a probe filters on. Record **the package manager from the
lock file** — `package-lock.json` is npm, `pnpm-lock.yaml` pnpm, `yarn.lock` Yarn, `bun.lock` or
`bun.lockb` Bun — because every probe is written in its syntax. Detect, don't assume: TypeScript or
JavaScript, and whether CI runs `tsc`; whether `<StrictMode>` wraps the tree; whether the React
Compiler is on (`babel-plugin-react-compiler`, or `reactCompiler` in a Next.js config); the state
layer (Redux, Zustand, Jotai, context alone); the data-fetching layer (React Query, SWR, RTK Query,
Apollo, server components); the form and validation libraries; the router; the test runner (Vitest
or Jest), the DOM library (Testing Library, and jsdom or happy-dom), and whether Playwright or
Cypress drives a browser; whether `eslint-plugin-react-hooks` is configured; and, for a library, the
`exports`, `peerDependencies` and the version it publishes.

## Next.js

On a **Next.js app**, also find **which router the changed files live under** — `app/` (the App
Router), `pages/` (the Pages Router), or both, either possibly under `src/` — because half of
`nextjs.md` and every `nextjs.org` catalogue row is router-specific; whether a `middleware.*` or
`proxy.*` exists and its `matcher`; how authentication is attached (a session helper, middleware, a
data-access layer); the `output` mode and any `experimental` flags in `next.config.*`; where server
actions and route handlers live; and the database layer if there is one — Prisma
(`prisma/schema.prisma` and its `migrations/`), Drizzle, or none.

## Versions

Record the **locked version of `react`, and of `next` on a Next.js app**, read from the lock file
rather than from `package.json`'s range: `npm ls react next`, or the entry in `pnpm-lock.yaml` or
`yarn.lock`. What the catalogue pins is the **major** — both documentation sites publish one page
per API per major — and each package pins its own, so a Next.js page carrying `15` for Next.js and
`19` for React is correct. A workspace can resolve two versions of React for two packages; the one
that counts is the version the changed package resolves.

## The frontend

**On a React stack the frontend is the application**, recorded above; what is left to find is the
API it talks to, if any, and `SKILL.md` step 2's client seam applies to it unchanged, with
`references/react.md` § *When there is an API across the wire* saying which lens sections cover the
client half.
