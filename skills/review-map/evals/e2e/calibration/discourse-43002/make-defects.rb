require "tmpdir"
# make-defects.rb — cut defects/*.patch against gold.html, one planted defect each, named for the
# judge whose criterion it plants a failure of.
#   ruby calibration/discourse-43002/make-defects.rb
# Each anchor must match gold exactly once. A regenerated gold that no longer contains one
# aborts here, loudly, rather than producing a patch that plants nothing — so a new gold means
# new anchors in this file, and labels.yml stays as it is.
C = __dir__
gold = File.read("#{C}/gold.html")
HEAD = "4f7ccd0326cf1f7d36000d2e530aca6ff4f8981f"
BLOB = "https://github.com/discourse/discourse/blob/#{HEAD}"

# A block of gold found by pattern rather than spelled out, aborting when the pattern misses.
def block(gold, pattern, what)
  gold[pattern] or abort "make-defects: #{what} not found in gold.html"
end

# § 01's last paragraph ends here; the variants that add to § 01 add after it.
TAIL = "how every card rendered before.</p>\n"

# The end of checkpoint E, where the attention section closes, and the checkpoint the unmerged
# variant adds there: checkpoint A's question asked again from the endpoint's side.
CP_E_END = "        </ul>\n        </details>\n      </section>\n    </section>\n"
CP_F = <<~HTML.gsub(/^(?=.)/, "      ")

  <section class="cp" id="cp-f">
    <span class="lbl lbl-wide">Checkpoint F</span>
    <h3>Storing a layout save that leaves out a size</h3>
    <p>The layout endpoint accepts a size with each report, and a report sent without one is not
      refused: <a class="ref" href="https://github.com/discourse/discourse/pull/43002/files#diff-adc7e857a80c568a183a7b17d30163292d709e6e73a802862fdb4ef314f56449R235-R241">an absent row count or column span becomes 1</a>.
      The layout is then replaced as a whole, so a save that omits a card's size stores that card at
      one cell, whatever size it had.</p>
    <p class="open"><b>Review question</b>Should an omitted size mean one cell, or should it keep the size the card already has?</p>
    <details class="cp-ev">
      <summary><span class="chev">&#9656;</span><span class="cp-ev-lbl">Supporting evidence</span></summary>
    <ul class="lookat">
      <li>
        <b>Defaults in the parser</b>
        <span>falls back to 1 for each missing dimension</span>
        <a class="path" href="https://github.com/discourse/discourse/pull/43002/files#diff-adc7e857a80c568a183a7b17d30163292d709e6e73a802862fdb4ef314f56449R235-R241">app/controllers/admin/dashboard_controller.rb:235-241</a>
      </li>
    </ul>
    </details>
  </section>
HTML

# The reading path's list, and the same list with its first stop — the one whose why says it comes
# before the code that checks the rules — moved to the end and the numbers redone.
START_OL = block(gold, %r{      <ol class="begin">\n.*?      </ol>\n}m, "the reading path")
stops = START_OL.scan(%r{        <li>\n.*?        </li>\n}m)
REORDERED_OL = START_OL.sub(stops.join) do
  (stops[1..] + [stops.first]).each_with_index.map { |li, i| li.sub(%r{<span class="n">\d+</span>}, format('<span class="n">%02d</span>', i + 1)) }.join
end

# Checkpoint B's opening paragraph, which says what the layout is before the change uses it.
CP_B_OPENING = block(gold, %r{        <p>The dashboard stores its pinned reports as one list.*?already worked this way\.</p>\n}m, "checkpoint B's opening")
# Checkpoint C's paragraph on the read-only bulk endpoint, the unchanged caller the check reaches.
CP_C_BULK = block(gold, %r{        <p>The same check also guards a request that only reads\..*?could\.</p>\n}m, "checkpoint C's bulk paragraph")
# Checkpoint C's citation of bulk_reports, untouched lines of the changed controller.
BULK_REF = block(gold, %r{<a class="ref" href="#{Regexp.escape(BLOB)}/app/controllers/admin/dashboard_controller\.rb#L148-L160">a bulk\n          endpoint that parses its items with the same method</a>}, "the bulk_reports citation")

