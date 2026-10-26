# frozen_string_literal: true

# The deterministic tests for review-map's scripts, as a library: run.rb runs every section of it
# against this checkout, and self-test.rb runs one section of it against a copy it has just broken.
#
# Whether a Review Map is any good is a model run and cannot be asserted on. The scripts underneath
# it are ordinary software with right answers, and this is where that half is held to account:
# page-skeleton.sh — that what it emits is the template's own bytes and not a copy, and that it
# refuses to overwrite a page somebody is already reading — plus diff-render.sh, whose verdict
# decides which URL form a citation gets, carry-plan.sh, whose mistakes are silent, excerpt.sh,
# page-lint.sh and usage.sh.
#
# It is NOT under evals/checks/ for the reason verify-catalogue.sh is not: check.rb dispatches
# offline rules over a page, and this takes no page — it is a relation between files in the
# repository. Unlike that one it needs no network, so it runs in CI on every push.
#
# ONLY THE TEST CODE IS RUBY. The scripts under test run in users' repositories and on CI runners,
# so they stay shell and are called here as subprocesses, exactly as a run calls them.
#
# THE ORACLE PROBLEM, and how this avoids it. Extracting the head on the markers and comparing it
# against the script's own extraction on the markers would test the script against itself and pass
# for any consistent pair of bugs. So the assertion here is a PARTITION: strip the four marker lines
# and the maintainer preamble from the template, put the theme files where the fifth marker was, and
# what remains must be exactly head + markup + tail, concatenated, byte for byte. Move a marker and it
# fails. Inline a line of CSS into the script and it fails. Edit the CSS in the template and it
# passes, which is correct — that is the one source of truth doing its job.
#
# Each section is a method that builds what it needs, so it can run alone. That is what lets
# self-test.rb run only the section a break can reach instead of the whole suite once per break.
#
# No network, no model, and nothing that depends on the machine: no assertion reads the date, and
# where usage.sh compares two files' ages the fixture sets the ages rather than sleeping for them.
#
# EVERY RECORDED SEARCH IN THIS SUITE IS A grep, AND NONE MAY BE AN rg. GitHub's runners have no
# ripgrep, so a fixture recording an rg search is a row asserting that ripgrep is installed.

require "fileutils"
require "open3"

# The template and the scripts' messages carry em dashes and arrows, and a runner's locale is often
# C. Read every byte as UTF-8 whatever the machine says, or the answer depends on its locale.
Encoding.default_external = Encoding::UTF_8

