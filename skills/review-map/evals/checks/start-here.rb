#!/usr/bin/env ruby
# frozen_string_literal: true

# start_here.rb — section 3, the route through the code.
#
# The section is ONE list. What most needs judgment and what to read first are the same
# question, and the failure this script exists to catch is answering it twice: a findings
# list followed by a separate reading order, which is how this section used to restate the
# rest of the page.
#
# Three things are checkable. The list is an order with reasons rather than a list of paths.
# Its entries point INTO the flows, because section 2 is where a finding is explained and an
# entry that does not link is one that re-explained instead. And the list is short — a cap
# that is never reached bounds nothing, so the count is reported either way.
#
# What needs a reader: whether an entry names a finding or restates the flow, and whether
# the order is defensible. Neither is countable.

require_relative "lib/review_map/check"

ANCHOR = /id="start"/

check = ReviewMap::Check.new(ARGV, name: "start-here.sh")
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
  check.bad("section 3 carries #{lists} lists — it is one list; a second is the findings/reading-order split this format removed")
else
  check.ok("section 3 is a single list")
end

# Entries point into the flows. Section 2 explains; section 3 names and routes.
flowlinks = region.count(/href="#flow/)
if items.zero?
  check.skip("no entries to check for flow links")
elsif flowlinks < 1
  check.bad("no entry links into a flow — an entry that does not point at section 2 has re-explained the finding instead of naming it")
else
  check.ok("entries link into the flows that explain them (#{flowlinks})")
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

# The budget. Roughly five to eight; never one per changed file. Reported rather than
# enforced at the low end, because a small diff legitimately produces a short list.
if items > 12
  check.bad("#{items} entries — past about eight this is the ledger with reasons attached, not a starting point")
elsif items > 8
  check.maybe("#{items} entries — the shape is roughly five to eight; check none of these is a file that merely changed")
elsif items.positive?
  check.ok("#{items} entries, within the shape of a starting point")
end

# The sampling caveat lives here, once. Its absence is what lets the page read as an audit.
if region.has?(/not (an|a full) (audit|exhaustive)|pass, not an audit|surfaced|exhaustive/i)
  check.ok("the sampling caveat is carried here")
else
  check.maybe("no sampling caveat in section 3 — it lives here, once, and without it the list reads as an audit")
end

check.finish
