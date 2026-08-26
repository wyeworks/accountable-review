You are producing ONE SECTION of a review map: section 2, the review map itself — where
consequences leave the diff. Not the whole page, and not any other section.

The repository under review is `{{FIXTURE_DIR}}` and the shell is already inside it. The base
ref is `{{BASE}}`; the head is `HEAD`.

The upstream is already decided. Read these and treat them as given — do not re-resolve the
target, re-inventory the diff, or re-derive the goal:

- `{{FROZEN}}/target.md`
- `{{FROZEN}}/inventory.md`
- `{{FROZEN}}/goal.md`
- `{{FROZEN}}/flows.md`

Then read, and follow:

- `{{SKILL_DIR}}/SKILL.md` — steps 5, 6 and 8
- `{{SKILL_DIR}}/references/rails-nextjs.md` — the search recipes per artifact kind
- `{{SKILL_DIR}}/references/report-format.md` — § *Section 2*, § *Evidence tiers*,
  § *Source excerpts*, § *Depth rules*
- `{{SKILL_DIR}}/references/page-template.html` — the component classes and the SVG vocabulary

The work of this section is the searching. The frozen upstream names the flows; it does not
tell you which unchanged code they reach, and finding that is the whole exercise. Run the
searches yourself against the repository.

Write the fragment to `{{OUT}}`.

An HTML fragment: no `<html>`, `<head>`, `<style>` or `<body>`, no page shell, no other
section. It will be graded as a fragment, so every claim in it has to stand without the rest
of the page around it.

Do not publish an artifact. Do not write into the repository under review. When the file is
written, reply with one line: the path, and how many affected-but-unchanged entries it holds.
