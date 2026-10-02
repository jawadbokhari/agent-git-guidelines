#!/usr/bin/env bash
# verify-git-commands.sh
# Runs every Git command and behavior claim used by agent-git-guidelines.md and
# agent-git-playbook.md in throwaway repositories, and prints PASS or FAIL for each.
# It touches no real repository and no global or system Git configuration.
# Usage: ./verify-git-commands.sh      (exit status 0 when every check passes)
#        AUTO_COMMIT_SCRIPT=/path/to/hook.sh ./verify-git-commands.sh   (run the auto-commit checks against another script)
# Last run: 2026-10-02 on git 2.55.0, 89 of 89 passed.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
EX="${AUTO_COMMIT_SCRIPT:-$HERE/../examples/auto-commit.sh}"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_TERMINAL_PROMPT=0 GIT_PAGER=cat
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/verify-git.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT
pass=0; fail=0
ok()   { echo "PASS  $1"; pass=$((pass+1)); }
bad()  { echo "FAIL  $1  ($2)"; fail=$((fail+1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1" "$2"; fi; }

git --version

# origin with default branch 'trunk' (not main, not master) to prove no name is hard-coded
git init -q --bare -b trunk "$ROOT/origin.git"
git clone -q "$ROOT/origin.git" "$ROOT/work" 2>/dev/null
cd "$ROOT/work" || exit 1
git checkout -q -b trunk 2>/dev/null || true
echo a > a.txt; git add a.txt; git commit -qm "init"; git push -q origin trunk 2>/dev/null
git remote set-head origin trunk >/dev/null 2>&1

# 1. default branch discovery, local ref and remote query
D1=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); check "default branch from origin/HEAD is origin/trunk" '[ "$D1" = "origin/trunk" ]'
D2=$(git ls-remote --symref origin HEAD | awk '/^ref:/ {sub("refs/heads/","",$2); print $2}'); check "default branch from ls-remote --symref is trunk" '[ "$D2" = "trunk" ]'

# 2. snapshot without touching the shared stash: stash create + private ref
echo "wip edit" >> a.txt
SNAP=$(git stash create); check "stash create returns a commit id for dirty tree" '[ -n "$SNAP" ]'
git update-ref refs/agent/snapshots/session-1 "$SNAP"
check "snapshot ref exists" 'git rev-parse -q --verify refs/agent/snapshots/session-1 >/dev/null'
check "shared stash list unchanged (empty)" '[ -z "$(git stash list)" ]'
check "working tree untouched by stash create" 'grep -q "wip edit" a.txt'
git checkout -q -- a.txt
check "restore from snapshot: file has the edit via git show" 'git show refs/agent/snapshots/session-1:a.txt | grep -q "wip edit"'
git restore --source=refs/agent/snapshots/session-1 -- a.txt
check "restore --source brings back the edit" 'grep -q "wip edit" a.txt'
git checkout -q -- a.txt

# 3. merge-tree conflict pre-check without touching worktree/index
git checkout -q -b left; echo L > c.txt; git add c.txt; git commit -qm left
git checkout -q trunk; git checkout -q -b right; echo R > c.txt; git add c.txt; git commit -qm right
git checkout -q left
BEFORE=$(git status --porcelain)
git merge-tree --write-tree left right >/dev/null 2>&1; RC=$?
check "merge-tree exits 1 on conflict" '[ "$RC" -eq 1 ]'
check "merge-tree left worktree/index unchanged" '[ "$(git status --porcelain)" = "$BEFORE" ]'
git checkout -q trunk; git checkout -q -b clean1; echo x > d.txt; git add d.txt; git commit -qm d
git merge-tree --write-tree trunk clean1 >/dev/null 2>&1; RC=$?; check "merge-tree exits 0 on clean merge" '[ "$RC" -eq 0 ]'

# 4. trailers via git commit --trailer, parsed by interpret-trailers and log format
git checkout -q trunk
echo t > t.txt; git add t.txt
git commit -q -F - --trailer "Assisted-by: agent-x:model-y" <<'EOF'
Add t file

Explain why in the body.
EOF
check "trailer parsed" 'git log -1 --format="%(trailers:key=Assisted-by,valueonly)" | grep -q "agent-x:model-y"'
check "interpret-trailers --parse sees it" 'git log -1 --format=%B | git interpret-trailers --parse | grep -q "Assisted-by: agent-x:model-y"'

# 5. fixup + autosquash non-interactively
git checkout -q -b fx trunk
echo 1 > f.txt; git add f.txt; git commit -qm "Add f"
echo 2 >> f.txt; git add f.txt; git commit -q --fixup=HEAD
N1=$(git rev-list --count trunk..fx)
GIT_SEQUENCE_EDITOR=true git rebase -q -i --autosquash trunk
N2=$(git rev-list --count trunk..fx)
check "fixup then autosquash: 2 commits -> 1" '[ "$N1" -eq 2 ] && [ "$N2" -eq 1 ]'

# 6. porcelain v2 with -z is NUL separated
echo new > u.txt
check "status --porcelain=v2 -z has NULs" '[ "$(git status --porcelain=v2 -z | tr -cd "\0" | wc -c)" -ge 1 ]'
rm -f u.txt

# 7. force-with-lease with explicit sha + force-if-includes
git checkout -q trunk
git push -q origin trunk 2>/dev/null
SHA=$(git rev-parse origin/trunk)
git commit -q --amend -m "init amended" --allow-empty
git push -q --force-with-lease=trunk:"$SHA" --force-if-includes origin trunk 2>/dev/null; RC=$?
check "lease push with expected sha succeeds" '[ "$RC" -eq 0 ]'
# stale expectation must fail
git clone -q "$ROOT/origin.git" "$ROOT/other" 2>/dev/null; ( cd "$ROOT/other" && git checkout -q trunk && echo o > o.txt && git add o.txt && git commit -qm other && git push -q origin trunk 2>/dev/null )
git commit -q --amend -m "amend again" --allow-empty
git push -q --force-with-lease=trunk:"$SHA" --force-if-includes origin trunk 2>/dev/null; RC=$?
check "lease push with stale expectation is rejected" '[ "$RC" -ne 0 ]'

# 8. GIT_OPTIONAL_LOCKS=0 status does not refresh (write) the index
git fetch -q origin 2>/dev/null; git reset -q --hard origin/trunk
touch -t 202001010000 a.txt   # make stat info stale so a normal status would refresh the index
M1=$(stat -f %m .git/index 2>/dev/null || stat -c %Y .git/index)
sleep 1; GIT_OPTIONAL_LOCKS=0 git status >/dev/null
M2=$(stat -f %m .git/index 2>/dev/null || stat -c %Y .git/index)
check "GIT_OPTIONAL_LOCKS=0 status leaves index file untouched" '[ "$M1" = "$M2" ]'

# 9. notes are NOT pushed or cloned by default
git notes --ref=ai add -m '{"agent":"x"}' HEAD
git push -q origin trunk 2>/dev/null
check "default push did not send refs/notes/ai" '[ -z "$(git ls-remote origin refs/notes/ai)" ]'
git push -q origin refs/notes/ai 2>/dev/null
check "explicit push sends refs/notes/ai" '[ -n "$(git ls-remote origin refs/notes/ai)" ]'
git clone -q "$ROOT/origin.git" "$ROOT/clone2" 2>/dev/null
check "plain clone does not fetch refs/notes/ai" '[ -z "$(git -C "$ROOT/clone2" for-each-ref refs/notes/ai)" ]'

# 10. dangling commit recoverable with fsck --lost-found after branch delete + reflog expire
git checkout -q -b doomed trunk; echo d > doomed.txt; git add doomed.txt; git commit -qm doomed; DSHA=$(git rev-parse HEAD)
git checkout -q trunk; git branch -D doomed >/dev/null
check "commit still reachable via reflog right after branch -D" 'git cat-file -e "$DSHA"'
git reflog expire --expire=now --all; git gc -q --prune=now
check "after reflog expire + gc --prune=now the commit is gone" '! git cat-file -e "$DSHA" 2>/dev/null'


# ---------- extended checks: claims made by the guideline about Git behaviour ----------
git checkout -q trunk 2>/dev/null; git reset -q --hard origin/trunk 2>/dev/null

# 11. stash create: staged new file captured, untracked file not
echo s > staged-new.txt; git add staged-new.txt; echo u > untracked-new.txt
SN=$(git stash create); check "stash create captures a staged new file" 'git ls-tree -r --name-only "$SN" | grep -q staged-new.txt'
check "stash create does not capture an untracked file" '! git ls-tree -r --name-only "$SN" | grep -q untracked-new.txt'
git reset -q; rm -f staged-new.txt untracked-new.txt

# 12. GIT_EDITOR=true is fail-safe for a bare 'git commit'
echo e > e.txt; git add e.txt
GIT_EDITOR=true git commit -q >/dev/null 2>&1; RC=$?; check "GIT_EDITOR=true git commit aborts on empty message" '[ "$RC" -ne 0 ]'
git reset -q; rm -f e.txt

# 13. commit-msg hook enforces Assisted-by; both --no-verify and -c core.hooksPath bypass it
mkdir -p "$ROOT/hooks"
cat > "$ROOT/hooks/commit-msg" <<'HOOK'
#!/bin/sh
[ -n "$AGENT_SESSION" ] || exit 0
git interpret-trailers --parse "$1" | grep -q '^Assisted-by: ' || { echo "commit-msg: agent commit needs an Assisted-by trailer" >&2; exit 1; }
HOOK
chmod +x "$ROOT/hooks/commit-msg"
echo h > h.txt; git add h.txt
AGENT_SESSION=1 git -c core.hooksPath="$ROOT/hooks" commit -q -m "no trailer" >/dev/null 2>&1; RC=$?
check "commit-msg hook blocks an agent commit with no trailer" '[ "$RC" -ne 0 ]'
AGENT_SESSION=1 git -c core.hooksPath="$ROOT/hooks" commit -q --no-verify -m "bypass" >/dev/null 2>&1; RC=$?
check "--no-verify bypasses the hook (so hooks are not the control)" '[ "$RC" -eq 0 ]'
git reset -q --hard origin/trunk; echo h2 > h2.txt; git add h2.txt
AGENT_SESSION=1 git -c core.hooksPath=/dev/null commit -q -m "bypass2" >/dev/null 2>&1; RC=$?
check "-c core.hooksPath=/dev/null bypasses the hook" '[ "$RC" -eq 0 ]'
git reset -q --hard origin/trunk; echo h3 > h3.txt; git add h3.txt
AGENT_SESSION=1 git -c core.hooksPath="$ROOT/hooks" commit -q -m "with trailer" --trailer "Assisted-by: a:b" >/dev/null 2>&1; RC=$?
check "commit-msg hook accepts an agent commit that has the trailer" '[ "$RC" -eq 0 ]'

# 14. prepare-commit-msg adds the trailer through interpret-trailers
mkdir -p "$ROOT/hooks2"
cat > "$ROOT/hooks2/prepare-commit-msg" <<'HOOK'
#!/bin/sh
[ -n "$AGENT_SESSION" ] && git interpret-trailers --in-place --trailer "Assisted-by: hook-agent:hook-model" "$1"
exit 0
HOOK
chmod +x "$ROOT/hooks2/prepare-commit-msg"
git reset -q --hard origin/trunk; echo p > p.txt; git add p.txt
AGENT_SESSION=1 git -c core.hooksPath="$ROOT/hooks2" commit -q -m "Add p" >/dev/null 2>&1
check "prepare-commit-msg hook added a parseable trailer" 'git log -1 --format="%(trailers:key=Assisted-by,valueonly)" | grep -q "hook-agent:hook-model"'
git reset -q --hard origin/trunk

# 15. squash recipe: final message with trailers at the end parses; default squash message does not
git checkout -q -b sq trunk; echo 1 >> a.txt; git commit -qam "step 1" --trailer "Assisted-by: a:b"; echo 2 >> a.txt; git commit -qam "step 2" --trailer "Assisted-by: a:b"
git checkout -q trunk; git merge --squash sq >/dev/null 2>&1
git commit -q -F .git/SQUASH_MSG
check "default squash message: trailer NOT parseable on landed commit" '[ -z "$(git log -1 --format="%(trailers:key=Assisted-by,valueonly)")" ]'
git reset -q --hard origin/trunk; git merge --squash sq >/dev/null 2>&1
printf 'Add steps 1 and 2\n\nWhy: test.\n\nAssisted-by: a:b\n' > "$ROOT/final.txt"; git commit -q -F "$ROOT/final.txt"
check "recipe (PR title+description with trailers): trailer IS parseable" 'git log -1 --format="%(trailers:key=Assisted-by,valueonly)" | grep -q "a:b"'
git reset -q --hard origin/trunk

# 16. worktrees: one branch per worktree, shared stash, shared refs
git worktree add -q "$ROOT/wt1" -b wt-branch trunk 2>/dev/null
git worktree add -q "$ROOT/wt2" trunk >/dev/null 2>&1; RC=$?
check "cannot check out the same branch in two worktrees" '[ "$RC" -ne 0 ]'
( cd "$ROOT/wt1" && echo stashme >> a.txt && git stash -q )
check "stash made in worktree 1 is visible in the main worktree (shared)" '[ -n "$(git stash list)" ]'
git stash drop -q
git update-ref refs/agent/snapshots/from-main HEAD
check "refs made in main are visible in a linked worktree (shared)" '( cd "$ROOT/wt1" && git rev-parse -q --verify refs/agent/snapshots/from-main >/dev/null )'
echo dirty > "$ROOT/wt1/dirty.txt"; ( cd "$ROOT/wt1" && git add dirty.txt )
git worktree remove "$ROOT/wt1" >/dev/null 2>&1; RC=$?; check "worktree remove refuses a dirty worktree" '[ "$RC" -ne 0 ]'
git worktree remove --force "$ROOT/wt1" >/dev/null 2>&1; RC=$?; check "worktree remove --force removes it (so it needs approval)" '[ "$RC" -eq 0 ]'

# 17. branch -d refuses unmerged; -D deletes; switch refuses to clobber; switch -f discards
git checkout -q -b unmerged trunk; echo um > um.txt; git add um.txt; git commit -qm um; git checkout -q trunk
git branch -d unmerged >/dev/null 2>&1; RC=$?; check "branch -d refuses an unmerged branch" '[ "$RC" -ne 0 ]'
git branch -D unmerged >/dev/null 2>&1; RC=$?; check "branch -D deletes it anyway (so it needs approval)" '[ "$RC" -eq 0 ]'
git checkout -q -b sw1 trunk; echo v1 > conflict.txt; git add conflict.txt; git commit -qm c1; git checkout -q trunk; git checkout -q -b sw2 trunk; echo v2 > conflict.txt; git add conflict.txt; git commit -qm c2
echo dirty-local >> conflict.txt
git switch -q sw1 >/dev/null 2>&1; RC=$?; check "switch refuses when local changes would be overwritten" '[ "$RC" -ne 0 ]'
git switch -q -f sw1 >/dev/null 2>&1; RC=$?; check "switch -f discards local changes (so it needs approval)" '[ "$RC" -eq 0 ] && ! grep -q dirty-local conflict.txt'
git checkout -q trunk

# 18. pull --ff-only refuses when diverged
git checkout -q -b div trunk; echo d1 > div.txt; git add div.txt; git commit -qm d1
git branch -q div-remote-sim trunk; git checkout -q div-remote-sim; echo d2 > div2.txt; git add div2.txt; git commit -qm d2
git checkout -q div; git config branch.div.remote .; git config branch.div.merge refs/heads/div-remote-sim
git pull --ff-only -q >/dev/null 2>&1; RC=$?; check "pull --ff-only refuses on diverged branches" '[ "$RC" -ne 0 ]'
git checkout -q trunk

# 19. reflog recovery after reset --hard; fsck --lost-found after branch delete and reflog expire
git checkout -q -b rr trunk; echo r1 > r1.txt; git add r1.txt; git commit -qm r1; R1=$(git rev-parse HEAD)
git reset -q --hard HEAD~1
check "commit gone from branch after reset --hard" '! git merge-base --is-ancestor "$R1" HEAD'
check "reflog still lists the lost commit" 'git reflog | grep -q "${R1:0:7}"'
git branch rescue "$R1"; check "branch rescue <sha> restores it" 'git merge-base --is-ancestor "$R1" rescue'
git branch -D rescue >/dev/null; git checkout -q trunk; git branch -D rr >/dev/null
git reflog expire --expire=now --expire-unreachable=now --all
check "fsck --lost-found finds the unreferenced commit" 'git fsck --lost-found 2>/dev/null | grep -q "dangling commit ${R1}"'

# 20. safe.bareRepository=explicit refuses implicit bare repo discovery; --git-dir still works
( cd "$ROOT/origin.git" && git -c safe.bareRepository=explicit rev-parse --git-dir >/dev/null 2>&1 ); RC=$?
check "safe.bareRepository=explicit refuses to use a bare repo found via cwd" '[ "$RC" -ne 0 ]'
( cd "$ROOT/origin.git" && git --git-dir="$ROOT/origin.git" -c safe.bareRepository=explicit rev-parse --git-dir >/dev/null 2>&1 ); RC=$?
check "explicit --git-dir still works under safe.bareRepository=explicit" '[ "$RC" -eq 0 ]'

# 21. .git-blame-ignore-revs works
git checkout -q -b bl trunk; printf 'alpha\nbeta\n' > bl.txt; git add bl.txt; git commit -qm "content"; C1=$(git rev-parse HEAD)
printf 'alpha \nbeta \n' > bl.txt; git commit -qam "reformat"; C2=$(git rev-parse HEAD)
echo "$C2" > "$ROOT/ignore-revs"
B1=$(git blame --porcelain bl.txt | head -1 | cut -d' ' -f1)
B2=$(git blame --porcelain --ignore-revs-file "$ROOT/ignore-revs" bl.txt | head -1 | cut -d' ' -f1)
check "blame without ignore file points at the reformat commit" '[ "$B1" = "$C2" ]'
check "blame with ignore-revs-file points at the content commit" '[ "$B2" = "$C1" ]'
git checkout -q trunk

# 22. cherry-pick -x records the source commit
git checkout -q -b rel trunk~0; git cherry-pick -x "$C1" >/dev/null 2>&1
check "cherry-pick -x appends the source commit line" 'git log -1 --format=%B | grep -q "(cherry picked from commit $C1)"'
git checkout -q trunk


# ---------- examples/auto-commit.sh meets rule O3 ----------
check "example auto-commit script exists and is executable" '[ -x "$EX" ]'
mkdir -p "$ROOT/ac-origin.git" && git init -q --bare -b trunk "$ROOT/ac-origin.git"
git clone -q "$ROOT/ac-origin.git" "$ROOT/ac" 2>/dev/null; cd "$ROOT/ac" || exit 1
git checkout -q -b trunk 2>/dev/null || true
mkdir -p notes; echo one > tracked.txt; echo n > notes/keep.txt; git add -A; git commit -qm init; git push -q origin trunk 2>/dev/null
ORIGIN_BEFORE=$(git ls-remote "$ROOT/ac-origin.git" refs/heads/trunk)

# a. tracked change is committed with the auto prefix and the trailer; nothing is pushed
echo two >> tracked.txt; "$EX"
check "auto-commit commits a tracked change" '[ "$(git log -1 --format=%s | cut -c1-5)" = "auto:" ]'
check "auto-commit adds the Assisted-by trailer" 'git log -1 --format="%(trailers:key=Assisted-by,valueonly)" | grep -q "claude-code"'
check "auto-commit does not push" '[ "$(git ls-remote "$ROOT/ac-origin.git" refs/heads/trunk)" = "$ORIGIN_BEFORE" ]'

# b. an untracked file outside the allowlist is left alone
echo new > stray.txt; echo three >> tracked.txt; "$EX"
check "untracked file outside the allowlist is not committed" '! git ls-files --error-unmatch stray.txt >/dev/null 2>&1'

# c. a new file under an allowlisted path is committed
echo "notes/" > .auto-commit-paths; git add .auto-commit-paths; git commit -qm "allowlist"; echo fresh > notes/new-note.txt; "$EX"
check "new file under an allowlisted path is committed" 'git ls-files --error-unmatch notes/new-note.txt >/dev/null 2>&1'

# d. a secret blocks the commit before anything is staged
export AUTO_COMMIT_LOG="$ROOT/auto-commit-blocked.log"
git add tracked.txt 2>/dev/null; echo unrelated > unrelated-staged.txt; git add unrelated-staged.txt
HEADBEFORE=$(git rev-parse HEAD)
printf 'key=%s%s\n' 'AKIA' 'ABCDEFGHIJKLMNOP' >> notes/new-note.txt; "$EX" 2>/dev/null
check "secret pattern blocks the auto-commit" '[ "$(git rev-parse HEAD)" = "$HEADBEFORE" ]'
check "a block leaves the index as the user had it (the unrelated staged file is still staged)" 'git diff --cached --name-only | grep -q "^unrelated-staged.txt$"'
check "a block writes a log line naming the file" 'grep -q "new-note.txt" "$AUTO_COMMIT_LOG"'
git reset -q; rm -f unrelated-staged.txt; git checkout -q -- notes/new-note.txt

# e. skipped during a rebase in progress
git commit -q --allow-empty -m e1; git commit -q --allow-empty -m e2
GIT_SEQUENCE_EDITOR="sed -i.bak '1s/^pick/edit/'" git rebase -q -i HEAD~2 >/dev/null 2>&1
echo mid-rebase >> tracked.txt; HEADBEFORE=$(git rev-parse HEAD); "$EX"
check "auto-commit skips while a rebase is in progress" '[ "$(git rev-parse HEAD)" = "$HEADBEFORE" ] && ! git diff --quiet'
git checkout -q -- tracked.txt; git rebase --abort >/dev/null 2>&1

# f. skipped on a detached HEAD
git checkout -q --detach; echo detached >> tracked.txt; HEADBEFORE=$(git rev-parse HEAD); "$EX"
check "auto-commit skips on a detached HEAD" '[ "$(git rev-parse HEAD)" = "$HEADBEFORE" ]'
git checkout -q -- tracked.txt; git checkout -q trunk

# g. per-repository opt-out
touch .no-auto-commit; echo optout >> tracked.txt; HEADBEFORE=$(git rev-parse HEAD); "$EX"
check "auto-commit honors .no-auto-commit" '[ "$(git rev-parse HEAD)" = "$HEADBEFORE" ]'
rm -f .no-auto-commit; git checkout -q -- tracked.txt


# h. a secret inside an allowlisted NEW file also blocks
printf 'key=%s%s\n' 'AKIA' 'ZYXWVUTSRQPONMLK' > notes/leaky-new.txt; HEADBEFORE=$(git rev-parse HEAD); "$EX" 2>/dev/null
check "a secret in an allowlisted new file blocks the commit" '[ "$(git rev-parse HEAD)" = "$HEADBEFORE" ] && ! git ls-files --error-unmatch notes/leaky-new.txt >/dev/null 2>&1'
rm -f notes/leaky-new.txt

# i. ordinary prose with hyphens is not mistaken for an sk- key
echo "notes on task-planning-and-assessment-framework-for-distributed-teams-2026" >> tracked.txt; HEADBEFORE=$(git rev-parse HEAD); "$EX"
check "hyphenated prose containing 'sk-' is not treated as a secret" '[ "$(git rev-parse HEAD)" != "$HEADBEFORE" ]'

# j. a repository that requires signed commits is skipped, not overridden
echo signed-repo >> tracked.txt; HEADBEFORE=$(git rev-parse HEAD); git config commit.gpgsign true; "$EX"
check "auto-commit skips when commit.gpgsign is true" '[ "$(git rev-parse HEAD)" = "$HEADBEFORE" ]'
git config --unset commit.gpgsign; git checkout -q -- tracked.txt

# k. a nested repository under .claude/worktrees is not added as a gitlink
mkdir -p .claude/worktrees/x && ( cd .claude/worktrees/x && git init -q . && git commit -q --allow-empty -m nested )
echo tracked-edit >> tracked.txt; "$EX"
check "an untracked nested repository is not committed" '! git ls-files -s | grep -q "^160000"'
git checkout -q -- tracked.txt 2>/dev/null; rm -rf .claude

# l. a repository with no commits yet is skipped
mkdir -p "$ROOT/empty" && ( cd "$ROOT/empty" && git init -q -b trunk . && echo x > f.txt && git add f.txt && "$EX" )
check "auto-commit skips a repository with no commits" '[ -z "$(git -C "$ROOT/empty" log --oneline 2>/dev/null)" ]'

# m. claims (K7, playbook 13.3): an empty lease creates a branch only if it does not exist yet
git init -q --bare -b trunk "$ROOT/claim.git"
git clone -q "$ROOT/claim.git" "$ROOT/ca" 2>/dev/null; git clone -q "$ROOT/claim.git" "$ROOT/cb" 2>/dev/null
( cd "$ROOT/ca" && git checkout -q -b trunk 2>/dev/null; git commit -q --allow-empty -m init && git push -q origin trunk 2>/dev/null )
( cd "$ROOT/cb" && git fetch -q origin && git checkout -q -B trunk origin/trunk )
( cd "$ROOT/ca" && git commit -q --allow-empty -m "Claim work item 42" --trailer "Agent-Session: a" )
( cd "$ROOT/cb" && git commit -q --allow-empty -m "Claim work item 42" --trailer "Agent-Session: b" )
check "first claim with an empty lease succeeds" '( cd "$ROOT/ca" && git push -q --force-with-lease=refs/heads/agent/42: origin HEAD:refs/heads/agent/42 2>/dev/null )'
check "second claim with an empty lease is rejected" '! ( cd "$ROOT/cb" && git push -q --force-with-lease=refs/heads/agent/42: origin HEAD:refs/heads/agent/42 2>/dev/null )'
check "the first claim is still the branch tip after the second attempt" '[ "$(git -C "$ROOT/claim.git" rev-parse agent/42)" = "$(git -C "$ROOT/ca" rev-parse HEAD)" ]'
check "a later ordinary push by the holder renews the claim" '( cd "$ROOT/ca" && git commit -q --allow-empty -m work && git push -q origin HEAD:refs/heads/agent/42 2>/dev/null )'

# n. worker branch names (G3, playbook 13.4): nesting fails, a separator works
check "a branch nested under an existing branch is rejected (agent/42/a)" '! ( cd "$ROOT/ca" && git push -q origin HEAD:refs/heads/agent/42/a 2>/dev/null )'
check "a worker branch with a separator is accepted (agent/42--a)" '( cd "$ROOT/ca" && git push -q --force-with-lease=refs/heads/agent/42--a: origin HEAD:refs/heads/agent/42--a 2>/dev/null )'
check "agent branches can be listed by last commit date" '( cd "$ROOT/cb" && git fetch -q origin && git for-each-ref --sort=committerdate --format="%(committerdate:short) %(refname:short)" refs/remotes/origin/agent/ | grep -q "origin/agent/42--a" )'

# o. a worker tests for conflicts with the integration branch without touching its tree (G5)
( cd "$ROOT/ca" && echo base > shared.txt && git add shared.txt && git commit -qm base && git push -q origin HEAD:refs/heads/agent/42 2>/dev/null )
( cd "$ROOT/cb" && git fetch -q origin && git checkout -q -B agent/42--b origin/agent/42 && echo worker > shared.txt && git commit -qam worker )
( cd "$ROOT/ca" && echo coordinator > shared.txt && git commit -qam coord && git push -q origin HEAD:refs/heads/agent/42 2>/dev/null )
( cd "$ROOT/cb" && git fetch -q origin )
check "merge-tree reports a conflict with the moved integration branch" '! ( cd "$ROOT/cb" && git merge-tree --write-tree HEAD origin/agent/42 >/dev/null )'
check "the worker tree is untouched by the conflict test" '[ "$(cat "$ROOT/cb/shared.txt")" = worker ] && [ -z "$(git -C "$ROOT/cb" status --porcelain)" ]'

# ---------- examples/check-trailers.sh: provenance check (V3, B2, P1) ----------
CT="$HERE/../examples/check-trailers.sh"
check "example trailer check script exists and is executable" '[ -x "$CT" ]'
git init -q -b trunk "$ROOT/ct"; cd "$ROOT/ct" || exit 1
echo a > a.txt; git add a.txt; git commit -qm init; CT_BASE=$(git rev-parse HEAD)
git checkout -q -b human; echo h >> a.txt; git commit -qam "human change"
git checkout -q -b agent trunk; echo b >> a.txt; git commit -qam "agent change" --trailer "Assisted-by: claude-code"
git checkout -q trunk
printf 'What changed.\n\nAssisted-by: claude-code\nAgent-Session: https://example.com/s/1\n' > "$ROOT/good.md"
printf 'What changed.\n\nAssisted-by: claude-code\nAgent-Session: https://example.com/s/1\n\nGenerated with a tool\n\nhttps://example.com/s/1\n' > "$ROOT/footer.md"
printf 'What changed.\r\n\r\nAssisted-by: claude-code\r\n' > "$ROOT/crlf.md"
printf 'Assisted-by: claude-code\n' > "$ROOT/only.md"
printf 'What changed.\n' > "$ROOT/none.md"

# a. PR mode: the squash message is the PR title and description
check "a PR with no agent commits passes" '"$CT" pr "$CT_BASE" human "T" "$ROOT/none.md" >/dev/null'
check "a PR whose description ends with the trailer block passes" '"$CT" pr "$CT_BASE" agent "T" "$ROOT/good.md" >/dev/null'
check "a footer after the trailer block fails" '! "$CT" pr "$CT_BASE" agent "T" "$ROOT/footer.md" 2>/dev/null'
check "a description without the trailer fails" '! "$CT" pr "$CT_BASE" agent "T" "$ROOT/none.md" 2>/dev/null'
check "a description with CRLF line ends passes" '"$CT" pr "$CT_BASE" agent "T" "$ROOT/crlf.md" >/dev/null'
check "a description that is only the trailer block passes" '"$CT" pr "$CT_BASE" agent "T" "$ROOT/only.md" >/dev/null'

# b. landed mode: squash commits written from the footer and the good description
git merge -q --squash agent >/dev/null 2>&1; { echo "Agent change (#1)"; echo; cat "$ROOT/footer.md"; } | git commit -q -F -; CT_BAD=$(git rev-parse HEAD)
git reset -q --hard "$CT_BASE"
git merge -q --squash agent >/dev/null 2>&1; { echo "Agent change (#2)"; echo; cat "$ROOT/good.md"; } | git commit -q -F -; CT_GOOD=$(git rev-parse HEAD)
check "a landed commit with an unparsed Assisted-by line fails" '! "$CT" landed "$CT_BAD" 2>/dev/null'
check "a landed commit with the trailer block last passes" '"$CT" landed "$CT_GOOD" >/dev/null'
check "a landed range is checked commit by commit" '"$CT" landed "$CT_BASE..$CT_GOOD" >/dev/null && ! "$CT" landed "$CT_BASE..$CT_BAD" 2>/dev/null'
check "a usage error exits 2" '"$CT" landed 2>/dev/null; [ $? -eq 2 ]'
echo "----"; echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
