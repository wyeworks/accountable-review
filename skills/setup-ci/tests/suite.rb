# frozen_string_literal: true

# The deterministic tests for the CI setup, as a library: run.rb runs every section of it against
# this checkout, and self-test.rb runs one section of it against a copy it has just broken.
#
# Everything about generating a Review Map is a model run and cannot be asserted on. Everything
# about *arranging* for one is ordinary software, and this is where that half is held to account:
# what the generated workflow contains, that setup leaves other people's CI alone, that running it
# twice is safe, that a config file is actually respected, and that the delivery seam returns what
# its contract says it does.
#
# ONLY THE TEST CODE IS RUBY. The scripts under test run in users' repositories and on CI runners,
# so they stay shell and are called here as subprocesses, exactly as a workflow calls them. A test
# that loaded them any other way would be testing something nobody runs.
#
# Each section is a method that builds what it needs through the lazy fixtures below, so it can run
# alone. That is what lets self-test.rb run only the section a mutation can reach instead of the
# whole suite once per break — which is what made the shell self-test cost minutes and get deleted.
#
# No network, no model, no API key, and nothing that depends on the machine: no assertion reads the
# date, and the one step that would reach a model has every credential removed from its environment.

require "fileutils"
require "open3"
require "yaml"

# The workflow and the scripts' messages carry em dashes and arrows, and a runner's locale is
# often C. Read every byte as UTF-8 whatever the machine says, or the answer depends on its locale.
Encoding.default_external = Encoding::UTF_8

