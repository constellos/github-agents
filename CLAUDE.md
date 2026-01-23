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
