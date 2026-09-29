require "tmpdir"
# make-defects.rb — re-cut defects/*.patch against gold.html. Run from anywhere:
#   ruby calibration/discourse-43002/make-defects.rb
# Each anchor must match gold exactly once; a regenerated gold that no longer contains one aborts
# here, loudly, rather than producing a patch that plants nothing.
C = __dir__
gold = File.read("#{C}/gold.html")
# Each: [name, old, new]. One defect per variant, all inside § 01.
D = [
  ["what-changed-wrong-delta",
   "Moderators see the sizes but get no handle, because the\n        component checks <code>currentUser.admin</code>.",
   "Moderators can resize cards too, because the component checks\n        <code>currentUser.staff</code>."],
  ["what-changed-steps-as-deltas",
   "        commit adds a test.</p>\n",
   "        commit adds a test.</p>\n      <ul>\n        <li>An admin hovers a card and the handle appears</li>\n        <li>The admin drags the corner and the grid reflows</li>\n        <li>The client sends the new layout to the server</li>\n        <li>The server deletes and re-inserts every row</li>\n      </ul>\n"],
  ["what-changed-unattributed-intent",
   "An admin can drag a card's bottom corner",
   "Admins asked for denser dashboards, and this is what they wanted: an admin can drag a card's bottom corner"],
  ["what-changed-false-limit",
   "        commit adds a test.</p>\n",
   "        commit adds a test.</p>\n      <p>The Ember client under <code>frontend/</code> could not be read, so what the page says about the handle is inferred from the server side.</p>\n"],
  ["what-changed-grading",
   "        commit adds a test.</p>",
   "        commit adds a test. It is a small, low-risk change and looks safe to approve.</p>"],
  ["what-changed-coverage",
   "        commit adds a test.</p>",
   "        commit adds a test. Every changed file was reviewed and no other issues were found.</p>"],
]
D.each do |name, old, new|
  abort "no unique match for #{name}" unless gold.scan(old).size == 1
  v = gold.sub(old, new)
  tmp = File.join(Dir.tmpdir, "#{name}.html")
  File.write(tmp, v)
  diff = `diff -u "#{C}/gold.html" "#{tmp}"`
  File.write("#{C}/defects/#{name}.patch", diff.sub(/\A--- .*\n\+\+\+ .*\n/, "--- gold.html\n+++ gold.html\n"))
  File.delete(tmp)
end
puts D.map(&:first)
