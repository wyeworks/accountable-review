require "tmpdir"
# make-defects.rb — cut defects/*.patch against gold.html, one planted defect each, named for the
# judge whose criterion it plants a failure of.
#   ruby calibration/discourse-43002/make-defects.rb
# Each anchor must match gold exactly once. A regenerated gold that no longer contains one
# aborts here, loudly, rather than producing a patch that plants nothing — so a new gold means
# new anchors in this file, and labels.yml stays as it is.
C = __dir__
gold = File.read("#{C}/gold.html")
TAIL = "one writer the diff did not touch.</p>\n"
HEAD = "4f7ccd0326cf1f7d36000d2e530aca6ff4f8981f"

# The end of checkpoint D, where the attention section closes, and the checkpoint the unmerged
# variant adds there.
CP_D_END = "        </ul>\n      </section>\n    </section>\n"
CP_E = <<~HTML.gsub(/^(?=.)/, "      ")

  <section class="cp" id="cp-e">
    <span class="lbl lbl-wide">Checkpoint E</span>
    <h3>Should a layout save that leaves out a size store that card at 1&times;1?</h3>

    <p>The parser treats a missing <code>rows</code> or <code>cols</code> as 1, at
      <a class="path" href="https://github.com/discourse/discourse/pull/43002/files#diff-adc7e857a80c568a183a7b17d30163292d709e6e73a802862fdb4ef314f56449R235-R240">app/controllers/admin/dashboard_controller.rb:235-240</a>,
      and <code>LayoutUpdater</code> deletes every row before it writes what it is handed. A save that
      omits a card's size therefore stores that card at one cell, whatever size it had. Decide whether an
      omitted size should mean one cell, or should keep the size the card already has.</p>

    <ul class="lookat">
      <li>
        <b>Default in the parser</b>
        <span>falls back to 1 for each missing dimension</span>
        <a class="path" href="https://github.com/discourse/discourse/pull/43002/files#diff-adc7e857a80c568a183a7b17d30163292d709e6e73a802862fdb4ef314f56449R235-R240">app/controllers/admin/dashboard_controller.rb:235-240</a>
      </li>
      <li>
        <b>Default-to-1 request spec</b>
        <span>pins the one-cell fallback for an item sent with no size</span>
        <a class="path" href="https://github.com/discourse/discourse/pull/43002/files#diff-944d3162ab0371dfd9113fb935b2e3216446d4841565b194a446d44ee97dea64R2378-R2392">spec/requests/admin/dashboard_controller_spec.rb:2378-2392</a>
      </li>
    </ul>
  </section>
HTML

# The reading path's list, and the same list with its last stop — the one whose why says it
# comes last — moved to the front and the numbers redone.
START_OL = gold[%r{      <ol class="begin">\n.*?      </ol>\n}m]
stops = START_OL.scan(%r{        <li>\n.*?        </li>\n}m)
REORDERED_OL = START_OL.sub(stops.join) do
  ([stops.last] + stops[0..-2]).each_with_index.map { |li, i| li.sub(%r{<span class="n">\d+</span>}, format('<span class="n">%02d</span>', i + 1)) }.join
end

# Checkpoint D's click-branch entry, from its clause to its excerpt's summary line.
CLICK_ENTRY = gold[%r{ *<span><code>isNormal</code> is true only.*?every other size goes to 1x1</span>\n}m]

# A real excerpt (excerpt.sh --at, at head), of code the claim beside it is not about.
SCSS_EXCERPT = <<~'HTML'
<details class="excerpt excerpt--source">
  <summary>
    <span class="chev">&#9656;</span>
    <span class="ex-loc"><a class="cite" href="https://github.com/discourse/discourse/blob/4f7ccd0326cf1f7d36000d2e530aca6ff4f8981f/app/assets/stylesheets/admin/admin_dashboard.scss#L486-L494">app/assets/stylesheets/admin/admin_dashboard.scss:486-494</a></span>
    <span class="tag">At head</span>
    <span class="ex-why">the grid's fixed row height and its two columns</span>
  </summary>
  <div class="ex-body">
