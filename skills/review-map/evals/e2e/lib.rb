# frozen_string_literal: true

# lib.rb — what run.rb, judge.rb, calibrate.rb and report.rb share: the manifest, the paths,
# the checkout cache, and the stamp every result line carries.
#
# The stamp is the point of the harness. A pass rate is evidence about a VERSION of the prose or
# it is evidence about nothing, so every line names the skill's git sha, the plugin version, and
# the model on each side — and report.rb groups by them, so a line produced by one never averages
# into a line produced by another.

require "digest"
require "fileutils"
require "json"
require "open3"
require "time"
require "yaml"

module E2E
  HERE = __dir__
  EVALS = File.dirname(HERE)
  SKILL = File.dirname(EVALS)
  ROOT = File.expand_path("../..", SKILL)
  RESULTS = File.join(EVALS, "results")
  JUDGES = File.join(HERE, "judges")
  CALIBRATION = File.join(HERE, "calibration")

  # Outside the checkout on purpose: the clones are large, and ci/generate-review-map.sh refuses
  # an --output inside the repository under review — so neither may live under ROOT either.
  def self.cache = ENV.fetch("EVAL_CACHE") { File.join(Dir.home, ".cache", "accountable-review-e2e") }
  def self.out = ENV.fetch("EVAL_OUT") { File.join(ENV.fetch("TMPDIR", "/tmp"), "review-map-e2e") }

  Pr = Struct.new(:id, :repo, :pr, :base_sha, :head_sha, :stack, :role, :update_from, :notes,
                  keyword_init: true)

  def self.prs
    YAML.safe_load_file(File.join(HERE, "prs.yml")).map do |h|
      Pr.new(**h.transform_keys(&:to_sym).slice(*Pr.members))
    end
  end

  def self.pr(id)
    prs.find { |p| p.id == id } or abort "e2e: no PR with id #{id} in prs.yml (have: #{prs.map(&:id).join(', ')})"
  end

  def self.sh!(*cmd, chdir: ROOT)
    out, err, st = Open3.capture3(*cmd, chdir: chdir)
    abort "e2e: #{cmd.join(' ')} failed (#{st.exitstatus}):\n#{err}#{out}" unless st.success?
    out
  end

  # ------------------------------------------------------------------ checkout

  # One blobless clone per repository, shared by every repetition; one detached worktree per
  # repetition, so parallel runs never share a working tree. Blobless because a Discourse clone
  # with every blob is gigabytes and a review map reads a few hundred files.
  def self.clone(pr)
    dir = File.join(cache, pr.repo.tr("/", "__"))
    unless File.directory?(File.join(dir, ".git"))
      FileUtils.mkdir_p(File.dirname(dir))
      sh!("git", "clone", "--filter=blob:none", "--no-checkout", "https://github.com/#{pr.repo}.git", dir)
    end
    wanted = [pr.base_sha, pr.head_sha, pr.update_from].compact
    missing = wanted.reject { |sha| system("git", "-C", dir, "cat-file", "-e", "#{sha}^{commit}", err: File::NULL) }
    unless missing.empty?
      sh!("git", "-C", dir, "fetch", "--filter=blob:none", "origin",
          "+refs/pull/#{pr.pr}/head:refs/remotes/origin/pr/#{pr.pr}", *missing)
    end
    dir
  end

  # Serialised: parallel repetitions share one clone, and two `git worktree add`s racing for
  # its lock is a failed repetition that has nothing to do with the prose.
  GIT = Mutex.new

  def self.worktree(pr, path, sha)
    GIT.synchronize do
      dir = clone(pr)
      sh!("git", "-C", dir, "worktree", "add", "--detach", "--force", path, sha)
    end
    path
  end

  def self.drop_worktree(pr, path)
    dir = File.join(cache, pr.repo.tr("/", "__"))
    GIT.synchronize do
      system("git", "-C", dir, "worktree", "remove", "--force", path, out: File::NULL, err: File::NULL)
    end
  end

  # ------------------------------------------------------------------ stamps

  def self.plugin_version
    JSON.parse(File.read(File.join(ROOT, ".claude-plugin", "plugin.json")))["version"]
  end

  # The sha of the last commit to touch the skill, plus a dirty flag, because a result from an
  # uncommitted wording is still a result — it just cannot be attributed to a sha alone.
  def self.skill_sha
    sha = sh!("git", "log", "-1", "--format=%h", "--", "skills/review-map", "agents").strip
    dirty = !sh!("git", "status", "--porcelain", "--", "skills/review-map", "agents").strip.empty?
    dirty ? "#{sha}+dirty" : sha
  end

  def self.file_sha(path) = Digest::SHA256.file(path).hexdigest[0, 12]

  def self.append(name, row)
    FileUtils.mkdir_p(RESULTS)
    File.open(File.join(RESULTS, "#{name}.jsonl"), "a") { |f| f.puts(JSON.generate(row)) }
  end

  def self.read(name)
    path = File.join(RESULTS, "#{name}.jsonl")
    return [] unless File.exist?(path)

    File.readlines(path).filter_map { |l| JSON.parse(l) unless l.strip.empty? }
  end

  # ------------------------------------------------------------------ the page

  # § 01's prose, as the agenda budget counts it: the paragraphs, bullets and before/after rows
  # of <section id="changed">, never code, never a collapsed block, never the heading. Mechanical,
  # so it is measured here rather than asked of the judge — counting is what a grader is worst at.
  def self.section(html, id)
    start = html.index(/<section\b[^>]*\bid="#{Regexp.escape(id)}"/) or return nil
    depth = 0
    html.to_enum(:scan, %r{<section\b|</section>}).each do
      m = Regexp.last_match
      next if m.begin(0) < start

      depth += m[0] == "</section>" ? -1 : 1
      return html[start...m.end(0)] if depth.zero?
    end
    nil
  end

  def self.prose_words(fragment)
    text = fragment.gsub(/<!--.*?-->/m, " ")
                   .gsub(%r{<(details|code|pre|h2|h3|figure)\b.*?</\1>}m, " ")
    blocks = text.scan(%r{<(p|li|dd)\b[^>]*>(.*?)</\1>}m).map { |_, inner| inner }
    blocks.join(" ").gsub(/<[^>]+>/, " ").gsub(/&[a-z#0-9]+;/i, " ").split.count { |w| w.match?(/\w/) }
  end
end
