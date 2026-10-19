# frozen_string_literal: true

# summary.rb — what run.rb prints when it is done: how the batch graded, and why.
#
# The headline is the per-criterion table grade.rb computes over this batch's repetitions —
# every calibrated judge's criteria, each with its class, its pooled count and its status under
# evals/README.md § What counts as good. The number of repetitions that passed EVERY criterion is
# printed second, because it is the number that cannot move: a sampled page judged by six
# stochastic judges fails one of 23 criteria most of the time whatever the prose does.
#
# Beneath that, one block per repetition says what that page did: whether it was generated,
# what check.rb found, every verdict with the judge's why where it was not a pass.
#
# Three things never decide it, each for a reason:
#
#   * a WARN — the checks' own contract is that a warning is a page to read again, not a page
#     that is wrong, so the summary lists them and moves on;
#   * an UNCALIBRATED judge — its verdicts are shown, never counted, for the reason report.rb
#     gives: a judge nobody has checked against a known answer is not a measurement yet;
#   * the § 01 word count — guidance, never a verdict, as report-format.md § The agenda budget
#     says of every length in it.
#
# An `unclear` from a calibrated judge is not a pass and not a fail: it is the judge saying it
# could not tell, and it is listed beside the counts rather than guessed on its behalf. The exit
# code moves only on what grade.rb calls blocking. This grades the PAGE, never the pull request,
# like everything in this directory.

require_relative "grade"
require_relative "judge"
require_relative "verdicts"

