#!/usr/bin/env ruby
# frozen_string_literal: true

# start_here.rb — section 03, "read the code in this order".
#
# The section is ONE list. What most needs judgment and what to read first are the same
# question, and the failure this script exists to catch is answering it twice: a findings
# list followed by a separate reading order, which is how this section used to restate the
# rest of the page.
#
# Four things are checkable. The list is an order with reasons rather than a list of paths.
# Its entries point INTO the checkpoints, because section 02 is where a judgment is explained
# and an entry that does not link is one that re-explained instead. EVERY checkpoint is pointed
# at by something here, which is the half the link count alone misses. And the list is short —
# a cap that is never reached bounds nothing, so the count is reported either way.
#
# What needs a reader: whether the order builds understanding — schema before the code that
# trusts it, the smallest complete example before the bulk — and whether an entry names its
# reason or restates the checkpoint. Neither is countable.

require_relative "lib/review_map/check"

ANCHOR = /id="start"/

check = ReviewMap::Check.new(ARGV)
check.require_input

region = check.page.has?(ANCHOR) ? check.page.section_from(ANCHOR) : check.page
begin_list = region.range(from: /<ol class="begin"/, to: %r{</ol>})

# One list, and it is an order with reasons. A path list in some order is not a reading
# order, which is the whole distinction the .why span carries.
items = begin_list.count(/<li/)
whys  = begin_list.count(/class="why"/)
if items.zero?
  check.bad("no ol.begin — section 3 is one ordered list, and this fragment has none")
elsif whys >= items
  check.ok("start here: #{items} entr(ies), each with a why")
else
  check.bad("start here has #{items} entr(ies) but #{whys} why-clause(s) — a path list in an order is not a reading order")
end

# ONE list. A second ol in this section is the old shape: findings, then a separate
# reading order over the same files.
lists = region.count(/<ol/)
if lists > 1
  check.bad("section 03 carries #{lists} lists — it is one list; a second is the findings/reading-order split this format removed")
else
  check.ok("section 03 is a single list")
end

# Entries point into the checkpoints. Section 02 explains; section 03 names and routes.
cplinks = region.count(/href="#cp-/)
if items.zero?
  check.skip("no entries to check for checkpoint links")
elsif cplinks < 1
  check.bad("no entry links into a checkpoint — an entry that does not point at section 02 has re-explained the judgment instead of naming it")
else
  check.ok("entries link into the checkpoints that explain them (#{cplinks})")
end

# EVERY checkpoint is reachable from here, not just one of them. The rule above counts links
# and passes on a page that routes the reader to one judgment and orphans four, which is the
# shape a wide agenda produces: a checkpoint nothing points at is a question the reader was
# asked and never sent anywhere to answer.
#
# WARN rather than FAIL, because a draft legitimately carries stubs no stop routes yet, and
# failing a page for being unfinished is what the build states exist to say instead.
#
# GATED ON THE EVIDENCE, NOT ON check.kind. Requiring a whole page would have been the obvious
# guard and would have made this rule unreachable: every golden fixture runs as --fragment, so
# it would have SKIPped forever and self-test.rb could never prove it fires. A SKIP reads as
# verified, which is worse than no rule at all. So the question asked here is the honest one —
# are the checkpoints visible in this input? — and a bare section 03 still skips, saying why.
#
# Note what this does NOT check: that the stop count tracks the checkpoint count. It must not.
# Section 03 is a route ordered by conceptual dependency, and one stop routinely serves two
# judgments while one judgment routinely needs two. report-format.md § Section 3 owns that.
# The style block comes off first, and it is not a nicety. page-skeleton.sh emits the whole
# token block into every page, and one of its CSS comments explains the pending marker with the
# words `<section class="cp" id="cp-x">` in it. That is a CSS comment rather than an HTML one,
# so `without_comments` does not reach it, and every page this skill has ever produced was
# therefore reported as carrying a checkpoint `cp-x` that no stop routes to. A warning that
# fires on every correct page is worse than no warning: it is the one a reader learns to skip,
# and this rule's whole job is to be noticed on the rare page that really did orphan a judgment.
# Verified on five published pages, on both sides of the change that found it.
defined_cps = check.page.without(open: /<style/, close: %r{</style>})
                   .scan(/<section class="cp[^>]*id="cp-[^"]+"/)
                   .filter_map { |m| m[/id="(cp-[^"]+)"/, 1] }.uniq
cp_hrefs = region.scan(/href="#cp-[^"]+"/)
routed = cp_hrefs.filter_map { |m| m[/#(cp-[^"]+)"/, 1] }.uniq
orphans = defined_cps - routed

# An unsubstituted {{...}} is page-template.html itself, whose stops point at href="#cp-{{LETTER}}"
# and therefore resolve to none of its three assembled checkpoints. That is a template doing its
# job, not a page orphaning a judgment, and rails-anchors.rb draws the same distinction for
# {version}. Warning here would put a permanent WARN on correct input, which is how a real one
# stops being read.
if items.zero?
  check.skip("no entries to check for checkpoint coverage")
elsif cp_hrefs.any? { |h| h.include?("{{") }
  check.skip("the reading path's checkpoint links are unsubstituted placeholders — this is the template, not a page")
elsif defined_cps.empty?
  check.skip("no checkpoint sections in this input — coverage needs section 02 beside section 03")
elsif check.mode != "final"
  check.skip("checkpoint coverage is a final-page rule — a #{check.mode} page carries stubs no stop routes yet")
elsif orphans.empty?
  check.ok("every checkpoint is reachable from the reading path (#{defined_cps.size})")
else
  check.maybe("#{orphans.size} of #{defined_cps.size} checkpoint(s) have no stop pointing at them (#{orphans.join(', ')}) — a judgment the reader was asked and never routed to")
end

# Citations. Every entry names somewhere to go, and somewhere to go has a file:line.
# A .begin entry leads with <a class="path">; .cite is accepted too, both because a
# tier-4 run renders the citation as plain text in a span.cite and because a page built
# before the .begin list used .cite throughout.
cites = region.count(/class="cite"|class="path"/)
if items.positive? && cites < 1
  check.bad("section 3 has #{items} entr(ies) and no citation at all")
elsif items.positive?
  check.ok("citations present alongside the entries (#{cites})")
end

# The budget. Three to seven stops, never one per changed file. Reported rather than enforced
# at the low end, because a small diff legitimately produces a short route.
if items > 10
  check.bad("#{items} entries — past about seven this is the inventory with reasons attached, not a route")
elsif items > 7
  check.maybe("#{items} entries — the shape is three to seven; check none of these is a file that merely changed")
elsif items.positive?
  check.ok("#{items} entries, within the shape of a reading order")
end

# THE SAMPLING CAVEAT IS GONE FROM THE PAGE, so this script no longer looks for one. It
# used to require the sentence page-wide from here, which was always the wrong file for it —
# section 03 grading a rule about section 02. The rule that replaced it is the opposite one
# and lives where page-wide rules live: page_invariants.rb § 2d warns when a page carries a
# standing disclaimer, because what is true of every Review Map is stated once in the README
# rather than under a heading a reviewer opens to find out what to judge.

check.finish
