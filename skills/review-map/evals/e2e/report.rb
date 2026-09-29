#!/usr/bin/env ruby
# frozen_string_literal: true

# report.rb — read results/e2e.jsonl and write one HTML page a person can read.
#
#   e2e/report.rb [--id ID] [--out FILE] [--history VERSION]
#
# Grouped by PR, then by (plugin version, skill sha, effort, producing model): a row measured on
# one version of the prose is never averaged into a row measured on another. Inside a group, each
# judge gets one column per criterion, the pass rate across repetitions — and a judge that
# calibrate.rb has not passed at its current sha and model is labelled UNCALIBRATED instead of
# being given a colour, because an uncalibrated judge's number is not a measurement yet.
#
# This page grades Review Maps, not pull requests; it borrows nothing from the page rules and it
# is never published. --history writes the same summary as JSON to e2e/history/<version>.json,
# which is the one thing here that is committed: results/ is gitignored, and a release has to be
# comparable with the one before it.

require "cgi"
require "optparse"
require_relative "lib"
require_relative "judge"
require_relative "verdicts"

opts = { out: File.join(E2E.out, "report.html") }
OptionParser.new do |o|
  o.on("--id ID") { |v| opts[:id] = v }
  o.on("--out FILE") { |v| opts[:out] = v }
  o.on("--history VERSION", "also write e2e/history/VERSION.json") { |v| opts[:history] = v }
end.parse!

rows = E2E.read("e2e")
rows.select! { |r| r["id"] == opts[:id] } if opts[:id]
abort "report: nothing in #{File.join(E2E::RESULTS, 'e2e.jsonl')} yet — bin/evals e2e <id> first" if rows.empty?

