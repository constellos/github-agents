#!/bin/bash
# Link current branch to GitHub issue using native "Development" section
#
# Usage: link-branch-to-issue.sh <issue-number>
#
# This creates a proper GitHub link that shows in the issue's "Development"
# sidebar, avoiding namespace collisions between issues and PRs.
#
# Note: createLinkedBranch only works for NEW branches. For existing branches,
# we fall back to storing the mapping in .claude/logs/branch-issues.json

set -euo pipefail

ISSUE_NUMBER="${1:-}"
if [ -z "$ISSUE_NUMBER" ]; then
  echo "No issue number provided, skipping link"
  exit 0
fi

# Get repo info from git remote
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [ -z "$REMOTE_URL" ]; then
  echo "No git remote found"
  exit 0
fi

# Extract owner/repo from remote URL
# Handles: git@github.com:owner/repo.git, https://github.com/owner/repo.git
REPO_FULL=$(echo "$REMOTE_URL" | sed -E 's#^(git@github\.com:|https://github\.com/)##' | sed 's/\.git$//')
REPO_OWNER=$(echo "$REPO_FULL" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO_FULL" | cut -d'/' -f2)

if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
  echo "Could not parse repo from remote: $REMOTE_URL"
  exit 0
fi

BRANCH=$(git branch --show-current)
if [ -z "$BRANCH" ]; then
  echo "Not on a branch"
  exit 0
fi

echo "Linking branch '$BRANCH' to issue #$ISSUE_NUMBER in $REPO_OWNER/$REPO_NAME"

# Get issue node ID (required for GraphQL mutation)
ISSUE_ID=$(gh api graphql -f query="
  query {
    repository(owner: \"$REPO_OWNER\", name: \"$REPO_NAME\") {
      issue(number: $ISSUE_NUMBER) { id }
    }
  }" --jq '.data.repository.issue.id' 2>/dev/null || echo "")

if [ -z "$ISSUE_ID" ] || [ "$ISSUE_ID" = "null" ]; then
  echo "Could not find issue #$ISSUE_NUMBER"
  exit 0
fi

# Check if branch already exists on remote
BRANCH_EXISTS=$(git ls-remote --heads origin "$BRANCH" 2>/dev/null | wc -l)

if [ "$BRANCH_EXISTS" -gt 0 ]; then
  # Branch exists - createLinkedBranch won't work
  # Check if it's already linked
  EXISTING_LINK=$(gh api graphql -f query="
    query {
      repository(owner: \"$REPO_OWNER\", name: \"$REPO_NAME\") {
        issue(number: $ISSUE_NUMBER) {
          linkedBranches(first: 10) {
            nodes { ref { name } }
          }
        }
      }
    }" --jq ".data.repository.issue.linkedBranches.nodes[].ref.name | select(. == \"$BRANCH\")" 2>/dev/null || echo "")

  if [ -n "$EXISTING_LINK" ]; then
    echo "Branch '$BRANCH' is already linked to issue #$ISSUE_NUMBER"
  else
    echo "Branch already exists on remote. GitHub's createLinkedBranch only works for new branches."
    echo "The link will be established when a PR is created with 'Closes #$ISSUE_NUMBER' in the body."
  fi
else
  # Branch doesn't exist on remote - try createLinkedBranch
  OID=$(git rev-parse HEAD)

  RESULT=$(gh api graphql -f query="
    mutation {
      createLinkedBranch(input: {
        issueId: \"$ISSUE_ID\",
        oid: \"$OID\",
        name: \"$BRANCH\"
      }) {
        linkedBranch {
          ref { name }
        }
      }
    }" 2>&1 || echo "FAILED")

  if echo "$RESULT" | grep -q "FAILED\|errors"; then
    echo "Could not create linked branch via GitHub API."
    echo "This may be because the branch needs to be pushed first."
    echo "The link will be established when a PR is created."
  else
    echo "Successfully linked branch '$BRANCH' to issue #$ISSUE_NUMBER"
  fi
fi

# Always update local tracking file as a fallback/cache
LOGS_DIR="$(git rev-parse --show-toplevel)/.claude/logs"
mkdir -p "$LOGS_DIR"
TRACKING_FILE="$LOGS_DIR/branch-issues.json"

if [ -f "$TRACKING_FILE" ]; then
  # Update existing file
  jq --arg branch "$BRANCH" \
     --argjson issue "$ISSUE_NUMBER" \
     --arg url "https://github.com/$REPO_OWNER/$REPO_NAME/issues/$ISSUE_NUMBER" \
     --arg now "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
     '.[$branch] = {issueNumber: $issue, issueUrl: $url, createdAt: $now, linkedViaHook: true}' \
     "$TRACKING_FILE" > "$TRACKING_FILE.tmp" && mv "$TRACKING_FILE.tmp" "$TRACKING_FILE"
else
  # Create new file
  jq -n --arg branch "$BRANCH" \
        --argjson issue "$ISSUE_NUMBER" \
        --arg url "https://github.com/$REPO_OWNER/$REPO_NAME/issues/$ISSUE_NUMBER" \
        --arg now "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
        '{($branch): {issueNumber: $issue, issueUrl: $url, createdAt: $now, linkedViaHook: true}}' \
        > "$TRACKING_FILE"
fi

echo "Updated local tracking in $TRACKING_FILE"
