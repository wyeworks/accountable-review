You are producing ONLY THE DIAGRAMS a review map of this change would carry. No prose
sections, no review units, no ledger.

The repository under review is `{{FIXTURE_DIR}}` and the shell is already inside it. The base
ref is `{{BASE}}`; the head is `HEAD`.

The upstream is already decided. Read these and treat them as given:

- `{{FROZEN}}/target.md`
- `{{FROZEN}}/inventory.md`
- `{{FROZEN}}/goal.md`
- `{{FROZEN}}/flows.md`

Then read, and follow:

- `{{SKILL_DIR}}/references/page-template.html` — the SVG vocabulary and the diagram
  catalogue: the four worked layouts, their grids, and which kind belongs where. The two
  section 2 kinds — the boundary chain and the guard fork — are assembled inside flows A
  and B there rather than in the section 5 catalogue block
- `{{SKILL_DIR}}/references/report-format.md` — § *Depth rules* for the budget, the stop grids
  and the guard fork's three-part trigger, and §§ *Section 2*, *Section 4* and *Section 5* for
  what each diagram has to show. A flow draws at most one figure and most flows draw none
- `{{SKILL_DIR}}/SKILL.md` — step 9's rules on diagrams

Draw what this diff earns and nothing more. Read the files in the repository first: an edge
that does not match the real call path is worse than no diagram, because it is followed.

Write the fragment to `{{OUT}}`: each diagram as `figure > .scroller > svg` (`.wide` styles nothing; a section 2 figure
takes `figure.inflow`), with its
caption, in the order the page would carry them, and one short line above each naming which
section it belongs to and what mechanism it shows. Nothing else — no `<html>`, `<head>`,
`<style>` or `<body>`.

Do not publish an artifact. Do not write into the repository under review. When the file is
written, reply with one line per diagram: its kind, and the section it is for.
