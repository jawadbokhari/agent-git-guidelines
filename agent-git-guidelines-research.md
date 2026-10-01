---
title: Research behind the agent Git guidelines
created: 2026-09-19
updated: 2026-09-25
tags:
  - ai
  - guideline
  - git
source: First research pass 2026-09-19, second pass 2026-09-25.
---

# Research behind the agent Git guidelines

**Status:** desk research. First pass 2026-09-19 (sources S01 to S47). Second pass 2026-09-25 (sources S48 to S123, tests T1 and T2). Supports [`agent-git-guidelines.md`](./agent-git-guidelines.md) v2 and [`agent-git-playbook.md`](./agent-git-playbook.md).
**Method, first pass:** five parallel research passes (standards, vendor controls, provenance, concurrency, incidents). Each claim was taken from a fetched source with a short exact quote. An independent verification pass then re-checked every statistic and incident claim, plus a sample of the rest, and a link check covered every URL. Verification status is shown per source in the [source list](#source-list). Claims marked *secondary* rest on a summary of the primary text, not the text itself.
**Method, second pass:** one researcher, working from a self-audit of v1 ([section 6](#6-self-audit-of-v1-and-what-v2-changed)). It fetched each source and took short quotes from the fetched text. It read three kinds of source as raw files: the Linux kernel documents, the Claude Code settings reference and the Git configuration documents. It ran 69 checks of Git behavior in throwaway repositories ([section 7](#7-tests-run-for-v2)). Second-pass sources use these marks: **F** fetched from the primary source, **R** read as a raw file, **2nd** secondary, **T** own test. **F and R mean one researcher checked the source once. They do not mean the independent re-check that V means for the first pass.** The fetch tool summarizes pages with a small model, so an F quote is only as good as that summary. Where a quote decided a rule, the raw file was read instead. This mattered once: the summary of Aider's git page described its co-author trailer as opt-in, and the raw options reference showed it is on by default (S82). It was corrected before publication. No independent verification pass and no adversarial review has been run on the v2 additions. Run one before treating a v2 rule as settled.

## 1. What the market has converged on

These practices appear across standards bodies and most vendors. The guideline treats them as the baseline.

1. **Least agency.** OWASP LLM06 names excessive functionality, permissions and autonomy as the root causes of agent harm. It requires authorization to be enforced "in downstream systems rather than relying on an LLM" [S01]. Joint government guidance from 2026 adds distinct agent identities, minimum-scope permissions, and a ban on agents changing their own privileges [S08].
2. **Agents work on their own branch and cannot merge their own change.** The Copilot coding agent pushes only to `copilot/` branches and "cannot push directly to your default branch". Its own approval does not count [S12]. GitLab's composite identity blocks one actor from authoring and approving the same change [S17]. Cursor and Jules also default to a new branch per task [S15, S16].
3. **Same review bar for AI and human code.** NIST SP 800-218A "does not distinguish between human-written and AI-generated source code" [S05]. OpenSSF's guide keeps the human "responsible for any harms" [S07].
4. **Hosted agents restrict network egress by default. Local agents do not.** Copilot's firewall, Codex cloud's offline agent phase, Cursor's allowlist mode and GitLab's sandboxed flows are all restricted by default [S12, S14, S15, S17]. GitLab documents its IDE and CLI agents as "Not applied" for sandboxing, with unrestricted network access [S17].
5. **A repository instruction file.** AGENTS.md is now stewarded by the Linux Foundation's Agentic AI Foundation [S24], and Copilot and Codex read it [S12, S14]. Some tools read only their own file, so teams keep mirrors or pointers.
6. **Isolation per session.** A worktree per agent is the dominant local pattern [S25]. A container or VM per task is the hosted pattern [S15, S16, S27].
7. **Small batches and short-lived branches make AI safer.** DORA says small batches amplify "the positive impact of AI adoption" and act "as a safety net for AI adoption" [S48]. Its trunk-based guidance is three or fewer active branches, lasting hours, merged at least daily [S49]. The 2025 DORA report found that AI adoption raises throughput but "does continue to have a negative relationship with software delivery stability", unless there are "robust control systems, like strong automated testing, mature version control practices, and fast feedback loops" [S50].
8. **The person who submits stays accountable and must understand the change.** The Linux kernel: "AI agents MUST NOT add Signed-off-by tags" [S79]. LLVM: "The contributor is always the author and is fully accountable" [S114]. CPython expects authors "to be able to explain their proposed changes in their own words" [S74]. Mesa: "The submitter is responsible for the code change, regardless of where that code change came from" [S76]. Ghostty: "The human-in-the-loop must fully understand all code" [S72].
9. **Hosts now give maintainers controls against contribution floods.** In 2026 GitHub added settings to turn PRs off or limit them to collaborators (February) [S65], to cap open PRs for users without write access (June, and per organization in August) [S77], and to block a merge while secret alerts are unresolved (September) [S78]. It reports that merged PRs rose from about 25 million a month in January 2023 to over 90 million [S93].
10. **The commit and review basics are old and stable.** One logical change per commit, an imperative subject, a description that says what and why, and small changes reviewed quickly [S51, S52, S54, S115, S116, S117].

## 2. Where the market disagrees, and what the guideline chose

| Question | Positions found | Guideline choice and reason |
|---|---|---|
| Who is the author of record? | Bot as author with the human as co-author (Copilot, Devin) [S12, S18]; human as author with the agent as a secondary identity (GitLab composite identity) [S17]; operator's own identity (most local CLIs) | Machine identity for delegated and headless runs, with the triggering human recorded. The operator's identity plus trailers for interactive runs (rule I1). The machine identity makes permissions and revocation per-agent. Recording the human keeps accountability |
| Can an agent approval count? | GitHub made Copilot approvals countable, as an admin opt-in (2026-09-01) [S13]; GitLab forbids self-approval by design [S17] | Advisory only. Never for its own PR, never for Protected paths (L3). Separation of duties is what SLSA Source L4 and OpenSSF Code-Review measure [S03, S06] |
| Which disclosure trailer? | `Co-authored-by:` is the vendor default (Claude Code, Aider, Copilot, Amp) [S19, S20, S81, S82]. Codex briefly added a co-author-style trailer by an instruction in the model's prompt, and its status is now unconfirmed [S83]. `Assisted-by:` (Linux kernel, LLVM, Fedora, Mesa) [S21, S22, S23, S76, S79]. `Generated-by:` (Apache, Mesa) [S34, S76]. The formats differ: the kernel simplified its tag on 2026-07-01 to `Assisted-by: LLM [TOOL...]`, with no agent or model [S79] | `Assisted-by:` with agent and model. It is the open-source convergence point on the tag name, and `Co-authored-by:` carries human contribution credit on GitHub [S33]. The agent-and-model form is local to this guideline because audits and incident response benefit from both. The model is optional (P1, D3, decided 2026-09-25). Vendor defaults must be reconfigured (P1, P3) |
| Is the agent sandboxed? | Yes by default for hosted agents; no, or opt-in, for local agents [S14, S17, S26] | Never assume it. Turn the sandbox on and lock the escape hatch for unattended runs (I4) |
| Who may trigger a CI agent? | Write-access checks and bot-actor rejection (claude-code-action, Copilot) [S12, S26]; looser or undocumented elsewhere | Write-access actors only, read-only tokens for untrusted text, no fork-secret triggers (U2) |
| May AI-generated content be contributed at all? | Banned: OpenJDK (interim policy) [S71], QEMU [S73], NetBSD ("presumed to be tainted code") [S75]. Conditional: Mesa (no autonomous tools, disclosure) [S76], CPython (submitter responsible, explain in own words, disclosure appreciated) [S74], Ghostty (disclose, human must understand) [S72]. Accepted with disclosure: Linux kernel [S79, S80], LLVM (no agents acting without human approval) [S114]. The policies are moving. Search results mention discussion of relaxing QEMU's on its mailing list, which was not verified. The policy file in its repository was last changed on 2026-05-20 (formatting only) and still says decline [S73] | Follow the target project's policy (X1). In our own repositories, accept with disclosure (P1) and the understanding rules (Q4). Agents never contribute to outside projects on their own (X2) |
| Which merge method? | GitHub offers merge commit, squash and rebase. A rebase merge recreates commits with a new committer and new hashes [S85]. The squash default message is the PR title and a list of the commits [S118]. Rulesets can require linear history [S64] | One documented method per repository, and the P1 trailers must survive it (B2). Tested: they do not survive a default squash (T1) |
| How much should an instruction file say? | Model providers recommend repository overviews in context files. A 2026 study found that "providing context files does not generally improve task success rates, while increasing inference cost by over 20% on average". Instructions in them are followed. Overviews are not helpful [S66] | Only what an agent cannot infer (U5) |
| How fine-grained should provenance be? | A trailer per commit (kernel, LLVM, Mesa) [S76, S79, S114]. Line-level Git notes (git-ai v3.0.0) [S69]. An open specification at draft 0.1.0 with no storage rule (Agent Trace) [S70]. Session checkpoints kept in repository refs [S84] | A trailer is required. The rest is optional and treated as a label (P8) |

## 3. Incidents and the controls they point to

| Incident | Date | What the postmortem or advisory recommends | Guideline rules |
|---|---|---|---|
| A malicious GitHub issue steered an agent using the GitHub MCP server into leaking private repository data [S28] | 2025-05 | Least-privilege tokens, one repository per session, a runtime guardrail layer | I2, U1, U3 |
| An over-scoped CI token let an attacker commit a destructive prompt into the Amazon Q VS Code extension, which shipped in 1.84.0 (CVE-2025-8217) [S29] | 2025-07 | Scope and rotate CI tokens, pull the release | I2, L2 (CI config is Protected) |
| A Replit agent deleted a production database during a code freeze [S30] | 2025-07 | Dev and prod separation, a planning-only mode, confirmation before destructive actions | H4, V1 (enforce in the environment, not in instructions) |
| Nx "s1ngularity": CI command injection stole a publish token, and malicious versions harvested credentials, partly by driving locally installed AI CLIs [S31] | 2025-08 | OIDC trusted publishing, manual approval on publishing, no CI for external contributors by default | I2, U2 |
| Shai-Hulud npm worm [S32] | 2025-09 | Rotate credentials, pin dependencies, MFA, secret scanning, branch protection | L4, R1, V3 |
| Rules-file backdoor: hidden Unicode in agent instruction files [S35] | 2025-03 | Review instruction files like code, detect hidden characters | U4, V3 (instruction-file check) |
| "PromptPwnd": AI agents in GitHub Actions and GitLab CI followed untrusted issue and PR text [S36] | 2025-12 | Restrict write access, never allow all users to trigger, avoid `pull_request_target` with secrets | U2 |
| An agent ran `git reset --hard` and `git checkout -- .` over uncommitted work [S37] | 2025 | Confirm before destructive commands | H4, H3 |
| Slopsquatting: agents suggest package names that do not exist, and attackers register them [S38] | ongoing | Lockfiles, hash checks, human review of new dependencies | L4 |
| The `tj-actions/changed-files` action's tags were moved to a malicious commit that printed secrets into workflow logs. The reviewdog action was compromised the same week [S95] | 2025-03 | Audit which workflows used it, "Rotate all identified secrets immediately as they should be considered compromised" [S95]. "Pinning an action to a full-length commit SHA is currently the only way to use an action as an immutable release" [S94] | V3 (pinned actions), R1 |
| Clone-time code execution in Git through submodules and hooks: CVE-2024-32002 (critical) and CVE-2025-48384 with CVE-2025-48385 [S120, S60] | 2024-05 and 2025-07 | Upgrade Git. "Avoid running `git clone` with `--recurse-submodules` against untrusted repositories". Set `transfer.bundleURI` to false [S60] | H10, E5 |
| Cursor CVE-2026-26268 (GHSA-8pcm-8jpx-hv8r): a malicious agent could write to improperly protected `.git` settings, including hooks, which ran outside the sandbox the next time Git ran them. Reported by Novee, fixed in Cursor 2.5 [S61] | 2026-02 | Protect `.git` from agent writes, sandbox the agent | H11, V2, E5 |
| GitHub's own push pipeline: unsanitized `git push` options were injected into internal metadata and led to command execution (CVE-2026-3854). Found by Wiz. GitHub reports no exploitation beyond the researchers, patched github.com within two hours, and told Enterprise Server users to upgrade [S119] | 2026-03 | Keep self-hosted hosts patched | E5, R1 |
| An agent ran `git filter-repo` with a size filter and force-pushed the rewritten history, which removed files from history. Second-hand report: no complete vendor root-cause report is public [S100] | 2026-04 | Test history rewrites on disposable clones, protect default branches and reject force-push remotely, require approval before rewrites [S100] | H4 (`filter-repo`), R5 |
| A flood of low-quality and machine-made PRs pushed projects to ban or restrict AI contributions and pushed GitHub to add PR controls [S65, S71 to S76, S77, S93] | 2026 | Read the project's policy, cap and limit outside PRs. LLVM defines an "extractive contribution" as one where "the marginal cost of reviewing and merging that contribution is greater than the marginal benefit to the project's producers" [S114] | X1, X6, Q7 |

## 4. Numbers worth knowing

| Figure | Source |
|---|---|
| Commits assisted by one popular coding agent leaked secrets at 3.2%, against a 1.5% baseline for all public GitHub commits. About 29 million secrets were leaked on public GitHub in 2025 (+34% year on year) | GitGuardian, State of Secrets Sprawl 2026 [S39] |
| 19.7% of packages recommended in 576,000 generated code samples did not exist | Socket / academic study [S38] |
| More than 1 million agent-created PRs on GitHub between May and September 2025 | GitHub Octoverse 2025 [S40] |
| When two different agent tools had PRs open in the same repository at the same time, 41.7% of those PR pairs conflicted. For two PRs from the same tool, 19.8% did | arXiv 2607.04697 [S41] |
| Overall merge rate of agent-authored PRs was 71.48%, ranging from 43% to 83% by tool | arXiv 2601.15195 [S42] |
| 27.67% of agent PRs conflicted with their base: more than 29,000 of over 107,000 PRs run through a merge simulation, with more than 336,000 conflict regions | AgenticFlict, arXiv 2604.03551 [S68] |
| The best models correctly resolve less than 60% of merge conflicts (7,938 hunks from 1,439 repositories) | Merge-Bench, arXiv 2605.25890 [S67] |
| About 4% of agent PRs are security-related. They have lower merge rates and longer review latency | arXiv 2601.00477 [S98] |
| Context files raise inference cost by over 20% on average and do not generally improve task success | arXiv 2602.11988 [S66] |
| Merged PRs on GitHub rose from about 25 million a month (January 2023) to over 90 million | GitHub blog [S93] |
| AI-co-authored PRs had 10.83 issues each against 6.45 for human-only PRs (about 1.7 times). 320 against 150 open-source PRs, with the AI label inferred from a co-author signal. A vendor report on a small sample: use it as motivation, not as a rate | CodeRabbit [S96] |
| AI adoption has a positive relationship with throughput and a negative one with delivery stability | DORA 2025 [S50] |

## 5. Gaps in the evidence

Carried over from the first pass, with their state after the second:

- **Stop at a rebase conflict, or resolve it?** Still no primary, agent-specific guidance. The second pass adds evidence around it: 27.67% of agent PRs conflict [S68], the best models resolve under 60% of conflicts correctly [S67], and in a test-driven setup Anthropic's parallel agents resolved frequent conflicts themselves [S91]. Rule H7 keeps the stop line for files other sessions changed and for protected paths. It allows resolution elsewhere with full verification. It is still a judgement call.
- **A numeric limit on work in progress for agents.** Still none found. The nearest sources are DORA's three or fewer active branches for human trunk teams [S49] and GitHub's PR caps for outside contributors [S77]. The guideline sets no number (Q7, D1).
- **The official text of the OWASP Top 10 for Agentic Applications (2026).** Still not retrieved. The official page only links a PDF [S99]. The ten names ASI01 to ASI10 (Agent Goal Hijack, Tool Misuse and Exploitation, Identity and Privilege Abuse, Agentic Supply Chain Vulnerabilities, Unexpected Code Execution, Memory and Context Poisoning, Insecure Inter-Agent Communication, Cascading Failures, Human-Agent Trust Exploitation, Rogue Agents) are known only through secondary summaries.
- **Codex CLI's default attribution behavior.** Resolved in part. A `commit_attribution` key was added by a change merged on 2026-02-17, and the trailer was requested through the model's prompt, not added by a hook. An open issue reports that the feature was removed and stopped working after version 0.131.0, and the current configuration reference does not list the key (checked 2026-09-25) [S83]. Codex attribution is therefore unconfirmed, and the playbook says not to rely on it.
- **Primary texts for the NetBSD, Mesa and CPython AI policies.** Retrieved [S75, S76, S74].
- **Trunk-based development as a way to keep agent branches short.** Now backed by a primary source [S49, S48]. DORA is survey research on human teams, so the fit to agents is still an inference.

New in the second pass:

- **No independent verification** of the v2 additions (see Method).
- **No primary source gives a numeric PR size limit** for agent-authored changes. The owner decided on 2026-09-25 not to set or enforce one (D1).
- **Agent Trace and git-ai are drafts with little adoption evidence** [S69, S70]. The guideline makes them optional (P8, D4).
- **Policies keep moving.** Several projects adopted or changed policies during 2026, and a relaxation of QEMU's was reported in search results but not verified [S73]. Expect drift (M3).
- **The names of the seven DORA AI capabilities** could not be fetched from dora.dev. Only the report announcement was read [S50].
- **GitHub's squash behavior was checked in its documentation [S118] and through Git's own `merge --squash` [T1], not on a live host.**
- **The GitLab column of the host map is mostly "not checked"**, and so are the attribution defaults of Copilot, Cursor, Gemini CLI, Amp and Devin (playbook sections 10 and 11).
- **Some rules have no primary source.** They are judgement calls, listed in the [rule-to-source map](#rule-to-source-map).

## 6. Self-audit of v1 and what v2 changed

The v1 guideline was strong on security and governance and thin on how people and agents work in Git day to day. The audit compared it with the areas the task named and with the gaps above.

| # | Finding in v1 | Evidence | v2 rules |
|---|---|---|---|
| G1 | Commit quality had one rule (H3) | S53, S54, S102, S103, S106, S116, S117 | C1 to C8 |
| G2 | No branching, merge or release guidance for humans. H9 only stopped agents from tagging | S48, S49, S63, S64, S85, S108, S118, S122 | B1 to B6 |
| G3 | No rules on PR size, description, evidence or review capacity. A2 covered only the review bar | S51, S52, S74, S80, S96, S97, S98, S114, S115 | Q1 to Q10 |
| G4 | Nothing on non-interactive Git use, default-branch discovery, index locks or identity by variable | S56, S58, S102, S105, T2 | W8, E4, H6 |
| G5 | No repository baseline: files and host rules | S64, S88, S89, S106, S107, S113 | E1, E2 |
| G6 | No client configuration baseline | S56, S57, S123 | E3 |
| G7 | Missing security items: `.git` internals, patching, pinned actions, immutable releases | S60, S61, S62, S63, S94, S95, S119, S120 | H11, E5, V3, B5 |
| G8 | Nothing on contributing to repositories the operator does not own, or on maintainers facing floods | S65, S71 to S76, S77, S79, S80, S93, S114 | X1 to X6, Q7 |
| G9 | Multi-agent gaps: atomic claims, runtime isolation, conflicts | S68, S86, S91, S92 | W2, W7, H7 |
| G10 | The instruction-file rule assumed more content helps | S66 | U5 |
| G11 | No measurement and no review cadence for the guideline | S50, S109 | M1 to M4 |
| G12 | A solo owner could not meet A1. Auto-commit hooks were not addressed. Guardrails scoped too widely blocked unrelated writes | Internal review of a deployed guardrail; judgement | A1, O1 to O5, V5 |
| G13 | Recovery: the shared stash, snapshots, reflog expiry, history rewrites | S55, S87, S100, S104, S110, S121, T2 | W1, W9, R2, R5 |
| G14 | Provenance: trailers vanish under squash. Some tools only ask the model to add them | S69, S70, S83, S84, S118, T1 | B2, P3, P5 to P8 |
| G15 | The H4 list was incomplete: `filter-repo`, `branch -D`, `reflog expire`, `-c core.hooksPath` | S100, S111, T2 | H4 |

**Corrections to v1.**

- v1 presented `Assisted-by:` as following the Linux kernel, with an example in the form `<agent-name>:<model-id>`. The kernel's own format was `AGENT_NAME:MODEL_VERSION` when the doc was added on 2025-12-23, and it was simplified on 2026-07-01 to `Assisted-by: LLM [TOOL1] [TOOL2]` [S79]. The convergence is on the tag name, not on carrying agent and model. v2 says so in P1 and keeps the richer local form.
- v1 said Codex's attribution behavior was unclear. It is now known in part (section 5).
- v1's P6 query was presented without a caveat. It cannot see trailers after a default squash merge (T1). v2 adds the caveat and B2.

## 7. Tests run for v2

**T1. Trailers under a squash.** Git 2.55.0, 2026-09-25. A branch of two commits, each ending with `Assisted-by: agent-x:model-y`. After `git merge --squash` and a commit with `.git/SQUASH_MSG`, the trailers sat inside indented quoted commit blocks. `git interpret-trailers --parse` on the message returned nothing, and `git log --format='%(trailers:key=Assisted-by,valueonly)'` printed an empty line. Writing the final message with the trailers as its last lines (the recipe in playbook section 8) made the query return the value. Limit: this is Git's own squash. GitHub's default squash message has the same shape [S118], but no live host was tested.

**T2. Behavior checks.** [`tests/verify-git-commands.sh`](./tests/verify-git-commands.sh) ran 69 checks on Git 2.55.0 on macOS, in throwaway repositories with no global configuration. All 69 passed. The groups:

| Group | Checks |
|---|---|
| Default branch read from `origin/HEAD` and from `ls-remote --symref`, on a repository whose default branch is `trunk` | 2 |
| `git stash create` plus a private ref: does not touch the working tree or the shared stash, restores with `git restore --source`, captures staged new files and not untracked ones | 8 |
| `git merge-tree --write-tree`: exit 1 on conflict, exit 0 when clean, leaves the working tree and index unchanged | 3 |
| Trailers: `git commit --trailer`, `interpret-trailers --parse`, the log format query | 2 |
| Fixup and autosquash, non-interactive | 1 |
| `git status --porcelain=v2 -z` uses NUL separators | 1 |
| `--force-with-lease=<ref>:<sha>` with `--force-if-includes`: succeeds with the right expectation, is rejected with a stale one | 2 |
| `GIT_OPTIONAL_LOCKS=0` leaves the index untouched, with a control run showing that a normal `git status` does refresh it | 1 (plus 1 control) |
| Notes: a default push does not send `refs/notes/ai`, an explicit push does, a plain clone does not fetch it | 3 |
| Recovery: reachable through the reflog after `branch -D`, gone after `reflog expire` and `gc --prune=now`, restorable after `reset --hard`, found by `fsck --lost-found` | 6 |
| `GIT_EDITOR=true git commit` aborts on an empty message | 1 |
| Hooks: a `commit-msg` hook blocks an agent commit with no trailer, `--no-verify` and `-c core.hooksPath=/dev/null` bypass it, a `prepare-commit-msg` hook adds a parseable trailer | 5 |
| Squash: the default message loses the trailer, the recipe keeps it | 2 |
| Worktrees: one branch per worktree, the stash and refs are shared, `remove` refuses a dirty tree and `--force` removes it | 5 |
| `branch -d` refuses unmerged and `-D` deletes, `switch` refuses to overwrite and `switch -f` discards, `pull --ff-only` refuses on divergence | 5 |
| `safe.bareRepository=explicit` refuses implicit discovery, and `--git-dir` still works | 2 |
| `blame --ignore-revs-file` skips a reformat commit | 2 |
| `cherry-pick -x` records the source commit | 1 |
| The reference auto-commit script ([`examples/auto-commit.sh`](./examples/auto-commit.sh), rule O3): commits a tracked change with the `auto:` prefix and the trailer, never pushes, leaves untracked files alone, commits allowlisted new files, blocks a secret pattern before staging and leaves the index as it was, logs the block, does not mistake hyphenated prose for a key, skips during a rebase, on a detached HEAD, in an empty repository, with signing required and with an opt-out file, and ignores a nested repository. The same checks also passed against the real hook it was adapted into | 17 |

Limits: one Git version and one operating system. No Windows or Linux run. No live host. No agent tool was driven. The tests establish what Git does, not what any agent will do.

## Rule-to-source map

Rules marked *judgement* have no primary source. They come from combining the evidence above with the incident record.

| Rules | Sources |
|---|---|
| A1, A2 | S03, S05, S06, S07 |
| I1 | S08, S12, S17, S18 |
| I2, I3 | S01, S04, S06, S08, S28, S29, S31 |
| I4 | S02, S14, S15, S17, S26 |
| I5, I6 | S07, S39 |
| W1, W6 | S25, S27, S55, T2 |
| W2, W3 | S10, S41, S68, S91, S92 |
| W4, W5 | S11, S43, S49 |
| W7 | S91, S92 |
| W8 | S56, T2 |
| W9 | S104, S121, T2 |
| C1, C2 | S51, S54, S102, S116, S117 |
| C3 | S05 |
| C4 | *judgement* |
| C5 | S57, S102, T2 |
| C6 | S106, T2 |
| C7 | S53 |
| C8 | S103, T2 |
| H1 | S12, S15 |
| H2, H3 | S44 |
| H4, H7 | S09, S37, S45, S67, S68, S86, S91, S100, S111, T2 |
| H5, H8 | S03 (continuous, immutable history), S06 (stale-review dismissal is part of Scorecard's Branch-Protection check), practitioner consensus |
| H6 | S58, S111, *judgement* on the list of keys |
| H9 | S06, S31 (release publishing was the Nx attack path), S63, S108 |
| H10 | S02 (ASI04 supply chain), S35, S60, S120 |
| H11 | S59, S61 |
| B1 | S48, S49, S50 |
| B2 | S64, S85, S118, T1, T2 |
| B3 | S51, S64 |
| B4 | S57, S122 |
| B5 | S63, S108 |
| B6 | S103 |
| Q1 | S51 |
| Q2 | S97, S116 |
| Q3 | S74, S97 |
| Q4 | S72, S74, S76, S79 |
| Q5 | S113, S114 |
| Q6 | S52, *judgement* |
| Q7 | S77, S93, S114, S115 |
| Q8 | S52 |
| Q9 | S50, S74, S96, S98 |
| Q10 | S114 |
| L1 to L5 | S03, S06, S12, S13, S17, S38, S89, S113 |
| P1 | S19, S20, S21, S22, S23, S34, S76, S79, S81, S82, S83, S114 |
| P2 | S46, S47, S54, S79 |
| P3 | S33, S81, S82, S83 |
| P4 | S46, S47 |
| P5 | S83 |
| P6 | S112, T1 |
| P7 | S102, S111, S112, T2 |
| P8 | S69, S70, S84, S101, T2 |
| V1 | S01, S06, S08, S35, S39, S45, S59, S111, T2 |
| V2 | S08 (no self-modification of privileges), S59, S81 |
| V3 | S39, S64, S78, S88, S94, S95 |
| V4 | S45 |
| V5 | S45, *judgement* (from an internal review of a deployed guardrail) |
| V6 | S111 |
| U1 to U4, U6 | S01, S24, S28, S35, S36 |
| U5 | S66 |
| S1 to S5 | S07, S08 |
| R1, R3, R4 | S29, S31, S32, S95, S119 |
| R2 | S37, S87, S110, T2 |
| R5 | S87, S100 |
| X1 | S71, S72, S73, S74, S75, S76, S79, S114 |
| X2 | S76, S79, S114 |
| X3 | S76, S79 |
| X4 | S79 |
| X5 | S72, S74, S76 |
| X6 | S65, S77, S93 |
| E1 | S106, S107, S113 |
| E2 | S64, S78, S88, S89 |
| E3 | S56, S57, S123 |
| E4 | S58, S102, S105, T2 |
| E5 | S56, S60, S61, S119, S120, T2 |
| E6 | S90 |
| E7 | S56 |
| O1 to O5 | *judgement* |
| M1 | S50, S109 |
| M2 to M4 | *judgement* |
| Autonomy levels | as the rules they cite |

## Source list

Access date for all sources: first pass 2026-09-19 (S01 to S47), second pass 2026-09-25 (S48 to S123). Marks for S01 to S47: **V** independently re-checked against the source, **C** cited from a fetched primary source but not re-checked, **2nd** secondary summary, **?** uncertain or conflicting. Marks for S48 onward: **F** fetched from the primary source, **R** read as a raw file, **2nd** secondary, **T** own test. See Method for what F and R do and do not mean.

| ID | Source | Type | Status |
|---|---|---|---|
| S01 | [OWASP LLM06:2025 Excessive Agency](https://github.com/OWASP/www-project-top-10-for-large-language-model-applications/blob/main/2_0_vulns/LLM06_ExcessiveAgency.md) and [LLM01 Prompt Injection](https://github.com/OWASP/www-project-top-10-for-large-language-model-applications/blob/main/2_0_vulns/LLM01_PromptInjection.md) | Standard | C |
| S02 | [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/) | Standard | 2nd |
| S03 | [SLSA v1.2 Source requirements](https://slsa.dev/spec/v1.2/source-requirements) | Standard | V |
| S04 | [NIST SP 800-218A, SSDF generative AI profile](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-218A.pdf), PS.1.1 | Standard | C |
| S05 | Same document, the statement that human-written and AI-generated code are treated alike | Standard | V |
| S06 | [OpenSSF Scorecard checks](https://github.com/ossf/scorecard/blob/main/docs/checks.md) and [SCM Best Practices](https://best.openssf.org/SCM-BestPractices/github/repository/code_review_not_required.html) | Standard | C |
| S07 | [OpenSSF Security-Focused Guide for AI Code Assistant Instructions](https://best.openssf.org/Security-Focused-Guide-for-AI-Code-Assistant-Instructions.html) | Standard | V |
| S08 | "Careful adoption of agentic AI services", ASD's ACSC with CISA, NSA and partners, 2026 ([PDF](https://cyberscoop.com/wp-content/uploads/sites/3/2026/05/CAREFUL-ADOPTION-OF-AGENTIC-AI-SERVICES_FINAL.pdf)) | Government guidance | V |
| S09 | [git-push documentation](https://git-scm.com/docs/git-push) (`--force`, `--force-with-lease`) | Tool doc | C |
| S10 | [Anthropic: multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) | Vendor blog | C |
| S11 | [GitHub merge queue](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue) and [GitLab merge trains](https://docs.gitlab.com/ci/pipelines/merge_trains/) | Vendor doc | C |
| S12 | [GitHub: responsible use of the Copilot coding agent](https://docs.github.com/en/copilot/responsible-use-of-github-copilot-features/responsible-use-of-copilot-coding-agent-on-githubcom) | Vendor doc | V |
| S13 | [GitHub changelog 2026-09-01: Copilot code review can approve PRs](https://github.blog/changelog/2026-09-01-copilot-code-review-can-now-approve-pull-requests/) | Vendor doc | V |
| S14 | [OpenAI Codex approvals and security](https://learn.chatgpt.com/docs/agent-approvals-security), [internet access](https://learn.chatgpt.com/docs/cloud/internet-access), [AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md) | Vendor doc | C |
| S15 | [Cursor Cloud Agents: security and network](https://cursor.com/docs/cloud-agent/security-network) | Vendor doc | C |
| S16 | Google Jules sandbox description ([secondary summary](https://www.digitalapplied.com/blog/google-jules-gemini-async-coding-agent-guide)) | Vendor blog | 2nd |
| S17 | [GitLab Duo composite identity](https://docs.gitlab.com/user/duo_agent_platform/composite_identity/) and [security threats](https://docs.gitlab.com/user/duo_agent_platform/security_threats/) | Vendor doc | V |
| S18 | [Devin review workflow](https://docs.devin.ai/work-with-devin/devin-review) | Vendor doc | C |
| S19 | [Claude Code settings: attribution](https://code.claude.com/docs/en/settings-reference) | Vendor doc | C |
| S20 | [Aider git integration](https://aider.chat/docs/git.html) | Vendor doc | C |
| S21 | [Linux kernel: AI coding assistants](https://docs.kernel.org/process/coding-assistants.html). The tag format described in the first pass was replaced on 2026-07-01, see S79 | Project policy | V |
| S22 | [LLVM AI Tool Policy](https://llvm.org/docs/AIToolPolicy.html) | Project policy | V |
| S23 | [Fedora policy on AI-assisted contributions](https://communityblog.fedoraproject.org/council-policy-proposal-policy-on-ai-assisted-contributions/). It encourages disclosure and suggests `Assisted-by:`, but does not mandate disclosure | Project policy | V |
| S24 | [Linux Foundation: Agentic AI Foundation announcement](https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation) | Press release | C |
| S25 | [Claude Code: worktrees](https://code.claude.com/docs/en/worktrees) | Vendor doc | C |
| S26 | [Claude Code: GitHub Actions](https://code.claude.com/docs/en/github-actions) and [sandboxing](https://code.claude.com/docs/en/sandboxing) | Vendor doc | C |
| S27 | [Dagger container-use](https://github.com/dagger/container-use) | Project doc | C |
| S28 | [Invariant Labs: GitHub MCP vulnerability](https://invariantlabs.ai/blog/mcp-github-vulnerability) | Security research | C |
| S29 | [AWS security bulletin AWS-2025-015](https://aws.amazon.com/security/security-bulletins/AWS-2025-015/) | Vendor advisory | V |
| S30 | [The Register: Replit incident](https://www.theregister.com/2025/07/21/replit_saastr_vibe_coding_incident/) | News | 2nd |
| S31 | [Nx s1ngularity postmortem](https://nx.dev/blog/s1ngularity-postmortem) | Vendor postmortem | C |
| S32 | [CISA alert: npm supply chain compromise](https://www.cisa.gov/news-events/alerts/2025/09/23/widespread-supply-chain-compromise-impacting-npm-ecosystem) | Government advisory | V |
| S33 | [GitHub: commits with multiple authors](https://docs.github.com/en/pull-requests/committing-changes-to-your-project/creating-and-editing-commits/creating-a-commit-with-multiple-authors) | Vendor doc | C |
| S34 | [ASF Generative Tooling Guidance](https://www.apache.org/legal/generative-tooling.html) | Project policy | C |
| S35 | [Pillar Security: rules file backdoor](https://www.pillar.security/blog/new-vulnerability-in-github-copilot-and-cursor-how-hackers-can-weaponize-code-agents) | Security research | C |
| S36 | [Aikido: PromptPwnd](https://www.aikido.dev/blog/promptpwnd-github-actions-ai-agents) | Security research | V |
| S37 | [anthropics/claude-code issue #7232](https://github.com/anthropics/claude-code/issues/7232) | Incident report | V |
| S38 | [Socket: slopsquatting](https://socket.dev/blog/slopsquatting-how-ai-hallucinations-are-fueling-a-new-class-of-supply-chain-attacks) | Security research | V |
| S39 | [GitGuardian: State of Secrets Sprawl 2026](https://blog.gitguardian.com/the-state-of-secrets-sprawl-2026/) | Industry report | V |
| S40 | [GitHub Octoverse 2025](https://github.blog/news-insights/octoverse/octoverse-a-new-developer-joins-github-every-second-as-ai-leads-typescript-to-1/) | Vendor report | V |
| S41 | [arXiv 2607.04697: AI agent PRs, frequency and merge conflict rates](https://arxiv.org/abs/2607.04697v2) | Academic | V |
| S42 | [arXiv 2601.15195: where AI coding agents fail](https://arxiv.org/abs/2601.15195). An earlier pass cited arXiv 2509.14745 for this figure. That paper is a single-agent study | Academic | V |
| S43 | [Graphite: stacked PRs](https://graphite.com/blog/stacked-prs) | Vendor blog | C |
| S44 | [git-add documentation](https://git-scm.com/docs/git-add) | Tool doc | C |
| S45 | [pydevtools: stopping agents bypassing pre-commit hooks](https://pydevtools.com/handbook/how-to/how-to-stop-ai-agents-from-bypassing-pre-commit-hooks/) | Practitioner doc | 2nd |
| S46 | [Sigstore gitsign](https://github.com/sigstore/gitsign) | Project doc | C |
| S47 | [GitHub: commit signature verification and vigilant mode](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification) | Vendor doc | C |
| S48 | [DORA: working in small batches](https://dora.dev/capabilities/working-in-small-batches/) | Research program | F |
| S49 | [DORA: trunk-based development](https://dora.dev/capabilities/trunk-based-development/) | Research program | F |
| S50 | [Google Cloud: announcing the 2025 DORA report](https://cloud.google.com/blog/products/ai-machine-learning/announcing-the-2025-dora-report) | Vendor blog on research | F |
| S51 | [Google engineering practices: small CLs](https://google.github.io/eng-practices/review/developer/small-cls.html) | Practice guide | F |
| S52 | [Google engineering practices: the standard of code review](https://google.github.io/eng-practices/review/reviewer/standard.html) | Practice guide | F |
| S53 | [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) | Specification | F |
| S54 | [Git: SubmittingPatches](https://git-scm.com/docs/SubmittingPatches) | Project policy | F |
| S55 | [git-worktree](https://git-scm.com/docs/git-worktree) | Tool doc | F |
| S56 | [Git 3.0 planned breaking changes](https://git-scm.com/docs/BreakingChanges) | Tool doc | F |
| S57 | [GitButler: how core Git developers configure Git](https://blog.gitbutler.com/how-git-core-devs-configure-git) | Practitioner blog | F |
| S58 | [git(1), environment variables](https://git-scm.com/docs/git) | Tool doc | F |
| S59 | [Claude Code: permissions](https://code.claude.com/docs/en/permissions). A deny or ask rule "isn't a security boundary around the program". Pattern rules on arguments are "fragile". Sandboxing is the enforcement that does not depend on command text | Vendor doc | R |
| S60 | [GitHub blog: Git security vulnerabilities announced (2025-07-08)](https://github.blog/open-source/git/git-security-vulnerabilities-announced-6/) | Vendor advisory | F |
| S61 | [Hackread on CVE-2026-26268](https://hackread.com/cursor-ai-ide-vulnerability-code-execution-git-hooks/), with [SentinelOne](https://www.sentinelone.com/vulnerability-database/cve-2026-26268/) and [The Hacker News](https://thehackernews.com/2026/07/cursor-flaw-lets-malicious-cloned.html). The NVD page could not be fetched | News and vulnerability databases | 2nd |
| S62 | [GitHub: what's coming to the Actions 2026 security roadmap](https://github.blog/news-insights/product-news/whats-coming-to-our-github-actions-2026-security-roadmap/) | Vendor blog | F |
| S63 | [GitHub: immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases) | Vendor doc | F |
| S64 | [GitHub: available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets) | Vendor doc | F |
| S65 | [GitHub changelog 2026-02-13: pull request access settings](https://github.blog/changelog/2026-02-13-new-repository-settings-for-configuring-pull-request-access/) | Vendor doc | F |
| S66 | [arXiv 2602.11988: Evaluating AGENTS.md](https://arxiv.org/abs/2602.11988) (ETH Zurich SRI Lab, submitted 2026-02-12) | Academic | F |
| S67 | [arXiv 2605.25890: Merge-Bench](https://arxiv.org/abs/2605.25890) (submitted 2026-05-25) | Academic | F |
| S68 | [arXiv 2604.03551: AgenticFlict](https://arxiv.org/abs/2604.03551) (submitted 2026-04-04) | Academic | F |
| S69 | [git-ai standard v3.0.0](https://github.com/git-ai-project/git-ai/blob/main/specs/git_ai_standard_v3.0.0.md) | Project spec | F |
| S70 | [Agent Trace, version 0.1.0 RFC](https://agent-trace.dev/) | Draft specification | F |
| S71 | [OpenJDK interim policy on generative AI](https://openjdk.org/legal/ai) | Project policy | F |
| S72 | [Ghostty AI_POLICY.md](https://github.com/ghostty-org/ghostty/blob/main/AI_POLICY.md). Only the quotes on disclosure, human understanding and the maintainer exemption were confirmed. A rule about pre-approved issues appears only in secondary summaries and is not used | Project policy | F |
| S73 | [QEMU code provenance](https://www.qemu.org/docs/master/devel/code-provenance.html). Also read: the repository's current file and its commit history through the GitHub API on 2026-09-25 | Project policy | F |
| S74 | [CPython devguide: guidelines for using AI tools](https://devguide.python.org/getting-started/ai-tools/) | Project policy | F |
| S75 | [NetBSD commit guidelines](https://www.netbsd.org/developers/commit-guidelines.html) | Project policy | F |
| S76 | [Mesa: submitting patches](https://docs.mesa3d.org/submittingpatches.html) | Project policy | F |
| S77 | GitHub changelog: [limit open PRs for users without write access (2026-06-17)](https://github.blog/changelog/2026-06-17-limit-open-pull-requests-for-users-without-write-access/) and [organization-level limits (2026-08-06)](https://github.blog/changelog/2026-08-06-set-pull-request-limits-at-the-organization-level/) | Vendor doc | F |
| S78 | [GitHub changelog 2026-09-09: block PRs with exposed secrets from merging](https://github.blog/changelog/2026-09-09-block-pull-requests-with-exposed-secrets-from-merging/) | Vendor doc | F |
| S79 | [Linux kernel: coding-assistants.rst](https://github.com/torvalds/linux/blob/master/Documentation/process/coding-assistants.rst), read in full. History: added 2025-12-23, attribution simplified 2026-07-01, bug-finding steps added 2026-08-02 | Project policy | R |
| S80 | [Linux kernel: generated-content.rst](https://github.com/torvalds/linux/blob/master/Documentation/process/generated-content.rst), read in full | Project policy | R |
| S81 | [Claude Code settings reference](https://code.claude.com/docs/en/settings-reference), the `attribution`, `includeCoAuthoredBy`, `sandbox.allowUnsandboxedCommands` and managed-only keys | Vendor doc | R |
| S82 | [Aider: git integration](https://aider.chat/docs/git.html) and the [options reference](https://aider.chat/docs/config/options.html). The two pages describe attribution differently. The options reference was read raw and is the one relied on: `--attribute-co-authored-by` defaults to true and takes precedence over the `(aider)` name suffix unless `--attribute-author` or `--attribute-committer` is set explicitly | Vendor doc | R |
| S83 | [openai/codex PR #11617](https://github.com/openai/codex/pull/11617), with issues [#19799](https://github.com/openai/codex/issues/19799) and [#31619](https://github.com/openai/codex/issues/31619), and the [Codex configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference), which does not list the key | Project code, issues and vendor doc | F |
| S84 | [Entire CLI](https://github.com/entireio/cli), session checkpoints | Project doc | F |
| S85 | [GitHub: about pull request merges](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/about-pull-request-merges) | Vendor doc | F |
| S86 | [git-merge-tree](https://git-scm.com/docs/git-merge-tree) | Tool doc | F |
| S87 | [git-gc](https://git-scm.com/docs/git-gc), expiry defaults | Tool doc | F |
| S88 | [GitLab: push rules](https://docs.gitlab.com/user/project/repository/push_rules/) | Vendor doc | F |
| S89 | [GitLab: merge request approval settings](https://docs.gitlab.com/user/project/merge_requests/approvals/settings/) | Vendor doc | F |
| S90 | [GitHub blog: partial clone and shallow clone](https://github.blog/open-source/git/get-up-to-speed-with-partial-clone-and-shallow-clone/) | Vendor blog | F |
| S91 | [Anthropic: building a C compiler with a team of parallel Claudes](https://www.anthropic.com/engineering/building-c-compiler) | Vendor blog | F |
| S92 | [Ready Solutions: seven Claude Code sessions on one repo](https://readysolutions.ai/blog/2026-06-06-parallel-claude-code-sessions-one-repo/) | Practitioner blog | 2nd |
| S93 | [GitHub blog: how pull request limits are cutting down the noise](https://github.blog/open-source/maintainers/how-pull-request-limits-are-cutting-down-the-noise/) | Vendor blog | F |
| S94 | [GitHub Actions: secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) | Vendor doc | F |
| S95 | [CISA alert: supply chain compromise of tj-actions/changed-files and reviewdog/action-setup](https://www.cisa.gov/news-events/alerts/2025/03/18/supply-chain-compromise-third-party-tj-actionschanged-files-cve-2025-30066-and-reviewdogaction) | Government advisory | F |
| S96 | [CodeRabbit: state of AI vs human code generation](https://www.coderabbit.ai/blog/state-of-ai-vs-human-code-generation-report). A vendor report on a small sample | Industry report | F |
| S97 | [Simon Willison: your job is to deliver code you have proven to work](https://simonwillison.net/2025/Dec/18/code-proven-to-work/) | Practitioner blog | F |
| S98 | [arXiv 2601.00477: security in the age of AI teammates](https://arxiv.org/abs/2601.00477) (revised 2026-09-03) | Academic | F |
| S99 | [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/). The page links a PDF and holds no risk text. The names come from secondary summaries | Standard | 2nd |
| S100 | [OpenLeash: a `git filter-repo` production outage](https://openleash.com/blog/claude-code-git-filter-repo-mining-pool-outage). It cites an Anthropic GitHub issue and says no complete vendor root cause is public | Practitioner blog | 2nd |
| S101 | [git-notes](https://git-scm.com/docs/git-notes) | Tool doc | F |
| S102 | [git-commit](https://git-scm.com/docs/git-commit) | Tool doc | F |
| S103 | [git-cherry-pick](https://git-scm.com/docs/git-cherry-pick) | Tool doc | F |
| S104 | [git-stash](https://git-scm.com/docs/git-stash) | Tool doc | F |
| S105 | [git-status](https://git-scm.com/docs/git-status) | Tool doc | F |
| S106 | [git-blame](https://git-scm.com/docs/git-blame) | Tool doc | F |
| S107 | [gitattributes](https://git-scm.com/docs/gitattributes) | Tool doc | F |
| S108 | [Semantic Versioning 2.0.0](https://semver.org/) | Specification | F |
| S109 | [DORA metrics guide](https://dora.dev/guides/dora-metrics/) | Research program | F |
| S110 | [git-fsck](https://git-scm.com/docs/git-fsck) | Tool doc | F |
| S111 | [githooks](https://git-scm.com/docs/githooks) | Tool doc | F |
| S112 | [git-interpret-trailers](https://git-scm.com/docs/git-interpret-trailers) | Tool doc | F |
| S113 | [GitHub: about code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) | Vendor doc | F |
| S114 | [LLVM AI tool use policy](https://llvm.org/docs/AIToolPolicy.html), re-fetched | Project policy | F |
| S115 | [Google engineering practices: speed of code reviews](https://google.github.io/eng-practices/review/reviewer/speed.html) | Practice guide | F |
| S116 | [Google engineering practices: CL descriptions](https://google.github.io/eng-practices/review/developer/cl-descriptions.html) | Practice guide | F |
| S117 | [Linux kernel: submitting-patches.rst](https://github.com/torvalds/linux/blob/master/Documentation/process/submitting-patches.rst), grepped | Project policy | R |
| S118 | [GitHub: configuring commit squashing](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/configuring-commit-squashing-for-pull-requests) | Vendor doc | F |
| S119 | [GitHub blog: securing the git push pipeline, CVE-2026-3854](https://github.blog/security/securing-the-git-push-pipeline-responding-to-a-critical-remote-code-execution-vulnerability/) | Vendor advisory | F |
| S120 | [GitHub blog: Git security vulnerabilities, 2024-05-14 (CVE-2024-32002 and others)](https://github.blog/open-source/git/securing-git-addressing-5-new-vulnerabilities/) | Vendor advisory | F |
| S121 | [Jujutsu: operation log](https://docs.jj-vcs.dev/latest/operation-log/) | Tool doc | F |
| S122 | [GitHub: about stacked pull requests](https://docs.github.com/en/pull-requests/get-started/about-stacked-prs) (public preview, changelog 2026-07-30) | Vendor doc | F |
| S123 | Git configuration documents, [raw files](https://github.com/git/git/tree/master/Documentation/config): `transfer`, `merge`, `pull`, `rebase`, `push`, `help` | Tool doc | R |
| T1 | Squash and trailers test, 2026-09-25, Git 2.55.0 | Own test | T |
| T2 | [`tests/verify-git-commands.sh`](./tests/verify-git-commands.sh), 69 checks, 2026-09-25, Git 2.55.0 | Own test | T |
