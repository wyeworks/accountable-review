#!/usr/bin/env ruby
# frozen_string_literal: true

# brief_budget.rb — how much prose the default detail level may spend.
#
# report-format.md § *The brief budget* owns the numbers; this is the mechanical half of
# them. A ceiling on the page, a cap per component, the two concepts whose removal is
# structural rather than a matter of wording, and one floor.
#
# DETAIL LEVEL. This is the SECOND check that reads --level, and the first was
# before-approving.rb. At --level full there is no budget at all: --brief is where the caps
# live, and a page written to seven sections is not overspending by carrying seven. So this
# whole script SKIPs there, out loud, saying nothing was measured — the budget is a property
# of one level and pretending otherwise would grade every full page against a cap nobody
# wrote for it.
#
# VERBOSITY WARNS, SHAPE FAILS, AND THE FLOOR FAILS. That split is the design, not caution:
# a hard failure on length teaches a run to drop a claim to get under a number, which is
# worse than the long page it was trying to prevent. So every count here is a WARN and names
# the part that overspent, while the rules that fail are the ones a run cannot satisfy by
# deleting evidence — a primer that belongs to --full, a flow carrying section 1's
# before/after pair, and a field compressed into its own label.
#
# WHAT IT DOES NOT COUNT is half the reason a word count is a fair measure here, and the
# exemptions are listed once, in EXEMPT, rather than per rule. Figures are exempt entirely —
# every <svg>, its figcaption, its legend, the .pipe spine's labels and the .impact panel's
# boxes — because the budget must never be answerable by dropping or trimming a drawing.
# Commands and quotations are exempt because they are bytes: shortening a validation step
# invents one. Collapsed <details> is exempt because it is not reading length, which is only
# safe because SKILL.md's hard rule already makes a shut page a complete one.
#
# It counts words over the JOINED text rather than line by line, which is the one place this
# directory's line-oriented habit does not carry: a <dd> is prose that wraps, and a rule
# about how long it is has to see it whole. Region finding is still line-oriented, so the
# region vocabulary in lib/review_map/page.rb is unchanged.
#
# What no script can settle, and what the eval case is for: whether the half that came out
# was the half nobody needed. A page can sit inside every number here and still have spent
# its words on the wrong sentences.

require_relative "lib/review_map/check"

FIXED_WORDS    = 950   # sections 1 and 3 and the merged tail
PER_FLOW_WORDS = 440   # each written behaviour flow

CAPS = {
  mech:        45,
  field:       35,
  understand:  60,
  decision:    45,
  begin_entry: 40,
  cc_row:      30,
}.freeze

FLOOR_WORDS = 4