class ReviewMapSuite
  SECTIONS = {
    skeleton:    "page-skeleton.sh and the template",
    diff_render: "diff-render.sh",
    carry_plan:  "carry-plan.sh",
    excerpt:     "excerpt.sh",
    page_lint:   "page-lint.sh",
    usage:       "usage.sh"
  }.freeze

  # A subprocess that outlives this is waiting on something, and a suite that hangs is worse than
  # one that fails: the failure is reported, the hang is waited on.
  TIMEOUT = 120

  # A theme set in the caller's environment would change every page this file emits, and a Codex
  # thread id would change what usage.sh reads. Unset for every subprocess unless a row sets it.
  SCRUB = %w[ACCOUNTABLE_REVIEW_THEME CODEX_THREAD_ID CODEX_HOME].freeze

  Result = Struct.new(:label, :ok, :detail)
  Run = Struct.new(:out, :err, :code)

  attr_reader :results

  # skill is the skills/review-map directory to test: this checkout's, or self-test.rb's broken copy.
  def initialize(skill, tmp, out: $stdout)
    @skill = skill
    @tmp = tmp
    @out = out
    @results = []
    @skeleton    = File.join(skill, "scripts/page-skeleton.sh")
    @template    = File.join(skill, "references/page-template.html")
    @themes      = File.join(skill, "references/themes")
    @diff_render = File.join(skill, "scripts/diff-render.sh")
    @carry_plan  = File.join(skill, "scripts/carry-plan.sh")
    @excerpt     = File.join(skill, "scripts/excerpt.sh")
    @page_lint   = File.join(skill, "scripts/page-lint.sh")
    @usage       = File.join(skill, "scripts/usage.sh")
    @golden      = File.join(skill, "evals/golden")
  end

  def run_sections(names = SECTIONS.keys)
    names.each do |name|
      raise ArgumentError, "unknown section: #{name}" unless SECTIONS.key?(name)
      @out.puts "", "== #{SECTIONS[name]} =="
      begin
        send(:"section_#{name}")
      rescue StandardError => e
        # A section that dies part-way has not passed what it never reached. Reported as a failure of
        # its own, so self-test.rb can tell it from the assertion a break was meant to turn red.
        record("the #{name} section ran to the end", false, "#{e.class}: #{e.message}")
      end
    end
    self
  end

  def failures = @results.reject(&:ok)

  # ------------------------------------------------------------------ assertions
  #
  # One line per expectation, PASS or FAIL, in the same idiom as evals/checks — a test that prints
  # nothing when it passes is a test nobody can tell apart from one that never ran. The label is the
  # assertion's name: self-test.rb names the one each break must turn red.

  def record(label, ok, detail = nil)
    @results << Result.new(label, ok, detail)
    @out.puts(ok ? "PASS  #{label}" : "FAIL  #{label}#{detail ? " (#{detail})" : ""}")
  end

  def check(cond, label, detail = nil) = record(label, cond ? true : false, cond ? nil : detail)
  def assert_eq(got, want, label) = check(got == want, label, "got '#{got}', wanted '#{want}'")

  # ------------------------------------------------------------------ plumbing

  def sh(*cmd, env: {}, chdir: @tmp)
    env = SCRUB.to_h { |k| [k, nil] }.merge(env)
    Open3.popen3(env, *cmd.map(&:to_s), chdir: chdir, pgroup: true) do |stdin, stdout, stderr, wait|
      # stdin is closed: the code under the self-test is deliberately broken, and broken code reads
      # stdin. A `sed` left without its input file blocks forever on a terminal and returns at once
      # on EOF, and only the second of those is a failure anyone gets to read.
      stdin.close
      o = Thread.new { stdout.read.force_encoding(Encoding::UTF_8) }
      e = Thread.new { stderr.read.force_encoding(Encoding::UTF_8) }
      unless wait.join(TIMEOUT)
        begin
          Process.kill("KILL", -wait.pid)
        rescue Errno::ESRCH
          nil
        end
        wait.join
      end
      Run.new(o.value, e.value, wait.value.exitstatus || 124)
    end
  end

  def git(dir, *args) = sh("git", "-C", dir, *args)

  def new_repo(dir)
    FileUtils.mkdir_p(dir)
    git(dir, "init", "-q", ".")
    git(dir, "config", "user.email", "test@example.com")
    git(dir, "config", "user.name", "test")
    dir
  end

  def commit_all(dir, message)
    git(dir, "add", "-A")
    git(dir, "commit", "-qm", message)
  end

  def rev(dir, ref = "HEAD") = git(dir, "rev-parse", ref).out.strip

  def path(*parts) = File.join(@tmp, *parts)
  def read(file) = File.exist?(file) ? File.read(file) : ""
  def bytes(file) = File.exist?(file) ? File.binread(file) : ""
  def write(file, text) = FileUtils.mkdir_p(File.dirname(file)).then { File.write(file, text) }
  def append(file, text) = File.open(file, "a") { |f| f << text }
  def lines_of(from, to = nil) = (to ? (from..to) : (1..from)).map { |i| "#{i}\n" }.join

  # A needle is a fixed string unless it is a Regexp — the shell suite's `grep -F` and `grep`.
  def hit(line, needle) = needle.is_a?(Regexp) ? line.match?(needle) : line.include?(needle)

  # `grep -c`: the number of LINES that hold the needle, not the number of times it occurs.
  def count(text, needle) = text.lines.count { |l| hit(l, needle) }

  # `awk '/open/ { f = 1 } f { print } /close/ { f = 0 }'` — opens on a match, keeps the closing
  # line, and opens again on the next match.
  def between(text, open, close)
    f = false
    text.lines.select do |l|
      f = true if hit(l, open)
      keep = f
      f = false if hit(l, close)
      keep
    end.join
  end

  # `awk '/from/,/to/'` — an awk range, whose end is tested on its own opening line too.
  def awk_range(text, from, to)
    inside = false
    text.lines.select do |l|
      if inside
        inside = false if hit(l, to)
        true
      elsif hit(l, from)
        inside = !hit(l, to)
        true
      else
        false
      end
    end.join
  end

  # `awk '/from/ { f = 1 } f { print } f && /to/ { exit }'` — the first block only, and then stop.
  def first_block(text, from, to)
    out = []
    f = false
    text.lines.each do |l|
      f = true if hit(l, from)
      next unless f
      out << l
      break if hit(l, to)
    end
    out.join
  end

  # ------------------------------------------------------------------ the skeleton

  def skeleton(*args, env: {}) = sh(@skeleton, "--template", @template, "--themes", @themes, *args, env: env)

  # Every theme goes onto the page, in the menu's order, with the ones not chosen switched off by
  # media="not all" on each element that names them. Built here by substitution, not with the
  # script's awk, so a consistent pair of bugs cannot agree with itself.
  def themes_for(chosen)
    %w[daylight workshop field-notes].map do |n|
      t = File.read(File.join(@themes, "#{n}.html"))
      n == chosen ? t : t.gsub(%(data-style="#{n}")) { |m| %(#{m} media="not all") }
    end.join
  end

  # The template with the themes put where the theme marker was — sed's `r` followed by `d`.
  def splice_themes(lines, chosen)
    lines.flat_map { |l| l.include?("SKELETON:THEME") ? [themes_for(chosen)] : [l] }
  end

  # The template after its HEAD:START line: `sed '1,/SKELETON:HEAD:START/d'`.
  def after_head_start(text)
    lines = text.lines
    i = lines.drop(1).index { |l| l.include?("SKELETON:HEAD:START") }
    i ? lines.drop(i + 2) : []
  end

  def first_diff(a, b)
    i = (0...[a.bytesize, b.bytesize].min).find { |k| a.getbyte(k) != b.getbyte(k) }
    i ? "differ at byte #{i + 1}" : "one is a prefix of the other (#{a.bytesize} vs #{b.bytesize} bytes)"
  end

  # Each declaration in a theme file, tagged with the selector it sits under: every COLOUR token it
  # declares on bare :root must be declared again in the media dark block and in the explicit dark
  # one. Counting a name three times is not that — a theme that redeclared a token on :root three
  # times would pass. Type stacks and radii are exempt: a typeface needs no dark value.
  def theme_states(text)
    ctx = nil
    seen = {}
    names = []
    text.tr("{};", "\n\n\n").lines.map(&:chomp).each do |l|
      if l.include?("prefers-color-scheme: dark") then ctx = "media"
      elsif l.match?(/\A[[:space:]]*:root\[data-theme="dark"\][[:space:]]*\z/) then ctx = "dark"
      elsif l.match?(/\A[[:space:]]*:root[[:space:]]*\z/) then ctx = "light"
      elsif l.match?(/\A[[:space:]]*:root:not\(\[data-theme="light"\]\)[[:space:]]*\z/) then next
      elsif l.match?(/\A[[:space:]]*--[a-z0-9-]+:/)
        next unless l.match?(/#[0-9a-fA-F]|oklch\(|rgb/)
        n = l.sub(/:.*/, "").sub(/\A[[:space:]]*/, "")
        seen[[n, ctx]] = true
        names << n unless names.include?(n)
      end
    end
    missing = names.select { |n| seen[[n, "light"]] && !(seen[[n, "media"]] && seen[[n, "dark"]]) }
    never = names.reject { |n| seen[[n, "light"]] }.map { |n| "#{n} (never on bare :root)" }
    (missing + never).join(" ")
  end

  def section_skeleton
    @out.puts "template  #{@template}", ""
    template = File.read(@template)
    page_file = path("page.html")

    # ---------------------------------------------------------------- the partition
    # The title is passed as the placeholder itself, so the emitted head comes back with the
    # template's own bytes on that line and the comparison needs no un-substitution step.
    skeleton("--repo", @tmp, "--out", page_file, "--title", "{{PR_TITLE_OR_BRANCH}}")
    markup = skeleton("--repo", @tmp, "--markup").out
    page = read(page_file)

    # head and tail, taken off the emitted page by splitting on the body placeholder — one
    # operation, and not the one the script used to build it.
    plines = page.lines
    body = plines.index { |l| l.include?("SKELETON:BODY") } || plines.size
    head = plines[0...body].join
    tail = (plines[(body + 1)..] || []).join

    # No --theme and no config file in the work directory, so what was emitted is the default —
    # which is why this names daylight rather than asking.
    expected = splice_themes(after_head_start(template), "daylight").join
    expected = expected.lines.reject { |l| l.include?("SKELETON:") }.join
    actual = head + markup + tail

    check actual == expected, "head + markup + tail is the template, byte for byte", first_diff(actual, expected)

    # Stated separately because the prefix is the assertion that fails the moment someone inlines
    # CSS into the script, and a reader should see that named.
    check expected.byteslice(0, head.bytesize) == head, "the emitted head is an exact byte prefix of the template"
    check expected.bytesize >= tail.bytesize && expected.byteslice(expected.bytesize - tail.bytesize, tail.bytesize) == tail,
          "the emitted tail is an exact byte suffix of the template"

    # ---------------------------------------------------------------- the halves are the right halves
    assert_eq count(markup, "<style"),  0, "the markup half carries no style block for a run to copy"
    assert_eq count(markup, "<script"), 0, "the markup half carries no script for a run to copy"
    assert_eq count(markup, "<svg"),    0, "the markup half carries no svg — this page has no drawings"
    assert_eq count(markup, "hljs-"),   0, "the markup half carries no tint class — the tint is applied at read time"

    # ---------------------------------------------------------------- the page has one shape
    # There is one page, and no flag names another one. So the markup half is the whole page, and
    # what these rows assert is that every section a run has to write is assembled in front of it.
    %w[changed context attention start impact].each do |sec|
      assert_eq count(markup, /^ *<section id="#{sec}"/), 1, %(the markup half carries <section id="#{sec}">)
    end
    assert_eq count(markup, '<details class="evidence">'), 1, "the evidence foot is assembled"
    assert_eq count(markup, 'class="gt gt-paths"'),        1, "the foot carries the data-path inventory"
    check markup.include?("data-path="), "the inventory cells carry data-path, which is the whole interface to the coverage gate"
    assert_eq count(markup, /class="eyebrow"[^>]*>Affected, not changed/), 2, "the affected label is verbatim, beside the panel and in the foot"

    # THE CHECKPOINT, ASSEMBLED. Five written and one pending stub: a run copies the composition,
    # and a composition described but never shown assembled does not survive a weaker reader. A and
    # B are the composition, one with every optional part and one without; C, D and E exist to show
    # one topology figure each. The pending one is counted too, because a half-written section 03
    # has to be distinguishable from a flattened one.
    assert_eq count(markup, 'class="cp"'),     6, "five checkpoints assembled whole and one pending stub"
    assert_eq count(markup, 'id="cp-a"'),      1, "the first checkpoint is anchored for the rail and the reading path"
    assert_eq count(markup, 'class="lookat"'), 5, "each written checkpoint carries its own where-to-look list"
    assert_eq count(markup, 'class="open"'),   6, "every checkpoint, the pending stub included, ends in its review question"

    # THE CHAIN, AND THE RULE THAT KEEPS IT OUT OF SECTION 05. A chain inside a checkpoint shows
    # mechanism inside the change, so it holds .ip-step and never .ip-aff: a hop into unchanged code
    # is an impact path and belongs in the panel, drawn once. This is the assertion that fails when
    # the two figures blur into each other.
    chain = between(markup, '<figure class="chain">', "</figure>")
    assert_eq count(markup, '<figure class="chain">'),  1, "one chain is assembled inside a checkpoint"
    assert_eq count(markup, '<figure class="impact">'), 1, "one impact panel is assembled, in section 05"
    check count(markup, 'class="ip-n ip-step"') >= 1, "the chain uses .ip-step, the neutral hop that exists only there"
    assert_eq count(chain, "ip-aff"), 0, "no .ip-aff node inside the chain — that hop is an impact path"

    # THE TOPOLOGY FIGURES — the three shapes a chain cannot draw, one assembled each. A converge's
    # paths are siblings, not a sequence, so it holds NO .ip-rel: the impact panel's lane crossing
    # hangs off `.ip-chg + .ip-aff > .ip-rel`, and a converge alternates exactly those kinds. Its
    # target is an invariant, a property rather than a file, so it carries no locator. A lifecycle
    # is states, not code, so it holds no .ip-aff.
    fig = ->(kind) { between(markup, %(<figure class="#{kind}">), "</figure>") }
    %w[converge lifecycle structure].each do |kind|
      assert_eq count(markup, %(<figure class="#{kind}">)), 1, "one #{kind} figure is assembled inside a checkpoint"
      assert_eq count(fig.(kind), "data-path"), 0, "no data-path inside the #{kind} figure"
    end
    converge = fig.("converge")
    assert_eq count(converge, "ip-rel"), 0, "no .ip-rel inside a converge — its paths are siblings, and a connector would fire the panel's elbow"
    check count(converge, '<li class="ip-n') >= 2, "a converge draws at least two paths — one is a chain"
    assert_eq converge.lines.count { |l| l.include?('class="cv-target"') && l.include?("ip-loc") }, 0,
              "no locator on a converge's target — an invariant is not in a file"
    assert_eq count(fig.("lifecycle"), "ip-aff"), 0, "no .ip-aff inside a lifecycle — a state is not a file"

    # THE PARAGRAPH AND THE LOCATOR, which are the two things a node and a card carry that a diagram
    # on its own does not. One p.ip-why per card and none in the chain: a checkpoint's own sentences
    # already are that paragraph. The locator is in both figures, and NEVER on an outcome — a
    # behaviour is not in a file, and an address on that node is the locator defect that reads as
    # more thorough than the correct markup.
    assert_eq count(markup, '<p class="ip-why">'), 2, "each impact card opens with its own paragraph"
    assert_eq count(chain, "ip-why"), 0, "no p.ip-why inside a checkpoint chain — the checkpoint's own sentences are that"
    check count(markup, 'class="path ip-loc"') >= 6, "nodes carry their locator in both figure vocabularies"
    assert_eq markup.lines.count { |l| l.include?('<li class="ip-n ip-out"') && l.include?("ip-loc") }, 0,
              "no locator on an .ip-out node — a behaviour is not in a file"

    # data-path IS RESERVED TO THE INVENTORY. coverage-gate.sh greps it page-wide and compares the
    # result to git diff --name-only as whole strings, so a locator carrying one would register as a
    # surplus path and fail the page's one mechanical gate — most reliably when quoting unchanged
    # code, which is the page's best content.
    panel = between(markup, '<figure class="impact">', "</figure>")
    assert_eq count(panel, "data-path"), 0, "no data-path inside the impact panel — that attribute belongs to the inventory alone"

    # THE PRIMER CALLOUT, the only component on this page a flag admits and therefore the only one
    # whose assembled example has to say what it is gated on. It carries no artwork: this page has
    # no drawings, and a trademark line disclaims a mark on display. Both are asserted at zero,
    # because "the primer is back" is exactly the edit that would bring the svg back with it.
    assert_eq count(markup, '<aside class="primer">'), 1, "one primer callout is assembled"
    assert_eq count(markup, "pr-mark"), 0, "the primer carries no logotype — this page has no drawings"
    assert_eq count(markup, "pr-tm"),   0, "and no trademark line, because there is no mark to disclaim"
    assert_eq count(markup, "primer--lib"), 0, "and no branded/unbranded variant split, which only the mark needed"

    # ITS HEADER NAMES THE STACK, NOT THE COMPONENT. The words a reader new to the stack needs are
    # what it is going to teach them. The separator is asserted at zero the way pr-mark is: a header
    # that grows a second element back is the old shape returning one span at a time.
    assert_eq count(markup, 'class="pr-title"'), 1, "the primer header is one title naming the stack"
    assert_eq count(markup, "Understanding Ruby on Rails"), 1, "and it says what the block teaches, in words"
    assert_eq count(markup, "pr-sep"), 0, "no separator survives — there is nothing left to divide"

    # A RUST PRIMER IS THE SAME COMPONENT IN A DIFFERENT FRAME, and the frame is one class. The rule
    # that holds it is that .pr-rust re-points every --primer-* slot and declares nothing else: a
    # slot it misses stays Rails red inside a graphite frame, which renders, and reads as a mistake
    # nobody made on purpose. The class is in the head range, so a run never types it as a colour.
    assert_eq count(head, ".primer.pr-rust {"), 1, "the Rust frame is a variant of the one primer, in the skeleton"
    rust = first_block(head, /^\.primer\.pr-rust \{/, /^\}/)
    assert_eq rust.scan(/var\(--primer-rust-[a-z0-9-]*\)/).uniq.size, 6, "and it re-points all six primer slots at the graphite ramp"

    # A primer is gated on its doc link and earned by a repo citation, and BOTH live inside the
    # aside: rails-anchors.rb judges it as one block. The link is pinned with the placeholder, never
    # a literal series — a template carrying one app's version teaches it to every other.
    primer = between(markup, '<aside class="primer">', "</aside>")
    assert_eq count(primer, 'class="doc"'), 1, "the primer carries exactly one documentation link"
    assert_eq count(primer, "v{{RAILS_SERIES}}"), 1, "and it is pinned with the placeholder, not a literal series"
    assert_eq count(primer, 'class="path"'), 1, "the primer cites the line in this repository that earned it"
    assert_eq count(primer, 'class="probe"'), 0, "no probe inside a primer — the two anchors are adjacent, never nested"

    # pre.demo MAY show a result line, and pre.probe may never. The whole difference is the receiver,
    # so a demo outside a primer would be a general-purpose hole for output nobody observed. Counting
    # both totals is what makes "only inside a primer" an assertion rather than a sentence.
    assert_eq count(primer, '<pre class="demo">'), 1, "the primer quotes the manual in one pre.demo"
    assert_eq count(markup, '<pre class="demo">'), 1, "and no demo sits anywhere else in the markup"

    # AND IT IS INSIDE A CHECKPOINT, before that checkpoint's ul.lookat. A primer in section 05 or in
    # the evidence foot is a framework lesson with no judgment attached to it; one below the lookat
    # list is a lesson arriving after the reader has already been sent to the code.
    cp_region = first_block(markup, '<section class="cp" id="cp-a">', '<ul class="lookat">')
    assert_eq count(cp_region, 'class="primer"'), 1, "the primer sits inside a checkpoint and above its Look at list"

    # AND THE COMPONENTS THE AGENDA PUT DOWN STAY DOWN. Each of these was a required part of the page
    # this one replaced, so each is a thing a run with the old shape in mind would reach for.
    ['class="mech"', 'class="rows"', 'class="pipe"', 'class="checkpoint"',
     'class="decisions"', 'class="inflow"', 'class="usecases"', "gt-ledger", "coverage-foot"].each do |gone|
      assert_eq count(markup, gone), 0, "the markup half has no #{gone}"
    end

    # The rail is assembled, never derived. Five numbered entries and one sub-entry per checkpoint.
    assert_eq count(markup, 'class="rail-links"'), 1, "exactly one rail"
    assert_eq count(markup, "data-rail="), 11, "the rail is five entries and six checkpoint sub-entries"
    assert_eq count(markup, "05</span>"), 1, "the rail numbers up to 05"
    assert_eq count(markup, "06</span>"), 0, "and stops there — the evidence foot has no number"

    # CONTEXT — section 02, the repository concepts the checkpoints rely on. It sits BEFORE the
    # agenda, because a judgment about a piece the reader cannot name is a sentence they can read and
    # not follow. Every entry ends in a pointer at the checkpoints that use it, which is the earning
    # test made visible. It is prose plus at most ONE figure, the shift. No tier either: an entry
    # asserts nothing about the change.
    ctx = first_block(markup, /^ *<section id="context">/, %r{^ *</section>})
    assert_eq count(markup, '<dl class="ctx">'), 1, "one Context list is assembled"
    # --context collapsed wraps that list in a details.ctx-fold the run types; its CSS is emitted,
    # like every other rule, so a collapsed page needs nothing from the run but the element.
    assert_eq count(head, /^details\.ctx-fold \{/), 1, "the collapsed Context fold is styled in the emitted head"
    mlines = markup.lines
    ctx_line = mlines.index { |l| l.match?(/^ *<section id="context">/) }
    att_line = mlines.index { |l| l.match?(/^ *<section id="attention"/) }
    check ctx_line && att_line && ctx_line < att_line, "Context comes before the agenda"
    used = %(class="ctx-used">Used by <a href="#cp-)
    assert_eq count(ctx, "<dd>"), ctx.lines.grep_v(/<figcaption>/).count { |l| l.include?(used) },
              "every Context entry points at a checkpoint that uses it"
    check count(ctx, "<dd>") >= 1, "the Context list carries at least one entry"
    # THE SHIFT — Context's one figure, the request sequence before and after. Two columns, the one
    # moved state filled in each, and no .ip-aff, for the lifecycle's reason.
    assert_eq count(ctx, "<figure"), 1, "Context holds one figure at most"
    assert_eq count(ctx, '<figure class="lifecycle lc-shift">'), 1, "Context's one figure is the shift"
    assert_eq count(ctx, '<div class="lc-row">'), 2, "the shift draws a Before and an After column"
    assert_eq count(ctx, 'class="lc-s lc-moved"'), 2, "the moved state is marked in both columns"
    assert_eq count(ctx, "ip-aff"), 0, "no .ip-aff inside the shift — a state is not a file"
    assert_eq count(ctx, "data-path"), 0, "no data-path inside Context"
    assert_eq ctx.lines.count { |l| l.include?("<figcaption>") && l.include?(used) }, 1,
              "the shift's caption points at the checkpoints that earned it"
    assert_eq count(ctx, 'class="tier'), 0, "no evidence tier inside Context — an entry asserts nothing about the change"
    assert_eq count(ctx, 'class="primer'), 0, "no primer inside Context — the framework is --mentor's, the repository is Context's"

    # AND THE ENTRY'S HANGING INDENT STOPS AT THE ENTRY. text-indent inherits and an inline-flex box
    # lays out its own line, so .rail-links a's -24px reaches inside the pending chip and pulls the
    # word left of its own border. Read out of the rule itself: a reset somewhere in the head is not
    # the same as THIS rule carrying one.
    assert_eq count(awk_range(head, /^\.pending \{/, /^}/), "text-indent: 0"), 1,
              "the pending chip resets the rail entry's hanging indent"

    # AND A READING-PATH STOP SPANS ITS EXCERPT. .begin li is a three-column grid, so a details with
    # no span auto-places into the 26px number column — where .ex-loc's overflow-wrap: anywhere
    # renders the path one character per line. Both halves are asserted: the rule has to be in the
    # emitted head AND the composition has to be shown assembled.
    begin_rule = awk_range(head, /^\.begin li > \.excerpt \{/, /}/)
    assert_eq count(begin_rule, "grid-column: 2 / -1"), 1, "a stop's excerpt is spanned out of the 26px number column"
    assert_eq count(begin_rule, "min-width: 0"), 1, "and shrinks below its pre's width, so the quotation scrolls instead of the page"

    # THE SEARCH ROW'S HANGING INDENT, which is .pending's defect in another component: a rule about
    # a row's FIRST child written as a descendant rule. The -16px then reaches a code inside the
    # clause and pulls it over the words before it.
    assert_eq count(awk_range(head, /^\.searched \.sr-list > li > code:first-child \{/, /}/), "margin-left: -16px"), 1,
              "only a search row's leading command hangs into the indent"
    assert_eq count(awk_range(head, /^\.searched \.sr-list code \{/, /}/), "margin-left"), 0,
              "and the rule that styles every code in a row does not pull any of them left"

    # THE INVENTORY'S ODD LAST CELL. .gt paints its gaps by showing --rule through a 1px grid gap,
    # which needs every row full; an odd number of paths leaves the container's own rule colour
    # rendering as a filled slab where the missing cell would be.
    assert_eq count(awk_range(head, /^\.gt-paths > \.c:last-child:nth-child\(odd\) \{/, /}/), "grid-column: 1 / -1"), 1,
              "an odd final inventory cell spans its row instead of leaving a rule-coloured slab"

    # AND THE ASSEMBLED FOOT HAS TO EXERCISE BOTH. Counted by data-path: the attribute is RESERVED
    # to inventory cells, so it selects exactly those. The masthead's .c cells carry none.
    check count(markup, '<div class="c" data-path=').odd?, "the assembled inventory has an odd number of cells, so the odd-cell rule is exercised"
    assert_eq count(markup, /class="sr-r">[^<]*<code>/), 1, "a search row's clause carries an inline code, so the indent's scope is exercised"
    begin_list = between(markup, '<ol class="begin">', "</ol>")
    assert_eq count(begin_list, 'details class="excerpt excerpt--source"'), 1, "a reading-path stop is assembled carrying its excerpt"

    # A LOOK AT ENTRY WITH AN EXCERPT CITES ONCE AND SAYS ITS CLAUSE ONCE. The excerpt's summary is
    # the citation — its .ex-loc is the link — so an entry that also keeps its own a.path shows one
    # path twice, and a summary why under the entry's clause says one thing twice. Per entry: the two
    # zeros are what the self-test breaks, and the first count is what proves the walk saw an excerpt.
    n, np, nw = lookat_walk(markup)
    assert_eq n,  2, "two Look at entries are assembled carrying an excerpt"
    assert_eq np, 0, "and neither keeps an a.path beside the excerpt's linked summary"
    assert_eq nw, 0, "and neither excerpt repeats the entry's clause as a summary why"
    assert_eq count(markup, 'class="ex-src"'), 0, "no excerpt carries a second, body-foot citation under its code"

    # ---------------------------------------------------------------- markers
    %w[SKELETON:HEAD:START SKELETON:HEAD:END SKELETON:TAIL:START SKELETON:TAIL:END SKELETON:THEME].each do |m|
      assert_eq count(template, m), 1, "template has exactly one #{m}"
    end
    assert_eq count(markup, "SKELETON:"), 0, "no marker survives into the markup half"
    assert_eq count(head, "SKELETON:"), 0, "no marker survives into the emitted head"
    assert_eq count(tail, "SKELETON:"), 0, "no marker survives into the emitted tail"
    assert_eq count(page, "SKELETON:BODY"), 1, "the emitted page carries one body placeholder for the run to replace"

    # ---------------------------------------------------------------- every colour is in the skeleton
    # Counted by name, the way page-invariants.rb §6 and excerpts.rb count them: the three theme
    # blocks EXISTING is not the same as a colour being declared in all three. The template's own
    # lines are added to the expected count: .primer.pr-rust re-points --primer-ink at the Rust ramp,
    # a var() rather than a colour, and it lives in the head range by design.
    theme_files = Dir[File.join(@themes, "*.html")].sort
    ["--syn-key:", "--ex-add:", "--primer-ink:", "--primer-rust-ink:"].each do |tok|
      want = count(template, tok) + theme_files.sum { |th| count(File.read(th), tok) }
      assert_eq count(head, tok), want, "every theme's #{tok} declarations are in the skeleton"
    end
    ntheme = theme_files.size
    assert_eq count(head, '<style data-style="'), ntheme, "every theme's style block is on the page"
    assert_eq count(head, '" media="not all" data-style-label='), ntheme - 1, "and all but one arrive switched off"
    assert_eq count(markup, "--syn-key:"), 0, "no colour is left in the half a model reads"
    assert_eq count(template, "--syn-key:"), 0, "the template declares no token of its own — every one comes from a theme"

    # ---------------------------------------------------------------- the appearance menu
    # A reader's control, and none of it is a run's to type: its CSS is in the head range, its markup
    # is built by the tail script, and the half a model reads carries no trace of either.
    assert_eq count(head, ".rc-pop { position: absolute"), 1, "the menu's CSS is in the skeleton"
    assert_eq count(markup, "rc-"), 0, "the markup half carries none of the menu for a run to copy"
    assert_eq count(markup, "data-style"), 0, "nor any theme switch"
    assert_eq count(tail, "line.appendChild(rc);"), 1, "the tail script builds the menu into the masthead"
    assert_eq count(tail, "save('review-style', name)"), 1, "a reader's theme is remembered"
    assert_eq count(tail, "save('review-theme', m[0])"), 1, "and their light or dark"
    assert_eq count(head, "get('review-style')"), 1, "the head applies a saved theme before first paint"
    # Storage throws in a private window or with site data blocked, and then the page must still be
    # the repository's choice rather than a script error that stops the tint and the rail with it.
    assert_eq count(page, /localStorage\./), count(page, /try \{ [a-z ]*localStorage\./), "every storage call is inside a try"

    # ---------------------------------------------------------------- every theme, every state
    # The partition above proves the default. These prove the other two reach the page the same way,
    # and that each theme file keeps the theme rule on its own.
    theme_files.each do |th|
      name = File.basename(th, ".html")
      text = File.read(th)
      out = path("th.html")
      FileUtils.rm_f(out)
      skeleton("--repo", @tmp, "--theme", name, "--out", out, "--title", "t")
      tlines = read(out).lines
      th_head = tlines.take_while { |l| !l.include?("SKELETON:BODY") }.join
      region = after_head_start(template)
      region = region.take_while { |l| !l.include?("SKELETON:HEAD:END") }
      th_expected = splice_themes(region, name).join.lines.map { |l| l.sub("{{PR_TITLE_OR_BRANCH}}", "t") }.join
      check th_head == th_expected, "theme #{name}: the emitted head carries every theme, with #{name} the one switched on",
            first_diff(th_head, th_expected)
      assert_eq count(text, %(data-style="#{name}")), count(text, '<link rel="stylesheet"') + count(text, "<style"),
                "theme #{name} names itself on every link and style element, so the menu can switch all of it"
      assert_eq count(text, "SKELETON:"), 0, "theme #{name} carries no marker of its own"
      assert_eq theme_states(text), "", "theme #{name} declares every colour on bare :root and in both dark blocks"
      assert_eq count(text, 'href="https://fonts.googleapis.com/'), count(text, '<link rel="stylesheet"'),
                "theme #{name} loads its stylesheets from Google Fonts only"
      assert_eq count(text, "<script"), 0, "theme #{name} carries no script — the page has one, in the tail"
    end

    # ---------------------------------------------------------------- which theme
    # The repository decides, through .accountable-review.yml; the CI adapter can say so from a
    # config file elsewhere; --theme beats both; a name with no file behind it is refused, never
    # defaulted.
    cfg = path("cfg")
    cfg_file = File.join(cfg, ".accountable-review.yml")
    c = path("c.html")
    write(cfg_file, "review_map:\n  effort: low\n  delivery:\n    provider: github-artifact\n  theme: workshop   # the look\n")
    FileUtils.rm_f(c)
    skeleton("--repo", cfg, "--out", c, "--title", "t")
    assert_eq count(read(c), '<style data-style="workshop" data-style-label'), 1, "review_map.theme in the repository's config picks the theme"
    FileUtils.rm_f(c)
    skeleton("--repo", cfg, "--out", c, "--title", "t", env: { "ACCOUNTABLE_REVIEW_THEME" => "field-notes" })
    assert_eq count(read(c), '<style data-style="field-notes" data-style-label'), 1, "ACCOUNTABLE_REVIEW_THEME beats the repository's config"
    FileUtils.rm_f(c)
    skeleton("--repo", cfg, "--theme", "daylight", "--out", c, "--title", "t", env: { "ACCOUNTABLE_REVIEW_THEME" => "field-notes" })
    assert_eq count(read(c), '<style data-style="daylight" data-style-label'), 1, "--theme beats both"
    # The file goes through read-config.sh whole, so what CI refuses is refused here, before a model
    # has drafted a word: a theme: nested under delivery: and a misspelled key are both errors.
    write(cfg_file, "review_map:\n  delivery:\n    theme: workshop\n")
    FileUtils.rm_f(c)
    assert_eq skeleton("--repo", cfg, "--out", c, "--title", "t").code, 2, "a theme: nested under delivery: is refused, as CI refuses it"
    write(cfg_file, "review_map:\n  thme: workshop\n")
    assert_eq skeleton("--repo", cfg, "--out", c, "--title", "t").code, 2, "an unknown key in the repository's config is refused, not ignored"
    assert_eq File.exist?(c) ? "written" : "absent", "absent", "and nothing is written for it"
    write(cfg_file, "review_map:\n  theme: workshp\n")
    FileUtils.rm_f(c)
    assert_eq skeleton("--repo", cfg, "--out", c, "--title", "t").code, 2, "a theme name with no file behind it is refused, not defaulted"
    assert_eq File.exist?(c) ? "written" : "absent", "absent", "and nothing is written"
    # read-config.sh refuses that one before the script's own check is reached; the environment (how
    # CI passes a --config file's theme) and --theme are not parsed by it, so the script's check is
    # theirs.
    FileUtils.rm_f(cfg_file)
    assert_eq skeleton("--repo", cfg, "--out", c, "--title", "t", env: { "ACCOUNTABLE_REVIEW_THEME" => "workshp" }).code, 2,
              "a theme name from the environment with no file behind it is refused, not defaulted"
    assert_eq skeleton("--repo", @tmp, "--theme", "../themes/daylight", "--out", c, "--title", "t").code, 2,
              "a theme name is a name, never a path"

    # ---------------------------------------------------------------- the tint's three grammars
    # A language added to excerpt.sh's guess_lang without its grammar here tints nothing, silently.
    assert_eq count(tail, "<script src="), 3, "highlight.js and both extra grammars are in the skeleton"
    %w[highlight.min.js languages/erb.min.js languages/elixir.min.js].each do |g|
      assert_eq count(tail, g), 1, "the skeleton loads #{g}"
    end

    # ---------------------------------------------------------------- links open in a new tab
    # Applied by the tail script, never typed at a citation — so the assertion is a pair: the rule is
    # in the half nobody reads, and the half a run copies from carries no target for it to imitate.
    assert_eq count(tail, "'target', '_blank'"), 1, "the skeleton's script opens off-page links in a new tab"
    assert_eq count(tail, "'rel', 'noopener noreferrer'"), 1, "it sets rel with target, so the opened page gets no window.opener handle"
    assert_eq count(markup, "target="), 0, "no citation in the markup half types a target for a run to copy"
    # The other half of the same rule, and the one that is silently wrong rather than loudly: the
    # rail and the Checkpoint pointers are this page pointing at itself, and a new tab there is the
    # reader's place lost. The guard is a comparison against the current document, so a component
    # added later is covered without anyone editing the block.
    assert_eq count(tail, "if (there === here) { return; }"), 1, "a link to this same page is left in this tab"

    # ---------------------------------------------------------------- the title
    t = path("t.html")
    title = "<title>Fix A &amp; B &lt;thing&gt; Review</title>"
    skeleton("--repo", @tmp, "--out", t, "--title", "Fix A & B <thing>")
    check read(t).include?(title), "the title is HTML-escaped by the script, so an & in a PR title is not a defect"
    assert_eq count(read(t), "{{PR_TITLE_OR_BRANCH}}"), 0, "the title placeholder is substituted"
    # First line, not merely present: the Artifact gallery names a page from its <title>.
    check read(t).lines.first.to_s.chomp == title, "the <title> is the emitted page's first line"

    # ---------------------------------------------------------------- idempotency, and the refusal
    first = bytes(t)
    skeleton("--repo", @tmp, "--out", t, "--title", "Fix A & B <thing>")
    check bytes(t) == first, "running it twice over an untouched skeleton is byte-identical"

    written = path("written.html")
    write(written, read(t).lines.map { |l| l.include?("SKELETON:BODY") ? "  <main>a section somebody is already reading</main>\n" : l }.join)
    before = bytes(written)
    assert_eq skeleton("--repo", @tmp, "--out", written, "--title", "x").code, 3, "it refuses to overwrite a page that has content in it, and exits 3"
    check bytes(written) == before, "the refused page is left byte-unchanged"
    assert_eq skeleton("--repo", @tmp, "--out", written, "--title", "x", "--force").code, 0, "--force is the way past the refusal"

    # ---------------------------------------------------------------- required arguments
    assert_eq skeleton("--repo", @tmp, "--out", path("n.html")).code, 2, "a missing --title is refused rather than written as a placeholder"
    assert_eq skeleton("--repo", @tmp, "--title", "x").code, 2, "a missing --out is refused"
  end

  # Per ul.lookat li: does it hold an excerpt, and beside it an a.path or an ex-why?
  def lookat_walk(markup)
    f = false
    n = np = nw = 0
    ex = pa = wh = false
    markup.lines.each do |l|
      f = true if l.include?('<ul class="lookat">')
      if f
        ex = pa = wh = false if l.include?("<li>")
        ex = true if l.include?('details class="excerpt')
        pa = true if l.match?(/^ *<a class="path"/)
        wh = true if l.include?('class="ex-why"')
        if l.include?("</li>") && ex
          n += 1
          np += 1 if pa
          nw += 1 if wh
        end
      end
      f = false if l.include?("</ul>")
    end
    [n, np, nw]
  end

  # ------------------------------------------------------------------ diff-render.sh
  #
  # The verdict here decides whether a citation gets a diff anchor or a blob permalink
  # (report-format.md § When the diff will not render), and being wrong is invisible on the page: an
  # anchor into a file GitHub keeps behind "Load diff" lands on a stub, and the reader sees a link
  # that worked. So every signal gets a row, on a repository built here rather than on a fixture,
  # because the answer is a function of git's own attribute resolution and numstat.

  def section_diff_render
    @out.puts "diff-render  #{@diff_render}", ""
    repo = new_repo(path("repo"))
    f = ->(rel) { File.join(repo, rel) }
    # .gitattributes is the signal git resolves for us — nested files and precedence included,
    # which is why the script asks check-attr instead of grepping for the pattern.
    write(f.(".gitattributes"), "db/structure.sql linguist-generated=true\nassets/*.min.js -diff\n")
    write(f.("app/order.rb"), "one\n")
    write(f.("app/big.rb"), lines_of(100))
    # 700 lines that will be edited every 14th, far enough apart that no two hunks merge.
    write(f.("app/scattered.rb"), lines_of(700))
    # One contiguous block, sized so its rendered diff lands one line under the threshold.
    write(f.("app/boundary.rb"), lines_of(500))
    write(f.("db/structure.sql"), lines_of(30_000))
    write(f.("assets/app.min.js"), "v=1\n")
    File.binwrite(f.("app/logo.png"), "\x00\x01\x00")
    write(f.("package-lock.json"), %({"lockfileVersion":3}\n))
    commit_all(repo, "base")
    base = rev(repo)
    # One changed line in a generated file, a change over the auto-load threshold, a change over the
    # hard cap, a binary, a -diff path, a one-line lockfile edit, and one ordinary small file.
    append(f.("app/order.rb"), "two\n")
    write(f.("app/big.rb"), lines_of(700))
    # 50 isolated one-line edits: 100 changed lines, but 50 hunks each costing a header and six
    # context lines, so the diff GitHub renders is ~450 lines. add+del would call this renderable.
    write(f.("app/scattered.rb"), (1..700).map { |i| (i % 14 == 7 ? "scattered" : i.to_s) + "\n" }.join)
    # 196 lines replaced in one hunk: 1 header + 3 context + 196 + 196 + 3 context = 399 rendered.
    write(f.("app/boundary.rb"), (1..500).map { |i| (i >= 100 && i < 296 ? "boundary" : i.to_s) + "\n" }.join)
    write(f.("db/structure.sql"), lines_of(60_000))
    write(f.("assets/app.min.js"), "v=2\n")
    File.binwrite(f.("app/logo.png"), "\x00\x02\x00")
    write(f.("package-lock.json"), %({"lockfileVersion":4}\n))
    commit_all(repo, "head")

    render = ->(*args) { sh(@diff_render, *args, chdir: repo) }
    rows = ->(*args) { render.(*args).out.lines.map(&:split) }
    verdict = ->(p) { rows.(base, "HEAD").select { |r| r[2] == p }.map { |r| "#{r[0]}/#{r[1]}" }.join("\n") }

    assert_eq verdict.("app/order.rb"),      "render/-",               "an ordinary small change renders, so its citation keeps the diff anchor"
    assert_eq verdict.("app/big.rb"),        "collapse/over-autoload", "a diff past 400 lines is behind Load diff, whatever the file is"
    # The row the changed-line measure could not see. Its add+del is 100; the diff GitHub renders is
    # ~450 lines, because context and hunk headers are most of a scattered diff. Measured on real
    # pull requests 2026-09-17: discourse#43002 reports.gjs collapsed at 342 changed / 414 rendered,
    # while discourse#43772 core_primitives.rb rendered at 349 changed / 394 — 349 rendering while
    # 342 collapses is what rules out counting the changed lines.
    assert_eq verdict.("app/scattered.rb"),  "collapse/over-autoload", "context pushes a diff past 400 rendered lines though its changed lines are far fewer"
    # And the other side of the same boundary, because counting more lines can only ever collapse
    # more files: a diff of 399 rendered lines must still get its anchor.
    assert_eq verdict.("app/boundary.rb"),   "render/-",               "a diff one line under the threshold keeps its anchor"
    assert_eq verdict.("db/structure.sql"),  "collapse/generated",     "linguist-generated collapses on one changed line, where no size rule would fire"
    assert_eq verdict.("assets/app.min.js"), "collapse/no-diff",       "a -diff path is reported as an attribute, not as a coincidence of its bytes"
    assert_eq verdict.("app/logo.png"),      "collapse/binary",        "a binary file has no line to anchor to"
    assert_eq verdict.("package-lock.json"), "collapse/lockfile",      "a lockfile collapses as generated even when its diff is one line"

    # The hard cap is a different sentence on the page from the auto-load threshold — past it Load
    # diff does not fully help either — so the reason has to survive, not just the verdict. On its
    # own branch, and checked out BACK afterwards: leaving the repository on that branch redefines
    # HEAD for every row below.
    was = git(repo, "rev-parse", "--abbrev-ref", "HEAD").out.strip
    git(repo, "checkout", "-q", "-b", "hardcap", base)
    write(f.("db/big.txt"), lines_of(30_000))
    commit_all(repo, "hardcap")
    git(repo, "checkout", "-q", was)
    assert_eq rows.(base, "hardcap").select { |r| r[2] == "db/big.txt" }.map { |r| r[1] }.join("\n"), "over-hard-cap",
              "a diff past 20,000 lines is reported as over the hard cap, not merely un-auto-loaded"

    # --path is what a run asks while writing one citation, and a path outside the diff has to come
    # back renderable rather than collapse: an *affected but unchanged* citation is a blob link
    # already, and the commonest citation on the page must not be answered with a guess.
    one = ->(p) { rows.(base, "HEAD", "--path", p).map { |r| "#{r[0]}/#{r[1]}" }.join("\n") }
    assert_eq one.("app/order.rb"),     "render/-",           "--path answers about one file"
    assert_eq one.("app/untouched.rb"), "render/not-in-diff", "a path the diff never touched is not reported as collapsed"

    collapsed = render.(base, "HEAD", "--collapsed-only").out
    assert_eq count(collapsed, /^collapse/), 6, "--collapsed-only lists every collapsed path and no renderable one"
    assert_eq count(collapsed, /^render/),   0, "--collapsed-only emits no render rows"

    # The whole-diff caps are the two facts no per-path verdict can carry, so they are stated once.
    check render.(base, "HEAD").out.match?(/file\(s\),.*bytes of diff/), "the trailing summary states the file count and the diff size"

    assert_eq render.().code, 2, "a missing BASE is refused rather than diffed against nothing"

    # Asked and unable to answer is not an empty diff. Every git call here feeds a pipeline, so a
    # failing one leaves the exit status at 0 and prints no rows — which reads as "no file is
    # withheld", the most reassuring output this script has and the one with the least behind it.
    r = render.("0" * 40, "HEAD")
    assert_eq r.code, 4, "an unresolvable BASE exits 4 rather than reporting an empty diff"
    assert_eq count(r.out, /./), 0, "and prints nothing that could be read as a verdict"
  end

  # ------------------------------------------------------------------ carry-plan.sh
  #
  # The carry decision is the one place in this repository where being wrong is SILENT: a checkpoint
  # wrongly carried is a claim nobody re-read, sitting on a page whose masthead says it describes the
  # current head. Every row below is a way that happens. The repository is built here rather than on
  # a fixture for diff-render.sh's reason — the answer is a function of git.

  # A recorded search that matches nothing. grep, never rg — see the header.
  NOHIT = "grep -rn &#39;nothing_matches_this&#39; app"

  # search is the recorded search, already HTML-escaped as a real page carries it; extra is more
  # body. The two short SHAs are what P2 reads. revision is the revision the page claims to
  # describe: a row updating from a later commit has to pass it, or it refuses at P2 and passes for
  # a reason that has nothing to do with its subject.
  def cpage(search, extra = "", revision = @sh_prev)
    write(@cpage, <<~PAGE)
      <div class="c"><div class="path">#{revision} &rarr; #{@sh_base}</div></div>
      <section id="attention">
      <section class="cp" id="cp-a"><h3>Q1</h3>
        <a class="path" href="#">app/models/project.rb:1-2</a>
        <pre data-src="app/models/project.rb">x</pre></section>
      <section class="cp" id="cp-b"><h3>Q2</h3>
        <a class="path" href="#">app/queries/active.rb:1</a>
        <pre data-src="app/queries/active.rb">x</pre></section>
      <section class="cp" id="cp-c"><h3>Q3</h3>
        <a class="path" href="#">api/Gemfile.lock:1</a></section>
      </section>
      <section id="context"><dl class="ctx">
      <dt>Active scope</dt>
      <dd>What it is. <a class="path" href="#">app/queries/active.rb:1</a>
        <span class="ctx-used">Used by <a href="#cp-a">Checkpoint A</a></span></dd>
      <dt>Lock &amp; bundle</dt>
      <dd>What it is. <a class="path" href="#">api/Gemfile.lock:1</a>
        <span class="ctx-used">Used by <a href="#cp-c">Checkpoint C</a></span></dd>
      </dl>
      <figure class="lifecycle lc-shift"><div class="lc-pair">
        <a class="path ip-loc" href="#">app/queries/active.rb:1</a></div></figure>
      </section>
      <details class="searched"><ul class="sr-list">
      <li><code>#{search}</code> <span class="sr-r">a clause</span></li>
      </ul></details>
      #{extra}
    PAGE
  end

  # Runs carry-plan.sh over the page; the plan's lines, and its exit status.
  def plan(*args, page: @cpage)
    r = sh(@carry_plan, page, *args, chdir: @crepo)
    [r.out.lines.map(&:chomp), r.code]
  end

  def rows(out, re) = out.count { |l| l.match?(re) }

  def section_carry_plan
    @out.puts "carry-plan  #{@carry_plan}", ""
    @crepo = repo = new_repo(path("cprepo"))
    @cpage = path("cpage.html")
    f = ->(rel) { File.join(repo, rel) }
    write(f.("app/models/project.rb"), "class Project; end\n")
    write(f.("app/queries/active.rb"), "class Active; end\n")
    # Two paths where one is a prefix of the other, because that is the substring trap
    # coverage-gate.sh already paid for and it is worse here: there it fails a page loudly, here it
    # would CARRY a checkpoint that cites the changed file.
    write(f.("api/Gemfile"), %(source "x"\n))
    write(f.("api/Gemfile.lock"), "GEM\n")
    write(f.("README.md"), "readme\n")
    commit_all(repo, "base")
    cbase = rev(repo)
    # The first push: what the previous map described.
    append(f.("app/models/project.rb"), "# one\n")
    append(f.("app/queries/active.rb"), "# one\n")
    commit_all(repo, "push1")
    cprev = rev(repo)
    # The second push: the delta. One file, so the delta is half the diff and P4 admits it.
    append(f.("app/queries/active.rb"), "# second push\n")
    commit_all(repo, "push2")
    chead = rev(repo)
    @sh_prev = git(repo, "rev-parse", "--short=7", cprev).out.strip
    @sh_base = git(repo, "rev-parse", "--short=7", cbase).out.strip
    sh_head = git(repo, "rev-parse", "--short=7", chead).out.strip

    # A branch off chead with one more commit, left checked out — the shell suite's order, because
    # the recorded searches P6 replays read the working tree.
    branch = lambda do |name, &edit|
      git(repo, "checkout", "-q", "-B", name, chead)
      edit.call
      commit_all(repo, name)
      rev(repo)
    end

    # -- the plan itself --------------------------------------------------------------------------
    cpage(NOHIT)
    out, code = plan("--prev-head", cprev, "--base", cbase, "--head", chead)
    assert_eq code, 0, "a clean delta produces a plan rather than a refusal"
    assert_eq rows(out, /^verdict: update/), 1, "and says so in one verdict line"
    assert_eq rows(out, %r{^delta\tapp/queries/active\.rb$}), 1, "the delta is the second push's paths, not the whole diff"
    assert_eq rows(out, /^delta\t/), 1, "and nothing the first push changed is in it"
    assert_eq rows(out, /^cp\tcp-a\tcarry\t-$/), 1, "a checkpoint citing nothing in the delta is carried"
    assert_eq rows(out, %r{^cp\tcp-b\tredo\tcites app/queries/active\.rb$}), 1, "a checkpoint citing a delta path is re-derived, and the row says which path"

    # The substring trap, both directions. cp-c cites api/Gemfile.lock and the delta below is
    # api/Gemfile: a substring test carries neither and a reversed one carries both.
    assert_eq rows(out, /^cp\tcp-c\tcarry\t-$/), 1, "a checkpoint citing a path unrelated to the delta is carried"

    # A Context entry sits outside every checkpoint, so the cp rule cannot see it — and cp-a carries
    # here while the entry it relies on cites the file the delta moved. Keyed by the entry's name.
    assert_eq rows(out, %r{^ctx\tActive scope\tredo\tcites app/queries/active\.rb$}), 1,
              "a Context entry citing a delta path is re-derived, though the checkpoint using it carries"
    assert_eq rows(out, /^ctx\tLock & bundle\tcarry\t-$/), 1, "a Context entry citing nothing in the delta is carried, named by its unescaped dt"
    # The figure sits after the last entry and cites the delta path: it is its own row, and the entry
    # before it does not inherit its citation — which the Lock & bundle row above already asserts.
    assert_eq rows(out, %r{^ctx\tlc-shift\tredo\tcites app/queries/active\.rb$}), 1, "Context's before-and-after figure citing a delta path is re-derived"

    # And the trap itself, which needs a delta that is a PREFIX of a cited path rather than merely
    # unrelated to it: api/Gemfile changed, and cp-c cites api/Gemfile.lock.
    cgem = branch.("gem") { append(f.("api/Gemfile"), %(gem "x"\n)) }
    cpage(NOHIT, "", sh_head)
    out, = plan("--prev-head", chead, "--base", cbase, "--head", cgem)
    assert_eq rows(out, %r{^delta\tapi/Gemfile$}), 1, "the prefix case reaches the carry rule at all"
    assert_eq rows(out, /^cp\tcp-c\tcarry\t-$/), 1, "api/Gemfile in the delta does not match api/Gemfile.lock on the page"
    assert_eq rows(out, /^ctx\tLock & bundle\tcarry\t-$/), 1, "and a Context entry citing api/Gemfile.lock is carried by the same boundary"

    # Back to the first scenario, because the rows below read its plan.
    cpage(NOHIT)
    out, = plan("--prev-head", cprev, "--base", cbase, "--head", chead)

    # -- excerpts ----------------------------------------------------------------------------------
    # An excerpt is a verbatim quotation AND its state tag is computed from base...head, so a file
    # entering the diff in the delta invalidates both.
    assert_eq rows(out, %r{^excerpt\tapp/queries/active\.rb\tregen$}), 1, "an excerpt whose file moved in the delta is regenerated"
    assert_eq rows(out, %r{^excerpt\tapp/models/project\.rb\tkeep$}), 1, "an excerpt whose file did not is left alone"

    replay = lambda do |search|
      cpage(search)
      plan("--prev-head", cprev, "--base", cbase, "--head", chead)
    end

    # -- P6 · the delta landed where the page searched ---------------------------------------------
    # The rule that protects the product. A new consumer in a file NO checkpoint cites is invisible
    # to the carry rule, and the recorded searches are the only thing on the page that can see it.
    out, code = replay.("grep -rn &#39;second push&#39; app")
    assert_eq code, 3, "a delta path among a recorded search's hits refuses the update"
    assert_eq rows(out, /recorded search/), 1, "and names the search that found it"

    # -v would have eaten the word boundaries and the pattern would have matched something else
    # while still looking like it ran. Only an escape-bearing pattern can tell the two apart.
    _, code = replay.("grep -rn &#39;\\bsecond push\\b&#39; app")
    assert_eq code, 3, "a pattern's backslash escapes reach the tool intact"
    _, code = replay.("grep -rn &#39;\\bsecondpush\\b&#39; app")
    assert_eq code, 0, "and a boundary that genuinely does not match does not refuse"

    # A context window is a search searches.rb credits, so the replay has to read it. Its output
    # carries `path-2-text` lines no path:line:text parse reads; project.rb has a second line for
    # the window to reach, and it is not in the delta.
    _, code = replay.("grep -rn -A2 &#39;class Project&#39; app")
    assert_eq code, 0, "a recorded search with a context window is replayed rather than refused"
    out, = replay.("grep -rn -A2 &#39;second push&#39; app")
    assert_eq rows(out, /now finds/), 1, "and a windowed search that reaches the delta refuses for that reason"
    _, code = replay.("grep -n &#39;class Project&#39; app/models/project.rb")
    assert_eq code, 0, "a search over one file, which prints no filename column, is replayed too"

    # -- P6 · a search of the merge-base is fixed, not replayed --------------------------------------
    # An architectural checkpoint records the base half of its search as `git grep … <merge-base sha>`,
    # and git prints each hit as `sha:path`, which the hit-shape test cannot read. P2 already refuses
    # an update whose merge-base moved, so the commits since the last map cannot change what that
    # search returns: it is skipped as fixed, never sent to a full run for its shape. The base here
    # has hits for the pattern, so a row that still read the shape would refuse.
    out, code = replay.("git grep -n &#39;class&#39; #{cbase} -- app")
    assert_eq code, 0, "a recorded search of the merge-base does not refuse the update"
    assert_eq rows(out, /searches the merge-base/), 1, "and is recorded as fixed rather than replayed"

    # Any other revision is still a shape this cannot read: only the merge-base has a precondition
    # holding it still.
    _, code = replay.("git grep -n &#39;class&#39; #{cprev} -- app")
    assert_eq code, 3, "a recorded search of any other revision still refuses"

    # Nor does naming the merge-base buy an exemption for the other trees beside it: HEAD is a
    # tree these commits changed, and it is not hex.
    _, code = replay.("git grep -n &#39;class&#39; #{cbase} HEAD -- app")
    assert_eq code, 3, "a recorded search of the merge-base and HEAD together still refuses"

    # -- P6 · the replay is argv, and the gate is quote-aware ---------------------------------------
    # Every alternation in both lens files sits inside quotes, so a blanket refusal of | and < would
    # reject the real searches and send every re-run to a full one. Outside quotes the same
    # characters are a shell doing something.
    _, code = replay.("grep -Ern &#39;include Archivable|&lt; Project&#39; app")
    assert_eq code, 0, "a quoted alternation is replayed rather than refused"
    out, code = replay.("grep -rn &#39;x&#39; app ; echo pwned")
    assert_eq code, 3, "a shell metacharacter outside quotes refuses the whole update"
    assert_eq rows(out, /^pwned$/), 0, "and the command it would have run was never executed"
    _, code = replay.("grep -rn &#39;x&#39; app `id`")
    assert_eq code, 3, "a command substitution refuses too"

    # A tool this cannot replay is not a search that found nothing. Fail closed.
    _, code = replay.("ag -n &#39;x&#39; app")
    assert_eq code, 3, "a search whose tool is not installed refuses rather than counting as empty"

    # -- P1 · the branch was rebased or force-pushed ------------------------------------------------
    git(repo, "checkout", "-q", "--detach", cprev)
    git(repo, "commit", "-q", "--allow-empty", "-m", "sibling")
    csib = rev(repo)
    git(repo, "checkout", "-q", "-")
    cpage(NOHIT)
    out, code = plan("--prev-head", chead, "--base", cbase, "--head", csib)
    assert_eq code, 3, "a head that is not a descendant of the previous one refuses the update"
    assert_eq rows(out, /force-pushed/), 1, "and says the branch moved rather than reporting an empty delta"
    # A refusal prints the reason and the verdict and nothing else: half a plan reads as a plan.
    assert_eq rows(out, /^(cp|ctx|delta|excerpt)\t/), 0, "a refusal prints no plan rows at all"
    assert_eq rows(out, /./), 2, "only the reason and the verdict"

    # -- P2 · the page is not the page we think it is -----------------------------------------------
    cpage(NOHIT)
    write(@cpage, read(@cpage).lines.map { |l| l.sub(@sh_prev, "0000000") }.join)
    _, code = plan("--prev-head", cprev, "--base", cbase, "--head", chead)
    assert_eq code, 3, "a page that does not name the revision it is said to describe refuses"
    cpage(NOHIT)
    write(@cpage, read(@cpage).lines.map { |l| l.sub(@sh_base, "0000000") }.join)
    _, code = plan("--prev-head", cprev, "--base", cbase, "--head", chead)
    assert_eq code, 3, "a page that does not name the merge-base refuses — the diff's left side moved"

    # -- P3 · the previous page is not finished -----------------------------------------------------
    # Pending is a promise. An update that carried one would be promising work nothing is doing, and
    # a stopped page is one someone has to finish deliberately (SKILL.md § When a run stops early).
    {
      '<div class="buildstate">Still being written</div>' => "a page still carrying a build banner is a draft, not a base to update",
      '<span class="pending">pending</span>' => "a pending marker refuses for the same reason",
      "<p>Section 5 was not written.</p>" => "and a stopped run is finished deliberately, never updated"
    }.each do |extra, label|
      cpage(NOHIT, extra)
      _, code = plan("--prev-head", cprev, "--base", cbase, "--head", chead)
      assert_eq code, 3, label
    end

    # -- P4 · the delta is more than half the diff ---------------------------------------------------
    # Past half, an update costs more than a fresh run and produces a worse page, because the run
    # pays to read the old page as well and carries fewer of its claims for it.
    cwide = branch.("wide") do
      append(f.("app/models/project.rb"), "# wide\n")
      append(f.("app/queries/active.rb"), "# wide\n")
    end
    cpage(NOHIT, "", sh_head)
    out, code = plan("--prev-head", chead, "--base", cbase, "--head", cwide)
    assert_eq code, 3, "a delta covering more than half the diff refuses"
    assert_eq rows(out, /more than half/), 1, "and says so rather than reporting a git failure"
    # P1 refuses before the delta is computed, so the row there cannot see a refusal that prints
    # the delta it has. This one can.
    assert_eq rows(out, /^(cp|ctx|delta|excerpt)\t/), 0, "a refusal after the delta is known prints no plan rows either"

    # -- P5 · a lock file moved ----------------------------------------------------------------------
    # Every pinned documentation link on the page is derived from it, and there is no way to carry a
    # pinned link across a series change.
    clock = branch.("locked") { write(f.("api/Gemfile.lock"), "GEM2\n") }
    cpage(NOHIT, "", sh_head)
    out, code = plan("--prev-head", chead, "--base", cbase, "--head", clock)
    assert_eq code, 3, "a lock file in the delta refuses the update"
    assert_eq rows(out, /lock file/), 1, "and names that as the reason"

    # Cargo.lock is the Rust form of the same precondition: every docs.rs link is pinned from it.
    ccargo = branch.("cargolock") { write(f.("crates/core/Cargo.lock"), "version = 3\n") }
    cpage(NOHIT, "", sh_head)
    _, code = plan("--prev-head", chead, "--base", cbase, "--head", ccargo)
    assert_eq code, 3, "a Cargo.lock in the delta refuses the update too"

    # -- called wrongly, and asked-but-unable ---------------------------------------------------------
    cpage(NOHIT)
    _, code = plan("--prev-head", cprev, "--base", cbase)
    assert_eq code, 2, "a missing --head is refused rather than guessed at"
    _, code = plan("--prev-head", cprev, "--base", cbase, "--head", chead, page: path("nope.html"))
    assert_eq code, 2, "an unreadable page is refused"

    # Asked and unable to answer is not an empty delta — diff-render.sh's guard, and the same failure
    # shape: a pipeline whose git failed prints no rows and exits 0, which reads as "nothing changed",
    # the most reassuring answer this script has.
    out, code = plan("--prev-head", "0" * 40, "--base", cbase, "--head", chead)
    assert_eq code, 4, "an unresolvable ref exits 4 rather than reporting an empty delta"
    assert_eq rows(out, /./), 0, "and prints nothing that could be read as a plan"
  end

  # ------------------------------------------------------------------ excerpt.sh
  #
  # The quotation's bytes are git's, so what is tested here is the frame around them: where the
  # citation goes and what the summary says. A summary that carries no link at rungs 1 and 2 leaves
  # a closed excerpt with nothing to click, and one that carries the link AND a body-foot copy is the
  # duplicate this layout exists to remove.

  def section_excerpt
    @out.puts "excerpt  #{@excerpt}", ""
    repo = new_repo(path("exrepo"))
    write(File.join(repo, "app/changed.rb"), "a\nb\nc\n")
    write(File.join(repo, "app/same.rb"), "keep\n")
    commit_all(repo, "base")
    write(File.join(repo, "app/changed.rb"), "a\nB\nc\n")
    git(repo, "commit", "-qam", "head")
    ex = ->(*args) { sh("sh", @excerpt, *args, chdir: repo) }

    out = ex.("--at", "app/same.rb:1-1", "--base", "HEAD~1", "--blob", "https://h/blob/s/app/same.rb", "--why", "w").out
    assert_eq count(out, '<span class="ex-loc"><a class="cite" href="https://h/blob/s/app/same.rb#L1-L1">app/same.rb:1-1</a></span>'), 1,
              "--at with a link puts it on the summary's location, with the range it read"
    assert_eq count(out, "ex-src"), 0, "and repeats it nowhere under the code"
    assert_eq count(out, '<span class="ex-why">w</span>'), 1, "and keeps the why outside an entry"
    assert_eq count(out, '<span class="tag">Unchanged</span>'), 1, "and tags a path outside the diff Unchanged"

    out = ex.("--at", "app/same.rb:1-1", "--base", "HEAD~1").out
    assert_eq count(out, '<span class="ex-loc">app/same.rb:1-1</span>'), 1, "with no link the location is plain text, the rung-3/4 citation"

    out = ex.("--at", "app/same.rb:1-1", "--base", "HEAD~1", "--in-entry", "--blob", "https://h/blob/s/app/same.rb").out
    assert_eq count(out, "ex-why"), 0, "--in-entry leaves the why to the entry's clause"
    assert_eq count(out, "WHY_THIS_MATTERS"), 0, "and leaves no placeholder for it either"

    assert_eq ex.("--at", "app/same.rb:1-1", "--base", "HEAD~1", "--in-entry", "--why", "w").code, 2,
              "--in-entry with --why is refused rather than choosing one"

    out = ex.("--diff", "app/changed.rb", "--base", "HEAD~1", "--blob", "https://h/blob/s/app/changed.rb", "--in-entry").out
    assert_eq count(out, '<span class="ex-loc"><a class="cite" href="https://h/blob/s/app/changed.rb#L1-L3">app/changed.rb:1-3</a></span>'), 1,
              "--diff links the summary's location at the hunk's own range"
    assert_eq count(out, /ex-src|ex-why/), 0, "and, in an entry, carries no second citation and no why"

    d = "0123456789abcdef" * 4
    out = ex.("--diff", "app/changed.rb", "--base", "HEAD~1", "--in-entry", "--link", "https://h/pull/1/files#diff-#{d}R9").out
    assert_eq count(out, %(href="https://h/pull/1/files#diff-#{d}R1-R3")), 1,
              "--diff given a diff-page anchor links the hunk's own R-range, whatever range it carried"

    out = ex.("--diff", "app/changed.rb", "--base", "HEAD~1").out
    assert_eq count(out, '<span class="ex-loc">app/changed.rb:1-3</span>'), 1, "--diff with no link leaves the location plain"
    assert_eq count(out, "WHY_THIS_MATTERS"), 1, "and an unwritten why stays visibly unwritten"
  end

  # ------------------------------------------------------------------ page-lint.sh
  #
  # The runtime reading a run acts on at step 10 (SKILL.md), in shell because it runs on the user's
  # machine. The tier fixtures are the eval's golden pages — one defect each, their ledger the
  # changed set — because evals/checks/page-invariants.rb § 10 relays this script, so one set of
  # pages holds both readers to the same answer.

  def lint(file) = sh(@page_lint, file)

  def excerpt_entry(title, clause, loc)
    %(<li><b>#{title}</b> <span>#{clause} <span class="tier tier-unc">from unchanged code</span></span>\n) +
      %(<details class="excerpt excerpt--source"><summary><span class="chev">&#9656;</span>\n) +
      %(<span class="ex-loc">#{loc}</span>\n) +
      %(<span class="tag">Unchanged</span></summary><div class="ex-body"><pre data-src="x">code</pre></div></details></li>\n)
  end

  def section_page_lint
    @out.puts "page-lint  #{@page_lint}", ""
    ledger = %(<details class="evidence"><div class="gt gt-paths"><div class="c" data-path="app/models/project.rb">x</div></div></details>\n)

    r = lint(File.join(@golden, "invariants-tier-clean.html"))
    assert_eq count(r.out, "WARN"), 0, "a page whose labels agree with its ledger draws no WARN"
    assert_eq count(r.out, "PASS  tiers agree with the changed set"), 1, "and says the tiers agree, naming the ledger"
    assert_eq r.code, 0, "a WARN-free page exits 0"

    %w[unlabelled uncited on-changed].each do |shape|
      r = lint(File.join(@golden, "invariants-tier-#{shape}.html"))
      assert_eq count(r.out, "WARN"), 1, "invariants-tier-#{shape}.html draws exactly one WARN"
      assert_eq count(r.out, "WARN  #{shape} —"), 1, "and it is the #{shape} shape"
      assert_eq r.code, 0, "a WARN never moves the exit code"
    end

    # The href is where a citation's path lives when its text is short: app/models/project.rb is in
    # the ledger, so `project.rb:41` under a blob permalink is changed code (no WARN), and a diff-form
    # href is changed by definition. lib/other.rb is in neither, so its short citation with no tier is
    # the unlabelled shape — and a plain-text citation matches on its suffix.
    write(path("href.html"), <<~HTML)
      <section class="cp" id="cp-a">
        <p>The column is set at <a class="path" href="https://github.com/o/r/blob/0123abcd/app/models/project.rb#L41">project.rb:41</a>. The hunk at <a class="path" href="https://github.com/o/r/pull/1/files#diff-abc">project.rb:41</a> shows it. The helper at <a class="path" href="https://github.com/o/r/blob/0123abcd/lib/other.rb#L3">other.rb:3</a> reads it. The spec at <a class="path">spec/models/project_spec.rb:9</a> pins it.</p>
      </section>
      <details class="evidence"><summary>Evidence</summary><div class="gt gt-paths">
      <div class="c" data-path="app/models/project.rb">app/models/project.rb</div>
      <div class="c" data-path="spec/models/project_spec.rb">spec/models/project_spec.rb</div>
      </div></details>
    HTML
    r = lint(path("href.html"))
    assert_eq count(r.out, "WARN"), 1, "a citation's path is read from its href, a diff href is changed, plain text matches on its suffix"
    assert_eq count(r.out, "other.rb:3"), 1, "and the one WARN names the file outside the ledger"

    # A card's why may not carry a citation — impact-paths.rb holds that line — so its unchanged-code
    # label is never the uncited shape. The same label in a paragraph is.
    write(path("why.html"), %(<p class="ip-why">An archived project stays selectable <span class="tier tier-unc">from unchanged code</span>. <a href="#cp-a">Checkpoint A</a></p>\n) + ledger)
    assert_eq count(lint(path("why.html")).out, "WARN"), 0, "a card's why with an unchanged-code label and no citation is not the uncited shape"

    # A Look at entry whose citation is an in-entry excerpt carries it as excerpt.sh writes it — a
    # span.ex-loc holding the link, or the plain location on an unlinked rung — and that span is the
    # entry's citation. app/queries/active_projects.rb is outside the ledger, so its labelled entries
    # are clean; the same span over app/models/project.rb, which the ledger lists, is the on-changed
    # shape — which proves the span's href is resolved and not merely counted as a citation.
    write(path("excerpt-clean.html"),
          %(<section class="cp" id="cp-a"><ul class="lookat">\n) +
          excerpt_entry("Linked summary", "filters on status only",
                        '<a class="cite" href="https://github.com/o/r/blob/0123abcd/app/queries/active_projects.rb#L12-L14">active_projects.rb:12-14</a>') +
          excerpt_entry("Plain summary", "reads no archived flag", "app/queries/active_projects.rb:12-14") +
          "</ul></section>\n" + ledger)
    assert_eq count(lint(path("excerpt-clean.html")).out, "WARN"), 0, "an excerpt summary is the entry's citation, linked or plain"
    write(path("excerpt-changed.html"),
          %(<section class="cp" id="cp-a"><ul class="lookat">\n) +
          excerpt_entry("Linked summary over changed code", "sets the column",
                        '<a class="cite" href="https://github.com/o/r/blob/0123abcd/app/models/project.rb#L41">project.rb:41</a>') +
          "</ul></section>\n" + ledger)
    r = lint(path("excerpt-changed.html"))
    assert_eq count(r.out, "WARN  on-changed"), 1, "and the summary's href is resolved: a label over a changed file's excerpt is on-changed"
    assert_eq count(r.out, "WARN"), 1, "with no other WARN"

    # Placeholders are the one FAIL: the template copied and not filled in.
    write(path("ph.html"), %(<p>{{WHAT_GOES_WRONG}} <a href="#cp-{{LETTER}}">Checkpoint {{LETTER}}</a></p>\n))
    r = lint(path("ph.html"))
    assert_eq count(r.out, "FAIL  placeholders"), 1, "a placeholder left on the page is a FAIL"
    assert_eq count(r.out, "{{LETTER}} {{WHAT_GOES_WRONG}}"), 1, "naming each placeholder once"
    assert_eq r.code, 1, "and the exit code says so"

    # No ledger and no repository: nothing to hold a label against, said out loud rather than passed.
    write(path("bare.html"), %(<p>A claim <span class="tier tier-unc">from unchanged code</span>.</p>\n))
    r = lint(path("bare.html"))
    assert_eq count(r.out, "SKIP  tiers"), 1, "with no changed set the tier rule says SKIP"
    assert_eq count(r.out, "WARN"), 0, "and warns on nothing"

    # A comment carries every placeholder and rule name in the template; none of it is read.
    write(path("comment.html"), %(<!-- {{IN_A_COMMENT}} from unchanged code --><p>Plain.</p>\n<div class="c" data-path="a.rb">a</div>\n))
    assert_eq count(lint(path("comment.html")).out, "FAIL"), 0, "a placeholder inside a comment is not on the page"
  end

  # ------------------------------------------------------------------ usage.sh
  #
  # What a Codex run spent, read off the session log. The fixture is a CODEX_HOME holding this
  # thread's rollout, one falsifier's (its session meta names this thread as parent), and an
  # unrelated thread's, which must not count. Token lines are the shape Codex's protocol serialises:
  # an event_msg whose payload is a token_count with `info.total_token_usage` and `rate_limits`.

  TID = "0199aaaa-0000-7000-8000-00000000cafe"

  # in cached out primary_used [reset] — one token_count line
  def tc(inp, cached, out, used, reset = 1_760_900_000)
    %({"timestamp":"t","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":#{inp},"cached_input_tokens":#{cached},"output_tokens":#{out},"reasoning_output_tokens":0,"total_tokens":0},"last_token_usage":{"input_tokens":1,"cached_input_tokens":1,"output_tokens":1,"reasoning_output_tokens":0,"total_tokens":2},"model_context_window":272000},"rate_limits":{"limit_id":"codex","primary":{"used_percent":#{used},"window_minutes":300,"resets_at":#{reset}},"secondary":{"used_percent":12.0,"window_minutes":10080,"resets_at":1761000000}}}}\n)
  end

  def meta(id, parent) = %({"timestamp":"t","type":"session_meta","payload":{"id":"#{id}","session_id":"#{TID}","parent_thread_id":#{parent},"cwd":"/r"}}\n)

  def usage(tid, mode, work) = sh(@usage, mode, work, env: { "CODEX_THREAD_ID" => tid, "CODEX_HOME" => @codex })

  def section_usage
    @out.puts "usage  #{@usage}", ""
    @codex = path("codex")
    day = File.join(@codex, "sessions/2026/10/19")
    work = path("uw")
    FileUtils.mkdir_p([day, work])
    roll = File.join(day, "rollout-2026-10-19T10-00-00-#{TID}.jsonl")
    write(roll, meta(TID, "null") + tc(100_000, 80_000, 2000, "30.0"))

    r = usage("", "mark", work)
    assert_eq count(r.out, "SKIP usage: not a Codex session"), 1, "outside Codex it says SKIP, since Claude Code counts its own"
    assert_eq r.code, 0, "and a count it cannot read never stops a run"

    # A subagent of this thread from an earlier task, begun before the mark and still writing after it.
    early = File.join(day, "rollout-2026-10-19T09-00-00-0199ffff-early.jsonl")
    write(early, meta("0199ffff-early", %("#{TID}")) + tc(50_000, 0, 500, "29.0"))
    assert_eq count(usage(TID, "mark", work).out, "USAGE marked"), 1, "mark records where the thread stands"
    append(early, tc(70_000, 0, 700, "36.5"))
    append(roll, tc(900_000, 800_000, 12_000, "36.5"))
    write(File.join(day, "rollout-2026-10-19T10-05-00-0199bbbb-child.jsonl"), meta("0199bbbb-child", %("#{TID}")) + tc(300_000, 250_000, 6000, "36.5"))
    write(File.join(day, "rollout-2026-10-19T10-06-00-0199cccc-other.jsonl"), meta("0199cccc-other", '"0199dddd-unrelated"') + tc(999_999, 0, 999, "36.5"))

    out = usage(TID, "report", work).out
    assert_eq count(out, "USAGE review map used 1.12M tokens (1.10M input, 970k of it cached · 16k output; falsifiers 306k of it)"), 1,
              "report subtracts the mark, adds the falsifier, and leaves another thread's and an earlier subagent's logs out"
    assert_eq count(out, "5-hour window 30% → 36.5% (+6.5%), 7-day window 12% → 12% (+0%), account-wide"), 1,
              "and says how far each window moved, named from its length, account-wide"

    append(roll, tc(950_000, 850_000, 13_000, "4.0", 1_760_918_000)) # the 5-hour window reset since the mark
    out = usage(TID, "report", work).out
    assert_eq count(out, "5-hour window at 4%"), 1, "a window that reset is reported where it stands, never as a share"
    assert_eq count(out, "→ 4%"), 0, "with no delta across the reset"

    # A revert writes a newer rollout for the same thread, its totals starting over. Newer by an
    # mtime set here, not by sleeping past the file system's granularity.
    reverted = roll.sub(/\.jsonl\z/, "_0199abcd.jsonl")
    write(reverted, meta(TID, "null") + tc(1000, 0, 10, "4.0", 1_760_918_000))
    later = File.mtime(roll) + 10
    File.utime(later, later, reverted)
    assert_eq count(usage(TID, "report", work).out, "SKIP usage: the thread was reverted since the mark"), 1,
              "a thread reverted since the mark is refused rather than subtracted across two logs"
    FileUtils.rm_f(reverted)

    # Just under a million rounds into millions, never to 1000k.
    tid2 = "0199aaaa-0000-7000-8000-00000000beef"
    roll2 = File.join(day, "rollout-2026-10-19T11-00-00-#{tid2}.jsonl")
    work2 = path("uw2")
    FileUtils.mkdir_p(work2)
    write(roll2, meta(tid2, "null") + tc(0, 0, 0, "30.0"))
    usage(tid2, "mark", work2)
    append(roll2, tc(999_000, 0, 700, "30.0"))
    assert_eq count(usage(tid2, "report", work2).out, "used 1.00M tokens (999k input"), 1, "999,700 tokens read as 1.00M"

    assert_eq count(usage("0199eeee-not-marked", "report", work).out, "SKIP usage: no Codex session log"), 1, "a thread with no log says SKIP"
    assert_eq usage(TID, "report", path("nope")).code, 2, "a missing work directory is a usage error"
  end
end
