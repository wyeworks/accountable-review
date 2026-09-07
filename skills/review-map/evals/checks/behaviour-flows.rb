#!/usr/bin/env ruby
# frozen_string_literal: true

# behaviour_flows.rb — section 2, the bulk of the page, and the canonical home for
# everything one behaviour owns.
#
# The failure this section is most prone to is grouping by directory: Services / Models /
# Hooks / Components is the repository's structure, not the change's, and a reviewer who
# reads it still has to assemble the behaviour themselves. That failure is visible in the
# headings, so it is checkable.
#
# Then the SHAPE, which a script can settle outright: a flow body is a .mech block followed
# by one dl.rows carrying the seven fields, and .decisions sits after that dl. That is a
# check rather than a convention because a run flattened all three flows into loose field
# blocks and the page still rendered.
#
# The shape is MORE fragile in this design than in the one before it, not less. The unit used
# to be article.unit — a bordered card, so a flattened flow visibly lost its box. Now the unit
# is borderless by design: a .mech block and a hairline-separated grid. A flow that loses its
# .mech and spills its rows straight into the <section> looks very nearly correct. So the
# pairing is what gets checked, one .mech per dl.rows, and orphaned rows are a FAIL.
#
# The rest is per-unit. Two guards keep the review unit from becoming ceremony: it needs a
# non-obvious "things to understand", and every claim in it carries a file:line. Both are
# countable. Whether the split is DEFENSIBLE is the insight of the section and needs a
# reader — that is in the case, not here.

require_relative "lib/review_map/check"

