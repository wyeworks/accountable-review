# golden

Fragments with known verdicts. `../checks/self-test.rb` runs each one through the check it
is meant to exercise and asserts what comes back.

They exist because a check script that always passes is worse than none: it converts an
unchecked rule into a rule the reader believes is checked. Every check in `../checks/` that
can fail has a fragment here that makes it fail, and at least one that does not.

Keep them small — one defect each, planted on purpose, named in the filename. A fragment
with two defects cannot tell you which check caught which.

`searches-repo/` is the small repository three of these are graded against: `searches.rb` re-runs
recorded searches inside it, and `rails-anchors.rb` asks it whether the constants and attributes a
probe names actually exist. It holds a `Project` with one scope (`selectable`) and one method, and
deliberately no `slug` and no `published` scope — which is what `anchors-invented-attribute.html` and
`anchors-invented-scope.html` respectively lean on. Adding to that repository can therefore
turn an intended failure into a pass; check `self-test.rb` still goes red when you do.

The `anchors-*` set is where the one-defect rule earns itself most visibly: a fragment that both cites
an uncatalogued URL and names a missing scope would fail twice, and the row asserting one substring
would pass for the wrong reason.

The three `anchors-hexdocs-*` fragments are the Elixir arms of the same rules, and one of them is a
*clean* fragment pinning something a defect fragment cannot: `anchors-hexdocs-clean.html` carries two
different package versions deliberately, because hexdocs pins per package and Rails' one-app-one-series
rule must **not** fire on it. Generalizing that rule is the likeliest future edit, and it would pass
every other row here while failing every correct Phoenix page — so the guard has to be a page that
would only break if someone did.

`start-here-orphan-checkpoint.html` is the same argument for a rule that sits beside an older one
measuring nearly the same thing. Section 03 has always been checked for linking *into* the
checkpoints, and that rule counts links: the fixture keeps three stops, three why-clauses, three
citations and three `href="#cp-"` links, so it passes, and only comparing the set of checkpoints
against the set the reading path routes to notices that `cp-b` is a question nobody was sent to
answer. It plants one orphan rather than two on purpose — a fixture orphaning both checkpoints keeps
failing while either half of the comparison regresses, and therefore pins neither.
