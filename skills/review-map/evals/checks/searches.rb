#!/usr/bin/env ruby
# frozen_string_literal: true

# searches.rb — "record what was searched", checked against the repository.
#
# The rule this owns is not "is a search written down" — that is cheap and a page can satisfy
# it with a search that finds nothing it claims. It is: DOES THE RECORDED SEARCH REPRODUCE THE
# ENTRY IT IS OFFERED FOR.
#
# The failure that produced this script: a run recorded `rg -n 'account_type' app test db config`
# and said it returned every reader of the column, having just cited two guards that read that
# column through the enum predicate `steward?` — which the pattern does not match. Real search,
# right entries, false provenance, and nothing mechanical noticed. The judge did, at the cost of
# a model call.
#
# So this check RE-RUNS the recorded searches inside --repo and asks whether each cited entry is
# in their combined output. Re-running rather than matching the cited line against the pattern is
# deliberate: a search carries a PATH SCOPE, and ignoring it is how a check vouches wrongly. That
# same run recorded `rg -n 'steward|account_type|plan' app/views`, whose pattern does match
# `current_user.steward?` — so pattern-only matching would have passed the very entry the search
# could not have found, because the search never looked in app/controllers.
#
# Two things it deliberately does not do. It does not require every claim to record a search inline:
# § 2 has no such rule, so a fragment with affected entries and no recorded search WARNs rather
# than fails. And it skips entries that POINT at a checkpoint — their provenance lives where that
# explains them, which a fragment cannot see.
#
# What needs a reader: whether a search was the RIGHT one to run. This only settles whether the
# ones on offer reach what they are offered for.
#
# THE MATCHING STAYS IN grep, AND THAT IS THE POINT OF THIS FILE. Ruby has no BRE, and `\|` is
# alternation in grep's default BRE but a literal pipe in rg. Translating a page's recorded
# pattern into a Ruby regexp would silently change what that page's own search means — so this
# ports the orchestration, the parsing and the reporting, and hands every pattern to the tool
# whose dialect it was written in.

require_relative "lib/review_map/check"

