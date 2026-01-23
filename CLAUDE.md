# Constellos Actions

AI-powered code review for GitHub PRs using Claude.

## What This Is

This repo provides:
1. **Default agent prompts** for AI code reviews (can be overridden per-repo)
2. **GitHub Actions** for repos that want workflow-based approach
3. **Review comment formatting** for posting results to PRs

## Architecture

```
PR Opened → Webhook → Constellos Backend → Agent Execution → PR Comment
```

1. Constellos GitHub App installed on target repo
2. PR opened → webhook fires to Constellos backend (`constellos/constellos`)
3. Backend checks `.constellos/config.json` for enabled agents
4. For each enabled agent:
   - Reads prompt from `.constellos/agents/{agent}.md`
   - Runs `claude-code-base-action` with user's OAuth token
   - Posts review results to PR

## Agent Format

Agents are markdown files in `.constellos/agents/`. Same format as Claude Code agent prompts:

```markdown
# Agent Name

You are a [role] doing [task].

## Checks to Perform
1. Check name - what to look for

## Input Files
- Changed files: `.claude/review-context/changed.txt`

## Output Format
```json
{
  "checks": [
    {"name": "...", "status": "passed|failed|skipped", ...}
  ]
}
```
```

## Adding New Agents

1. Create `.constellos/agents/{agent-name}.md` with prompt
2. Add to `.constellos/config.json`:
   ```json
   {
     "agents": {
       "agent-name": {
         "enabled": true,
         "prompt": ".constellos/agents/agent-name.md"
       }
     }
   }
   ```
3. Create action in `.github/actions/{agent-name}-reviewer/action.yml`

## Key Files

```
.constellos/
├── config.json              # Agent configuration
└── agents/
    ├── requirements.md      # Requirements reviewer prompt
    └── code-quality.md      # Code quality reviewer prompt

.github/actions/
├── requirements-reviewer/   # Requirements review action
├── code-quality-reviewer/   # Code quality review action
└── review-comment/          # Posts formatted comments to PR

action.yml                   # Root action (routes to specific reviewer)
src/index.ts                 # TypeScript source
```

## Available Agents

| Agent | Purpose |
|-------|---------|
| `requirements` | Verifies PR implements issue requirements |
| `code-quality` | Checks DRY, YAGNI, modularity, maintainability |

## Setup Guide

### Manual Setup

If the Constellos GitHub App didn't automatically create the workflow file, or if you prefer manual control:

1. **Copy the workflow template** from [`templates/constellos-review.yml`](templates/constellos-review.yml) to your repo at `.github/workflows/constellos-review.yml`

2. **Add the required secret**: Add `CLAUDE_CODE_OAUTH_TOKEN` to your repository secrets (Settings > Secrets and variables > Actions)

3. **Optionally customize agents**: Create `.constellos/config.json` to enable/disable specific agents

### Automatic Setup

When you install the Constellos GitHub App on your repo, it should automatically:
1. Create the workflow file (`.github/workflows/constellos.yml`)
2. Start reviewing PRs after CI passes

Just install the app and add `CLAUDE_CODE_OAUTH_TOKEN` to your repo secrets.

**Note**: If reviews aren't appearing on your PRs, verify the workflow file was created. If not, use Manual Setup above.

### Configure Agents (Optional)

Create `.constellos/config.json` to enable/disable agents:

```json
{
  "agents": {
    "requirements": {
      "enabled": true,
      "prompt": ".constellos/agents/requirements.md"
    },
    "code-quality": {
      "enabled": true,
      "prompt": ".constellos/agents/code-quality.md"
    }
  }
}
```

If no config file exists, both `requirements` and `code-quality` agents are enabled by default.

### Issue Linking Conventions

The requirements reviewer links PRs to issues using these methods (in priority order):

1. **Branch name** - Use format `{issue-number}-{description}`
   - Example: `123-add-login-feature` → links to issue #123

2. **PR body keywords** - Include closing keywords in your PR description
   - `Closes #123`
   - `Fixes #123`
   - `Resolves #123`

If no issue is linked, the requirements review is skipped (code-quality still runs).

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
