#!/usr/bin/env ruby
# frozen_string_literal: true

# figures.rb — the figures inside a checkpoint, and the only check that reads them.
#
# FOUR KINDS, ONE PER CHECKPOINT AT MOST. figure.chain draws mechanism inside the change;
# figure.converge, .lifecycle and .structure draw the three shapes a chain cannot, because a
# chain has one successor per node: several paths onto one invariant, states and the actions
# between them, an entity and its relationships. report-format.md § Figures owns when each is
# earned, and NOTHING HERE CAN TELL WHETHER ONE WAS — whether the shape is the judgment's real
# shape, whether the edges are true, whether zero would have been better. What a script can
# hold is the shape, the locators, and the two rules that keep a figure from saying something
# the page has no right to say.
#
# Nothing graded a checkpoint chain before this. impact-paths.rb scopes itself inside
# figure.impact on purpose, and tests/run.sh checks only the template — so a published page
# could put an .ip-aff in a chain, which is the canonical-home regression arriving as a figure,
# and no check would have read it.
#
# WHY THE VERDICTS SPLIT WHERE THEY DO, which is impact-paths.rb's split for its reason. Shape is
# a FAIL: a converge with one path is a chain, a lifecycle with an unchanged node has said a
# state is a file, a figure with two locators on a box has put a citation where a label goes.
# Words are a WARN: an unlisted verb, a transition named after a callback, a note that leans on
# the reader. A hard failure there teaches a run to rename a true edge to get past the check.
#
# TWO WARNINGS ARE ABOUT WHAT THE FIGURE CLAIMS RATHER THAN HOW IT IS DRAWN, and both are the
# reason this check exists rather than a footnote in tests/run.sh.
#
#   A converge with no recorded search on the page. The figure's list implicitly claims to be
#   ALL the writers of its invariant, and it looks most complete when it is most wrong, because
#   the missing path is the defect. Only a recorded writer search makes that claim checkable.
#   It is a WARN because the search lives in the foot and a fragment cannot see it.
#
#   A .cv-note that grades. It is a free-text slot on a node — the third place on this page a
#   severity word can get in, after GAP and Open question, and the only one with no fixed label.
#   It says what the path skips. Why that matters is the checkpoint's to say.

require_relative "lib/review_map/check"
require_relative "lib/review_map/vocabulary"

KINDS_DRAWN = %w[chain converge lifecycle structure].freeze
CP_OPEN  = /<section class="cp/
CP_CLOSE = %r{</section>}
# Any figure in a checkpoint, by its FIRST class — a variant class must not hide a kind.
FIGURE   = %r{<figure class="([^" ]+)[^"]*"[^>]*>(.*?)</figure>}m
LOC      = /class="path ip-loc"/
ITEM     = %r{<li\b[^>]*class="([^"]*)"[^>]*>(.*?)</li>}m

NODE_CAPS = { "chain" => 3..5, "converge" => 2..7, "lifecycle" => 2..5, "structure" => 1..4 }.freeze
MAX_FIELDS = 3
MAX_BACK = 2
MAX_NOTE_WORDS = 6

# A note that tells the reader how to feel about the path rather than what it skips.
GRADING = /\b(?:attention|risk(?:y)?|careful|important|critical|dangerous|severe|serious|must review|watch out)\b/i

