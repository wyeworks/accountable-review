#!/usr/bin/env ruby
# frozen_string_literal: true

# link-form.rb — the href, checked against the citation it sits on.
#
# page-invariants.rb § 5 asks whether the page should be linking at all: with the head commit on
# no remote, every permalink 404s and the rung says plain text. It says outright that it does not
# check the FORM. This does, and the three rules here are the three ways a link can be live,
# well-formed and still wrong — each of them invisible to a reader, because a link that lands
# somewhere plausible does not announce that it landed in the wrong place.
#
#   1 · the span. A citation reading `:51-72` under an href ending at R51 selects one line of
#       twenty-two. The text promises a range, the link delivers a line, and nothing on the page
#       says which to believe. Reported from a real run.
#   2 · the fragment. GitHub's diff anchor is sha256 of the path, so it is exactly the part of a
#       URL no reader can proofread: one wrong character lands on the diff page with no file
#       selected. Every #diff- fragment therefore has to hash back to a path in the diff.
#   3 · the routing. A file GitHub keeps behind "Load diff" cannot be anchored into at all — the
#       cited line is not in the page — so report-format.md § When the diff will not render sends
#       those citations to the blob form. scripts/diff-render.sh holds the verdict, and this
#       re-asks it rather than reimplementing it: a check with its own copy of the thresholds is
#       a second source of truth that agrees until the day it matters.
#
# Rules 1 and 2 need nothing but the input (rule 2 falls back to the page's own ledger, which the
# completeness invariant guarantees is the whole diff). Rule 3 needs a repository git can answer
# about, and SKIPs rather than passing when it has none — an unanswered question is not a verdict.
#
# It is in every scope in check.rb, including the section ones, but only rule 1 grades on a section
# fragment: evals/run.sh passes --repo and not --base, and the rules below that ask what the diff
# holds refuse without it. That is the right way round — the span is a property of one citation and
# travels with any fragment, while the other three are properties of a diff.

require "digest"

require_relative "lib/review_map/check"

DIFF_ANCHOR = /#diff-(\h{64})(?:([RL])(\d+)(?:-([RL])(\d+))?)?/
BLOB_LINES  = %r{/blob/\h{7,40}/[^"#]*#L(\d+)(?:-L(\d+))?}
# a.path and a.cite are the two linked citation forms in page-template.html. The text is
# `path:line` or `path:start-end`, or a bare path in a ledger row and in section 4's entries.
CITATION    = %r{<a class="(?:path|cite)"[^>]*href="([^"]*)"[^>]*>([^<]*)</a>}
TEXT_SPAN   = /:(\d+)(?:[-–](\d+))?\s*\z/

check = ReviewMap::Check.new(ARGV)
check.require_input
page = check.page
doc = page.lines.join

Citation = Struct.new(:href, :text, :from, :to, keyword_init: true)

citations = doc.to_enum(:scan, CITATION).map { Regexp.last_match }.filter_map do |m|
  text = ReviewMap.unescape(m[2]).strip
  span = text.match(TEXT_SPAN)
  next unless span

  Citation.new(href: m[1], text: text, from: span[1].to_i, to: span[2]&.to_i)
end

# 1 · The span the text promises is the span the href addresses.
#
# Both directions fail, and for one reason: the two disagree. A range in the text with a single
# line in the href is the defect a real run shipped; a single line in the text with a range in the
# href is the same lie the other way round, and neither is something a reader can catch.
#
# A citation whose href carries no line at all is not this rule's business — a ledger row links
# its file, and § 7 says so. Only an href that addresses SOME line is compared.
if citations.empty?
  check.skip("citation spans: no linked file:line citations in this input")
else
  wrong = []
  citations.each do |c|
    if (m = c.href.match(DIFF_ANCHOR)) && m[2]
      side, start_line, end_side, end_line = m[2], m[3].to_i, m[4], m[5]&.to_i
      wrong << "#{c.text} starts at #{side}#{start_line}" unless start_line == c.from
      if c.to.nil? && end_line
        wrong << "#{c.text} names one line and links #{side}#{start_line}-#{end_side}#{end_line}"
      elsif c.to && end_line.nil?
        wrong << "#{c.text} names a range and links only #{side}#{start_line}"
      elsif c.to && end_line != c.to
        wrong << "#{c.text} ends at #{end_side}#{end_line}"
      elsif c.to && end_side != side
        # R51-L72 is not a range GitHub can select: the two sides are different columns.
        wrong << "#{c.text} spans #{side} to #{end_side}"
      end
    elsif (m = c.href.match(BLOB_LINES))
      start_line, end_line = m[1].to_i, m[2]&.to_i
      wrong << "#{c.text} starts at L#{start_line}" unless start_line == c.from
      if c.to.nil? && end_line
        wrong << "#{c.text} names one line and links L#{start_line}-L#{end_line}"
      elsif c.to && end_line.nil?
        wrong << "#{c.text} names a range and links only L#{start_line}"
      elsif c.to && end_line != c.to
        wrong << "#{c.text} ends at L#{end_line}"
      end
    end
  end

  if wrong.empty?
    check.ok("every linked citation addresses the lines its text names (#{citations.size})")
  else
    check.bad("citation text and href disagree about the lines: #{wrong.uniq.join("; ")}")
  end
end

# The changed set, from git where there is one and from the page's own ledger otherwise. Same two
# sources excerpts.rb uses for the state tag, and the same refusal in the middle: git asked and
# unable to answer is not an empty diff, and reading it as one turns both rules below into a
# clean bill of health.
changed = nil
source = nil
if !check.repo.to_s.empty? && !check.base.to_s.empty?
  out, answered = check.shell("git", "-C", check.repo, "diff", "--name-only",
                              "#{check.base}...#{check.head_ref}")
  if answered
    changed = out.split("\n").reject(&:empty?)
    source = "the diff"
  else
    changed = nil
    source = :unanswered
  end
end
if changed.nil? && source != :unanswered
  ledger = page.scan(/data-path="([^"]*)"/).map { |a| ReviewMap.unescape(a[/"([^"]*)"/, 1].to_s) }
  unless ledger.empty?
    changed = ledger
    source = "the page's own ledger"
  end
