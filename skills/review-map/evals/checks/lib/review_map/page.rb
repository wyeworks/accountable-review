# frozen_string_literal: true

# page.rb — the vocabulary the check scripts' awk programs used to be.
#
# A published page is HTML, and this does not parse it: the matching is still
# line-oriented and still by regular expression, exactly as `grep` and `awk`
# did it. What moves is WHERE that happens. The three region extractions in
# behaviour-flows.sh were three hand-rolled awk state machines with their own
# flag variables, and their subtleties were explained in comments above them
# because an awk flag cannot say what it is for. Here they are one scanner
# called three ways, with the subtlety as an argument name — and, for the
# first time, something a unit test can hand a string to.
#
# Line-oriented is not an implementation detail to be improved away. Two rules
# depend on it and would change meaning under a real parser: `count` counts
# MATCHING LINES, because `grep -c` does and the field census compares two of
# its results; and a region includes the line that closes it, because awk's
# print rule fired before its close rule did.

require "open3"

module ReviewMap
  # The entity decode two checks need before matching. Applied in order, like the sed it
  # replaces, which means &amp;lt; decodes twice — a quirk kept because the shell had it and a
  # recorded search or a doc link is compared against what the shell produced.
  ENTITIES = [["&amp;", "&"], ["&lt;", "<"], ["&gt;", ">"], ["&quot;", '"'], ["&#39;", "'"]].freeze

  # Every subprocess this directory runs, with its output forced to UTF-8.
  #
  # Open3 tags what it captures with the LOCALE's default external encoding, and these
  # containers run without a UTF-8 one — so a check's own em dashes come back as invalid
  # US-ASCII and the first `split` or `include?` against them raises. That is the same trap
  # Page.read declares its encoding for, one layer out: the bytes are fine, the label is wrong.
  # One place, because four callers capture subprocesses and each would have to remember.
  def self.capture(*command, **opts)
    out, err, status = Open3.capture3(*command, **opts)
    [out.force_encoding("UTF-8"), err.force_encoding("UTF-8"), status]
  end

  def self.unescape(text)
    ENTITIES.reduce(text) { |acc, (entity, char)| acc.gsub(entity, char) }
  end

  # A page, a fragment, or one region of either. Every query is a whole-region
  # question, so a region is just a smaller Page and the checks never have to
  # care which they were handed.
  class Page
    attr_reader :lines

    # UTF-8 explicitly, never the locale's default. A published page carries em dashes and
    # section signs, and this repository's containers run without a UTF-8 locale — where the
    # default would be US-ASCII and every match against such a line would raise. `grep` is
    # byte-oriented and never had to care; this is the one place the port pays for that.
    def self.read(path)
      new(File.readlines(path, encoding: "UTF-8"))
    end

    def initialize(lines)
      @lines = lines
    end

    def empty?
      @lines.empty?
    end

    # `grep -q` for a Regexp, `grep -Fq` for a String. The shell used both and the
    # distinction is load-bearing: the build-state banner is matched as a fixed sentence,
    # and a String silently promoted to a pattern is how a literal `.` or `?` in a future
    # sentence would start matching things it does not say.
    def has?(pattern)
      if pattern.is_a?(String)
        @lines.any? { |l| l.include?(pattern) }
      else
        @lines.any? { |l| matchable(l).match?(pattern) }
      end
    end

    # `grep -c`: matching LINES, not matches. Two lines of the field census are
    # compared against each other, so counting occurrences here would silently
    # change what a "field row" is.
    def count(pattern)
      @lines.count { |l| matchable(l).match?(pattern) }
    end

    # `grep -o`, flattened: every match in the region, in document order — the WHOLE match,
    # never a capture group, because that is what grep -o prints and these results go straight
    # into FAIL messages.
    #
    # String#scan returns groups when the pattern has any, which silently truncates a message
    # to its first alternation branch: page-invariants' assurance rule reported "independently"
    # where the shell reported "independently verified". It cost one wrong message and would
    # have cost one per future pattern, so the fix belongs here rather than in a rule that
    # remembers to write (?:...).
    def scan(pattern)
      @lines.flat_map { |l| matchable(l).to_enum(:scan, pattern).map { Regexp.last_match(0) } }
    end

    # `awk '/from/,/to/'`: inclusive line ranges, re-openable.
    def range(from:, to:)
      out = []
      inside = false
      @lines.each do |line|
        inside = true if !inside && matchable(line).match?(from)
        next unless inside

        out << line
        inside = false if matchable(line).match?(to)
      end
      Page.new(out)
    end

    # The one region scanner, in the order the awk rules fired.
    #
    #   1. a line matching `open` starts a region — and re-starts it, so a
    #      second `.mech` before the first one closed is a second unit rather
    #      than more of the first
    #   2. `arm`, if given, is what has to be seen INSIDE a region before
    #      `close` counts. This is the `ingrid` flag: a unit ends at the </dl>
    #      that closes its OWN grid, so a .mech whose grid never opens must not
    #      end at the next flow's </dl> and swallow everything between
    #   3. every line from `open` onward belongs to the region
    #   4. `close` ends it, and `hard_close` ends it armed or not
    #
    # 3 sits after 2 and before 4 on purpose: a region opened and closed on one
    # line is that line, and the closing line is always included.
    def regions(open:, close:, arm: nil, hard_close: nil)
      found = []
      current = nil
      armed = false

      @lines.each do |raw|
        line = matchable(raw)
        if line.match?(open)
          found << current if current
          current = []
          armed = arm.nil?
        end
        next unless current

        armed = true if arm && line.match?(arm)
        current << raw

        if (armed && line.match?(close)) || (hard_close && line.match?(hard_close))
          found << current
          current = nil
          armed = false
        end
      end

      found << current if current
      found.map { |ls| Page.new(ls) }
    end

    # The regions concatenated back into one document, which is what an awk
    # extractor writing to a single file produced.
    def narrow(**kwargs)
      Page.new(regions(**kwargs).flat_map(&:lines))
    end

    # Every HTML comment removed, line structure preserved.
    #
    # A comment is not markup, and no check may let one steer it. The case that forced it: a
    # golden documents its own anchors in a header comment ("id=\"blast\" on the <section> ... is
    # what before-approving.sh reads"), and the section-4 region ended on the sentence DESCRIBING
    # the anchor, reporting the fixture as having no blast panel at all. Real pages are exposed
    # the same way, because a published page carries page-template.html's header comments
    # verbatim and those comments discuss the very class and id names the checks match on.
    #
    # The open state carries ACROSS lines, which is why this is a scan rather than a gsub: a
    # `<!--` on one line and its `-->` three lines later must blank all three.
    def without_comments
      inside = false
      kept = @lines.map do |raw|
        rest = matchable(raw)
        out = +""
        loop do
          if inside
            close = rest.index("-->")
            break if close.nil?

            inside = false
            rest = rest[(close + 3)..]
            next
          end
          open = rest.index("<!--")
          if open.nil?
            out << rest
            break
          end
          out << rest[0...open]
          rest = rest[(open + 4)..]
          inside = true
        end
        "#{out}\n"
      end
      Page.new(kept)
    end

    # The inverse of `narrow`: everything EXCEPT the regions between `open` and `close`.
    # awk's `/open/{f=1} f&&/close/{f=0; next} !f`, which is how a callout is dropped before a
    # census runs over what is left. The closing line goes with the region, not the remainder.
    def without(open:, close:)
      inside = false
      Page.new(@lines.reject do |raw|
        line = matchable(raw)
        inside = true if line.match?(open)
        was_inside = inside
        inside = false if inside && line.match?(close)
        was_inside
      end)
    end

    # One region, from the first line matching `anchor` to just before `stop` — awk's
    # `/anchor/{f=1} f&&/stop/{exit} f{print}`, which is how every section in the page is
    # extracted. With no `stop` it runs to the end of the input (`awk '/anchor/,0'`).
    #
    # `stop` may be a Regexp or anything answering `call`, because two of the checks need a
    # compound terminator: a section ends at the next `<section ` line that is not its own
    # anchor, which no single pattern expresses.
    #
    # `stop_after` is awk's `seen` guard, and it is a real variant rather than a knob. By
    # default the stop rule can fire on the anchor line itself, because awk's rules run in
    # order and the print comes last. Section 6's author-question region cannot afford that:
    # its anchor line is often an <h3> and <h3> is also its terminator, so the region would
    # come back empty. Passing 1 makes the stop wait until something has been emitted.
    def from(anchor, stop: nil, stop_after: 0)
      out = []
      inside = false
      @lines.each do |raw|
        line = matchable(raw)
        inside = true if !inside && line.match?(anchor)
        next unless inside
        break if stop && out.size >= stop_after && stops?(stop, line)

        out << raw
      end
      Page.new(out)
    end

    # The section-region shape both § 3 and § 4 use: from this anchor to the next section
    # that is not it.
    def section_from(anchor)
      from(anchor, stop: ->(line) { line.match?(/<section /) && !line.match?(anchor) })
    end

    private

    # grep strips the line terminator before matching, and a page's patterns lean on
    # negated classes — `<dt>[^<]*`, `<h[234][^>]*>`. In Ruby those classes match a
    # newline, so an unterminated tag at end of line would pull the next line into the
    # match and no golden fragment would show it: matching the chomped line is what keeps
    # the whole primitive line-oriented rather than nearly so. The stored lines keep their
    # terminator, because a region is text and gets printed and joined as such.
    def matchable(line)
      line.chomp
    end

    def stops?(stop, line)
      stop.respond_to?(:call) ? stop.call(line) : line.match?(stop)
    end
  end
end
