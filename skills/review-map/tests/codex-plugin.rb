#!/usr/bin/env ruby
# frozen_string_literal: true

# The Codex plugin and its marketplace entry must describe the same plugin Claude Code installs.
#
# Codex reads `.codex-plugin/plugin.json` ahead of `.claude-plugin/plugin.json`, so once the first
# exists the second is invisible to it, and nothing but this check notices the two drifting. Three
# drifts matter. A version left behind is an update Codex users never receive: the version is the
# cache key under ~/.codex/plugins/cache, exactly as it is Claude Code's update pin. A `skills` path
# widened to `./skills` ships `setup-ci` into a host whose CI half still runs Claude. And a
# marketplace entry whose name or source points anywhere but this plugin installs something else
# under our name. `claude plugin validate --strict` reads neither file.
#
# Then it breaks each rule on a copy and asserts the check fails, because a check that passes
# because it never looked is worse than no check.
#
# Usage: ruby skills/review-map/tests/codex-plugin.rb   (exit 0 clean, 1 on any failure)

require "json"
require "fileutils"
require "tmpdir"

ROOT = File.expand_path("../../..", __dir__)
CLAUDE = ".claude-plugin/plugin.json"
CODEX = ".codex-plugin/plugin.json"
MARKET = ".agents/plugins/marketplace.json"
# The skills Codex ships. setup-ci is absent on purpose: see docs/codex.md § Current boundary.
SHIPPED = ["skills/review-map"].freeze

def read_json(root, rel)
  JSON.parse(File.read(File.join(root, rel)))
rescue Errno::ENOENT
  raise "#{rel} is missing"
rescue JSON::ParserError => e
  raise "#{rel} is not valid JSON: #{e.message.lines.first.strip}"
end

# Codex's own rule for a manifest path: `./`-relative, no `..`, inside the root.
def plugin_path(root, path, field)
  raise "#{field} #{path.inspect} must start with ./" unless path.is_a?(String) && path.start_with?("./")
  rel = path.delete_prefix("./").chomp("/")
  raise "#{field} #{path.inspect} must not contain .." if rel.split("/").include?("..")
  rel
end

def problems(root)
  claude = read_json(root, CLAUDE)
  codex = read_json(root, CODEX)
  market = read_json(root, MARKET)
  out = []

  %w[name version].each do |key|
    out << "#{CODEX} #{key} #{codex[key].inspect} differs from #{CLAUDE} #{claude[key].inspect}" if codex[key] != claude[key]
  end

  skills = codex["skills"].is_a?(Array) ? codex["skills"] : [codex["skills"]]
  dirs = skills.map { |s| plugin_path(root, s, "skills") }
  out << "skills ship #{dirs.sort.inspect}, expected #{SHIPPED.inspect}" if dirs.sort != SHIPPED
  dirs.each do |d|
    out << "skills path #{d} holds no SKILL.md" unless File.file?(File.join(root, d, "SKILL.md"))
  end

  out << "#{MARKET} has no name" unless market["name"].is_a?(String) && !market["name"].strip.empty?
  entries = Array(market["plugins"])
  if entries.size != 1
    out << "#{MARKET} lists #{entries.size} plugins, expected 1"
  else
    entry = entries.first
    out << "marketplace entry #{entry['name'].inspect} is not the plugin #{codex['name'].inspect}" if entry["name"] != codex["name"]
    src = entry["source"]
    path = src.is_a?(Hash) && src["source"] == "local" ? src["path"] : nil
    # The marketplace root is the repository root, two directories above the catalogue.
    out << "marketplace source #{src.inspect} is not this repository (local ./)" unless %w[. ./].include?(path)
  end
  out
rescue RuntimeError => e
  [e.message]
end

def report(label, list)
  list.each { |p| puts "FAIL  #{label}: #{p}" }
  list.empty?
end

ok = report("repository", problems(ROOT))

# Each mutation must be caught. Copies hold only the manifests; skills/ is linked, never copied.
MUTATIONS = {
  "version drift" => ->(c, _) { c["version"] = "0.0.0" },
  "skills widened to ./skills" => ->(c, _) { c["skills"] = "./skills" },
  "skills path without ./" => ->(c, _) { c["skills"] = "skills/review-map" },
  "skills path escaping the root" => ->(c, _) { c["skills"] = "./skills/../skills/review-map" },
  "marketplace entry renamed" => ->(_, m) { m["plugins"][0]["name"] = "review-map" },
  "marketplace source elsewhere" => ->(_, m) { m["plugins"][0]["source"] = { "source" => "local", "path" => "./skills" } },
  "marketplace with a second plugin" => ->(_, m) { m["plugins"] << m["plugins"][0].dup },
}.freeze

MUTATIONS.each do |name, mutate|
  Dir.mktmpdir("codex-plugin") do |t|
    [CLAUDE, CODEX, MARKET].each do |rel|
      FileUtils.mkdir_p(File.dirname(File.join(t, rel)))
      FileUtils.cp(File.join(ROOT, rel), File.join(t, rel))
    end
    File.symlink(File.join(ROOT, "skills"), File.join(t, "skills"))
    codex = read_json(t, CODEX)
    market = read_json(t, MARKET)
    mutate.call(codex, market)
    File.write(File.join(t, CODEX), JSON.generate(codex))
    File.write(File.join(t, MARKET), JSON.generate(market))
    if problems(t).empty?
      puts "FAIL  self-test: #{name} was not caught"
      ok = false
    end
  end
end

if ok
  puts "PASS: Codex manifest agrees with Claude's, ships review-map only, marketplace points here (#{MUTATIONS.size} mutations caught)"
else
  exit 1
end
