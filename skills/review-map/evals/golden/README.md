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

Three of them are about the frame rather than the content. `anchors-primer-rust-clean.html` is the
Rust positive case — a primer on a `docs.rs` row carrying `pr-rust` — and the other two are one
class away from a clean fragment in opposite directions: `-rust-unframed` drops the class from the
Rust one, `-rails-framed` adds it to the Rails one. Both fail § 8g and nothing else, because the frame
is read off the doc link's host and a mismatch either way is a colour somebody chose.

The three `anchors-hexdocs-*` fragments are the Elixir arms of the same rules, and one of them is a
*clean* fragment pinning something a defect fragment cannot: `anchors-hexdocs-clean.html` carries two
different package versions deliberately, because hexdocs pins per package and Rails' one-app-one-series
rule must **not** fire on it. Generalizing that rule is the likeliest future edit, and it would pass
every other row here while failing every correct Phoenix page — so the guard has to be a page that
would only break if someone did.

The three `anchors-docsrs-*` fragments are the Rust arms, and `anchors-docsrs-clean.html` does the same
job for the same reason: two crates and the toolchain, three different version segments, on one
page. `anchors-probe-rust-forms.html` is the probe half — `Cargo.toml` named as a file, and a struct
named as a test filter — and it is the reason `searches-repo` carries a `src/archive.rs`.

The three `anchors-reactdocs-*` and `anchors-nextjs-*` fragments are the React arms. The clean one
carries a React major and a Next.js major that differ, for the same reason again; the wrong-router
one is a `docs/pages/` link to an API catalogued under `docs/app/` only, which is the defect a
pinned, resolving URL can still have in this stack. `anchors-probe-js-forms.html` is the probe half
— a component named as a test filter, and its test file named by path — and it is the reason
`searches-repo` carries a `src/components/ProjectCard.tsx`.

`start-here-orphan-checkpoint.html` is the same argument for a rule that sits beside an older one
measuring nearly the same thing. Section 03 has always been checked for linking *into* the
checkpoints, and that rule counts links: the fixture keeps three stops, three why-clauses, three
citations and three `href="#cp-"` links, so it passes, and only comparing the set of checkpoints
against the set the reading path routes to notices that `cp-b` is a question nobody was sent to
answer. It plants one orphan rather than two on purpose — a fixture orphaning both checkpoints keeps
failing while either half of the comparison regresses, and therefore pins neither.
