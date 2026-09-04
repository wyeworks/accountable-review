#!/usr/bin/env ruby
# frozen_string_literal: true

# excerpts.rb — the mechanical half of the source excerpts.
#
# The half that matters is not here: does the prose still read completely with every
# excerpt CLOSED, judged field by field. That needs a reader and lives in the cases.
# What a script can settle is shape — collapsed by default, a summary that says what is
# inside, tints that exist in all three theme blocks, no range quoted twice, a quotation
# nobody coloured by hand, and a state tag that agrees with the diff it describes.
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

# excerpt.sh derives the state tag (see its STATE comment): Unchanged means the path is
# outside the diff, and Added / Removed / At head / Before the change mean it is inside.
# A --diff hunk is always Changed.
SOURCE_TAGS = /\A(Unchanged|Added|Removed|At head|Before the change)\z/
DIFF_TAG = "Changed"

Block = Struct.new(:variant, :tag, :src, :loc)

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
    current.loc = line.sub(/.*class="ex-loc">/, "").sub(/<.*/, "") if line.match?(/class="ex-loc"/)
    current.src = line.sub(/.*data-src="/, "").sub(/".*/, "") if line.match?(/data-src="/)
    next unless line.match?(%r{</details>})

    found << current
    current = nil
  end

  found
end

# Two ways to learn what the diff touched, and the page carries one of them itself: the
# ledger accounts for every changed path by invariant, so a page can be held against its own
# account of the change with no repository at hand.
def changed_set(check, source)
  if !check.repo.to_s.empty? && !check.base.to_s.empty?
    merge_base, = check.shell("git", "-C", check.repo, "merge-base", check.base, check.head_ref)
    merge_base = merge_base.strip
    merge_base = check.base if merge_base.empty?
    status, = check.shell("git", "-C", check.repo, "diff", "--name-status", "-M",
                          merge_base, check.head_ref)
    # A rename contributes BOTH paths: `R100<tab>old<tab>new`.
    paths = status.lines.flat_map do |line|
      fields = line.chomp.split("\t")
      fields.size > 2 ? [fields[1], fields[2]] : [fields[1]]
    end
    # "the diff" even when git failed, because the shell tested the exit status of a pipeline
    # ending in `sort` — so a failing git left an empty set and still took this branch.
    return [paths.compact.sort.uniq, "the diff"]
  end

  if source.has?("data-path=")
    ledger = source.scan(/data-path="[^"]*"/)
                   .map { |attr| attr.sub(/\Adata-path="/, "").sub(/"\z/, "") }
                   .sort.uniq
    return [ledger, "the page's own ledger"]
  end

  [nil, nil]
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
changed, set_from = changed_set(check, source)
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
locations = page.scan(/class="ex-loc">[^<]*/).reject { |loc| loc.include?("{{") }
duplicated = locations.tally.select { |_, n| n > 1 }.keys.sort.first(3)
if duplicated.empty?
  check.ok("no excerpt quotes the same lines twice")
else
  ranges = duplicated.map { |loc| loc.sub('class="ex-loc">', "") }
  check.bad("the same range is excerpted more than once: #{ranges.join(" ")} ")
end

check.finish
