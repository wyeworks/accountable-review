#!/usr/bin/env ruby
# frozen_string_literal: true

# build_state.rb — the page has three legitimate states, and they must not be
# confusable.
#
#   draft    published mid-run. It must admit it is unfinished.
#   final    the last publish of a completed run. No build-state markers may remain.
#   stopped  a run that ended early on purpose. The banner states what was not
#            written rather than promising stages that are never coming.
#
# The risk this guards is one reader mistake: taking a pending part for "nothing to
# say here".
#
# --updated is a FOURTH AXIS, not a fourth state, and it composes with final rather than
# replacing it. An updated page (SKILL.md § Re-running over new commits) re-reads only the commits
# since the previous map, so parts of it describe an earlier head — but it is finished, so every
# rule above still applies to it and the mode stays `final`. What it adds is the one thing only an
# updated page owes: the disclosure sentence, exactly once, and a masthead naming both revisions.
#
# The REFUSALS that go with it are not here. No recency marker and no resolved tick hold on every
# page, updated or not, so they are page-invariants.rb § 2e where they need no flag to be found —
# and a rule you have to remember to switch on is a rule that is off.

require_relative "lib/review_map/check"

BANNER  = /class="buildstate"/
PENDING = /class="pending"/

check = ReviewMap::Check.new(ARGV)
check.require_kind(:page)
page = check.page

case check.mode
when "draft"
  if page.has?(BANNER)
    check.ok("draft carries the build banner")
  else
    check.bad("draft has no build banner — a half-written page that looks finished")
  end

  if page.has?("absence is not a finding")
    check.ok("banner says a pending part is not an absent one")
  else
    check.bad("banner is missing the sentence that stops a pending part reading as nothing to say")
  end

  if page.has?(PENDING)
    check.ok("pending markers present (#{page.count(PENDING)})")
  else
    check.bad("no pending markers — the reader cannot see what is still coming")
  end

when "stopped"
  if page.has?(BANNER)
    check.ok("stopped run still explains its own state")
  else
    check.bad("a stopped run with no banner reads as a finished page with parts missing")
  end

  if page.has?("Still being written")
    check.bad("banner still says 'still being written' — nothing is writing it any more")
  else
    check.ok("banner does not promise work that is not coming")
  end

  if page.has?("not written")
    check.ok("the limit is stated in words")
  else
    check.bad("no statement of what was left unwritten — that is the whole point of this state")
  end

  # 'pending' is a promise. A stopped run says 'not written', which is a fact.
  if page.has?(/class="pending">pending/)
    check.bad("markers still say 'pending', which is a promise; a stopped run says 'not written'")
  else
    check.ok("markers state a fact rather than a promise")
  end

else
  leftover = page.count(/class="buildstate"|class="pending"/)
  if leftover.zero?
    check.ok("no build banner or pending markers left on the finished page")
  else
    check.bad("finished page still carries #{leftover} build-state element(s) — they were not removed")
  end
end

# The disclosure, and only on a page that says it is one. report-format.md § Build state § An
# updated page owns the wording; this checks that it is there and that it is there ONCE. Twice is
# not a harmless duplicate: the sentence names a revision, and a page carrying two of them is a
# page claiming two different things about which parts are current.
if check.updated
  # Comment-stripped, for the reason page-invariants.rb § 2 already carries: a published page ships
  # page-template.html's comments verbatim, and the comment beside the Revision cell explains this
  # very segment. Counted raw, the template's own explanation reads as a second disclosure and a
  # correct page is told it claims two different things — found by this rule's own clean fixture,
  # whose header describes what it is, which is how every fixture here is written.
  prose = page.without_comments
  disclosure = /was updated in place/i
  seen = prose.count(disclosure)
  case seen
  when 1 then check.ok("the update discloses which revision its carried parts describe")
  when 0 then check.bad("an updated page with no disclosure — parts of it describe an earlier head and nothing says so, which is the one failure a reader cannot detect from the inside")
  else        check.bad("the disclosure appears #{seen} times — it names a revision, so two of them claim two different things")
  end

  if prose.has?(/updated from\s+[0-9a-f]{7,40}/i)
    check.ok("the masthead names the revision the carried parts were written at")
  else
    check.bad("no `updated from <sha>` in the masthead — the page names one revision while describing two")
  end
end

check.finish
