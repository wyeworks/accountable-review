#!/usr/bin/env ruby
# frozen_string_literal: true

# calibrate.rb — does a judge say what a person already decided it should say?
#
#   e2e/calibrate.rb [<judge>] [-k N] [-j N] [--model M] [--id <calibration id>] [--variant NAME] [--keep]
#
# -j runs that many judge calls at once; they are independent, so it costs nothing but API load.
# --model overrides the judge's pinned model and -k below 3 samples too little to decide anything:
# either makes it a SMOKE pass — useful for finding a patch that plants nothing, before paying for
# the real one — and a smoke pass never writes status.json.
#
# A judge is an instrument, and an instrument nobody has checked against a known answer is a
# number generator. So each calibration PR in prs.yml carries, under calibration/<id>/:
#
#   gold.html            a real page of that PR, certified by a person criterion by criterion
#   gold.yml             provenance: plugin version and sha that produced it, who certified it, when
#   defects/*.patch      one unified diff each against gold.html, each planting EXACTLY ONE defect
#   labels.yml           the verdict a correct judge gives, per criterion, on gold and on each variant
#
# The judge runs K times (default 3) on gold and on every variant, inside a checkout of the PR at
# head — anchored exactly as it is in a real run. Two numbers come out, and both have to hold:
#
#   specificity  gold passes each criterion in at least ceil(2K/3) of K runs. A judge that fails
#                a page a person certified has invented a defect, and it will invent one on
#                every real page too.
#   sensitivity  each variant's planted criterion fails in at least ceil(2K/3) of K runs. A judge
#                that passes a planted defect is the check that always passes, in a new costume.
#
# Criteria a variant does not target are recorded and not gated: a planted defect can
# legitimately disturb a neighbouring criterion, and gating on that would make every patch
# responsible for being perfectly surgical.
#
# The result is written to calibration/status.json, keyed by judge and carrying the judge file's
# sha and the model. That file is committed: it is what run.rb and report.rb read to say whether
# a column is a measurement. Editing the judge's file changes its sha and uncalibrates it, which
# is the intended consequence.

require "optparse"
require "tmpdir"
require_relative "lib"
require_relative "judge"

opts = { k: 3, j: 1, keep: false }
OptionParser.new do |o|
  o.banner = "usage: calibrate.rb [<judge>] [-k N] [-j N] [--model M] [--id ID] [--variant NAME] [--keep]"
  o.on("-k N", Integer, "judge runs per page (default 3; below 3 is a smoke pass)") { |v| opts[:k] = v }
  o.on("-j N", Integer, "judge calls at once (default 1)") { |v| opts[:j] = v }
  o.on("--model M", "override the judge's pinned model (a smoke pass)") { |v| opts[:model] = v }
  o.on("--id ID", "one calibration PR (default: every calibration PR with a gold page)") { |v| opts[:id] = v }
  o.on("--variant NAME", "one variant only (gold always runs) — for iterating on a patch") { |v| opts[:variant] = v }
  o.on("--keep", "keep the worktree and the per-run output") { opts[:keep] = true }
end.parse!

judges = ARGV.empty? ? Dir[File.join(E2E::JUDGES, "*.md")].map { |f| File.basename(f, ".md") } - ["IDEAS"] : ARGV
prs = E2E.prs.select { |p| p.role == "calibration" && (opts[:id].nil? || p.id == opts[:id]) }
need = (2 * opts[:k] / 3.0).ceil

