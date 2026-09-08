#!/usr/bin/env ruby
# frozen_string_literal: true

# impact-paths.rb — the section 4 figure, and the only check that reads inside it.
#
# THE DIVISION WITH reach.rb: that file asks whether the SECTION is composed right and
# reports a missing panel. This file asks whether the FIGURE is right, and skips when there is
# no panel — so a missing figure is one FAIL, not two.
#
# A path runs from changed code, through the affected-but-unchanged code that gives the change
# its consequence, to an observable behaviour. What it replaced was a .blast box grid whose
# only encoding was border style, so it carried membership of two sets and nothing else, and
# the one relation it could not draw is the one this section is about. Real pages then wrote
# the missing relation into the boxes as prose, and the figure became a grid of sentences with
# no edges. Every rule below is aimed at one of those two failures returning: an edge with no
# label, or a node with a paragraph in it.
#
# WHY THE VERDICTS SPLIT WHERE THEY DO. Shape is a FAIL: a path that never reaches a behaviour,
# or never passes through unchanged code, is not an impact path, and no reading of it is. The
# causal verb is a WARN, because the vocabulary in report-format.md § Impact paths cannot
# anticipate every stack and a hard failure would teach a run to mislabel an edge to satisfy
# the check — which is worse than an unlisted verb that is true. Length is a WARN for the same
# reason: "too long" is a judgement, and the judged expectations in cases/diagrams.json are
# where it is actually settled.
#
# What needs a reader, and no script can supply: whether these are the RIGHT 2-3 paths, and
# whether each edge is true. A panel can satisfy every rule here and still describe a
# consequence that does not happen.

require_relative "lib/review_map/check"

ANCHOR = /id="reach"/
SUBPART = /id="crosscutting"|id="approving"/

# Prefix matches throughout, never class="impact" exactly. class="impact impact--x" does not
# match class="impact", and a rule about a component that silently skips its own variant is
# the defect this repository keeps writing down.
PANEL_OPEN  = /<figure class="impact/
PANEL_CLOSE = %r{</figure>}
PATH_OPEN   = /<ol class="ip-path/
PATH_CLOSE  = %r{</ol>}
CARD_OPEN   = /<div class="ip-card/
CARD_LANES  = /<div class="ip-lanes/
NODE_OPEN   = /<li[^>]*class="ip-n/
NODE_CLOSE  = %r{</li>}

KINDS = { "ip-chg" => :changed, "ip-aff" => :affected, "ip-out" => :outcome }.freeze

# The causal vocabulary, matched on the label's FIRST word so a relation may carry an object:
# "falls back to", "receives proficiency from", "filtered out by".
#
# PASSIVE FORMS ARE IN IT DELIBERATELY. A label reads from the node ABOVE to the node BELOW,
# and half the edges on this page run producer-to-consumer, where the honest verb is passive:
# a changed column is "read by" the query below it, not the other way round. Without them a
# run has to invert the pair to find an active verb, which puts the consumer above the thing
# it consumes and quietly reverses the figure. "ignored by" is the same case one step further
# on, and it is the label for the commonest finding this page carries — a consumer that does
# NOT account for what changed, which is causal even though nothing happens.
#
# Extend this list and report-format.md § Impact paths together — the rule diagram.rb states
# for its class vocabulary, and for the same reason: a verb here but not there is
# undocumented, and one there but not here is reported as unlisted.
CAUSAL = %w[calls reads writes passes returns defaults falls filters filtered scopes
            renders builds produces serializes receives enqueues broadcasts causes
            read called rendered ignored].freeze

MAX_REL_WORDS = 5
MAX_LABEL_CHARS = 40
MAX_DETAIL_WORDS = 10

def text_of(node, pattern)
  m = node.lines.join(" ").match(pattern)
  return nil unless m

  ReviewMap.unescape(m[1].gsub(/<[^>]*>/, "")).strip
end

Node = Struct.new(:kind, :rel, :label, :detail) do
  def lane = kind == :affected ? 2 : 1
end

