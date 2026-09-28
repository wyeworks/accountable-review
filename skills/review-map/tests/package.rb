#!/usr/bin/env ruby
# frozen_string_literal: true

# The npm package that lists review-map in Pi's gallery must agree with the Claude plugin.
#
# package.json is a second place the version lives, beside .claude-plugin/plugin.json, and a second
# version is one somebody forgets to move: npm would publish 1.1.0 of a skill whose plugin says 1.2.0,
# or refuse to publish at all because that version already exists. So the two must match, and the
# manifest must still ship what it names — a `pi.skills` path outside `files` publishes a package
# with no skill in it, which installs cleanly and does nothing.
#
# Usage: ruby skills/review-map/tests/package.rb   (exit 0 clean, 1 on any failure)

require "json"

ROOT = File.expand_path("../../..", __dir__)
failures = []

pkg = JSON.parse(File.read(File.join(ROOT, "package.json")))
plugin = JSON.parse(File.read(File.join(ROOT, ".claude-plugin/plugin.json")))

unless pkg["version"] == plugin["version"]
  failures << "package.json version #{pkg['version'].inspect} differs from plugin.json #{plugin['version'].inspect}"
end
failures << "keywords lack \"pi-package\", so Pi's gallery will not list it" unless Array(pkg["keywords"]).include?("pi-package")

files = Array(pkg["files"])
files.each { |f| failures << "files entry #{f} does not exist" unless File.exist?(File.join(ROOT, f)) }

skills = Array(pkg.dig("pi", "skills"))
failures << "pi.skills is empty" if skills.empty?
skills.each do |s|
  rel = s.delete_prefix("./")
  failures << "pi.skills #{s} has no SKILL.md" unless File.file?(File.join(ROOT, rel, "SKILL.md"))
  shipped = files.any? { |f| f == "#{rel}/SKILL.md" || f == rel || rel.start_with?("#{f}/") }
  failures << "pi.skills #{s} is not covered by files, so the published package has no SKILL.md" unless shipped
end

if failures.empty?
  puts "ok   package.json #{pkg['name']}@#{pkg['version']} agrees with plugin.json and ships #{skills.join(', ')}"
else
  failures.each { |f| puts "FAIL #{f}" }
end
exit(failures.empty? ? 0 : 1)
