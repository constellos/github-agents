# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Rebranded from "Claude Code CI" to "Constellos" in review comment footer
- Updated action name from "Claude Code Review Actions" to "Constellos Review Actions"
- Updated README with clearer documentation about review-comment action requirement
- Added inline comments to workflow examples clarifying two-step pattern (reviewer + comment)
- **Comment format overhaul**: Simplified and cleaner comment layout
  - Removed review type emojis (📝, 🔍, etc.) from agent summary lines
  - Changed format from "✅ 📝 Requirements — ✅ 3 Passed" to "Requirements: ✅ 3 passed • ⚠️ 0 skipped"
  - Replaced "📋 Reviews" title with "Updates on your PR checks from AI reviewers."
  - Removed aggregate agent summary line ("**N Agents**: ...")
  - Changed separator from "/" to "•" and lowercase status text
- Added `skipped` output to requirements-reviewer for workflow orchestration
- Added GitHub App documentation for custom bot identity

### Fixed
- Added troubleshooting section explaining why beautiful table format might not appear
- Clarified that review-comment action must be called explicitly to see detailed checks table
- Added warning in Quick Start section about root action not automatically posting comments
- All-skipped reviews now show ⚠️ status instead of ✅

## [1.0.0] - 2026-01-05

### Added
- Initial marketplace release
- 8 composite actions for comprehensive PR reviews:
  - `requirements-reviewer` - AI-powered review against issue requirements
  - `code-quality-reviewer` - Code quality analysis (DRY, YAGNI, modularity)
  - `context-reviewer` - Validation against CLAUDE.md context files
  - `visual-reviewer` - Visual design & accessibility review with screenshot analysis
  - `ux-reviewer` - UX review for interactivity and console errors
  - `review-comment` - Consolidated PR comment management
  - `changed-files` - Smart file change detection
  - `capture-routes` - Route discovery and screenshot capture from Playwright
- Root-level `action.yml` dispatcher for simplified usage
- Comprehensive documentation in README.md
- GitHub Marketplace branding for all actions
- Custom review prompt support via `.claude/agents/reviewers/` directory
- Visual regression detection using SHA256 hashes
- Automatic console error extraction from E2E results

### Fixed
- Use `.claude/review-context/` instead of `/tmp/` to avoid sandboxing issues
- Proper heredoc syntax in all shell scripts
- Always output results to prevent workflow stalling
- Graceful handling of missing files (no screenshots, no CLAUDE.md, etc.)

### Changed
- Moved from inline workflow logic to modular composite actions
- Enhanced descriptions for marketplace visibility
- Improved error handling with fail-safe defaults

### Security
- All file operations use project-local directories (`.claude/`)
- No external network calls except to GitHub API
- Secrets properly scoped to required actions only

---

[1.0.0]: https://github.com/constellos/claude-code-actions/releases/tag/v1.0.0
