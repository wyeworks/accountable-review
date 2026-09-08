# frozen_string_literal: true

require "fileutils"
require "tmpdir"

require_relative "page"

# fixture.rb — the one golden fixture that cannot be a file.
#
# Almost every rule in checks/ is a relation between a page and itself, so its fixture is a
# fragment in golden/. Two are relations between a page and a repository: searches.rb re-runs
# recorded greps, which needs nothing but files, and link-form.rb asks scripts/diff-render.sh
# which files GitHub will render, which needs git — check-attr resolution, numstat, the size of
# one path's diff. golden/links-repo.sh builds that repository; this materializes it once per
# process and expands @REPO@ / @REPO_BASE@ in self-test-cases.txt, the way @GOLD@ is expanded.
#
# Two constraints it has to respect, and both come from checks/frozen.rb.
#
#   It is built under TMPDIR, never inside the checkout. frozen.rb's own header refuses
#   diagram-shot for rendering into references/shots/ during a sweep, and a corpus that writes a
#   git repository into the working tree is the same violation with a different file type.
#
#   Its base SHA is therefore FIXED by links-repo.sh, because a frozen record is a function of
#   the input. The temp directory's name is not stable, so no row may produce output containing
#   it: the two messages in link-form.rb that name --repo are the ones git could not answer, and
#   those rows use golden/searches-repo instead, whose path frozen.rb already normalizes.
module ReviewMap
  FIXTURE_LOCK = Mutex.new

  # [directory, base sha]. Built on first use and removed when the process exits.
  def self.fixture_repo(gold)
    FIXTURE_LOCK.synchronize do
      @fixture_repo ||= begin
        dir = File.join(Dir.mktmpdir("review-map-links"), "repo")
        at_exit { FileUtils.remove_entry(File.dirname(dir), true) }
        out, err, status = ReviewMap.capture(File.join(gold, "links-repo.sh"), dir)
        raise "links-repo.sh failed: #{err}#{out}" unless status.success?

        [dir, out.lines.first.to_s.strip]
      end
    end
  end

  def self.expand_fixtures(text, gold)
    return text unless text.include?("@REPO@") || text.include?("@REPO_BASE@")

    dir, base = fixture_repo(gold)
    text.gsub("@REPO@", dir).gsub("@REPO_BASE@", base)
  end
end
