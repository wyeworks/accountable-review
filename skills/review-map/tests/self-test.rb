#!/usr/bin/env ruby
# frozen_string_literal: true

# self-test.rb — breaks things suite.rb claims to check, and asserts it notices each one.
#
#   Usage: ruby skills/review-map/tests/self-test.rb [--discover] [-j N] [number...]
#
# Same argument as evals/checks/self-test.rb: a check that passes because it never looked is worse
# than no check, and the only way to tell the two apart is to introduce the defect and watch the
# suite go red. So each case breaks exactly one thing, on a copy of the skill, and asserts that the
# NAMED assertion now fails — not merely that something did. A break that "fails" because it crashed
# an unrelated fixture is reported, not counted.
#
# Two kinds of break, and the split matters. Breaking the TEMPLATE proves the assertions about what
# each half must contain. Breaking the SCRIPT is what proves the partition assertion, because a
# template break alone cannot: the script extracts from the same file the test compares against, so
# both sides move together and the suite would stay green. That is the oracle problem in the one
# place it could still hide, so the first two cases here are script breaks.
#
# WHICH DEFECTS EARN A ROW. The sanity row runs every section on the unbroken copy and requires it
# green, and for an assertion of the form `count == N` with N of one or more, that already proves the
# pattern is spelled right and the assertion looked: a misspelled literal counts 0 and fails
# unbroken. Deleting the literal again only proves assert_eq can tell 0 from 1. So a template row is
# written only where the real template could pass with the check broken:
#   - an assertion expecting ZERO, because a misspelled pattern also counts zero and passes;
#   - a range or an order whose boundary could be wrong and still yield the expected count.
# Script breaks always earn one: they ask whether the suite's fixtures exercise the script's logic at
# all, and no unbroken run can answer that.
#
# A case runs only the section of suite.rb its break can reach, and the cases run in parallel, each
# worker on its own copy of skills/review-map. Nothing here touches the real files.
#
# --discover prints every assertion each break turns red, which is how the `expect` column below was
# chosen and how to choose one for a new row.
#
# Exit 0 when every case is caught, 1 otherwise, 2 when called wrongly.

require "etc"
require "fileutils"
require "stringio"
require "tmpdir"
require_relative "suite"

SKILL = File.expand_path("..", __dir__)

Case = Struct.new(:desc, :file, :edit, :section, :expect, keyword_init: true)

# ------------------------------------------------------------------ edits
#
# The shell self-test spelled these as sed and awk programs. They are Ruby here, with sed's
# semantics kept where they matter: `s` replaces the first match on each line, not every match.

def sed(pattern, replacement) = ->(s) { s.lines.map { |l| l.sub(pattern) { replacement } }.join }

# Every line matching `at` gets `line` inserted before it (or after, with after: true); once: only
# the first match, and only once `armed` has matched on or before it.
def insert(at, line, after: false, once: true, armed: nil)
  lambda do |s|
    done = false
    on = armed.nil?
    s.lines.flat_map do |l|
      on ||= l.match?(armed)
      next [l] unless on && !done && l.match?(at)
      done = once
      after ? [l, "#{line}\n"] : ["#{line}\n", l]
    end.join
  end
end

# `/at/ { skip = n }`: the matching line and the n - 1 after it are dropped.
def drop_from(at, n)
  lambda do |s|
    skip = 0
    s.lines.reject do |l|
      skip = n if skip.zero? && l.match?(at)
      next false if skip.zero?
      skip -= 1
      true
    end.join
  end
end

# The block from `from` through `to` is lifted out and put back in front of the first line matching
# `before`, or after the first line matching `after_line`, that follows it.
def move_block(from, to, before: nil, after_line: nil)
  lambda do |s|
    buf = []
    inside = false
    done = false
    s.lines.flat_map do |l|
      if inside
        buf << l
        inside = false if l.match?(to)
        next []
      end
      if buf.empty? && l.match?(from)
        buf << l
        inside = !l.match?(to)
        next []
      end
      next [l] if done || buf.empty?
      if before && l.match?(before)
        done = true
        next buf + [l]
      end
      if after_line && l.match?(after_line)
        done = true
        next [l] + buf
      end
      [l]
    end.join
  end
end

T = "references/page-template.html"
SKELETON = "scripts/page-skeleton.sh"
DIFF_RENDER = "scripts/diff-render.sh"
CARRY = "scripts/carry-plan.sh"
EXCERPT = "scripts/excerpt.sh"
LINT = "scripts/page-lint.sh"
USAGE = "scripts/usage.sh"
SKILL_MD = "SKILL.md"