# A real excerpt (excerpt.sh --at --in-entry, at head), of code the entry beside it is not about.
SCSS_EXCERPT = <<~'HTML'
<details class="excerpt excerpt--source">
  <summary>
    <span class="chev">&#9656;</span>
    <span class="ex-loc"><a class="cite" href="https://github.com/discourse/discourse/blob/4f7ccd0326cf1f7d36000d2e530aca6ff4f8981f/app/assets/stylesheets/admin/admin_dashboard.scss#L486-L494">app/assets/stylesheets/admin/admin_dashboard.scss:486-494</a></span>
    <span class="tag">At head</span>
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
  # ---- what-changed --------------------------------------------------------------------------
  # 1 accurate, in the headline: admin_dashboard_reports has no user column — one layout for every admin
  ["what-changed-headline",
   "Admins can resize report cards, and each card keeps its size</h2>",
   "Admins can resize report cards, and each admin's sizes are saved for them</h2>"],
  # 1 accurate: canEdit is currentUser?.admin (reports.gjs:171-173); moderators get no handle
  ["what-changed-wrong-delta",
   "The handles appear only for admins,",
   "The handles appear for admins and moderators,"],
  # 2 deltas: one change presented as a bullet list of execution steps
  ["what-changed-steps-as-deltas", TAIL,
   TAIL + "      <ul>\n        <li>An admin hovers a card and the handle appears</li>\n        <li>The admin drags the corner and the grid reflows</li>\n        <li>The browser sends the whole layout to the server</li>\n        <li>The server deletes and re-inserts every row</li>\n      </ul>\n"],
  # 3 attribution: an intent the diff does not show, stated as fact with no attribution or tier
  ["what-changed-unattributed-intent",
   "<p>Admins get layouts that survive a reload",
   "<p>This is what admins asked for: layouts that survive a reload"],
  # 4 limits: a limit that is false — the page reads the Ember client throughout
  ["what-changed-false-limit", TAIL,
   TAIL + "      <p>The Ember client under <code>frontend/</code> could not be read, so what this page says about the handles is inferred from the server side.</p>\n"],
  # 5 no verdict: a grade
  ["what-changed-grading", TAIL,
   "how every card rendered before. It is a small, low-risk change and looks safe to approve.</p>\n"],
  # 5 no verdict: a coverage assertion
  ["what-changed-coverage", TAIL,
   "how every card rendered before. Every changed file was reviewed and no other issues were found.</p>\n"],

  # ---- checkpoint-judgments ------------------------------------------------------------------
  # 1 a judgment, not a category: checkpoint C's review question becomes the layers it lives in
  ["checkpoint-judgments-category",
   "<b>Review question</b>Is the layout endpoint&#39;s check meant to be the only guard on stored sizes?</p>",
   "<b>Review question</b>Review the controller and model validations.</p>"],
  # 1 a judgment, not a category: checkpoint C's heading becomes a place
  ["checkpoint-judgments-place-heading",
   "<h3>Where the card-size rules are enforced</h3>",
   "<h3>Controller and model changes</h3>"],
  # 2 merged: checkpoint A's cause (default-to-1 + whole-list replace) and decision asked a second
  #   time, as its own checkpoint
  ["checkpoint-judgments-unmerged", CP_E_END, "        </ul>\n        </details>\n      </section>\n" + CP_F + "    </section>\n"],
  # 3 the order does not grade: the first checkpoint called the important one
  ["checkpoint-judgments-ranked",
   "<p>The dashboard now has two ways",
   "<p>This is the most important checkpoint on the page. The dashboard now has two ways"],
  # 4 asks, does not answer: checkpoint D pronounces a bug and prescribes the fix
  ["checkpoint-judgments-verdict",
   "<b>Review question</b>Should a click on a tall card&#39;s handle take it all the way back to the smallest size?</p>",
   "<b>Review question</b>This is a bug: a click should widen a one-by-one card and leave every other size alone.</p>"],

  # ---- checkpoint-explanation ----------------------------------------------------------------
  # 1 explains before it asks: checkpoint B opens on identifiers whose jobs its next paragraphs explain
  ["checkpoint-explanation-identifier-first", CP_B_OPENING,
   "        <p><code>setSize</code> sends the layout to the endpoint that calls\n          <code>LayoutUpdater</code>, which runs <code>delete_all</code> and then <code>insert_all</code>.</p>\n#{CP_B_OPENING}"],
  # 2 stands alone: checkpoint B leaves how the layout is stored, the fact its argument starts from, to Context
  ["checkpoint-explanation-step-in-context", CP_B_OPENING,
   "        <p>How the dashboard stores its layout is in <a href=\"#context\">Context</a>.</p>\n"],
  # 2 stands alone: checkpoint C's unchanged bulk caller cut down to a pointer
  ["checkpoint-explanation-callers-pointer", CP_C_BULK,
   "        <p>The same check reaches other callers too; see <a href=\"#impact\">Impact outside the diff</a>.</p>\n"],
  # 2 never exhaustive: checkpoint D padded with the handle component's internals, none of which
  #   changes the question
  ["checkpoint-explanation-exhaustive",
   "so a short, hesitant drag counts as a click too.</p>\n",
   "so a short, hesitant drag counts as a click too.</p>\n        <p>The handles are drawn by the shared <code>DResizeHandles</code> component, which takes a\n          list of corners from <code>handleDirectionsFor</code>, a <code>measure</code> callback and the\n          <code>--resizing</code> class for the card being dragged. <code>onCardResizeStart</code> records\n          the card&#39;s rectangle, its row height and the grid&#39;s gaps; <code>onCardResize</code>\n          recomputes a live row count and column span on every pointer move, and a rectangle for the\n          floating card to follow; <code>onCardResizeCancel</code> clears all of it. The live size\n          feeds <code>effectiveCards</code>, which the grid&#39;s column computation reads, and the\n          reflow animation runs whenever <code>resizeSignature</code> changes.</p>\n"],
  # 3 reads complete with the evidence shut: checkpoint D's GAP removed, so the untested larger-card
  #   click is said only in a Look at clause
  ["checkpoint-explanation-gap-in-evidence",
   "<div class=\"gap\"><b>GAP</b><span>Nothing tests a click on a card that is already larger than the smallest size.</span></div>\n",
   ""],

  # ---- checkpoint-claims ---------------------------------------------------------------------
  # 1 Look at entries: the click-test entry cites the two-resizes test instead
  ["checkpoint-claims-lookat-line",
   "reports-test.gjs#L284-L338\">frontend/discourse/tests/integration/components/dashboard/reports-test.gjs:284-338",
   "reports-test.gjs#L414-L494\">frontend/discourse/tests/integration/components/dashboard/reports-test.gjs:414-494"],
  # 2 explanations: LayoutUpdater deletes every row and re-inserts the list (layout_updater.rb:19,33)
  ["checkpoint-claims-explanation",
   "the layout endpoint deletes every stored row and inserts\n          the list it was given.",
   "the layout endpoint updates the stored rows in place and\n          leaves the others alone."],
  # 3 stated absences: the click test at reports-test.gjs:284-338 clicks a handle
  ["checkpoint-claims-gap",
   "<span>Nothing tests a click on a card that is already larger than the smallest size.</span>",
   "<span>Nothing tests a click on a resize handle.</span>"],

  # ---- reading-path --------------------------------------------------------------------------
  # 1 every stop points at the checkpoint that judges its code: the layout updater is B's, not E's
  ["reading-path-wrong-pointer",
   "<a class=\"ptr\" href=\"#cp-b\">Checkpoint B &rarr;</a>",
   "<a class=\"ptr\" href=\"#cp-e\">Checkpoint E &rarr;</a>"],
  # 2 the order has reasons: the stop that says it comes before the checks, moved last
  ["reading-path-unreasoned-order", START_OL, REORDERED_OL],
  # 3 points, does not re-explain: stop 03 restates checkpoint A's explanation and question
  ["reading-path-restates",
   "<span class=\"why\">A second sender to that endpoint, outside the diff, that sends no size <span class=\"tier tier-unc\">from unchanged code</span>.</span>",
   "<span class=\"why\">The modal sends each report&#39;s source and identifier and nothing else <span class=\"tier tier-unc\">from unchanged code</span>.\n              The endpoint turns a missing size into 1 and replaces the whole layout, so any save from the\n              modal, even a reorder, puts every card back at one row by one column. Decide whether that\n              reset is intended, or whether the modal should carry the sizes through.</span>"],
  # 4 what a stop says is true: the updater deletes every row, then inserts (layout_updater.rb:19,33)
  ["reading-path-false-claim",
   "<span class=\"why\">Where a received list replaces the stored layout, and where the bulk insert writes the sizes.</span>",
   "<span class=\"why\">Where each received item updates its own stored row in place, leaving the rest as they were.</span>"],

  # ---- impact --------------------------------------------------------------------------------
  # 1 an affected node's code does what the node says: toggleSection persists section visibility
  #   and never PUTs the reports layout
  ["impact-wrong-consumer",
   "<b>ManageReports#apply</b><span class=\"ip-d\">sends source and identifier only</span><a class=\"path ip-loc\" href=\"#{BLOB}/frontend/discourse/admin/components/modal/manage-reports.gjs#L197-L205\">frontend/discourse/admin/components/modal/manage-reports.gjs:197-205</a>",
   "<b>AdminDashboardController#toggleSection</b><span class=\"ip-d\">sends source and identifier only</span><a class=\"path ip-loc\" href=\"#{BLOB}/frontend/discourse/admin/controllers/admin/dashboard.js#L90-L103\">frontend/discourse/admin/controllers/admin/dashboard.js:90-103</a>"],
  # 2 every edge is true: the parser does not call the modal; the modal's request reaches the parser
  ["impact-false-edge",
   "<span class=\"ip-rel\"><i></i>called by</span>",
   "<span class=\"ip-rel\"><i></i>calls</span>"],
  # 3 the affected list holds unchanged code: section.rb is in the diff
  ["impact-changed-as-affected",
   "<a href=\"#cp-b\">Checkpoint B</a></li>\n      </ul>\n    </section>",
   "<a href=\"#cp-b\">Checkpoint B</a></li>\n        <li><a class=\"path\" href=\"https://github.com/discourse/discourse/pull/43002/files#diff-7746fec8454dfbbb711ddef80bc797cac7b3de6d1925f55ac19d3e939418cab7R26-R37\">lib/admin_dashboard/reports/section.rb:26-37</a> &mdash; sends each card&#39;s rows and cols back to the browser with the section. <a href=\"#cp-b\">Checkpoint B</a></li>\n      </ul>\n    </section>"],
  # 4 a card's why orients and points: this one walks every hop of the path drawn beneath it
  ["impact-why-walks-hops",
   block(gold, %r{<p class="ip-why">An admin who saves the Manage reports modal.*?<a href="#cp-a">Checkpoint A</a></p>}m, "card A's why"),
   "<p class=\"ip-why\"><code>parse_reports_items_payload</code> turns a missing size into 1.\n            <code>ManageReports#apply</code> sends it only <code>source</code> and <code>identifier</code>,\n            so every card comes back at one row by one column <span class=\"tier tier-unc\">from unchanged code</span>.\n            <a href=\"#cp-a\">Checkpoint A</a></p>"],

  # ---- evidence ------------------------------------------------------------------------------
  # 1 no claim is stated as more than it is: the overlapping-saves claim is an inference and loses
  #   its label
  ["evidence-unlabelled-inference",
   "the browser shows both sizes\n          <span class=\"tier tier-inf\">inferred</span>.",
   "the browser shows both sizes."],
  # 2 no label on what the diff shows: the default of 1 is the migration the diff adds
  ["evidence-labelled-diff-claim",
   "both default to 1</a>.",
   "both default to 1</a> <span class=\"tier tier-unc\">from unchanged code</span>."],
  # 3 an untouched line of a changed file is cited: bulk_reports sits outside every hunk of the
  #   changed controller, and its citation is taken back
  ["evidence-uncited-untouched-line", BULK_REF,
   "a bulk\n          endpoint that parses its items with the same method"],
  # 4 every excerpt is earned: real stylesheet bytes beside the seeder entry
  ["evidence-unearned-excerpt",
   "lib/seed_data/admin_dashboard_reports.rb:11-14</a>\n",
   "lib/seed_data/admin_dashboard_reports.rb:11-14</a>\n" + SCSS_EXCERPT],
  # 5 every field complete with its excerpt shut: checkpoint B's section entry loses its clause, so
  #   what to see is left inside the collapsed quotation
  ["evidence-hidden-claim",
   "<span>only rows that resolve, clipped to the newest ten before sorting by position</span>\n",
   ""],
]

