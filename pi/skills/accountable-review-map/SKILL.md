---
name: accountable-review-map
description: >-
  Accountable Review's review map for Pi. Builds an HTML review map of a pull request — what
  changed, the judgments the reviewer has to make with the exact lines that settle each one, the
  order to read the code in, and what the change reaches in code it did not touch — so a reviewer
  can explain the change before judging it. Targets Rails and Elixir/Phoenix, LiveView or JSON API,
  with or without a separate client such as Next.js. Use this whenever someone needs to understand a
  change rather than grade it: asks what a PR or branch does, where to start on a large diff, which
  files matter, what the change might break, or needs to bring a reviewer up to speed — even if they
  never say "review map". Invoke as /skill:accountable-review-map with a PR number, URL, branch or
  diff range; options are --effort high|low, --mentor, and --output <dir> for non-interactive static
  HTML. Not for posting review comments or approval verdicts.
---

# Accountable Review: review map

This is Pi's entry point for the `review-map` skill of the Accountable Review package. It exists
only to give the skill a name that says whose it is: Pi has no per-package namespace, and a bare
`review-map` is a name another package can take.

The procedure is not here. Read `../../../skills/review-map/SKILL.md`, resolved against this file's
directory, **in full, now**, and follow it as the skill for this request:

- Any arguments given to this command are that skill's arguments, parsed at its step 1.
- Resolve every bundled path it names against **its** directory, never this one.
- Its host reference for this run is `references/hosts/pi.md`.