module BehaviourFlows
  MECH     = /class="mech"/
  GRID     = /<dl class="rows"/
  DL_CLOSE = %r{</dl>}
  SECTION  = /<section [^>]*id="flow-/
  SEC_END  = %r{</section>}
  PENDING  = /class="pending"/

  # The canonical field labels, verbatim from report-format.md § The review unit. Matching
  # these rather than every <dt> is what keeps dl.ba's Before/After out of the field census.
  FIELDS = "Implementation|Tests|Affected, unchanged|Understand|Validate|Questions"
  FIELD_RE = /<dt>[[:space:]]*(#{FIELDS})[[:space:]]*<\/dt>/
  CANONICAL = /\A(#{FIELDS})\z/i

  LAYERS = "services?|models?|controllers?|serializers?|hooks?|components?|jobs?|helpers?|queries"
  # Layer names alone; "Archiving a project" passes, "Models" does not, and "Models and
  # serializers" does not either.
  LAYER_HEADING = /<h[234][^>]*>[[:space:]]*(#{LAYERS})([[:space:]]*(and|&amp;|,)[[:space:]]*[a-z]+)?[[:space:]]*</i
  LAYER_NAMED   = /<h[234][^>]*>[[:space:]]*(?:#{LAYERS})[^<]*/i

  # One flow's review unit, extracted from its .mech onward. The region starts at the .mech
  # and not at the grid because the mechanism statement IS the unit's "why this exists"
  # field: a unit that excluded it would be named after whatever <b> came first inside the
  # grid, which is a .gap callout's "GAP" often enough to be useless.
  class Unit
    def initialize(region, ordinal)
      @region = region
      @ordinal = ordinal
    end

    def label
      bold = @region.scan(/<b>[^<]*/).first.to_s.sub(/.*>/, "")[0, 48]
      bold.to_s.empty? ? "unit #{@ordinal}" : bold
    end

    def understand? = @region.has?(/<dt>[^<]*understand/i)

    # .path is the citation form in this design; .cite is still accepted, both for a rung-4
    # run that renders the citation as plain text and for a page built before .path existed.
    def cited? = @region.has?(/class="cite"|class="path"/)

    def validation? = @region.has?(/<dt>[^<]*validat/i)

    def pasteable_validation?
      @region.range(from: /<dt>[^<]*[Vv]alidat/, to: %r{</dd>}).has?(/<code/)
    end
  end
end

check = ReviewMap::Check.new(ARGV)
check.require_input

# On a page, narrow to the flow sections. The template gives them id="flow-a" and so on, and the
# narrowing is not tidiness: section 5 legitimately carries subheadings called "Jobs" or "Test
# infrastructure", and the layer-name check below would read those as grouping by directory.
# Section 4 also uses dl.rows, for Changed / Affected-not-changed, and must stay out of the
# unit census. Gate on what the extractor actually matches, not on a looser search: the template
# mentions id="flow-a" inside a comment, which a substring test accepts and this does not — and
# an empty region then reads as a section with no units in it.
flows = check.page.narrow(open: BehaviourFlows::SECTION, close: BehaviourFlows::SEC_END)

doc =
  if !flows.empty?
    # STAGE 3 JUST OPENED: every flow exists as a stub and none is written yet. The region is not
    # empty — a stub is a <section id="flow-b"> — so the pending branch below cannot fire, and the
    # checks would instead report "no .mech block found" and "no .pipe", which describe a wording
    # problem when the truth is "not written yet".
    #
    # Narrow on purpose, and the pending marker is the precondition rather than a detail: a SKIP
    # reads as verified, so this must be unreachable on a finished page. No .mech AND a pending
    # marker is the only shape that means what it says. One written flow beside a stub falls
    # through to the real checks, which is correct — the stub carries no .mech and no dl.rows, so
    # it adds nothing to either census.
    if !flows.has?(BehaviourFlows::MECH) && flows.has?(BehaviourFlows::PENDING)
      check.skip("every flow is still a stub — section 2's shape cannot be checked until one is written")
      check.finish
    end
    flows
  elsif check.kind == "page"
    # A PAGE with no flow sections at all. Falling back to the whole page here is what produced a
    # false positive on a real staged run: section 4 renders Changed / Affected-not-changed with the
    # same dl.rows and legitimately has no .mech, so an un-narrowed census read it as a flattened
    # flow. This is the same shape as the bug where article.cohort satisfied the old unit check —
    # section 1 always supplies one, so the substitute was always there no matter what section 2 did.
    # A fragment still falls through to the whole input, because a fragment need not carry the
    # <section id="flow-a"> wrapper at all.
    if check.page.has?(BehaviourFlows::PENDING)
      check.skip("no flow sections yet — section 2 is still pending, so its shape cannot be checked")
    else
      check.bad('no <section id="flow-..."> on the page — section 2 is the bulk of the report and it is absent')
    end
    check.finish
  else
    check.page
  end

# Grouping by directory, read off the headings.
if doc.has?(BehaviourFlows::LAYER_HEADING)
  named = doc.scan(BehaviourFlows::LAYER_NAMED).map { |h| h.sub(/.*>/, "") }.sort.uniq.join(" ")
  check.bad("a flow heading is a layer name: #{named} — that is the repository's structure, not the change's")
else
  check.ok("no flow is grouped by directory or layer")
end

# The grouping principle, stated before the flows. The split is the insight; an unstated
# one leaves the reader to reverse-engineer it.
first_flow = doc.lines.index { |l| l.match?(BehaviourFlows::MECH) }
if first_flow.nil?
  check.maybe("no .mech block found — a flow's body opens with one, so there is nothing for the grouping principle to precede")
# Truncate at the opening tag rather than taking whole lines: generated HTML is not always one
# element per line, and a first flow on line 1 is not the same thing as a missing one.
elsif doc.lines[0..first_flow].any? { |l| l.sub(/<div class="mech".*/, "").include?("<p") }
  check.ok("prose precedes the first flow, where the grouping principle belongs")
else
  check.maybe("the first flow opens with no prose before it — say why the split is what it is")
end

# The path, as a pipeline. A chain the reader can follow beats a paragraph describing one.
# ol.steps is accepted so a page built before .pipe still gets checked rather than warned at.
if doc.has?(/class="pipe"|class="steps"/)
  check.ok("at least one flow renders its path as a pipeline")
else
  check.maybe("no .pipe — the end-to-end path is what makes a flow a flow")
end

# The flows have to show the change, not only the unchanged code around it. A section whose
# only excerpts are --source has explained everything except the diff, and that is the failure
# this check exists to catch: the budget used to be read as rationing changed-code hunks too.
# WARN and not FAIL, because a fragment can legitimately hold a flow built entirely from
# unchanged code — and because "which flow lacks one" needs a reader, not a search.
if doc.has?(/class="excerpt/)
  if doc.has?(/excerpt--diff/)
    check.ok("the flows quote changed lines, not only unchanged ones")
  else
    check.maybe("every excerpt here is --source — no flow shows the hunk its behaviour turns on")
  end
end

# ---- The shape of a flow ----
#
# One .mech per dl.rows. The mech flag is cleared at each dl.rows, so a second grid riding on
# the first one's mech is reported rather than absorbed.
units = 0
orphans = 0
mech = false
doc.lines.each do |line|
  mech = true if line.match?(BehaviourFlows::MECH)
  next unless line.match?(BehaviourFlows::GRID)

  units += 1
  orphans += 1 unless mech
  mech = false
end

if units.positive? && orphans.positive?
  check.bad("#{orphans} of #{units} dl.rows grid(s) have no .mech before them — a flow body is a mechanism statement plus its fields, and rows alone read as a flow whose point was never stated")
elsif units.positive?
  check.ok("every dl.rows is introduced by a .mech block")
end

# TWO extractions, because the two questions below are different and one region cannot
# answer both.
#
# (1) Unit regions, for the per-unit guards and for naming. The region ends at the </dl> that
# closes its OWN grid — hence `arm` — so a .mech whose grid never opens ends at the next .mech
# or </section> instead, rather than running on and swallowing the next flow's dl.ba.
#
# The primer callout is dropped before this runs. It sits between the .mech and the grid, so it
# lands inside a unit region, and it carries a class="path" of its own — which would absolve a
# unit whose GRID cites nothing from the citation guard below. Its own citation is checked by
# rails-anchors.sh, where the rule about it belongs.
unit_regions = doc.without(open: /<aside class="primer/, close: %r{</aside>}).regions(open: BehaviourFlows::MECH, close: BehaviourFlows::DL_CLOSE,
                                      arm: BehaviourFlows::GRID, hard_close: BehaviourFlows::SEC_END)

# (2) The grids themselves, for the housing census. This has to be a separate region: a
# flattened flow keeps its .mech, so a census taken over unit regions counts loose fields as
# housed and reports the defect as something else entirely.
grids = doc.regions(open: BehaviourFlows::GRID, close: BehaviourFlows::DL_CLOSE)

# Fields outside a dl.rows. Counted, not merely detected, because the defect is a RATIO: a page
# can hold one correct unit and still spill fields beside it, which is the half that is hard to
# see by eye.
rows_total = doc.count(BehaviourFlows::FIELD_RE)
rows_housed = grids.sum { |g| g.count(BehaviourFlows::FIELD_RE) }
if rows_total > rows_housed
  check.bad("#{rows_total - rows_housed} of #{rows_total} field rows are outside a dl.rows — loose field blocks lose the row hairlines, the label gutter and every .rows-scoped rule")
elsif rows_total.positive?
  check.ok("every field row is inside a dl.rows")
end

# Decisions are pinned after the dl. .decision is a card; interleaved with the fields it reads
# as a new section starting mid-flow, and it breaks the grid.
if doc.has?(/class="decisions"/)
  if units.zero?
    # Do not report a placement as correct when there is no unit to place it against: the flow
    # this landed on had exactly that shape, and a PASS here would have read as absolution.
    check.skip("cannot check where the decisions block sits — there is no unit for it to sit after")
  elsif grids.any? { |g| g.has?(/class="decisions"/) }
    check.bad("a .decisions block sits inside a dl.rows — it belongs after the closing </dl>, where the card has the grid's edge to read against")
  else
    check.ok("decisions sit outside the unit, where .decision reads correctly")
  end
end

# Label drift. WARN, not FAIL: fields may be legitimately omitted, and a wrong label costs the
# reader a moment wondering whether two fields mean the same thing — it is not a false claim.
if rows_housed.positive?
  stray = grids.flat_map { |g| g.scan(/<dt>[^<]*/) }
               .map { |dt| dt.sub(/.*>/, "") }
               .reject { |dt| dt.match?(BehaviourFlows::CANONICAL) }
               .sort.uniq
  if stray.any?
    check.maybe("field labels outside the canonical set: #{stray.join(" ")} — report-format.md § The review unit names them verbatim")
  else
    check.ok("field labels match the canonical set")
  end
end

# ---- Per unit, the two guards ----
unit_regions.each_with_index do |region, i|
  unit = BehaviourFlows::Unit.new(region, i + 1)
  label = unit.label

  if unit.understand?
    check.ok("unit \"#{label}\" fills things-to-understand")
  else
    check.bad("unit \"#{label}\" has no things-to-understand — without one it is a ledger row, not a unit")
  end

  if unit.cited?
    check.ok("unit \"#{label}\" carries citations")
  else
    check.bad("unit \"#{label}\" makes claims with no file:line")
  end

  next unless unit.validation?

  if unit.pasteable_validation?
    check.ok("unit \"#{label}\" validation steps are commands")
  else
    check.maybe("unit \"#{label}\" has a validation field with no <code> — a step that is not pasteable is not a step")
  end
end

if units.zero?
  # A flow still carrying a pending marker has no shape to check yet, and saying so out loud is
  # the difference between "not written" and "written wrong" — the two build states this section
  # most needs to keep apart.
  if doc.has?(BehaviourFlows::PENDING)
    check.skip("no dl.rows yet — the flows here are still pending, so their shape cannot be checked")
  else
    check.bad("no dl.rows — a behaviour flow's body IS a unit, and fields rendered without one lose the grid that aligns them")
  end
else
  check.ok("#{units} review unit(s) inspected")
end

check.finish
