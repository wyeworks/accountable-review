require "tmpdir"
# make-defects.rb — cut defects/*.patch against gold.html, one planted defect each, all in § 01.
#   ruby calibration/discourse-43002/make-defects.rb
# Each anchor must match gold exactly once. A regenerated gold that no longer contains one
# aborts here, loudly, rather than producing a patch that plants nothing — so a new gold means
# new anchors in this file, and labels.yml stays as it is.
C = __dir__
gold = File.read("#{C}/gold.html")
TAIL = "one writer the diff did not touch.</p>\n"
D = [
  # 1 accurate: the component checks currentUser?.admin; moderators get no handle
  ["what-changed-wrong-delta",
   "Only\n        admins see the handle,",
   "Admins and\n        moderators see the handle,"],
  # 2 deltas: one change presented as a bullet list of execution steps
  ["what-changed-steps-as-deltas", TAIL,
   TAIL + "      <ul>\n        <li>An admin hovers a card and the handle appears</li>\n        <li>The admin drags the corner and the grid reflows</li>\n        <li>The client sends the new layout to the server</li>\n        <li>The server deletes and re-inserts every row</li>\n      </ul>\n"],
  # 3 attribution: the PR description's claim stated as fact, the attribution removed
  ["what-changed-unattributed-intent",
   "The\n        description says cards &ldquo;remember their size&rdquo;. Checkpoint A tests that claim against the\n        one writer the diff did not touch.",
   "Admins\n        wanted cards that remember their size, and now they do."],
  # 4 limits: a limit that is false — the page reads the Ember client throughout
  ["what-changed-false-limit", TAIL,
   TAIL + "      <p>The Ember client under <code>frontend/</code> could not be read, so what this page says about the handle is inferred from the server side.</p>\n"],
  # 5 no verdict: a grade
  ["what-changed-grading", TAIL,
   "one writer the diff did not touch. It is a small, low-risk change and looks safe to approve.</p>\n"],
  # 5 no verdict: a coverage assertion
  ["what-changed-coverage", TAIL,
   "one writer the diff did not touch. Every changed file was reviewed and no other issues were found.</p>\n"],
]
D.each do |name, old, new|
  abort "make-defects: #{name}'s anchor matches gold #{gold.scan(old).size} times, not once" unless gold.scan(old).size == 1
  tmp = File.join(Dir.tmpdir, "#{name}.html")
  File.write(tmp, gold.sub(old, new))
  diff = `diff -u "#{C}/gold.html" "#{tmp}"`
  File.write("#{C}/defects/#{name}.patch", diff.sub(/\A--- .*\n\+\+\+ .*\n/, "--- gold.html\n+++ gold.html\n"))
  File.delete(tmp)
end
puts D.map(&:first)
