#!/usr/bin/env ruby
# frozen_string_literal: true

# excerpts.rb — the mechanical half of the source excerpts.
#
# The half that matters is not here: does the prose still read completely with every
# excerpt CLOSED, judged field by field. That needs a reader and lives in the cases.
# What a script can settle is shape — collapsed by default (the inline snippet an explanation
# shows is a div, not a disclosure, and is read rather than opened), a summary that says what is
# inside, tints that exist in all three theme blocks, no range quoted twice, a quotation
# nobody coloured by hand, and a state tag that agrees with the diff it describes.
#
# Note which counts are OCCURRENCES and not lines. The shell used `grep -o | wc -l` here
# rather than `grep -c`, and the difference is load-bearing twice over: <details> and
# <summary> are compared against each other, so a page with two on one line must count two;
# and the tint checks assert a token appears three times, which is once per theme block and
# says nothing about how the CSS is wrapped.

require_relative "lib/review_map/check"
require_relative "lib/review_map/changed"

# The tint is applied at read time, so an hljs- class in the markup means someone coloured
# the quotation by hand — which is to say edited it.
HAND_COLOURED = /class="hljs-|class="l hljs-/

# Where an excerpt's block ends. A disclosure ends at </details>; the inline snippet a checkpoint's
# explanation shows (excerpt.sh --inline) is a div.excerpt.ex-inline with no disclosure, and its
# first </div> closes .ex-body, after the caption's tag and location and the pre's data-src have
# all been read. A disclosure's .ex-body closes the same way, one line before </details>, so the
# block ends there with nothing left unread. Reading only </details> left every inline snippet's
# state tag unchecked — the excerpt a reader is surest to see.
BLOCK_END = %r{</details>|</div>}

# data-lang belongs to --source only. A diff hunk is not one lexical stream, so a tinted one
# is mis-lexed from the first unbalanced quote onward.
def diff_excerpt_carries_lang?(page)
  in_diff = false
  page.lines.each do |raw|
    line = raw.chomp
    in_diff = true if line.match?(/class="excerpt excerpt--diff"/)
    in_diff = false if line.match?(BLOCK_END)
    return true if in_diff && line.match?(/data-lang=/)
  end
  false
end

# excerpt.sh derives the state tag (see its STATE comment): Unchanged means the path is
# outside the diff, and Added / Removed / At head / Before the change mean it is inside.
# A --diff hunk is always Changed.
SOURCE_TAGS = /\A(Unchanged|Added|Removed|At head|Before the change)\z/
DIFF_TAG = "Changed"

Block = Struct.new(:variant, :tag, :src, :loc)

# The summary's location, linked or not. excerpt.sh links it whenever the rung allows — the
# summary is the excerpt's one citation — so the text sits inside an <a class="cite">; reading
# up to the first "<" would see an empty string for every linked excerpt, and the duplicate
# check below would then call every pair of them the same range.
EX_LOC = /class="ex-loc">(?:<a\b[^>]*>)?([^<]*)/

