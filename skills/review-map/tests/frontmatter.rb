#!/usr/bin/env ruby
# frozen_string_literal: true

# Every SKILL.md and agent file in the plugin, Pi's entry skills under pi/skills/ included, must carry
# frontmatter a strict YAML parser accepts.
#
# `claude plugin validate --strict` does not establish this. It passed a review-map description
# holding an unquoted `: ` ("non-interactive: the page is written…"), which is not valid in a
# plain scalar, and Pi's loader — the Agent Skills host that parses strictly — dropped the skill
# with no message in print mode. A skill that silently fails to load in one host is invisible
# from every other, so the check is the parse itself, not any one host's leniency.
#
# Usage: ruby skills/review-map/tests/frontmatter.rb   (exit 0 clean, 1 on any failure)

require "yaml"

ROOT = File.expand_path("../../..", __dir__)
FRONT = /\A---\n(.*?)\n---\n/m
MAX_DESCRIPTION = 1024

# Returns a list of problems with one file's frontmatter; empty means it parses and is usable.
def problems(text, dir_name:, skill:)
  block = text[FRONT, 1] or return ["no frontmatter block"]
  data = begin
    YAML.safe_load(block)
  rescue Psych::Exception => e
    return ["not valid YAML: #{e.message.lines.first.strip}"]
  end
  return ["frontmatter is not a mapping"] unless data.is_a?(Hash)

  out = []
  %w[name description].each do |key|
    out << "#{key} is missing or not a non-empty string" unless data[key].is_a?(String) && !data[key].strip.empty?
  end
  # Hosts fall back to, or compare against, the directory name; a mismatch is a second name.
  out << "name #{data['name'].inspect} does not match its directory #{dir_name.inspect}" if skill && data["name"].is_a?(String) && data["name"] != dir_name
  # The Agent Skills limit. Pi warns past it on every start, so a skill over it is noisy there.
  out << "description is #{data['description'].length} characters, over the Agent Skills limit of #{MAX_DESCRIPTION}" if skill && data["description"].is_a?(String) && data["description"].length > MAX_DESCRIPTION
  out
end

# A Pi entry skill holds no procedure; it names the shared SKILL.md by a path relative to itself.
# If that path stops resolving, Pi loads a skill that sends the model to a file that is not there.
def pointer_problems(path, text)
  targets = text.scan(/`((?:\.\.\/)+[^`]*SKILL\.md)`/).flatten
  return ["names no shared SKILL.md by relative path"] if targets.empty?
  targets.reject { |t| File.file?(File.expand_path(t, File.dirname(path))) }.map { |t| "points at #{t}, which does not exist" }
end

failures = 0

PI_ENTRIES = Dir[File.join(ROOT, "pi/skills/*/SKILL.md")]
files = (Dir[File.join(ROOT, "skills/*/SKILL.md")] + PI_ENTRIES).map { |f| [f, true] } +
        Dir[File.join(ROOT, "agents/*.md")].map { |f| [f, false] }
if files.empty?
  puts "FAIL no SKILL.md or agent files found under #{ROOT}"
  failures += 1
end

files.sort.each do |path, skill|
  dir_name = skill ? File.basename(File.dirname(path)) : File.basename(path, ".md")
  text = File.read(path, encoding: "UTF-8")
  found = problems(text, dir_name: dir_name, skill: skill)
  found += pointer_problems(path, text) if PI_ENTRIES.include?(path)
  rel = path.delete_prefix("#{ROOT}/")
  if found.empty?
    puts "ok   #{rel}"
  else
    found.each { |p| puts "FAIL #{rel}: #{p}" }
    failures += 1
  end
end

exit(failures.zero? ? 0 : 1)
