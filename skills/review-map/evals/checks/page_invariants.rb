#!/usr/bin/env ruby
# frozen_string_literal: true

# page_invariants.rb — the rules that hold everywhere on the page, and therefore in
# every fragment of it too: no grading, no unlabelled inference, no reserved attribute
# out of place, no dead links, no colour that exists in only one theme.
#
# Runs on a page or on a fragment. Three of these need the whole document — themes,
# the data-path census, link reachability — and say SKIP on a fragment rather than
# passing on evidence they do not have.

require_relative "lib/review_map/check"

# Deliberately high-precision patterns: 'blocking' alone is a false positive ('blocks the
# request', 'locks the table'), so it is a WARN below rather than a failure here.
VERDICT = /LGTM|looks good to me|recommend (approv|merg)|approve this|ready to merge|risk score|overall risk/i
VERDICT_NAMED = /LGTM|looks good to me|recommend (?:approv|merg)[a-z]*|approve this|ready to merge|risk score|overall risk/i

# Assurance language, which is a verdict about the PAGE rather than about the PR and therefore
# easy to reintroduce while believing rule 2 still holds. A run at --effort high sends an
# adversarial pass at its own flows; nothing about that is allowed to reach the page (SKILL.md
# step 8, report-format.md § Detail levels). The patterns are high-precision on purpose: a bare
# 'verified' is a real column name in real Rails apps, and 'audit' appears inside the sanctioned
# "a pass, not an audit".
ASSURE = /(independently|adversarially|externally) verified|verification pass|falsification pass|(claims|findings) (were|have been|are all) (verified|checked|confirmed)|every claim (was|has been) (verified|checked)|class="(verified|checked)"|chip-verified/i

check = ReviewMap::Check.new(ARGV, name: "page-invariants.sh")
check.require_input
page = check.page

# 1 · The severity vocabulary is gone from the design system. If these class names are
#     back, the page is grading again, whatever its prose says.
if page.has?(/chip-(block|watch|good)/)
  check.bad("severity chips reintroduced (chip-block/chip-watch/chip-good)")
else
  check.ok("no severity chips")
end

# 2 · Verdict language.
if page.has?(VERDICT)
  found = page.scan(VERDICT_NAMED).sort.uniq
  check.bad("verdict language found: #{found.join(" ")} ")
else
  check.ok("no verdict or approval language")
end
if page.has?(/>[[:space:]]*(Blocking|Watch)[[:space:]]*</)
  check.maybe("a bare 'Blocking' or 'Watch' label is rendered — read it, it may be severity by another name")
end

# 2b · The page must not advertise that it was checked.
if page.has?(ASSURE)
  found = page.scan(ASSURE).sort.uniq
  check.bad("assurance language — the page is advertising that it was checked: #{found.join(" ")} ")
else
  check.ok("no assurance language — the effort level is invisible on the page")
end
if page.has?(/clean bill of health/i)
  check.maybe("'clean bill of health' appears — legitimate only as a denial; read the sentence")
end

# 3 · Evidence tiers. Silence is the first tier, so a document with no label either had
#     nothing to infer, which is rare, or presented inference as fact, which is the
#     failure this catches.
if page.has?(/class="tier"/)
  check.ok("evidence tiers used (#{page.count(/class="tier"/)} label(s))")
else
  check.bad("no evidence tier labels — inference is being presented as fact, or none was marked")
end

# 4 · Reserved attribute. coverage-gate.sh greps data-path across the whole page, so any
#     component other than a ledger row that emits it injects a surplus path and breaks
#     the gate. Source excerpts carry data-src for that reason. This check is here rather
#     than in the gate because the gate would only report a confusing surplus; this names
#     the cause.
#
#     The ledger is a CSS grid, not a <table>, so the cell that carries the path is
#     <div class="c" data-path="...">. Both forms are accepted: the old <td> so a page
#     built before the grid ledger still passes, and the grid cell for everything since.
paths = page.scan(/data-path="/).size
cells = page.scan(/<(?:td|div class="c")[[:space:]]+data-path="/).size
if paths == cells
  check.ok("data-path is only on ledger rows (#{paths})")
else
  check.bad("#{paths - cells} data-path attribute(s) outside a ledger cell — the coverage gate reads them as ledger paths; excerpts must use data-src")
end

# 5 · Dead links. When the head commit is on no remote, every permalink to it 404s, and
#     rung 4 of the ladder says plain text instead.
if check.repo.to_s.empty?
  check.skip("link reachability: needs --repo to ask git what is pushed")
else
  remotes, = check.shell("git", "-C", check.repo, "branch", "-r", "--contains", check.head_ref)
  if remotes.empty?
    if page.has?(%r{https://github\.com/[^"]*/(blob|pull|compare)/})
      check.bad("emits GitHub permalinks, but the head commit is on no remote — those 404")
    else
      check.ok("unpushed head: citations are plain text, no dead permalinks")
    end
  else
    check.ok("head is on a remote: permalinks are legitimate (link form not checked here)")
  end
end

# 6 · The three theme states. A colour defined only inside a media query is the classic
#     unreadable-artifact bug; this catches the structural version of it. A fragment
#     carries no token block at all, so there is nothing here to check.
if check.kind != "page"
  check.skip("theme states: a fragment carries no token block")
else
  missing = []
  missing << "prefers-color-scheme" unless page.has?("prefers-color-scheme: dark")
  missing << "data-theme=dark" unless page.has?(/\[data-theme="dark"\]/)
  unless page.has?(/\[data-theme="light"\]|:root:not\(\[data-theme="light"\]\)|^:root|[^-]:root[[:space:]]*\{/)
    missing << "bare-:root"
  end
  if missing.empty?
    check.ok("all three theme states present")
  else
    check.bad("theme states missing: #{missing.join(" ")}")
  end

  # The blocks existing is not the same as a colour being in all three of them. --rails is
  # checked by name because it is the newest colour and the easiest to half-declare: nothing
  # on the page depends on it to be readable, so a set missing from the dark blocks is
  # invisible until someone opens a primer with the OS in dark mode. Same idiom as the
  # --syn-* sweep in excerpts.rb, and for the same reason.
  rails = page.count("--rails:")
  if rails.zero?
    check.skip("--rails: this page has no primer colour to check")
  elsif rails >= 3
    check.ok("--rails defined in all three theme blocks")
  else
    check.bad("--rails is declared #{rails} time(s), needs 3 — bare :root plus both dark blocks")
  end
end

check.finish
