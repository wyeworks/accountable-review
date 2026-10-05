# frozen_string_literal: true

# progress.rb — a live status board for run.rb, so a 25-minute generation is something to watch
# rather than a cursor to stare at.
#
#   🌔 r1 ▕███████████▍       ▏ 47%  11:02 / ~23:30  🔎 tracing consumers  🔧 38  🥊 4  📄 2/4
#
# Every field is READ, not guessed, and that is the rule this file keeps: a progress bar that
# invents progress is the verification badge of the terminal. Three sources, all ones the run
# already writes:
#
#   * the session transcript, whose id run.rb pins — the latest tool call names the activity, and
#     claim-falsifier spawns are counted;
#   * the page the run is staging under --output — checkpoints written against pending ones;
#   * the clock, against the median generation time of earlier runs of the same PR.
#
# The bar is the only estimate on the line and it is labelled as one (~): it is elapsed time over
# that median, held below 100% until the run actually ends, because "99%" for three minutes is
# honest and "100%" while a falsifier is still reading is not. The activity is the latest tool call
# mapped by purpose, not a step number — profile.sh documents why steps cannot be inferred from a
# transcript (they interleave), and this does not pretend otherwise.
#
# On a terminal the board redraws in place, one line per repetition. Anywhere else (a CI log, a
# pipe) it prints one line when a repetition's activity changes, and nothing in between.

require "io/console"
require "json"