def nodes_in(path)
  path.regions(open: NODE_OPEN, close: NODE_CLOSE).map do |node|
    body = node.lines.join(" ")
    kind = KINDS.find { |cls, _| body.match?(/class="[^"]*#{cls}/) }&.last
    Node.new(kind,
              text_of(node, /class="ip-rel"[^>]*>(.*?)<\/span>/m),
              text_of(node, /<b>(.*?)<\/b>/m),
              text_of(node, /class="ip-d"[^>]*>(.*?)<\/span>/m))
  end
end

check = ReviewMap::Check.new(ARGV)
check.require_input

# A comment is not markup. page-template.html's own header comments discuss these very class
# names and ship verbatim inside every published page.
source = check.page.without_comments
region =
  if source.has?(ANCHOR)
    source.from(ANCHOR, stop: lambda { |line|
      (line.match?(/<section /) && !line.match?(ANCHOR)) || line.match?(SUBPART)
    })
  else
    source
  end

panels = region.regions(open: PANEL_OPEN, close: PANEL_CLOSE)

# SKIP, not PASS. reach.rb is what fails a section 4 with no panel; this check has nothing to
# read and says so, because a check that reports a pass on an input it never looked at is the
# failure mode this whole suite is built against.
if panels.empty?
  check.skip("no .impact panel in this input — reach.rb is what reports a section 4 missing one")
  check.finish
  exit
end

if panels.size == 1
  check.ok("one impact panel")
else
  check.bad("#{panels.size} .impact panels in section 4 — the panel IS the section's one figure, and a second competes with it for the same reading")
end

panel = panels.first
paths = panel.regions(open: PATH_OPEN, close: PATH_CLOSE)

# 2-3 paths. A single path is a chain, not a synthesis view, and the section's whole claim is
# that separately-explained flows reach the same unchanged code. The ceiling was 5, and a real
# page took all five: at that length the panel is a section to scroll rather than a figure to
# hold, and the consequences that do not fit are not lost — the affected list below carries
# their entries and the flow that owns each one carries its explanation.
if paths.empty?
  check.bad("an .impact panel with no ol.ip-path — a panel with no paths is the box grid this component replaced")
  check.finish
  exit
elsif paths.size.between?(2, 3)
  check.ok("#{paths.size} impact paths, within the 2-3 budget")
else
  check.bad("#{paths.size} impact path(s) — the budget is 2 to 3 (report-format.md § Impact paths). Wanting a fourth is the signal that the ones you have are not doing their job")
end

# --- One path per card, which is what makes them separate diagrams rather than one panel with
# headings in it. This is checked as a PAIRING and not as "a card exists", because the defect it
# guards against looks very nearly right: two paths inside one .ip-card still draw, still align to
# that card's lane rule, and still carry their own .ip-hd — they are the stacked panel back again,
# in a component that has since been sized on the assumption that a card is one figure.
#
# Interleaving rather than two counts. Equal counts are satisfied by a card holding two paths
# beside a card holding none, and the second of those is an empty box a reader stops at.
sequence = panel.scan(/#{CARD_OPEN}|#{PATH_OPEN}/).map { |m| m.match?(CARD_OPEN) ? :card : :path }
cards = sequence.count(:card)
if sequence == ([:card, :path] * paths.size)
  check.ok("each of the #{paths.size} paths sits alone in its own .ip-card")
else
  check.bad("#{cards} .ip-card(s) do not pair one-to-one with #{paths.size} ol.ip-path — one path per card. Paths stacked inside one card are the panel this replaced, where the reader on the third chain has the first one's geometry behind them")
end

# Each card carries its OWN lane labels. This is the one requirement the split introduced that a
# run is likely to get wrong from the outside: one .ip-lanes above one panel was correct for as
# long as there was one panel, and the mental model survives the change while the markup does not.
# A card without them draws a rule down its middle with nothing naming either side.
#
# Clamped at zero rather than a signed difference, so this rule ABSTAINS when the pairing above
# has already failed. A card holding two paths carries a spare .ip-hd and a spare set of labels,
# and reporting that as surplus furniture would be one defect reported as two — with the second
# message counting backwards.
bare = [cards - panel.scan(CARD_LANES).size, 0].max
if cards.positive? && bare.zero?
  check.ok("every card carries its own lane labels")
else
  check.bad("#{bare} .ip-card(s) with no .ip-lanes of their own — a separated card is a whole figure, and a reader arriving at the third one has nothing above it saying which column is the change and which is the existing system")
end

all = paths.map { |p| nodes_in(p) }

# --- Shape, per path. Aggregated per rule rather than per path: five paths times seven rules
# is 35 lines nobody reads, and the offending path is named in the message either way.

def label_paths(idx) = idx.map { |i| "path #{i + 1}" }.join(", ")

bad_len = all.each_index.reject { |i| all[i].size.between?(3, 5) }
if bad_len.empty?
  check.ok("every path is 3-5 nodes")
else
  check.bad("#{label_paths(bad_len)} outside the 3-5 node budget (#{bad_len.map { |i| all[i].size }.join(', ')})")
end

unknown = all.each_index.select { |i| all[i].any? { |n| n.kind.nil? } }
if unknown.empty?
  check.ok("every node carries one of .ip-chg, .ip-aff, .ip-out")
else
  check.bad("#{label_paths(unknown)} carries a node with no kind class — without one the node has no lane and no border, so the reader cannot tell changed from unchanged")
end

bad_start = all.each_index.reject { |i| all[i].first&.kind == :changed }
if bad_start.empty?
  check.ok("every path starts at changed code")
else
  check.bad("#{label_paths(bad_start)} does not start at an .ip-chg node — a path begins in the diff, or it is not this change's impact")
end

bad_end = all.each_index.reject do |i|
  outs = all[i].count { |n| n.kind == :outcome }
  outs == 1 && all[i].last.kind == :outcome
end
if bad_end.empty?
  check.ok("every path ends at exactly one observable behaviour")
else
  check.bad("#{label_paths(bad_end)} does not end at exactly one .ip-out — a chain that stops at a function has not reached a consequence, and the consequence is why the figure exists")
end

no_aff = all.each_index.reject { |i| all[i].any? { |n| n.kind == :affected } }
if no_aff.empty?
  check.ok("every path passes through affected-but-unchanged code")
else
  check.bad("#{label_paths(no_aff)} contains no .ip-aff node — a path with no unchanged node is a call stack inside the diff, which the diff already shows. Unchanged-but-affected code is what this page is for")
end

# --- Edges. The label is the component's first-class part, so a missing one is a missing
# element rather than an empty attribute, and that is exactly what makes it checkable.

missing = all.each_index.select { |i| all[i].drop(1).any? { |n| n.rel.to_s.empty? } }
if missing.empty?
  check.ok("every edge carries a label")
else
  check.bad("#{label_paths(missing)} has a node past the first with no .ip-rel — an unlabelled edge is adjacency again, which is the thing the box grid could not get past")
end

leading = all.each_index.select { |i| !all[i].first&.rel.to_s.empty? }
if leading.empty?
  check.ok("no path labels an edge into its first node")
else
  check.bad("#{label_paths(leading)} puts an .ip-rel on its FIRST node — a path's first node has nothing upstream of it, so the label names an edge that is not in the figure")
end

rels = all.flatten.map(&:rel).compact.reject(&:empty?)

wordy = rels.reject { |r| r.split.size <= MAX_REL_WORDS && !r.match?(/[.;]\s*\z/) }
if wordy.empty?
  check.ok("every edge label is a label, not a sentence")
else
  check.bad("#{wordy.size} edge label(s) over #{MAX_REL_WORDS} words or ending in punctuation: #{wordy.map(&:inspect).join(', ')} — an edge carries a verb, and the clause belongs to the affected list below")
end

unlisted = rels.reject { |r| CAUSAL.include?(r.split.first.to_s.downcase) }
if unlisted.empty?
  check.ok("every edge label leads with a causal verb from the vocabulary")
else
  check.maybe("#{unlisted.size} edge label(s) lead with a verb outside the vocabulary: #{unlisted.map(&:inspect).join(', ')} — legitimate for a stack the list does not cover, but extend report-format.md § Impact paths and CAUSAL here together if so")
end

# --- Labels, not sentences. This is image-one's defect: the box grid's boxes each carried a
# clause, which is how a figure became a word cloud.

long_labels = all.flatten.select { |n| n.label.to_s.length > MAX_LABEL_CHARS }
long_details = all.flatten.select { |n| n.detail.to_s.split.size > MAX_DETAIL_WORDS }
if long_labels.empty? && long_details.empty?
  check.ok("nodes carry labels rather than prose")
else
  check.maybe("#{long_labels.size} node label(s) over #{MAX_LABEL_CHARS} chars and #{long_details.size} detail line(s) over #{MAX_DETAIL_WORDS} words — a node names a thing, and the panel this replaced became unreadable by holding a clause in every box")
end

# Lane crossings, over the code nodes only: an .ip-out spans both lanes, so arriving at one is
# never a crossing. WARN, because "one or two interactions" is a judgement about emphasis.
crossings = all.each_index.select do |i|
  lanes = all[i].reject { |n| n.kind == :outcome }.map(&:lane)
  lanes.each_cons(2).count { |a, b| a != b } > 2
end
if crossings.empty?
  check.ok("no path crosses the lane boundary more than twice")
else
  check.maybe("#{label_paths(crossings)} crosses between changed and unchanged more than twice — the point is the one or two interactions that carry the consequence")
end

# --- What must not be in the panel at all.

if panel.has?(/<svg/)
  check.bad("an <svg> inside the .impact panel — the panel is a component because its size is a function of the diff; a drawing means geometry derived per run")
else
  check.ok("the panel is a component, not a drawing")
end

# Citations live in the affected list. Keeping them out is what stops the panel growing back
# into a second copy of that list, and it is also why reach.rb can drop the panel before its
# own entry census without losing anything.
if panel.has?(/class="(?:path|cite)"/)
  check.bad("a citation inside the .impact panel — the file:line belongs to the affected list below, which is the one canonical home for it")
else
  check.ok("no citations inside the panel")
end

placeholders = panel.scan(/\{\{[A-Z_|]+\}\}/).uniq
if placeholders.empty?
  check.ok("no unsubstituted placeholders in the panel")
else
  check.bad("#{placeholders.size} unsubstituted placeholder(s) in the panel: #{placeholders.join(', ')} — the template was copied and not filled in")
end

# --- The legend. Three kinds now, and a dashed node with nothing explaining it reads as
# DELETED, which is the opposite of "unchanged, and therefore worth reading".
if panel.has?(/class="legend"/)
  keys = %w[key-chg key-aff key-out].reject { |k| panel.has?(/class="#{k}"/) }
  if keys.empty?
    check.ok("the panel carries a legend naming all three node kinds")
  else
    check.bad("the legend is missing #{keys.join(', ')} — every kind the panel draws has to be named, or the reader is left to guess which border means what")
  end
else
  check.bad("an .impact panel with no .legend — dashed-means-unchanged has to be stated, or it reads as deleted")
end

check.finish
