#!/usr/bin/env ruby
# frozen_string_literal: true

# Every SKILL.md and agent file in the plugin must carry frontmatter a strict YAML parser accepts.
#
# `claude plugin validate --strict` does not establish this. It passed a review-map description
# holding an unquoted `: ` ("non-interactive: the page is written…"), which is not valid in a
# plain scalar, and Pi's loader — the Agent Skills host that parses strictly — dropped the skill
# with no message in print mode. A skill that silently fails to load in one host is invisible
# from every other, so the check is the parse itself, not any one host's leniency.
#
# A skill's name and description are also held to the Agent Skills specification's limits
# (agentskills.io/specification): `claude plugin validate --strict` accepts a description past 1024
# characters, and a host that applies the spec rejects or truncates it.
#
# Usage: ruby skills/review-map/tests/frontmatter.rb   (exit 0 clean, 1 on any failure)

require "yaml"

ROOT = File.expand_path("../../..", __dir__)
FRONT = /\A---\n(.*?)\n---\n/m
NAME = /\A[a-z0-9]+(-[a-z0-9]+)*\z/
NAME_MAX = 64
DESCRIPTION_MAX = 1024

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
  return out unless skill

  name, description = data.values_at("name", "description")
  out << "name #{name.inspect} is not lowercase letters, digits and single hyphens" if name.is_a?(String) && name !~ NAME
  out << "name is #{name.length} characters, over #{NAME_MAX}" if name.is_a?(String) && name.length > NAME_MAX
  out << "description is #{description.length} characters, over #{DESCRIPTION_MAX}" if description.is_a?(String) && description.length > DESCRIPTION_MAX
  out
end

# Each mutation must be caught, or the checks above pass because they never looked.
GOOD = "---\nname: a-skill\ndescription: Does one thing.\n---\n"
MUTATIONS = {
  "description over 1024" => ["---\nname: a-skill\ndescription: #{'x' * 1025}\n---\n", "a-skill"],
  "uppercase name" => ["---\nname: A-skill\ndescription: Does one thing.\n---\n", "A-skill"],
  "consecutive hyphens" => ["---\nname: a--skill\ndescription: Does one thing.\n---\n", "a--skill"],
  "leading hyphen" => ["---\nname: -skill\ndescription: Does one thing.\n---\n", "-skill"],
  "name over 64" => ["---\nname: #{'a' * 65}\ndescription: Does one thing.\n---\n", "a" * 65],
  "name not its directory" => [GOOD, "other-skill"]
}.freeze

failures = 0

files = Dir[File.join(ROOT, "skills/*/SKILL.md")].map { |f| [f, true] } +
        Dir[File.join(ROOT, "agents/*.md")].map { |f| [f, false] }
if files.empty?
  puts "FAIL no SKILL.md or agent files found under #{ROOT}"
  failures += 1
end

files.sort.each do |path, skill|
  dir_name = skill ? File.basename(File.dirname(path)) : File.basename(path, ".md")
  found = problems(File.read(path, encoding: "UTF-8"), dir_name: dir_name, skill: skill)
  rel = path.delete_prefix("#{ROOT}/")
  if found.empty?
    puts "ok   #{rel}"
  else
    found.each { |p| puts "FAIL #{rel}: #{p}" }
    failures += 1
  end
end

unless problems(GOOD, dir_name: "a-skill", skill: true).empty?
  puts "FAIL self-test: a valid skill frontmatter is refused"
  failures += 1
end
MUTATIONS.each do |label, (text, dir_name)|
  next unless problems(text, dir_name: dir_name, skill: true).empty?

  puts "FAIL self-test: #{label} was not caught"
  failures += 1
end
puts "ok   #{MUTATIONS.size} mutations caught" if failures.zero?

exit(failures.zero? ? 0 : 1)
