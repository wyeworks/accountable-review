#!/usr/bin/env ruby
# frozen_string_literal: true

# test_grade.rb — grade.rb's arithmetic on synthetic verdicts, and the one drift check that keeps
# criteria.yml and judges/*.md the same length: a criterion split in a judge file without a class
# here would be graded under the wrong bar, silently.

require "minitest/autorun"
require "tmpdir"
require_relative "grade"

class TestCriteriaMatchJudges < Minitest::Test
  def test_every_judge_criterion_has_exactly_one_class
    classes = Grade.classes
    judges = Dir[File.join(E2E::JUDGES, "*.md")].select { |p| File.read(p).start_with?("---\n") }.map { |p| File.basename(p, ".md") }.sort
    assert_equal judges, classes.keys.sort, "criteria.yml classes a judge that does not exist, or misses one"
    judges.each do |j|
      n = Judge.load(j)[:meta]["criteria"].length
      assert_equal (1..n).to_a, classes[j].keys.sort, "#{j}: criteria.yml has classes for #{classes[j].keys.sort}, the judge has #{n} criteria"
      classes[j].each_value { |c| assert_includes Grade::CLASSES, c }
    end
  end
end

class TestStatus < Minitest::Test
  def c(pass, fail = 0, unclear = 0) = { pass: pass, fail: fail, unclear: unclear }

  def test_truth_is_counted_not_rated
    assert_equal :good, Grade.status("truth", c(6))
    assert_equal :read, Grade.status("truth", c(5, 1))
    assert_equal :read, Grade.status("truth", c(2, 1)), "one failure in three is still a reading, not a rate"
    assert_equal :block, Grade.status("truth", c(4, 2))
    assert_equal :good, Grade.status("truth", c(5, 0, 1)), "unclear is not a failure"
  end

  def test_form_is_rated_as_a_fraction
    assert_equal :good, Grade.status("form", c(6))
    assert_equal :good, Grade.status("form", c(5, 1))
    assert_equal :watch, Grade.status("form", c(4, 2))
    assert_equal :failing, Grade.status("form", c(3, 3))
    assert_equal :good, Grade.status("form", c(3)), "a batch of three reads like a pooled six"
    assert_equal :watch, Grade.status("form", c(2, 1))
    assert_equal :failing, Grade.status("form", c(1, 2))
    assert_equal :watch, Grade.status("form", c(4, 0, 2)), "unclear is not a pass"
  end

  def test_a_gold_split_lowers_the_form_floor_only
    assert_equal :good, Grade.status("form", c(4, 2), split: true)
    assert_equal :failing, Grade.status("form", c(3, 3), split: true)
    assert_equal :read, Grade.status("truth", c(5, 1), split: true)
  end

  def test_nothing_counted_is_none
    assert_equal :none, Grade.status("form", c(0))
  end

  def test_a_deferred_criterion_has_one_status_whatever_the_count
    assert_equal :deferred, Grade.status("deferred", c(6))
    assert_equal :deferred, Grade.status("deferred", c(0, 6))
    assert_equal :none, Grade.status("deferred", c(0)), "nothing counted is still none"
  end
end

