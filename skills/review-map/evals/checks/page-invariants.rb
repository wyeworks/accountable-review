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

# Verdict language, in two families, because one of them is legitimate as a DENIAL.
#
# Deliberately high-precision patterns: 'blocking' alone is a false positive ('blocks the
# request', 'locks the table'), so it is a WARN below rather than a failure here.
#
# The split was forced by a correct page failing. § 7's ledger wrote "Attention is a reading
# estimate, not a risk score" — the page telling the reader that read/skim/mechanical is not
# severity, which is the no-grading invariant defending itself in the one place a reader is most
# likely to misread a column as a grade. The check failed it for containing the words. A rule
# that punishes a page for refusing a verdict teaches the run to stop refusing it out loud,
# which is the opposite of what rule 2 is for.
#
# So: HARD is never right in any form. A GRADED NOUN fails only where nothing refuses it.
VERDICT_HARD = /LGTM|looks good to me|recommend (?:approv|merg)[a-z]*|approve this|ready to merge/i
GRADED_NOUN = /risk score|overall risk|severity score|severity rating/

# The negation must be a WHOLE WORD, bounded on both sides. POSIX awk has no \b and each missing
# boundary loses a real defect: without the leading one "no" matches inside "another" and
# "denote", so "another way to read the overall risk" excuses itself; without the trailing one
# "not" matches inside "notice" and "notify", so "notice the overall risk" does too. Both were
# caught by testing the rule rather than reading it.
REFUSAL = /(?:\A|[^[:alpha:]])(?:not|nothing|never|no|rather than|instead of|without)(?:[^[:alpha:]][^.!?;]{0,23})?\z/

# The page narrating its own drafting. A separate rule from the assurance one because it is a
# separate failure with a separate fix: that is the page claiming it was checked, this is the
# page telling the reader what an earlier draft of it said. Both leak the run's process, and this
# one leaks it while reading as candour, which is why a run writes it without noticing — one
# --effort high page carried ten. A falsification pass does not have to be named to be on the
# page. The fix is never to delete the fact, only the autobiography.
NARRATE = Regexp.union(
  /(first|earlier|previous|initial|original) (version|draft) of (this|the) (section|page|flow|paragraph|entry|list|row|claim|map|file)/i,
  /(a|the|this) (first|earlier|previous|initial) (pass|draft|version) (got|had|reported|missed|claimed|said|read|ran|rested|came)/i,
  /on (a|the) (first|earlier|previous) (pass|draft)/i,
  /(this|the) (section|page|paragraph|entry|claim|row) (originally|initially) (said|read|claimed|reported|had)/i
)

# Per occurrence, not per document: one refused mention does not license an asserted one
# elsewhere on the page. The window is the 48 characters before the noun, and a negation counts
# only if nothing but short filler ("not a ", "rather than an ") stands between it and the noun —
# so "not X, this is an overall risk of 4" is still caught. Sentence-ending punctuation bounds the
# window, because the previous sentence's "not" is not this one's.
def asserted_grades(page)
  found = []
  page.lines.each do |raw|
    # The remainder is CONSUMED, not merely scanned past, which is what makes the rule per
    # occurrence rather than per line: a later noun's window cannot see back over an earlier
    # one, so "not a risk score, but the overall risk is 4" refuses the first and catches the
    # second. Scanning with an offset instead leaves the whole line visible to the window and
    # the earlier "not" excuses the later noun — a false PASS on a sentence that grades.
    rest = raw.chomp.downcase
    while (m = rest.match(GRADED_NOUN))
      window = rest[[m.begin(0) - 48, 0].max...m.begin(0)]
      found << m[0] unless window.match?(REFUSAL)
      rest = rest[m.end(0)..]
    end
  end
  found.sort.uniq
end

# Assurance language, which is a verdict about the PAGE rather than about the PR and therefore
# easy to reintroduce while believing rule 2 still holds. A run at --effort high sends an
# adversarial pass at its own flows; nothing about that is allowed to reach the page (SKILL.md
# step 8, report-format.md § Detail levels). The patterns are high-precision on purpose: a bare
# 'verified' is a real column name in real Rails apps, and 'audit' appears inside the sanctioned
# "a pass, not an audit".
ASSURE = /(independently|adversarially|externally) verified|verification pass|falsification pass|(claims|findings) (were|have been|are all) (verified|checked|confirmed)|every claim (was|has been) (verified|checked)|class="(verified|checked)"|chip-verified/i

check = ReviewMap::Check.new(ARGV)
check.require_input
page = check.page

# 1 · The severity vocabulary is gone from the design system. If these class names are
#     back, the page is grading again, whatever its prose says.
if page.has?(/chip-(block|watch|good)/)
  check.bad("severity chips reintroduced (chip-block/chip-watch/chip-good)")
else
  check.ok("no severity chips")
end

# 2 · Verdict language. A comment is not markup, and the prose rules must not read one:
#     page-template.html's header comments discuss verdicts and revision history in the exact
#     words these rules match, and a published page carries them verbatim.
prose = page.without_comments

if page.has?(VERDICT_HARD)
  check.bad("verdict language found: #{page.scan(VERDICT_HARD).sort.uniq.join(" ")} ")
else
  check.ok("no verdict or approval language")
end

graded = asserted_grades(prose)
if graded.any?
  check.bad("a graded noun asserted rather than refused: #{graded.join(" ")} ")
else
  check.ok("no asserted risk or severity score")
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

# 2c · Draft narration.
if prose.has?(NARRATE)
  narrated = prose.scan(NARRATE).sort.uniq
  check.bad("the page narrates its own drafting — a correction replaces a claim, it never annotates it: #{narrated.join(" ")} ")
else
  check.ok("no draft narration — corrections are written as claims, not as revisions")
end
if prose.has?(/got it wrong|came to rest on|invalidated (several|some) of these/i)
  check.maybe("a phrase that usually introduces draft history — read the sentence, and check it is about the code rather than about this page")
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
# An empty answer and NO answer are different, and only one of them means unpushed. Written
# with `|| true`, an unreadable repo or an unresolvable head produced empty output and this rule
# read it as "on no remote" — a false PASS on a page with no permalinks, and a false FAIL on one
# that has them. The verdict came from an answer git never gave, so the two are separated here
# and the rule refuses rather than guesses. A flat chain rather than a nested one because there
# are now three distinct states and nesting them hid that there were only two.
have_repo = !check.repo.to_s.empty?
remotes, git_answered =
  if have_repo
    check.shell("git", "-C", check.repo, "branch", "-r", "--contains", check.head_ref)
  else
    [nil, false]
  end

if !have_repo
  check.skip("link reachability: needs --repo to ask git what is pushed")
elsif !git_answered
  check.skip("link reachability: git cannot say whether #{check.head_ref} is pushed in #{check.repo} — with no answer this rule has nothing to check the citation form against")
elsif remotes.empty?
  if page.has?(%r{https://github\.com/[^"]*/(blob|pull|compare)/})
    check.bad("emits GitHub permalinks, but the head commit is on no remote — those 404")
  else
    check.ok("unpushed head: citations are plain text, no dead permalinks")
  end
else
  check.ok("head is on a remote: permalinks are legitimate (link form not checked here)")
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
