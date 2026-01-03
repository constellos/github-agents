# CI Configuration Templates

This directory contains template CI configuration files for different types of repositories. These templates provide pre-configured setups that you can copy and customize for your project.

## Quick Start

1. Choose the appropriate template for your project type
2. Copy the template to your repository root as `.github/ci-config.yml`
3. Customize any settings as needed
4. Commit and push to enable the CI pipeline

```bash
# Example: Copy the Vercel template
cp .github/templates/template-vercel.yml .github/ci-config.yml
```

## Available Templates

### template-vercel.yml

**Best for:** Next.js applications deployed to Vercel

**Features:**
- Full basic CI (lint, typecheck, vitest)
- Playwright E2E tests against Vercel previews
- AI-powered code reviews with UI screenshot analysis
- Vercel deployment integration

**Use when:**
- Building a Next.js or React application
- Deploying frontend to Vercel
- Want AI to review UI changes visually

---

### template-supabase-vercel.yml

**Best for:** Full-stack apps with Supabase backend and Vercel frontend

**Features:**
- Everything in template-vercel.yml
- Supabase preview branches for PRs
- Database migration automation
- E2E tests with database access

**Use when:**
- Using Supabase for authentication, database, or storage
- Need isolated database environments for PR previews
- Running E2E tests that require database seeding

**Required secrets:**
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_ID` (or configured per-environment)

---

### template-cloudflare.yml

**Best for:** Applications deployed to Cloudflare Pages

**Features:**
- Full basic CI (lint, typecheck, vitest)
- Playwright E2E tests against Cloudflare previews
- AI-powered code reviews with UI screenshot analysis
- Cloudflare Pages deployment integration

**Use when:**
- Deploying to Cloudflare Pages
- Using Cloudflare Workers or D1
- Want edge-first performance

**Required secrets:**
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

---

### template-non-deployable.yml

**Best for:** Libraries, GitHub Actions, CLI tools, and packages

**Features:**
- Full basic CI (lint, typecheck, vitest)
- AI-powered code reviews (no UI review)
- No deployment or E2E testing

**Use when:**
- Building an NPM package or library
- Creating GitHub Actions
- Building CLI tools
- Working on monorepo shared packages
- Any project without a hosted deployment

---

## Configuration Reference

### Basic CI Options

```yaml
ci:
  basic:
    enabled: true       # Master toggle for basic CI
    lint: true          # ESLint checks
    typecheck: true     # TypeScript compilation
    vitest: true        # Unit/integration tests
```

### E2E Testing Options

```yaml
ci:
  e2e:
    enabled: true                   # Master toggle for E2E
    framework: playwright           # Testing framework
    wait_for_deployment: true       # Wait for preview before testing
```

### Review Options

```yaml
ci:
  reviews:
    enabled: true           # Master toggle for AI reviews
    requirements: true      # Check against REQUIREMENTS.md
    rules: true             # Enforce .claude/rules/
    project_memory: true    # Use CLAUDE.md context
    agents: true            # Multi-agent review
    skills: true            # Specialized skills
    playwright_ui: true     # Visual UI review
```

### Deployment Options

```yaml
ci:
  deployment:
    enabled: true
    vercel:
      enabled: true         # Vercel integration
    supabase:
      enabled: false        # Supabase integration
    cloudflare:
      enabled: false        # Cloudflare Pages integration
```

## Customization Tips

### Disabling Specific Checks

If your project doesn't use TypeScript:
```yaml
ci:
  basic:
    typecheck: false
```

### Adding Multiple Deployments

You can enable multiple deployment platforms if needed:
```yaml
ci:
  deployment:
    enabled: true
    vercel:
      enabled: true
    supabase:
      enabled: true
```

### Minimal Configuration

For a minimal setup with just linting:
```yaml
ci:
  basic:
    enabled: true
    lint: true
    typecheck: false
    vitest: false
  e2e:
    enabled: false
  reviews:
    enabled: false
  deployment:
    enabled: false
```

## Troubleshooting

### E2E tests timing out
- Increase the deployment wait timeout in your workflow
- Ensure `wait_for_deployment: true` is set

### Reviews not running
- Check that `reviews.enabled: true`
- Verify `ANTHROPIC_API_KEY` secret is configured

### Deployment not detected
- Ensure the correct platform is enabled
- Check that required secrets are configured
- Verify your deployment platform's GitHub integration is set up
