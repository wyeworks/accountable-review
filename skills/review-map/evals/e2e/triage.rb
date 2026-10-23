#!/usr/bin/env ruby
# frozen_string_literal: true

# triage.rb — the readings evals/README.md § What counts as good leaves to a person, as one local
# HTML page to work through.
#
#   e2e/triage.rb [--id ID] [--out FILE] [--adjudications FILE]
#
# report.rb answers "how did this sha grade"; this page answers "what do I have to read before
# that answer stands". Its queue is every verdict the bar hands to a person:
#
#   claim    a TRUTH criterion's failure — the judge says a sentence on the page is false. One per
#            criterion is "read by a person", two block; either way the evidence is checked
#            against the repository before the sha goes anywhere, because a judge error is not a
#            false sentence and a confirmed false sentence blocks whatever the rate says.
#   unclear  a calibrated judge that could not tell — a pass nobody has given yet.
#   note     the judge saying the CRITERION is the problem. Read before the verdicts.
#
# Beneath the queue, off by default: form and deferred failures, check.rb WARN/FAIL lines, and
# every uncalibrated judge's verdicts — shown so a reading can use them, never counted.
#
# Every item links to what settles it: the generated page (with a text fragment on the quoted
# sentence, so the browser scrolls to it), the file:line in its evidence as a GitHub permalink at
# the PR's pinned head — a bare file name resolved against the cached clone when it names one file
# — and the run's check.txt and raw verdicts.
#
# A reading is a decision on an item, kept in the browser's localStorage and exported as JSON.
# Pass that file back with --adjudications (default results/adjudications.json) and the page opens
# with the readings already in it; the newer of the two wins per item. The page recomputes each
# truth criterion's status from the readings — a confirmed false sentence blocks, a judge error
# comes off the count — and says so beside the status grade.rb gave, never instead of it: the
# readings are a person's and the file is the record of them, not a new grade.
#
# Like report.rb, this grades Review Maps, never pull requests, and it is never published.

require "cgi"
require "erb"
require "optparse"
require_relative "lib"
require_relative "judge"
require_relative "verdicts"
require_relative "grade"

