You are producing ONE SECTION of a review map at the **{{LEVEL}}** detail level: the merged
tail section, which is sections 4 to 7 in one. Not the whole page, and not any other section.

The repository under review is `{{FIXTURE_DIR}}` and the shell is already inside it. The base
ref is `{{BASE}}`; the head is `HEAD`.

The upstream is already decided. Read these and treat them as given — do not re-resolve the
target, re-inventory the diff, or re-derive the goal:

- `{{FROZEN}}/target.md`
- `{{FROZEN}}/inventory.md`
- `{{FROZEN}}/goal.md`
- `{{FROZEN}}/flows.md`

Then read, and follow:

- `{{SKILL_DIR}}/SKILL.md` — steps 5, 6, 8, and step 10's ledger generation
- `{{SKILL_DIR}}/references/rails-nextjs.md` — the search recipes per artifact kind
- `{{SKILL_DIR}}/references/report-format.md` — § *Detail levels*, § *Section 4 at brief*,
  § *Section 4*, § *One canonical home*, § *Evidence tiers*, § *Source excerpts*,
  § *Depth rules*, § *The completeness invariant*
- `{{SKILL_DIR}}/references/page-template.html` — the component classes, and this section
  assembled whole at the bottom of the body skeleton

Two parts of the work are yours rather than the frozen upstream's. The searching: the upstream
names the flows, it does not say which unchanged code they reach, and finding that is the
exercise. And the diff's paths, which are generated rather than typed — run the bundled
`scripts/ledger-rows.sh` against this repository.

Write the fragment to `{{OUT}}`.

An HTML fragment: no `<html>`, `<head>`, `<style>` or `<body>`, no page shell, no other
section. It will be graded as a fragment, so every claim in it has to stand without the rest
of the page around it. Assume sections 1, 2 and 3 exist above it, written from the frozen
flows, and refer to them as the format says to.

Do not publish an artifact. Do not write into the repository under review. When the file is
written, reply with one line: the path, and how many affected-but-unchanged entries it holds.