<pre data-src="app/assets/stylesheets/admin/admin_dashboard.scss" data-lang="scss" style="counter-reset: exl 485"><span class="l">    &amp;.--grid {</span>
<span class="l">      display: grid;</span>
<span class="l">      grid-template-columns: repeat(2, minmax(0, 1fr));</span>
<span class="l">      grid-auto-rows: 320px;</span>
<span class="l">      gap: var(--space-4);</span>
<span class="l"></span>
<span class="l">      @include viewport.until(sm) {</span>
<span class="l">        grid-template-columns: minmax(0, 1fr);</span>
<span class="l">      }</span>
</pre>
  </div>
</details>
HTML
D = [
  # 1 accurate, in the masthead: admin_dashboard_reports has no user column — one layout for every admin
  ["what-changed-headline",
   "<h1>Admins can resize report cards on the admin dashboard, and the size is saved</h1>",
   "<h1>Admins can resize report cards on the admin dashboard, and each admin's sizes are saved for them</h1>"],
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
  # ---- checkpoint-judgments ------------------------------------------------------------------
  # 1 a judgment, not a category: checkpoint C's question retitled as the layers it lives in
  ["checkpoint-judgments-category",
   "<h3>Which layer actually enforces &ldquo;a multi-row card is full width&rdquo;?</h3>",
   "<h3>Controller and model validations</h3>"],
  # 2 merged: checkpoint A's cause (default-to-1 + delete-then-insert) and decision (is the reset
  #   intended?) asked a second time, as its own checkpoint
  ["checkpoint-judgments-unmerged", CP_D_END, "        </ul>\n      </section>\n" + CP_E + "    </section>\n"],
  # 3 the order does not grade: the first checkpoint called the important one
  ["checkpoint-judgments-ranked",
   "<p>The controller now treats",
   "<p>This is the most important checkpoint on the page. The controller now treats"],
  # 4 asks, does not answer: checkpoint D pronounces a bug and prescribes the fix
  ["checkpoint-judgments-verdict",
   "Decide whether collapsing a tall card on an accidental click is the intended behaviour.",
   "This is a bug: the click branch should widen a 1&times;1 card and leave every other size alone."],

  # ---- checkpoint-claims ---------------------------------------------------------------------
  # 1 Look at entries: the handle-contract citation moved onto the payload and event docs above it
  ["checkpoint-claims-lookat-line",
   "d-resize-handles.gts#L101-L106\">frontend/discourse/app/ui-kit/d-resize-handles.gts:101-106",
   "d-resize-handles.gts#L86-L91\">frontend/discourse/app/ui-kit/d-resize-handles.gts:86-91"],
  # 2 explanations: LayoutUpdater deletes every row and re-inserts the list (layout_updater.rb:19,33)
  ["checkpoint-claims-explanation",
   "<code>LayoutUpdater</code> deletes every row before it re-inserts the list.",
   "<code>LayoutUpdater</code> updates each row in place and leaves the others alone."],
  # 3 stated absences: the request spec at :2378 covers an omitted size (planted on the corrected
  #   copy, whose GAP is true)
  ["checkpoint-claims-gap",
   "<span>No test resizes a card and then applies the modal. The one system spec that\n          applies it starts every card at 1&times;1.</span>",
   "<span>No test resizes a card and then applies the modal. No test covers a\n          layout save that omits a size.</span>"],

  # ---- reading-path --------------------------------------------------------------------------
  # 1 every stop points at the checkpoint that judges its code: layoutItems/loadPayloads is B's
  ["reading-path-wrong-pointer",
   "<a class=\"ptr\" href=\"#cp-b\">Checkpoint B &rarr;</a>",
   "<a class=\"ptr\" href=\"#cp-d\">Checkpoint D &rarr;</a>"],
  # 2 the order has reasons: the stop that says it comes last, moved first
  ["reading-path-unreasoned-order", START_OL, REORDERED_OL],
  # 3 points, does not re-explain: stop 02 restates checkpoint A's explanation
  ["reading-path-restates",
   "<span class=\"why\">The parser holds the default-to-1 and every size check a production write passes. Both the\n              layout and bulk endpoints call it.</span>",
   "<span class=\"why\">The controller now treats a missing <code>rows</code> or <code>cols</code> as 1.\n              <code>LayoutUpdater</code> deletes every row before it re-inserts the list, and the modal's Apply\n              button still sends only <code>source</code> and <code>identifier</code>, so reordering or adding a\n              report there resets every card to 1&times;1. Decide whether this reset is intended, or whether the\n              modal should carry the sizes through.</span>"],
  # 4 what a stop says is true: bulk_reports calls the parser too (dashboard_controller.rb:155)
  ["reading-path-false-claim",
   "Both the\n              layout and bulk endpoints call it.",
   "Only the\n              layout endpoint calls it."],

  # ---- impact --------------------------------------------------------------------------------
  # 1 an affected node's code does what the node says: toggleSection persists section visibility
  #   and never PUTs the reports layout
  ["impact-wrong-consumer",
   "<b>ManageReports#apply</b><span class=\"ip-d\">sends source + identifier only</span><a class=\"path ip-loc\" href=\"https://github.com/discourse/discourse/blob/#{HEAD}/frontend/discourse/admin/components/modal/manage-reports.gjs#L201-L204\">frontend/discourse/admin/components/modal/manage-reports.gjs:201-204</a>",
   "<b>AdminDashboardController#toggleSection</b><span class=\"ip-d\">sends source + identifier only</span><a class=\"path ip-loc\" href=\"https://github.com/discourse/discourse/blob/#{HEAD}/frontend/discourse/admin/controllers/admin/dashboard.js#L90-L103\">frontend/discourse/admin/controllers/admin/dashboard.js:90-103</a>"],
  # 2 every edge is true: setSize never calls the controller's private #applyConfigOptimistically
  ["impact-false-edge",
   "<span class=\"ip-rel\"><i></i>ignored by</span>",
   "<span class=\"ip-rel\"><i></i>called by</span>"],
  # 3 the affected list holds unchanged code: section.rb is in the diff
  ["impact-changed-as-affected",
   "<a href=\"#cp-b\">Checkpoint B</a></li>\n      </ul>\n    </section>",
   "<a href=\"#cp-b\">Checkpoint B</a></li>\n        <li><a class=\"path\" href=\"https://github.com/discourse/discourse/blob/#{HEAD}/lib/admin_dashboard/reports/section.rb#L50-L52\">lib/admin_dashboard/reports/section.rb:50-52</a> &mdash; sends each card's rows and cols back to the client with the section. <a href=\"#cp-b\">Checkpoint B</a></li>\n      </ul>\n    </section>"],
  # 4 a card's why orients and points: this one walks every hop of the path drawn beneath it
  ["impact-why-walks-hops",
   "<p class=\"ip-why\">An admin who resized cards and then reorders or adds a report in the modal finds\n            every card back at one cell. <a href=\"#cp-a\">Checkpoint A</a></p>",
   "<p class=\"ip-why\"><code>parse_reports_items_payload</code> turns a missing size into 1&times;1.\n            <code>ManageReports#apply</code> sends it only <code>source</code> and <code>identifier</code>, then\n            <code>AdminDashboardReport.delete_all</code> removes every old row so no earlier size survives, and\n            every card comes back at one cell. <a href=\"#cp-a\">Checkpoint A</a></p>"],

  # ---- evidence ------------------------------------------------------------------------------
  # 1 tiers are honest: the overlapping-resize claim is an inference and loses its label
  ["evidence-unlabelled-inference",
   "sends the first card's old size <span class=\"tier tier-inf\">inferred</span>.",
   "sends the first card's old size."],
  # 2 every excerpt is earned: real stylesheet bytes beside a claim about database constraints
  ["evidence-unearned-excerpt",
   "db/structure.sql:311-312</a>\n",
   "db/structure.sql:311-312</a>\n" + SCSS_EXCERPT],
  # 3 reads complete with every block shut: checkpoint D's click-branch entry loses its clause and
  #   its excerpt's summary goes vague, so the claim is left only inside the collapsed quotation
  ["evidence-hidden-claim", CLICK_ENTRY,
   CLICK_ENTRY.sub(/^ *<span><code>isNormal<\/code>.*\n/, "")
              .sub("the not-moved branch: 1x1 goes wide, every other size goes to 1x1", "the click branch")],
]

# ---- the corrected copies ------------------------------------------------------------------------
# gold.html is a run's unedited output, and the pre-certification reading found it fails four
# judges' criteria on its own: labels.yml says so on its gold row. Where gold fails a criterion, a
# defect planted on gold for that criterion changes nothing and gold cannot show the judge passing a
# page that meets it. So each such judge also gets <judge>-corrected — gold with exactly those
# failures fixed, labelled pass where gold is labelled fail — and its defects for those criteria are
# planted on the corrected copy instead (REBASED, and `base:` in labels.yml).
BLOB = "https://github.com/discourse/discourse/blob/#{HEAD}"
# cp-b's open question asks whether the code does what dashboard.js:91-127 shows it does; the
# corrected copies ask the question only the author can answer instead.
OPEN_QUESTION_B =
  ["<p class=\"open\"><b>Open question</b> Does hiding and re-showing the Reports section rebuild the\n          component from cached, pre-resize data? If it does, the next resize or remove would send the old size\n          back to the server <span class=\"tier tier-inf\">inferred</span>. Impact path B shows where that would\n          happen. Trying it in the browser would settle it.</p>",
   "<p class=\"open\"><b>Open question</b> Is it intended that showing the Reports section again rebuilds\n          the component from the cached, pre-resize data, so that the next resize or remove sends the old size\n          back to the server <span class=\"tier tier-inf\">inferred</span>? Impact path B shows where that\n          happens.</p>"].freeze
FIX = {
  # c3: a browser spec does apply the modal; cp-b's open question is one the code answers; and
  # cp-c's premise and its c2 twin need "of rows and cols", because seeds write rows in production
  "checkpoint-claims" => [
    ["<span>No test resizes a card and then applies the modal. No frontend test\n          covers the modal's Apply at all.</span>",
     "<span>No test resizes a card and then applies the modal. The one system spec that\n          applies it starts every card at 1&times;1.</span>"],
    OPEN_QUESTION_B,
    ["The only production write goes through <code>insert_all</code>",
     "The only production write of <code>rows</code> and <code>cols</code> goes through <code>insert_all</code>"],
    ["given that the model validations never see a production write?</p>",
     "given that the model validations never see a production write of a size?</p>"],
  ],
  # c4: the test file is the largest part of the diff, and the click branch is not at the end of
  # the range; stop 01's default and stop 02's "only enforced size rule" were loose
  "reading-path" => [
    ["The drag handlers come last. They are the largest part of the diff and depend on\n              everything above, and the click branch is at the end.",
     "The drag handlers come last. They depend on everything above, and the click\n              branch is in <code>onCardResizeEnd</code>."],
    ["Start with the two new columns and their default, so you know what an omitted size\n              turns into.",
     "Start with the two new columns and their default of 1, the same value the parser\n              gives an omitted size."],
    ["The parser holds both the default-to-1 and the only enforced size rule. Both the",
     "The parser holds the default-to-1 and every size check a production write passes. Both the"],
    # c3: stops 03 and 04 restated Checkpoint A's mechanism and consequence
    ["<span class=\"why\">Every save replaces the whole list, which is why a missing size becomes a reset.",
     "<span class=\"why\">Read the delete and the insert together, with the parser's defaults in mind."],
    ["<span class=\"why\">This unchanged file is the third writer of the layout, and the only one that leaves\n              sizes out <span class=\"tier tier-unc\">from unchanged code</span></span>",
     "<span class=\"why\">This unchanged file is the third writer of the layout; read its request body\n              against the parser in stop 02 <span class=\"tier tier-unc\">from unchanged code</span></span>"],
  ],
  # c3: delete_all's file is in the diff, so the node is changed code — LayoutUpdater as a whole,
  # cited at its hunk. c1: BulkFetch never sees the parser; the 400 is the changed controller's.
  # c4: card B's why walked the first two hops and never said what the admin sees.
  "impact" => [
    ["        <li><a class=\"path\" href=\"https://github.com/discourse/discourse/blob/4f7ccd0326cf1f7d36000d2e530aca6ff4f8981f/lib/admin_dashboard/reports/bulk_fetch.rb#L10-L28\">lib/admin_dashboard/reports/bulk_fetch.rb:10-28</a> &mdash; ignores rows and cols, but the shared parser now returns 400 for the whole bulk request if any size is out of range. <a href=\"#cp-c\">Checkpoint C</a></li>\n",
     ""],
    ["<p class=\"ip-why\">A resize updates only local state. Section data that the dashboard serves from its\n            cache still has the old size <span class=\"tier tier-inf\">inferred</span>.\n            <a href=\"#cp-b\">Checkpoint B</a></p>",
     "<p class=\"ip-why\">An admin who resizes a card, then hides the Reports section and shows it again,\n            sees the card back at its old size <span class=\"tier tier-inf\">inferred</span>.\n            <a href=\"#cp-b\">Checkpoint B</a></p>"],
    ["<li class=\"ip-n ip-aff\"><span class=\"ip-rel\"><i></i>causes</span><span class=\"ip-box\"><b>AdminDashboardReport.delete_all</b><span class=\"ip-d\">no old size survives</span><a class=\"path ip-loc\" href=\"#{BLOB}/lib/admin_dashboard/reports/layout_updater.rb#L19\">lib/admin_dashboard/reports/layout_updater.rb:19</a></span></li>",
     "<li class=\"ip-n ip-chg\"><span class=\"ip-rel\"><i></i>causes</span><span class=\"ip-box\"><b>LayoutUpdater.call</b><span class=\"ip-d\">deletes every row, re-inserts at 1&times;1</span><a class=\"path ip-loc\" href=\"https://github.com/discourse/discourse/pull/43002/files#diff-e14c2deaef5cedc3ef477f317420dbcddffc1faa6376518de3055fff3b0c723aR18-R35\">lib/admin_dashboard/reports/layout_updater.rb:18-35</a></span></li>"],
  ],
  # c1: the date-change and cached-copy claims rest on unchanged dashboard.js, cited nowhere in cp-b
  # and the second tiered
  # `inferred` on the card; the seeds claim rests on unchanged seed data; the bulk caller is
  # outside every hunk
  "evidence" => [
    OPEN_QUESTION_B,
    # the impact card hedged what the body and its tier now state
    ["A resized card may revert when the Reports section is shown again",
     "A resized card reverts when the Reports section is shown again"],
    # admin_dashboard.scss:489 is a line the diff adds, listed as affected-not-changed in the foot
    ["        <li><a class=\"path\" href=\"https://github.com/discourse/discourse/pull/43002/files#diff-35807e3f075a8c1fbb902e87020dbf0982d206585c14170247fb6844277dbda5R489\">app/assets/stylesheets/admin/admin_dashboard.scss:489</a> &mdash; <code>grid-auto-rows: 320px</code> applies to every <code>.--grid</code> section, and in core only Reports uses one.</li>\n",
     ""],
    ["After a date change that data\n          is refetched and correct,",
     "After a date change that data\n          is refetched, at\n          <a class=\"path\" href=\"#{BLOB}/frontend/discourse/admin/controllers/admin/dashboard.js#L74-L88\">frontend/discourse/admin/controllers/admin/dashboard.js:74-88</a>,\n          and correct <span class=\"tier tier-unc\">from unchanged code</span>,"],
    ["but when the dashboard re-serves its cached copy it still holds the sizes from\n          before the resize.",
     "but when the dashboard re-serves its cached copy, at\n          <a class=\"path\" href=\"#{BLOB}/frontend/discourse/admin/controllers/admin/dashboard.js#L96-L127\">frontend/discourse/admin/controllers/admin/dashboard.js:96-127</a>,\n          it still holds the sizes from before the resize <span class=\"tier tier-unc\">from unchanged code</span>."],
    ["cache still has the old size <span class=\"tier tier-inf\">inferred</span>.",
     "cache still has the old size <span class=\"tier tier-unc\">from unchanged code</span>."],
    ["So the model validations run only in seeds and specs, and",
     "So the model validations run only in seeds, at\n          <a class=\"path\" href=\"#{BLOB}/lib/seed_data/admin_dashboard_reports.rb#L11-L14\">lib/seed_data/admin_dashboard_reports.rb:11-14</a>,\n          and in specs <span class=\"tier tier-unc\">from unchanged code</span>, and"],
    ["That parser is also shared with the bulk-fetch endpoint.",
     "That parser is also shared with the bulk-fetch endpoint, at\n          <a class=\"path\" href=\"#{BLOB}/app/controllers/admin/dashboard_controller.rb#L155\">app/controllers/admin/dashboard_controller.rb:155</a>."],
    # § 01's "only admins" rests on canEdit, untouched lines of the changed reports.gjs that the diff
    # adds a caller of and the page cited nowhere; a judge that can run `git diff` sees they sit
    # outside every hunk
    ["admins see the handle, and only after the card's data has loaded.",
     "admins see the handle, at\n        <a class=\"path\" href=\"#{BLOB}/frontend/discourse/admin/components/dashboard/reports.gjs#L171-L173\">frontend/discourse/admin/components/dashboard/reports.gjs:171-173</a>,\n        and only after the card's data has loaded."],
  ],
}.freeze

# The defects planted on a corrected copy, because gold already fails the criterion they target.
REBASED = {
  "checkpoint-claims-gap" => "checkpoint-claims",
  "reading-path-restates" => "reading-path",
  "reading-path-false-claim" => "reading-path",
  "impact-wrong-consumer" => "impact",
  "impact-false-edge" => "impact",
  "impact-why-walks-hops" => "impact",
  "impact-changed-as-affected" => "impact",
  "evidence-unlabelled-inference" => "evidence",
}.freeze

VARIANTS = D.map { |name, old, new| [name, FIX.fetch(REBASED[name], []) + [[old, new]]] } +
           FIX.map { |judge, edits| ["#{judge}-corrected", edits] }
VARIANTS.each do |name, edits|
  html = edits.reduce(gold) do |h, (old, new)|
    n = h.scan(old).size
    abort "make-defects: an anchor of #{name} matches #{n} times, not once:\n#{old}" unless n == 1
    h.sub(old) { new }
  end
  tmp = File.join(Dir.tmpdir, "#{name}.html")
  File.write(tmp, html)
  diff = `diff -u "#{C}/gold.html" "#{tmp}"`
  File.write("#{C}/defects/#{name}.patch", diff.sub(/\A--- .*\n\+\+\+ .*\n/, "--- gold.html\n+++ gold.html\n"))
  File.delete(tmp)
end
puts VARIANTS.map(&:first)
