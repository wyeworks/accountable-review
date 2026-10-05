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
to `status.json` under the judge file's sha and the model, so **editing a judge's file
uncalibrates it**, and report.rb then shows that judge's column as *uncalibrated* instead of as a
score. Editing the rest of the instrument does not, yet; see *Known gaps*.
`--variant NAME` runs one variant while you iterate on a patch, and never writes `status.json`.

## Known gaps

- **One calibration PR, and it's Rails** (`discourse-43002`, with the Ember client in the same
  repository). No judge is calibrated against a Phoenix page.
- **The masthead is outside what calibration measured.** The judge's prompt calls § 01 "the masthead
  plus `<section id="changed">`", but `E2E.section` (`../lib.rb`) hands it the section alone; the
  masthead's `<h1>`, lede and Shape cell sit in the `<header>` before it (`gold.html:1372-1393`), and
  the judge reaches them only by reading the whole page. All six defects in
  `discourse-43002/defects/` sit inside the section, so calibration has not measured whether the
  judge catches a false claim where § 01's headline claim lives. Closing it is two changes and one
  recalibration: extract the header with the section for the judge — keeping the § 01 word count on
  the section alone, since the agenda budget excludes the masthead — and add a seventh patch planting
  a false `<h1>` or lede, labelled `{1: fail}`.
- **The calibrated identity is the judge's file and nothing else.** `Judge.calibration` compares the
  sha of `judges/<name>.md` and the model. The rest of the instrument — the prompt assembly and tool
  allowlist in `judge.rb`, the section extraction, and `Verdicts.parse`'s recovery of a fenced or
  prose-wrapped reply — can change while `status.json` still says calibrated. Hashing `lib.rb` whole
  is the wrong fix, because it holds report plumbing too and an unrelated edit there would uncalibrate
  every judge; move the extraction into `judge.rb` and hash the judge file, `judge.rb` and
  `verdicts.rb` together, in the same change as the masthead fix, so one recalibration covers both.
- **Blindness is assumed, not tested.** "Blind to the mechanical results" and "a sibling variant must
  not be readable" both rest on `claude -p` confining `Read` to the working directory and the
  `--add-dir` directories. `check.txt` sits one level above the judge's working directory
  (`run.rb:162`). Nobody has run the judge's exact flags against a file outside those directories to
  see whether it can be read.
