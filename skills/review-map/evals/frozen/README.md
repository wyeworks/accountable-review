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
