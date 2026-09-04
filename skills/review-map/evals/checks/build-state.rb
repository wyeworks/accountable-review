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

check.finish
