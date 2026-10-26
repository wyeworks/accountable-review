#!/usr/bin/env ruby
# frozen_string_literal: true

# test_triage.rb — triage.rb's queue on synthetic result lines: which verdicts reach a person,
# how evidence turns into links, and that the page carries its data without breaking out of the
# <script> it sits in. No model, no network.

require "minitest/autorun"
require "tmpdir"
require_relative "triage"

class TestTriage < Minitest::Test
  PR = Struct.new(:id, :repo, :pr, :head_sha)
  HEAD = "4f7ccd0326cf1f7d36000d2e530aca6ff4f8981f"

  def setup
    @dir = Dir.mktmpdir
    @pr = PR.new("demo-1", "acme/app", 7, HEAD)
  end

  def teardown = FileUtils.rm_rf(@dir)

  def row(rep, judges, check: nil)
    rd = File.join(@dir, "r#{rep}")
    FileUtils.mkdir_p(File.join(rd, "page"))
    File.write(File.join(rd, "page", "index.html"), "<p>page</p>")
    File.write(File.join(rd, "check.txt"), check) if check
    js = judges.to_h do |name, (doc, cal)|
      path = File.join(rd, "#{name}.json")
      File.write(path, JSON.generate(doc))
      [name, { "verdicts" => path, "calibration" => cal ? "calibrated" : "uncalibrated", "usable" => true }]
    end
    { "id" => "demo-1", "rep" => rep, "batch" => "b1", "rundir" => rd, "generated" => true, "check_failed" => 0,
      "plugin_version" => "1.0", "skill_sha" => "abc1234", "effort" => "high", "model" => "m", "judges" => js }
  end

  def build(rows, files: %w[app/models/report.rb app/serializers/report_serializer.rb lib/report.rb])
    Triage.build(rows, classes: { "claims" => { 1 => "truth", 2 => "form", 3 => "deferred" } }, splits: {},
                       pr_of: ->(_) { @pr }, files_of: ->(_) { files })
  end

  def v(n, verdict, why = "w", evidence = "") = { "n" => n, "verdict" => verdict, "why" => why, "evidence" => evidence }

  def test_queue_is_truth_failures_unclears_and_notes
    doc = { "verdicts" => [v(1, "fail", "false", "report.rb:12"), v(2, "unclear"), v(3, "pass")], "notes" => "criterion 2 is ambiguous here" }
    data = build([row(1, { "claims" => [doc, true] }, check: "WARN  tier on line 3\nPASS  ok\n")])
    kinds = data["items"].map { |i| i["kind"] }.sort
    assert_equal %w[check claim note unclear], kinds
    claim = data["items"].find { |i| i["kind"] == "claim" }
    assert_equal ["truth", true], claim.values_at("class", "calibrated")
    assert_equal "read", data["groups"].first["criteria"].find { |c| c["n"] == 1 }["status"]
  end

  def test_form_and_deferred_failures_are_kept_but_not_queued
    doc = { "verdicts" => [v(2, "fail"), v(3, "fail")], "notes" => "" }
    items = build([row(1, { "claims" => [doc, true] })])["items"]
    assert_equal %w[deferred form], items.map { |i| i["kind"] }.sort
    assert items.none? { |i| Triage::QUEUE.include?(i["kind"]) }
  end

  def test_uncalibrated_verdicts_are_marked
    doc = { "verdicts" => [v(1, "fail")], "notes" => "" }
    items = build([row(1, { "claims" => [doc, false] })])["items"]
    assert_equal [false], items.map { |i| i["calibrated"] }
  end

  def test_ids_are_stable_across_builds_and_distinct_across_reps
    doc = { "verdicts" => [v(1, "fail")], "notes" => "" }
    rows = [row(1, { "claims" => [doc, true] }), row(2, { "claims" => [doc, true] })]
    a = build(rows)["items"].map { |i| i["id"] }
    assert_equal a, build(rows)["items"].map { |i| i["id"] }
    assert_equal 2, a.uniq.size
  end

  def test_a_bare_file_name_resolves_only_when_it_names_one_file
    links = Triage.evidence_links("report_serializer.rb:11-14 and report.rb:3", pr: @pr, files: %w[app/serializers/report_serializer.rb app/models/report.rb lib/report.rb], page: nil)
    assert_equal ["https://github.com/acme/app/blob/#{HEAD}/app/serializers/report_serializer.rb#L11-L14"], links.map { |l| l["href"] }
  end

  def test_a_path_with_a_directory_links_without_a_clone_and_not_when_the_clone_lacks_it
    assert_equal 1, Triage.evidence_links("app/x.rb:4", pr: @pr, files: nil, page: nil).size
    assert_empty Triage.evidence_links("app/x.rb:4", pr: @pr, files: %w[app/y.rb], page: nil)
  end

  def test_a_quote_becomes_a_text_fragment_on_the_page
    l = Triage.evidence_links(%("The 422 body is read by nothing"), pr: @pr, files: [], page: "/tmp/p/index.html")
    assert_equal ["file:///tmp/p/index.html#:~:text=The%20422%20body%20is%20read%20by%20nothing"], l.map { |x| x["href"] }
    long = Triage.fragment("one two three four five six seven eight nine ten eleven-twelve")
    assert_equal "one%20two%20three%20four%20five,seven%20eight%20nine%20ten%20eleven%2Dtwelve", long
  end

  def test_the_page_cannot_be_closed_from_inside_its_data
    doc = { "verdicts" => [v(1, "fail", "</script><script>alert(1)</script>", %q(a\\0b \\1))], "notes" => "" }
    html = Triage.html(build([row(1, { "claims" => [doc, true] })]), readings: {}, source: "<x>")
    assert_equal 3, html.scan("</script>").size, "only the template's own three script elements may close"
    refute_includes html, "/*DATA*/null"
    assert_includes html, "&lt;x&gt;"
    data = JSON.parse(html[%r{<script id="data" type="application/json">(.*?)</script>}m, 1].gsub("<\\/", "</"))
    assert_equal %q(a\\0b \\1), data["items"].first["evidence"], "a backslash in the data is not a back-reference"
  end

  def test_readings_file_accepts_the_export_shape_and_survives_garbage
    path = File.join(@dir, "a.json")
    File.write(path, JSON.generate("written" => "t", "readings" => { "abc" => { "decision" => "false" } }))
    assert_equal({ "abc" => { "decision" => "false" } }, Triage.adjudications(path))
    File.write(path, "not json")
    assert_output(nil, /not JSON/) { assert_equal({}, Triage.adjudications(path)) }
    assert_equal({}, Triage.adjudications(File.join(@dir, "missing.json")))
  end
end
