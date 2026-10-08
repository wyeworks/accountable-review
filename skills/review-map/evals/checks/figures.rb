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
#
# AND ONE FIGURE THAT IS NOT A CHECKPOINT'S. figure.lifecycle.lc-shift is Context's — the request
# sequence before and after, drawn once because several checkpoints stand on it. This check reads
# section 02 for it, because before it did, a figure arriving there was the one on the page nothing
# looked at. Its rules are the lifecycle's twice plus the three that make the comparison true: the
# columns start at the same state, exactly one state is lc-moved in each with the same label, and
# it sits at a different position — a shift where nothing moved has drawn one list twice. The
# cases that differ and the two-checkpoint earning test are WARNs: both are about what the figure
# claims, and a page may honestly have one case and a draft may point at a stub.

require_relative "lib/review_map/check"
require_relative "lib/review_map/vocabulary"

KINDS_DRAWN = %w[chain converge lifecycle structure].freeze
CP_OPEN  = /<section class="cp/
CP_CLOSE = %r{</section>}
# Any figure, by its FIRST class — a variant class must not hide a kind. The variants follow it.
FIGURE   = %r{<figure class="([^" ]+)([^"]*)"[^>]*>(.*?)</figure>}m
CONTEXT  = /<section id="context"/
SHIFT    = "lc-shift"
MAX_CASES = 4
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

# One column of states: the lifecycle's own rules, shared by the plain figure and by each column
# of the shift. Returns the states so the shift can compare its two columns.
def lifecycle_states(check, where, body, faults, label: "")
  states = body.scan(ITEM).select { |cls, _| cls.split.include?("lc-s") }
  faults << "#{label}#{states.size} state(s) — a lifecycle is #{NODE_CAPS['lifecycle'].minmax.join('–')}" unless NODE_CAPS["lifecycle"].cover?(states.size)
  states.each_with_index do |(_, inner), n|
    rel = inner[%r{class="ip-rel"[^>]*>(.*?)</span>}m, 1]
    faults << "#{label}state 1 carries a transition — it is where the lifecycle starts" if n.zero? && rel
    next if n.zero?

    if rel.nil?
      faults << "#{label}state #{n + 1} has no incoming transition"
      next
    end
    faults << "#{label}the transition into state #{n + 1} has no locator — the line that performs it is what shows whether it is guarded" unless rel.scan(LOC).size == 1
    name = text(rel.sub(%r{<a\b.*?</a>}m, ""))
    if name.match?(METHOD_NAME)
      check.maybe("#{where}: #{label}the transition into state #{n + 1} is labelled \"#{name}\" — name the domain action, and leave the method to the locator")
    end
  end
  states
end

def state_label(inner) = text(inner[%r{<span class="ip-box"[^>]*>(.*?)</span>\s*\z}m, 1] || inner[%r{<b>(.*?)</b>}m, 1])

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
  # figure.impact is section 05's and impact-paths.rb grades it; it only reaches here through a
  # fragment with no checkpoint around it.
  found = html.scan(FIGURE).reject { |kind, _, _| kind == "impact" }.map { |kind, variants, body| [id, kind, variants.split, body] }
  if found.size > 1
    check.bad("#{id} carries #{found.size} figures (#{found.map { |_, k, _, _| k }.join(', ')}) — one per checkpoint, of any kind, because two figures for one judgment are two answers to which shape it has")
  end
  figures.concat(found)
end

# Context's figure, read from section 02 only. A checkpoint inside it is impossible by the page's
# order, so nothing here is graded twice.
context_figures = []
if source.has?(CONTEXT)
  ctx = source.section_from(CONTEXT).lines.join
  context_figures = ctx.scan(FIGURE).map { |kind, variants, body| ["Context", kind, variants.split, body] }
  if context_figures.size > 1
    check.bad("Context carries #{context_figures.size} figures — one at most, the request sequence before and after")
  end
end
cp_ids = checkpoints.filter_map { |cp| cp.lines.join[/<section class="cp[^"]*" id="([^"]+)"/, 1] }

if figures.empty? && context_figures.empty?
  if check.kind == "page"
    check.ok("no checkpoint carries a figure — a valid result, and most checkpoints earn none")
  else
    check.skip("no checkpoint figure in this input")
  end
  check.finish
  exit
end

check.ok("at most one figure per checkpoint") if !figures.empty? && figures.group_by(&:first).values.none? { |fs| fs.size > 1 }

page_has_search = source.has?(/<details class="searched/)

context_figures.each do |id, kind, variants, body|
  where = "Context's #{kind}"
  unless kind == "lifecycle" && variants.include?(SHIFT)
    check.bad("#{where}: figure.#{([kind] + variants).join('.')} is not Context's figure — the one it may hold is figure.lifecycle.#{SHIFT}, and every other figure belongs to the checkpoint whose judgment earned it")
    next
  end
  figures << [id, kind, variants, body]
end

figures.each do |id, kind, variants, body|
  shift = kind == "lifecycle" && variants.include?(SHIFT)
  where = shift ? "#{id}'s shift" : "#{id}'s #{kind}"
  faults = []

  if shift && id != "Context"
    check.bad("#{where}: figure.lifecycle.#{SHIFT} is Context's figure — a sequence only one checkpoint turns on is that checkpoint's plain lifecycle, and one several turn on is drawn once, above them")
    next
  end

  unless KINDS_DRAWN.include?(kind)
    check.bad("#{where}: figure.#{kind} is not a checkpoint figure — the four are #{KINDS_DRAWN.join(', ')}, and figure.impact lives in section 05")
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
      faults << "node #{n + 1} is .ip-aff — a hop into unchanged code whose meaning the change altered is an impact path, drawn once in section 05" if k == "ip-aff"
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
    faults << "an .ip-aff node — a state is not a file, so unchanged-code has nothing to mean here" if body.match?(/class="[^"]*\bip-aff\b/)
    if shift
      columns = body.scan(%r{<div class="lc-row"[^>]*>(.*?)</ol>}m).map(&:first)
      faults << "#{columns.size} column(s) — a shift is a Before and an After, exactly two" unless columns.size == 2
      faults << "a back transition — a retry is a case, and goes in ul.lc-cases" if body.include?('class="lc-back"')
      cols = columns.first(2).each_with_index.map do |col, c|
        name = text(col[%r{<span class="lc-when"[^>]*>(.*?)</span>}m, 1])
        faults << "column #{c + 1} has no .lc-when label" if name.empty?
        lifecycle_states(check, where, col, faults, label: "#{name.empty? ? "column #{c + 1}" : name}: ")
      end
      if cols.size == 2
        firsts = cols.map { |st| st.first ? state_label(st.first[1]) : "" }
        faults << "the columns start at different states (#{firsts.map { |f| "\"#{f}\"" }.join(' and ')}) — two answers to one question start from the same place" unless firsts.uniq.size == 1
        moved = cols.map { |st| st.each_index.select { |n| st[n][0].split.include?("lc-moved") } }
        if moved.any? { |m| m.size != 1 }
          faults << "#{moved.map(&:size).join(' and ')} moved state(s) — exactly one in each column, because that state is the point of the figure"
        else
          labels = moved.each_with_index.map { |(n), c| state_label(cols[c][n][1]) }
          faults << "the moved state is \"#{labels[0]}\" before and \"#{labels[1]}\" after — it is one state, so one label" unless labels.uniq.size == 1
          faults << "the moved state sits at position #{moved[0][0] + 1} in both columns — a shift where nothing moved has drawn one list twice" if moved[0][0] == moved[1][0]
        end
      end
      cases = body[%r{<ul class="lc-cases"[^>]*>(.*?)</ul>}m, 1]
      if cases.nil?
        check.maybe("#{where}: no ul.lc-cases — the figure draws the main path, and a sequence drawn once reads as the only one; say the cases that differ, a line each")
      elsif (n = cases.scan(/<li\b/).size) > MAX_CASES
        check.maybe("#{where}: #{n} cases that differ — at most #{MAX_CASES}, one line each; a case needing more is a checkpoint's concern")
      end
      caption = body[%r{<figcaption[^>]*>(.*?)</figcaption>}m, 1].to_s
      pointed = caption.include?('class="ctx-used"') ? caption.scan(/href="#(cp-[^"]+)"/).flatten.uniq : []
      if pointed.empty?
        check.maybe("#{where}: no span.ctx-used naming the checkpoints that rely on it — the shift is earned by them, like every Context entry")
      elsif pointed.size < 2
        check.maybe("#{where}: only #{pointed.first} relies on it — a sequence one checkpoint turns on is that checkpoint's lifecycle, and Context draws only the shared one")
      elsif check.kind == "page" && !(dead = pointed - cp_ids).empty?
        check.maybe("#{where}: points at #{dead.join(', ')}, which this page does not carry")
      end
    else
      lifecycle_states(check, where, body, faults)
      backs = body.scan(%r{<p class="lc-back"[^>]*>(.*?)</p>}m)
      faults << "#{backs.size} back transitions — two at most, or the lifecycle is a graph this figure cannot draw" if backs.size > MAX_BACK
      faults << "a back transition with no locator" if backs.any? { |(b)| !b.match?(LOC) }
    end

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