class TestOverRows < Minitest::Test
  CLASSES = { "j" => { 1 => "truth", 2 => "form", 3 => "form", 4 => "form" } }.freeze
  DEFERRED = { "j" => { 1 => "truth", 2 => "deferred", 3 => "deferred", 4 => "form" } }.freeze

  def setup
    @dir = Dir.mktmpdir("grade-")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # One repetition: a page, a check count, and j's four verdicts — calibrated unless told otherwise.
  def rep(i, verdicts, check_failed: 0, calibration: "calibrated", page: true)
    rundir = File.join(@dir, "r#{i}")
    FileUtils.mkdir_p(File.join(rundir, "page"))
    File.write(File.join(rundir, "page", "index.html"), "<html>") if page
    path = File.join(rundir, "j.json")
    File.write(path, JSON.generate("verdicts" => verdicts.each_with_index.map { |v, k| { "n" => k + 1, "verdict" => v } }, "notes" => ""))
    { "rundir" => rundir, "generated" => page, "check_failed" => check_failed,
      "judges" => { "j" => { "calibration" => calibration, "verdicts" => path } } }
  end

  def test_pool_counts_every_calibrated_verdict
    rows = [rep(1, %w[pass pass fail unclear]), rep(2, %w[fail pass pass pass])]
    pool = Grade.pool(rows)
    assert_equal({ pass: 1, fail: 1, unclear: 0 }, pool[["j", 1]])
    assert_equal({ pass: 1, fail: 1, unclear: 0 }, pool[["j", 3]])
    assert_equal({ pass: 1, fail: 0, unclear: 1 }, pool[["j", 4]])
  end

  def test_an_uncalibrated_judge_is_never_counted
    rows = [rep(1, %w[fail fail fail fail], calibration: "uncalibrated")]
    assert_empty Grade.pool(rows)
  end

  def test_table_and_overall
    rows = [rep(1, %w[pass pass fail pass]), rep(2, %w[fail pass pass pass]), rep(3, %w[pass pass pass pass])]
    lines = Grade.table(rows, classes: CLASSES, splits: {})
    assert_equal %i[read good watch good], lines.map(&:status)
    assert_equal :read, Grade.overall(lines)
    refute Grade.blocking?(rows, lines, classes: CLASSES)
  end

  def test_two_truth_failures_block_and_a_check_fail_blocks
    rows = [rep(1, %w[fail pass pass pass]), rep(2, %w[fail pass pass pass]), rep(3, %w[pass pass pass pass])]
    lines = Grade.table(rows, classes: CLASSES, splits: {})
    assert_equal :block, lines.first.status
    assert Grade.blocking?(rows, lines, classes: CLASSES)

    rows = [rep(1, %w[pass pass pass pass], check_failed: 1)]
    assert Grade.blocking?(rows, Grade.table(rows, classes: CLASSES, splits: {}), classes: CLASSES)
  end

  def test_page_cap_counts_form_failures_only
    p = Grade.page(rep(1, %w[fail fail fail pass]), classes: CLASSES)
    assert_equal 1, p[:truth_fails]
    assert_equal 2, p[:form_fails]
    assert p[:acceptable], "two form failures is the cap, and a truth failure is held per criterion"
    refute Grade.page(rep(2, %w[pass fail fail fail]), classes: CLASSES)[:acceptable]
    refute Grade.page(rep(3, %w[pass pass pass pass], page: false), classes: CLASSES)[:acceptable]
  end

  def test_median_repetition
    rows = [rep(1, %w[pass fail fail fail]), rep(2, %w[pass pass pass pass]), rep(3, %w[pass pass fail pass])]
    assert Grade.median_acceptable?(rows, classes: CLASSES)
    rows = [rep(1, %w[pass fail fail fail]), rep(2, %w[pass fail fail fail]), rep(3, %w[pass pass pass pass])]
    refute Grade.median_acceptable?(rows, classes: CLASSES)
  end

  def test_a_deferred_failure_moves_nothing
    rows = [rep(1, %w[pass fail fail pass]), rep(2, %w[pass fail fail pass]), rep(3, %w[pass fail fail pass])]
    lines = Grade.table(rows, classes: DEFERRED, splits: {})
    assert_equal %i[good deferred deferred good], lines.map(&:status)
    assert_equal :good, Grade.overall(lines), "deferred lines never set the overall"
    refute Grade.blocking?(rows, lines, classes: DEFERRED)
    p = Grade.page(rows.first, classes: DEFERRED)
    assert_equal 2, p[:deferred_fails]
    assert_equal 0, p[:form_fails]
    assert p[:acceptable], "a deferred failure is outside the page cap"
    assert Grade.median_acceptable?(rows, classes: DEFERRED)
  end

  def test_the_same_verdicts_graded_as_form_do_block
    rows = [rep(1, %w[pass fail fail pass]), rep(2, %w[pass fail fail pass]), rep(3, %w[pass fail fail pass])]
    assert Grade.blocking?(rows, Grade.table(rows, classes: CLASSES, splits: {}), classes: CLASSES)
  end

  def test_an_unclassed_criterion_is_an_error_not_a_guess
    rows = [rep(1, %w[pass pass pass pass pass])]
    assert_raises(ArgumentError) { Grade.table(rows, classes: CLASSES, splits: {}) }
  end

  def test_split_on_gold_reads_status_json
    path = File.join(@dir, "status.json")
    File.write(path, JSON.generate("j" => { "findings" => [
      { "variant" => "gold", "criterion" => 2, "got" => %w[pass fail] },
      { "variant" => "gold", "criterion" => 3, "got" => %w[pass pass] },
      { "variant" => "j-defect", "criterion" => 4, "got" => %w[pass fail] }
    ] }))
    assert_equal({ "j" => [2] }, Grade.split_on_gold(path))
    assert_equal({}, Grade.split_on_gold(File.join(@dir, "missing.json")))
  end
end