end

by_hash = (changed || []).to_h { |path| [Digest::SHA256.hexdigest(path), path] }

# 2 · Every diff anchor hashes back to a path in the diff.
anchors = doc.to_enum(:scan, DIFF_ANCHOR).map { Regexp.last_match }
if anchors.empty?
  check.skip("diff anchors: this input has none")
elsif source == :unanswered
  check.skip("diff anchors: git cannot say what #{check.base}...#{check.head_ref} changed in #{check.repo} — with no answer there is nothing to hash them against")
elsif changed.nil?
  check.skip("diff anchors: needs --repo and --base, or a ledger, to know which paths the diff holds")
else
  unknown = anchors.map { |m| m[1] }.uniq.reject { |hex| by_hash.key?(hex) }
  if unknown.empty?
    check.ok("every diff anchor hashes to a path in #{source} (#{anchors.size})")
  else
    check.bad("#{unknown.size} diff anchor(s) hash to no path in #{source} — a fragment nobody can proofread, landing on no file: #{unknown.map { |h| h[0, 12] }.join(" ")}")
  end
end

# Which files GitHub withholds, from the script the run itself uses rather than from a second
# copy of GitHub's thresholds living here. Both rules below need it, and the two are separate
# rules rather than one with a branch: a page that routes every collapsed citation to a blob and
# quotes none of them has the first rule right and the second wrong, and the first version of
# this file could not say so — it gated the excerpt question on the presence of a diff anchor,
# which is precisely what a correctly routed page does not have.
renderer = File.join(ReviewMap::Check::SKILL_DIR, "scripts", "diff-render.sh")
collapsed = nil
render_answered = false
unless check.repo.to_s.empty? || check.base.to_s.empty?
  out, render_answered = check.shell(renderer, check.base, check.head_ref, "--collapsed-only",
                                     chdir: check.repo)
  collapsed = out.lines.filter_map do |line|
    fields = line.chomp.split("\t")
    fields[2] if fields[0] == "collapse"
  end
end

# 3 · No line-level diff anchor into a file GitHub will not render.
#
# Nothing else here would notice this: the anchor is well-formed, the hash is right, the file is
# really in the diff, and the reviewer still arrives at a "Load diff" stub with the cited line
# nowhere in the page.
line_anchors = anchors.select { |m| m[2] }
if collapsed.nil?
  check.skip("collapsed-diff routing: needs --repo and --base to ask which files GitHub renders")
elsif !render_answered
  check.skip("collapsed-diff routing: diff-render.sh could not read #{check.repo} at #{check.base} — an unanswered question is not a clean page")
elsif collapsed.empty?
  check.ok("no file in this diff is withheld by GitHub, so every line in it can be a diff anchor")
else
  offenders = line_anchors.filter_map do |m|
    path = by_hash[m[1]]
    "#{path}:#{m[2]}#{m[3]}" if path && collapsed.include?(path)
  end
  if offenders.any?
    check.bad("#{offenders.uniq.size} citation(s) anchor into a diff GitHub will not render, so the link lands on a Load diff stub with the line nowhere in the page — these take the blob form: #{offenders.uniq.join(" ")}")
  else
    check.ok("#{collapsed.size} withheld file(s) in the diff, and no citation anchors into one")
  end
end

# 4 · The excerpt is what carries the loss. A blob link into a withheld file lands on the line
# and shows it with nothing marking what it replaced — which is the half the diff was going to
# supply. Whether a given excerpt is load-bearing is a judgement, so this is a WARN; whether
# there is one at all is not, so it is checked.
if collapsed.nil? || !render_answered || collapsed.empty?
  check.skip("withheld-file excerpts: no verdict on which files GitHub renders, so nothing to expect an excerpt for")
else
  quoted = page.scan(/data-src="([^"]*)"/).map { |a| a[/"([^"]*)"/, 1].to_s }.map { |v| ReviewMap.unescape(v) }
  cited = citations.map { |c| c.text.sub(TEXT_SPAN, "") }.uniq
  bare = collapsed.select { |path| cited.include?(path) && !quoted.include?(path) }
  if bare.any?
    check.maybe("cited from a withheld file with no excerpt to make up for it, where the link cannot show what the line replaced: #{bare.join(" ")}")
  else
    check.ok("every citation into a withheld file has an excerpt beside it, or none is cited")
  end
end

check.finish
