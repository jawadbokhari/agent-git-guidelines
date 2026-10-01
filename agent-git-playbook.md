---
title: Git playbook for teams of AI agents and humans
created: 2026-09-25
updated: 2026-09-25
tags:
  - ai
  - guideline
  - git
  - playbook
source: Companion to agent-git-guidelines.md v2, written 2026-09-25.
---

# Git playbook for teams of AI agents and humans

**Status:** informative companion to [`agent-git-guidelines.md`](./agent-git-guidelines.md) v2, 2026-09-25. It has no rules of its own. Each item names the rule it serves.
**Names products:** unlike the guideline, this playbook names products and settings. They change often. Each product fact says when it was checked. Re-check before relying on it.
**Tested:** every Git behavior this playbook relies on ran in throwaway repositories on Git 2.55.0 on 2026-09-25 ([`tests/verify-git-commands.sh`](./tests/verify-git-commands.sh), 69 of 69 checks passed). Plain commands with no special behavior, such as `git push -u`, were not tested. Results and their limits are in the research note, [section 7](./agent-git-guidelines-research.md#7-tests-run-for-v2).
**Blank tables** (sections 4 and 12) are for a person to fill in. Do not pre-fill them.

## 1. Session start and finish

Serves W1, W8, W9, H2, S2.

```bash
# Start: read the default branch from the remote, then make an isolated workspace.
git fetch origin
DEF=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)          # for example origin/trunk
[ -n "$DEF" ] || DEF=origin/$(git ls-remote --symref origin HEAD | awk '/^ref:/ {sub("refs/heads/","",$2); print $2}')
[ "$DEF" != "origin/" ] || { echo "cannot find the default branch"; exit 1; }
git worktree add ../<repo>-<task> -b agent/<task-id>-<slug> "$DEF"
```

```bash
# While working: a recovery point that does not touch the working tree, the index or the shared stash.
SNAP=$(git stash create) && [ -n "$SNAP" ] && git update-ref refs/agent/snapshots/<session-id> "$SNAP"
# Restore one file from it later:
git restore --source=refs/agent/snapshots/<session-id> -- <path>
```

`git stash create` records tracked changes and files that are staged. It does not record untracked files. Commit early ([H3](./agent-git-guidelines.md#6-branches-and-git-hygiene)) for those. The stash and every ref are shared by all worktrees of a repository, so name snapshot refs by session.

```bash
# Finish: look at exactly what you are about to land.
git fetch origin
git diff --stat "$DEF"...HEAD      # the full branch diff (S2, Q5)
git diff --staged                  # what the next commit will contain (H2)
```

## 2. Commit message

Serves C1 to C4, P1, P7.

```text
<Subject in the imperative mood, about 50 characters>

<Why: the problem, and why this change is the answer. What the diff does, in plain words.
State what you verified and how. State what you did not verify.>

Refs: <work item, in the tracker's syntax>
Assisted-by: <agent-name>[:<model-id>]
Agent-Session: <link to the session record>
```

```bash
# Pass the message as a file so shell quoting cannot mangle it. Add trailers with Git, not with text.
git commit -F <message-file> --trailer "Assisted-by: <agent-name>[:<model-id>]"
```

| Bad | Better |
|---|---|
| `Fix bug` | `Reject empty invoice numbers before saving` |
| `Update file` | `Read the retry limit from config instead of the constant` |
| `Address review` | Fold the change into the commit it belongs to with `git commit --fixup=<sha>` |
| `Add tests, all pass` (nothing was run) | Say what you ran, or say nothing about it |

## 3. Pull request template

Serves Q2, Q3, Q4, B2. Save as the repository's PR template.

```markdown
## What changed

## Why

## How it was verified
- Automated test that fails without this change:
- What I saw when I ran it:

## Risk and rollback

## Not done in this change

## AI involvement
- Drafted by (agent and model, session link), or "none":
- I have read the whole diff and can explain it:

## Work item

## Trailers for the landed commit
Paste the `Assisted-by:` and `Agent-Session:` lines here, as the last lines of this description. With squash merges they become the trailers of the landed commit (section 8).
```

## 4. Reviewer checklist for agent-authored changes

Serves Q9. Fill it in by hand while reading the change. Add the PR number or link in the first row.

| # | Check | Where to look | Reviewed | Notes |
|---|---|---|---|---|
| 1 | Every new dependency exists in the official registry and is not newly published (L4) | Manifest and lockfile diff | | |
| 2 | No test was weakened, skipped or deleted to make a check pass | Test diff, CI history | | |
| 3 | The test fails without the change (Q3) | Run it on the base commit | | |
| 4 | Security-relevant code (auth, input handling, secrets, permissions) had a closer read | The diff of those paths | | |
| 5 | Nothing changed outside the task | File list against the work item | | |
| 6 | Every claim in the description is supported by the diff | Description against diff | | |
| 7 | Protected paths untouched, or a code owner approved (L2) | File list, code-owners file | | |
| 8 | No secret, credential or personal data in the diff, message or description (I5) | Diff, message, description | | |
| 9 | The change can be read in one sitting, or the work is split (Q1, B4) | Diff stat | | |
| 10 | The P1 trailers will be on the landed commit (B2) | Description, merge method | | |
| 11 | The operator can explain the change in their own words (Q4) | Ask | | |

## 5. Client configuration

### 5.1 Human baseline

Serves E3. Choose the values that fit the team, then apply them with `git config --global`. Settings marked "taste" are a matter of preference among Git's own developers. Pick either `pull.ff` or `pull.rebase`, not both.

| Setting | Value | Why | Rule |
|---|---|---|---|
| `init.defaultBranch` | `main` | New repositories get one name. Existing ones keep theirs (W8) | W8 |
| `fetch.prune` | `true` | Remove local copies of deleted remote branches | |
| `pull.ff` | `only` | `git pull` fails instead of creating a surprise merge | H7 |
| `pull.rebase` | `true` (taste) | The alternative to `pull.ff = only` | |
| `push.autoSetupRemote` | `true` | First push sets the upstream | |
| `rebase.autoSquash` | `true` | Reorders fixup commits for you | C5 |
| `rebase.updateRefs` | `true` | Moves stacked branches when the base moves | B4 |
| `rebase.autoStash` | `true` (taste) | Stashes and restores local changes around a rebase | |
| `merge.conflictStyle` | `zdiff3` (taste) | Shows the base text inside a conflict | H7 |
| `rerere.enabled` | `true` | Reuses a conflict resolution you already made | H7 |
| `diff.algorithm` | `histogram` | Clearer diffs | |
| `commit.verbose` | `true` (taste) | Shows the diff in the commit editor | Q4 |
| `transfer.fsckObjects` | `true` | Checks objects received from a remote. Default is `false`. Costs some speed | E5 |
| `safe.bareRepository` | `explicit` | Refuses to use a bare repository that Git finds on its own. It must be named with `--git-dir` or `GIT_DIR`. This becomes the default in Git 3.0 | E5 |

### 5.2 Agent session environment

Serves E4, H6. Set these for a session. Commands that would open an editor or a pager, or ask for a password, then fail or finish instead of hanging.

```bash
export GIT_TERMINAL_PROMPT=0     # never prompt for credentials on the terminal
export GIT_PAGER=cat             # never start a pager
export GIT_EDITOR=true           # an editor call accepts the default text. A bare `git commit` then aborts on an empty message
export GIT_OPTIONAL_LOCKS=0      # background pollers only: `git status` will not refresh the index and fight for its lock
# Identity comes from variables, not from `git config` (H6):
export GIT_AUTHOR_NAME="<name>" GIT_AUTHOR_EMAIL="<email>" GIT_COMMITTER_NAME="<name>" GIT_COMMITTER_EMAIL="<email>"
```

Read status with `git status --porcelain=v2 -z`. Its format stays stable across Git versions and user configuration. Do not parse the default output.

### 5.3 What an agent session must not set

Serves H6. Not with `git config`, and not with `git -c` or `GIT_CONFIG_*` for one command: `core.hooksPath`, `core.sshCommand`, `core.fsmonitor`, `credential.*`, `gpg.*`, `commit.gpgsign`, `safe.*`, `url.*.insteadOf`. Do not set `help.autoCorrect` to `immediate` or to a number in agent sessions: Git would run its guess for a mistyped command. The default, `show`, only prints the suggestion.

## 6. Command reference for agents

Serves H4. Use the left column freely. The right column needs explicit human approval for each action, or is blocked by a guardrail.

| Need | Use | Needs approval instead |
|---|---|---|
| Unstage a file | `git restore --staged <path>` | `git reset --hard`, `git checkout -- .`, `git restore <path>` and `git restore .` (they discard edits) |
| Move to another branch | `git switch <branch>` (refuses to overwrite local changes) | `git switch -f`, `git switch --discard-changes`, `git checkout -f` |
| Update a branch that is not pushed yet | `git fetch origin`, then `git rebase "$DEF"` | |
| Update a branch that is already pushed | `git merge "$DEF"` (adds a commit, rewrites nothing) | `git rebase` on it, then a force-push |
| Check for conflicts first | `git merge-tree --write-tree <ours> <theirs>` (exit 1 means conflicts. It touches no file and no index) | Resolving with `-X ours`, `-X theirs` or `checkout --ours .` without review |
| Fold a fixup into its commit, before pushing | `git commit --fixup=<sha>`, then `GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash "$DEF"` | The same on a pushed branch. `git filter-repo`, `git filter-branch` |
| Delete a merged local branch | `git branch -d <name>` (refuses if unmerged) | `git branch -D <name>`, `git update-ref -d` |
| Remove a finished worktree | `git worktree remove <path>` (refuses if dirty) | `git worktree remove --force` |
| Publish a branch | `git push -u origin <branch>` | Any force-push, `git push --delete`, `git push :<ref>`, `git push --mirror` |
| Replace a pushed branch, after approval | `git push --force-with-lease=<ref>:<sha> --force-if-includes` | Bare `--force`. Bare `--force-with-lease` |
| Commit | `git commit -F <file> --trailer "..."` | `--no-verify`, `-c core.hooksPath=...` |
| Keep work in progress | A commit on the task branch, or a snapshot ref (section 1) | `git stash drop`, `git stash clear`, `git reflog expire`, `git gc --prune=now` |
| Update from the remote | `git pull --ff-only` (refuses when history has diverged) | |

## 7. Hooks

Serves P7, V6. A client hook is a first line only. `--no-verify` skips `pre-commit` and `commit-msg`, and `-c core.hooksPath=/dev/null` skips the repository's hooks, so the check on the landed commit (V3) is the control. Both bypasses were tested.

```sh
#!/bin/sh
# .githooks/commit-msg: while an agent session is active, require an Assisted-by trailer.
[ -n "$AGENT_SESSION" ] || exit 0
git interpret-trailers --parse "$1" | grep -q '^Assisted-by: ' || {
  echo "commit-msg: an agent commit needs an Assisted-by trailer (P1)" >&2; exit 1; }
```

```sh
#!/bin/sh
# .githooks/prepare-commit-msg: add the trailer for the agent when the session sets it.
[ -n "$AGENT_SESSION" ] && git interpret-trailers --in-place --trailer "Assisted-by: $AGENT_SESSION" "$1"
exit 0
```

Install with a bootstrap script the operator runs, for example `git config core.hooksPath .githooks`. An agent does not change the hooks path (H6).

**Auto-commit at session end (O3).** A reference script that meets O3 is [`examples/auto-commit.sh`](./examples/auto-commit.sh). It stages tracked changes, and new files only under the paths listed in `.auto-commit-paths`. It skips during a rebase, merge, cherry-pick or revert, on a detached HEAD, in a repository with no commits, with unresolved conflicts, and when the repository requires signed commits. It looks for secrets before it stages anything, so a hit leaves the index as it was and writes a log line. It marks the commit `auto:`, adds the `Assisted-by` trailer, never pushes, and honors a `.no-auto-commit` file. Seventeen checks cover it. The secret patterns are a floor, not a scanner, so add your own.

## 8. Squash merges and trailers

Serves B2, P6. The problem: a squash merge writes one commit whose message lists the branch's commits. The trailers of those commits sit inside the list, so they are no longer trailers. In the test, `git merge --squash` followed by a commit with the default message left the `Assisted-by` query empty. GitHub's default squash message has the same shape: the PR title and a list of the commits.

The default for agent PRs is squash (decision D2, 2026-09-25). The recipe:

1. Put the `Assisted-by:` and `Agent-Session:` lines at the end of the PR description (section 3).
2. Set the repository's squash commit message to the PR title and description.
3. After the first squash merge, run `git log -1 --format='%(trailers:key=Assisted-by,valueonly)'` on the default branch. It must print the value.
4. Keep the provenance check (V3) on the default branch. It catches every merge that did not follow steps 1 and 2.

With merge commits, the original commits and their trailers are kept. With rebase merges, the commits are recreated with a new committer and new hashes, so signatures made on the originals do not carry over.

## 9. Recovery drills

Serves R1, R2, R5, M2. Practice these in a scratch repository.

**Clobbered work (R2).** Stop writing. Do not force-push.

1. `git reflog` and `git reflog show <branch>`. Find the commit. `git branch rescue-<task> <sha>` puts a name on it. The default expiry is 90 days, or 30 for commits no branch reaches.
2. Nothing in the reflog: `git fsck --lost-found`. Commits appear in `.git/lost-found/commit/`. A commit that no ref points to is found here until `gc` prunes it.
3. A snapshot ref exists: `git restore --source=refs/agent/snapshots/<session-id> -- <path>`.
4. Make a fresh workspace from the latest default branch, cherry-pick the rescued commits, and land from there.
5. Edits that were never staged, committed or snapshotted exist only in the working tree. Git cannot bring them back.

**Rewritten or deleted remote history (R5).**

1. Freeze pushes to the repository.
2. Find a clone, mirror or CI cache that still has the old objects. Do not run `gc` in it.
3. Ask the host to restore the refs, and do it quickly, because unreachable objects are pruned after a grace period (`gc.pruneExpire` defaults to two weeks).
4. With approval, put the good commit back: `git push --force-with-lease=<ref>:<bad-sha> <remote> <good-sha>:refs/heads/<branch>`.
5. Find how the rewrite got past H4. Add the missing control.

**Exposed secret (R1).** Rotate first. Tell the security owner. Then remove it from live locations. Rewriting history is optional clean-up and does not replace rotation.

## 10. Host settings map

Serves E2, V3, L1, L2, X6, B5. Each cell says what was checked on 2026-09-25 and against which page. "Not checked" means this pass did not look, not that the feature is missing. A rule the host cannot express belongs in a server-side `pre-receive` hook (any self-hosted host).

| Control | GitHub | GitLab |
|---|---|---|
| Block force-pushes and deletions on the default branch | Ruleset rules "Block force pushes" and "Restrict deletions" | Not checked |
| Require a PR and passing status checks | Ruleset rules "Require a pull request before merging" and "Require status checks to pass before merging" | Not checked |
| Linear history | Ruleset rule "Require linear history" | Not checked |
| Signed commits | Ruleset rule "Require signed commits" | Push rule "Reject unsigned commits" (Premium or Ultimate) |
| Secret scanning before merge | Ruleset rule "Require secret scanning alerts are resolved" (needs Secret Protection or Advanced Security, added 2026-09-09) | Push rule "Prevent pushing secret files". It matches file names, not content (Premium or Ultimate) |
| Restrict paths, path length, extensions, file size | Ruleset rules "Restrict file paths", "Restrict file path length", "Restrict file extensions", "Restrict file size" | Push rules "Prohibited filenames" and "Maximum file size" |
| Commit message and branch name format, DCO | Not in the rule list fetched | Push rules on commit message expressions, "Branch name" and "Reject commits that aren't DCO certified" |
| Author cannot approve their own change | Not checked | "Prevent approval by merge request creator" and "Prevent approvals by users who add commits" |
| Approvals dropped when new commits arrive | Not checked | "Remove all approvals" |
| Code owners | A `CODEOWNERS` file in `.github/`, the root or `docs/`. It is read from the base branch. The last matching pattern wins. Owners are not requested on draft PRs | Not checked |
| Limit outside contributors | Disable PRs or limit creation to collaborators (2026-02-13). Cap open PRs for users without write access, per repository (2026-06-17) and per organization (2026-08-06) | Not checked |
| Immutable releases and tags | Immutable releases: the tag cannot be moved or deleted while the release exists, and a release attestation is generated | Not checked |
| CI hardening | Pin third-party actions to a full commit SHA. Default the `GITHUB_TOKEN` to read-only. Pass untrusted strings through environment variables. Workflow dependency locking is on a 2026 roadmap in preview | Not checked |
| Stacked PRs | Public preview since 2026-07-30. Same repository only | Not checked |

## 11. Attribution settings for common tools

Serves P1, P3. Checked 2026-09-25. Tools not listed here (Copilot coding agent, Cursor, Gemini CLI, Amp, Devin) were not checked in this pass.

| Tool | Default | How to change it | Limits |
|---|---|---|---|
| Claude Code | Commits get `Co-Authored-By: <active model name> <noreply@anthropic.com>`. PR descriptions get a "Generated with Claude Code" line | `attribution.commit` and `attribution.pr` (strings), `attribution.sessionUrl` (boolean). `attribution: false` hides all of it (needs v2.1.281 or later). Lock it in managed settings. Without a managed setting, your own instruction file or memory rule takes precedence over these lines | `attribution.commit` is a static string. A model id written into it goes stale when the model changes. Use the agent name alone, or add the trailer with a hook (section 7). The session link that Claude Code adds to cloud and remote sessions can serve as `Agent-Session:` |
| Aider | A `Co-authored-by` trailer on commits that contain its edits (`--attribute-co-authored-by`, on by default). It takes precedence over the `(aider)` suffix on the author and committer names, unless `--attribute-author` or `--attribute-committer` is set explicitly | `--no-attribute-co-authored-by` turns the trailer off. `--attribute-commit-message-author` prefixes the message with `aider: ` (off by default). `--no-attribute-author` and `--no-attribute-committer` turn the name suffix off | It has no `Assisted-by` option, so P1 needs a hook (section 7). Aider's two doc pages describe the defaults differently. This row follows the options reference |
| Codex CLI | Unconfirmed. A change merged on 2026-02-17 added a co-author-style trailer for Codex, controlled by a `commit_attribution` key | Was: a blank `commit_attribution` value turned it off | Do not rely on it. It was done by an instruction added to the model's prompt, not by a hook, so the model could leave it out. An open issue (openai/codex #31619) reports that it was removed and stopped working after version 0.131.0, and the current configuration reference does not list the key (checked 2026-09-25). An earlier default identity was reported to credit commits to an unrelated GitHub account (#19799). Check that the address in any trailer cannot belong to a real person. Add the trailer with a hook (section 7) |

**Carrying the model name (P1).** The trailer needs the agent. The model is optional, and the decision of 2026-09-25 is agent name only. If an audit later needs the model, there are three ways to get it. None is free.

1. **Agent name only**, for example `Assisted-by: claude-code`, set once in the tool's configuration. Deterministic. The model is missing, and the session link (where the tool adds one) points to the record that has it.
2. **A session-start hook stores the model, and the commit hook reads it.** In Claude Code, only the session-start hook receives the `model` field, and it can be absent (after `/clear` or a restored session). The stop hook that makes auto-commits does not get it. Deterministic when it works, and it needs a file per session.
3. **An instruction in the instruction file** telling the model to write its own id into the trailer. It carries the live model, and it is a request to the model, so it can be missed (P5).

**Optional provenance records (P8).** None of these is a standard. Treat them as labels.

- A line-level standard that stores attribution in Git notes under `refs/notes/ai`, and copies it across rebase, squash and cherry-pick.
- An open specification, at draft 0.1.0, for recording AI contributions. It does not say where records are stored.
- A tool that stores session checkpoints in the repository's own object store and links each commit with a trailer.

Notes refs are not part of the default fetch and push. In the test, a plain push did not send `refs/notes/ai` and a plain clone did not fetch it.

## 12. Repository baseline sign-off

Serves E1, E2, M4. One copy per repository. Fill it in by hand, checking each control live on the host, and record the date.

| Control | Rule | Done | Date | Checked by | Notes |
|---|---|---|---|---|---|
| Default branch: force-push blocked, deletion restricted | L1 | | | | |
| PR and required checks needed to land | L1, V3 | | | | |
| Stale approvals dismissed. Approval of the last push required | H5 | | | | |
| Code-owners file on the default branch lists the protected paths | L2 | | | | |
| Protected-path check runs as a required status check, drafts included | L2 | | | | |
| Secret scanning, push protection and merge block | V3 | | | | |
| CI token read-only by default. Actions pinned to a commit SHA | V3, U2 | | | | |
| Instruction file present. Mirrors in sync. Size under the ceiling | U4, U5, V3 | | | | |
| Merge method documented. Trailers survive it (checked with the query in section 8) | B2 | | | | |
| Provenance check on landed commits | V3, P6 | | | | |
| PR template present | Q2 | | | | |
| Contribution guide: review window, AI policy, and optionally a size budget | E1, Q1, Q7, X6 | | | | |
| `.gitignore`, `.gitattributes`, `.git-blame-ignore-revs` present | E1, H2, H8, C6 | | | | |
| Release tags restricted. Releases immutable | H9, B5 | | | | |
| Agent identity and credential scope | I1, I2 | | | | |
| Agents lack rights over protection, settings and visibility | I3 | | | | |
| Sandbox on. Unsandboxed escape hatch off for unattended runs | I4 | | | | |
| Guardrails load from a location the agent cannot write | V2 | | | | |
| Hook bootstrap script present | V6 | | | | |
| Last recovery drill | M2 | | | | |