# Regions a word count must not see. Order matters only in that comments go first, so a
# comment discussing a class name cannot steer any pattern below it.
EXEMPT = [
  /<!--.*?-->/m,
  %r{<script\b.*?</script>}m,
  %r{<style\b.*?</style>}m,
  %r{<svg\b.*?</svg>}m,
  %r{<figcaption\b.*?</figcaption>}m,
  %r{<details\b.*?</details>}m,
  %r{<pre\b.*?</pre>}m,
  %r{<code\b.*?</code>}m,
  %r{<div class="legend".*?</div>}m,
  %r{<div class="ip-lanes".*?</div>}m,
  %r{<li class="ip-n\b.*?</li>}m,
  %r{<span class="ip-hd".*?</span>}m,
  %r{<div class="pipe".*?</ol>}m,
].freeze

def words(page)
  text = page.lines.join
  EXEMPT.each { |pattern| text = text.gsub(pattern, " ") }
  text = ReviewMap.unescape(text.gsub(/<[^>]*>/m, " "))
  text.gsub(/&[a-zA-Z]+;|&#\d+;/, " ").split(/\s+/).count { |w| w.match?(/[[:alnum:]]/) }
end

# Everything from each line matching `on` up to the next one, which is what a run of sibling
# blocks with nested <div>s needs — .decision closes on a </div> that three of its own
# children also emit, so the region scanner cannot find its end.
def chunks(page, on:)
  found = []
  page.lines.each do |line|
    found << [] if line.match?(on)
    found.last << line if found.any?
  end
  found.map { |ls| ReviewMap::Page.new(ls) }
end

# A field's own words, and whether the floor applies to it. A <dd> holding only commands or
# only a collapsed excerpt measures zero by design — the field carries evidence rather than
# prose — so the floor has to stand aside for it or it fails every Validate row on the page.
def fields(region)
  grids = region.narrow(open: /<dl class="rows"/, close: %r{</dl>})
  out = []
  label = nil
  current = nil
  grids.lines.each do |line|
    if (m = line.match(%r{<dt>([^<]*)</dt>}))
      label = m[1].strip
    end
    current = [] if line.match?(/<dd[\s>]/) && current.nil?
    next if current.nil?

    current << line
    next unless line.match?(%r{</dd>})

    out << [label, ReviewMap::Page.new(current)]
    current = nil
  end
  out
end

check = ReviewMap::Check.new(ARGV)
check.require_input

unless check.level == "brief"
  check.skip("nothing measured: the word budget belongs to --brief, and this input was graded at --level #{check.level}")
  check.finish
end

page = check.page.without_comments
flows = page.regions(open: /<section id="flow-/, close: %r{</section})
written = flows.select { |f| f.has?(/class="mech"/) }

# --- Shape. The two concepts whose removal is structural, so a page either carries them or
# does not and there is nothing to weigh.
primers = page.count(/class="primer/)
if primers.zero?
  check.ok("no aside.primer, which is right at --brief: the callout belongs to --full and the flow keeps the pinned doc link it would have escalated from")
else
  check.bad("#{primers} framework primer(s) at --brief — the heaviest component carrying no evidence of its own belongs to --full; keep the a.doc link and explain the mechanism in the flow's own prose")
end

ba_in_flows = written.count { |f| f.has?(/<dl class="ba"/) }
if written.empty?
  check.skip("no written behaviour flow in this input, so the flow rules — the dl.ba pair, the field caps and the field floor — had nothing to read")
elsif ba_in_flows.zero?
  check.ok("no flow carries a dl.ba pair, which is right at --brief: section 1 holds the page's one before/after block")
else
  check.bad("#{ba_in_flows} flow(s) carry a dl.ba before/after pair at --brief — section 1 already states the transition, and the flow's own belongs in its .mech")
end

# --- The floor. The one length rule that fails, because it is the one where a smaller
# number means a deleted claim rather than a tighter sentence.
short = []
written.each_with_index do |flow, i|
  fields(flow).each do |label, dd|
    next if dd.has?(/<code|<pre|<details/)

    count = words(dd)
    short << "#{label.to_s.empty? ? "an unlabelled field" : label} in flow #{i + 1} (#{count} word#{"s" unless count == 1})" if count < FLOOR_WORDS
  end
end
if written.empty?
  # Nothing: the SKIP above already says the flow rules could not run, and saying it twice
  # would make one absence read as two verified rules.
elsif short.empty?
  check.ok("no field is compressed into its own label: every prose <dd> in the flows carries at least #{FLOOR_WORDS} words")
else
  check.bad("field(s) compressed into their own label — #{short.join("; ")}. A <dd> this short is a deleted field with the <dt> left behind, and in the 132px gutter it reads like a filled one. Omit the field instead")
end

# --- The caps. Every one of these warns.
def cap(check, kind, label, count)
  limit = CAPS.fetch(kind)
  return if count <= limit

  check.maybe("#{label} runs to #{count} words against a cap of #{limit} — report-format.md § The brief budget")
end

over = 0
written.each_with_index do |flow, i|
  flow.regions(open: /class="mech"/, close: %r{</div>}).each do |mech|
    count = words(mech)
    over += 1 if count > CAPS[:mech]
    cap(check, :mech, "flow #{i + 1}'s .mech", count)
  end

  fields(flow).each do |label, dd|
    kind = label.to_s.downcase.start_with?("understand") ? :understand : :field
    count = words(dd)
    over += 1 if count > CAPS[kind]
    cap(check, kind, "flow #{i + 1}'s #{label} field", count)
  end

  decisions = flow.from(/class="decisions"/, stop: %r{</section})
  chunks(decisions, on: /class="decision"/).each_with_index do |decision, d|
    count = words(decision)
    over += 1 if count > CAPS[:decision]
    cap(check, :decision, "flow #{i + 1}'s decision #{d + 1}", count)
  end
end

page.narrow(open: /<ol class="begin"/, close: %r{</ol>})
    .regions(open: /<li[\s>]/, close: %r{</li>})
    .each_with_index do |entry, i|
  count = words(entry)
  over += 1 if count > CAPS[:begin_entry]
  cap(check, :begin_entry, "start-here entry #{i + 1}", count)
end

# The cells and the block both close on </div>, so a range terminator cannot tell them
# apart — the region ends at the next heading or section instead. Narrowing at all is what
# keeps the coverage foot's .gt-paths cells, which are paths and not prose, out of this.
page.from(/class="gt-ripple"/, stop: %r{<h3|</section}, stop_after: 1)
    .lines.each_with_index do |line, i|
  next unless line.match?(/<div class="c"/)

  count = words(ReviewMap::Page.new([line]))
  over += 1 if count > CAPS[:cc_row]
  cap(check, :cc_row, "cross-cutting cell #{i + 1}", count)
end

if over.positive?
  # The WARNs above already name each one.
elsif written.empty? && page.count(/<ol class="begin"/).zero? && !page.has?(/class="gt-ripple"/)
  check.skip("no capped component in this input: no written flow, no start-here list and no cross-cutting rows to measure")
else
  check.ok("every component is inside its word cap")
end

# --- The ceiling, which is a whole-page question and only on a finished page: a draft is
# mid-write by definition, and a stage that has not written the flows yet would pass it for
# the wrong reason.
total = words(page)
if check.kind != "page"
  check.skip("no page ceiling on a fragment: #{total} visible words here, but the ceiling is #{FIXED_WORDS} plus #{PER_FLOW_WORDS} a flow across the whole page")
elsif check.mode != "final"
  check.skip("no page ceiling on a #{check.mode} page: it is mid-write, and its #{total} visible words are not the finished total")
else
  ceiling = FIXED_WORDS + (PER_FLOW_WORDS * written.size)
  if total <= ceiling
    check.ok("#{total} visible words against a ceiling of #{ceiling} (#{FIXED_WORDS} + #{PER_FLOW_WORDS} × #{written.size} flow(s))")
  else
    check.maybe("#{total} visible words against a ceiling of #{ceiling} (#{FIXED_WORDS} + #{PER_FLOW_WORDS} × #{written.size} flow(s)) — #{total - ceiling} over. The caps above name which part, and none of the overspend is a figure: every svg, figcaption, legend, .pipe label and .impact box is exempt from this count")
  end
end

check.finish
