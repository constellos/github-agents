# Constellos GitHub Agents

AI-powered code review for GitHub PRs using Claude.

## What This Is

This repo (`constellos/github-agents`) provides:
1. **Reusable workflow** that external repos can call for AI code reviews
2. **Default agent prompts** for reviews (can be overridden per-repo)
3. **GitHub Actions** for running individual agents
4. **Review comment formatting** for posting results to PRs

## Architecture

```
PR Opened → Workflow Trigger → Reusable Workflow → Agent Execution → PR Comment
```

1. External repo creates minimal workflow calling `constellos/github-agents/.github/workflows/review.yml`
2. Workflow reads `.constellos/config.json` for enabled agents (defaults to all)
3. For each enabled agent:
   - Loads prompt from `.constellos/agents/{agent}.md` or uses default
   - Runs `claude-code-base-action` with provided OAuth token
   - Posts review results as PR comment

## Quick Start

### 1. Add Workflow to Your Repo

Create `.github/workflows/constellos-review.yml`:

```yaml
name: Constellos Review
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  review:
    uses: constellos/github-agents/.github/workflows/review.yml@main
    with:
      pr_number: ${{ github.event.number }}
      sha: ${{ github.event.pull_request.head.sha }}
      branch: ${{ github.head_ref }}
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

### 2. Add Secret

Add `CLAUDE_CODE_OAUTH_TOKEN` to your repository secrets (Settings > Secrets and variables > Actions).

### 3. (Optional) Configure Agents

Create `.constellos/config.json` to enable/disable specific agents:

```json
{
  "agents": {
    "requirements": { "enabled": true },
    "code-quality": { "enabled": true },
    "context": { "enabled": false }
  }
}
```

If no config file exists, `requirements` and `code-quality` agents run by default.

## Available Agents

| Agent | Purpose |
|-------|---------|
| `requirements` | Verifies PR implements linked issue requirements |
| `code-quality` | Checks DRY, YAGNI, modularity, maintainability |
| `context` | Reviews PR title, description, and change grouping |

## Custom Agent Prompts

Override default prompts by creating `.constellos/agents/{agent}.md` in your repo:

```markdown
# Requirements Review

You are reviewing PR changes against issue requirements.

## Checks to Perform
1. Completeness - all acceptance criteria addressed
2. Scope - changes within issue scope
3. Traceability - changes map to requirements

## Input Files
- Changed files: `.claude/review-context/changed.txt`
- Issue context: `.claude/review-context/issue.json`

## Output Format
```json
{
  "checks": [
    {"name": "...", "status": "passed|failed|skipped", "result": "...", "reasoning": "..."}
  ]
}
```
```

## Key Files

```
.github/
├── workflows/
│   ├── review.yml              # Reusable workflow (external repos call this)
│   └── constellos-review.yml   # Local workflow for this repo
└── actions/
    ├── requirements-reviewer/  # Requirements review action
    ├── code-quality-reviewer/  # Code quality review action
    ├── context-reviewer/       # Context review action
    ├── review-comment/         # Posts formatted comments to PR
    ├── create-check-run/       # Creates GitHub check runs
    └── shared/                 # Shared scripts

.constellos/
├── config.json                 # Agent configuration
└── agents/
    ├── requirements.md         # Requirements reviewer prompt
    └── code-quality.md         # Code quality reviewer prompt

action.yml                      # Root action (generic agent runner)
```

## Using the Root Action Directly

For more control, use the root action directly:

```yaml
- uses: constellos/github-agents@main
  with:
    agent: requirements
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    pr_number: ${{ github.event.number }}
    branch: ${{ github.head_ref }}
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

Supported agents: `requirements`, `code-quality`, `context`, or any custom agent with a prompt file.

## Issue Linking

The requirements reviewer links PRs to issues using these methods (in priority order):

1. **Branch name** - Use format `{issue-number}-{description}`
   - Example: `123-add-login-feature` → links to issue #123

2. **PR body keywords** - Include closing keywords in your PR description
   - `Closes #123`
   - `Fixes #123`
   - `Resolves #123`

If no issue is linked, the requirements review is skipped (other agents still run).

## Output Format

All agents output JSON with a `checks` array:

```json
{
  "checks": [
    {
      "name": "Check Name",
      "status": "passed|failed|skipped",
      "result": "Brief summary",
      "reasoning": "Why this status",
      "files": [
        {"path": "file.ts", "line": 42, "note": "Issue description"}
      ]
    }
  ],
  "message": "Optional overall message"
}
```
