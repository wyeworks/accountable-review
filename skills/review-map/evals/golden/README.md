# golden

Fragments with known verdicts. `../checks/self-test.sh` runs each one through the check it
is meant to exercise and asserts what comes back.

They exist because a check script that always passes is worse than none: it converts an
unchecked rule into a rule the reader believes is checked. Every check in `../checks/` that
can fail has a fragment here that makes it fail, and at least one that does not.

Keep them small — one defect each, planted on purpose, named in the filename. A fragment
with two defects cannot tell you which check caught which.
