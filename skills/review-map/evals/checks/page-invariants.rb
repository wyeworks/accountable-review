#!/usr/bin/env ruby
# frozen_string_literal: true

# page_invariants.rb — the rules that hold everywhere on the page, and therefore in
# every fragment of it too: no grading, no advertising that the page was checked and no
# boilerplate hedge disclaiming it either, no unlabelled inference, no reserved attribute
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
# `an` is in the third alternative because it was NOT, and the grammatical form was the one that
# escaped: "on a earlier pass" is a sentence nobody writes, "on an earlier pass" is the sentence a
# run writes. Found by running the rule against wordings rather than by reading it, the same way
# the negation boundaries above were — and it matters more since --update, the one mode where a
# run has an earlier pass to narrate.
NARRATE = Regexp.union(
  /(first|earlier|previous|initial|original) (version|draft) of (this|the) (section|page|flow|paragraph|entry|list|row|claim|map|file)/i,
  /(a|the|this) (first|earlier|previous|initial) (pass|draft|version) (got|had|reported|missed|claimed|said|read|ran|rested|came)/i,
  /on (an?|the) (first|earlier|previous) (pass|draft|run|version)/i,
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
# 'verified' is a real column name in real Rails apps.
# The `re-?` prefixes are not decoration. "every claim was re-checked against the new commits" is
# the sentence an --update run reaches for, and without them it read as clean while saying exactly
# what a verification badge says. The numeric alternative is that badge with the arithmetic left to
# the reader: "3 of 5 checkpoints re-analysed" advertises how much of the page was looked at again,
# which report-format.md § Build state § An updated page refuses for the reason a count of
# corrected claims is refused at --effort high.
ASSURE = /(independently|adversarially|externally) verified|verification pass|falsification pass|(claims|findings) (were|have been|are all) (re-?)?(verified|checked|confirmed)|every claim (was|has been) (re-?)?(verified|checked|confirmed)|\d+ of \d+ (checkpoints?|judgments?|claims?|sections?) (were |have been )?(re-?)?(analysed|analyzed|verified|checked|derived|read)|class="(verified|checked)"|chip-verified/i

# The standing disclaimer, which is the OPPOSITE leak from ASSURE and therefore its own rule:
# that one is the page overclaiming its coverage, this one is the page hedging it in a sentence
# no reviewer acts on. "These are what this pass surfaced, not an audit" used to open section 02
# and has been removed — it is true of every Review Map rather than of this one, so README.md
# § "What a Review Map cannot do" states it once for the tool and the page states it never. A
# disclaimer a reader has met before is a line they skip, and the next line they skip is the
# first checkpoint.
#
# WARN rather than FAIL, and graded on the COMMENT-STRIPPED copy for the reason § 2's graded
# noun is: page-template.html says in a comment why the caveat is not there, and a real page
# carries that comment verbatim. A warning because the phrasings below also have honest uses —
# "the grep is not exhaustive" about one search is a fact, not a hedge about the page — so the
# line needs reading rather than failing.
DISCLAIM = /not an? (full )?audit|not (an )?exhaustive|this pass surfaced|pass, not an|overlapping but different/i

# The flow vocabulary, which is gone from the page the way the severity vocabulary is gone from the
# design system — and this is the § 1 rule for it. A flow is SKILL.md step 6's unit of ANALYSIS: it
# becomes a checkpoint, an impact path or a foot entry, it is named in $W/analysis/, and the page
# names it nowhere. So "Flow A" on a page points at a section nobody wrote, and the reader who
# follows it finds no rail entry for it.
#
# FAIL rather than WARN, because unlike a graded noun there is no sentence that legitimately carries
# one: the name has nothing on the page to mean. The letter class stops at G, seven checkpoints being
# the page's outside, and the trailing boundary is what keeps the rule off "Flow Hooks" — a letter
# class alone would have matched the F-word and the capital after it in any prose.
#
# Graded on the comment-stripped copy, for § 2's reason rather than § 3's: a published page carries
# page-template.html's comments verbatim, so a comment there explaining why the page names no flow
# would be written in the words this matches — which is exactly how § 2's graded noun was caught
# failing a correct page. Its own fixture therefore must not name the label in its header comment,
# or deleting this rule's prose half would leave the fixture failing and the mutation test would
# report a bypass as caught.
FLOW_LABEL = %r{\bFlows? [A-G]\b|(?:id|href)="\#?flow-}

# Recency, which is the severity chip arriving as provenance and --update is the door it comes
# through. When a re-run finds that the new commits answered a checkpoint, the tempting thing is to
# strike it through or label it resolved — showing the reviewer what has been addressed. A page
# with three of five questions ticked reports progress toward approval, which is the one output
# this format exists to withhold, so the checkpoint is deleted instead and nothing marks where it
# was. New / updated / carried is the same regression a step earlier: three ordered states beside a
# question is a scale in different words, and it would pull a run toward hoisting the new ones to
# the top, turning a ranked agenda into a changelog of the change.
#
# UNCONDITIONAL, and that is the point of it living here rather than behind --updated in
# build-state.rb: an ordinary run must not write these either, so there is no flag to forget. What
# IS conditional — the disclosure sentence being present — is the other file's, because only an
# updated page owes it.
#
# FAIL rather than WARN, for FLOW_LABEL's reason: there is no sentence that legitimately carries
# one. Graded on the comment-stripped copy, because page-template.html refuses the carry badge in a
# comment written in exactly these words and a real page carries that comment verbatim — which is
# how § 2's graded noun was caught failing a correct page. Its fixture therefore must not name the
# marker in its own header comment, or deleting this rule would leave the fixture failing and the
# mutation test would report a bypass as caught.
RECENCY = Regexp.union(
  # A WHOLE space-delimited class, not an exact attribute: the marker arrives as
  # class="cp updated", so an exact-quote match would have counted zero of the real ones — § 3's
  # tier-modifier bug, in the direction where the rule passes a page that carries the defect.
  /class="(?:[^"]* )?(?:new|carried|updated|resolved|addressed)(?: [^"]*)?"/i,
  /\b(?:new|updated|carried|unchanged) since (?:the )?(?:last|previous) (?:map|review|run|push)\b/i,
  /\b\d+ of \d+ (?:checkpoints?|judgments?|questions?) (?:were |have been )?(?:addressed|resolved|answered|re-?analysed|re-?analyzed|re-?derived)\b/i,
  /<(?:s|del|strike)>/i
)

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

# 2d · The standing disclaimer. Between this and 2b the page is pinned from both sides: it may
#      not advertise having been checked, and it may not carry a boilerplate hedge either. What
#      it carries instead is the claims, each at the tier it earned.
if prose.has?(DISCLAIM)
  hedged = prose.scan(DISCLAIM).sort.uniq
  check.maybe("a standing disclaimer may have come back — that sentence lives in README.md, not on the page: #{hedged.join(" ")} ")
end

# 2e · Recency as a marker. The checkpoints are ranked and an order is not a scale; a marker saying
#      which of them are new since the last map is that scale rebuilt out of words that sound like
#      provenance. The page says WHICH REVISION its content describes, once, and never which parts
#      of it were re-read.
if prose.has?(RECENCY)
  marked = prose.scan(RECENCY).sort.uniq
  check.bad("a checkpoint is marked by its recency — the page says which revision it describes, never which parts were re-read: #{marked.join(" ")} ")
else
  check.ok("no recency markers — an answered checkpoint is deleted rather than ticked")
end

# 3 · Evidence tiers. Silence is the first tier, so a document with no label either had
#     nothing to infer, which is rare, or presented inference as fact, which is the
#     failure this catches.
#
#     The trailing character class is load-bearing: two of the five tiers carry a
#     family modifier (`class="tier tier-unc"`, `class="tier tier-inf"`), and an
#     exact-quote match counted only the unmodified ones. A page whose every tier
#     was `from unchanged code` therefore read as a page with no tiers at all —
#     the worst direction for this rule to be wrong in, because the message it
#     prints then accuses a correctly-evidenced page of presenting inference as
#     fact. Found by adding the modifier, not by reading the rule.
TIER = /class="tier[ "]/
if page.has?(TIER)
  check.ok("evidence tiers used (#{page.count(TIER)} label(s))")
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

end

# 7 · The flow vocabulary. Step 6's analysis labels and the page's own designators share one
#     alphabet, so a run holding a note called Flow A, writing a checkpoint whose id is cp-a,
#     beside an impact path called A, has no local signal that one of the three labels is its own.
#     One real page carried "(Flow A)" in a checkpoint's second sentence and "Impact path A" in its
#     last — both namespaces in one paragraph. report-format.md § One canonical home owns the rule.
if prose.has?(FLOW_LABEL)
  named = prose.scan(FLOW_LABEL).sort.uniq
  check.bad("the page names a flow — that is the run's analysis unit, and the page refers to Checkpoint <letter> and Impact path <letter> only: #{named.join(" ")} ")
else
  check.ok("no flow designator — the page refers to checkpoints and impact paths only")
end

check.finish
