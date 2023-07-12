#!/bin/bash -eu

COMMITTED_BY=$(curl -s -H "Circle-Token: $CIRCLE_TOKEN" "https://circleci.com/api/v2/workflow/${CIRCLE_WORKFLOW_ID}" | jq -r .started_by)

COMMITTER=$(curl -s -H "Circle-Token: $CIRCLE_TOKEN" "https://circleci.com/api/v2/user/${COMMITTED_BY}")
COMMITTER_NAME=$(echo "$COMMITTER" | jq -r '"\(.name) (\(.login))"')

WORKFLOW_JOBS=$(curl -s -H "Circle-Token: $CIRCLE_TOKEN" "https://circleci.com/api/v2/workflow/${CIRCLE_WORKFLOW_ID}/job")
CURRENT_JOB_DEPENDENCIES=$(echo "$WORKFLOW_JOBS" | jq -cr ".items[] | select(.id == \"$CIRCLE_WORKFLOW_JOB_ID\") | .dependencies[]")
APPROVAL_JOBS=$(echo "$WORKFLOW_JOBS" | jq -cr '.items[] | select(.type == "approval")')

for JOB in $APPROVAL_JOBS
do
  JOB_ID=$(echo "$JOB" | jq -r .id)
  for DEPENDENCY_ID in $CURRENT_JOB_DEPENDENCIES
  do
    if [ "$DEPENDENCY_ID" = "$JOB_ID" ]; then
      APPROVED_BY=$(echo "$JOB" | jq -r .approved_by)
    fi
  done
done

if [ "$APPROVED_BY" = "" ]; then
  echo "Could not find linked approval job. Make sure you run this step in a job that depends on an approval job."
  exit 1
fi

APPROVER=$(curl -s -H "Circle-Token: $CIRCLE_TOKEN" "https://circleci.com/api/v2/user/${APPROVED_BY}")
APPROVER_NAME=$(echo "$APPROVER" | jq -r '"\(.name) (\(.login))"')
echo "Committer: $COMMITTER_NAME"
echo "Approver: $APPROVER_NAME"
echo
if [[ "$COMMITTER_NAME" == "null" || "$APPROVER_NAME" == "null" ]]; then
  echo "Could not verify identity of committer and/or approver!"
  exit 1
fi

if [ "$COMMITTER_NAME" != "$APPROVER_NAME" ]; then
  echo "Approval verified successfully!"
    exit 0
else
  echo "Approval verification failed.  Please ensure that deployments are approved by someone other than the committer."
    exit 1
fi
