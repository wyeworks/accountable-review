#!/usr/bin/env ruby
# frozen_string_literal: true

# rails_anchors.rb — the two framework anchors: documentation links and runtime probes.
#
# Both exist to make a claim about the framework followable. Both fail in ways that look
# like diligence, which is why they are checked mechanically rather than trusted:
#
#   a URL nobody opened            reads as a citation, resolves to a 404
#   a doc link with no file:line   reads as evidence, says nothing about this repo
#   a probe with output beneath it reads as the most concrete thing on the page,
#                                  and is the one part of it that is fiction
#   a probe naming a missing scope reads as pasteable, fails on first paste
#   a link on every mechanism      reads as thoroughness and is a Rails manual with a
#                                  diff attached
#
# The catalogue is the allowlist, and this script derives it from the files rather than
# hard-coding hosts: references/rails-docs.md and references/elixir-docs.md are the single
# home for what may be cited, so a row added to either is immediately legal here and a URL
# invented in a run is not. Both are read on every page, not the one the page's stack
# suggests: a page cites from one catalogue, but nothing in the markup says which, and
# guessing the stack here would be a rule that fails on a monorepo touching both.
#
# The name is Rails-shaped and the scope is not, deliberately: renaming it would churn
# check.rb, self-test-cases.txt, evals.json, a case and a driver for no behavioural gain.
#
# What needs a reader, and lives in the case: whether the link is the RIGHT concept for
# the claim, and whether the probe is the one worth proposing. This settles only whether
# what is on offer is real.
#
# --repo is what makes rule 7 possible, the way it makes searches.rb possible. Without it
# the identifier check SKIPs rather than passing on evidence it does not have.
#
# THE PRIMER IS GONE, along with the aside it lived in and the pre.demo it licensed. It was a
# --full-only callout on a page that no longer has levels, and a component with no markup left
# cannot be graded: what remains is the link and the probe, which are what an agenda page
# actually anchors with. report-format.md § A future full mode records what the rules were.

require_relative "lib/review_map/check"