CASES = [
  # ---- script breaks: the partition assertion, which no template break can exercise ----

  # The regression this whole design exists to prevent: someone decides it is simpler to hold the
  # style block in the script than to extract it, and the two copies drift from that day on.
  # Appended rather than prepended: a line ahead of the head's opening <title> is refused by the
  # script's own title guard, and this case has to reach the prefix assertion to prove it.
  Case.new(desc: "the script emits a line of its own instead of only the template's bytes", file: SKELETON,
           edit: sed(/^extract "\$HEAD_S" "\$HEAD_E" "\$TEMPLATE" /,
                     '{ extract "$HEAD_S" "$HEAD_E" "$TEMPLATE"; echo "<style>.injected{color:red}</style>"; } '),
           section: :skeleton, expect: "the emitted head is an exact byte prefix of the template"),

  # Without the placeholder there is nothing for stage 1 to Edit, and nothing for the clobber
  # refusal to key on — so a re-invocation would silently wipe a published page.
  Case.new(desc: "the script writes no body placeholder for the run to replace", file: SKELETON,
           edit: sed(/^printf .%s\\n. "\$PLACEHOLDER" >> "\$tmp"$/, "true"),
           section: :skeleton, expect: "the emitted page carries one body placeholder for the run to replace"),

  # ---- template breaks: what each half must contain ----

  # A duplicated marker makes the range wrong while every other assertion still passes.
  Case.new(desc: "a marker appears twice in the template", file: T,
           edit: ->(s) { s.lines.flat_map { |l| l.include?("SKELETON:HEAD:END") ? [l, l] : [l] }.join },
           section: :skeleton, expect: "template has exactly one SKELETON:HEAD:END"),

  # The boundary slipping into the token block: the markup half would then carry colours for a model
  # to copy, which is the defect the split exists to make unreachable.
  Case.new(desc: "HEAD:END sits above the token block, leaving every colour in the markup half", file: T,
           edit: ->(s) { insert(/^<style>$/, "<!-- SKELETON:HEAD:END -->").call(s.lines.reject { |l| l.include?("SKELETON:HEAD:END") }.join) },
           section: :skeleton, expect: "the markup half carries no style block for a run to copy"),

  # ---- the page's one shape ----
  #
  # Every case below leaves a page that still renders and still looks finished, which is the whole
  # reason each needs a rule of its own rather than a reading of the template.

  # This page draws nothing. An <svg> in the half a run reads is one it will copy, and a drawing
  # derived per run spends the run's attention on geometry instead of on whether the edges are true.
  Case.new(desc: "an svg is back in the markup half", file: T,
           edit: insert(/<section class="cp" id="cp-b">/, '        <svg viewBox="0 0 10 10"></svg>', after: true),
           section: :skeleton, expect: "the markup half carries no svg — this page has no drawings"),

  # The rule that keeps the two chain figures apart. An .ip-aff node inside a checkpoint's chain is a
  # hop into unchanged code drawn in the wrong section — the same consequence drawn twice.
  Case.new(desc: "a chain inside a checkpoint carries an affected-unchanged node", file: T,
           edit: sed('class="ip-n ip-step"', 'class="ip-n ip-aff"'),
           section: :skeleton, expect: "no .ip-aff node inside the chain — that hop is an impact path"),

  # The paragraph belongs to the panel and not to a checkpoint's chain, whose own two to four
  # sentences already are it.
  Case.new(desc: "a checkpoint chain is given a paragraph of its own", file: T,
           edit: insert(/<figure class="chain">/, '          <p class="ip-why">a second explanation</p>', after: true, once: false),
           section: :skeleton, expect: "no p.ip-why inside a checkpoint chain — the checkpoint's own sentences are that"),

  # A locator on the outcome, the locator defect that looks MORE thorough than the correct markup: it
  # draws, it links somewhere real, and it puts an address on the one node that is a behaviour.
  Case.new(desc: "an outcome node is given a locator", file: T,
           edit: lambda { |s|
             done = false
             s.lines.map { |l|
               next l if done || !l.include?('<li class="ip-n ip-out">')
               done = true
               l.sub("</span></li>", '<a class="path ip-loc" href="#">app/x.rb:1</a></span></li>')
             }.join
           },
           section: :skeleton, expect: "no locator on an .ip-out node — a behaviour is not in a file"),

  # data-path is reserved to the inventory: coverage-gate.sh greps it page-wide, so a locator
  # carrying one registers as a surplus path and fails the page's one mechanical gate.
  Case.new(desc: "a locator carries the inventory's data-path attribute", file: T,
           edit: sed('class="path ip-loc" href="{{BLOB}}#L{{START}}"', 'class="path ip-loc" data-path="x" href="{{BLOB}}#L{{START}}"'),
           section: :skeleton, expect: "no data-path inside the impact panel — that attribute belongs to the inventory alone"),

  # A connector between a converge's paths. They are siblings, not a sequence, and the impact panel's
  # lane crossing hangs off `.ip-chg + .ip-aff > .ip-rel` — which a converge alternates.
  Case.new(desc: "a converge's paths are joined by a connector", file: T,
           edit: lambda { |s|
             on = done = false
             s.lines.map { |l|
               on ||= l.include?('<ol class="cv-paths">')
               next l unless on && !done && l.include?('class="ip-n ip-aff"')
               done = true
               l.sub('<span class="ip-box">', '<span class="ip-rel"><i></i>calls</span><span class="ip-box">')
             }.join
           },
           section: :skeleton, expect: "no .ip-rel inside a converge — its paths are siblings, and a connector would fire the panel's elbow"),

  # A locator on the converge's target. An invariant is a property, not a file.
  Case.new(desc: "a converge's target is given a locator", file: T,
           edit: sed('<b>{{THE_INVARIANT}}</b><span class="ip-d">must hold on every path</span>',
                     '<b>{{THE_INVARIANT}}</b><span class="ip-d">must hold on every path</span><a class="path ip-loc" href="#">app/x.rb:1</a>'),
           section: :skeleton, expect: "no locator on a converge's target — an invariant is not in a file"),

  # An unchanged node in a lifecycle. A state is not a file, so the teal kind has nothing to mean.
  Case.new(desc: "a lifecycle state is drawn as unchanged code", file: T,
           edit: sed('<li class="lc-s lc-new">', '<li class="lc-s ip-aff">'),
           section: :skeleton, expect: "no .ip-aff inside a lifecycle — a state is not a file"),

  # The search row's hanging indent, unscoped. -16px on every code in the row reaches one inside the
  # clause and drags it over the words before it.
  Case.new(desc: "the search row's indent pulls every code left, not only the leading command", file: T,
           edit: sed(/^\.searched \.sr-list code \{ min-width: 0;/, ".searched .sr-list code { min-width: 0; margin-left: -16px;"),
           section: :skeleton, expect: "and the rule that styles every code in a row does not pull any of them left"),

  # ---- links leaving the page open in a new tab ----

  # A target typed at a citation rather than applied by the tail script. Every later run copies an
  # attribute it has to remember at every citation, which is how one of them ends up without it.
  Case.new(desc: "a citation in the markup half types a target for a run to copy", file: T,
           edit: sed('<a class="path" href="{{BLOB}}#L{{LINE}}">', '<a class="path" target="_blank" href="{{BLOB}}#L{{LINE}}">'),
           section: :skeleton, expect: "no citation in the markup half types a target for a run to copy"),

  # ---- the primer callout, the only component a flag admits ----

  # The logotype returns, asserted through .pr-mark rather than through the svg count, so the row
  # goes red on the class alone — a mark smuggled in as a web font or a background image is the same
  # defect, and neither carries an opening svg tag.
  Case.new(desc: "the primer's logotype comes back, bringing the trademark obligation with it", file: T,
           edit: insert(/<span class="pr-title">/, '            <span class="pr-mark"></span>'),
           section: :skeleton, expect: "the primer carries no logotype — this page has no drawings"),

  # Position. Below the Look at list the lesson arrives after the reader has already been sent to
  # the code: they open four files without the rule that decides what they are looking at.
  Case.new(desc: "the primer is assembled below the Look at list it is meant to precede", file: T,
           edit: move_block(/<aside class="primer">/, %r{</aside>}, after_line: %r{</ul>}),
           section: :skeleton, expect: "the primer sits inside a checkpoint and above its Look at list"),

  # The header goes back to naming the component, reinstated with the separator it needs, because
  # that is how the old shape actually returns: not as one stray span, but as the pair.
  Case.new(desc: "the primer header names the component again instead of the stack", file: T,
           edit: sed('<span class="pr-title">Understanding Ruby on Rails</span>',
                     '<span class="pr-title">Rails</span><i class="pr-sep"></i><span class="lbl">Primer</span>'),
           section: :skeleton, expect: "no separator survives — there is nothing left to divide"),

  # The Rust frame forgets a slot. The top rule carries the frame's identity, so a variant that stops
  # re-pointing it renders a graphite callout under a Rails-red bar.
  Case.new(desc: "the Rust primer frame stops re-pointing one of its slots", file: T,
           edit: sed("--primer-rule-2: var(--primer-rust-rule-2);", ""),
           section: :skeleton, expect: "and it re-points all six primer slots at the graphite ramp"),

  # ---- Context, section 02 ----
  #
  # Every row here expects zero or reads an order: a misspelled pattern also counts zero, and a
  # section in the wrong place still counts one.

  # A second figure in Context, planted as a kind no other row counts, so only the count of one can
  # catch it.
  Case.new(desc: "a second figure is drawn inside Context", file: T,
           edit: insert(/<dl class="ctx">/, '      <figure class="flow"><figcaption>x</figcaption></figure>'),
           section: :skeleton, expect: "Context holds one figure at most"),

  # An unchanged node in the shift: the lifecycle defect, in the one lifecycle the checkpoint range
  # does not reach, and only the zero can notice it.
  Case.new(desc: "a state in the shift is drawn as unchanged code", file: T,
           edit: sed('<li class="lc-s lc-new"><span class="ip-rel"><i></i>{{REQUEST}}', '<li class="lc-s ip-aff"><span class="ip-rel"><i></i>{{REQUEST}}'),
           section: :skeleton, expect: "no .ip-aff inside the shift — a state is not a file"),

  # A tier in Context. An entry says what a thing is, not what the change did.
  Case.new(desc: "an evidence tier is put on a Context entry", file: T,
           edit: sed("{{WHAT_IT_IS}}", '{{WHAT_IT_IS}} <span class="tier tier-unc">from unchanged code</span>'),
           section: :skeleton, expect: "no evidence tier inside Context — an entry asserts nothing about the change"),

  # The foot given a number. It replaces a sub-entry rather than adding one, so the rail's total
  # cannot be what goes red.
  Case.new(desc: "the evidence foot gets a sixth rail number", file: T,
           edit: sed(/<a class="sub" data-rail="cp-x" href="#cp-x">.*/, '<a data-rail="evidence" href="#evidence"><span class="n">06</span>Evidence</a>'),
           section: :skeleton, expect: "and stops there — the evidence foot has no number"),

  # Context after the agenda. Every entry is still there and still points at its checkpoint, so only
  # the order assertion can notice.
  Case.new(desc: "Context is assembled after the agenda", file: T,
           edit: move_block(/^ *<section id="context">/, %r{^ *</section>}, before: /^ *<section id="start"/),
           section: :skeleton, expect: "Context comes before the agenda"),

  # ---- diff-render.sh: every break here publishes a link that lands on nothing ----

  # The signal no size rule can replace. One changed line in a linguist-generated file is a small
  # diff by every measurement there is, and GitHub collapses it anyway.
  Case.new(desc: "the script stops asking .gitattributes, so a generated file reads as renderable", file: DIFF_RENDER,
           edit: sed(/^  if _why=\$\(attr_says "\$_path"\); then/, "  if false; then"),
           section: :diff_render, expect: "linguist-generated collapses on one changed line, where no size rule would fire"),

  # Reading GitHub's limits and keeping only the memorable pair. The hard cap is the number that
  # sounds like the limit; 400 lines is the one that decides almost every real citation.
  Case.new(desc: "only the 20,000-line hard cap is enforced, not the 400-line auto-load threshold", file: DIFF_RENDER,
           edit: sed(/^AUTOLOAD_LINES=400$/, "AUTOLOAD_LINES=20000"),
           section: :diff_render, expect: "a diff past 400 lines is behind Load diff, whatever the file is"),

  # The other direction: answering "collapse" for a path the diff never touched pushes every
  # *affected but unchanged* citation off the blob form it requires.
  Case.new(desc: "a path outside the diff is reported as collapsed", file: DIFF_RENDER,
           edit: sed("printf 'render\\tnot-in-diff", "printf 'collapse\\tnot-in-diff"),
           section: :diff_render, expect: "a path the diff never touched is not reported as collapsed"),

  # The guard whose absence is a silent clean bill of health: with the refs unresolved, every git
  # call still feeds a pipeline that exits 0 and prints nothing. The whole loop goes, all six lines:
  # the shell row dropped three and left a `fi` and a `done` behind, so the script died on a syntax
  # error and the row was caught by every assertion at once rather than by this one.
  Case.new(desc: "the ref guard is gone, so an unresolvable base reads as a diff with nothing withheld", file: DIFF_RENDER,
           edit: drop_from(/^for ref in "\$BASE" "\$HEAD_REF"; do$/, 6),
           section: :diff_render, expect: "an unresolvable BASE exits 4 rather than reporting an empty diff"),

  # Counting the changed lines instead of the diff GitHub renders. It agrees with the correct measure
  # on every file whose changes are contiguous, and disagrees exactly where the context is.
  Case.new(desc: "the changed lines are counted instead of the diff GitHub renders", file: DIFF_RENDER,
           edit: sed(/^    _lines=\$\(printf .*/, "    _lines=$((_add + _del))"),
           section: :diff_render, expect: "context pushes a diff past 400 rendered lines though its changed lines are far fewer"),

  # ---- carry-plan.sh: every way a carried claim goes quietly false ----

  # The polarity. A skip needs EVERY precondition to hold; flipping the delta-size rule inverts the
  # one number standing between a cheap update and a page most of which nobody re-read.
  Case.new(desc: "the delta-size rule never fires, so a rewrite of the branch updates in place", file: CARRY,
           edit: sed('if [ "$N_FULL" -eq 0 ] || [ $((N_DELTA * 2)) -gt "$N_FULL" ]; then', "if [ $((N_DELTA * 2)) -lt 0 ]; then"),
           section: :carry_plan, expect: "a delta covering more than half the diff refuses"),

  # P6, the rule that protects the product. With the intersection stubbed out the script still runs
  # every search and still reports them safe.
  Case.new(desc: "a delta path among a recorded search's hits no longer refuses", file: CARRY,
           edit: sed(/^  landed=\$\(comm -12 "\$TMP\/delta" "\$TMP\/hitpaths" \| head -n 1\)$/, "  landed="),
           section: :carry_plan, expect: "a delta path among a recorded search's hits refuses the update"),

  # The merge-base exemption. Without it a base-side `git grep … <sha>` reads as a shape the hit
  # test cannot parse, and every page carrying an architectural checkpoint updates in full.
  Case.new(desc: "a recorded search of the merge-base is read for its shape again", file: CARRY,
           edit: sed(/^      if \[ "\$rev" = "\$MB" \]; then at_mb=1; else other=1; fi$/, "      other=1"),
           section: :carry_plan, expect: "a recorded search of the merge-base does not refuse the update"),

  # The exemption's other half. Counting only the merge-base among the trees named lets a search
  # of it and HEAD together skip the replay, and HEAD is exactly what these commits changed.
  Case.new(desc: "a search naming the merge-base beside another tree is exempt too", file: CARRY,
           edit: sed(/^      if \[ "\$rev" = "\$MB" \]; then at_mb=1; else other=1; fi$/, %(      [ "$rev" = "$MB" ] && at_mb=1)),
           section: :carry_plan, expect: "a recorded search of the merge-base and HEAD together still refuses"),

  # The reason -v is not used. awk's -v processes escape sequences in the value, so a recorded
  # `\bProjects::Archive\b` arrives with two backspaces where its word boundaries were.
  Case.new(desc: "the recorded pattern reaches awk through -v, which eats its backslash escapes", file: CARRY,
           edit: ->(s) { sed(/^      s = ENVIRON\["CARRY_CMD"\]$/, "").call(sed("  CARRY_CMD=$1 awk '", %(  awk -v s="$1" ')).call(s)) },
           section: :carry_plan, expect: "a pattern's backslash escapes reach the tool intact"),

  # An unreplayable search is not a search that found nothing.
  Case.new(desc: "a search that cannot be replayed is skipped instead of refusing the update", file: CARRY,
           edit: sed(/^    UNSAFE=\$cmd$/, "    continue"),
           section: :carry_plan, expect: "a shell metacharacter outside quotes refuses the whole update"),

  # The replay without -l. Every plain search still answers, but a recorded context window prints
  # lines the parse cannot read, so a page carrying one refuses every update.
  Case.new(desc: "the replay keeps the recorded window instead of asking only which files it hits", file: CARRY,
           edit: sed(/^  if \[ "\$first" = git \]; then .*$/, %(  set -- "$first" "$@")),
           section: :carry_plan, expect: "a recorded search with a context window is replayed rather than refused"),

  # The substring trap. Without the token boundaries api/Gemfile matches inside api/Gemfile.lock.
  # A linked phrase keeps its file in the href, so a carry rule reading only visible text carries a
  # checkpoint that turns on the changed file — once per href form.
  Case.new(desc: "a linked phrase's blob href is not read as a path", file: CARRY,
           edit: sed(%q<  body=$(printf '%s' "$1" | sed 's#/blob/[0-9a-f]\{7,40\}/# #g')>, '  body=$1'),
           section: :carry_plan, expect: "a linked phrase whose blob href names a delta path is re-derived"),
  Case.new(desc: "a linked phrase's diff href is not hashed against the delta", file: CARRY,
           edit: sed('grep -qF "#diff-$h"', 'grep -qF "#diff-x$h"'),
           section: :carry_plan, expect: "and so is one whose diff href hashes to it"),

  Case.new(desc: "the path test is a substring match rather than a whole token", file: CARRY,
           # A boundary of any character, not none: `(^|)` is an empty subexpression some greps refuse,
           # and a refused pattern matches nothing, which would leave the row green for the wrong reason.
           edit: sed(%r{^BOUND='\[\^A-Za-z0-9\._/-\]'$}, "BOUND='.'"),
           section: :carry_plan, expect: "api/Gemfile in the delta does not match api/Gemfile.lock on the page"),

  # A Context entry is outside every checkpoint, so the cp rule never reaches it.
  Case.new(desc: "a Context entry citing a delta path is carried", file: CARRY,
           edit: sed(/^  plan_row ctx "\$name"$/, '  reason=-; plan_row ctx "$name"'),
           section: :carry_plan, expect: "a Context entry citing a delta path is re-derived, though the checkpoint using it carries"),

  # The figure's citations stay in the buffer, so the entry above it inherits them.
  Case.new(desc: "the before-and-after figure's citations leak into the last Context entry", file: CARRY,
           edit: sed(/^      buf = substr\(buf, 1, RSTART - 1\) " " substr\(buf, RSTART \+ RLENGTH\)$/, ""),
           section: :carry_plan, expect: "a Context entry citing nothing in the delta is carried, named by its unescaped dt"),

  # P1. A rebased branch's "delta" is a diff between two histories rather than the commits someone
  # pushed.
  Case.new(desc: "the ancestry guard is gone, so a force-pushed branch updates in place", file: CARRY,
           edit: drop_from(/^if ! git merge-base --is-ancestor/, 3),
           section: :carry_plan, expect: "and says the branch moved rather than reporting an empty delta"),

  # P3. Pending is a promise; carrying one promises work that nothing is doing.
  Case.new(desc: "a draft page is accepted as a base to update from", file: CARRY,
           edit: sed(/^if grep -q .class="buildstate". "\$PAGE" .*$/, "if false; then"),
           section: :carry_plan, expect: "a page still carrying a build banner is a draft, not a base to update"),

  # The excerpt rule. Keeping it is the one way this page lies about bytes while the bytes are real.
  Case.new(desc: "an excerpt whose file moved in the delta is carried rather than regenerated", file: CARRY,
           edit: sed(%(    printf 'excerpt\\t%s\\tregen\\n' "$p"), %(    printf 'excerpt\\t%s\\tkeep\\n' "$p")),
           section: :carry_plan, expect: "an excerpt whose file moved in the delta is regenerated"),

  # A refusal that prints its plan rows anyway. Half a plan reads as a plan. `|| :` because the
  # delta does not exist yet at P1, and under `set -e` a failing sed changed every refusal's exit
  # status — which is what the shell row was caught by, while the leak itself went unasserted.
  Case.new(desc: "a refusal prints plan rows alongside its verdict", file: CARRY,
           edit: sed(/^  echo "verdict: full"$/, %(  sed "s/^/delta\\t/" "$TMP/delta" 2>/dev/null || :; echo "verdict: full")),
           section: :carry_plan, expect: "a refusal after the delta is known prints no plan rows either"),

  # ---- themes: three files, one marker, and a lookup in the repository's config ----

  # A colour dropped from one dark block of one non-default theme. Every page still renders — in
  # light — and counting names would still find it twice, so this proves the per-selector rule looked.
  Case.new(desc: "a theme declares a colour on :root and in only one dark block", file: "references/themes/workshop.html",
           edit: lambda { |s|
             d = false
             s.lines.reject { |l|
               d = true if l.match?(/^:root\[data-theme="dark"\] \{$/)
               next false unless d && l.start_with?("  --syn-key:")
               d = false
               true
             }.join
           },
           section: :skeleton, expect: "theme workshop declares every colour on bare :root and in both dark blocks"),

  # The script stops reading the repository's config. Every page is still a correct Daylight page,
  # which is exactly why it needs a row: the team's choice is ignored and nothing looks wrong.
  Case.new(desc: "the script ignores review_map.theme in the repository's config", file: SKELETON,
           edit: sed(/^    THEME=\$\{CFG_theme:-\}$/, "    THEME="),
           section: :skeleton, expect: "review_map.theme in the repository's config picks the theme"),

  # A config file the parser refuses is shrugged off. The page comes out in Daylight, CI then fails
  # on the same file, and the team learns about its typo from a red run.
  Case.new(desc: "a config file read-config.sh refuses is ignored rather than refused", file: SKELETON,
           edit: sed(/\(see above\)" >&2; exit 2; \}$/, '(see above)" >&2; cfg=; }'),
           section: :skeleton, expect: "an unknown key in the repository's config is refused, not ignored"),

  # An unknown theme falls back to the default instead of refusing. A typo then reads as a team that
  # never chose, and nobody is told.
  Case.new(desc: "a theme name with no file behind it quietly becomes daylight", file: SKELETON,
           edit: sed('[ -n "$THEME" ] || { THEME=daylight; SOURCE=default; }', '[ -r "$THEMES/$THEME.html" ] || { THEME=daylight; SOURCE=default; }'),
           section: :skeleton, expect: "a theme name from the environment with no file behind it is refused, not defaulted"),

  # The menu typed into the masthead instead of built by the script. It renders exactly the same,
  # which is why the assertion expects zero.
  Case.new(desc: "the appearance menu is typed into the markup half", file: T,
           edit: lambda { |s|
             lines = s.lines
             i = lines.index { |l| l.match?(/<header style=/) }
             lines.insert(i + 2, %(        <div class="rc"><button class="rc-btn">Aa</button></div>\n))
             lines.join
           },
           section: :skeleton, expect: "the markup half carries none of the menu for a run to copy"),

  # A storage call outside a try. In a private window it throws, and an exception in the tail script
  # stops the rail, the tint and the link pass along with the menu.
  Case.new(desc: "a localStorage call sits outside a try", file: T,
           edit: insert(%r{^  /\* ---- The appearance menu ----}, "  localStorage.getItem('review-style');"),
           section: :skeleton, expect: "every storage call is inside a try"),

  # Only the chosen theme reaches the page. Every page still looks right — in the repository's theme
  # — and the menu offers nothing, which is the failure nobody would notice.
  Case.new(desc: "only the chosen theme is emitted, so the menu has nothing to switch to", file: SKELETON,
           edit: sed(/^  if \[ "\$name" = "\$THEME" \]; then$/, '  [ "$name" = "$THEME" ] || continue; if true; then'),
           section: :skeleton, expect: "and all but one arrive switched off"),

  # A figure in the explanation keeps the caption it carried as evidence, so the sentence before it
  # and the line under it say one thing twice, in the middle of the argument.
  Case.new(desc: "a figure in a checkpoint's explanation carries a figcaption", file: T,
           edit: insert(%r{^        </figure>}, "          <figcaption>x</figcaption>", armed: /<figure class="chain">/),
           section: :skeleton, expect: "checkpoint A's explanation sets its figure like prose, with no figcaption"),

  # ---- one citation per Look at entry ----

  # An entry keeps its own a.path beside the excerpt whose summary is the link.
  Case.new(desc: "a Look at entry keeps an a.path beside its excerpt", file: T,
           edit: insert(/<details class="excerpt excerpt--diff">/,
                        '            <a class="path" href="{{DIFF}}R{{START}}-R{{END}}">{{PATH}}:{{START}}-{{END}}</a>',
                        armed: /<ul class="lookat">/),
           section: :skeleton, expect: "and neither keeps an a.path beside the excerpt's linked summary"),

  # The excerpt in an entry repeats the entry's clause as a summary why.
  Case.new(desc: "a Look at entry's excerpt repeats the clause as a why", file: T,
           edit: insert(%r{<span class="tag">Unchanged</span>}, '                <span class="ex-why">{{WHY_THIS_MATTERS}}</span>',
                        after: true, armed: /<ul class="lookat">/),
           section: :skeleton, expect: "and neither excerpt repeats the entry's clause as a summary why"),

  # --in-entry is parsed and then ignored, so every excerpt says its why twice inside an entry.
  Case.new(desc: "excerpt.sh ignores --in-entry", file: EXCERPT,
           edit: sed("--in-entry) IN_ENTRY=1; shift ;;", "--in-entry) shift ;;"),
           section: :excerpt, expect: "--in-entry with --why is refused rather than choosing one"),

  # The body-foot citation comes back under the code, the third copy of the address.
  Case.new(desc: "excerpt.sh writes a second citation under the code", file: EXCERPT,
           edit: ->(s) { s.lines.map { |l| l.match?(%r{^  printf .</pre>\\n.$}) ? l.chomp + %(; printf "<p class=\\"ex-src\\">x</p>\\n"\n) : l }.join },
           section: :excerpt, expect: "and repeats it nowhere under the code"),

  # The link falls off the summary — the closed excerpt is then a citation nobody can click.
  Case.new(desc: "excerpt.sh --at leaves the summary's location unlinked", file: EXCERPT,
           edit: sed(/^  if \[ -n "\$LINK" \]; then$/, "  if false; then"),
           section: :excerpt, expect: "--at with a link puts it on the summary's location, with the range it read"),

  # --inline is parsed and then ignored, so the snippet the explanation shows ships as a shut
  # disclosure with a why placeholder in it, in the middle of the prose.
  Case.new(desc: "excerpt.sh ignores --inline", file: EXCERPT,
           edit: sed("--inline) INLINE=1; shift ;;", "--inline) shift ;;"),
           section: :excerpt, expect: "--inline --diff emits the open snippet, not a disclosure"),

  # ---- page-lint.sh: each break one rule switched off ----
  #
  # A lint whose rule never fires passes every page, which is the check that always passes in a new
  # costume.

  # The tier is never seen, so every cited unchanged file reads as unlabelled — the clean page goes
  # red, which is the only way to prove the clean assertion looked for a label.
  Case.new(desc: "page-lint.sh stops seeing tier labels", file: LINT,
           edit: sed('  tier = index(s, "class=\\"tier") > 0', "  tier = 0"),
           section: :page_lint, expect: "a page whose labels agree with its ledger draws no WARN"),

  # The href is ignored, so a short citation under a blob permalink is matched on its text.
  Case.new(desc: "page-lint.sh stops resolving a citation to the changed set", file: LINT,
           edit: sed("  if (path in changed) return 1", "  return 0"),
           section: :page_lint, expect: "a citation's path is read from its href, a diff href is changed, plain text matches on its suffix"),

  # The linked phrase is no longer a citation, so a claim woven into the prose resting on a file
  # outside the diff carries no tier and nothing notices.
  Case.new(desc: "page-lint.sh stops reading a linked phrase as a citation", file: LINT,
           edit: sed('    pr = match(rest, /<a class="ref"[^>]*>/) ? RSTART : 0; lr = RLENGTH', "    pr = 0"),
           section: :page_lint, expect: "a linked phrase is a citation read from its href: one outside the diff with no tier is unlabelled"),

  # Only a pull request's diff anchor counts as changed, so on a branch with no pull request every
  # linked phrase into the diff is unplaceable and its tier goes unchecked.
  Case.new(desc: "page-lint.sh reads only /files#diff- as a diff anchor", file: LINT,
           edit: sed("  if (attrs ~ /#diff-[0-9a-f]/) return 1", '  if (index(attrs, "/files#diff-")) return 1'),
           section: :page_lint, expect: "a linked phrase into a compare range's diff is changed code, so the unchanged label on it is on-changed"),

  # An inline snippet's caption is read as a sentence, so every snippet quoting unchanged code in an
  # explanation draws an unlabelled WARN, and a run learns to stop using the form.
  Case.new(desc: "page-lint.sh reads an inline snippet's caption as a sentence", file: LINT,
           edit: sed("(note|buildstate|ex-cap)", "(note|buildstate)"),
           section: :page_lint, expect: "an inline snippet's caption is not a sentence, and the prose around it still is"),

  # The on-changed shape is dropped, so a label on changed code passes.
  Case.new(desc: "page-lint.sh stops warning on from-unchanged-code over changed files", file: LINT,
           edit: sed("  if (unc && inside && !outside) {", "  if (0) {"),
           section: :page_lint, expect: "and it is the on-changed shape"),

  # The excerpt summary is no longer a citation, so every entry cited through an excerpt reads as
  # uncited — the shape that sent runs editing against a warning nothing earned.
  Case.new(desc: "page-lint.sh stops reading an excerpt summary as the entry's citation", file: LINT,
           edit: sed('    pe = index(rest, "<span class=\\"ex-loc\\">")', "    pe = 0"),
           section: :page_lint, expect: "an excerpt summary is the entry's citation, linked or plain"),

  # Placeholders are not a FAIL any more.
  Case.new(desc: "page-lint.sh lets a placeholder ship", file: LINT,
           edit: sed("  status=1", "  status=0"),
           section: :page_lint, expect: "and the exit code says so"),

  # ---- usage.sh: each break a count that would read plausibly and be wrong ----

  # The mark is not subtracted, so the session's tokens before the run are billed to it.
  Case.new(desc: "usage.sh stops subtracting the mark", file: USAGE,
           edit: sed('    inp = b["in"] - a["in"]; cached = b["cached"] - a["cached"]; out = b["out"] - a["out"]',
                     '    inp = b["in"]; cached = b["cached"]; out = b["out"]'),
           section: :usage, expect: "report subtracts the mark, adds the falsifier, and leaves another thread's and an earlier subagent's logs out"),

  # Any thread begun since the mark counts as a falsifier, another session's included.
  Case.new(desc: "usage.sh counts threads that are not this run's", file: USAGE,
           edit: sed(%(    if head -n 1 "$f" | grep -q "\\"parent_thread_id\\":\\"$tid\\""; then), "    if :; then"),
           section: :usage, expect: "report subtracts the mark, adds the falsifier, and leaves another thread's and an earlier subagent's logs out"),

  # A subagent that existed at the mark counts too: an earlier task's, still writing.
  Case.new(desc: "usage.sh counts a subagent begun before the mark", file: USAGE,
           edit: sed('  grep -qxF "$f" "$W/usage.before" && continue', "  :"),
           section: :usage, expect: "report subtracts the mark, adds the falsifier, and leaves another thread's and an earlier subagent's logs out"),

  # A reverted thread is subtracted across two logs instead of refused.
  Case.new(desc: "usage.sh subtracts a mark from a reverted thread's new log", file: USAGE,
           edit: sed(/^#{Regexp.escape(%([ "$(sed -n 's/^rollout=//p' "$start")" = "$rollout" ] ||))}/, ": ||"),
           section: :usage, expect: "a thread reverted since the mark is refused rather than subtracted across two logs"),

  # A window that reset is reported as a share — a delta across two different windows.
  Case.new(desc: "usage.sh reports a share across a window reset", file: USAGE,
           edit: sed('a[w "_reset"] == b[w "_reset"] && ', ""),
           section: :usage, expect: "a window that reset is reported where it stands, never as a share"),

  # ---- the voice comparison in SKILL.md step 10: each break a snippet the shell no longer counts ----

  # The page side stops on the review question's first line, so a question that wraps loses its
  # second line there and a page that landed its draft whole reports a change it never made.
  Case.new(desc: "the voice comparison cuts the review question at its first line", file: SKILL_MD,
           edit: sed(%(on && (q && /<\\/p>/ || /<\\/section>/) {print; exit} on'), %(on && /class="open"|<\\/section>/ {print; exit} on')),
           section: :voice, expect: "a page that landed its draft whole draws no voice line, though its question wraps and its evidence cites"),

  # The inline snippet's caption link is not collected, so a revision that moves it out lands unflagged.
  Case.new(desc: "the voice comparison stops collecting the inline snippet's citation", file: SKILL_MD,
           edit: sed("(ref|cite|path ip-loc)", "(ref|path ip-loc)"),
           section: :voice, expect: "a revision that drops the inline snippet draws a voice line")
].freeze

# ------------------------------------------------------------------ running

def run_suite(skill, sections)
  Dir.mktmpdir("review-map-self") { |tmp| ReviewMapSuite.new(skill, tmp, out: StringIO.new).run_sections(sections) }
end

# One case against one copy: break, run the section it names, put the file back. Returns
# [verdict, message, red labels].
def run_case(skill, c)
  target = File.join(skill, c.file)
  original = File.read(target)
  broken = begin
    c.edit.call(original)
  rescue StandardError => e
    return [:bad, "the break itself failed to apply: #{c.desc} (#{e.message})", []]
  end
  # A break that changed nothing would make the suite pass for the right reason and be reported as
  # decorative; worse, a break that corrupted the file would make it fail for the wrong one. The
  # first is caught here, the second by naming the assertion that has to go red.
  return [:bad, "the break changed nothing: #{c.desc}", []] if broken == original

  begin
    File.write(target, broken)
    red = run_suite(skill, [c.section]).failures.map(&:label)
  ensure
    File.write(target, original)
  end
  if red.include?(c.expect)
    [:ok, "ok    #{c.section} fails when: #{c.desc}", red]
  elsif red.empty?
    [:bad, "bad   the suite still passed with: #{c.desc}", red]
  else
    [:bad, "bad   `#{c.expect}` stayed green with: #{c.desc} (red instead: #{red.join(" | ")})", red]
  end
end

discover = ARGV.delete("--discover")
jobs = [Etc.nprocessors, 8].min
if (i = ARGV.index("-j"))
  jobs = Integer(ARGV[i + 1], exception: false) or abort("self-test.rb: -j needs a number")
  ARGV.slice!(i, 2)
end
picked = ARGV.map { |a| Integer(a, exception: false) or (warn "self-test.rb: not a case number: #{a}"; exit 2) }
cases = picked.empty? ? CASES.each_with_index.to_a : picked.map { |n| [CASES.fetch(n - 1), n - 1] }

unknown = CASES.map(&:section).uniq - ReviewMapSuite::SECTIONS.keys
abort "self-test.rb: unknown section #{unknown.join(", ")}" unless unknown.empty?

Dir.mktmpdir("review-map-self-test") do |scratch|
  # The sanity row: every section, on a clean copy, must pass. Without it a section that fails for
  # its own reasons makes every break aimed at it look caught.
  clean = File.join(scratch, "clean")
  FileUtils.cp_r(SKILL, clean, preserve: true)
  red = run_suite(clean, ReviewMapSuite::SECTIONS.keys).failures.map(&:label)
  unless red.empty?
    puts "bad   the unbroken copy already fails: #{red.join(" | ")}"
    puts "", "self-test: 0 ok, 1 bad (nothing below the sanity row can be trusted)"
    exit 1
  end
  puts "ok    the unbroken copy passes every section"

  # Workers, each with its own copy, each taking every jobs-th case. A case restores its file before
  # the next one starts, so a copy is only ever broken in one place at a time.
  slices = cases.group_by.with_index { |_, k| k % jobs }.values
  readers = slices.each_with_index.map do |slice, w|
    reader, writer = IO.pipe
    copy = w.zero? ? clean : File.join(scratch, "copy-#{w}").tap { |d| FileUtils.cp_r(SKILL, d, preserve: true) }
    pid = fork do
      reader.close
      results = slice.map { |c, n| [n, run_case(copy, c)] }
      Marshal.dump(results, writer)
      writer.close
      exit!(0)
    end
    writer.close
    [pid, reader]
  end
  results = readers.flat_map do |pid, reader|
    data = reader.read
    Process.wait(pid)
    data.empty? ? [] : Marshal.load(data) # rubocop:disable Security/MarshalLoad
  end.sort_by(&:first)

  missing = cases.map(&:last) - results.map(&:first)
  bad = missing.size
  missing.each { |n| puts "bad   case #{n + 1} never reported: #{CASES[n].desc}" }
  results.each do |n, (verdict, message, red_labels)|
    bad += 1 if verdict == :bad
    puts "#{format("%2d", n + 1)} #{message}"
    red_labels.each { |l| puts "        red: #{l}" } if discover
  end

  puts "", "self-test: #{results.size - results.count { |_, (v, _, _)| v == :bad } + 1} ok, #{bad} bad"
  exit(bad.zero? ? 0 : 1)
end