module Progress
  MOON = %w[🌑 🌒 🌓 🌔 🌕 🌖 🌗 🌘].freeze

  # [pattern over the tool call's summary, label]. First match wins, so specific beats general.
  ACTIVITY = [
    [/claim-falsifier/,                          "🥊 falsifiers reading"],
    [/coverage-gate\.sh/,                        "🚪 coverage gate"],
    [/ledger-rows\.sh/,                          "🧾 listing every file"],
    [/excerpt\.sh/,                              "✂️  cutting excerpts"],
    [/page-skeleton\.sh/,                        "🏗️  laying out the page"],
    [/(rails|elixir)-docs\.md/,                  "📖 pinning doc links"],
    [/carry-plan\.sh/,                           "♻️  deciding what to carry"],
    [/diff-render\.sh/,                          "🗺️  mapping the diff"],
    [/check\.rb|page-invariants/,                "🧪 self-checking"],
    [/agenda\.md/,                               "🧩 building the agenda"],
    [/\/analysis\b/,                             "📝 writing analysis notes"],
    [%r{page/index\.html|body\.html|\bWrite\b.*\.html|\bEdit\b.*\.html}, "✍️  writing the page"],
    [/references\/|SKILL\.md/,                   "📚 reading the playbook"],
    [/\bgit (diff|log|show)\b/,                  "🌿 reading the diff"],
    [/\b(rg|grep|Grep)\b/,                       "🔎 tracing consumers"],
    [/\b(sed|cat|head|Read)\b/,                  "👀 reading code"],
  ].freeze

  # One per repetition. run.rb owns the writes; the board only reads.
  class Rep
    attr_reader :phase
    attr_accessor :rep, :session, :page, :started, :gen_started, :eta,
                  :tools, :falsifiers, :activity, :checkpoints, :finished, :failed

    def initialize(rep, eta)
      @rep = rep
      @eta = eta
      @phase = "🧳 preparing the checkout"
      @started = Time.now
      @tools = 0
      @falsifiers = 0
      @offset = 0
    end

    # Leaving the generating phase freezes the clock: checking and judging are not generation, and
    # a clock that kept running through them would overstate the number the ETA is built from.
    def phase=(value)
      @gen_ended ||= Time.now if @phase == :generating && value != :generating
      @phase = value
    end

    def elapsed
      @gen_started ? (@gen_ended || Time.now) - @gen_started : 0
    end

    def generating(session, page)
      @session = session
      @page = page
      @gen_started = Time.now
      @gen_ended = nil
      @phase = :generating
    end

    # Reads only what was appended since the last poll: a transcript reaches megabytes, and the
    # board polls every second.
    def poll
      return unless @phase == :generating && @session

      @transcript ||= Dir[File.join(Dir.home, ".claude", "projects", "*", "#{@session}.jsonl")].first
      if @transcript && File.exist?(@transcript)
        File.open(@transcript) do |f|
          f.seek(@offset)
          f.each_line do |line|
            calls(line).each do |summary|
              @tools += 1
              @falsifiers += 1 if summary.include?("claim-falsifier")
              label = ACTIVITY.find { |re, _| summary.match?(re) }&.last
              @activity = label if label
            end
          end
          @offset = f.pos
        end
      end
      return unless @page && File.exist?(@page)

      # A pending checkpoint is a <section class="cp"> whose <h3> carries span.pending, so each
      # checkpoint is read up to its own close. Comments are stripped first: the template's own
      # comments describe these sections in the same words.
      html = File.read(@page, encoding: "UTF-8").gsub(/<!--.*?-->/m, "")
      cps = html.scan(%r{<section class="cp\b.*?</section>}m)
      written = cps.count { |c| !c.include?('class="pending"') }
      @checkpoints = cps.empty? ? "📄 page started" : "📄 #{written}/#{cps.size}"
    rescue StandardError
      nil # a half-written line or a page mid-Edit: next poll will have it
    end

    def calls(line)
      r = JSON.parse(line)
      content = r.dig("message", "content")
      return [] unless content.is_a?(Array)

      content.filter_map do |x|
        next unless x.is_a?(Hash) && x["type"] == "tool_use"

        i = x["input"].is_a?(Hash) ? x["input"] : {}
        "#{x['name']} #{i['subagent_type']} #{i['command']} #{i['file_path']} #{i['pattern']}"
      end
    rescue JSON::ParserError
      []
    end

    def status
      return @phase if @phase.is_a?(String)

      @activity || "🤔 thinking"
    end
  end

  class Board
    def initialize(id, reps)
      @id = id
      @reps = reps
      @tty = $stdout.tty?
      @lock = Mutex.new
      @drawn = 0
      @last = {}
      @tick = 0
    end

    def start
      @thread = Thread.new do
        loop do
          @lock.synchronize do
            @reps.each(&:poll)
            @tty ? redraw : log_changes
          end
          @tick += 1
          sleep 1
        end
      end
      self
    end

    # Idempotent: run.rb stops the board before its last line, and at_exit stops it again on any
    # other way out — an abort mid-run still leaves the final state on screen, drawn once.
    def stop
      return if @stopped

      @stopped = true
      @thread&.kill
      @lock.synchronize { @tty ? redraw : log_changes }
    end

    # A line printed above the board, which then redraws below it.
    def say(msg)
      @lock.synchronize do
        clear if @tty
        puts msg
        @drawn = 0
        redraw if @tty
      end
    end

    private

    def clear
      return if @drawn.zero?

      print "\e[#{@drawn}A"
      @drawn.times { print "\e[2K\n" }
      print "\e[#{@drawn}A"
    end

    def redraw
      clear
      cols = IO.console&.winsize&.last.to_i
      width = (cols.positive? ? cols : 120) - 1 # a fresh pty, or tmux mid-resize, reports 0
      header = "🧭 #{@id} · #{@reps.size} rep#{'s' unless @reps.size == 1}"
      lines = [header] + @reps.map { |r| fit(line(r), width) }
      puts lines
      @drawn = lines.size
    end

    def log_changes
      @reps.each do |r|
        s = r.status
        next if @last[r.rep] == s

        @last[r.rep] = s
        puts "#{@id} r#{r.rep} #{clock(Time.now - r.started)} #{s}"
      end
    end

    def line(r)
      icon = if r.failed then "💥"
             elsif r.finished then "✅"
             else MOON[(@tick + r.rep) % MOON.size]
             end
      elapsed = r.elapsed
      frac = if r.finished || r.failed then 1.0
             elsif r.gen_started then [elapsed / r.eta, 0.99].min
             else 0.0
             end
      # No generation (a --rejudge, or the checkout still being prepared): no bar, because there is
      # no clock to put one against.
      bits = if r.gen_started
               ["#{icon} r#{r.rep}", bar(frac), format("%3d%%", (frac * 100).floor),
                "#{clock(elapsed)} / ~#{clock(r.eta)}", r.status]
             else
               ["#{icon} r#{r.rep}", r.status]
             end
      bits << "🔧 #{r.tools}" if r.tools.positive?
      bits << "🥊 #{r.falsifiers}" if r.falsifiers.positive?
      bits << r.checkpoints if r.checkpoints
      bits.join("  ")
    end

    BLOCKS = %w[▏ ▎ ▍ ▌ ▋ ▊ ▉].freeze

    def bar(frac, cells = 20)
      full = (frac * cells).floor
      part = ((frac * cells - full) * BLOCKS.size).floor
      s = "█" * full
      s += BLOCKS[part] if full < cells && part.positive?
      "▕#{s.ljust(cells)}▏"
    end

    def clock(secs)
      secs = secs.to_i
      format("%d:%02d", secs / 60, secs % 60)
    end

    # Emoji are two cells wide; count them so a long line truncates instead of wrapping, since a
    # wrapped line breaks the cursor arithmetic the redraw depends on.
    def fit(s, width)
      w = 0
      out = +""
      s.each_char do |c|
        cw = c.ord >= 0x1F000 || (0x2600..0x27BF).cover?(c.ord) ? 2 : (c.ord == 0xFE0F ? 0 : 1)
        break if w + cw > width

        out << c
        w += cw
      end
      out
    end
  end

  # The median of earlier generations of this PR, or 25 minutes when there are none — the order
  # of magnitude evals/README.md records for a run.
  def self.eta(rows, id)
    secs = rows.select { |r| r["id"] == id && r["generated"] && !r["rejudged"] }.filter_map { |r| r["generate_seconds"] }.sort
    secs.empty? ? 1500.0 : secs[secs.size / 2].to_f
  end
end
