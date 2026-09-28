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
# Usage: ruby skills/review-map/tests/frontmatter.rb   (exit 0 clean, 1 on any failure)

require "yaml"

ROOT = File.expand_path("../../..", __dir__)
FRONT = /\A---\n(.*?)\n---\n/m

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
  out
end

failures = 0

# The check, checked. The planted form is the exact defect this file exists for; if it ever
# parses clean, the parser or the extraction has stopped looking and every PASS below is void.
planted = "---\nname: x\ndescription: Passing --output makes the run non-interactive: the page is written.\n---\n"
if problems(planted, dir_name: "x", skill: true).empty?
  puts "FAIL self-check: the planted unquoted `: ` parsed clean"
  failures += 1
end

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

exit(failures.zero? ? 0 : 1)
