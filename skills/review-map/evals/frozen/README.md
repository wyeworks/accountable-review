# frozen

The upstream a section eval is allowed to assume: the resolved target, the diff inventory,
the goal and use cases, and the flow split. One directory per fixture, mirroring what steps
1, 3, 4 and 6 of the procedure produce.

**Hand-authored from the fixture, never captured from a run.** A captured upstream bakes in
whatever that run got wrong, and every section graded downstream of it is then graded
against a mistake. These files are ground truth, in the same sense as the planted findings
in `../README.md`: written from reading the fixture, and correct by construction.

That is also the honest limit of a section eval. Freezing the upstream removes the very step
whose variance the page cases measure, so a section at 100% here is compatible with poor
pages — it just locates the defect upstream. See `../README.md` § *What each scope cannot
settle*.

Change a fixture and these change with it. A frozen upstream that has drifted from its
fixture is worse than none: every section eval then measures agreement with a stale
document.

**`rails-house-style` has no directory here, deliberately.** A frozen upstream is read only
by a section eval, and the section scope is deferred; `trivial` has none for the same reason.
Writing one now would be hand-authoring a document nothing opens, which then goes stale
unobserved — the drift this file warns about, arriving through diligence. Write it if and when
a section case runs against that fixture.

**And when you do, follow `monolith-guard-chain`'s convention, not the other two's.** Its
`target.md` says *"Commit SHAs are assigned when make-fixtures.sh runs, so do not cite them"*,
which is correct: `init_repo` and `commit` fix no author or committer date, so every build
produces different hashes. `rails-only-small/target.md` and `monorepo-contract/target.md` cite
literal SHAs that no build reproduces. Do not copy them.
