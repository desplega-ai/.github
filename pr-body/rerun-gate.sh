#!/usr/bin/env bash
# After a PR description edit, re-run the required job that embeds the PR Body
# result (require-pr-body.sh), so its status follows the body without a push.
#
# Re-runs only when the result can flip: the gate job failed and the body now
# passes, or the gate job passed and the body now fails. A gate job that has not
# finished yet reads the live result on its own, so it is left alone.
#
# Env: GH_TOKEN (actions: write), REPO, HEAD_SHA, GATE_WORKFLOW (file name,
#      e.g. ci.yml), GATE_JOB (job name, e.g. ci), BODY_RESULT (the PR Body
#      job result: success, failure, skipped, cancelled),
#      WAIT_SECONDS (default 1800: how long to wait for the gate run to end).
set -euo pipefail

WAIT_SECONDS="${WAIT_SECONDS:-1800}"
case "$BODY_RESULT" in
  success | skipped) body_ok=true ;;
  failure) body_ok=false ;;
  *) echo "PR Body result is $BODY_RESULT. Nothing to sync."; exit 0 ;;
esac

run_id=$(gh api "repos/$REPO/actions/workflows/$GATE_WORKFLOW/runs?head_sha=$HEAD_SHA&event=pull_request&per_page=1" \
  --jq '.workflow_runs[0].id // empty')
if [ -z "$run_id" ]; then
  echo "No $GATE_WORKFLOW run on $HEAD_SHA yet. It will read the PR Body result when it runs."
  exit 0
fi

job() {
  gh api --paginate "repos/$REPO/actions/runs/$run_id/jobs?filter=latest&per_page=100" \
    | jq -s -c --arg n "$GATE_JOB" '[.[].jobs[] | select(.name == $n)] | max_by(.id) // empty | {id, status, conclusion}'
}

gate=$(job)
if [ -z "$gate" ]; then
  echo "::warning::No job named '$GATE_JOB' in run $run_id. Check the gate-job input."
  exit 0
fi
if [ "$(jq -r .status <<<"$gate")" != "completed" ]; then
  echo "$GATE_JOB has not finished in run $run_id. It reads the PR Body result itself."
  exit 0
fi

gate_ok=$([ "$(jq -r .conclusion <<<"$gate")" = "success" ] && echo true || echo false)
if [ "$gate_ok" = "$body_ok" ]; then
  echo "$GATE_JOB already agrees with the PR body (gate ok: $gate_ok). Nothing to re-run."
  exit 0
fi

# A job can be re-run only once its whole run has ended.
deadline=$(( $(date +%s) + WAIT_SECONDS ))
until [ "$(gh api "repos/$REPO/actions/runs/$run_id" --jq .status)" = "completed" ]; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "::warning::Run $run_id did not end within ${WAIT_SECONDS}s. Re-run '$GATE_JOB' by hand."
    exit 0
  fi
  echo "Waiting for run $run_id to end..."
  sleep 20
done

gh api -X POST "repos/$REPO/actions/jobs/$(jq -r .id <<<"$gate")/rerun" --silent
echo "Re-ran '$GATE_JOB' in run $run_id (gate ok: $gate_ok, body ok: $body_ok)."
