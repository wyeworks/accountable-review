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

Where a gold directory has a `make-defects.rb`, add the defect there instead — an anchor that must
match gold exactly once, and its replacement — and rerun it, so a regenerated gold fails loudly
rather than quietly yielding a patch that plants nothing.

Name each patch `<judge>-<defect>`. Then give it labels. A variant lists only the criteria its
defect changes; every other criterion inherits gold's label.

```yaml
gold:
  what-changed: [pass, pass, pass, pass, pass]
variants:
  what-changed-wrong-delta:
    what-changed: {1: fail}
```

**When gold itself fails a criterion**, label it `fail` on the gold row — gold is a run's output,
not an ideal page, and its own defects test the judge as well as a planted one does. Two things
then need a variant of their own. Gold can no longer show the judge *passing* a page that meets
that criterion, so add `<judge>-corrected`: gold with exactly those failures fixed, labelled
`pass` on them. And a defect planted on gold for that criterion changes nothing, so plant it on the
corrected copy and name it as the base; it is gated where it differs from the base, not from gold:

```yaml
  impact-corrected:
    impact: {2: pass, 3: pass}
  impact-false-edge:
    base: impact-corrected
    impact: {2: fail}
```

**When a person cannot settle a criterion on gold** — a sentence true on one reasonable reading and
false on another — label it `~`. Gold is not gated on it, because either label would grade the
judge on which reading it picked; the corrected copy removes the doubt and is gated instead.

The patch is still a diff against `gold.html`, carrying the corrections and the defect together;
`make-defects.rb`'s `FIX` and `REBASED` build both.

Watch the words a patch uses. Two of the first golden fragments passed for the wrong reason,
because their own `aria-label` contained the word the check was looking for.

## What calibrated means

`bin/evals calibrate` runs each judge up to K=3 times on gold and on every variant labelled for it,
stopping on a page once the remaining runs could not change a gated verdict — so a page whose
first two runs agree costs two:

- **Specificity.** Gold passes each criterion in at least 2 of 3 runs.
- **Sensitivity.** Each variant's targeted criterion fails in at least 2 of 3 runs.

Both have to hold. Criteria a variant doesn't target are recorded but not gated, and a judge runs
only on the variants labelled for it. The result goes to `status.json` under the **instrument's**
sha and the model: one hash over the judge's file, `../judge.rb` (the prompt assembly, the tool
allowlist and the extraction of the parts a judge is handed) and `../verdicts.rb` (how a reply
becomes verdicts). **Editing any of the three uncalibrates** — the judge's file uncalibrates that
judge, the other two every judge — and report.rb then shows the column as *uncalibrated* instead of
as a score. `../lib.rb` is outside the hash because it holds report plumbing; nothing a judge sees
is computed there.

A judge whose name is missing from every `gold.yml`'s `judges` list is reported as not calibrated
and gets no `status.json` entry: its gold labels are a guess until a person has read that gold
against its criteria. A smoke pass (`--variant`, `--model`, or `-k` under 3) runs it anyway,
because it writes nothing, and its notes on gold are a useful first read for the person
certifying.
`--variant NAME` runs one variant while you iterate on a patch, and never writes `status.json`.

## Known gaps

- **One calibration PR, and it's Rails** (`discourse-43002`, with the Ember client in the same
  repository). No judge is calibrated against a Phoenix page, and the judges whose subject this
  page does not carry — Context, a checkpoint's figure, a coding-decision checkpoint, a probe — wait
  for a second gold (`../judges/IDEAS.md`).
- **Blindness is assumed, not tested.** "Blind to the mechanical results" and "a sibling variant must
  not be readable" both rest on `claude -p` confining `Read` to the working directory and the
  `--add-dir` directories. `check.txt` sits one level above the judge's working directory
  (`run.rb:162`). Nobody has run the judge's exact flags against a file outside those directories to
  see whether it can be read.
