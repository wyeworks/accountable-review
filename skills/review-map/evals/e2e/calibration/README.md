# Calibration

A judge is an instrument. Until it has been checked against an answer a person already knows,
it just generates numbers. Each calibration PR in `../prs.yml` gets a directory here:

```
<id>/
├── gold.html           a real page of that PR, certified by a person
├── gold.yml            where it came from and who certified it
├── labels.yml          the verdict a correct judge gives, per criterion, on gold and on each variant
└── defects/*.patch     one unified diff each against gold.html, each planting one defect
status.json             written by calibrate.rb, committed: which judge sha + model is calibrated
```

Calibration PRs are **held out**: they never appear in the eval set, so a judge is never graded
on a page it was tuned against.

## Making the gold page

1. `bin/evals e2e <id> --no-judge --keep`
2. Read the page against the code, criterion by criterion, for every judge that will be
   calibrated on it.
3. If it's right, copy `page/index.html` from the run directory to `<id>/gold.html` and write
   `gold.yml`:
   ```yaml
   plugin_version: 1.2.0
   skill_sha: abc1234
   generated: 2026-09-29
   certified_by: <who read it>
   certified: 2026-09-30
   judges: [what-changed]    # which judges' criteria were checked by hand
   ```
4. If it's wrong, **regenerate it rather than hand-editing it.** A hand-tuned gold page
   calibrates the judge against what someone could write, not against what the skill writes.

Gold is **not** `examples/`. Examples get regenerated whenever the format moves, while gold has
to stay put for as long as its defect patches apply. When the format moves enough that gold
stops looking like a current page, make a new gold, re-certify it, and re-cut the patches.
That's the maintenance cost, and it's why there is one gold case and not five.

## Planting a defect

One patch, one defect, one criterion. The same discipline as `../../golden/`, for the same
reason: a variant that plants two defects keeps failing while either regresses, so it pins
neither.

```sh
cp <id>/gold.html /tmp/v.html
$EDITOR /tmp/v.html                     # plant exactly one defect
diff -u <id>/gold.html /tmp/v.html > <id>/defects/what-changed-wrong-delta.patch
```

Name each patch `<judge>-<defect>`. Then give it labels. A variant lists only the criteria its
defect changes; every other criterion inherits gold's label.

```yaml
gold:
  what-changed: [pass, pass, pass, pass, pass]
variants:
  what-changed-wrong-delta:
    what-changed: {1: fail}
```

Watch the words a patch uses. Two of the first golden fragments passed for the wrong reason,
because their own `aria-label` contained the word the check was looking for.

## What calibrated means

`bin/evals calibrate` runs each judge K=3 times on gold and on every variant:

- **Specificity.** Gold passes each criterion in at least 2 of 3 runs.
- **Sensitivity.** Each variant's targeted criterion fails in at least 2 of 3 runs.

Both have to hold. Criteria a variant doesn't target are recorded but not gated. The result goes
to `status.json` under the judge file's sha and the model, so **editing a judge uncalibrates
it**, and report.rb then shows that judge's column as *uncalibrated* instead of as a score.
`--variant NAME` runs one variant while you iterate on a patch, and never writes `status.json`.

## Known gaps

- **One calibration PR, and it's Rails** (`discourse-43002`, with the Ember client in the same
  repository). No judge is calibrated against a Phoenix page.
- The gold page and its patches don't exist yet. `calibrate.rb` says so and prints the steps
  above.
