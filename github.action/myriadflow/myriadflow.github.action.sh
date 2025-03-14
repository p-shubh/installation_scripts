#!/bin/bash

# Set variables
PRIVATE_TOKEN="Z2hwX0RHb0syNWhMakdia2d2NmhpdXU3Y1Z5bXpCYUtNMzB4T2toTA==" 
GITHUB_REPO="MyriadFlow/gateway_v2"  # GitHub repository in "owner/repo" format
WORKFLOW_NAME="deploy-dev.yml"  # Workflow file name
BRANCH="main"  # Branch to trigger the workflow on

GITHUB_TOKEN=$(echo "$PRIVATE_TOKEN" | base64 --decode)

# Construct the API endpoint
API_ENDPOINT="https://api.github.com/repos/$GITHUB_REPO/actions/workflows/$WORKFLOW_NAME/dispatches"

# Create the request body
REQUEST_BODY='{"ref":"'${BRANCH}'"}'

# Send the POST request to trigger the workflow
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY" \
  "$API_ENDPOINT"