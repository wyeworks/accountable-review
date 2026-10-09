#!/usr/bin/env ruby
# frozen_string_literal: true

# run.rb — generate a Review Map of a real pull request, check it, judge it, record it.
#
#   e2e/run.rb <id> [-n N] [-j N] [--effort high|low] [--model M] [--no-judge] [--keep]
#   e2e/run.rb <id> --rejudge RUNDIR   # check and judge a run that already exists; no generation
#   e2e/run.rb --list
#
# One repetition is:
#
#   1. a detached worktree of the PR's repository at head, from a blobless clone in $EVAL_CACHE;
#   2. ci/generate-review-map.sh --output, which is the skill run exactly as CI runs it — the one
#      non-interactive path, and the reason this harness does not share the old one's blind spot
#      (under a bare `claude -p` there is no Artifact tool, so a run could not do its last step);
#   3. check.rb --final over the page, with --repo and --base;
#   4. every judge in judges/, blind to step 3;
#   5. profile.sh over the pinned session, parent and subagents;
#   6. one line in results/e2e.jsonl, stamped.
#
# Everything a repetition produced stays in its run directory under $EVAL_OUT, and report.rb
# links to it. The worktree is removed afterwards unless --keep, because a Discourse checkout per
# repetition is the one thing here that costs disk rather than tokens.
#
# The adapter needs a model credential in the environment — ANTHROPIC_API_KEY, or the
# CLAUDE_CODE_OAUTH_TOKEN that `claude setup-token` prints — because it is written for a runner
# where nobody is logged in. It says so and stops if there is none; so does this, first.

require "optparse"
require "securerandom"
require_relative "lib"
require_relative "judge"
require_relative "progress"
require_relative "summary"

opts = { n: 1, j: 1, judge: true, keep: false }
OptionParser.new do |o|
  o.banner = "usage: run.rb <id> [-n N] [-j N] [--effort high|low] [--model M] [--no-judge] [--keep]"
  o.on("-n N", Integer, "repetitions (default 1; 3 before believing a number)") { |v| opts[:n] = v }
  o.on("-j N", Integer, "run this many at once") { |v| opts[:j] = v }
  o.on("--effort E", %w[high low], "the skill's --effort (default: the skill's own, high)") { |v| opts[:effort] = v }
  o.on("--model M", "the PRODUCING model; the judge's is pinned in its file") { |v| opts[:model] = v }
  o.on("--no-judge", "generate and check only") { opts[:judge] = false }
  o.on("--keep", "keep the worktree") { opts[:keep] = true }
  o.on("--rejudge DIR", "re-check and re-judge an existing run directory instead of generating") { |v| opts[:rejudge] = File.expand_path(v) }
  o.on("--list", "list the PRs in prs.yml") do
    E2E.prs.each { |p| puts format("%-20s %-11s %-6s %s#%d", p.id, p.role, p.stack, p.repo, p.pr) }
    exit 0
  end
end.parse!

id = ARGV.shift or abort("usage: run.rb <id> [-n N] … (run.rb --list for the ids)")
pr = E2E.pr(id)

creds = %w[ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX]
if !opts[:rejudge] && creds.none? { |k| ENV[k].to_s != "" }
  abort <<~MSG
    e2e: no model credential in the environment. ci/generate-review-map.sh is written for a
    runner nobody is logged into, so it reads one from the environment rather than your login:

      export CLAUDE_CODE_OAUTH_TOKEN=$(claude setup-token)   # bills your subscription
      # or ANTHROPIC_API_KEY=…                               # bills the API

    Nothing was generated.
  MSG
end

stamp = {
  "plugin_version" => E2E.plugin_version,
  "skill_sha" => E2E.skill_sha,
  "effort" => opts[:effort] || "high",
  "model" => opts[:model] || "ambient",
}
E2E.clone(pr) # once, before any thread needs it
batch = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")

