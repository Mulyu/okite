# okite

> [日本語](./README.ja.md) | **English**

A central repository for shared Claude Code / monban assets across `mulyu` repositories. "Okite" (掟) means "common rules" in Japanese.

## What it ships

### 1. monban security baseline — `monban.yml`

A shared configuration that downstream repos pull in via [monban](https://github.com/Mulyu/monban)'s `extends` mechanism. It covers secret / conflict / invisible / injection detection, GitHub Actions hardening, npm supply-chain checks, MCP config inspection, and detection of files that should have been ignored by `.gitignore`.

Child repos inherit it from their own `monban.yml`:

```yaml
extends:
  - type: github
    repo: Mulyu/okite
    ref: main          # use a commit hash or tag for stable operation
    path: monban.yml

# Project-specific rules go below
```

Merge semantics:

- Arrays are concatenated (child rules are appended to parent rules)
- Scalars favour the child
- Transitive resolution is not performed (further `extends` inside okite does not chain)

### 2. Claude Code plugin — `okite`

`plugins/okite/` hosts the Claude Code plugin itself. It distributes skills and hooks.

#### Skills

- **thinking** — A general-purpose skill that deepens planning / design through three rounds (investigate → consolidate → refine)
- **documentation** — Naming conventions, language selectors, and sync rules for maintaining bilingual (English / Japanese) READMEs and docs
- **implementation** — A 9-step implementation process: write the plan to a temporary doc, then drive architecture → `monban.yml` update → coding → tests → `monban all` → reconcile against the plan → delete the doc → open a PR. Each step ends with a self-review pass against five lenses (plan-fit, scope, overengineering, reuse, safety)
- **improvement** — A meta-skill that revises `SKILL.md` itself. Triggers on user feedback after a skill ran, mid-run failure / interruption, post-skill self-reflection, or explicit request; targets both okite plugin skills and a repo-local `.claude/skills/`; edits, commits, and opens a PR with the trigger recorded

#### Hooks

- **session-start** — Sets up Node project dependencies by inspecting `.nvmrc` and `package.json` (web environments only)
- **guard-bash** — Blocks force pushes to main/master, `--no-verify`, and `git config` mutations

Project-specific bans (e.g. forbidding particular commands) should be added as separate hooks in each repository.

## Usage

### Register the marketplace

```
/plugin marketplace add Mulyu/okite
/plugin install okite@mulyu-okite
```

Or, in each repository's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "mulyu-okite": {
      "source": {
        "source": "github",
        "repo": "Mulyu/okite"
      }
    }
  },
  "enabledPlugins": {
    "okite@mulyu-okite": true
  }
}
```

## Versioning

- `ref: main` always fetches the latest version (mutable, refetched every time)
- For stability, pin to a commit hash or tag (persistent cache)
- Cut a tag whenever a breaking change ships

## License

MIT
