You are producing ONE SECTION of a review map: section 2, the behaviour flows, at the
**{{LEVEL}}** detail level and **{{SKILL_EFFORT}}** effort. Not a review map, and not any
other section.

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
- `{{SKILL_DIR}}/references/report-format.md` — § *Section 2*, § *The review unit*,
  § *Evidence tiers*, § *Source excerpts*, § *Depth rules*
- `{{SKILL_DIR}}/references/rails-nextjs.md` — while reading each layer
- `{{SKILL_DIR}}/references/page-template.html` — the component classes

The frozen upstream is context, not a substitute for the code: open the files in the
repository before making claims about them.

Write the fragment to `{{OUT}}`.

An HTML fragment: no `<html>`, `<head>`, `<style>` or `<body>`, no page shell, no other
section, no rail. It will be graded as a fragment, so every claim in it has to stand without
the rest of the page around it.

Do not publish an artifact. Do not write into the repository under review. When the file is
written, reply with one line: the path, and how many flows it contains.
