# frozen_string_literal: true

# changed.rb — the set of paths the diff touches, for the checks that hold a page against it:
# excerpts.rb (no `Unchanged` tag on a changed file), impact-paths.rb (no `.ip-aff` node in one)
# and searches.rb (no *Affected, not changed* entry in one). All three rules are the same rule —
# the page splits changed from affected-not-changed BY FILE — so they read one set, one way.

module ReviewMap
  # Two ways to learn what the diff touched, and the page carries one of them itself: the
  # ledger accounts for every changed path by invariant, so a page can be held against its own
  # account of the change with no repository at hand.
  # Returns [changed paths, where they came from, git's failure if it had one]. The failure is a
  # third value rather than an absent set because it is not the same as having no source: a page
  # with a ledger is still checkable, and the caller says out loud that it fell back.
  def self.changed_set(check, source)
    git_unreadable = nil

    if !check.repo.to_s.empty? && !check.base.to_s.empty?
      merge_base, = check.shell("git", "-C", check.repo, "merge-base", check.base, check.head_ref)
      merge_base = merge_base.strip
      merge_base = check.base if merge_base.empty?
      # git's OWN status. The shell wrote this as `git … | awk | sort > file` and tested the
      # pipeline, which exits with `sort` — so an unresolvable --base produced an empty changed
      # set, matched nothing, and reported a PASS on the one rule whose purpose is catching a
      # label the diff contradicts. Fixed in both, together, with a golden row for each.
      status, ok = check.shell("git", "-C", check.repo, "diff", "--name-status", "-M",
                               merge_base, check.head_ref)
      if ok
        # A rename contributes BOTH paths: `R100<tab>old<tab>new`.
        paths = status.lines.flat_map do |line|
          fields = line.chomp.split("\t")
          fields.size > 2 ? [fields[1], fields[2]] : [fields[1]]
        end
        return [paths.compact.sort.uniq, "the diff", nil]
      end
      git_unreadable = "git cannot resolve #{check.base}..#{check.head_ref}"
    end

    if source.has?("data-path=")
      ledger = source.scan(/data-path="[^"]*"/)
                     .map { |attr| attr.sub(/\Adata-path="/, "").sub(/"\z/, "") }
                     .sort.uniq
      return [ledger, "the page's own ledger", git_unreadable]
    end

    [nil, nil, git_unreadable]
  end
end
