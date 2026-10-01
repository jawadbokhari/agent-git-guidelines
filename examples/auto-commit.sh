#!/bin/bash
# auto-commit.sh: an example of an auto-commit hook that meets rule O3 of agent-git-guidelines.md.
# For solo repositories only. Run it from a session-end hook. It never pushes and never forces anything.
#
# What it does:
#   - stages tracked changes (git add -u), and new files only under the paths listed in .auto-commit-paths
#     (one path per line, blank lines and lines starting with # are ignored, ignore rules still apply)
#   - skips while a rebase, merge, cherry-pick or revert is in progress, on a detached HEAD, in a repository
#     with no commits yet, with unresolved conflicts, and when the repository requires signed commits
#   - looks for secrets BEFORE staging. A hit means nothing is staged, nothing is committed and the index is untouched.
#     The hit is logged to $AUTO_COMMIT_LOG (default ~/.auto-commit-blocked.log)
#   - marks the commit as automatic and adds the Assisted-by trailer
# Opt out per repository by creating a file named .no-auto-commit at the repository root.
# Tested by tests/verify-git-commands.sh.

set -u

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" || exit 0
[ -f .no-auto-commit ] && exit 0

GITDIR=$(git rev-parse --absolute-git-dir)
for state in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD; do
  [ -e "$GITDIR/$state" ] && exit 0
done
git symbolic-ref -q HEAD >/dev/null || exit 0
git rev-parse -q --verify HEAD >/dev/null || exit 0
[ -n "$(git diff --name-only --diff-filter=U)" ] && exit 0
[ "$(git config --type=bool --get commit.gpgsign)" = "true" ] && exit 0

# New files the hook is allowed to add: only paths listed in .auto-commit-paths
allowed_paths() {
  [ -f .auto-commit-paths ] || return 0
  while IFS= read -r path; do
    case "$path" in ''|'#'*) continue ;; esac
    printf '%s\n' "$path"
  done < .auto-commit-paths
}

# Secret patterns are a floor, not a scanner. Add your own.
SECRET_RX='BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|glpat-[A-Za-z0-9_-]{16,}|xox[abprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|(^|[^A-Za-z0-9_])sk-[A-Za-z0-9_-]{32,}'

# Files with a secret-looking line: added lines of tracked changes (staged or not), and the content of allowed new files
HITS=$(
  {
    git diff HEAD -U0 --no-color 2>/dev/null \
      | awk '/^\+\+\+ /{f=substr($0,7)} /^\+[^+]/{print f "\t" substr($0,2)}' \
      | grep -E "$SECRET_RX" | cut -f1
    allowed_paths | while IFS= read -r path; do
      git ls-files --others --exclude-standard -z -- "$path" | xargs -0 -r grep -I -l -E "$SECRET_RX" 2>/dev/null
    done
  } | sort -u | paste -sd, -
)
if [ -n "$HITS" ]; then
  LOG="${AUTO_COMMIT_LOG:-$HOME/.auto-commit-blocked.log}"
  mkdir -p "$(dirname "$LOG")"
  echo "$(date '+%Y-%m-%d %H:%M') blocked auto-commit in $ROOT: possible secret in: $HITS" >> "$LOG"
  echo "auto-commit blocked, possible secret. See $LOG" >&2
  exit 0
fi

git add -u
allowed_paths | while IFS= read -r path; do git add -- "$path" 2>/dev/null; done
git diff --cached --quiet && exit 0

git commit -q -m "auto: $(date '+%Y-%m-%d %H:%M')" --trailer "Assisted-by: claude-code" >/dev/null 2>&1
exit 0