module Searches
  TOOL_PREFIX = /^[[:space:]]*(git[[:space:]]+)?(rg|grep|egrep|ag)[[:space:]]/
  RERUN_PREFIX = /^[[:space:]]*(git[[:space:]]+)?(rg|grep|egrep|ag)[[:space:]]/
  ENTITIES = [["&amp;", "&"], ["&lt;", "<"], ["&gt;", ">"], ["&quot;", '"'], ["&#39;", "'"]].freeze
  # a.path is the current citation form and span.cite the retired one; both count.
  # Non-capturing on purpose: these are scanned off a plain String, where a group makes scan
  # return the group instead of the match. Page#scan is immune to that; String#scan is not.
  CITE = /class="(?:cite|path)"[^>]*>[^<]*</
  # Ranges arrive with a NON-BREAKING hyphen: real pages write :15&#8209;27, not :15-27. Left
  # undecoded, "15&#8209;27" is not a number, the entry falls through to `unresolved`, and the
  # check reports nothing wrong while checking nothing at all — the same silent-pass shape as
  # the markup drift below, which is why the decode sits with the extraction.
  HYPHENS = ["&#8209;", "&#x2011;", "&ndash;", "&#8211;"].freeze

  # Every element-delimited text node, then the ones that look like a search invocation.
  #
  # Not just <code>: nothing in the format says a recorded search has to be one, and a run put
  # its whole search table in <td><span class="cite">grep -rn ...</span></td>, which a
  # <code>-only extractor read as ONE recorded search out of ten — and then failed the nine
  # entries the other nine would have found. Text nodes are element-delimited by construction,
  # so requiring the node to BEGIN with the tool keeps prose like "one grep is not enough" out.
  def self.text_nodes(page)
    page.lines.flat_map { |raw| nodes_in(raw.chomp) }
  end

  # The scan re-includes the closing `<`, the way the awk did by stepping back one character,
  # so `>a</span><span>b<` yields both nodes rather than only the first.
  def self.nodes_in(line)
    found = []
    pos = 0
    while (m = line.match(/>[^<]*</, pos))
      found << m[0][1..-2]
      pos = m.end(0) - 1
    end
    found
  end

  def self.decode(text)
    ENTITIES.reduce(text) { |acc, (entity, char)| acc.gsub(entity, char) }
  end

  Command = Struct.new(:prefix, :pattern, :paths)

  # Split into pattern and paths without eval. A quoted pattern first; failing that, the first
  # token that is not a flag.
  def self.parse(command)
    quoted = split_on_quote(command, "'") || split_on_quote(command, '"')
    return quoted if quoted

    # rg -n foo app lib — walk the tokens, first non-flag after the tool is the pattern.
    tokens = command.split
    prefix = [tokens.shift]
    pattern = nil
    while (token = tokens.shift)
      if token.start_with?("-")
        prefix << token
      else
        pattern = token
        break
      end
    end
    Command.new(prefix.join(" "), pattern, tokens.join(" "))
  end

  def self.split_on_quote(command, quote)
    first = command.index(quote)
    return nil if first.nil?

    second = command.index(quote, first + 1)
    return nil if second.nil?

    Command.new(command[0...first], command[(first + 1)...second], command[(second + 1)..])
  end

  # RE-RUN IT WITH THE DIALECT IT WAS WRITTEN IN. This is not fussiness: `\|` is alternation
  # in grep's default BRE and a LITERAL PIPE in rg, so running a recorded
  # `grep -rn "recommendable\|general_recommendations_eligible" app` through rg matches
  # nothing — and the check then reports every entry that search found as unreachable. A check
  # that invents failures is worse than no check, and this one invented ten before it was fixed.
  def self.engine_for(prefix)
    # `git grep` is grep for every purpose here — same dialect flags, and the `--` that
    # separates its pattern from its paths is already dropped by the flag filter. Strip the
    # `git` so the dispatch below sees the tool it actually is. Not a nicety: a real run
    # recorded all six of its searches as `git grep -nE "..." -- api/app`, an entirely
    # idiomatic form, and every one was discarded before reaching here — leaving the page
    # reported as having recorded NO search at all, which is the opposite of what it had done.
    words = prefix.to_s.split
    prefix = words.drop(1).join(" ") if words.first == "git"
    tool = File.basename(prefix.to_s.split(/[[:space:]]/).first.to_s)
    engine =
      case tool
      when "rg", "ag" then :rg
      when "egrep" then :ere
      when "grep"
        # The shell tested `case " $prefix " in *\ -*E*\ *|*\ -*F*\ *)`, and a glob `*` spans
        # spaces — so a `-` in one token and an `E` in a LATER one selected ERE. Scoping the
        # flag letter to its own token, which is what it means, would read `grep -rn NOTE 'a\|b'
        # app` as BRE where the shell reads it as ERE, and BRE alternation reaches an entry that
        # ERE does not: a PASS where the shell FAILs. That only happens on a malformed recorded
        # command, where both are guessing — but this port's contract is byte-identical output,
        # and a verdict is the last thing it may quietly change. So the looseness is reproduced
        # here, deliberately. If it is wrong it is wrong in both, and fixing it means a golden
        # fixture and a change to both, not a silent correction inside a port.
        padded = " #{prefix} "
        if padded.match?(/ -.*[EP].* /) then :ere
        elsif padded.match?(/ -.*F.* /) then :fixed
        else :bre
        end
      else :ere
      end
    # No rg on this machine and an rg pattern: grep -E is close enough for the alternation and
    # character classes these patterns actually use, and firing approximately beats skipping.
    engine = :ere if engine == :rg && !which("rg")
    engine
  end

  def self.which(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
       .any? { |dir| File.executable?(File.join(dir, name)) }
  end

  def self.argv_for(engine, pattern, paths)
    case engine
    when :rg    then ["rg", "--no-heading", "--line-number", "--no-messages", "--regexp", pattern, "--", *paths]
    when :ere   then ["grep", "-rEn", "--no-messages", "-e", pattern, "--", *paths]
    when :fixed then ["grep", "-rFn", "--no-messages", "-e", pattern, "--", *paths]
    else             ["grep", "-rn", "--no-messages", "-e", pattern, "--", *paths]
    end
  end

  # Scoped by the template's own markers rather than by a section id, which is what lets one
  # rule read both places the label appears: section 04 carries
  # <p class="eyebrow">Affected, not changed</p> beside the panel and the evidence foot carries
  # it again over the lower-priority list. That label is verbatim in both, and it has to sit
  # directly after the class attribute for this to open on it. The Changed column, the end of a
  # field and <h3> reset it.
  # AN ENTRY IS WHATEVER THE TEMPLATE EMITS, and it stopped being <li>. When the design system
  # moved § 4 from div.two-col > div.card > ul > li > span.cite to dl.rows > dt/dd > div.item >
  # a.path, this extractor was not moved with it — and neither were the goldens self-test.rb
  # measures it against, so the check went on passing its own suite while matching nothing on
  # any real page. Two published runs, one at each detail level, both came back SKIP with
  # checked=0: the header above says a search that finds nothing it claims is the failure this
  # script exists for, and for months it was the script doing exactly that. Both shapes are read
  # now — the <li> accumulation so an older page still grades, and a single-line div.item, which
  # is how page-template.html and every real page write it.
  #
  # The .item form is read as ONE LINE. That is the template's shape, and it also keeps the
  # <a class="cite"> inside a details.excerpt .ex-src — which sits in the same <dd> — from being
  # mistaken for the entry's own citation, since it is never on an .item line.
  def self.affected_entries(page)
    affected = false
    in_li = false
    buffer = ""
    entries = []

    page.lines.each do |raw|
      line = raw.chomp
      affected = false if line.match?(%r{class="eyebrow"[^>]*>[^<]*[Cc]hanged[^<]*</p>}) && !line.match?(/[Aa]ffected/)
      affected = false if line.match?(%r{<dt[^>]*>[^<]*[Cc]hanged</dt>}) && !line.match?(/[Aa]ffected/)
      affected = true if line.match?(/class="eyebrow"[^>]*>[^<]*[Aa]ffected/)
      affected = true if line.match?(/<dt[^>]*>[^<]*[Aa]ffected/)
      # </ul> and </section> joined the resets when the affected list stopped being a dl field.
      # Without them the region opened in section 04 stays open through the evidence foot, and
      # the <li> rows inside details.searched are collected as affected entries — every recorded
      # search read as a claim that needed a recorded search.
      affected = false if line.match?(%r{</dd>|<h3|</dl>|</ul>|</section>})

      if affected && line.match?(/class="item"/)
        entries << line
        next
      end

      if affected && line.match?(/<li/)
        in_li = true
        buffer = ""
      end
      next unless in_li

      buffer = "#{buffer} #{line}"
      next unless line.match?(%r{</li>})

      entries << buffer
      in_li = false
    end

    entries
  end

  def self.citations(entry)
    entry.scan(CITE)
         .map { |seg| seg.sub(/\A[^>]*>/, "").sub(/<\z/, "") }
         .map { |cite| HYPHENS.reduce(cite) { |acc, h| acc.gsub(h, "-") } }
  end
end

check = ReviewMap::Check.new(ARGV)
check.require_input

if check.repo.to_s.empty?
  check.skip("search provenance: needs --repo to re-run the searches the page recorded")
  check.finish
end
unless File.directory?(check.repo)
  check.bad("search provenance: --repo is not a directory: #{check.repo}")
  check.finish
end

# Comments are not markup and must not be read as either a search or an entry — see
# Page#without_comments for the case that forced it.
page = check.page.without_comments

commands = Searches.text_nodes(page)
                   .select { |node| node.match?(Searches::TOOL_PREFIX) }
                   .map { |node| Searches.decode(node) }
                   .select { |node| node.match?(Searches::RERUN_PREFIX) }

hits = []
unparsed = []
recorded = 0

commands.each do |command|
  next if command.empty?

  parsed = Searches.parse(command)
  if parsed.pattern.to_s.empty?
    unparsed << command
    next
  end

  # Drop any remaining flags from the path list; an empty list means the whole repo.
  paths = parsed.paths.to_s.split.reject { |p| p.start_with?("-") }
  paths = ["."] if paths.empty?
  recorded += 1

  engine = Searches.engine_for(parsed.prefix)
  out, = check.shell(*Searches.argv_for(engine, parsed.pattern, paths), chdir: check.repo)
  # cut -d: -f1,2 — path and line, which is the granularity an entry cites.
  hits.concat(out.lines.map { |line| line.chomp.split(":", 3).first(2).join(":") })
end

hits = hits.sort.uniq

checked = 0
missing = 0
pointers = 0
unresolved = 0
failures = []

Searches.affected_entries(page).each do |entry|
  next if entry.empty?

  if entry.match?(/href="#cp-/)
    pointers += 1
    next
  end

  cites = Searches.citations(entry)
  next if cites.empty?

  # The entry's SUBJECT is its first full citation; later ones are supporting. A bare :N binds
  # to the citation immediately before it and no further — the run that prompted this check
  # wrote "...test_helper.rb:7-24 ... (redirect_test.rb:21, :38)", where a rule of "narrowest
  # bare cite in the entry" would have attributed :38 to test_helper.rb.
  subject = nil
  next_cite = nil
  cites.each do |cite|
    if subject
      next_cite = cite
      break
    end
    subject = cite if cite.match?(%r{\A.*/.*:[0-9]})
  end

  unless subject
    unresolved += 1
    next
  end

  path = subject.split(":").first
  unless File.file?(File.join(check.repo, path))
    unresolved += 1
    next
  end

  if next_cite.to_s.match?(/\A:[0-9]/)
    first = next_cite.delete_prefix(":")
    last = first
  else
    lines = subject.sub(/\A[^:]*:/, "")
    first = lines.split("-").first.to_s
    last = lines.split("-").last.to_s
  end

  unless first.match?(/\A[0-9]+\z/)
    unresolved += 1
    next
  end
  last = first unless last.match?(/\A[0-9]+\z/)

  checked += 1
  # The narrowest cited range, not the enclosing one: checking the enclosing range instead is
  # how a guard that reads a column at :67 gets vouched for by a match on :70.
  found = (first.to_i..last.to_i).any? { |n| hits.include?("#{path}:#{n}") }
  next if found

  missing += 1
  failures << (first == last ? "#{path}:#{first}" : "#{path}:#{first}-#{last}")
end

# ---------------------------------------------------------------- verdicts
if recorded.zero?
  if checked.positive? || pointers.positive?
    check.maybe("affected entries are present but no search is recorded anywhere — provenance cannot be checked, and unrecorded, absence and omission look identical")
  else
    check.skip("no recorded search and no affected entry to check one against")
  end
else
  check.ok("#{recorded} recorded search(es) re-run inside the repository")
end

if unparsed.any?
  check.maybe("#{unparsed.size} recorded command(s) could not be parsed into a pattern and paths — read them by hand")
end

if recorded.zero?
  # Nothing recorded means provenance is UNVERIFIABLE, not false. The warning above is the
  # whole verdict: failing every entry here would punish § 2, which has no rule requiring a
  # every claim to record its searches inline, for a rule only section 04 states.
  unless checked.zero?
    check.skip("#{checked} cited entr(ies) left unchecked: with no search recorded there is nothing to check them against")
  end
elsif checked.zero?
  check.skip("no affected entry resolved to a file in the repo, so provenance had nothing to check")
elsif missing.zero?
  check.ok("every one of #{checked} cited entr(ies) is reachable from a recorded search")
else
  # One line, because the Check contract is one line per expectation and the expectation is
  # "the recorded searches reproduce the entries" — not one per entry. Naming the first few is
  # what makes it actionable; the count is what says how far it goes.
  named = failures.first(5).join(" ")
  named = "#{named}, and #{missing - 5} more" if missing > 5
  check.bad("#{missing} of #{checked} cited entr(ies) are reachable from no recorded search: #{named}")
end

# Coverage of the check itself, so a small number of FAILs cannot be read as a clean sweep.
unless pointers.zero?
  check.skip("#{pointers} entr(ies) point at a checkpoint: their provenance lives there, not here")
end
unless unresolved.zero?
  check.skip("#{unresolved} entr(ies) carried no citation this check could resolve to a file in the repo")
end

check.finish
