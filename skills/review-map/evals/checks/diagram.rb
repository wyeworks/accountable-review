#!/usr/bin/env ruby
# frozen_string_literal: true

# diagram.rb — every diagram on a page or in a fragment, checked against the design
# system it is supposed to be drawn in.
#
# Diagrams are hand-authored inline SVG, which means they are the one component with no
# generator behind it and no browser to complain. Five things go wrong silently:
#
#   an invented class      styled by nothing, so it renders as an unstyled shape
#   a literal colour       correct in one theme, invisible in the other
#   a surviving {{...}}    a placeholder shipped as content
#   a coordinate off-canvas  a node the reader never sees, in a figure that looks fine
#   a label wider than its box  the most common defect in hand-authored SVG
#
# All five are mechanical. What is not: whether the diagram shows a mechanism a table
# could not, and whether its edges match the real call path. Those are in the case, and
# the PNGs from diagram-shot.sh are how a reader settles the last one.
#
# The vocabulary below is the template's, and it is now exactly the two surviving SVG kinds'
# vocabulary: the ER fragment and the lifecycle. Extend both together — a class added here but
# not to page-template.html has no styles, and one added there but not here is reported
# as invented.
#
# Two class families that used to be here are gone, not renamed. The blast radius is a .blast
# box grid and the boundary chain is a .pipe spine — both CSS components, neither an SVG — so
# `legend` and `box-json` no longer style anything inside an <svg> and would be reported as
# invented if a run reached for them. That is the intended behaviour: a run drawing a blast
# radius as SVG should be told to use the component instead.
#
# TWO PLACES THIS FILE DECLINES TO REPRODUCE THE SHELL, both documented in
# evals/README.md § Two intentional differences. The second is here: diagram.sh finds its
# diagrams with `grep -n '<svg'`, and on a file containing NUL bytes grep prints "binary file
# matches" instead of line numbers — so the shell SKIPs a page whose diagrams are all present.
# Reproducing that would mean writing a NUL-byte test into Page in order to make these rules
# stop firing.
#
# TWO ORDERS THIS FILE DEFINES AND THE SHELL DID NOT. The awk it replaces iterated the
# coordinate names and the per-section diagram counts with `for (key in array)`, whose order
# POSIX leaves unspecified — mawk walks the coords as x1 cy y2 x2 y x y1 cx. Both are reachable
# only when one element is out of bounds on several axes at once, or two sections both carry
# diagrams, and neither happens anywhere in the corpus. Here they are declaration order and
# document order. That is the one intentional behavioural difference in the port, and it is a
# narrowing: the shell's output for those cases was whatever the local awk did.

require_relative "lib/review_map/check"

