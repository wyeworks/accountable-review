A stub repository for `checks/searches.rb`, which re-runs a page's recorded searches and asks
whether they reach the entries the page cites.

Deliberately **not** a git repo and deliberately tiny: the check reads lines and runs greps, and
never asks git anything, so `self-test.rb` can point at this directory with `--repo` and stay at
about a second with no fixture build.

The two files are shaped to plant the exact defect the check exists for. `project.rb:2` names the
column, so `rg 'archived_at' app` reaches it. `projects_controller.rb:5` reads that same column
through the predicate `archived?`, so the same search misses it — which is the shape that produced
this check: a run recorded a grep for `account_type` and offered it as provenance for two guards
that read the column through `steward?`.