class SetupCiSuite
  # Ordered as the shell suite was, and as a reader meets the setup: what is rendered, what the
  # renderer decides, what installing it does, what configuration changes, what delivery returns,
  # what generation refuses, and the two gates that decide whether there is a run at all.
  SECTIONS = {
    workflow:   "the generated workflow",
    decisions:  "the decisions about when it runs",
    comment:    "the comment on the pull request",
    preserve:   "existing CI is preserved",
    twice:      "running it twice",
    recovery:   "a re-run does not revert what someone confirmed",
    config:     "configuration",
    delivery:   "delivery",
    adapter:    "the generation adapter",
    gate:       "the application-code gate",
    inspection: "inspection",
    previous:   "the previous map, and updating over it",
    still:      "a push that reaches nothing the map says"
  }.freeze

  # A subprocess that outlives this is waiting on something, and a suite that hangs is worse than
  # one that fails: the failure is reported, the hang is waited on.
  TIMEOUT = 120

  # The environment a model run would read. Unset for every subprocess, so the missing-credential
  # assertion cannot be turned into a real model run by whatever the person running this exported.
  CREDENTIALS = %w[ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX].freeze

  Result = Struct.new(:label, :ok, :detail)
  Run = Struct.new(:out, :err, :code) do
    def all = out + err
  end

  attr_reader :results

  def initialize(root, tmp, out: $stdout)
    @root = root
    @tmp = tmp
    @out = out
    @results = []
    @render   = File.join(root, "skills/setup-ci/scripts/render-workflow.sh")
    @install  = File.join(root, "skills/setup-ci/scripts/install-workflow.sh")
    @read_cfg = File.join(root, "skills/setup-ci/scripts/read-config.sh")
    @inspect  = File.join(root, "skills/setup-ci/scripts/inspect-repo.sh")
    @generate = File.join(root, "ci/generate-review-map.sh")
    @deliver  = File.join(root, "ci/delivery/deliver.sh")
    @gate     = File.join(root, "ci/application-code.sh")
    @still    = File.join(root, "ci/map-still-current.sh")
  end

  def run_sections(names = SECTIONS.keys)
    names.each do |name|
      raise ArgumentError, "unknown section: #{name}" unless SECTIONS.key?(name)
      @out.puts "", "== #{SECTIONS[name]} =="
      send(:"section_#{name}")
    end
    self
  end

  def failures = @results.reject(&:ok)

  # ------------------------------------------------------------------ assertions
  #
  # One line per expectation, PASS or FAIL, in the same idiom as skills/review-map/evals/checks — a
  # test that prints nothing when it passes is a test nobody can tell apart from one that never ran.
  # The label is the assertion's name: self-test.rb names the one each mutation must turn red.

  def record(label, ok, detail = nil)
    @results << Result.new(label, ok, detail)
    @out.puts(ok ? "PASS  #{label}" : "FAIL  #{label}#{detail ? " (#{detail})" : ""}")
  end

  def ok(label) = record(label, true)
  def bad(label, detail = nil) = record(label, false, detail)
  def check(cond, label, detail = nil) = record(label, cond ? true : false, cond ? nil : detail)
  def assert_in(text, needle, label) = check(text.include?(needle), label)
  def assert_not_in(text, needle, label) = check(!text.include?(needle), label)
  def assert_eq(got, want, label) = check(got == want, label, "got '#{got}', wanted '#{want}'")

  # ------------------------------------------------------------------ plumbing

  def sh(*cmd, env: {}, chdir: @tmp)
    env = CREDENTIALS.to_h { |k| [k, nil] }.merge(env)
    Open3.popen3(env, *cmd.map(&:to_s), chdir: chdir, pgroup: true) do |stdin, stdout, stderr, wait|
      # stdin is closed: the code under the self-test is deliberately broken, and broken code reads
      # stdin. A `sed` left without its input file blocks forever on a terminal and returns at once
      # on EOF, and only the second of those is a failure anyone gets to read.
      stdin.close
      o = Thread.new { stdout.read.force_encoding(Encoding::UTF_8) }
      e = Thread.new { stderr.read.force_encoding(Encoding::UTF_8) }
      unless wait.join(TIMEOUT)
        begin
          Process.kill("KILL", -wait.pid)
        rescue Errno::ESRCH
          nil
        end
        wait.join
      end
      Run.new(o.value, e.value, wait.value.exitstatus || 124)
    end
  end

  def git(dir, *args) = sh("git", "-C", dir, *args)

  def new_repo(dir)
    FileUtils.mkdir_p(dir)
    git(dir, "init", "-q", ".")
    git(dir, "config", "user.email", "t@example.com")
    git(dir, "config", "user.name", "t")
    dir
  end

  def commit_all(dir, message)
    git(dir, "add", "-A")
    git(dir, "commit", "-qm", message)
  end

  def rev(dir, ref = "HEAD") = git(dir, "rev-parse", ref).out.strip

  def path(*parts) = File.join(@tmp, *parts)
  def read(file) = File.exist?(file) ? File.read(file) : ""
  def write(file, text) = FileUtils.mkdir_p(File.dirname(file)).then { File.write(file, text) }
  def append(file, text) = File.open(file, "a") { |f| f << text }
  def lines_of(n) = (1..n).map { |i| "#{i}\n" }.join

  # The negative assertions run against a comment-stripped copy. The workflow explains, in comments,
  # why it does not use pull_request_target and does not boot the application — and a test that
  # could not tell an explanation from an instruction would forbid the file from documenting its own
  # reasoning. `grep -v '^[[:space:]]*#'`, which is what the shell suite used.
  def code_only(text) = text.lines.grep_v(/\A[ \t]*#/).join

  def count_lines(text, pattern) = text.lines.count { |l| l.match?(pattern) }

  # A real parse, which is the only thing that sees what the folded scalar actually folded to. It
  # still cannot validate GitHub's expression grammar, which no offline tool has; that is what the
  # two structural assertions in section_workflow stand in for, and why both exist as well as this.
  def yaml_problem(text)
    d = YAML.safe_load(text, aliases: true)
    job = d.fetch("jobs").fetch("review-map")
    return "no if:" unless job["if"].is_a?(String)
    return "newline in if:" if job["if"].include?("\n")
    # `on:` is YAML 1.1's boolean true, which is how every GitHub workflow parses.
    return "no types" unless d[true]["pull_request"]["types"].is_a?(Array)
    nil
  rescue StandardError, Psych::Exception => e
    e.message.lines.first.to_s.strip
  end

  # ------------------------------------------------------------------ fixtures

  def render(*flags) = sh(@render, *flags)

  def workflow = @workflow ||= render.out
  def workflow_code = @workflow_code ||= code_only(workflow)
  def w_push = @w_push ||= render("--regenerate-on-push").out
  def w_push_code = @w_push_code ||= code_only(w_push)

  # A repository that has CI already, and none of it ours. Everything about preservation is
  # measured against this, and it is installed into once, by the first section that asks.
  def preserved
    @preserved ||= begin
      r = new_repo(path("repo-preserve"))
      write(File.join(r, ".github/workflows/tests.yml"), <<~Y)
        name: tests
        on: [push, pull_request]
        jobs:
          rspec:
            runs-on: ubuntu-latest
            steps:
              - uses: actions/checkout@v4
              - run: bundle exec rspec
      Y
      write(File.join(r, ".github/workflows/lint.yml"), <<~Y)
        name: lint
        on: pull_request
        jobs:
          rubocop:
            runs-on: ubuntu-latest
            steps:
              - uses: actions/checkout@v4
              - run: bundle exec rubocop
      Y
      commit_all(r, "init")
      ours = -> { %w[tests.yml lint.yml].map { |f| File.binread(File.join(r, ".github/workflows", f)) }.join }
      before = { head: rev(r), ours: ours.call }
      install = sh(@install, "--repo-dir", r).all
      { dir: r, before: before, ours: ours, install: install }
    end
  end

  # ------------------------------------------------------------------ sections

  def section_workflow
    w = workflow
    code = workflow_code

    assert_in w, "name: Accountable Review",              "it is a workflow named for the plugin"
    assert_in w, "  pull_request:",                       "it triggers on pull_request"
    assert_in w, "      - opened",                        "trigger: opened"
    assert_in w, "      - ready_for_review",              "trigger: ready_for_review"
    assert_in w, "      - reopened",                      "trigger: reopened"
    # Not by default: one Review Map per pull request is the shipped answer, and a push regenerating
    # it is the thing a person turns on knowing what it costs.
    assert_not_in code, "      - synchronize",            "pushes do not regenerate the map by default"
    assert_not_in code, "      - labeled",                "no trigger on labels"
    assert_not_in code, "      - edited",                 "no trigger on edits to the description"
    assert_not_in code, "pull_request_target",            "never pull_request_target"

    assert_in w, "github.event.pull_request.draft == false",                          "draft pull requests are skipped"
    assert_in w, "github.event.pull_request.head.repo.full_name == github.repository", "fork pull requests are skipped"
    assert_in w, "github.event.pull_request.user.login != 'dependabot[bot]'",          "a bot's pull requests are skipped"
    # How big a change has to be is decided after the checkout, by a script reading the real diff —
    # not here. These three fields count the WHOLE diff and come with no file list, so a threshold
    # written against them can only ever measure the wrong thing: a three-line model change beside a
    # five-thousand-line lockfile reads as enormous. Their absence is the assertion.
    assert_not_in code, "changed_files",                  "the job condition counts no files"
    assert_not_in code, "pull_request.additions",         "nor added lines"
    assert_not_in code, "pull_request.deletions",         "nor deleted ones"

    # The two ways to write an `if:` GitHub rejects outright — no job created, and an error naming
    # neither the line nor the reason. Both shipped once.
    #
    # Expressions have no arithmetic operators, so `additions + deletions` is an invalid-file error
    # rather than a sum.
    lines = w.lines
    start = lines.index { |l| l.match?(/^    if: >-/) }
    expr = start ? lines[(start + 1)..].take_while { |l| l.start_with?("      ") } : []
    check expr.none? { |l| [" + ", " - ", " * "].any? { |op| l.include?(op) } },
          "the guard expression uses no arithmetic"

    # And in a folded scalar a more-indented line keeps its newline, which lands inside the
    # expression string. Every line has to sit at the same indentation, so the temptation to align a
    # parenthesis is the defect.
    check !expr.empty? && expr.all? { |l| l.match?(/^      [^ ]/) },
          "every line of the guard expression is at the same indentation"

    assert_in w, "group: accountable-review-${{ github.event.pull_request.number }}", "concurrency is scoped to the pull request"
    assert_in w, "cancel-in-progress: true",              "superseded runs are cancelled"

    assert_in w, "permissions:",                          "permissions are declared"
    assert_in w, "  contents: read",                      "the repository is read, never written"
    assert_not_in code, "contents: write",                "nothing asks to write the repository's contents"
    assert_not_in code, "issues: write",                  "nothing asks to write issues"
    assert_not_in code, "checks: write",                  "nothing asks to set a check"
    assert_not_in code, "statuses: write",                "nothing asks to set a status"
    # `pull-requests: write` is asserted in section_comment, where it is paired with the step that
    # uses it — the two are only ever right together.

    assert_in w, "fetch-depth: 0",                        "the checkout has the history the diff needs"
    assert_in w, "ref: ${{ github.event.pull_request.head.sha }}", "it checks out the pull request head, not a merge commit"
    assert_in w, "persist-credentials: false",            "no git credentials are left beside the checkout"

    assert_in w, "ci/application-code.sh",                "the run is scoped by the application-code gate"
    assert_in w, "id: scope",                             "the scope check is a step later steps can read"
    assert_in w, "if: steps.scope.outputs.verdict == 'generate'", "generation is guarded by the scope check"
    assert_in w, "steps.scope.outputs.verdict == 'skip'", "a skipped run says why, rather than just not happening"
    # The size thresholds are real, and they are NOT here. Two reasons, and both would be undone by
    # the same edit. The payload's counts are over the whole diff, and what decides this is
    # application paths only. And a number in the rendered workflow is a number a team can only
    # change by regenerating the file, which is what .accountable-review.yml exists to avoid.
    assert_not_in code, "changed_files",                  "the job condition counts no files — the payload counts the whole diff"
    assert_not_in code, "pull_request.additions",         "and no lines, for the same reason"
    assert_not_in code, "trivial-files",                  "no threshold is baked into the rendered workflow"
    assert_not_in code, "trivial-lines",                  "nor the line one — both are read from the config at run time"
    assert_in w, "ci/generate-review-map.sh",             "there is a Review Map generation step"
    assert_in w, "ci/delivery/deliver.sh",                "delivery is resolved through the provider seam"
    assert_in w, "uses: actions/upload-artifact@v4",      "the map is uploaded as an artifact"
    assert_in w, "retention-days: ${{ steps.delivery.outputs.retention_days }}", "retention comes from the delivery result"
    assert_in w, "if-no-files-found: error",              "an empty upload fails rather than passing quietly"
    assert_in w, "accountable-review--v",                 "the plugin is pinned to a release tag"

    assert_not_in code, "bundle exec",                    "it never runs the application under review"
    assert_not_in code, "services:",                      "it starts no database or service"
    assert_not_in code, "db:migrate",                     "it runs no migrations"

    # The generated file has to be stable, or "already set up" is undecidable.
    check render.out == w, "rendering twice produces identical bytes"
    no_date(w, render_at("2001-02-03"), render_at("2033-12-31"), "the rendered file carries no timestamp")

    problem = yaml_problem(w)
    check problem.nil?, "it parses as YAML, defines the review-map job, and its guard folds to one line", problem
  end

  # Against the whole file, comments included: a date in a comment still makes the workflow
  # different tomorrow, which is exactly what idempotency cannot survive.
  #
  # The shell suite grepped for today's date, which made the assertion a function of the clock it
  # ran under. This one asks the same question twice without one: the file holds nothing shaped like
  # a date, and two renders under a `date` that answers two different days are the same bytes — the
  # first catches a date typed into the template, the second one computed while rendering.
  DATE = /\b\d{4}-\d{2}-\d{2}\b/
  def no_date(text, first, second, label)
    stamped = text[DATE]
    check stamped.nil? && first == second, label,
          stamped ? "it carries #{stamped}" : "two renders on two different days differ"
  end

  def render_at(day, *flags)
    stub = path("clock-#{day}")
    unless File.exist?(File.join(stub, "date"))
      # Answers every formatted request with the day, and anything else with a clock line.
      write(File.join(stub, "date"), "#!/bin/sh\ncase \"$*\" in *+*) echo #{day} ;; *) echo 'Sat Feb  3 00:00:00 UTC #{day[0, 4]}' ;; esac\n")
      File.chmod(0o755, File.join(stub, "date"))
    end
    sh(@render, *flags, env: { "PATH" => "#{stub}:#{ENV.fetch("PATH")}", "SOURCE_DATE_EPOCH" => day.delete("-") }).out
  end

  def section_decisions
    w = workflow
    # Each of these is a default someone confirms during setup, so each has to be both what ships
    # and actually changeable. A knob that renders the same bytes either way is a confirmation that
    # means nothing.
    push = w_push
    assert_in push, "      - synchronize",      "--regenerate-on-push adds the push trigger"
    assert_in push, "Review Map, regenerated",  "and the file explains that it regenerates"
    assert_not_in push, "is NOT regenerated",   "without the one-map-per-PR trade beside it"
    assert_in w, "is NOT regenerated",          "the default file explains that it does not regenerate"

    # The 0.28.0 size flags are taken and ignored: a workflow generated then carries them in its
    # `# Decisions:` line, and install-workflow.sh feeds that line back on the next upgrade. An
    # unknown-argument exit there would turn "move the version pin" into a hard failure on every
    # repository that set a threshold.
    nosize = render("--no-size-gate").out
    # Comment-stripped, like every other negative assertion here: the template explains in a comment
    # why the payload's counts are the wrong measurement.
    assert_not_in code_only(nosize), "changed_files", "--no-size-gate is accepted and renders no clause"
    legacy = render("--min-files", "7", "--min-lines", "300").out
    check legacy == w, "the old thresholds render the same bytes as no thresholds at all"
    assert_not_in nosize, "a lockfile churn sails", "and drops the comment explaining it"
    assert_in nosize, "!= 'dependabot[bot]'",       "leaving the author clause as the last one"

    bare = render("--no-skip-authors").out
    assert_not_in bare, "user.login",               "--no-skip-authors drops the author clauses"
    assert_in bare, "full_name == github.repository", "leaving the fork guard as the last one"

    two = render("--skip-authors", "dependabot[bot],renovate[bot]").out
    assert_in two, "!= 'renovate[bot]'",            "a second bot gets its own clause"
    assert_eq count_lines(two, /user\.login !=/), 2, "one clause per author, not a merged one"

    # Every combination has to end the expression on a clause rather than a dangling operator, which
    # is the way an optional clause breaks the two beside it.
    broken = { "default" => w, "push" => push, "no-size-gate" => nosize, "no-skip-authors" => bare, "two authors" => two }
             .filter_map { |name, text| (p = yaml_problem(text)) && "#{name}: #{p}" }
    check broken.empty?, "every combination of the when-decisions parses and folds to one line", broken.join("; ")

    frac = path("frac.yml")
    write(frac, "review_map:\n  trivial_files: 3.5\n")
    assert_eq sh(@read_cfg, frac).code, 1,          "a threshold that is not a whole number is refused"
    assert_eq render("--skip-authors", "bad'login").code, 1, "an author login carrying a quote is refused"

    # The recorded line is what makes the knobs safe to re-run, so it has to say everything rather
    # than only what differs from the defaults.
    assert_in w, "# Decisions: --no-regenerate-on-push --skip-authors dependabot[bot] --pr-comment",
              "the file records every decision in the form setup takes them"
    # How big a change has to be is not one of them: it is a number a team changes in
    # .accountable-review.yml without regenerating this.
    assert_not_in w, "--min-files",                 "the recorded decisions carry no size threshold"
  end

  def section_comment
    w = workflow
    # The one thing this job does to the repository, and the only reason it asks for a write scope.
    # Off, BOTH have to go: a repository must not carry `pull-requests: write` for a step that is
    # not there.
    assert_in w, "  pull-requests: write",          "commenting brings the write scope it needs"
    assert_in w, "Link the Review Map on the pull request", "and the step that uses it"
    assert_in w, "GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}", "the token is named by the comment step"
    # Against the comment-stripped copy: the permissions block explains in prose why GITHUB_TOKEN
    # reaches only this step, and counting the explanation as a second use would forbid the file
    # from explaining itself.
    assert_eq count_lines(workflow_code, /GH_TOKEN|GITHUB_TOKEN/), 1,
              "and by no other step, so the model step never sees a write-capable credential"

    off = render("--no-pr-comment").out
    assert_not_in off, "pull-requests: write",      "--no-pr-comment drops the write scope"
    assert_not_in off, "GITHUB_TOKEN",              "and the token with it"
    assert_not_in off, "issues/comments",           "and the step that would have posted"
    assert_in off, "never comments",                "and says the job is read-only, because now it is"
    assert_in off, "  contents: read",              "leaving the read scope it still needs"

    # Nothing anywhere in the job may set a check or a status. A link is not a verdict, and the
    # distance between them is one step someone adds later.
    assert_not_in workflow_code, "check-run",          "it sets no check run"
    assert_not_in workflow_code, "statuses: write",    "it asks for no status scope"
    assert_not_in workflow_code, "createCommitStatus", "it sets no commit status"

    # The step is the only shell in this repository that writes to someone's repository, so it is
    # run rather than read: both paths, against a stub.
    step = begin
      YAML.safe_load(w, aliases: true)["jobs"]["review-map"]["steps"].find { |x| x["name"].to_s.include?("Link the") }
    rescue StandardError, Psych::Exception
      nil
    end
    script = path("comment-step.sh")
    write(script, step ? step["run"].to_s : "echo 'no comment step' >&2; exit 1\n")

    stub = path("stub")
    write(File.join(stub, "gh"), <<~'STUB')
      #!/bin/sh
      # Records the call, and answers the listing from $GH_EXISTING.
      printf '%s\n' "$*" >> "$GH_CALLS"
      case $* in
        *"issues/$PR_NUMBER/comments"*--jq*) printf '%s' "$GH_EXISTING" ;;
        *) : ;;
      esac
    STUB
    File.chmod(0o755, File.join(stub, "gh"))

    run_step = lambda do |name, existing, artifact: "https://github.test/artifact/1", browsable: "false", stable: ""|
      calls = path("calls-#{name}")
      File.write(calls, "")
      r = sh("sh", script, env: {
        "GH_CALLS" => calls, "GH_EXISTING" => existing,
        "ARTIFACT_URL" => artifact, "BROWSABLE" => browsable, "STABLE_URL" => stable,
        "HEAD_SHA" => "a93bd21deadbeefcafe", "PR_NUMBER" => "412", "REPOSITORY" => "acme/app",
        "PATH" => "#{stub}:#{ENV.fetch("PATH")}"
      })
      [r, File.read(calls)]
    end

    r, calls = run_step.call("new", "")
    check r.code.zero?, "the comment step runs clean when there is no comment yet", r.err.strip
    assert_in calls, "-X POST",                     "with no existing comment it posts one"
    assert_not_in calls, "-X PATCH",                "and patches nothing"
    assert_in calls, "accountable-review -->",      "the body carries the marker it will search for"
    assert_in calls, "a93bd21",                     "and the short head SHA, which is how staleness is seen"
    assert_in calls, "Download the Review Map",     "an artifact is offered as a download, not as a page"
    assert_in calls, "no verdict, no score and no approval",
              "and says on the pull request itself that it is not a review"

    r, calls = run_step.call("upsert", "998877\n998899")
    check r.code.zero?, "the comment step runs clean when one is already there", r.err.strip
    assert_in calls, "issues/comments/998877",      "an existing comment is patched, not duplicated"
    assert_not_in calls, "-X POST",                 "and no second comment is posted"
    assert_not_in calls, "issues/comments/998899",  "only the first match is touched"

    # A browsable provider gets its own URL, through the delivery seam rather than around it — the
    # comment must not be a second thing that knows about artifacts.
    _, calls = run_step.call("browsable", "", artifact: "", browsable: "true", stable: "https://maps.test/pr/412")
    assert_in calls, "https://maps.test/pr/412",    "a browsable provider's URL is what gets linked"
    assert_in calls, "Open the Review Map",         "and it is offered as a page rather than a download"
  end

  def section_preserve
    pr = preserved
    r = pr[:dir]
    assert_in pr[:install], "status=created",       "a first run creates the workflow"
    check pr[:ours].call == pr[:before][:ours], "the repository's own workflows are byte-identical afterwards"
    assert_eq rev(r), pr[:before][:head],           "nothing was committed"
    assert_eq Dir.children(File.join(r, ".github/workflows")).size, 3, "exactly one workflow was added"
    check File.file?(File.join(r, ".github/workflows/accountable-review.yml")),
          "it landed at .github/workflows/accountable-review.yml"
    check !File.exist?(File.join(r, ".accountable-review.yml")),
          "no config file is written when nothing differs from the defaults"
  end

  def section_twice
    r = preserved[:dir]
    ours = File.join(r, ".github/workflows/accountable-review.yml")
    assert_in sh(@install, "--repo-dir", r).all, "status=unchanged", "a second run reports unchanged"
    assert_eq Dir.children(File.join(r, ".github/workflows")).size, 3, "a second run adds no second workflow"
    check read(ours) == workflow,         "the file is still exactly what setup renders"
    assert_eq count_lines(read(ours), /^name: Accountable Review/), 1, "no duplicated job or workflow body"

    append(ours, "\n# a team edit\n")
    edited = File.binread(ours)
    drift = sh(@install, "--repo-dir", r)
    assert_in drift.all, "status=drift",            "a hand-edited workflow is reported as drift"
    assert_eq drift.code, 3,                        "drift exits 3 so a caller can tell"
    check File.binread(ours) == edited,   "drift changes nothing on disk"
    assert_in sh(@install, "--repo-dir", r, "--update").all, "status=updated", "--update rewrites it, when asked"
  end

  def section_recovery
    # The knobs are only safe because of this. Upgrading the pin is the ordinary reason to run setup
    # twice, and without recovery it would report every confirmed decision as drift and then revert
    # them all under --update.
    k = path("repo-knobs")
    FileUtils.mkdir_p(k)
    ours = File.join(k, ".github/workflows/accountable-review.yml")
    k1 = sh(@install, "--repo-dir", k, "--", "--plugin-ref", "v1", "--regenerate-on-push", "--skip-authors", "renovate[bot]").all
    assert_in k1, "status=created",                 "a first run installs the confirmed decisions"
    assert_in k1, "decisions=--regenerate-on-push --skip-authors renovate[bot] --pr-comment",
              "and reports back what it wrote rather than what it was asked"

    k2 = sh(@install, "--repo-dir", k, "--", "--plugin-ref", "v1").all
    assert_in k2, "status=unchanged",               "a re-run passing no decisions recovers them and finds nothing to do"

    k3 = sh(@install, "--repo-dir", k, "--print-diff", "--", "--plugin-ref", "v2").all
    assert_in k3, "status=drift",                   "upgrading the pin is drift, as any change is"
    assert_not_in k3, "-      - synchronize",       "but the diff does not propose reverting the push trigger"
    assert_not_in k3, "-      && github.event.pull_request.user.login != 'renovate[bot]'",
                  "nor the author list someone chose"

    sh(@install, "--repo-dir", k, "--update", "--", "--plugin-ref", "v2")
    assert_in read(ours), "      - synchronize",    "an upgrade keeps the push trigger"
    assert_in read(ours), "user.login != 'renovate[bot]'", "an upgrade keeps the author list"
    assert_in read(ours), "PLUGIN_REF: v2",         "and does move the pin, which is what it was run for"

    # An explicit flag still wins over a recovered one, or the decisions could never be changed again.
    sh(@install, "--repo-dir", k, "--update", "--", "--plugin-ref", "v2", "--no-regenerate-on-push")
    assert_not_in read(ours), "      - synchronize", "an explicit decision overrides the recovered one"
    assert_in read(ours), "user.login != 'renovate[bot]'", "and leaves the decisions it said nothing about alone"

    # The comment decision is the one where a silent revert is worst in both directions: re-adding a
    # step a team removed, or dropping a scope they agreed to.
    c2 = path("repo-nocomment")
    FileUtils.mkdir_p(c2)
    sh(@install, "--repo-dir", c2, "--", "--plugin-ref", "v1", "--no-pr-comment")
    sh(@install, "--repo-dir", c2, "--update", "--", "--plugin-ref", "v2")
    c2_file = read(File.join(c2, ".github/workflows/accountable-review.yml"))
    assert_not_in c2_file, "pull-requests: write",  "an upgrade does not re-grant a write scope the team declined"
    assert_not_in c2_file, "GITHUB_TOKEN",          "nor hand back the token that goes with it"

    # A file with nothing recorded is compared against the defaults, which is the honest answer
    # rather than a guess at what someone meant.
    File.write(ours, read(ours).lines.grep_v(/^# Decisions: /).join)
    k6 = sh(@install, "--repo-dir", k, "--", "--plugin-ref", "v2").all
    assert_in k6, "status=drift",                   "a workflow recording no decisions is drift against the defaults"
  end

  def section_config
    c = path("config")
    cfg = File.join(c, ".accountable-review.yml")
    write(cfg, <<~Y)
      review_map:
        delivery:
          provider: github-artifact
          retention_days: 14
    Y
    out = sh(@read_cfg, cfg).out
    assert_in out, "CFG_retention_days='14'",       "retention_days is read"
    assert_not_in out, "CFG_effort",                "a key the file omits produces no line"

    page_dir = path("out-cfg")
    write(File.join(page_dir, "index.html"), "<html>x</html>\n")
    dr = sh(@deliver, "--dir", page_dir, "--repository", "acme/app", "--pr", "412", "--head-sha", "a93bd21deadbeef", chdir: c).out
    assert_in dr, '"retention_days": "14"',         "the workflow honours retention_days from the config file"

    # THE PAGE HAS ONE SHAPE, and nothing names one any more — not a flag on this script and not a
    # key in the config file. A page-shape argument is an unknown argument, which is the state this
    # asserts: an adapter that quietly swallowed one would be the first half of a second product.
    inv = ->(*extra, chdir: @tmp) {
      sh(@generate, "--print-invocation", "--output", page_dir, "--pr", "412", "--head-sha", "a93bd21deadbeef", *extra, chdir: chdir)
    }
    assert_eq inv.call("--repo-dir", @tmp, "--mode", "brief").code, 2, "a page-shape flag is an unknown argument, not a no-op"

    default = inv.call("--repo-dir", @tmp).out
    assert_in default, "--effort high",             "the default effort is high, as the skill's is"

    # --mentor is OFF unless asked for, and off is the ABSENCE of the flag rather than a value: the
    # skill parses no `--mentor off`. It is also the one setting that changes what is on the page,
    # which is why its default is the one that matters most here.
    assert_not_in default, "--mentor",              "no mentor flag is passed by default"
    assert_in inv.call("--repo-dir", @tmp, "--mentor").out, "--mentor", "a bare --mentor reaches the run"
    assert_in inv.call("--repo-dir", @tmp, "--mentor", "rails").out, "--mentor rails", "and a stack name travels with it"
    # The optional value must not swallow the flag after it. A peek that consumed any next argument
    # would turn `--mentor --effort low` into a mentor run at the default effort, silently.
    assert_in inv.call("--repo-dir", @tmp, "--mentor", "--effort", "low").out, "--effort low",
              "a bare --mentor does not swallow the flag after it"

    # And it is configurable, at run time, like everything else a team legitimately sets.
    write(File.join(c, "mentor.yml"), "review_map:\n  mentor: rails\n")
    assert_in inv.call("--repo-dir", c, "--config", File.join(c, "mentor.yml"), chdir: c).out, "--mentor rails",
              "mentor is read from the config file"
    write(File.join(c, "mentor-bad.yml"), "review_map:\n  mentor: nope\n")
    assert_eq sh(@read_cfg, File.join(c, "mentor-bad.yml")).code, 1, "a mentor value that is not a stack is an error"

    write(File.join(c, "bad.yml"), "review_map:\n  retention_day: 14\n")
    assert_eq sh(@read_cfg, File.join(c, "bad.yml")).code, 1, "a misspelled key is an error, not a shrug"
    # There is no page-shape key either. `mode` is not read, not validated and not tolerated — it
    # falls through to the unknown-key rule, which is what stops it coming back as a silent no-op.
    write(File.join(c, "mode.yml"), "review_map:\n  mode: brief\n")
    assert_eq sh(@read_cfg, File.join(c, "mode.yml")).code, 1, "a page-shape key is an unknown key, not a shrug"
  end

  def section_delivery
    d = path("deliver-dir")
    write(File.join(d, "index.html"), "<html>x</html>\n")
    dr = sh(@deliver, "--dir", d, "--repository", "acme/app", "--pr", "412", "--base-sha", "7bd312f0", "--head-sha", "a93bd21deadbeef").out
    assert_in dr, '"provider": "github-artifact"',  "the default provider is github-artifact"
    assert_in dr, '"location": "accountable-review-pr-412-a93bd21"', "the artifact is named for the PR and the revision"
    assert_in dr, '"browsable": false',             "an artifact is not browsable in place, and says so"
    assert_in dr, '"stable_url": null',             "an artifact has no stable URL"
    assert_in dr, '"retention_days": "30"',         "the default retention is 30 days"

    assert_eq sh(@deliver, "--dir", d, "--provider", "s3", "--repository", "acme/app", "--pr", "1", "--head-sha", "abc1234").code, 2,
              "an unimplemented provider fails with a usable message"

    command = ["--dir", d, "--provider", "command", "--repository", "acme/app", "--head-sha", "abc1234"]
    assert_eq sh(@deliver, *command, "--command", "echo https://x.example/1", "--pr", "1").code, 1,
              "the command provider refuses without an explicit opt-in"

    cmd = sh(@deliver, *command, "--command", "echo published to https://x.example/pr/412", "--pr", "412",
             env: { "ACCOUNTABLE_REVIEW_ALLOW_COMMAND" => "1" }).out
    assert_in cmd, '"provider": "command"',         "the command provider runs when opted in"
    assert_in cmd, '"browsable": true',             "a provider that returns a URL is browsable"
    assert_in cmd, '"stable_url": "https://x.example/pr/412"', "the URL it printed becomes the stable URL"

    check sh(@deliver, "--dir", path("empty-dir"), "--repository", "acme/app", "--pr", "1", "--head-sha", "abc1234").code != 0,
          "delivering a directory with no page fails"
  end

  def section_adapter
    g = new_repo(path("gen-repo"))
    write(File.join(g, "a.txt"), "one\n")
    commit_all(g, "one")
    base = rev(g)
    write(File.join(g, "b.txt"), "two\n")
    commit_all(g, "two")
    head = rev(g)
    short = head[0, 7]
    filler = "." * 2100

    assert_eq sh(@generate, "--print-invocation", "--output", File.join(g, "review-map"), "--repo-dir", g, "--head-sha", head).code, 1,
              "an output directory inside the repository is refused"

    nocred = sh(@generate, "--output", path("nocred"), "--repo-dir", g, "--base-sha", base, "--head-sha", head)
    check nocred.code != 0 && nocred.all.include?("credential"), "a missing model credential is reported as a missing credential"

    page = lambda do |dir, body|
      write(File.join(dir, "index.html"), <<~HTML)
        <!doctype html><html><body>
        <header><div class="path">feature/x → main</div><div class="path">#{short} → #{base[0, 7]}</div></header>
        #{body}
        <div class="gt gt-paths"><div class="c" data-path="b.txt">b.txt</div></div>
        </body></html>
      HTML
    end

    o = path("out-good")
    page.call(o, "<p>A page about the change.</p>#{filler}")
    v = sh(@generate, "--verify-only", "--output", o, "--repo-dir", g, "--repository", "acme/app", "--pr", "412",
           "--base-sha", base, "--head-sha", head)
    check v.code.zero?, "a finished page passes verification", v.all.strip
    m = read(File.join(o, "manifest.json"))
    assert_in m, "\"head_sha\": \"#{head}\"",       "the manifest records the head revision"
    assert_in m, "\"base_sha\": \"#{base}\"",       "the manifest records the base revision"
    assert_in m, '"pull_request": 412',             "the manifest records the pull request"
    assert_in m, '"coverage_gate": "pass"',         "the coverage gate runs and its result is recorded"
    assert_not_in m, "severity",                    "the manifest carries no verdict vocabulary"

    o2 = path("out-pending")
    page.call(o2, "<div class=\"buildstate\">Still being written</div>#{filler}")
    pending = sh(@generate, "--verify-only", "--output", o2, "--repo-dir", g, "--base-sha", base, "--head-sha", head)
    check pending.code != 0 && pending.all.match?(/pending marker|build banner/),
          "a page still promising pending sections is refused"

    o3 = path("out-norev")
    write(File.join(o3, "index.html"), "<!doctype html><html><body><p>no revision here</p>#{filler}</body></html>\n")
    norev = sh(@generate, "--verify-only", "--output", o3, "--repo-dir", g, "--base-sha", base, "--head-sha", head)
    check norev.code != 0 && norev.all.include?("revision"), "a page that never names its revision is refused"
  end

  # Two rules, asked in order: is any of this application code, and is what it changes more than
  # trivial. Both halves are measured over application paths ONLY, which is the thing the
  # whole-diff counts of the pull_request payload cannot do.
  def section_gate
    p = new_repo(path("gate-repo"))
    %w[app/models/order.rb app/models/line.rb app/models/cart.rb app/services/pricer.rb
       spec/models/order_spec.rb README.md yarn.lock config/routes.rb].each { |f| write(File.join(p, f), "base\n") }
    FileUtils.mkdir_p([File.join(p, "docs"), File.join(p, ".github/workflows")])
    commit_all(p, "base")
    gate_base = rev(p)
    logs = {}
    f = ->(rel) { File.join(p, rel) }

    gate = lambda do |branch, want, label, *flags, &edit|
      git(p, "checkout", "-q", "-B", branch, gate_base)
      edit.call
      commit_all(p, branch)
      r = sh(@gate, "--base", gate_base, "--head", "HEAD", *flags, chdir: p)
      logs[branch] = r.all
      got = { 0 => "generate", 3 => "skip" }.fetch(r.code, "error(#{r.code})")
      assert_eq got, want, label
    end

    # --- rule 1: is any of it application code at all?
    gate.call("docs", "skip", "a documentation-only pull request gets no Review Map") do
      append(f["README.md"], "x\n")
      write(f["docs/guide.md"], "x\n")
    end
    gate.call("lock", "skip", "a lockfile bump gets none") { append(f["yarn.lock"], "x\n") }
    gate.call("specs", "skip", "a tests-only pull request gets none") { append(f["spec/models/order_spec.rb"], "x\n") }
    gate.call("tooling", "skip", "a CI or linter config change gets none") do
      write(f[".github/workflows/tests.yml"], "x\n")
      write(f[".rubocop.yml"], "x\n")
    end
    assert_in logs["docs"], "verdict: skip (no-application-code)", "rule 1 names itself in the log, not only in a step output"

    # Fail open: a path this script has never heard of is application code. The exclusion list is
    # narrow on purpose, and this is the assertion that keeps it so. Deliberately 40 lines: rule 2
    # would skip a small change whatever rule 1 said, so a 3-line fixture here would pass while
    # proving nothing about fail-open.
    gate.call("unknown", "generate", "an unrecognised path counts as application code") { write(f["odd/thing.xyz"], lines_of(40)) }

    # config/ is where a Rails app keeps its routes. A blanket exclusion by directory name would take
    # it, and take the routing change with it.
    gate.call("routes", "generate", "config/routes.rb is application code, not configuration") { write(f["config/routes.rb"], lines_of(40)) }

    # --- rule 2: is what it changes more than trivial?
    gate.call("tiny", "skip", "a one-line application change is trivial, and gets none") { append(f["app/models/order.rb"], "x\n") }
    assert_in logs["tiny"], "verdict: skip (trivial)", "rule 2 names itself too"
    assert_in logs["tiny"], "trivial threshold",       "and prints the numbers it judged against"

    gate.call("bulky", "generate", "a 900-line change in ONE file earns one") { write(f["app/models/order.rb"], lines_of(900)) }
    gate.call("spread", "generate", "a 4-line change across FOUR files earns one") do
      %w[app/models/order.rb app/models/line.rb app/models/cart.rb app/services/pricer.rb].each { |x| append(f[x], "x\n") }
    end

    # THE TWO ABOVE ARE THE WHOLE POINT OF THE AND, and each is the case the other polarity gets
    # wrong. A skip predicate joined by OR would discard both: one is under the file threshold, the
    # other under the line threshold. Only requiring BOTH to be small leaves a large change on the
    # generating side whichever way it is large.

    gate.call("mixed", "generate", "one substantial application file among documentation earns one") do
      append(f["README.md"], "x\n")
      write(f["app/models/order.rb"], lines_of(40))
    end

    # The counts are over application paths only. This is the case that separates them from the
    # payload's whole-diff numbers: by those, this pull request is five thousand lines.
    gate.call("masked", "skip", "a one-line model change beside a 5000-line lockfile is still trivial") do
      append(f["app/models/order.rb"], "x\n")
      write(f["yarn.lock"], lines_of(5000))
    end
    assert_in logs["masked"], "1 application line", "the lockfile's lines are not counted"

    # --- the thresholds are configurable, and 0 turns them off
    gate.call("offcfg", "generate", "trivial_lines: 0 in the config file generates a map for any application change") do
      append(f["app/models/order.rb"], "x\n")
      write(f[".accountable-review.yml"], "review_map:\n  trivial_lines: 0\n")
    end
    gate.call("upcfg", "skip", "a raised threshold makes a larger change trivial") do
      write(f["app/models/order.rb"], lines_of(40))
      write(f[".accountable-review.yml"], "review_map:\n  trivial_files: 5\n  trivial_lines: 100\n")
    end
    gate.call("flagwins", "generate", "an explicit flag beats the config file", "--trivial-lines", "10") do
      write(f["app/models/order.rb"], lines_of(40))
      write(f[".accountable-review.yml"], "review_map:\n  trivial_files: 5\n  trivial_lines: 100\n")
    end

    bad_cfg = path("trivial-bad.yml")
    write(bad_cfg, "review_map:\n  trivial_lines: lots\n")
    assert_eq sh(@read_cfg, bad_cfg).code, 1,       "a threshold that is not a number is an error"

    assert_in logs["docs"], "skip\tdocs\tREADME.md", "the gate names each discounted path and why"
    assert_in logs["mixed"], "code\t-\tapp/models/order.rb", "and names the application paths it found"

    # ASKED AND UNABLE TO ANSWER IS NOT AN EMPTY DIFF. Every failure mode of this script ends in zero
    # application paths, which is the skip verdict — so a base that is not in the checkout has to be
    # fatal rather than reassuring.
    assert_eq sh(@gate, "--base", "4b825dc642cb6eb9a060e54bf8d69288fbee4904111", "--head", "HEAD", chdir: p).code, 4,
              "a base that cannot be resolved is an error, not a skip"
  end

  def section_inspection
    found = sh(@inspect, "--repo-dir", preserved[:dir]).out
    assert_in found, "git_repo=yes",                "inspection recognises a git repository"
    assert_in found, "workflows_dir=present",       "inspection finds the workflows directory"
    assert_in found, "accountable_workflow=.github/workflows/accountable-review.yml",
              "inspection finds an Accountable Review workflow that is already there"
    plain = path("not-a-repo")
    FileUtils.mkdir_p(plain)
    assert_in sh(@inspect, "--repo-dir", plain).out, "git_repo=no", "inspection says so when there is no repository"
  end

  def section_previous
    push = w_push
    # Nothing persisted between runs before this, so a second run on a pull request rebuilt the page
    # it already had. The cache is the carrier, and it rides the `synchronize` decision because a
    # pull request that gets ONE map has no second run to restore anything into.
    assert_in push, "actions/cache/restore@v4",     "--regenerate-on-push restores the previous map"
    assert_in push, "actions/cache/save@v4",        "and keeps this one for the next push"
    assert_not_in workflow, "actions/cache",        "the default file caches nothing — there is no second run to feed"

    # The two keys must be the SAME string. A save under a key the restore never looks for is a cache
    # that fills up and is never read: every run then rebuilds from scratch, silently, and the only
    # symptom is a bill.
    key_after = lambda do |action|
      lines = push.lines
      i = lines.index { |l| l.include?(action) }
      i && lines[i, 4].filter_map { |l| l[/^ *key: (.*)$/, 1] }.first.to_s
    end
    restore_key = key_after.call("actions/cache/restore@v4").to_s
    save_key = key_after.call("actions/cache/save@v4").to_s
    assert_eq restore_key, save_key,                "the restore and the save name the same key"
    check restore_key.include?("pull_request.head.sha"), "the key is per head sha, so each push saves its own entry",
          "got '#{restore_key}'"
    assert_in push, "restore-keys: accountable-review-map-",
              "and a prefix restore-key, so the previous push's entry is what a new sha falls back to"

    # Only a page that shipped is worth keeping. Correctness does not depend on it — a half-written
    # page restored next run carries a pending marker and carry-plan.sh refuses it — but a cache
    # entry nothing can use is still worth not writing.
    assert_in push, "if: success() && steps.scope.outputs.verdict == 'generate'",
              "the save runs only when this run actually delivered"

    # The fact that makes pull-requests: write acceptable, re-checked here because the cache steps
    # are two more places an env: block could appear.
    assert_eq count_lines(w_push_code, /GH_TOKEN|GITHUB_TOKEN/), 1,
              "exactly one step in the file with the cache steps still names GITHUB_TOKEN"

    # Idempotency is decided by comparing bytes, so the key may carry nothing that varies between two
    # renders of the same request. Run-time ${{ }} expressions are fine; a date is not, and a date
    # is what someone reaches for to expire a cache.
    check render("--regenerate-on-push").out == push, "two renders with the cache steps are byte identical"
    no_date(push, render_at("2001-02-03", "--regenerate-on-push"), render_at("2033-12-31", "--regenerate-on-push"),
            "and the cache key carries no date")

    # review_map.update is RUN-TIME configuration: it is about the map, not about when a map is
    # generated, so it renders nothing and needs no setup flag.
    assert_not_in push, "review_map.update",        "the workflow holds no update setting of its own"

    update_value = lambda do |yaml|
      file = path("cfg-#{yaml.hash.abs}.yml")
      write(file, yaml)
      sh(@read_cfg, file, "--prefix", "CFG_").out[/^CFG_update=(.*)$/, 1].to_s
    end
    assert_eq update_value.call("review_map:\n  update: false\n"), "'false'", "update: false is read"
    assert_eq update_value.call("review_map:\n  update: no\n"), "'false'",    "and no is the same answer spelled the other way"
    assert_eq update_value.call("review_map:\n  effort: high\n"), "",
              "an absent key emits nothing, so the config rung stays distinguishable from the default"
    maybe = path("cfg-bad-update.yml")
    write(maybe, "review_map:\n  update: maybe\n")
    assert_eq sh(@read_cfg, maybe, "--prefix", "CFG_").code, 1, "and a value that is neither is an error rather than a guess"

    # The adapter asks for an update only when something already put a page where it is about to
    # write. Asking against an empty directory would be a flag the skill has to talk its way out of.
    repo = new_repo(path("urepo"))
    run = path("urun")
    FileUtils.mkdir_p(run)
    write(File.join(repo, "f.rb"), "a\n")
    commit_all(repo, "base")
    append(File.join(repo, "f.rb"), "b\n")
    commit_all(repo, "second")
    ubase = rev(repo, "HEAD~1")
    uhead = rev(repo)
    uhs = uhead[0, 7]
    ups = ubase[0, 7]
    common = ["--output", run, "--head-sha", uhead, "--base-sha", ubase, "--repo-dir", repo]
    invocation = ->(*extra) { count_lines(sh(@generate, *common, "--print-invocation", *extra).out, /--update/) }

    assert_eq invocation.call, 0,                   "no previous page means no --update, whatever the config says"
    File.write(File.join(run, "index.html"), "x\n")
    assert_eq invocation.call, 1,                   "a previous page is what turns it on"
    File.write(File.join(repo, ".accountable-review.yml"), "review_map:\n  update: false\n")
    assert_eq invocation.call, 0,                   "update: false turns it off with the page still there"
    assert_eq invocation.call("--update"), 1,       "and an explicit flag beats the config file, like every other setting"
    FileUtils.rm_f(File.join(repo, ".accountable-review.yml"))

    # WHICH REVISION THE CARRIED PARTS DESCRIBE IS READ OFF THE PAGE, NOT TRACKED. The masthead's
    # `updated from <sha>` segment is written only by an update that carried something, so the
    # manifest agrees with the page by construction — and a run that asked for an update and fell
    # back to a full one, which is what every carry-plan.sh refusal does, records null without the
    # adapter learning that it did.
    upage = ->(segment) { File.write(File.join(run, "index.html"), "<html><div class=\"path\">#{uhs} &rarr; #{ups} #{segment}</div>#{"x" * 2500}</html>\n") }
    field = -> { read(File.join(run, "manifest.json"))[/"updated_from"\s*:\s*(.*)$/, 1].to_s.delete(" ,") }

    upage.call("")
    sh(@generate, *common, "--verify-only")
    assert_in read(File.join(run, "manifest.json")), "review-map-manifest@3", "the manifest says which schema carries updated_from"
    assert_eq field.call, "null",                   "a page with no update segment records null"

    upage.call("&middot; updated from #{ups}")
    sh(@generate, *common, "--verify-only")
    assert_eq field.call, "\"#{ups}\"",             "and a page that names one records exactly that revision"
  end

  # The gate asks its question over BASE...HEAD, so a README-only push to a branch that changed
  # application code earlier still answers `generate`. Asking it again over the commits since the
  # map we already have is what makes that push cost nothing.
  def section_still
    push = w_push
    lines = push.lines
    line_of = ->(needle) { (i = lines.index { |l| l.include?(needle) }) && i + 1 }

    # The restore has to sit ABOVE the step that decides the verdict, because the second half of that
    # decision is about the restored map — and it therefore carries no verdict guard, while every
    # later step still does. An ordering assertion rather than a presence one.
    restore_line = line_of.call("actions/cache/restore@v4")
    scope_line = line_of.call("id: scope")
    check restore_line && scope_line && restore_line < scope_line,
          "the previous map is restored before the step that decides whether to generate"
    guard = restore_line ? lines[[restore_line - 7, 0].max...restore_line].count { |l| l.include?("verdict == 'generate'") } : -1
    assert_eq guard, 0, "and the restore carries no verdict guard — it is what the verdict is decided from"

    # -- ripgrep, installed only when there is a previous map to replay searches against. Both halves
    # of reusing a map replay the page's own recorded searches, and the lens files write those with
    # rg, which a GitHub runner does not have. Without this step every recorded search refuses and a
    # re-run rebuilds the page — correct, and the whole saving gone.
    rg_line = line_of.call("Install ripgrep")
    check rg_line && restore_line && scope_line && restore_line < rg_line && rg_line < scope_line,
          "ripgrep is installed after the restore and before the step that replays the searches"
    # ON DEMAND, and the guard is the whole point: a run with nothing restored has nothing to carry,
    # so it pays for no install. `cache-matched-key` is empty on a cold cache, where `cache-hit` is
    # also false on a restore-key hit — which is the case this step most needs to fire for.
    rg_guard = rg_line ? lines[rg_line].to_s : ""
    assert_eq rg_guard.include?("cache-matched-key != ''") ? 1 : 0, 1, "and only when a previous map was actually restored"
    # It is an optimisation, so it must never be the reason a Review Map does not get made. The last
    # command in the block has to succeed even when the package cannot be had.
    rg_block = rg_line ? lines[rg_line..].take_while { |l| !l.match?(/^      - /) } : []
    assert_eq rg_block.count { |l| l.include?("|| echo") }, 1,
              "and a failed install leaves the run to rebuild the page rather than failing the job"
    assert_not_in workflow, "ripgrep", "the default file installs nothing — there is no previous map to replay"

    assert_in push, "map-still-current.sh",         "the scope step asks the second question"
    assert_in push, "reason=map-still-current",     "and downgrades its own verdict rather than adding a second one"
    # WHICH verdict it writes, not merely that it writes a reason. A downgrade to anything but `skip`
    # computes the cheap answer, prints it, and generates anyway.
    still_block = awk_range(lines, /map-still-current\.sh/, /SETUP:END:push/)
    assert_eq still_block.count { |l| l.include?('echo "verdict=skip"') }, 1,
              "and the verdict it writes is skip — anything else computes the answer and ignores it"
    assert_not_in workflow, "map-still-current.sh", "the default file asks it nowhere — there is no second run to ask about"

    # No guard below the scope step moved, which is the whole reason this change is small.
    assert_in push, "if: steps.scope.outputs.verdict == 'skip'", "the existing skip-reporting step is what explains it"
    # One home for the DECISION: a verdict is read from the scope step and from nowhere else. The
    # ripgrep step's cache-matched-key is the cache reporting what it restored, not a second opinion.
    others = push.scan(/steps\.[a-z_-]*\.outputs\.verdict/).reject { |s| s == "steps.scope.outputs.verdict" }
    assert_eq others.size, 0,
              "and no step reads a verdict from anywhere but the scope step — it is still the only one that decides"

    still_against_a_real_repository
  end

  # awk's `/a/,/b/`: a range may end on the line that opened it, and opens again after it closes.
  def awk_range(lines, from, to)
    inside = false
    lines.select do |l|
      inside ||= l.match?(from)
      keep = inside
      inside = false if inside && l.match?(to)
      keep
    end
  end

  def still_against_a_real_repository
    repo = new_repo(path("srepo"))
    map = path("smap")
    FileUtils.mkdir_p(map)
    write(File.join(repo, "app/models/project.rb"), "class Project; end\n")
    write(File.join(repo, "spec/models/project_spec.rb"), "describe Project do; end\n")
    write(File.join(repo, "README.md"), "# Timesheet\n")
    commit_all(repo, "base")
    git(repo, "checkout", "-q", "-b", "feat")
    append(File.join(repo, "app/models/project.rb"), "# archived_at\n")
    commit_all(repo, "push1")
    sbase = rev(repo, "feat~1")
    sprev = rev(repo, "feat")

    # cited: the path the page's one checkpoint cites
    smap = lambda do |cited|
      File.write(File.join(map, "index.html"), <<~PAGE)
        <div class="path">#{sprev[0, 7]} &rarr; #{sbase[0, 7]}</div>
        <section class="cp" id="cp-a"><a class="path" href="#">#{cited}</a></section>
        <details class="searched"><ul class="sr-list">
        <li><code>grep -rn &#39;nothing_matches_this&#39; app</code> <span class="sr-r">no hits</span></li>
        </ul></details>
      PAGE
      File.write(File.join(map, "manifest.json"), <<~JSON)
        { "schema": "accountable-review/review-map-manifest@3",
          "revision": { "base_sha": "#{sbase}", "head_sha": "#{sprev}" } }
      JSON
    end

    branch = lambda do |name, &edit|
      git(repo, "checkout", "-q", "-B", name, "feat")
      edit.call
      commit_all(repo, name)
    end

    still = lambda do |label, want, want_text, ref|
      r = sh(@still, "--dir", map, "--head", rev(repo, ref), "--repo-dir", repo)
      problems = []
      problems << "exit #{r.code}, wanted #{want}" unless r.code == want
      problems << "no reason matching '#{want_text}'" unless r.all.include?(want_text)
      check problems.empty?, label, problems.join("; ")
    end

    branch.call("docsonly") { append(File.join(repo, "README.md"), "more\n") }
    smap.call("app/models/project.rb:1")
    still.call("a docs-only push leaves the existing map standing", 0, "change no application code", "docsonly")

    # THE HOLE THIS COMPOSITION EXISTS TO CLOSE, and the row to write first. application-code.sh
    # classifies tests as not application code, so the first half says yes on its own — while the
    # line the page cites has moved and a reader following that citation lands somewhere else.
    branch.call("testonly") { append(File.join(repo, "spec/models/project_spec.rb"), "x\ny\n") }
    smap.call("spec/models/project_spec.rb:1")
    still.call("a test-only push that moves a cited line regenerates", 3, "reach something the page cites", "testonly")

    # Trivial is the gate's answer to ITS question and the wrong answer to this one: one line in a
    # file a checkpoint cites is exactly where the page has quietly stopped being true.
    branch.call("tiny") { append(File.join(repo, "app/models/project.rb"), "# one more\n") }
    smap.call("app/models/project.rb:1")
    still.call("a trivially small application change still regenerates", 3, "trivially little of it but not none", "tiny")

    # LOCK FILES SPLIT TWO WAYS HERE, and the split is right rather than an oversight — the two name
    # lists exist for two different questions. diff-render.sh's, which application-code.sh borrows,
    # holds the JS ones, because what it answers is "will GitHub render this diff". carry-plan.sh's
    # P5 holds the Ruby and Elixir ones, because what IT answers is "did the thing every
    # documentation link on the page is pinned from move".
    #
    # So a yarn.lock bump is correctly SKIPPED, and a Gemfile.lock bump correctly regenerates — not
    # through P5, which never sees it, but through the fail-open half, where a path diff-render does
    # not recognise counts as code. Pinning both is what stops someone "fixing" the lists into
    # agreement and losing one.
    branch.call("jslock") { File.write(File.join(repo, "yarn.lock"), "# yarn\n") }
    smap.call("app/models/project.rb:1")
    still.call("a JS lock file bump changes nothing the map says, so it is skipped", 0, "change no application code", "jslock")

    branch.call("rubylock") { File.write(File.join(repo, "Gemfile.lock"), "GEM\n") }
    smap.call("app/models/project.rb:1")
    still.call("a Gemfile.lock bump regenerates — it re-pins every doc link on the page", 3, "application code", "rubylock")

    still.call("an unmoved head needs nothing", 0, "has not moved", "feat")

    # Every way of NOT KNOWING leads to the expensive answer. An absence is not evidence that the map
    # is current, and treating it as one is how a stale page ships.
    smap.call("app/models/project.rb:1")
    FileUtils.rm_f(File.join(map, "manifest.json"))
    still.call("a restored map with no manifest regenerates", 3, "no manifest", "docsonly")
    smap.call("app/models/project.rb:1")
    FileUtils.rm_f(File.join(map, "index.html"))
    still.call("nothing restored at all regenerates", 3, "no previous Review Map", "docsonly")
    smap.call("app/models/project.rb:1")
    assert_eq sh(@still, "--dir", map, "--head", "0" * 40, "--repo-dir", repo).code, 3,
              "an unresolvable head regenerates rather than failing the job"
    assert_eq sh(@still, "--dir", map, "--repo-dir", repo).code, 2,
              "and being called wrongly is a usage error, not a verdict"
  end
end
