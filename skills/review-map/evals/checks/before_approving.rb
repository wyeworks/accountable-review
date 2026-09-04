#!/usr/bin/env ruby
# frozen_string_literal: true

# before_approving.rb — section 6, the reviewer's action list.
#
# Three of its four parts have a mechanical edge. The checkpoint has a hard cap of
# five, because the old standalone part had none and grew into a quiz that restated the
# page. Author questions have to be questions — an imperative in that list is a task the
# reviewer can do alone, which means it belongs under Run. Run steps have to be real
# commands, and a command is markup, not prose.
#
# What no script can settle: whether a question is answerable by copying one sentence
# from earlier in the page. That is the cap's actual purpose and it lives in the case.
#
# DETAIL LEVEL. This is the ONE check that reads --level. At --level brief there is no
# section 6: its anchor is an <h3> inside the merged tail section, and the checkpoint is not
# there at all — it is a comprehension test rather than something to weigh before approving,
# so it belongs to --full. That inverts the cap check rather than relaxing it: at brief, no
# checkpoint is a PASS and a present one is a FAIL. The rest of this script is level-agnostic,
# because author questions and real commands are what the brief level keeps.

require_relative "lib/review_map/check"

ANCHOR = /id="approving"/

# The checkpoint is a grid of inverted tiles, so its questions are <div>s inside .checkpoint
# rather than <li>s. The two fallbacks keep a page built before the tiles being checked
# rather than silently skipped — ol.firstlook was the shape before that.
def checkpoint_questions(region)
  tiles = region.from(/class="checkpoint"/, stop: %r{</div>[[:space:]]*$}).count(/<div><b>/)
  return tiles if tiles.positive?

  bolds = region.range(from: /class="checkpoint"/, to: %r{</section}).count(/<b>/)
  return bolds if bolds.positive?

  region.range(from: /<ol class="firstlook"/, to: %r{</ol>}).count(/<li/)
end

check = ReviewMap::Check.new(ARGV, name: "before-approving.sh")
check.require_input

# On a page, section 6 is the region from its anchor onward — which is also true at brief,
# where the anchor is an <h3> and is deliberately the LAST part of the merged section. A
# fragment is already the region.
region =
  if check.page.has?(ANCHOR)
    check.page.from(ANCHOR)
  elsif check.kind == "fragment"
    check.page
  elsif check.level == "brief"
    # At brief the anchor is not optional: it is the merged section's last <h3>, and
    # without it this whole script goes quiet on a page that has a before-approving part.
    # A SKIP here would read as verified, which is the failure this branch exists to stop.
    check.bad('no id="approving" anchor at --brief — the merged tail section carries it on its last <h3>, and without it none of section 6\'s rules can be checked')
    check.finish
  else
    check.skip('no section 6 on this page (id="approving" absent)')
    check.finish
  end

# The cap. Five forces the questions to be the ones that join things the page
# established separately.
questions = checkpoint_questions(region)
if check.level == "brief"
  if questions.zero?
    check.ok("no comprehension checkpoint, which is right at --brief: it belongs to --full")
  else
    check.bad("a comprehension checkpoint with #{questions} question(s) at --brief — the checkpoint belongs to --full, and this level's tail carries author questions and validations only")
  end
elsif questions.zero?
  check.maybe("no comprehension checkpoint found inside 'Before approving'")
elsif questions <= 5
  check.ok("comprehension checkpoint has #{questions} question(s), within the cap of 5")
else
  check.bad("comprehension checkpoint has #{questions} questions — the cap is 5, and past it they turn into a quiz that restates the page")
end

# Author questions, phrased as questions. Counting question marks against list items is
# crude on purpose: it is a WARN, and a reader settles it.
if region.has?(/ask the author/i)
  ask = region.from(/[Aa]sk the author/, stop: %r{<h3|act-group|</section}, stop_after: 1)
  items = ask.count(/<li/)
  marks = ask.count(/\?/)
  if items.zero?
    check.maybe("an 'ask the author' heading with no items under it")
  elsif marks >= items
    check.ok("#{items} author question(s), each apparently phrased as one")
  else
    check.maybe("#{items} author item(s) but only #{marks} question mark(s) — an imperative here is a task, and tasks belong under Run")
  end
else
  check.maybe("no 'ask the author' part — legitimate only if nothing needs the author")
end

# Validation steps are commands. An invented step is worse than none, because it burns
# the reader's trust on the first paste that fails — but a script can only check that
# something command-shaped is there at all.
if region.has?(/<code|<pre/)
  check.ok("validation steps carry command markup")
else
  check.bad("no <code> anywhere in section 6 — validations must be pasteable commands, not prose")
end

check.finish
