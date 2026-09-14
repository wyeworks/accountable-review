# Deferred: the section cases

These six cases and their drivers predate the review agenda. Each was keyed to a section of the
old page — `behaviour-flows`, `reach`, `before-approving` at two detail levels — and to a
`check.rb` scope that no longer exists, so none of them runs: `bin/evals section` reads
`cases/`, and nothing here is in it.

They are kept rather than deleted because the judged expectations in them are the expensive
half. What has to change is the unit: a section case produced ONE section from the frozen
upstream and graded it, and the agenda's equivalent is one CHECKPOINT — the question, whether
it is a judgment rather than a category, whether the merge in step 7c was the right one,
whether the chain earned its place. That is a different driver and a different scope, not a
rename of these.

`frozen/` stays where it is. Its `flows.md` is still the upstream a run's per-flow analysis
notes are written from — it just no longer produces a section of the page.
