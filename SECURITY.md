# Security Policy

## Supported Versions

`accountable-review` is a Claude Code plugin distributed as a single rolling release, pinned by the
`version` field in `.claude-plugin/plugin.json`. There are no long-term maintenance branches, so
security fixes are only made against the latest release.

| Version         | Supported          |
| --------------- | ------------------- |
| Latest release  | :white_check_mark: |
| Older releases  | :x:                 |

If you are running a pinned release (a marketplace entry pinned by `ref` or `sha`, or an older
`git tag`), please update to the latest tag before reporting an issue, unless the report is about the
pin mechanism itself.

## Scope

This repository has no application code and does not process user data at runtime. The parts worth a
security report are:

- **The generated GitHub Actions workflow** (`skills/setup-ci/templates/workflow.yml` and the scripts
  under `skills/setup-ci/scripts/` that render and install it) — its triggers, guards, permissions,
  and the one `GITHUB_TOKEN` usage it contains.
- **The shell scripts** under `scripts/`, `ci/`, and `skills/*/scripts/` that generate or validate a
  Review Map.
- **The prose instructions** (`SKILL.md`, `references/*.md`, `agents/claim-falsifier.md`) — for
  example, a wording that would cause the skill to execute untrusted code from a pull request, exfiltrate
  repository contents, or post somewhere it should not.

General Claude Code platform vulnerabilities (unrelated to this plugin) should be reported to
Anthropic directly rather than through this repository.

## Reporting a Vulnerability

Please report suspected vulnerabilities privately to
**accountable-review-security@wyeworks.com** rather than opening a public issue.

Include, where possible:

- The affected file(s) or generated artifact (e.g. the rendered workflow YAML).
- Plugin version (`.claude-plugin/plugin.json`) or commit SHA.
- Steps to reproduce, and the impact you believe it has (e.g. privilege escalation in CI, token
  exposure, arbitrary code execution).

You can expect an acknowledgment within **5 business days**. We aim to provide an initial assessment
(accepted, needs more information, or declined) within **14 days**, and to ship a fix or mitigation for
an accepted report within **30 days**, depending on severity. We will credit reporters in the release
notes unless you ask to remain anonymous.

If a report is declined, we will explain why.
