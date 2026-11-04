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

The template is the rule set. `**Label:**` lines before the first heading are
required. Every `## ` section is required unless its heading carries a marker:
`optional`, `fix`, `ui`, `bot`, `outline` or `pick one`. The comment at the top
of `pull_request_template.md` explains each one. Bodies by `desplega-bot` also
get the leak check: no Slack ids, chat quotes, or task, dashboard, agent-fs or
Slack links outside `## Swarm provenance`.

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
