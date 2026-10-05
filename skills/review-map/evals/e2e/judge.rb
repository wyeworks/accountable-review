#!/usr/bin/env ruby
# frozen_string_literal: true

# judge.rb — one judge, one page, one set of verdicts.
#
#   e2e/judge.rb <judge> --page P --repo R --base SHA --head SHA [--out DIR] [--model M]
#
# <judge> names judges/<judge>.md: YAML front matter carrying the pinned model, the section it
# grades and its criteria, then the prompt. Prints the tally and exits 0 when the verdict file is
# usable, 1 when it is not — a failed criterion is a finding, not an error.
#
# Three properties carried over from the judge this replaced, because they are what made its
# verdicts worth anything:
#
#   * ANCHORED. It runs inside the checkout at head with read-only tools, so "is this claim true"
#     is settled by opening the file the claim is about. Without that it is a second opinion
#     about prose.
#   * BLIND to the mechanical results. check.rb's output is never in the prompt: two independent
#     readings beat one reading anchored to the other.
#   * UNAMBITIOUS about format. A fenced or prose-wrapped answer is recovered by verdicts.rb, and
#     the raw reply is kept beside the parsed one, because how the judge answered is evidence too.
#
# It cannot load a skill (--disable-slash-commands) or an MCP server (--strict-mcp-config): a
# judge whose environment has this plugin installed must not be able to invoke review-map on the
# page it is meant to be grading.

require "optparse"
require "tmpdir"
require_relative "lib"
require_relative "verdicts"

module Judge
  Result = Struct.new(:judge, :judge_sha, :model, :counts, :criteria, :verdicts_path, :usable,
                      :session, :cost_usd, :seconds, keyword_init: true)

  def self.load(name)
    path = File.join(E2E::JUDGES, "#{name}.md")
    abort "judge: no judge at #{path}" unless File.exist?(path)

    text = File.read(path)
    front, body = text.match(/\A---\n(.*?)\n---\n(.*)\z/m)&.captures
    abort "judge: #{path} has no front matter" unless front

    meta = YAML.safe_load(front)
    { path: path, sha: E2E.file_sha(path), meta: meta, body: body }
  end

  def self.run(name, page:, repo:, base:, head:, out:, model: nil, claude: ENV.fetch("CLAUDE_BIN", "claude"))
    j = load(name)
    model ||= j[:meta]["model"]
    criteria = j[:meta]["criteria"]
    FileUtils.mkdir_p(out)

    html = File.read(page)
    section_path = File.join(out, "#{name}.section.html")
    File.write(section_path, E2E.section(html, j[:meta]["section"]) || "<!-- no section id=#{j[:meta]['section']} on the page -->")

    list = criteria.each_with_index.map { |c, i| "#{i + 1}. #{c.strip}" }.join("\n\n")
    prompt = j[:body].gsub("{{CRITERIA}}", list)
    prompt = prompt.gsub("{{PAGE}}", File.expand_path(page)).gsub("{{SECTION}}", section_path)
                   .gsub("{{BASE}}", base).gsub("{{HEAD}}", head)

    cmd = [claude, "-p", prompt,
           "--model", model,
           "--output-format", "json",
           "--add-dir", File.dirname(File.expand_path(page)), "--add-dir", out,
           "--allowedTools", "Read,Grep,Glob,Bash(git diff:*),Bash(git show:*),Bash(git log:*),Bash(git grep:*)",
           "--disallowedTools", "Edit,Write,NotebookEdit,WebFetch,WebSearch,Agent,Task",
           "--disable-slash-commands", "--strict-mcp-config"]
    started = Time.now
    stdout, stderr, status = Open3.capture3(*cmd, chdir: repo)
    seconds = (Time.now - started).round(1)
    File.write(File.join(out, "#{name}.stderr.txt"), stderr) unless stderr.empty?

    envelope = begin
      JSON.parse(stdout)
    rescue JSON::ParserError
      {}
    end
    raw = envelope["result"] || stdout
    File.write(File.join(out, "#{name}.raw.txt"), raw.to_s)

    verdicts_path = File.join(out, "#{name}.verdicts.json")
    doc = Verdicts.parse(raw.to_s)
    usable = status.success? && doc.is_a?(Hash) && doc["verdicts"].is_a?(Array)
    File.write(verdicts_path, JSON.pretty_generate(doc)) if usable

    Result.new(judge: name, judge_sha: j[:sha], model: model, criteria: criteria.length,
               counts: usable ? Verdicts.counts(doc) : nil, verdicts_path: usable ? verdicts_path : nil,
               usable: usable, session: envelope["session_id"], cost_usd: envelope["total_cost_usd"],
               seconds: seconds)
  end

  # Whether this judge, at this sha and this model, has passed calibrate.rb. Anything else —
  # never calibrated, calibrated at another sha, failed — is "uncalibrated", and report.rb shows
  # an uncalibrated judge's column as such rather than as a score.
  def self.calibration(name, sha, model)
    path = File.join(E2E::CALIBRATION, "status.json")
    return "uncalibrated" unless File.exist?(path)

    s = JSON.parse(File.read(path))[name]
    return "uncalibrated" unless s && s["judge_sha"] == sha && s["model"] == model

    s["calibrated"] ? "calibrated" : "uncalibrated"
  end
end

if $PROGRAM_NAME == __FILE__
  opts = {}
  OptionParser.new do |o|
    o.banner = "usage: judge.rb <judge> --page P --repo R --base SHA --head SHA [--out DIR] [--model M]"
    o.on("--page P") { |v| opts[:page] = v }
    o.on("--repo R") { |v| opts[:repo] = v }
    o.on("--base SHA") { |v| opts[:base] = v }
    o.on("--head SHA") { |v| opts[:head] = v }
    o.on("--out DIR") { |v| opts[:out] = v }
    o.on("--model M") { |v| opts[:model] = v }
  end.parse!
  name = ARGV.shift
  unless name && opts[:page] && opts[:repo] && opts[:base] && opts[:head]
    warn "usage: judge.rb <judge> --page P --repo R --base SHA --head SHA [--out DIR] [--model M]"
    exit 2
  end
  opts[:out] ||= Dir.mktmpdir("judge-")

  r = Judge.run(name, **opts)
  unless r.usable
    puts "unusable  #{name} returned no verdicts array — raw reply in #{opts[:out]}/#{name}.raw.txt"
    exit 1
  end
  system("ruby", File.join(__dir__, "verdicts.rb"), r.verdicts_path, "--expected", r.criteria.to_s)
  puts "judge #{name} @ #{r.judge_sha} · #{r.model} · #{Judge.calibration(name, r.judge_sha, r.model)} · #{r.seconds}s"
end
