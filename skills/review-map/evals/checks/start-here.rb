#!/usr/bin/env ruby
# frozen_string_literal: true

# start_here.rb — section 03, "read the code in this order".
#
# The section is ONE list. What most needs judgment and what to read first are the same
# question, and the failure this script exists to catch is answering it twice: a findings
# list followed by a separate reading order, which is how this section used to restate the
# rest of the page.
#
# Three things are checkable. The list is an order with reasons rather than a list of paths.
# Its entries point INTO the checkpoints, because section 02 is where a judgment is explained
# and an entry that does not link is one that re-explained instead. And the list is short — a
# cap that is never reached bounds nothing, so the count is reported either way.
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

# THE SAMPLING CAVEAT MOVED TO SECTION 02, where the judgments are, so it is looked for
# page-wide rather than in this region. A fragment of section 03 alone cannot carry it and
# must not be failed for that — the skip says which, rather than passing on nothing.
if check.kind != "page"
  check.skip("the sampling caveat lives under section 02; a section 03 fragment cannot carry it")
elsif check.page.has?(/not (an|a full) (audit|exhaustive)|pass, not an audit|surfaced|exhaustive/i)
  check.ok("the sampling caveat is on the page")
else
  check.maybe("no sampling caveat anywhere on the page — it lives under section 02, once, and without it the agenda reads as the complete set")
end

check.finish
