#!/usr/bin/env ruby
# frozen_string_literal: true

# diagram_shot.rb — render each diagram on its own, in both themes, to a PNG.
#
# diagram.rb catches what is countable. Crowding, overlap and a label that collides with
# an edge are none of those things: they need eyes. This produces the images those eyes
# need, one pair per diagram, using the same styles the published page uses — the whole
# style block is lifted from page-template.html rather than reproduced, so a token that
# only exists in one theme shows up here as it would for a reader.
#
# Chrome is the renderer because it is the engine the artifact is read in. No Chrome, no
# images: it skips rather than failing, since CI has no browser and this is a check for a
# person, not a gate.
#
#   diagram_shot.rb --page page.html [--out dir]

require "fileutils"
require "tmpdir"

require_relative "lib/review_map/check"

CANDIDATES = [
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
].freeze

def find_chrome
  return ENV["CHROME"] unless ENV["CHROME"].to_s.empty?

  found = CANDIDATES.find { |c| File.executable?(c) }
  return found if found

  %w[google-chrome chromium].each do |name|
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
      candidate = File.join(dir, name)
      return candidate if File.executable?(candidate)
    end
  end
  nil
end

check = ReviewMap::Check.new(ARGV, name: "diagram-shot.sh")
check.require_input

chrome = find_chrome
if chrome.nil?
  check.skip("no Chrome found — set $CHROME to render the diagrams")
  check.finish
end

out_dir = check.outdir.to_s.empty? ? File.join(File.dirname(check.input), "shots") : check.outdir
FileUtils.mkdir_p(out_dir)

lines = check.page.lines
starts = lines.each_index.select { |i| lines[i].include?("<svg") }.map { |i| i + 1 }
if starts.empty?
  check.skip("no diagrams to render")
  check.finish
end

# The real style block, not a copy of it. A diagram that only works against a
# hand-maintained subset of the tokens is not the diagram the reader gets.
template = File.join(ReviewMap::Check::SKILL_DIR, "references", "page-template.html")
style = ReviewMap::Page.read(template).range(from: /<style/, to: %r{</style>}).lines.join

Dir.mktmpdir do |tmp|
  starts.each_with_index do |start, index|
    number = index + 1
    # From the opening line to the one that closes it, both whole — unlike diagram.rb, which
    # truncates them, because here the drawing is being re-rendered rather than parsed.
    svg = []
    lines[(start - 1)..].each do |raw|
      svg << raw
      break if raw.include?("</svg>")
    end

    %w[light dark].each do |theme|
      harness = File.join(tmp, "harness-#{number}-#{theme}.html")
      File.write(harness, <<~HTML)
        <!doctype html><html data-theme="#{theme}"><head><meta charset="utf-8">
        #{style}</head><body style="background:var(--bg);padding:24px">
        <figure class="wide"><div class="scroller">
        #{svg.join}
        </div></figure></body></html>
      HTML

      shot = File.join(out_dir, "#{File.basename(check.input, ".html")}-diagram#{number}-#{theme}.png")
      _out, ok = check.shell(chrome, "--headless", "--disable-gpu", "--hide-scrollbars",
                             "--window-size=1000,760", "--screenshot=#{shot}",
                             "file://#{harness}")
      if ok && File.size?(shot)
        check.ok("rendered #{shot}")
      else
        check.bad("Chrome produced no image for diagram #{number} in #{theme}")
      end
    end
  end
end

puts
puts "Look at these. A script cannot tell you that two boxes overlap, that an edge label"
puts "sits on top of a line, or that the dashed nodes are the ones that should be dashed."

check.finish