# ---- the corrected copies ------------------------------------------------------------------------
# gold.html is a run's unedited output, and where the pre-certification reading found it fails a
# criterion, labels.yml says so on its gold row. A defect planted on gold for that criterion changes
# nothing, and gold cannot show the judge passing a page that meets it. So each such judge also gets
# <judge>-corrected — gold with exactly those failures fixed — and its defects for those criteria are
# planted on the corrected copy instead (REBASED, and `base:` in labels.yml).
FIX = {
  # c2: the rules allow five sizes (1x1, 1x2, 2x2, 3x2, 4x2); eight counts the four-by-two
  # combinations the full-width rule forbids
  "checkpoint-claims" => [
    ["The shortcut is a toggle between two sizes over a range of eight,",
     "The shortcut is a toggle between two sizes over a range of five,"],
  ],
  # c1: two claims rest on files the diff does not touch and carry no tier — what the eight-pixel
  # threshold means (d-pointer-drag.ts) and where the modal loads its reports from
  # (manage-reports.gjs:137); the corrected copy cites and tiers both, and tiers the two
  # untiered claims about what the modal sends (manage-reports.gjs:197-205), in A and B.
  # c3: checkpoint B's two "removing a report already did this" rest on removeReport, and § 01's
  # admins-only handles on canEdit, untouched lines of the changed reports.gjs; B's "ten" rests on
  # VISIBLE_CAP, an untouched line of the changed admin_dashboard_report.rb. The corrected copy
  # cites all four.
  "evidence" => [
    ["pixels of travel</a>, so a short, hesitant drag counts as a click too.</p>",
     "pixels of travel</a>, because\n          <a class=\"ref\" href=\"#{BLOB}/frontend/discourse/app/ui-kit/modifiers/d-pointer-drag.ts#L451-L461\">the drag modifier reports no move until the pointer passes it</a>\n          <span class=\"tier tier-unc\">from unchanged code</span>, so a short, hesitant drag counts as a click too.</p>"],
    ["The handles appear only for admins, and not while a card is still loading.",
     "The handles appear\n        <a class=\"ref\" href=\"#{BLOB}/frontend/discourse/admin/components/dashboard/reports.gjs#L171-L173\">only for admins</a>,\n        and not while a card is still loading."],
    ["It loads its enabled reports from\n          <a class=\"ref\"",
     "It\n          <a class=\"ref\" href=\"#{BLOB}/frontend/discourse/admin/components/modal/manage-reports.gjs#L137\">loads its enabled reports from the available-reports action</a>\n          <span class=\"tier tier-unc\">from unchanged code</span>, which builds them from\n          <a class=\"ref\""],
    ["Removing a report from the dashboard already worked this way.",
     "<a class=\"ref\" href=\"#{BLOB}/frontend/discourse/admin/components/dashboard/reports.gjs#L411-L426\">Removing\n          a report from the dashboard</a> already worked this way."],
    ["browser, and is deleted by the next resize. Removing a report or saving the modal already did",
     "browser, and is deleted by the next resize.\n          <a class=\"ref\" href=\"#{BLOB}/frontend/discourse/admin/components/dashboard/reports.gjs#L411-L426\">Removing\n          a report</a> or\n          <a class=\"ref\" href=\"#{BLOB}/frontend/discourse/admin/components/modal/manage-reports.gjs#L197-L205\">saving\n          the modal</a> <span class=\"tier tier-unc\">from unchanged code</span> already did"],
    ["\">the ten most recently created</a>.",
     "\">the most recently created</a>, up to\n          <a class=\"ref\" href=\"#{BLOB}/app/models/admin_dashboard_report.rb#L4\">ten</a>."],
    ["<strong>The modal, which this change does not touch, still",
     "<strong>The modal, which this change does not touch\n          <span class=\"tier tier-unc\">from unchanged code</span>, still"],
  ],
  # c1, unsettled on gold: "a click … toggles the card's width" is true of every size but leaves out
  # that a taller card also drops to one row; the corrected copy says both sizes the click chooses
  "what-changed" => [
    ["A click on the corner without dragging toggles the card&#39;s width instead.",
     "A click on the corner without dragging instead widens a card of the smallest size to one row at full width,\n        and returns a card of any other size to the smallest."],
  ],
}.freeze

# The defects planted on a corrected copy, because gold already fails, or may fail, the criterion
# they target.
REBASED = {
  "checkpoint-claims-explanation" => "checkpoint-claims",
  "evidence-unlabelled-inference" => "evidence",
  "evidence-uncited-untouched-line" => "evidence",
  "what-changed-headline" => "what-changed",
  "what-changed-wrong-delta" => "what-changed",
}.freeze

VARIANTS = D.map { |name, old, new| [name, FIX.fetch(REBASED[name], []) + [[old, new]]] } +
           FIX.map { |judge, edits| ["#{judge}-corrected", edits] }
Dir["#{C}/defects/*.patch"].each { |f| File.delete(f) }
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
