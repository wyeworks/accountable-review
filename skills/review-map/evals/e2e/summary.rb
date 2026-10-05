# frozen_string_literal: true

# summary.rb — what run.rb prints when it is done: did the page pass, and if not, why.
#
# A repetition PASSES when three things hold, and the summary says which one did not:
#
#   1. a page was generated;
#   2. check.rb reported no FAIL;
#   3. every criterion of every CALIBRATED judge came back pass.
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
# could not tell, and the summary marks the repetition as needing a look rather than guessing on
# its behalf. This grades the PAGE, never the pull request, like everything in this directory.

require_relative "judge"
require_relative "verdicts"

module Summary
  RULE = "━" * 64

  # :pass, :fail, or :look — and the reasons behind anything but :pass.
  def self.verdict(row)
    reasons = []
    look = []
    page = File.join(row["rundir"].to_s, "page", "index.html")
    reasons << "no page was generated" unless row["generated"] && File.exist?(page)
    reasons << "check.rb reported #{row['check_failed']} failure(s)" if row["check_failed"].to_i.positive?
    (row["judges"] || {}).each do |name, j|
      next unless j["calibration"] == "calibrated"

      if !j["usable"]
        reasons << "#{name} returned no usable verdicts"
      elsif j.dig("counts", "fail").to_i.positive?
        reasons << "#{name} failed #{j.dig('counts', 'fail')} criterion/criteria"
      elsif j.dig("counts", "unclear").to_i.positive?
        look << "#{name} was unclear on #{j.dig('counts', 'unclear')} criterion/criteria"
      end
    end
    status = if reasons.any? then :fail
             elsif look.any? then :look
             else :pass
             end
    [status, reasons + look]
  end

  BADGE = { pass: "✅ PASS", fail: "❌ FAIL", look: "🔍 LOOK" }.freeze

  def self.print(pr, rows, out: $stdout)
    tty = out.tty?
    paint = ->(s, code) { tty ? "\e[#{code}m#{s}\e[0m" : s }
    color = { pass: "1;32", fail: "1;31", look: "1;33" }

    rows = rows.sort_by { |r| r["rep"].to_i }
    verdicts = rows.map { |r| verdict(r) }
    passed = verdicts.count { |v, _| v == :pass }
    overall = if verdicts.any? { |v, _| v == :fail } then :fail
              elsif verdicts.any? { |v, _| v == :look } then :look
              else :pass
              end

    first = rows.first || {}
    out.puts
    out.puts RULE
    out.puts " 🧭 #{pr.id} · #{pr.role} · skill #{first['skill_sha']} · plugin #{first['plugin_version']} · effort #{first['effort']}"
    out.puts RULE
    out.puts " #{paint.(BADGE[overall], color[overall])}   #{passed}/#{rows.size} repetition#{'s' unless rows.size == 1} passed"

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
