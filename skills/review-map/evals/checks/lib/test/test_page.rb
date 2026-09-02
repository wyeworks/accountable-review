#!/usr/bin/env ruby
# frozen_string_literal: true

# test_page.rb — the region scanner, checked directly.
#
# This is the file that has no counterpart in the shell version, and it is most of the
# argument for the port. The three awk extractors in behaviour-flows.sh could only ever be
# exercised end to end, through a golden fragment, by reading a PASS line and trusting that
# it came from the region you had in mind. Every property below was already load-bearing —
# each one is a sentence that had to be written as a comment above an awk flag, because
# there was nowhere to assert it.

require "minitest/autorun"
require "tempfile"
require_relative "../review_map/page"

MECH     = /class="mech"/
GRID     = /<dl class="rows"/
DL_CLOSE = %r{</dl>}
SEC_END  = %r{</section>}

def page(html)
  ReviewMap::Page.new(html.lines)
end

class TestRegions < Minitest::Test
  # awk printed before it cleared its flag, so the line that ends a region is part of it.
  # The housing census depends on this: a </dl> outside its own grid would leave every
  # closing line unhoused and report a correct page as flattened.
  def test_a_region_includes_the_line_that_closes_it
    regions = page(<<~HTML).regions(open: GRID, close: DL_CLOSE)
      <p>before</p>
      <dl class="rows">
      <dt>Understand</dt>
      </dl>
      <p>after</p>
    HTML

    assert_equal 1, regions.size
    assert_equal ["<dl class=\"rows\">\n", "<dt>Understand</dt>\n", "</dl>\n"], regions.first.lines
  end

  def test_a_region_that_opens_and_closes_on_one_line_is_that_line
    regions = page(%(<dl class="rows"><dt>Tests</dt></dl>\n)).regions(open: GRID, close: DL_CLOSE)

    assert_equal 1, regions.size
    assert_equal 1, regions.first.lines.size
  end

  # A second .mech before the first one closed is a second unit, not more of the first.
  def test_open_restarts_a_region_that_never_closed
    regions = page(<<~HTML).regions(open: MECH, close: DL_CLOSE, arm: GRID, hard_close: SEC_END)
      <div class="mech"><b>One</b></div>
      <p>no grid here</p>
      <div class="mech"><b>Two</b></div>
      <dl class="rows">
      <dt>Understand</dt>
      </dl>
    HTML

    assert_equal 2, regions.size
    assert_includes regions[0].lines.first, "One"
    assert_includes regions[1].lines.first, "Two"
  end

  # The `arm` rule, and the reason it exists. A .mech whose own grid never opens must NOT
  # end at the next flow's </dl> — it would swallow everything between and be named, cited
  # and graded on a neighbour's fields.
  def test_an_unarmed_region_ignores_close_and_ends_at_hard_close
    regions = page(<<~HTML).regions(open: MECH, close: DL_CLOSE, arm: GRID, hard_close: SEC_END)
      <div class="mech"><b>Flattened</b></div>
      <div>
      <dt>Understand</dt>
      </dl>
      </section>
      <section id="flow-b">
      <dl class="rows">
      </dl>
    HTML

    assert_equal 1, regions.size
    refute_includes regions.first.lines.join, "flow-b"
    assert_includes regions.first.lines.join, "</section>"
  end

  def test_an_armed_region_ends_at_its_own_grid_close
    regions = page(<<~HTML).regions(open: MECH, close: DL_CLOSE, arm: GRID, hard_close: SEC_END)
      <div class="mech"><b>One</b></div>
      <dl class="rows">
      <dt>Understand</dt>
      </dl>
      <div class="decisions">after the dl</div>
    HTML

    assert_equal 1, regions.size
    refute_includes regions.first.lines.join, "decisions"
  end

  # dl.rows is SHARED with section 4, so the flow census narrows on id="flow-" first. This
  # is the false positive flows-blast-rows.html pins, expressed directly.
  def test_narrow_keeps_document_order_and_drops_unmatched_sections
    narrowed = page(<<~HTML).narrow(open: /<section [^>]*id="flow-/, close: SEC_END)
      <section id="flow-a">
      <dl class="rows">A</dl>
      </section>
      <section id="blast">
      <dl class="rows">not a unit</dl>
      </section>
      <section id="flow-b">
      <dl class="rows">B</dl>
      </section>
    HTML

    refute_includes narrowed.lines.join, "not a unit"
    assert_equal 2, narrowed.count(GRID)
    assert_operator narrowed.lines.join.index("A"), :<, narrowed.lines.join.index("B")
  end
end

class TestCounting < Minitest::Test
  # `grep -c` counts matching LINES. The field census compares two of its results against
  # each other, so counting occurrences instead would change what a "field row" is and turn
  # a compact one-line grid into a page that reports its own fields as unhoused.
  def test_count_counts_lines_not_occurrences
    doc = page(%(<dt>Implementation</dt><dt>Tests</dt>\n<dt>Understand</dt>\n))

    assert_equal 2, doc.count(/<dt>/)
    assert_equal 3, doc.scan(/<dt>/).size
  end

  # grep strips the line terminator before matching. The page's patterns lean on negated
  # classes, and in Ruby those match a newline — so without chomping, an unterminated tag
  # at end of line silently pulls the next line into the match. No golden fragment has that
  # shape, which is exactly why it needs a test rather than a fixture.
  def test_a_negated_class_does_not_cross_a_line_boundary
    doc = page(%(<dt>Validate\n<dd>next line</dd>\n))

    assert_equal ["<dt>Validate"], doc.scan(/<dt>[^<]*/)
  end

  # grep -Fq vs grep -q. The shell used both, so a String here is a fixed string.
  def test_a_string_pattern_is_a_fixed_string
    doc = page(%(absence is not a finding\n))

    assert doc.has?("absence is not a finding")
    refute doc.has?("absence is n.t a finding")
    assert doc.has?(/absence is n.t a finding/)
  end

  def test_scan_flattens_in_document_order
    doc = page(%(<b>one</b><b>two</b>\n<b>three</b>\n))

    assert_equal %w[one two three], doc.scan(/<b>([^<]*)/)
  end
end

class TestRange < Minitest::Test
  # awk '/from/,/to/': inclusive, and re-openable.
  def test_range_is_inclusive_and_reopens
    doc = page(<<~HTML).range(from: /<dt>[^<]*[Vv]alidat/, to: %r{</dd>})
      <dt>Understand</dt><dd>no code here</dd>
      <dt>Validate</dt>
      <dd><code>rspec</code></dd>
      <dt>Validate</dt>
      <dd>not pasteable</dd>
    HTML

    assert doc.has?(/<code/)
    refute_includes doc.lines.join, "Understand"
    assert_includes doc.lines.join, "not pasteable"
  end
end

class TestReading < Minitest::Test
  # These containers run without a UTF-8 locale, so a page's em dash would raise on the
  # first match if the encoding were left to the default. grep never had to care.
  def test_read_handles_utf8_regardless_of_locale
    Tempfile.create(["page", ".html"]) do |f|
      f.write(%(<p>a section — and a sign § 4</p>\n))
      f.close

      doc = ReviewMap::Page.read(f.path)

      assert doc.has?(/section/)
      assert_equal Encoding::UTF_8, doc.lines.first.encoding
    end
  end
end