with_gold = prs.select { |p| File.exist?(File.join(E2E::CALIBRATION, p.id, "gold.html")) }
if with_gold.empty?
  abort <<~MSG
    calibrate: no calibration PR has a gold page yet. To make one:

      1. bin/evals e2e #{prs.first&.id || '<id>'} --no-judge --keep
      2. read the page it wrote against the code, criterion by criterion, for every judge
      3. if it is right, copy it to #{File.join(E2E::CALIBRATION, '<id>', 'gold.html')} and
         write gold.yml beside it; if it is not, regenerate rather than hand-edit it —
         a hand-tuned gold page calibrates the judge against what someone could write
      4. write defects/*.patch and labels.yml (calibration/README.md says how)
  MSG
end

smoke = !!(opts[:variant] || opts[:model] || opts[:k] < 3)
all_held = true
status_path = File.join(E2E::CALIBRATION, "status.json")
status = File.exist?(status_path) ? JSON.parse(File.read(status_path)) : {}

judges.each do |name|
  jmeta = Judge.load(name)
  model = opts[:model] || jmeta[:meta]["model"]
  ncrit = jmeta[:meta]["criteria"].length
  findings = []
  ok = true

  with_gold.each do |pr|
    dir = File.join(E2E::CALIBRATION, pr.id)
    labels = YAML.safe_load_file(File.join(dir, "labels.yml"))
    gold_labels = Array(labels.dig("gold", name))
    abort "calibrate: labels.yml has no gold labels for #{name}" if gold_labels.length != ncrit

    work = Dir.mktmpdir("calibrate-#{pr.id}-")
    repo = E2E.worktree(pr, File.join(work, "repo"), pr.head_sha)
    begin
      pages = { "gold" => File.join(dir, "gold.html") }
      Dir[File.join(dir, "defects", "*.patch")].sort.each do |patch|
        v = File.basename(patch, ".patch")
        next if opts[:variant] && v != opts[:variant]

        out = File.join(work, "#{v}.html")
        _, err, st = Open3.capture3("patch", "--quiet", "-o", out, pages["gold"], patch)
        abort "calibrate: #{patch} does not apply to gold.html — regenerate it against the current gold:\n#{err}" unless st.success?
        pages[v] = out
      end

      expected_for = {}
      pages.each do |variant, page|
        # A page lives in its own directory, as it does after a real run: the judge is handed
        # the page's directory with --add-dir, and a sibling variant must not be readable from it.
        pdir = File.join(work, "page-#{variant}")
        FileUtils.mkdir_p(pdir)
        FileUtils.cp(page, File.join(pdir, "index.html"))
      
        expected = gold_labels.dup
        unless variant == "gold"
          override = labels.dig("variants", variant, name) or abort "calibrate: labels.yml has no #{name} labels for variant #{variant}"
          override.each { |n, v| expected[Integer(n) - 1] = v }
        end
        expected_for[variant] = expected
      end
      
      got = Hash.new { |h, k| h[k] = Array.new(ncrit) { [] } }
      lock = Mutex.new
      jobs = Queue.new
      pages.each_key { |variant| opts[:k].times { |run| jobs << [variant, run] } }
      Array.new([opts[:j], jobs.size].min) do
        Thread.new do
          while (job = begin jobs.pop(true) rescue nil end)
            variant, run = job
            r = Judge.run(name, page: File.join(work, "page-#{variant}", "index.html"), repo: repo, base: pr.base_sha,
                                head: pr.head_sha, out: File.join(work, "out", variant, run.to_s), model: model)
            doc = r.usable ? Verdicts.read(r.verdicts_path) : nil
            lock.synchronize do
              doc&.fetch("verdicts")&.each { |v| got[variant][Integer(v["n"]) - 1] << v["verdict"] if v["n"].to_i.between?(1, ncrit) }
              E2E.append("calibration", "judge" => name, "judge_sha" => jmeta[:sha], "model" => model,
                                        "id" => pr.id, "variant" => variant, "run" => run, "usable" => r.usable,
                                        "verdicts" => doc && doc["verdicts"], "notes" => doc && doc["notes"])
              puts "  … #{variant} r#{run} #{r.usable ? 'done' : 'UNUSABLE'} (#{r.seconds}s)"
            end
          end
        end
      end.each(&:join)
      
      pages.each_key do |variant|
        expected = expected_for[variant]
        targeted = variant == "gold" ? (0...ncrit).to_a : (0...ncrit).select { |i| expected[i] != gold_labels[i] }
        (0...ncrit).each do |i|
          hits = got[variant][i].count(expected[i])
          gated = targeted.include?(i)
          pass = !gated || hits >= need
          ok &&= pass
          findings << { "id" => pr.id, "variant" => variant, "criterion" => i + 1, "expected" => expected[i],
                        "got" => got[variant][i], "gated" => gated, "held" => pass }
          mark = gated ? (pass ? "ok  " : "MISS") : "  · "
          puts format("%s %-8s %-34s c%d  want %-7s got %s", mark, name, variant, i + 1, expected[i], got[variant][i].join(","))
        end
      end
    ensure
      E2E.drop_worktree(pr, repo)
      FileUtils.rm_rf(work) unless opts[:keep]
    end
  end

  all_held &&= ok
  status[name] = { "judge_sha" => jmeta[:sha], "model" => model, "k" => opts[:k], "need" => need,
                   "calibrated" => ok && !smoke, "date" => Time.now.utc.iso8601,
                   "prs" => with_gold.map(&:id), "findings" => findings }
  verdict = ok ? (smoke ? "all held (smoke pass — not a calibration)" : "CALIBRATED") : "NOT calibrated"
  puts "\n#{name} @ #{jmeta[:sha]} · #{model}: #{verdict}"
end

# A smoke pass — one variant, a model other than the pinned one, or fewer than three runs — has
# calibrated nothing, so it must not overwrite a status that a full run earned.
if smoke
  puts "not written: #{status_path} (smoke pass)"
else
  File.write(status_path, JSON.pretty_generate(status) + "\n")
  puts "written: #{status_path}"
end
exit(smoke ? (all_held ? 0 : 1) : (status.values_at(*judges).all? { |s| s["calibrated"] } ? 0 : 1))
