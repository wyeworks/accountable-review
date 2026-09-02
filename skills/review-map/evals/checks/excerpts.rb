#!/usr/bin/env ruby
# frozen_string_literal: true

# excerpts.rb — the mechanical half of the source excerpts.
#
# The half that matters is not here: does the prose still read completely with every
# excerpt CLOSED, judged field by field. That needs a reader and lives in the cases.
# What a script can settle is shape — collapsed by default, a summary that says what is
# inside, tints that exist in all three theme blocks, no range quoted twice, and a
# quotation nobody coloured by hand.
#
# Note which counts are OCCURRENCES and not lines. The shell used `grep -o | wc -l` here
# rather than `grep -c`, and the difference is load-bearing twice over: <details> and
# <summary> are compared against each other, so a page with two on one line must count two;
# and the tint checks assert a token appears three times, which is once per theme block and
# says nothing about how the CSS is wrapped.

require_relative "lib/review_map/check"

# The tint is applied at read time, so an hljs- class in the markup means someone coloured
# the quotation by hand — which is to say edited it.
HAND_COLOURED = /class="hljs-|class="l hljs-/

# data-lang belongs to --source only. A diff hunk is not one lexical stream, so a tinted one
# is mis-lexed from the first unbalanced quote onward.
def diff_excerpt_carries_lang?(page)
  in_diff = false
  page.lines.each do |raw|
    line = raw.chomp
    in_diff = true if line.match?(/class="excerpt excerpt--diff"/)
    in_diff = false if line.match?(%r{</details>})
    return true if in_diff && line.match?(/data-lang=/)
  end
  false
end

# Three theme states or none: bare :root plus both dark blocks. A colour declared only
# inside a media query is the classic unreadable-artifact bug.
def theme_states(check, token, label, absent: nil)
  if check.kind != "page"
    check.skip("#{label}: a fragment carries no token block")
    return
  end

  seen = check.page.scan(Regexp.new(Regexp.escape(token))).size
  if seen.zero? && absent
    check.skip(absent)
  elsif seen >= 3
    check.ok("#{label} defined in all three theme blocks")
  else
    check.bad("#{token} appears #{seen} time(s), needs 3 — bare :root plus both dark blocks")
  end
end

check = ReviewMap::Check.new(ARGV, name: "excerpts.sh")
check.require_input
page = check.page

excerpts = page.scan(/class="excerpt/).size
if excerpts.zero?
  check.skip("no excerpts in this input")
  check.finish
end

details = page.scan(/<details/).size
summaries = page.scan(/<summary/).size
if details == summaries
  check.ok("#{excerpts} source excerpt(s), each with a summary")
else
  check.bad("#{details} <details> but #{summaries} <summary> — a disclosure with no summary is an unlabelled black box")
end

# Collapsed by default. An excerpt that ships open is just a code dump, and it is the
# reader who decides when they are ready to check the claim.
if page.has?(/<details[^>]*[[:space:]]open([[:space:]>]|=)/)
  check.bad("an excerpt is open by default — excerpts are revealed by the reader, not shipped expanded")
else
  check.ok("every excerpt is collapsed by default")
end

# A closed excerpt is the state most readers see, so its summary has to say what is
# inside. "View diff" is not a summary.
if page.has?(/<summary>[[:space:]]*(view|show|see) (diff|code|source)/i)
  check.bad("a summary reads 'view diff'/'show code' — say the location and why to open it")
else
  check.ok("no placeholder summaries")
end

# The excerpt tints are the newest colours in the system, which makes them the most
# likely to be declared in one theme block and forgotten in the other two.
theme_states(check, "--ex-add", "excerpt tints")

# This is the one defect here that changes what the reader believes the file says.
if page.has?(HAND_COLOURED)
  check.bad("hljs- classes are written into the markup — the tint is the page script's job, and a hand-coloured quotation is an edited one")
else
  check.ok("no hand-written syntax colouring inside a quotation")
end

if diff_excerpt_carries_lang?(page)
  check.bad("a --diff excerpt carries data-lang — only unchanged code is tinted, a hunk is two realities interleaved")
else
  check.ok("data-lang is on unchanged excerpts only")
end

theme_states(check, "--syn-key", "syntax tints", absent: "no syntax tokens on this page")

# Exact-duplicate excerpts. The budget forbids quoting the same lines twice — if a
# start-here entry and its cohort field rest on one citation, the excerpt goes in one of
# them. Near-duplicates (structurally identical code a few lines apart) are the more
# common waste and need a reader; this catches only the literal case. Placeholders are
# excluded: an unfilled template legitimately repeats {{PATH}}:{{LINES}}.
locations = page.scan(/class="ex-loc">[^<]*/).reject { |loc| loc.include?("{{") }
duplicated = locations.tally.select { |_, n| n > 1 }.keys.sort.first(3)
if duplicated.empty?
  check.ok("no excerpt quotes the same lines twice")
else
  ranges = duplicated.map { |loc| loc.sub('class="ex-loc">', "") }
  check.bad("the same range is excerpted more than once: #{ranges.join(" ")} ")
end

check.finish
