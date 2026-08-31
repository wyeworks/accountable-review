# golden

Fragments with known verdicts. `../checks/self-test.sh` runs each one through the check it
is meant to exercise and asserts what comes back.

They exist because a check script that always passes is worse than none: it converts an
unchecked rule into a rule the reader believes is checked. Every check in `../checks/` that
can fail has a fragment here that makes it fail, and at least one that does not.

Keep them small — one defect each, planted on purpose, named in the filename. A fragment
with two defects cannot tell you which check caught which.

`searches-repo/` is the small repository three of these are graded against: `searches.sh` re-runs
recorded searches inside it, and `rails-anchors.sh` asks it whether the constants and attributes a
probe names actually exist. It holds a `Project` with one scope (`selectable`) and one method, and
deliberately no `slug` and no `published` scope — which is what `anchors-invented-attribute.html` and
`anchors-invented-scope.html` respectively lean on. Adding to that repository can therefore
turn an intended failure into a pass; check `self-test.sh` still goes red when you do.

The `anchors-*` set is where the one-defect rule earns itself most visibly: a fragment that both cites
an uncatalogued URL and names a missing scope would fail twice, and the row asserting one substring
would pass for the wrong reason.