module RailsAnchors
  # A code permalink belongs to the deep-link ladder, which page_invariants.rb § 5 owns.
  # `tree/` is NOT excluded, though it once was: a tag-pinned gem README — the only github.com
  # shape a doc link may take — is exactly `tree/v2.8.0#section`, so excluding it meant the one
  # github doc link the catalogue offers was the one nothing checked.
  PERMALINK = %r{\Ahttps://github\.com/[^/]+/[^/]+/(?:blob|pull|compare|commit)/}
  RAILS_HOST = %r{\Ahttps://(?:guides|api)\.rubyonrails\.org/}
  # /v<digit>, NOT /v — a guide page whose name merely begins with the letter v
  # (`validations.html`) took the "pinned" branch under a /v* glob, yielded no series, and so
  # was recorded in neither list and checked by neither rule.
  PINNED = %r{\Ahttps://(?:guides|api)\.rubyonrails\.org/v[0-9]}
  SERIES = %r{\Ahttps://[a-z.]*rubyonrails\.org/v([0-9][0-9.]*)/}
  HEXDOCS = %r{\Ahttps://hexdocs\.pm/}
  # hexdocs.pm/<pkg>/<version>/…, where <version> starts with a digit. The package sits between
  # the host and the version, so a pinned link and an unpinned one differ in their SECOND
  # segment and nowhere else.
  HEXDOCS_PINNED = %r{\Ahttps://hexdocs\.pm/[^/]+/[0-9][^/]*/}

  # Constants that are the framework's own or Ruby's, so they say nothing about this repository.
  # ONE list, because two rules need it: rule 7 skips these when asking whether a constant
  # exists, and the scope rule skips them as RECEIVERS. When only the constant rule had it,
  # `Rails.application` sailed past rule 7 and then failed the scope rule for calling an
  # "undefined method" named `application`.
  FW = "ActiveRecord|ActiveJob|ActiveSupport|ActionController|ActionDispatch|ActionMailer|Rails|I18n|JSON|Base|Time|Date|DateTime|Logger|STDOUT|Hash|Array|String|Integer|Float|Object|Kernel|GC|ENV|PP"
  FRAMEWORK = /\A(#{FW})/
  FRAMEWORK_RECEIVER = /\A(#{FW})\./
  FRAMEWORK_NS = /\A(ActiveRecord|ActiveJob|ActiveSupport)::/
  CONSTANT = /\b[A-Z][A-Za-z0-9]*(?:::[A-Z][A-Za-z0-9]*)*\b/

  # ActiveRecord's own surface: real methods on every model, and so no evidence about this app.
  AR_API = %w[to_sql all new first last count where order limit select pluck find find_by
              find_each in_batches explain connection columns_hash column_names attribute_names
              defined_enums validators_on validators reflect_on_association
              reflect_on_all_associations nested_attributes_options queue_name serialize
              instance_methods primary_key table_name create! create update! update destroy
              delete_all update_all insert_all upsert_all save save! unscoped default_scoped
              reload attributes as_json to_json].freeze

  MUTATING = /create!?\(|update!?\(|update_all|update_column|destroy|delete_all|save!?\b|insert_all|upsert_all|touch\(|archive!/
  FABRICATED = /\A[[:space:]]*(?:=>|#[[:space:]]*=>)/
  FABRICATED_SQL = /\A[[:space:]]*(?:SELECT|INSERT|UPDATE|DELETE)[[:space:]]/i
  # A leading `[` or `{` is output only OUTSIDE a quoted script — see fabricated_line below.
  FABRICATED_LITERAL = /\A[[:space:]]*[\[{]/
  RUNNER_OPEN = /runner[[:space:]]*'/

  Row = Struct.new(:applies, :path)

  # Every href a READER can follow out of the page, which means <a> only. Not <link>: a
  # stylesheet or a font is an asset, not a citation, and a whole-page match for href pulled in
  # the template's own fonts.googleapis.com tags and failed every real page for it. The tag has
  # to open and carry its href on one line, which is how the template writes them.
  def self.external_links(page)
    page.scan(/<a [^>]*href="[^"]*"/)
        .flat_map { |tag| tag.scan(/href="[^"]*"/) }
        .map { |href| ReviewMap.unescape(href.sub(/\Ahref="/, "").sub(/"\z/, "")) }
        .select { |url| url.match?(%r{\Ahttps?://}) }
        .reject { |url| url.match?(PERMALINK) }
        .sort.uniq
  end

  # The allowlist is the TABLE ROWS, not the file. The file's prose quotes URLs it is warning
  # about — the dead Persistence/ClassMethods anchor is named there precisely so nobody re-adds
  # it — and a whole-file sweep would allowlist every one of those. A URL is legal because a row
  # offers it, never because the file mentions it.
  #
  # Cells split on `·` first, each segment tested for a leading `<series>:`, the way
  # verify-catalogue.sh does. That is what makes the series rule possible: an override is legal
  # for ITS series and no other, and the only way to know which is to keep the two attached.
  def self.catalogue(path)
    rows = []
    File.readlines(path, encoding: "UTF-8").each do |raw|
      line = raw.chomp
      next unless line.start_with?("|")
      next if line.match?(/\A\|[[:space:]]*-/)

      line.split("|", -1).drop(2).each do |cell|
        cell.split("·").each do |segment|
          part = segment
          applies = "*"
          if (m = part.match(/\A[[:space:]]*[0-9]+\.[0-9]+:/))
            applies = m[0].chop.strip
            part = m.post_match
          end
          token = part.match(/`([^`]+)`/)
          rows << Row.new(applies, token[1]) if token
        end
      end
    end
    rows.uniq { |r| [r.applies, r.path] }
  end

  # The page emits PINNED URLs; the catalogue stores unpinned paths, so the version segment
  # comes off before matching. A gem tag is reduced to the {version} placeholder the row
  # actually carries.
  #
  # hexdocs keeps its PACKAGE in the needle and loses only the version segment, because the
  # package is part of the stored path — `ecto/Ecto.Changeset.html#cast/4`. That is what makes a
  # right-module-wrong-package URL fail here instead of passing: the two differ in the needle.
  # The unpinned form is reduced too, so it is still tested against the allowlist; the hexdocs
  # pinning rule is what fails it for being unpinned.
  def self.needle(url)
    url.sub(%r{\Ahttps://guides\.rubyonrails\.org/v[0-9][0-9.]*/}, "")
       .sub(%r{\Ahttps://guides\.rubyonrails\.org/}, "")
       .sub(%r{\Ahttps://api\.rubyonrails\.org/v[0-9][0-9.]*/classes/}, "")
       .sub(%r{\Ahttps://api\.rubyonrails\.org/classes/}, "")
       .sub(%r{\Ahttps://hexdocs\.pm/([^/]+)/[0-9][^/]*/}, "\\1/")
       .sub(%r{\Ahttps://hexdocs\.pm/}, "")
       .sub(%r{/tree/v[0-9][0-9A-Za-z.-]*}, "/tree/v{version}")
  end

  # What separates one block from the next. A doc link belongs with the sentence around it, and
  # these are the boundaries that sentence cannot cross: a list item, a paragraph, a checkpoint,
  # a figure caption. Without the closers a link in one block would borrow the citation in the
  # one above it, which is the rule working backwards.
  BLOCK_BREAK = %r{<li[ >]|</li>|<p[ >]|</p>|<section class="cp|</section>|<figcaption|<div class="item"}

  # A doc link is judged with the block it sits in, because the link and the citation that
  # earned it are often different children of the same sentence. The rule is about the sentence
  # having a stake in this repository, not about which child holds the path — and the break
  # tokens are what stop it working in the other direction: a link with no citation of its own
  # cannot borrow the one in the paragraph that happens to precede it.
  def self.link_blocks(lines)
    blocks = []
    buffer = ""
    lines.each do |line|
      if line.match?(BLOCK_BREAK) && !buffer.empty?
        blocks << buffer
        buffer = ""
      end
      buffer = "#{buffer} #{line}"
    end
    blocks << buffer unless buffer.empty?
    blocks.select { |b| b.include?('class="doc"') }.map { |b| ReviewMap.unescape(b) }
  end

  # Defined anywhere in the repository, as a class or module. Ruby's own file naming is not
  # assumed: a search for the definition is what a reviewer would do.
  def self.defined_in?(check, constant)
    leaf = constant.split("::").last
    _out, found = check.shell("grep", "-rEq",
                              "^[[:space:]]*(class|module)[[:space:]]+([A-Za-z0-9_:]*::)?#{leaf}\\b",
                              check.repo)
    found
  end

  def self.constants_in(lines)
    lines.flat_map { |l| l.scan(CONSTANT) }
         .reject { |c| c.match?(FRAMEWORK) || c.match?(FRAMEWORK_NS) }
         .sort.uniq
  end

  # The first line of a probe body that looks like the probe's own output, or nil.
  #
  # A leading `[` or `{` is output only OUTSIDE a quoted script. `bin/rails runner '` opens one
  # whose continuation lines are Ruby, and a real probe's second line began
  # "[Profile, Community, Event].each { |m| ... }" — a literal being iterated, not a literal
  # being printed. The two are indistinguishable by their first character, so the quote is what
  # tells them apart: track it, and a printed array still fails while Ruby does not. `=>` and
  # the SQL keywords need no such care — neither is legal at the head of a continuation line,
  # so they are caught inside a script too.
  def self.fabricated_line(lines)
    inside = false
    lines.each do |line|
      return line if line.match?(FABRICATED) || line.match?(FABRICATED_SQL)
      return line if !inside && line.match?(FABRICATED_LITERAL)

      # Parity of single quotes, counted only once a runner script has opened.
      inside = !inside if (inside || line.match?(RUNNER_OPEN)) && line.count("'").odd?
    end
    nil
  end

  # Strip tags, decode, drop blank lines — the body of a <pre> as the reviewer would paste it.
  def self.body_of(page, open_tag)
    inside = false
    page.lines.filter_map do |raw|
      line = raw.chomp
      inside = true if line.match?(open_tag)
      next unless inside

      kept = line
      inside = false if line.match?(%r{</pre>})
      text = ReviewMap.unescape(kept.gsub(/<[^>]*>/, ""))
      text unless text.match?(/\A[[:space:]]*\z/)
    end
  end
end

check = ReviewMap::Check.new(ARGV)
check.require_input
page = check.page
# Both catalogues, always — see the header. A page cites from one, and nothing in the markup
# says which.
catalogue_paths = %w[rails-docs.md elixir-docs.md]
                  .map { |name| File.join(ReviewMap::Check::SKILL_DIR, "references", name) }
                  .select { |path| File.readable?(path) }

# ---------------------------------------------------------------- doc links
external = RailsAnchors.external_links(page)
if external.empty?
  check.skip("doc links: none on this input")
elsif catalogue_paths.empty?
  check.bad("doc links: no catalogue readable at references/rails-docs.md or references/elixir-docs.md — nothing can be checked against it")
else
  # Both catalogues parsed into ONE allowlist. A path is legal because some row offers it;
  # which file the row lives in is the run's business, not this check's, and a monorepo page can
  # legitimately cite from both. The per-series override syntax is Rails-only in practice —
  # elixir-docs.md ships none, because hexdocs pins per package rather than per series — so
  # every Elixir row parses as `*` and the series rule below never fires on one.
  rows = catalogue_paths.flat_map { |path| RailsAnchors.catalogue(path) }
                        .uniq { |r| [r.applies, r.path] }
  rails_links = external.select { |u| u.match?(RailsAnchors::RAILS_HOST) }
  pinned, unpinned = rails_links.partition { |u| u.match?(RailsAnchors::PINNED) }
  seen_series = pinned.filter_map { |u| u[RailsAnchors::SERIES, 1] }.sort.uniq

  # Pinning, rule 1: a Rails doc link must carry a version segment. An unpinned one silently
  # means current stable, which is the defect the pinning rule exists for — a 7.1 app handed
  # 8.1 documentation with nothing on the page to notice it with.
  #
  # Skipped rather than passed when the page has no Rails doc link at all: "every link is
  # pinned" over an empty set is a PASS that reads as verification of something nobody checked,
  # which is the same defect as a SKIP that reads as verified, in reverse.
  if rails_links.empty?
    check.skip("pinning: no Rails documentation links on this input")
  else
    if unpinned.empty?
      check.ok("all #{rails_links.size} Rails doc link(s) carry a version segment")
    else
      check.bad("#{unpinned.size} unpinned Rails doc link(s) — an unpinned path silently means current stable: #{unpinned.join(" ")} ")
    end

    # Pinning, rule 2: one app, one series. A page mixing /v7.1/ and /v8.0/ has pinned from
    # something other than this repo's Gemfile.lock, and the reader cannot tell which link
    # describes their app.
    #
    # THIS RULE IS RAILS-ONLY, and generalizing it is how a correct Elixir page starts failing.
    # Rails has one major.minor for the whole framework; an Elixir app pins ecto, phoenix,
    # phoenix_live_view, oban and elixir independently from mix.lock, and hexdocs serves exact
    # versions rather than a series prefix. Several different version segments on one Elixir
    # page is the CORRECT output. Hence rule 1b checks that hexdocs links are pinned at all, and
    # says nothing about whether they agree.
    if seen_series.size > 1
      check.bad("doc links pinned to #{seen_series.size} different Rails series — one app has one version: #{seen_series.join(" ")} ")
    elsif seen_series.size == 1
      check.ok("all doc links pinned to one series (v#{seen_series.first})")
    end
  end

  # Pinning, rule 1b: the hexdocs arm of rule 1. A hexdocs URL with no version segment resolves
  # to the package's newest release, which is the same silent defect an unpinned Rails guide is —
  # an app on phoenix_live_view 0.20 handed 1.x documentation, with nothing on the page to
  # notice it with.
  #
  # Skipped rather than passed when the page carries no hexdocs link, for the same reason rule 1
  # skips: "all pinned" over an empty set reads as verification of something nobody checked.
  hex_links = external.select { |u| u.match?(RailsAnchors::HEXDOCS) }
  if hex_links.empty?
    check.skip("pinning: no hexdocs links on this input")
  else
    hex_unpinned = hex_links.reject { |u| u.match?(RailsAnchors::HEXDOCS_PINNED) }
    if hex_unpinned.empty?
      check.ok("all #{hex_links.size} hexdocs link(s) carry a version segment")
    else
      check.bad("#{hex_unpinned.size} unpinned hexdocs link(s) — an unpinned path silently means the package's newest release: #{hex_unpinned.join(" ")} ")
    end
  end

  # Pinning, rule 3: an unsubstituted placeholder. `tree/v{version}` is the literal the
  # catalogue stores, so it matches its own row perfectly and is invisible to the allowlist
  # test — while being a guaranteed 404.
  placeholder = external.find { |u| u.match?(/\{version\}|%7Bversion%7D/) }
  if external.any? { |u| u.include?("{version}") || u.include?("%7Bversion%7D") }
    check.bad("a doc link still carries the {version} placeholder — the catalogue's path reached the page unsubstituted: #{placeholder}")
  else
    check.ok("no unsubstituted {version} placeholder")
  end

  page_series = seen_series.first
  bad_urls = []
  wrong_series = []
  external.each do |url|
    needle = RailsAnchors.needle(url)
    # Matched as a WHOLE backticked token, never as a substring. A bare fixed-string search on
    # the path passed `guides.rubyonrails.org/v8.0/validations.html` — an HTTP 404 — because
    # `validations.html` is a substring of the catalogued `active_record_validations.html`.
    hits = rows.select { |r| r.path == needle }.map(&:applies)
    if hits.empty?
      # A fragment the catalogue does not carry is still legal if the page it hangs off is
      # catalogued: landing at the top of the right page is an outcome the catalogue explicitly
      # prefers to a guessed anchor.
      base = needle.split("#", 2).first
      next if base != needle && rows.any? { |r| r.path == base }

      bad_urls << url
      next
    end
    # Rule 4: the path has to be catalogued FOR THIS SERIES. A per-series override is the right
    # URL for one series and the wrong page for every other.
    next if hits.include?("*")
    next if page_series.nil? || hits.include?(page_series)

    wrong_series << "#{url}  [catalogued only for series #{hits.join(" ")}— page is pinned at #{page_series}]"
  end

  if bad_urls.empty?
    check.ok("#{external.size} documentation link(s), all from the catalogue")
  else
    check.bad("#{bad_urls.size} documentation link(s) in neither references/rails-docs.md nor references/elixir-docs.md — a URL nobody opened is a 404 the reader finds: #{bad_urls.join(" ")} ")
  end

  if wrong_series.empty?
    check.ok("no doc link uses another series' override path")
  else
    check.bad("#{wrong_series.size} doc link(s) pinned to a series the catalogue does not offer that path for: #{wrong_series.first}")
  end
end

unless external.empty?
  # A doc link is provenance. The claim it decorates still has to cite this repository, so the
  # element carrying the link needs a file:line — its own, not one from elsewhere on the page.
  alone = RailsAnchors.link_blocks(page.lines).count do |block|
    next false if block.include?('class="path"') || block.include?('class="cite"')

    # A bare path:line with no anchor counts too — that is the rung-3 and rung-4 form.
    !block.match?(%r{[A-Za-z0-9_./-]+\.(?:rb|rake|erb|ts|tsx|js|jsx|yml|yaml|sql|json):[0-9]+})
  end
  if alone.zero?
    check.ok("every documentation link sits beside a repository citation")
  else
    check.bad("#{alone} documentation link(s) with no file:line beside them — a link to the Rails guides says nothing about this repository")
  end

  # The page must read complete with every excerpt closed, so a link inside one is a link the
  # reader of the closed page never sees.
  in_excerpt = false
  hidden = page.lines.any? do |raw|
    line = raw.chomp
    in_excerpt = true if line.match?(/<details class="excerpt/)
    found = in_excerpt && line.match?(/class="doc"/)
    in_excerpt = false if line.match?(%r{</details>})
    found
  end
  if hidden
    check.bad("a documentation link is inside a collapsed excerpt — the page has to read complete with every excerpt closed")
  else
    check.ok("no documentation link hidden inside an excerpt")
  end

  # The budget's mechanical edge. At most one per checkpoint is the rule; a page carrying more
  # links than judgments has stopped selecting, and that needs a reader.
  cps = page.count(/<section class="cp/)
  if cps.positive? && external.size > cps
    check.maybe("#{external.size} doc link(s) across #{cps} checkpoint(s) — at most one each, and a page near that ratio has stopped selecting")
  end
end

# ---------------------------------------------------------------- runtime probes
nprobe = page.count(/class="probe"/)
if nprobe.zero?
  check.skip("runtime probes: none on this input")
  check.finish
end

probe_body = RailsAnchors.body_of(page, /<pre class="probe"/)

# 5 · No fabricated output. The skill does not run these, so anything that looks like a result
#     is invented. `=>` is the console's own prompt for a return value; a leading SQL keyword is
#     the other common shape; a leading `[` or `{` is one only outside a quoted runner script,
#     which is what fabricated_line tracks.
fabricated = RailsAnchors.fabricated_line(probe_body)
if fabricated
  check.bad("a probe carries what looks like its own output — the skill never ran it, so a transcript here is fiction: #{fabricated}")
else
  check.ok("#{nprobe} probe(s), none showing output the run did not observe")
end

# 6 · Safety. A reviewer who pastes what the page told them to must not thereby mutate a
#     database. Writes belong in `console --sandbox`; production is never a target.
if probe_body.any? { |l| l.include?("RAILS_ENV=production") }
  check.bad("a probe names RAILS_ENV=production — these are for the reviewer's own checkout")
else
  check.ok("no probe targets production")
end
writes = probe_body.select { |l| l.match?(RailsAnchors::MUTATING) }
if writes.any?
  if probe_body.any? { |l| l.include?("console --sandbox") }
    check.ok("a write-shaped probe is present and a sandboxed console is what runs it")
  else
    check.bad("a probe writes but no 'console --sandbox' is named — bin/rails runner is not sandboxed and the change persists: #{writes.first}")
  end
else
  check.ok("every probe is read-only")
end

# 7 · The identifiers are real. Same rule as "validation steps must exist in this repo", and the
#     same reason searches.rb re-runs its searches: a plausible constant is the failure mode, and
#     it is invisible until someone pastes it.
if check.repo.to_s.empty?
  check.skip("probe identifiers: needs --repo to ask whether the constants exist")
elsif !File.directory?(check.repo)
  check.bad("probe identifiers: --repo is not a directory: #{check.repo}")
else
  consts = RailsAnchors.constants_in(probe_body)
  missing = consts.reject { |c| RailsAnchors.defined_in?(check, c) }
  if consts.empty?
    check.skip("probe identifiers: no project constants named in the probes")
  elsif missing.empty?
    check.ok("all #{consts.size} constant(s) named by a probe exist in the repository")
  else
    check.bad("#{missing.size} constant(s) named by a probe do not exist in this repository — an invented probe fails on first paste: #{missing.join(" ")} ")
  end

  # Scopes and class methods called on a project constant. A probe's whole value is that it
  # names THIS app's scope, so an invented one is the defect this rule exists for — and it is
  # the likeliest fabrication, because a plausible scope name is exactly what a model writes
  # when it has not read far enough.
  #
  # The receiver is filtered before the method name is taken, through the same FW list rule 7
  # uses. The rule is about a scope on one of THIS app's models; a framework constant's methods
  # are not the app's to define, and reading them as such failed a correct probe —
  # `pp Rails.application.routes.routes` was reported as calling an undefined `application`.
  scopes = probe_body.flat_map { |l| l.scan(/\b[A-Z][A-Za-z0-9]*\.[a-z_]+[a-z_0-9]*/) }
                     .reject { |call| call.match?(RailsAnchors::FRAMEWORK_RECEIVER) }
                     .map { |call| call.sub(/\A[^.]*\./, "") }
                     .sort.uniq
                     .reject { |m| RailsAnchors::AR_API.include?(m) }
  if scopes.any?
    # A scope, a class method, or an instance method — a probe may reasonably call any.
    #
    # Plus the enum's generated plural, which has no `def` anywhere: `enum :invite_area`
    # generates `Event.invite_areas`, and reading that map is the version-proof way to ask what
    # values an app actually admits — the probe rails-nextjs.md recommends. Without this the
    # check failed a probe the reference tells the run to write.
    #
    # Both plural forms, because one is not enough and the fixture proved it: trimming a
    # trailing "s" turns invite_areas back into invite_area but statuses into "statuse". Rails
    # adds "es" after s, x, z, ch and sh, and `status` is the enum name a Rails app is
    # likeliest to have.
    missing_scopes = scopes.reject do |sc|
      sing = sc.sub(/s\z/, "")
      sing_es = sc.sub(/es\z/, "")
      _out, found = check.shell("grep", "-rEq",
                                "(scope[[:space:]]+:#{sc}\\b|def[[:space:]]+(self\\.)?#{sc}\\b|" \
                                "enum[[:space:]]+:?#{sc}\\b|enum[[:space:]]+:?#{sing}\\b|" \
                                "enum[[:space:]]+:?#{sing_es}\\b)",
                                check.repo)
      found
    end
    if missing_scopes.empty?
      check.ok("#{scopes.size} scope(s) or method(s) called by a probe are defined in the repository")
    else
      check.bad("#{missing_scopes.size} scope(s) or method(s) a probe calls are not defined in this repository — a plausible scope name is the likeliest thing an invented probe gets wrong: #{missing_scopes.join(" ")} ")
    end
  end

  # Attribute and association names a probe reflects on, checked the same way.
  syms = probe_body.flat_map { |l| l.scan(/\.(?:reflect_on_association|validators_on)\(:[a-z_]+\)/) }
                   .map { |call| call.sub(/.*\(:/, "").sub(/\)/, "") }
                   .sort.uniq
  if syms.any?
    missing_syms = syms.reject do |sym|
      _out, found = check.shell("grep", "-rEq", "([:\"']#{sym}\\b|\\b#{sym}:)", check.repo)
      found
    end
    if missing_syms.empty?
      check.ok("#{syms.size} attribute/association name(s) in probes appear in the repository")
    else
      check.bad("#{missing_syms.size} name(s) a probe reflects on are absent from the repository: #{missing_syms.join(" ")} ")
    end
  end
end

check.finish