def generate(pr, rundir, repo, head, opts, label, live = nil)
  session = SecureRandom.uuid
  live&.generating(session, File.join(rundir, "page", "index.html"))
  wrapper = File.join(rundir, "claude-#{label}")
  model = opts[:model] ? " --model '#{opts[:model]}'" : ""
  File.write(wrapper, "#!/bin/sh\nexec #{ENV.fetch('CLAUDE_BIN', 'claude')} --session-id #{session}#{model} \"$@\"\n")
  File.chmod(0o755, wrapper)

  cmd = [File.join(E2E::ROOT, "ci", "generate-review-map.sh"),
         "--output", File.join(rundir, "page"), "--repository", pr.repo, "--pr", pr.pr.to_s,
         "--base-sha", pr.base_sha, "--head-sha", head,
         "--repo-dir", repo, "--plugin-dir", E2E::ROOT, "--claude-bin", wrapper]
  cmd += ["--effort", opts[:effort]] if opts[:effort]
  started = Time.now
  log, st = Open3.capture2e(*cmd)
  File.write(File.join(rundir, "generate-#{label}.log"), log)
  [st.success?, session, (Time.now - started).round(1)]
end

def profile(rundir, session)
  prof = File.join(E2E::EVALS, "profile.sh")
  # --all is exact here rather than loose: the session is pinned to this one run, so there is no
  # neighbouring work for the attributionSkill filter to exclude.
  json, st = Open3.capture2e(prof, "--session", session, "--all", "--json")
  File.write(File.join(rundir, "profile.json"), json)
  txt, = Open3.capture2e(prof, "--session", session, "--all")
  File.write(File.join(rundir, "profile.txt"), txt)
  return {} unless st.success?

  p = JSON.parse(json)
  { "requests" => p["requests"], "model_seconds" => p["model_s"], "tool_seconds" => p["tool_s"],
    "ttft_seconds" => p["ttft_s"], "stream_seconds" => p["stream_s"],
    "output_tokens" => p["out_tokens"], "thinking_tokens" => p["think_tokens"] }
rescue JSON::ParserError
  {}
end

