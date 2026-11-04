#!/usr/bin/env bash
# Fail unless the latest PR Body check run on the PR head is green.
#
# Runs inside a check that branch protection already requires (agent-swarm's
# "Merge Gate", agent-fs's "ci"), so a red PR body blocks the merge without a
# ruleset change. rerun-gate.sh re-runs that job when the body is edited.
#
# Env: GH_TOKEN (checks: read), REPO, HEAD_SHA, EVENT_NAME,
#      CHECK_NAME (default "PR Body"; also matches "<caller job> / PR Body"),
#      TIMEOUT_SECONDS (default 600).
set -euo pipefail

CHECK_NAME="${CHECK_NAME:-PR Body}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"

if [ "$EVENT_NAME" != "pull_request" ]; then
  echo "Event $EVENT_NAME: the PR body was checked before this ref existed. Skipping."
  exit 0
fi

deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))
while :; do
  latest=$(gh api --paginate "repos/$REPO/commits/$HEAD_SHA/check-runs?per_page=100" \
    | jq -s -c --arg n "$CHECK_NAME" \
      '[.[].check_runs[] | select(.name == $n or (.name | endswith(" / " + $n)))] | max_by(.id) // empty | {status, conclusion, html_url}')
  if [ -n "$latest" ] && [ "$(jq -r .status <<<"$latest")" = "completed" ]; then
    conclusion=$(jq -r .conclusion <<<"$latest")
    url=$(jq -r .html_url <<<"$latest")
    case "$conclusion" in
      success | skipped | neutral)
        echo "$CHECK_NAME is $conclusion: $url"
        exit 0
        ;;
      *)
        echo "::error title=$CHECK_NAME::$CHECK_NAME is $conclusion ($url). Fill the PR template in the description. Editing the description re-runs this check; no push needed."
        exit 1
        ;;
    esac
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "::error title=$CHECK_NAME::No completed $CHECK_NAME check on $HEAD_SHA after ${TIMEOUT_SECONDS}s."
    exit 1
  fi
  echo "Waiting for $CHECK_NAME on $HEAD_SHA (${latest:-not started})..."
  sleep 10
done
