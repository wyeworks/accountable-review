You are producing ONE SECTION of a review map: section 2, the behaviour flows. Not a review
map, and not any other section.

The repository under review is `{{FIXTURE_DIR}}` and the shell is already inside it. The base
ref is `{{BASE}}`; the head is `HEAD`.

The upstream is already decided. Read these and treat them as given — do not re-resolve the
target, re-inventory the diff, re-derive the goal, or re-group the flows:

- `{{FROZEN}}/target.md`
- `{{FROZEN}}/inventory.md`
- `{{FROZEN}}/goal.md`
- `{{FROZEN}}/flows.md`

Then read, and follow:

- `{{SKILL_DIR}}/SKILL.md` — steps 7 and 8
- `{{SKILL_DIR}}/references/report-format.md` — § *Framework anchors*, § *The review unit*,
  § *Evidence tiers*, § *Source excerpts*
- `{{SKILL_DIR}}/references/rails-nextjs.md` — the lenses, and § *Runtime probes*
- `{{SKILL_DIR}}/references/rails-docs.md` — the documentation URLs you may cite
- `{{SKILL_DIR}}/references/page-template.html` — the component classes, including `a.doc`,
  `pre.probe` and `aside.primer` as they appear inside the assembled flow

The frozen upstream is context, not a substitute for the code: open the files in the
repository before making claims about them.

This case grades the framework anchors specifically, so the flows have to carry them where the
change earns them — and only there. It does not grade them generously: an anchor on a
behaviour every Rails developer knows, or a probe naming something this repository does not
have, is worse than none. A primer is the same judgement with more at stake: it is the largest
component here and the only one that carries no evidence of its own, so write one only where the
decision genuinely cannot be made without the framework rule, at most one per flow — and most
flows earn none.

You have no network access. You cannot open any documentation URL, which is why the catalogue
exists.

Write the fragment to `{{OUT}}`.

An HTML fragment: no `<html>`, `<head>`, `<style>` or `<body>`, no page shell, no other
section, no rail. It will be graded as a fragment, so every claim in it has to stand without
the rest of the page around it.

Do not publish an artifact. Do not write into the repository under review. When the file is
written, reply with one line: the path, how many flows it contains, and how many documentation
links, probes and primers.
