# Constellos GitHub Agents

AI-powered code review for GitHub PRs using Claude, delivered via the Constellos cloud.

## What This Is

This repo (`constellos/github-agents`) provides:
1. **Default agent prompts** for reviews (can be overridden per-repo)
2. **Agent configuration** to enable/disable specific reviewers
3. **CI pipeline templates** for common deployment targets

Reviews are handled automatically by the Constellos cloud — no GitHub Actions workflow or secrets are required.

## Architecture

```
PR Opened → GitHub Webhook (github.constellos.ai) → Cloud Reviewer (mcp.constellos.ai) → PR Comment
```

1. A PR is opened or updated, triggering the GitHub webhook
2. The cloud reviewer fetches the PR diff and reads `.constellos/config.json` for enabled agents
3. For each enabled agent, it loads the prompt from `.constellos/agents/{agent}.md` (repo-level override or default)
4. Review results are posted back to the PR as comments

## Quick Start

### 1. Install the Constellos GitHub App

Install the [Constellos app](https://github.com/apps/constellos) on your repository. Reviews start automatically on new PRs — no workflow files or secrets needed.

### 2. (Optional) Configure Agents

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
```

## Issue Linking

The requirements reviewer links PRs to issues using these methods (in priority order):

1. **Branch name** - Use format `{issue-number}-{description}`
   - Example: `123-add-login-feature` → links to issue #123

2. **PR body keywords** - Include closing keywords in your PR description
   - `Closes #123`
   - `Fixes #123`
   - `Resolves #123`

If no issue is linked, the requirements review is skipped (other agents still run).

## Key Files

```
.constellos/
├── config.json                 # Agent configuration
└── agents/
    ├── requirements.md         # Requirements reviewer prompt
    └── code-quality.md         # Code quality reviewer prompt

.github/
├── workflows/
│   └── ci-pipeline.yml         # CI pipeline for this repo
├── ci-config.yml               # CI configuration
└── templates/
    ├── README.md               # Documents CI config templates
    ├── template-vercel.yml     # Vercel deployment CI template
    ├── template-cloudflare.yml # Cloudflare deployment CI template
    ├── template-supabase-vercel.yml
    └── template-non-deployable.yml
```