def repetition(pr, opts, stamp, batch, rep)
  live = $live[rep]
  rundir = opts[:rejudge] || File.join(E2E.out, pr.id, "#{batch}-r#{rep}")
  FileUtils.mkdir_p(rundir)
  repo = File.join(rundir, "repo")
  row = stamp.merge("id" => pr.id, "rep" => rep, "batch" => batch, "rundir" => rundir,
                    "head_sha" => pr.head_sha, "base_sha" => pr.base_sha)
  started = Time.now
  made_worktree = false

  begin
    if opts[:rejudge]
      # The page was produced by whatever prose was current when it was generated, so the stamp
      # is that run's, not this checkout's: a re-judged line must never attribute an old page to
      # a new sha. The generation fields are carried over and nothing is regenerated.
      original = E2E.read("e2e").reverse.find { |o| o["rundir"] == rundir && !o["rejudged"] }
      abort "e2e: no recorded run for #{rundir} in results/e2e.jsonl" unless original
      row.merge!(original.slice("plugin_version", "skill_sha", "effort", "model", "batch", "rep", "session",
                                "generated", "generate_seconds", "requests", "model_seconds", "tool_seconds",
                                "ttft_seconds", "stream_seconds", "output_tokens", "thinking_tokens"))
      row["rejudged"] = Time.now.utc.iso8601
      unless File.directory?(repo)
        E2E.worktree(pr, repo, pr.head_sha)
        made_worktree = true
      end
      page = File.join(rundir, "page", "index.html")
      abort "e2e: no page at #{page}" unless File.exist?(page)
      session = nil
    end
    unless opts[:rejudge]
    E2E.worktree(pr, repo, pr.update_from || pr.head_sha)
    if pr.update_from
      ok, s0, = generate(pr, rundir, repo, pr.update_from, opts, "first", live)
      row["first_session"] = s0
      row["first_generated"] = ok
      E2E.sh!("git", "-C", repo, "checkout", "--quiet", "--detach", pr.head_sha)
    end
    ok, session, gen_s = generate(pr, rundir, repo, pr.head_sha, opts, "head", live)
    row.merge!("session" => session, "generated" => ok, "generate_seconds" => gen_s)
    File.write(File.join(rundir, "session"), session) # so `bin/evals profile --rundir` finds it
    page = File.join(rundir, "page", "index.html")
    made_worktree = true
    end

    if File.exist?(page)
      live.phase = "🔬 checking the page"
      check_out, = Open3.capture2e(File.join(E2E::EVALS, "check.rb"), "--final", "--page", page,
                                   "--repo", repo, "--base", pr.base_sha)
      File.write(File.join(rundir, "check.txt"), check_out)
      tally = check_out.lines.grep(/passed, \d+ failed/).last.to_s
      %w[passed failed warning skipped].each do |k|
        row["check_#{k}"] = tally[/(\d+) #{k}/, 1]&.to_i
      end

      html = File.read(page)
      if (sec = E2E.section(html, "changed"))
        words = E2E.prose_words(sec)
        row["changed_words"] = words
        row["changed_words_in_budget"] = words.between?(80, 160)
      end

      if opts[:judge]
        Dir[File.join(E2E::JUDGES, "*.md")].reject { |f| File.basename(f) == "IDEAS.md" }.sort.each do |jf|
          name = File.basename(jf, ".md")
          live.phase = "⚖️  judging #{name}"
          r = Judge.run(name, page: page, repo: repo, base: pr.base_sha, head: pr.head_sha,
                              out: File.join(rundir, "judges"))
          row["judges"] ||= {}
          row["judges"][name] = {
            "judge_sha" => r.judge_sha, "model" => r.model, "usable" => r.usable,
            "criteria" => r.criteria, "counts" => r.counts, "verdicts" => r.verdicts_path,
            "calibration" => Judge.calibration(name, r.judge_sha, r.model),
            "seconds" => r.seconds, "cost_usd" => r.cost_usd
          }
        end
      end
    end

    live.phase = "📊 profiling" if session
    row.merge!(profile(rundir, session)) if session
  ensure
    E2E.drop_worktree(pr, repo) if made_worktree && !opts[:keep]
    row["seconds"] = (Time.now - started).round(1)
    E2E.append("e2e", row)
    $rows_lock.synchronize { $rows << row }
  end

  judged = (row["judges"] || {}).map do |n, j|
    c = j["counts"]
    c ? "#{n} #{c['pass']}/#{c['fail']}/#{c['unclear']} (#{j['calibration']})" : "#{n} unusable"
  end
  live.failed = !row["generated"] || !File.exist?(File.join(rundir, "page", "index.html"))
  live.finished = true
  live.phase = live.failed ? "no page" : "done" # the row's icon already says which
  $board.say "#{live.failed ? '💥' : '✅'} #{pr.id} r#{rep}: generated=#{row['generated']} · check #{row['check_passed']}p/#{row['check_failed']}f/" \
       "#{row['check_warning']}w · §01 #{row['changed_words'] || '-'} words · #{judged.join(', ')} · #{rundir}"
end

eta = Progress.eta(E2E.read("e2e"), pr.id)
$rows = []
$rows_lock = Mutex.new
$live = (1..(opts[:rejudge] ? 1 : opts[:n])).to_h { |i| [i, Progress::Rep.new(i, eta)] }
$board = Progress::Board.new(pr.id, $live.values).start
at_exit { $board.stop }

if opts[:rejudge]
  repetition(pr, opts, stamp, batch, 1)
  $board.stop
  exit(Summary.print(pr, $rows) == :fail ? 1 : 0)
end

queue = Queue.new
(1..opts[:n]).each { |i| queue << i }
workers = Array.new([opts[:j], opts[:n]].min) do
  Thread.new do
    while (rep = begin queue.pop(true) rescue nil end)
      repetition(pr, opts, stamp, batch, rep)
    end
  end
end
workers.each(&:join)
$board.stop
# Exit 1 only on a FAIL. A LOOK — a calibrated judge that could not tell — exits 0, because a
# person has to read it and a red exit would say the page was wrong when nobody knows yet.
exit(Summary.print(pr, $rows) == :fail ? 1 : 0)