# A transition labelled with the hook rather than the action: after_destroy, archive!, #disown,
# confirm_ownership(). The domain action is the label and the method is what the locator is for.
METHOD_NAME = /\A(?:[#.:]?[a-z][a-z0-9]*(?:_[a-z0-9]+)+[!?]?|[#.:]?[a-z][a-z0-9_]*[!?]|[#.:][a-z][a-z0-9_]*|[a-z][a-z0-9_]*\(\))\z/

def text(html) = ReviewMap.unescape(html.to_s.gsub(/<[^>]*>/, " ")).split.join(" ")
def first_word(html) = text(html).split.first.to_s.downcase
def kind_of(classes) = classes.split.find { |c| c.start_with?("ip-") && c != "ip-n" }

check = ReviewMap::Check.new(ARGV)
check.require_input

source = check.page.without_comments
checkpoints = source.regions(open: CP_OPEN, close: CP_CLOSE)
# A fragment written as one checkpoint's figure and nothing around it is still one checkpoint.
checkpoints = [source] if checkpoints.empty? && check.kind == "fragment"

figures = []
checkpoints.each_with_index do |cp, i|
  html = cp.lines.join
  id = html[/<section class="cp[^"]*" id="([^"]+)"/, 1] || "checkpoint #{i + 1}"
  # figure.impact is section 04's and impact-paths.rb grades it; it only reaches here through a
  # fragment with no checkpoint around it.
  found = html.scan(FIGURE).reject { |kind, _| kind == "impact" }.map { |kind, body| [id, kind, body] }
  if found.size > 1
    check.bad("#{id} carries #{found.size} figures (#{found.map { |_, k, _| k }.join(', ')}) — one per checkpoint, of any kind, because two figures for one judgment are two answers to which shape it has")
  end
  figures.concat(found)
end

if figures.empty?
  if check.kind == "page"
    check.ok("no checkpoint carries a figure — a valid result, and most checkpoints earn none")
  else
    check.skip("no checkpoint figure in this input")
  end
  check.finish
  exit
end

check.ok("at most one figure per checkpoint") if figures.group_by(&:first).values.none? { |fs| fs.size > 1 }

page_has_search = source.has?(/<details class="searched/)

figures.each do |id, kind, body|
  where = "#{id}'s #{kind}"
  faults = []

  unless KINDS_DRAWN.include?(kind)
    check.bad("#{where}: figure.#{kind} is not a checkpoint figure — the four are #{KINDS_DRAWN.join(', ')}, and figure.impact lives in section 04")
    next
  end

  faults << "an <svg> — this page has no drawings" if body.include?("<svg")
  faults << "a data-path — that attribute is the inventory's, and coverage-gate.sh greps it page-wide" if body.include?("data-path")
  faults << "no figcaption saying what the figure answers" unless body.include?("<figcaption")
  holes = body.scan(/\{\{[A-Z_|]+\}\}/).uniq
  faults << "#{holes.size} unsubstituted placeholder(s): #{holes.join(', ')}" unless holes.empty?

  case kind
  when "chain"
    nodes = body.scan(ITEM).select { |cls, _| cls.split.include?("ip-n") }
    faults << "#{nodes.size} nodes — a chain is #{NODE_CAPS['chain'].minmax.join('–')}" unless NODE_CAPS["chain"].cover?(nodes.size)
    nodes.each_with_index do |(cls, inner), n|
      k = kind_of(cls)
      faults << "node #{n + 1} is .ip-aff — a hop into unchanged code whose meaning the change altered is an impact path, drawn once in section 04" if k == "ip-aff"
      faults << "node #{n + 1} has an unknown kind" unless %w[ip-chg ip-step ip-out ip-aff].include?(k)
      rel = inner[%r{class="ip-rel"[^>]*>(.*?)</span>}m, 1]
      faults << "node 1 carries a relation — the first node has nothing incoming" if n.zero? && rel
      faults << "node #{n + 1} has no .ip-rel — an edge is labelled or it is missing" if n.positive? && rel.nil?
      if rel && !ReviewMap::CAUSAL.include?(first_word(rel))
        check.maybe("#{where} node #{n + 1}: \"#{text(rel)}\" is outside the causal vocabulary in report-format.md § Impact paths")
      end
      locs = inner.scan(LOC).size
      faults << "node #{n + 1} (.ip-chg) has #{locs} locators — it needs exactly one" if k == "ip-chg" && locs != 1
      faults << "node #{n + 1} (.ip-out) carries a locator — a behaviour is not in a file" if k == "ip-out" && locs.positive?
    end
    outs = nodes.each_index.select { |n| kind_of(nodes[n][0]) == "ip-out" }
    faults << "it does not end at exactly one .ip-out" unless outs == [nodes.size - 1]

  when "converge"
    paths = body.scan(ITEM).select { |cls, _| cls.split.include?("ip-n") }
    faults << "#{paths.size} path(s) — a converge is #{NODE_CAPS['converge'].minmax.join('–')}, and one path is a chain" unless NODE_CAPS["converge"].cover?(paths.size)
    faults << "an .ip-rel between paths — they are siblings, not a sequence, and a connector fires the impact panel's lane crossing" if body.include?('class="ip-rel"')
    paths.each_with_index do |(cls, inner), n|
      k = kind_of(cls)
      faults << "path #{n + 1} is neither .ip-chg nor .ip-aff" unless %w[ip-chg ip-aff].include?(k)
      locs = inner.scan(LOC).size
      faults << "path #{n + 1} has #{locs} locators — a writer is a line in a file, exactly one" unless locs == 1
      note = inner[%r{class="cv-note"[^>]*>(.*?)</span>}m, 1]
      next unless note

      words = text(note).split.size
      check.maybe("#{where} path #{n + 1}: a #{words}-word note — it says what the path skips, in a few words, and the checkpoint says the rest") if words > MAX_NOTE_WORDS
      if (hit = text(note)[GRADING])
        check.maybe("#{where} path #{n + 1}: \"#{hit}\" in a .cv-note — a note says what the path skips, never how much it matters")
      end
    end
    targets = body.scan(%r{<div class="cv-target"[^>]*>(.*?)</div>}m)
    faults << "#{targets.size} .cv-target(s) — exactly one invariant" unless targets.size == 1
    faults << "a locator on the target — an invariant is a property, not a file" if targets.any? { |(t)| t.match?(LOC) }
    if check.kind == "page" && !page_has_search
      check.maybe("#{where}: no details.searched on the page — a converge claims its paths are all the writers, and only a recorded search makes that claim checkable")
    end

  when "lifecycle"
    states = body.scan(ITEM).select { |cls, _| cls.split.include?("lc-s") }
    faults << "#{states.size} state(s) — a lifecycle is #{NODE_CAPS['lifecycle'].minmax.join('–')}" unless NODE_CAPS["lifecycle"].cover?(states.size)
    faults << "an .ip-aff node — a state is not a file, so unchanged-code has nothing to mean here" if body.match?(/class="[^"]*\bip-aff\b/)
    states.each_with_index do |(_, inner), n|
      rel = inner[%r{class="ip-rel"[^>]*>(.*?)</span>}m, 1]
      faults << "state 1 carries a transition — it is where the lifecycle starts" if n.zero? && rel
      next if n.zero?

      if rel.nil?
        faults << "state #{n + 1} has no incoming transition"
        next
      end
      faults << "the transition into state #{n + 1} has no locator — the line that performs it is what shows whether it is guarded" unless rel.scan(LOC).size == 1
      label = text(rel.sub(%r{<a\b.*?</a>}m, ""))
      if label.match?(METHOD_NAME)
        check.maybe("#{where}: the transition into state #{n + 1} is labelled \"#{label}\" — name the domain action, and leave the method to the locator")
      end
    end
    backs = body.scan(%r{<p class="lc-back"[^>]*>(.*?)</p>}m)
    faults << "#{backs.size} back transitions — two at most, or the lifecycle is a graph this figure cannot draw" if backs.size > MAX_BACK
    faults << "a back transition with no locator" if backs.any? { |(b)| !b.match?(LOC) }

  when "structure"
    head = body.split('<ul class="st-edges"').first.to_s
    focal = head[%r{<div class="ip-n ([^"]*)"[^>]*>(.*)</div>}m, 2]
    if focal.nil?
      faults << "no focal entity above the relationships"
    else
      faults << "the focal entity is not .ip-chg — the figure is about what this change made or altered" unless head.match?(/<div class="ip-n ip-chg/)
      faults << "the focal entity needs exactly one locator" unless focal.scan(LOC).size == 1
      fields = focal[%r{<ul class="st-fields"[^>]*>(.*?)</ul>}m, 1].to_s.scan(/<li\b/).size
      faults << "#{fields} fields — at most #{MAX_FIELDS}, the ones the behaviour turns on, never the table" if fields > MAX_FIELDS
    end
    edges = body.scan(ITEM).select { |cls, _| cls.split.include?("st-e") }
    faults << "#{edges.size} relationship(s) — a structure is #{NODE_CAPS['structure'].minmax.join('–')}, and a whole schema is the ERD this figure refuses" unless NODE_CAPS["structure"].cover?(edges.size)
    edges.each_with_index do |(cls, inner), n|
      faults << "relationship #{n + 1}: the entity at the other end is neither .ip-chg nor .ip-aff" unless %w[ip-chg ip-aff].include?(kind_of(cls))
      faults << "relationship #{n + 1} has no .st-rel naming it" unless inner.include?('class="st-rel"')
      faults << "relationship #{n + 1} has #{inner.scan(LOC).size} locators — exactly one, on the line that declares it or on the entity" unless inner.scan(LOC).size == 1
    end
  end

  if faults.empty?
    check.ok("#{where} holds its shape and carries its locators")
  else
    check.bad("#{where}: #{faults.join('; ')}")
  end
end

check.finish
