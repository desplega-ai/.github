# PR Body check

Every desplega-ai PR fills its repo's PR template, or the org default
(`pull_request_template.md` at the root of this repo). This directory holds the
check that enforces it.

| Path | What it is |
|---|---|
| `.github/workflows/pr-body.yml` | Reusable workflow. Checks the live PR description against the template; the check is `pr-body / PR Body` in the caller. |
| `actions/require-pr-body` | Last step of a job that branch protection already requires. Fails while PR Body is red, so a bad description blocks the merge. |
| `actions/rerun-gate` (and the reusable workflow's `sync-gate` job) | Re-runs that required job after a description edit, so no push is needed. |
| `pr-body/scripts/check-pr-body.ts`, `pr-body/src/utils/pr-body-leaks.ts` | Byte-identical copies of the same files in desplega-ai/agent-swarm. |

## Rules

The template is the rule set. The checker holds no repo paths and no section
names: every rule comes from an HTML comment marker in the template.

| Marker | Where | Rule |
|---|---|---|
| (none) | `**Label:**` line before the first heading | required, with text |
| `one of: a \| b \| c` | lead line | the value is one of them, a reason in parentheses may follow |
| `max words: N`, `hard max words: N` | lead line | warns above the first, fails above the second |
| (none) | `## ` heading | the section is required, with text |
| `optional` | heading | the section may be deleted |
| `evidence` | heading | always required: a fence with content, a table with a data row, media with a source, `Before: ... After: ...`, or `No visible change: <reason>` |
| `outline` | heading | may be skipped when Risk is low and the diff is 50 lines or fewer |
| `bot` | heading | required when `desplega-bot` is the author. Present content is links only, each as `[label](url)` |
| `link: Task` | heading with `bot` | the bot must link that label |
| `fix`, `fix mentions: main` | heading | required for a `fix:` title, or the section must hold that word for a `fix:` title |
| `max rows: N`, `max bullets: N`, `max code lines: N` | heading | warning only |
| `pick one` | heading | exactly one checked `- [ ]` item |

Prose warns above 200 words and fails above 300. Code blocks, tables and
`<details>` do not count.

A template line `<!-- new rules fail from: YYYY-MM-DD -->` opens a window: until
that date the newer rules (evidence, the provenance link format, the fix
control, the length limits) only warn. Delete the line after the date.

Bodies by `desplega-bot` also get the leak check: no Slack ids, chat quotes, or
task, dashboard, agent-fs or Slack links outside `## Swarm provenance`.

Local check, from a clone of this repo:

```bash
cd pr-body && PR_TEMPLATE_PATH=../pull_request_template.md \
  bun scripts/check-pr-body.ts --title "<title>" --body-file <absolute path> --author <login>
```

Skipped: Dependabot PRs, `release:` titles, and PRs labeled `skip-pr-body-check`.

## Adopt it in a repo

1. Copy the caller block from the top of `.github/workflows/pr-body.yml` into
   the repo's `.github/workflows/pr-body.yml`. Pin both SHAs to the same commit.
2. Make it block merges. Either add `uses: desplega-ai/.github/actions/require-pr-body@<sha>`
   as the last step of an already-required job (with `permissions: checks: read`)
   and pass that job as `gate-workflow` / `gate-job`, or ask an org admin to add
   `pr-body / PR Body` to the branch ruleset's required checks.

## Update the checker

agent-swarm owns the code. After a change there, copy both files here
unchanged, then bump the pinned SHA in each caller.