h = ->(s) { CGI.escapeHTML(s.to_s) }
link = ->(path, text) { path && File.exist?(path) ? %(<a href="file://#{h.(path)}">#{h.(text)}</a>) : h.(text) }
key = ->(r) { r.values_at("plugin_version", "skill_sha", "effort", "model") }

def verdict_doc(path)
  path && File.exist?(path) ? Verdicts.read(path) : nil
rescue Verdicts::Unusable
  nil
end

summary = []
body = +""

rows.group_by { |r| r["id"] }.each do |id, by_pr|
  body << %(<h2>#{h.(id)}</h2>)
  by_pr.group_by(&key).each do |(version, sha, effort, model), group|
    reps = group.length
    gen = group.count { |r| r["generated"] }
    body << %(<h3>#{h.(version)} · skill #{h.(sha)} · effort #{h.(effort)} · model #{h.(model)} · #{reps} rep(s)</h3>)
    body << %(<p class="meta">generated #{gen}/#{reps}.)
    body << " Check fails per run: #{group.map { |r| r['check_failed'] || '—' }.join(', ')}."
    words = group.filter_map { |r| r["changed_words"] }
    body << " §01 words: #{words.join(', ')} <span class=\"hint\">(budget 80–160, guidance)</span>." unless words.empty?
    secs = group.filter_map { |r| r["model_seconds"] }
    body << " Model seconds: #{secs.map(&:round).join(', ')}." unless secs.empty?
    body << "</p>"

    judges = group.flat_map { |r| (r["judges"] || {}).keys }.uniq.sort
    group_summary = { "id" => id, "plugin_version" => version, "skill_sha" => sha, "effort" => effort,
                      "model" => model, "reps" => reps, "generated" => gen, "judges" => {} }

    judges.each do |jn|
      entries = group.filter_map { |r| r.dig("judges", jn) }
      cal = entries.map { |e| e["calibration"] }.uniq
      calibrated = cal == ["calibrated"]
      docs = entries.map { |e| verdict_doc(e["verdicts"]) }
      ncrit = entries.map { |e| e["criteria"].to_i }.max
      criteria = (Judge.load(jn)[:meta]["criteria"] rescue [])

      body << %(<h4>#{h.(jn)} #{calibrated ? '<span class="cal">calibrated</span>' : '<span class="uncal">UNCALIBRATED — not a measurement</span>'}</h4>)
      body << %(<table><tr><th>criterion</th><th>pass rate</th>#{docs.each_index.map { |i| "<th>r#{i + 1}</th>" }.join}</tr>)
      rates = {}
      (1..ncrit).each do |n|
        vs = docs.map { |d| d && d["verdicts"].find { |v| v["n"].to_i == n } }
        passes = vs.count { |v| v && v["verdict"] == "pass" }
        usable = vs.count { |v| v }
        rates[n] = usable.zero? ? nil : (passes.to_f / usable).round(2)
        rate = rates[n] ? "#{passes}/#{usable}" : "—"
        cls = calibrated && rates[n] ? (rates[n] == 1 ? "good" : rates[n].zero? ? "bad" : "mixed") : "plain"
        label = criteria[n - 1].to_s[/\A[A-Z][A-Z ,]+[A-Z]/] || "criterion #{n}"
        cells = vs.map do |v|
          next "<td>unusable</td>" unless v

          %(<td class="v-#{h.(v['verdict'])}"><b>#{h.(v['verdict'])}</b><div class="why">#{h.(v['why'])}</div>) +
            (v["evidence"].to_s.empty? ? "" : %(<div class="ev">#{h.(v['evidence'])}</div>)) + "</td>"
        end
        body << %(<tr><td class="crit">#{n}. #{h.(label)}</td><td class="#{cls}">#{rate}</td>#{cells.join}</tr>)
      end
      body << "</table>"
      notes = docs.each_with_index.filter_map { |d, i| d && !d["notes"].to_s.empty? ? "r#{i + 1}: #{d['notes']}" : nil }
      body << %(<div class="notes"><b>notes — read before the verdicts</b><ul>#{notes.map { |n| "<li>#{h.(n)}</li>" }.join}</ul></div>) unless notes.empty?
      group_summary["judges"][jn] = { "judge_sha" => entries.first["judge_sha"], "model" => entries.first["model"],
                                      "calibrated" => calibrated, "pass_rate" => rates }
    end

    body << "<ul class=\"runs\">"
    group.each do |r|
      rd = r["rundir"].to_s
      body << "<li>r#{r['rep']} #{h.(r['batch'])}: " +
              [link.(File.join(rd, "page", "index.html"), "page"), link.(File.join(rd, "check.txt"), "check"),
               link.(File.join(rd, "profile.txt"), "profile"), link.(File.join(rd, "generate-head.log"), "log")].join(" · ") +
              "</li>"
    end
    body << "</ul>"
    summary << group_summary
  end
end

html = <<~HTML
  <!doctype html><meta charset="utf-8"><title>Review Map evals</title>
  <style>
    :root{--bg:#fbfaf7;--ink:#1d1d1b;--mute:#6b6a64;--rule:#dedbd2;--good:#dff0dc;--bad:#f6dcd6;--mixed:#f5ecd0}
    @media (prefers-color-scheme:dark){:root{--bg:#1b1b19;--ink:#e9e7e0;--mute:#a19f97;--rule:#3a3935;--good:#23402a;--bad:#4a2a24;--mixed:#44391d}}
    body{background:var(--bg);color:var(--ink);font:14px/1.5 system-ui,sans-serif;margin:0;padding:24px 20px;max-width:1200px}
    h1{font-size:22px}h2{margin-top:36px;border-top:1px solid var(--rule);padding-top:16px}
    table{border-collapse:collapse;width:100%;margin:8px 0}td,th{border:1px solid var(--rule);padding:6px 8px;vertical-align:top;text-align:left}
    .crit{width:22%}.why{color:var(--mute)}.ev{font-family:ui-monospace,monospace;font-size:12px;margin-top:4px}
    .good{background:var(--good)}.bad{background:var(--bad)}.mixed{background:var(--mixed)}
    .v-fail b{color:#b3401f}.v-unclear b{color:#8a6d00}.uncal{color:#b3401f;font-size:12px}.cal{color:#2c7a3f;font-size:12px}
    .meta,.hint{color:var(--mute)}.notes{border-left:3px solid var(--rule);padding-left:12px}
    a{color:inherit}.wrap{overflow-x:auto}
  </style>
  <h1>Review Map evals</h1>
  <p class="meta">These grade the pages, never the pull requests. Written #{Time.now.utc.iso8601} from #{h.(File.join(E2E::RESULTS, 'e2e.jsonl'))}.</p>
  <div class="wrap">#{body}</div>
HTML

FileUtils.mkdir_p(File.dirname(opts[:out]))
File.write(opts[:out], html)
puts "report: #{opts[:out]}"

if opts[:history]
  path = File.join(E2E::HERE, "history", "#{opts[:history]}.json")
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, JSON.pretty_generate(summary) + "\n")
  puts "history: #{path}"
end