module Triage
  QUEUE = %w[claim unclear note].freeze

  # The decisions a reading can take, per kind: the key the page stores, and its label.
  DECISIONS = {
    "claim" => [["false", "confirmed false — blocks"], ["judge-error", "judge error — the sentence holds"], ["unsettled", "can't settle it"]],
    "unclear" => [["holds", "the page holds"], ["wrong", "the page is wrong"], ["ill-posed", "the criterion is ill-posed"]],
    "note" => [["read", "read"], ["criterion-fix", "the criterion needs fixing"]],
    "form" => [["agree", "agree"], ["judge-error", "judge error"]],
    "deferred" => [["agree", "agree"], ["judge-error", "judge error"]],
    "check" => [["read", "read"]]
  }.freeze

  CITE = %r{(?<![\w/.-])((?:[\w.@+-]+/)*[\w.@+-]+\.[A-Za-z0-9]+):(\d+)(?:[-–](\d+))?}
  QUOTE = /"([^"]{12,})"|“([^”]{12,})”/

  def self.group_key(r) = r.values_at("plugin_version", "skill_sha", "effort", "model").map(&:to_s).join(" · ")

  # A percent-encoding for a text fragment: everything but unreserved, and `-` too, which the
  # directive syntax reserves.
  def self.fragment(text)
    words = text.gsub(/\s+/, " ").strip.split
    enc = ->(s) { ERB::Util.url_encode(s).gsub("-", "%2D") }
    return enc.(words.join(" ")) if words.size <= 10

    "#{enc.(words.first(5).join(' '))},#{enc.(words.last(5).join(' '))}"
  end

  # file:line tokens and quoted page text in a verdict's evidence, as links. files: the repository's
  # paths at head, or nil when no clone is cached — then only a token with a directory is linked.
  def self.evidence_links(text, pr:, files:, page:)
    links = []
    text.to_s.scan(CITE) do |path, from, to|
      full = if path.include?("/") && (files.nil? || files.include?(path)) then path
             elsif files then (m = files.select { |f| f == path || f.end_with?("/#{path}") }).size == 1 ? m.first : nil
             end
      next unless full && pr

      anchor = to ? "#L#{from}-L#{to}" : "#L#{from}"
      links << { "text" => "#{full}:#{from}#{to ? "-#{to}" : ''}", "href" => "https://github.com/#{pr.repo}/blob/#{pr.head_sha}/#{full}#{anchor}", "kind" => "code" }
    end
    if page
      text.to_s.scan(QUOTE) do |a, b|
        q = (a || b).strip
        links << { "text" => "find “#{q.length > 48 ? "#{q[0, 47]}…" : q}” on the page", "href" => "file://#{page}#:~:text=#{fragment(q)}", "kind" => "page" }
      end
    end
    links.uniq { |l| l["href"] }
  end

  def self.files_at_head(pr)
    dir = File.join(E2E.cache, pr.repo.tr("/", "_"))
    return nil unless File.directory?(File.join(dir, ".git"))

    out, ok = Open3.capture2("git", "-C", dir, "ls-tree", "-r", "--name-only", pr.head_sha, err: File::NULL)
    ok.success? ? out.split("\n") : nil
  end

  def self.kind_of(klass, verdict)
    return "unclear" if verdict == "unclear"
    return nil unless verdict == "fail"

    { "truth" => "claim", "form" => "form", "deferred" => "deferred" }.fetch(klass, "form")
  end

  def self.id(*parts) = Digest::SHA256.hexdigest(parts.join("\0"))[0, 16]

  # Everything the page renders, as plain data: {"groups" => [...], "items" => [...]}.
  def self.build(rows, classes: Grade.classes, splits: Grade.split_on_gold, pr_of: ->(id) { E2E.pr(id) rescue nil },
                 files_of: ->(pr) { files_at_head(pr) })
    files = Hash.new { |h, pr| h[pr] = files_of.(pr) }
    items = []
    groups = rows.group_by { |r| group_key(r) }.sort_by { |_k, g| g.map { |r| r["batch"].to_s }.max.to_s }.reverse

    out_groups = groups.map do |key, group|
      group.sort_by { |r| [r["id"].to_s, r["rep"].to_i] }.each do |r|
        pr = pr_of.(r["id"])
        rd = r["rundir"].to_s
        page = File.join(rd, "page", "index.html")
        page = nil unless File.exist?(page)
        base = { "group" => key, "pr" => r["id"], "rep" => r["rep"], "batch" => r["batch"],
                 "repo" => pr&.repo, "number" => pr&.pr, "head" => pr&.head_sha,
                 "page" => page, "check" => (c = File.join(rd, "check.txt")) && File.exist?(c) ? c : nil }

        (r["judges"] || {}).sort.each do |name, j|
          calibrated = j["calibration"] == "calibrated"
          doc = begin
            j["verdicts"] ? Verdicts.read(j["verdicts"]) : nil
          rescue Verdicts::Unusable
            nil
          end
          unless doc
            items << base.merge("id" => id(rd, name, "unusable"), "kind" => "check", "judge" => name, "calibrated" => calibrated,
                                "title" => "#{name} returned no usable verdicts", "why" => "", "evidence" => "", "links" => [])
            next
          end
          doc["verdicts"].each do |v|
            n = v["n"].to_i
            klass = (Grade.klass(name, n, classes) rescue "form")
            kind = kind_of(klass, v["verdict"])
            next unless kind

            items << base.merge("id" => id(rd, name, n), "kind" => kind, "judge" => name, "n" => n, "label" => Grade.label(name, n),
                                "class" => klass, "calibrated" => calibrated, "split" => Array(splits[name]).include?(n),
                                "verdict" => v["verdict"], "why" => v["why"].to_s, "evidence" => v["evidence"].to_s,
                                "verdicts" => j["verdicts"],
                                "links" => evidence_links(v["evidence"], pr: pr, files: pr && files[pr], page: page))
          end
          next if doc["notes"].to_s.strip.empty?

          items << base.merge("id" => id(rd, name, "notes"), "kind" => "note", "judge" => name, "calibrated" => calibrated,
                              "why" => doc["notes"].to_s, "evidence" => "", "verdicts" => j["verdicts"],
                              "links" => evidence_links(doc["notes"], pr: pr, files: pr && files[pr], page: page))
        end

        next unless base["check"]

        File.foreach(base["check"]) do |line|
          next unless line.start_with?("FAIL", "WARN")

          items << base.merge("id" => id(rd, "check", line), "kind" => "check", "judge" => "check.rb", "calibrated" => true,
                              "title" => line.start_with?("FAIL") ? "check FAIL" : "check WARN",
                              "why" => line.strip.sub(/\A(FAIL|WARN)\s+/, ""), "evidence" => "", "links" => [])
        end
      end

      lines = Grade.table(group, classes: classes, splits: splits)
      { "key" => key, "reps" => group.size, "prs" => group.map { |r| r["id"] }.uniq.sort,
        "dirty" => key.include?("+dirty"),
        "overall" => (Grade.blocking?(group, lines, classes: classes) ? "block" : Grade.overall(lines).to_s),
        "criteria" => lines.map do |l|
          { "judge" => l.judge, "n" => l.n, "label" => l.label, "class" => l.klass, "status" => l.status.to_s,
            "pass" => l.counts[:pass], "fail" => l.counts[:fail], "unclear" => l.counts[:unclear], "split" => l.split }
        end }
    end

    { "groups" => out_groups, "items" => items, "decisions" => DECISIONS }
  end

  # Readings from a file earlier exported by the page: {id => {"decision", "note", "at"}}.
  def self.adjudications(path)
    return {} unless path && File.exist?(path)

    doc = JSON.parse(File.read(path))
    doc.is_a?(Hash) ? (doc["readings"] || doc) : {}
  rescue JSON::ParserError
    warn "triage: #{path} is not JSON — opening with no readings"
    {}
  end

  # JSON safe inside a <script> element.
  def self.embed(obj) = JSON.generate(obj).gsub("</", "<\\/").gsub("\u2028", "\\u2028").gsub("\u2029", "\\u2029")

  def self.html(data, readings:, source:)
    # Block form throughout: a replacement STRING reads \1 and \0 in the data as back-references.
    File.read(File.join(__dir__, "triage.html"), encoding: "UTF-8")
        .sub("/*DATA*/null") { embed(data) }.sub("/*READINGS*/null") { embed(readings) }
        .sub("<!--SOURCE-->") { CGI.escapeHTML(source) }.sub("<!--WRITTEN-->") { Time.now.utc.iso8601 }
  end
end

if $PROGRAM_NAME == __FILE__
  opts = { out: File.join(E2E.out, "triage.html"), adjudications: File.join(E2E::RESULTS, "adjudications.json") }
  OptionParser.new do |o|
    o.on("--id ID") { |v| opts[:id] = v }
    o.on("--out FILE") { |v| opts[:out] = v }
    o.on("--adjudications FILE", "readings exported from the page (default results/adjudications.json)") { |v| opts[:adjudications] = v }
  end.parse!

  rows = E2E.runs(E2E.read("e2e"))
  rows.select! { |r| r["id"] == opts[:id] } if opts[:id]
  abort "triage: nothing in #{File.join(E2E::RESULTS, 'e2e.jsonl')} yet — bin/evals e2e <id> first" if rows.empty?

  data = Triage.build(rows)
  readings = Triage.adjudications(opts[:adjudications])
  FileUtils.mkdir_p(File.dirname(opts[:out]))
  File.write(opts[:out], Triage.html(data, readings: readings, source: File.join(E2E::RESULTS, "e2e.jsonl")))
  queue = data["items"].count { |i| Triage::QUEUE.include?(i["kind"]) && i["calibrated"] }
  read = data["items"].count { |i| Triage::QUEUE.include?(i["kind"]) && i["calibrated"] && readings.key?(i["id"]) }
  puts "triage: #{opts[:out]}"
  puts "        #{queue} item(s) for a person, #{read} already read#{readings.empty? ? '' : " (readings from #{opts[:adjudications]})"}"
end