# One row per excerpt: variant, state tag, quoted path, location.
#
# The tag is read only BETWEEN a <details> and its </details>, because .tag is shared with
# the decisions block's Tradeoff chip and a page-wide match would collect that as an
# excerpt's state. Two details of the scan carry over from the awk: the opening line is
# consumed by the variant, so no tag, path or location is read off it; and a later line
# overwrites an earlier one, so the LAST match inside a block wins.
def blocks_in(page)
  found = []
  current = nil

  page.lines.each do |raw|
    line = raw.chomp
    if line.match?(/class="excerpt excerpt--/)
      variant = line.sub(/.*excerpt--/, "").sub(/["[:space:]].*/, "")
      current = Block.new(variant, "", "", "")
      next
    end
    next unless current

    current.tag = line.sub(/.*class="tag">/, "").sub(/<.*/, "") if line.match?(/class="tag"/)
    current.loc = line[EX_LOC, 1] if line.match?(EX_LOC)
    current.src = line.sub(/.*data-src="/, "").sub(/".*/, "") if line.match?(/data-src="/)
    next unless line.match?(BLOCK_END)

    found << current
    current = nil
  end

  found
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

check = ReviewMap::Check.new(ARGV)
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

# --- The state tag is a claim about the diff, so it is checked against one ---
#
# excerpt.sh used to hard-code "Unchanged" on every --source block, and a run duly published
# db/structure.sql:304-313 tagged Unchanged on a page whose own ledger listed that file as
# changed — the page contradicting itself about the one thing a reader cannot check from the
# page. That defect is invisible by construction: the block is real, the bytes are verbatim,
# and only the label is false. Hence two rules, one lexical and one relational.
#
# Comments are stripped for these two only. Everything else here reads the input as published,
# because every other rule is about markup the page actually carries.
source = page.without_comments
blocks = blocks_in(source)

# The vocabulary is closed, and it is closed because the generator computes it. A tag outside
# it — "Modified", "New", a bare "Changed" on a listing with no +/- gutters — is a tag somebody
# typed, which is the same defect one step earlier. A block with no tag at all is left to the
# summary rule in report-format.md; this one only reads what is there.
typed = blocks.filter_map do |block|
  next if block.tag.empty? || block.tag.include?("{{")

  case block.variant
  when "source" then "#{block.tag} on #{block.loc}" unless block.tag.match?(SOURCE_TAGS)
  when "diff" then "#{block.tag} on #{block.loc}" unless block.tag == DIFF_TAG
  end
end
if typed.empty?
  check.ok("every state tag is one excerpt.sh emits")
else
  check.bad("a state tag is outside the generator's vocabulary, so it was typed: #{typed.join(";")};")
end

# The relational half.
changed, set_from, git_unreadable = ReviewMap.changed_set(check, source)
# Said out loud, because e2e/run.rb passes --repo and --base on every page run: without this, a
# wrong base silently downgrades every run to ledger-only and the operator never learns.
if git_unreadable
  check.maybe("the changed set could not be read from #{check.repo}: #{git_unreadable} — a page carrying a ledger is still checked against that, and one without is not checked at all")
end
if set_from.nil?
  check.skip("state tags against the diff: nothing to compare with — needs --repo and --base, or an input carrying the ledger")
else
  mislabelled = blocks.select do |block|
    # Whole lines, never substrings: api/Gemfile sits inside api/Gemfile.lock.
    block.variant == "source" && block.tag == "Unchanged" &&
      !block.src.empty? && changed.include?(block.src)
  end
  if mislabelled.empty?
    check.ok("no excerpt labels a changed file Unchanged, against #{set_from}")
  else
    check.bad("labelled Unchanged, but the change touches the file: #{mislabelled.map(&:loc).join("; ")} — quote it and let excerpt.sh --base tag the state")
  end
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
locations = page.scan(EX_LOC).map { |m| m[EX_LOC, 1] }.reject { |loc| loc.include?("{{") }
duplicated = locations.tally.select { |_, n| n > 1 }.keys.sort.first(3)
if duplicated.empty?
  check.ok("no excerpt quotes the same lines twice")
else
  check.bad("the same range is excerpted more than once: #{duplicated.join(" ")} ")
end

# Overlapping ranges in one file: the same lines quoted twice under two different locations,
# which the literal test above cannot see. It is also the one mechanical trace of an entry
# quoting the wrong block — a run that cited a revocation loop for a claim about an assignment
# collided with the entry that cited the loop correctly, 54-66 around 54-56. A WARN, because a
# FAIL here teaches a run to shift a range by a line until the two stop touching; which of the
# two is the wrong citation is a reader's question.
ranges = locations.uniq.filter_map do |loc|
  m = loc.strip.match(/\A(.+):(\d+)(?:-(\d+))?\z/)
  m && [loc.strip, m[1], m[2].to_i, (m[3] || m[2]).to_i]
end
overlapping = ranges.combination(2).filter_map do |(a, path_a, from_a, to_a), (b, path_b, from_b, to_b)|
  "#{a} and #{b}" if path_a == path_b && from_a <= to_b && from_b <= to_a
end
if overlapping.empty?
  check.ok("no two excerpts quote overlapping lines")
else
  check.maybe("excerpts quote overlapping lines: #{overlapping.first(3).join("; ")} — the same lines twice, or one of the two entries cites the wrong block")
end

check.finish