module Diagram
  VOCAB = %w[t-title t-col t-dim t-lbl t-edge box box-hd edge edge-dash edge-accent
             node node-dead lifeline].freeze
  COORDS = %w[x y x1 y1 x2 y2 cx cy].freeze
  # Sequential, later wins, exactly as the awk's run of ifs did.
  TEXT_SIZES = [["t-title", 13], ["t-col", 11], ["t-dim", 10.5], ["t-lbl", 10], ["t-edge", 10.5]].freeze
  CATEGORIES = %w[vocab colour placeholder bounds label].freeze
  CLEAN = {
    "vocab" => "uses only template classes",
    "colour" => "takes every colour from a class",
    "placeholder" => "has no placeholders left",
    "bounds" => "draws inside its viewBox",
    "label" => "labels fit their boxes",
  }.freeze

  Finding = Struct.new(:severity, :category, :message)
  Rect = Struct.new(:x, :y, :w, :h)
  Label = Struct.new(:x, :y, :anchor, :size, :content)

  # awk stringifies a number through CONVFMT, which defaults to %.6g — so 120 prints as
  # "120" and not "120.0". Every number that reaches a message goes through here.
  def self.num(value)
    format("%.6g", value)
  end

  def self.attrnum(element, attr)
    m = element.match(/(?:^|[ \t])#{Regexp.escape(attr)}="(-?[0-9.]+)"/)
    m ? m[1].to_f : -1.0
  end

  # The four analyses that need the geometry, in one pass over the flattened SVG, emitting
  # only problems so the caller can print a single PASS per category.
  class Analysis
    def initialize(body)
      @body = body.gsub("\r", " ")
      @findings = []
      @rects = []
      @labels = []
      @seen = { class: {}, colour: {}, style: false, path: false }
      @vw = 0.0
      @vh = 0.0
    end

    def findings
      read_viewbox
      walk_elements
      # Placeholders, checked against the whole drawing: the ones that ship are usually text
      # content, not attributes, so an element-by-element pass misses exactly the common case.
      err("placeholder", "a {{PLACEHOLDER}} survives inside the diagram") if @body.include?("{{")
      check_labels
      @findings
    end

    private

    def err(category, message) = @findings << Finding.new("ERR", category, message)
    def wrn(category, message) = @findings << Finding.new("WRN", category, message)

    # Anything outside the viewBox is drawn where no reader will look.
    def read_viewbox
      m = @body.match(/viewBox="([^"]*)"/)
      return unless m

      box = m[1].split(/[ ,]+/)
      # awk's split leaves a leading empty field when the value starts with a space, and the
      # shell read fields 3 and 4 off that, so the offset has to survive the port.
      box.shift if box.first == ""
      @vw = box[2].to_f
      @vh = box[3].to_f
    end

    def walk_elements
      rest = @body
      while (m = rest.match(/<[a-zA-Z]+[^>]*>/))
        element = m[0]
        after = m.post_match
        rest = after
        tag = element.sub(/\A</, "").sub(%r{[ />].*}, "")

        check_classes(element)
        check_colours(element)
        collect_rect(element) if tag == "rect"
        collect_label(element, after) if tag == "text"
        check_bounds(element, tag) if @vw > 0
      end
    end

    # Invented classes: styled by nothing, so they render as bare shapes.
    def check_classes(element)
      m = element.match(/class="([^"]*)"/)
      return unless m

      m[1].split(" ").each do |name|
        next if name.empty? || VOCAB.include?(name) || @seen[:class][name]

        @seen[:class][name] = true
        err("vocab", %(class "#{name}" is not in the template vocabulary — nothing styles it))
      end
    end

    # A colour spelled out here is correct in one theme and wrong in the other; the classes
    # exist so it never has to be.
    def check_colours(element)
      %w[fill stroke].each do |attr|
        m = element.match(/#{attr}="([^"]*)"/)
        next unless m

        value = m[1]
        next if value == "none" || value.start_with?("var(", "url(") || value == "currentColor"
        next if @seen[:colour][value]

        @seen[:colour][value] = true
        err("colour", %(#{attr}="#{value}" is a literal colour — use a class, or var(--token)))
      end

      style = element.match(/style="([^"]*)"/)
      return unless style
      return unless style[1].match?(/(fill|stroke|color)[ ]*:[ ]*(#|rgb|hsl)/)
      return if @seen[:style]

      @seen[:style] = true
      err("colour", "inline style declares a literal colour: #{style[1]}")
    end

    def collect_rect(element)
      @rects << Rect.new(Diagram.attrnum(element, "x"), Diagram.attrnum(element, "y"),
                         Diagram.attrnum(element, "width"), Diagram.attrnum(element, "height"))
    end

    def collect_label(element, after)
      anchor = if element.match?(/text-anchor="middle"/) then "middle"
               elsif element.match?(/text-anchor="end"/) then "end"
               else "start"
               end
      size = 12
      TEXT_SIZES.each { |name, points| size = points if element.match?(/class="[^"]*#{name}/) }
      content = after.sub(/<.*/, "").sub(/\A[ \t]+/, "").sub(/[ \t]+\z/, "")
      @labels << Label.new(Diagram.attrnum(element, "x"), Diagram.attrnum(element, "y"),
                           anchor, size, content)
    end

    # Explicit coordinates, checked hard. Path data is checked loosely, because pairing
    # numbers off a d= attribute is a guess about the commands.
    def check_bounds(element, tag)
      COORDS.each do |name|
        next unless element.match?(/(?:^|[ \t])#{name}="-?[0-9.]+"/)

        value = Diagram.attrnum(element, name)
        limit = name.match?(/\A(y|cy)/) ? @vh : @vw
        next unless value < 0 || value > limit

        err("bounds", "<#{tag}> has #{name}=#{Diagram.num(value)}, outside the " \
                      "#{Diagram.num(@vw)}x#{Diagram.num(@vh)} viewBox")
      end

      if tag == "rect"
        rect = @rects.last
        if rect && rect.x + rect.w > @vw + 0.5
          err("bounds", "a rect runs to x=#{Diagram.num(rect.x + rect.w)}, " \
                        "past the #{Diagram.num(@vw)}-wide viewBox")
        end
      end

      check_path(element)
    end

    def check_path(element)
      m = element.match(/d="([^"]*)"/)
      return unless m

      numbers = m[1].gsub(/[A-Za-z,]/, " ").split(/[ ]+/).reject(&:empty?)
      numbers.each_with_index do |raw, index|
        # The alternating limit is the awk's k counter: odd is an x, even is a y.
        limit = (index + 1).even? ? @vh : @vw
        next unless raw.to_f > limit
        next if @seen[:path]

        @seen[:path] = true
        # `raw` is printed as the string it was split from, not as a number — the awk
        # concatenated the field itself, so "0120" would print as "0120".
        wrn("bounds", "a path coordinate reads #{raw} against a limit of " \
                      "#{Diagram.num(limit)} — check the far edge of the figure")
      end
    end

    # Labels against the boxes. Monospace, so width is close to 0.6 per character; crude,
    # and a WARN, but these are the defects that actually ship. Two of them, and the second
    # was found by looking at a PNG this pass had just called clean: a label INSIDE a box can
    # be wider than the box, and a label outside every box can still run underneath one.
    def check_labels
      @labels.each do |label|
        next if label.content.empty?

        # bytesize, not length: mawk's length() counts bytes, and a label carrying an em
        # dash would otherwise be measured differently here than it was there.
        width = label.content.bytesize * label.size * 0.6
        left = case label.anchor
               when "middle" then label.x - width / 2
               when "end" then label.x - width
               else label.x
               end

        housing = @rects.find { |r| r.w.positive? && vertically_within?(label, r) && horizontally_within?(label, r) }
        if housing
          if left + width > housing.x + housing.w - 2 || left < housing.x + 2
            wrn("label", %("#{clip(label.content)}" is about #{width.to_i}px wide in a box ) +
                         "#{housing.w.to_i}px wide — likely spills")
          end
          next
        end

        collision = @rects.find do |r|
          r.w.positive? && vertically_within?(label, r) && left + width > r.x && left < r.x + r.w
        end
        next unless collision

        wrn("label", %("#{clip(label.content)}" is about #{width.to_i}px wide and runs under ) +
                     "a box at x=#{collision.x.to_i} — an edge label wider than its gap")
      end
    end

    def vertically_within?(label, rect)
      label.y >= rect.y && label.y <= rect.y + rect.h
    end

    def horizontally_within?(label, rect)
      label.x >= rect.x && label.x <= rect.x + rect.w
    end

    def clip(content)
      content.byteslice(0, 40)
    end
  end
end

check = ReviewMap::Check.new(ARGV, name: "diagram.sh")
check.require_input
page = check.page
lines = page.lines

# 1-based line numbers, because two of the context checks below read the ORIGINAL input
# around each diagram rather than the extracted drawing.
starts = lines.each_index.select { |i| lines[i].include?("<svg") }.map { |i| i + 1 }
if starts.empty?
  check.skip("no diagrams in this input")
  check.finish
end

# One drawing per start line: the first line truncated to begin at <svg>, any line carrying
# </svg> truncated after it, and the scan stopping there.
drawings = starts.map do |start|
  out = []
  lines[(start - 1)..].each_with_index do |raw, offset|
    line = raw.chomp
    line = line.sub(/\A.*<svg/, "<svg") if offset.zero?
    closes = line.include?("</svg>")
    line = line.sub(%r{</svg>.*}, "</svg>") if closes
    out << line
    break if closes
  end
  out
end

check.ok("#{starts.size} diagram(s) found")

# The overflow contract: a diagram lives in figure.wide > .scroller, which is what lets a
# 880-wide figure sit on a phone without the page itself scrolling sideways.
starts.each do |start|
  from = [start - 4, 1].max
  context = lines[(from - 1)...start].join
  next if context.include?('class="scroller"')

  check.bad("diagram at line #{start} is not inside .scroller — wide content must scroll in its own container, never the page")
end

drawings.each_with_index do |drawing, index|
  number = index + 1
  start = starts[index]

  # The legend is usually the figcaption, which sits OUTSIDE the svg — so the context is
  # the figure, not the drawing. A dashed box with no legend reads as "deleted", which is
  # the opposite of what it means here.
  if drawing.any? { |line| line.include?("node-dead") }
    window = lines[(start - 1)...(start + drawing.size + 4)].to_a
                                                            .map { |line| line.gsub(/aria-label="[^"]*"/, "") }
    if window.any? { |line| line.match?(/legend|dashed|solid/i) }
      check.ok("diagram #{number} explains its dashed nodes")
    else
      check.bad("diagram #{number} uses .node-dead with nothing explaining it — a dashed box unexplained reads as deleted")
    end
  end

  # Accessibility and framing, read off the opening tag.
  head = drawing.join(" ").sub(/\A.*<svg/, "<svg").sub(/>.*\z/, "")
  check.bad("diagram #{number} has no viewBox — it cannot scale, and the bounds check cannot run") unless head.include?("viewBox=")
  check.bad(%(diagram #{number} has no role="img")) unless head.include?('role="img"')
  if head.match?(/aria-label="[^"]*\{\{/)
    check.bad("diagram #{number} ships a placeholder aria-label")
  elsif head.include?('aria-label=""')
    check.bad("diagram #{number} has an empty aria-label")
  elsif !head.include?("aria-label=")
    check.bad("diagram #{number} has no aria-label — the one part of a figure a screen reader can use")
  end

  findings = Diagram::Analysis.new(drawing.map { |line| " #{line}" }.join).findings
  Diagram::CATEGORIES.each do |category|
    in_category = findings.select { |f| f.category == category }
    if in_category.empty?
      check.ok("diagram #{number} #{Diagram::CLEAN[category]}")
      next
    end
    in_category.each do |finding|
      message = "diagram #{number} · #{finding.message}"
      finding.severity == "ERR" ? check.bad(message) : check.maybe(message)
    end
  end
end

# The budget, which only means anything across a whole page: one per section, a second
# only for a genuinely different mechanism.
if check.kind != "page"
  check.skip("diagram budget: it is a per-section count, so a fragment cannot settle it")
else
  counts = {}
  current = nil
  lines.each do |raw|
    line = raw.chomp
    if line.match?(/<section [^>]*id="/)
      id = line.sub(/.*id="/, "").sub(/".*/, "")
      counts[id] ||= 0
      current = id
    end
    current = nil if line.include?("</section>")
    counts[current] += 1 if line.include?("<svg") && current
  end

  over = false
  counts.each do |section, count|
    next unless count.positive?

    if count >= 3
      check.bad(%(section "#{section}" carries #{count} diagrams — the budget is one, and a second only for a different mechanism))
      over = true
    elsif count == 2
      check.maybe(%(section "#{section}" carries 2 diagrams — legitimate only if they show different mechanisms (ER plus lifecycle is the usual case)))
      over = true
    end
  end
  check.ok("diagram budget respected in every section") unless over
end

check.finish
