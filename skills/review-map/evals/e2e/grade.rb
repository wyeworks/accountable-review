# frozen_string_literal: true

# grade.rb — what the numbers have to show. evals/README.md § What counts as good owns the
# reasoning; this file holds the arithmetic, and summary.rb and report.rb print it.
#
# A criterion has a class, read from criteria.yml (never from the judge file, whose bytes are the
# instrument), and the class decides its bar over the verdicts pooled across repetitions — and,
# in report.rb, across PRs at one skill sha:
#
#   truth   counted, not rated: no failure is good, ONE failure is a verdict a person reads
#           against the repository, TWO block. Absolute, whatever the sample size, because a
#           false sentence is not diluted by the pages beside it.
#   form    rated: pass ≥ 5/6 is good, ≥ 4/6 is watch, below that fails and blocks. A fraction,
#           so a batch of 3 reads the same way a pooled 6 does (3/3 good, 2/3 watch, 1/3 failing).
#
# Where calibration/status.json records the judge splitting its own vote on the gold page for a
# criterion, the instrument sets the ceiling: a form criterion is good at 4/6 and a truth
# criterion's single failure is read knowing the judge disagreed with itself there.
#
# `unclear` is not a pass in either class and is reported beside the counts, never folded into
# them. Only CALIBRATED judges count, for the reason report.rb gives.
#
# A page is acceptable when it was generated, check.rb reported no FAIL, and at most two FORM
# criteria failed; truth criteria are held per criterion above, never by a per-page cap. Per PR
# the median repetition must be acceptable.
#
# Blocking is the only thing that moves an exit code: a check FAIL, a truth criterion at two
# failures, a form criterion below 4/6, no page. Watch and read exit 0 — a number that fails a
# run for what the README calls a reading is the all-or-nothing gate under a new name.

require "json"
require "yaml"
require_relative "lib"
require_relative "judge"
require_relative "verdicts"

module Grade
  CRITERIA = File.join(E2E::HERE, "criteria.yml")
  CLASSES = %w[truth form].freeze
  BLOCKING = %i[block failing].freeze
  ORDER = { block: 0, failing: 1, read: 2, watch: 3, good: 4, none: 5 }.freeze

  # {judge => {n => "truth"|"form"}}
  def self.classes(path = CRITERIA)
    YAML.safe_load_file(path).to_h do |judge, map|
      [judge, map.to_h { |n, c| [Integer(n), c.to_s] }]
    end
  end

  def self.klass(judge, n, classes = self.classes)
    classes.dig(judge, n) or raise ArgumentError, "criteria.yml has no class for #{judge} criterion #{n}"
  end

  # {[judge, n] => {pass:, fail:, unclear:}} over every calibrated judge's usable verdicts in rows.
  # Read rows through E2E.runs first, or a re-judged page counts twice.
  def self.pool(rows)
    out = Hash.new { |h, k| h[k] = { pass: 0, fail: 0, unclear: 0 } }
    rows.each do |row|
      each_doc(row) do |judge, doc|
        doc["verdicts"].each do |v|
          verdict = v["verdict"].to_s.to_sym
          out[[judge, v["n"].to_i]][verdict] += 1 if %i[pass fail unclear].include?(verdict)
        end
      end
    end
    out
  end

  def self.each_doc(row)
    (row["judges"] || {}).each do |judge, j|
      next unless j["calibration"] == "calibrated" && j["verdicts"]

      doc = begin
        Verdicts.read(j["verdicts"])
      rescue Verdicts::Unusable
        nil
      end
      yield judge, doc if doc
    end
  end

  def self.status(klass, counts, split: false)
    n = counts[:pass] + counts[:fail] + counts[:unclear]
    return :none if n.zero?

    if klass == "truth"
      counts[:fail] >= 2 ? :block : counts[:fail] == 1 ? :read : :good
    else
      rate = Rational(counts[:pass], n)
      good = split ? Rational(4, 6) : Rational(5, 6)
      rate >= good ? :good : rate >= Rational(4, 6) ? :watch : :failing
    end
  end

  # {judge => [n, …]}: the gold-row criteria where the calibrated judge's runs disagreed.
  def self.split_on_gold(path = File.join(E2E::CALIBRATION, "status.json"))
    return {} unless File.exist?(path)

    JSON.parse(File.read(path)).to_h do |judge, s|
      ns = (s["findings"] || []).select { |f| f["variant"] == "gold" && Array(f["got"]).uniq.size > 1 }
      [judge, ns.map { |f| f["criterion"].to_i }.uniq]
    end
  end

  def self.label(judge, n)
    path = File.join(E2E::JUDGES, "#{judge}.md")
    criteria = File.exist?(path) ? Array(Judge.load(judge)[:meta]["criteria"]) : []
    criteria[n - 1].to_s[/\A[A-Z][A-Z ,'-]+[A-Z]/]&.capitalize || "criterion #{n}"
  end

  Line = Struct.new(:judge, :n, :label, :klass, :counts, :status, :split, keyword_init: true)

  # One line per criterion seen in rows, judges in name order, criteria in number order.
  def self.table(rows, classes: self.classes, splits: split_on_gold)
    pool(rows).sort_by { |(judge, n), _| [judge, n] }.map do |(judge, n), counts|
      klass = klass(judge, n, classes)
      split = Array(splits[judge]).include?(n)
      Line.new(judge: judge, n: n, label: label(judge, n), klass: klass, counts: counts,
               status: status(klass, counts, split: split), split: split)
    end
  end

  # :good, :watch, :read or :block over a table.
  def self.overall(lines)
    worst = lines.map(&:status).min_by { |s| ORDER[s] } || :none
    { block: :block, failing: :block, read: :read, watch: :watch, good: :good, none: :good }[worst]
  end

  # One repetition: generated, no check FAIL, at most two form failures.
  def self.page(row, classes: self.classes)
    form = 0
    truth = 0
    each_doc(row) do |judge, doc|
      doc["verdicts"].each do |v|
        next unless v["verdict"] == "fail"

        klass(judge, v["n"].to_i, classes) == "truth" ? truth += 1 : form += 1
      end
    end
    checks = row["check_failed"].to_i
    generated = !!row["generated"] && File.exist?(File.join(row["rundir"].to_s, "page", "index.html"))
    { generated: generated, check_failed: checks, form_fails: form, truth_fails: truth,
      acceptable: generated && checks.zero? && form <= 2 }
  end

  # The median repetition, by how far from acceptable it is, must be acceptable.
  def self.median_acceptable?(rows, classes: self.classes)
    pages = rows.map { |r| page(r, classes: classes) }
    return false if pages.empty?

    sorted = pages.sort_by { |p| [p[:generated] ? 0 : 1, p[:check_failed], p[:form_fails]] }
    sorted[(sorted.size - 1) / 2][:acceptable]
  end

  def self.blocking?(rows, lines = table(rows), classes: self.classes)
    lines.any? { |l| BLOCKING.include?(l.status) } ||
      rows.any? { |r| p = page(r, classes: classes); !p[:generated] || p[:check_failed].positive? }
  end
end
