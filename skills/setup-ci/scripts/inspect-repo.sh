#!/bin/sh
# inspect-repo.sh — report what a repository already has, before setup changes it.
#
#   Usage: inspect-repo.sh [--repo-dir .]
#
# Prints `key=value` lines. It reports; it never decides and never writes. The
# judgement — dedicated workflow or integration into an existing one, write a
# config file or leave the defaults implicit — is the skill's, and it is made by
# reading the files this names rather than by trusting a summary of them.
#
# The point of running it first is the rule in SKILL.md: do not write a generic
# workflow into a repository you have not looked at. A repo with a reusable
# workflow convention, or one already running Claude Code in CI, deserves a
# different conversation from an empty .github/.
#
#   git_repo                 yes | no
#   default_branch           the name, if one can be determined
#   remote_github            yes | no
#   workflows_dir            present | absent
#   workflow_count           how many .yml/.yaml files are in it
#   workflows                their basenames, space separated
#   pull_request_workflows   those that trigger on pull_request
#   reusable_workflows       those exposing workflow_call
#   claude_workflows         those already mentioning claude or anthropic
#   accountable_workflow     the path of an existing Accountable Review workflow, or none
#   config_file              .accountable-review.yml, or none
#   claude_settings          .claude/settings.json, or none
#   plugin_declared          yes | no — accountable-review named in checked-in settings
#   anthropic_secret_used    yes | no — some workflow already reads the credential

set -eu

REPO_DIR=.
while [ $# -gt 0 ]; do
  case $1 in
    --repo-dir) REPO_DIR=$2; shift 2 ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "inspect-repo.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

cd "$REPO_DIR" || { echo "inspect-repo.sh: no such directory: $REPO_DIR" >&2; exit 2; }

if git rev-parse --git-dir >/dev/null 2>&1; then
  echo "git_repo=yes"
else
  echo "git_repo=no"
  echo "default_branch="
  echo "remote_github=no"
  exit 0
fi

branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)
[ -n "$branch" ] || branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
echo "default_branch=$branch"

if git remote -v 2>/dev/null | grep -q 'github\.com'; then
  echo "remote_github=yes"
else
  echo "remote_github=no"
fi

WF=.github/workflows
if [ -d "$WF" ]; then
  echo "workflows_dir=present"
else
  echo "workflows_dir=absent"
  echo "workflow_count=0"
  echo "workflows="
  echo "pull_request_workflows="
  echo "reusable_workflows="
  echo "claude_workflows="
  echo "accountable_workflow=none"
fi

if [ -d "$WF" ]; then
  files=$(find "$WF" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort || true)
  n=0; names=; prs=; reusable=; claude=; ours=none
  for f in $files; do
    n=$((n + 1))
    b=$(basename "$f")
    names="$names $b"
    if grep -q '^[[:space:]]*pull_request' "$f"; then prs="$prs $b"; fi
    if grep -q 'workflow_call' "$f"; then reusable="$reusable $b"; fi
    if grep -qi 'claude\|anthropic' "$f"; then claude="$claude $b"; fi
    if grep -q 'accountable-review' "$f"; then ours=$f; fi
  done
  echo "workflow_count=$n"
  echo "workflows=${names# }"
  echo "pull_request_workflows=${prs# }"
  echo "reusable_workflows=${reusable# }"
  echo "claude_workflows=${claude# }"
  echo "accountable_workflow=$ours"
fi

if [ -f .accountable-review.yml ]; then
  echo "config_file=.accountable-review.yml"
else
  echo "config_file=none"
fi
if [ -f .claude/settings.json ]; then
  echo "claude_settings=.claude/settings.json"
else
  echo "claude_settings=none"
fi

if grep -rqs 'accountable-review' .claude/settings.json 2>/dev/null; then
  echo "plugin_declared=yes"
else
  echo "plugin_declared=no"
fi

if [ -d "$WF" ] && grep -rqs 'ANTHROPIC_API_KEY\|CLAUDE_CODE_OAUTH_TOKEN' "$WF" 2>/dev/null; then
  echo "anthropic_secret_used=yes"
else
  echo "anthropic_secret_used=no"
fi
