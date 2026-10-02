# Agent Git guidelines

Git guidelines for teams where AI coding agents and humans work in the same repositories. Vendor-neutral rules, a practice playbook that names products, and the research behind every rule.

**Version:** 3, accepted 2026-10-02 (v2 accepted 2026-10-01). Version 3 adds work items and multi-agent coordination (section 14).

| File | What it is |
|---|---|
| [`agent-git-guidelines.md`](./agent-git-guidelines.md) | The policy. Section 0 is the one-page summary. Rules use RFC 2119 keywords |
| [`agent-git-playbook.md`](./agent-git-playbook.md) | How to apply it: commit and PR templates, reviewer checklist, client configuration, hooks, host settings, repository sign-off checklist |
| [`agent-git-guidelines-research.md`](./agent-git-guidelines-research.md) | Sources (S1 to S123) and the rule-to-source map |
| [`examples/auto-commit.sh`](./examples/auto-commit.sh) | Reference auto-commit hook for solo repositories (rule O3) |
| [`tests/verify-git-commands.sh`](./tests/verify-git-commands.sh) | 78 checks of the Git behaviour the rules rely on. Run it after a Git upgrade |

## Using it in a repository

Link the policy from the repository's contribution guide or agent instruction file, name the tracker for work items (rule K1), and record the rules that do not apply there with a reason. The guideline allows a SHOULD to be skipped only with a recorded reason. For example:

```markdown
## Git policy
This repository follows the [agent Git guidelines](https://github.com/jawadbokhari/agent-git-guidelines/blob/main/agent-git-guidelines.md) v2.
Exceptions: <rule>: <reason>.
```

## Review

Reviewed every six months and after incidents (rule M3). Contribution policies, host features and tool defaults change often, so rules that depend on them are the first to go stale. Issues and corrections are welcome.

## Licence

Documents: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Scripts in `examples/` and `tests/`: MIT, see [`LICENSE`](./LICENSE).