module Summary
  RULE = "━" * 64

  # One repetition against every GRADED criterion: :pass, :fail, or :look — and the reasons behind
  # anything but :pass. A deferred criterion's failure is listed and decides nothing, so a page
  # that fails only those is a :pass with a line saying what it failed. Detail beneath the
  # headline, never the headline.
  def self.verdict(row, classes: Grade.classes)
    reasons = []
    look = []
    deferred = []
    page = File.join(row["rundir"].to_s, "page", "index.html")
    reasons << "no page was generated" unless row["generated"] && File.exist?(page)
    reasons << "check.rb reported #{row['check_failed']} failure(s)" if row["check_failed"].to_i.positive?
    (row["judges"] || {}).each do |name, j|
      next unless j["calibration"] == "calibrated"

      unless j["usable"]
        reasons << "#{name} returned no usable verdicts"
        next
      end
      doc = begin
        Verdicts.read(j["verdicts"])
      rescue Verdicts::Unusable
        nil
      end
      fails = Array(doc&.dig("verdicts")).select { |v| v["verdict"] == "fail" }
                                         .group_by { |v| Grade.klass(name, v["n"].to_i, classes) == "deferred" }
      graded = fails.fetch(false, []).size
      held = fails.fetch(true, []).size
      reasons << "#{name} failed #{graded} criterion/criteria" if graded.positive?
      deferred << "#{name} failed #{held} deferred criterion/criteria — reported, not graded" if held.positive?
      if graded.zero? && j.dig("counts", "unclear").to_i.positive?
        look << "#{name} was unclear on #{j.dig('counts', 'unclear')} criterion/criteria"
      end
    end
    status = if reasons.any? then :fail
             elsif look.any? then :look
             else :pass
             end
    [status, reasons + look + deferred]
  end

  BADGE = { pass: "✅ PASS", fail: "❌ FAIL", look: "🔍 LOOK" }.freeze
  HEAD = { good: "✅ GOOD", watch: "🔍 WATCH", read: "🔍 READ", block: "❌ BLOCKED" }.freeze
  STATUS = { good: "good", watch: "watch", read: "read by a person", block: "BLOCKS — two failures",
             failing: "BLOCKS — below 4/6", deferred: "deferred — reported, not graded", none: "—" }.freeze

  def self.print(pr, rows, out: $stdout)
    tty = out.tty?
    paint = ->(s, code) { tty ? "\e[#{code}m#{s}\e[0m" : s }
    color = { pass: "1;32", fail: "1;31", look: "1;33", good: "1;32", watch: "1;33", read: "1;33", block: "1;31", failing: "1;31", deferred: "2" }

    rows = rows.sort_by { |r| r["rep"].to_i }
    verdicts = rows.map { |r| verdict(r) }
    all = verdicts.count { |v, _| v == :pass }
    lines = Grade.table(rows)
    overall = Grade.blocking?(rows, lines) ? :block : Grade.overall(lines)

    first = rows.first || {}
    out.puts
    out.puts RULE
    out.puts " 🧭 #{pr.id} · #{pr.role} · skill #{first['skill_sha']} · plugin #{first['plugin_version']} · effort #{first['effort']}"
    out.puts RULE
    out.puts " #{paint.(HEAD[overall], color[overall])}   over #{rows.size} repetition#{'s' unless rows.size == 1}" \
             " · #{all}/#{rows.size} passed every criterion"
    out.puts "     #{first['skill_sha']} is uncommitted prose: this batch is attributable to no sha" if first["skill_sha"].to_s.end_with?("+dirty")
    unless lines.empty?
      out.puts
      width = lines.map { |l| l.label.length }.max
      lines.each do |l|
        n = l.counts.values.sum
        extra = []
        extra << "#{l.counts[:unclear]} unclear" if l.counts[:unclear].positive?
        extra << "judge split on gold" if l.split
        out.puts format("   %-22s %d. %-#{width}s  %-5s  %s/%d  %s%s", l.judge, l.n, l.label, l.klass,
                        l.counts[:pass], n, paint.(STATUS[l.status], color.fetch(l.status, "0")),
                        extra.empty? ? "" : "  (#{extra.join(', ')})")
      end
      out.puts "   median repetition #{Grade.median_acceptable?(rows) ? 'acceptable' : 'NOT acceptable'} (≤ 2 form failures, no check FAIL)"
    end

    rows.zip(verdicts).each do |row, (status, reasons)|
      out.puts
      secs = row["generate_seconds"].to_i
      out.puts " r#{row['rep']}  #{paint.(BADGE[status], color[status])}   " \
               "#{format('%d:%02d', secs / 60, secs % 60)} to generate#{'  (re-judged)' if row['rejudged']}"
      reasons.each { |r| out.puts "     ↳ #{r}" }
      lines(row).each { |l| out.puts "     #{l}" }
    end

    out.puts
    out.puts " 📊 bin/evals report      📂 #{File.join(E2E::RESULTS, 'e2e.jsonl')}"
    out.puts RULE
    overall
  end

  def self.lines(row)
    rundir = row["rundir"].to_s
    page = File.join(rundir, "page", "index.html")
    l = []
    if File.exist?(page)
      cps = File.read(page, encoding: "UTF-8").gsub(/<!--.*?-->/m, "").scan(/<section class="cp\b/).size
      l << "📄 page         generated · #{cps} checkpoint#{'s' unless cps == 1}"
    else
      l << "📄 page         none"
    end
    if row["check_passed"]
      l << "🔬 checks       #{row['check_passed']} passed · #{row['check_failed']} failed · #{row['check_warning']} warning(s)"
      check = File.join(rundir, "check.txt")
      if File.exist?(check)
        File.foreach(check) do |c|
          l << "   #{c.start_with?('FAIL') ? '❌' : '⚠️ '} #{c.strip.sub(/\A(FAIL|WARN)\s+/, '')}" if c.start_with?("FAIL", "WARN")
        end
      end
    end
    (row["judges"] || {}).each do |name, j|
      cal = j["calibration"] == "calibrated" ? "calibrated" : "UNCALIBRATED · not counted"
      l << "⚖️  #{name}  (#{cal})"
      doc = begin
        j["verdicts"] && File.exist?(j["verdicts"]) ? Verdicts.read(j["verdicts"]) : nil
      rescue Verdicts::Unusable
        nil
      end
      unless doc
        l << "   ⚠️  no usable verdicts"
        next
      end
      labels = (Judge.load(name)[:meta]["criteria"] rescue []).map { |c| c.to_s[/\A[A-Z][A-Z ,]+[A-Z]/].to_s.capitalize }
      doc["verdicts"].each do |v|
        icon = { "pass" => "✅", "fail" => "❌", "unclear" => "❔" }.fetch(v["verdict"], "⚠️ ")
        label = labels[v["n"].to_i - 1]
        l << "   #{icon} #{v['n']}. #{label.to_s.empty? ? "criterion #{v['n']}" : label}"
        l << "        #{v['why']}" unless v["verdict"] == "pass"
      end
      l << "   📝 notes: #{doc['notes']}" unless doc["notes"].to_s.empty?
    end
    if row["changed_words"]
      within = row["changed_words_in_budget"] ? "within" : "outside"
      l << "✍️  §01          #{row['changed_words']} words, #{within} the 80–160 guidance"
    end
    l << "📂 #{page}" if File.exist?(page)
    l
  end
end
