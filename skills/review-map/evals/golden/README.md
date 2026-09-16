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

The `anchors-primer-*` set grades the third anchor — the callout `--mentor` admits — and it is the
largest family here for one component, because a primer has more ways to be quietly wrong than
anything else on the page: it is two paragraphs of framework prose, which read as self-justifying,
and each of its guards can be dropped while the callout still renders beautifully. One of them,
`anchors-primer-clean.html`, is the *positive* case and carries four pinned PASS rows, so a rule
that starts firing on correct markup goes red here rather than in the field.

`anchors-demo-loose.html` is the odd one: it plants its defect on a page with **no** primer at all,
which is the arm of that check that asserts rather than skipping. A `pre.demo` may show a result
line only because its receiver is a class the repository does not have, and "there is no primer
here" must never be allowed to excuse one.

`anchors-primer-uncited.html` breaks the one-defect rule on purpose and says so in its own header:
the doc link's "not alone" test asks the same question of a smaller block, so one missing `file:line`
fails twice. Its row pins the substring only the primer rule prints.

The three `anchors-hexdocs-*` fragments are the Elixir arms of the same rules, and one of them is a
*clean* fragment pinning something a defect fragment cannot: `anchors-hexdocs-clean.html` carries two
different package versions deliberately, because hexdocs pins per package and Rails' one-app-one-series
rule must **not** fire on it. Generalizing that rule is the likeliest future edit, and it would pass
every other row here while failing every correct Phoenix page — so the guard has to be a page that
would only break if someone did.
