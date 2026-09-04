# frozen_string_literal: true

require "open3"

require_relative "page"

# check.rb — shared plumbing for the check scripts, the port of checks/lib.sh.
#
# Every check prints one line per expectation and nothing else:
#
#   PASS  what held
#   FAIL  what did not
#   WARN  what needs a human to look
#   SKIP  what could not run on this input, and why
#
# check.sh dispatches several of them and tallies those lines, which is why the
# prefixes are fixed and why a dispatched script prints no summary of its own.
#
# SKIP is not decoration. A check that cannot run here has to say so out loud: a
# fragment has no :root, no ledger and no build banner, and silently dropping those
# checks is how a fragment ends up reading as thoroughly verified as a page.

module ReviewMap
  class Check
    # Two kinds of input. A page is a whole published document; a fragment is one section,
    # produced by a driver in ../drivers from the frozen upstream in ../frozen. Checks that
    # need the whole document refuse a fragment rather than passing vacuously on it.
    #
    # LEVEL is the skill's detail level, and it is a THIRD axis: MODE is build state
    # (draft/final/stopped) and SCOPE is which section, neither of which says how many
    # sections the page was supposed to have. It defaults to `full` so every existing
    # golden fragment and page case keeps meaning exactly what it meant — a check that
    # quietly reinterpreted its own corpus would be measuring the wrong thing.
    attr_reader :input, :kind, :repo, :base, :head_ref, :mode, :scope, :level,
                :outdir, :visual, :expects, :forbids

    def initialize(argv, name: File.basename($PROGRAM_NAME))
      @name = name
      @kind = nil
      @head_ref = "HEAD"
      @mode = "final"
      @level = "full"
      @visual = false
      @expects = []
      @forbids = []
      @counts = { "PASS" => 0, "FAIL" => 0, "WARN" => 0, "SKIP" => 0 }
      parse(argv)
    end

    def ok(message)    = say("PASS", message)
    def bad(message)   = say("FAIL", message)
    def maybe(message) = say("WARN", message)
    def skip(message)  = say("SKIP", message)

    def require_input
      if @input.nil?
        warn "usage: #{@name} --page <file> | --fragment <file> [--repo D --base REF]"
        exit 2
      end
      return if File.readable?(@input)

      puts "FAIL  input is not readable: #{@input}"
      exit 1
    end

    # Exit 3, not 1: the dispatcher treats it as "this check does not apply here", which is
    # a different thing from a failure and must not read as one.
    def require_kind(wanted)
      require_input
      return if @kind == wanted.to_s

      puts "SKIP  #{@name} needs a whole #{wanted}, got a #{@kind}"
      exit 3
    end

    def page
      @page ||= Page.read(@input)
    end

    # lib.sh derived these by walking up from CHECKS_DIR, because POSIX sh cannot find the
    # path of the file being sourced. Ruby can, so they are just constants — but they stay
    # here rather than in each check, because a check that computed its own would be one
    # more place to get wrong.
    CHECKS_DIR = File.expand_path("../..", __dir__)
    EVALS_DIR  = File.dirname(CHECKS_DIR)
    SKILL_DIR  = File.dirname(EVALS_DIR)

    # The one place a check reaches outside itself. Two checks need it and neither should
    # reimplement what it calls: `completeness` runs scripts/coverage-gate.sh, which is
    # RUNTIME code invoked by SKILL.md step 10 and stays shell, and `page-invariants` asks
    # git whether the head is pushed. Returns [stdout, ok?] and never raises — a missing
    # command is a false answer to the check's question, not a crash in the harness.
    def shell(*command, chdir: nil)
      opts = chdir ? { chdir: chdir } : {}
      out, _err, status = ReviewMap.capture(*command, **opts)
      [out, status.success?]
    rescue SystemCallError
      ["", false]
    end

    def finish
      if ENV.fetch("CHECK_TALLY", "1") == "1"
        puts
        puts format("%s: %d passed, %d failed, %d warning(s), %d skipped",
                    @name, @counts["PASS"], @counts["FAIL"], @counts["WARN"], @counts["SKIP"])
      end
      exit(@counts["FAIL"].zero? ? 0 : 1)
    end

    private

    def say(prefix, message)
      @counts[prefix] += 1
      puts "#{prefix}  #{message}"
    end

    def parse(argv)
      argv = argv.dup
      until argv.empty?
        case (flag = argv.shift)
        when "--page"     then @input = argv.shift; @kind = "page"
        when "--fragment" then @input = argv.shift; @kind = "fragment"
        when "--repo"     then @repo = argv.shift
        when "--base"     then @base = argv.shift
        when "--head"     then @head_ref = argv.shift
        when "--draft", "--final", "--stopped" then @mode = flag.delete_prefix("--")
        when "--scope"    then @scope = argv.shift
        when "--level"    then @level = argv.shift
        when "--out"      then @outdir = argv.shift
        when "--visual"   then @visual = true
        when "--expect"   then @expects << argv.shift
        when "--forbid"   then @forbids << argv.shift
        else
          warn "unknown argument: #{flag}"
          exit 2
        end
      end
    end
  end
end
