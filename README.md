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

#### Maintenance rule for `deps.forbidden`

Packages confirmed compromised in supply-chain incidents are appended to `deps.forbidden.names` in `monban.yml`. The maintenance flow is written down explicitly so agents can drive it without human prompting.

- **Review cadence**: revisit the list every six months. Trigger an out-of-band update immediately when a major supply-chain incident lands (e.g. a large-scale npm registry compromise)
- **How to add**: go through a PR; record the incident summary and reference URLs (advisory / primary report) in the `message` field
- **Never remove entries**: known-bad packages stay blocked forever, so they cannot sneak back in if they reappear later
- **Decision owner**: okite maintainers approve via PR review. If a child repo needs an individual exception, do not silently override `severity` downstream — first propose the addition to okite

### 2. Claude Code plugin — `okite`

`plugins/okite/` hosts the Claude Code plugin itself. It distributes skills and hooks.

#### Skills

A set of skills for designing and operating agent harnesses around the four axes of **harness engineering** (context / behavior / feedback / operation).

- **thinking** — A general-purpose skill that deepens planning / design through three rounds (investigate → consolidate → refine)
- **documentation** — Naming conventions, language selectors, and sync rules for maintaining bilingual (English / Japanese) READMEs and docs
- **implementation** — A 9-step implementation process: write the plan to a temporary doc, then drive architecture → static-check rule update → coding → tests → static-check + test run → reconcile against the plan → delete the doc → open a PR. Each step ends with a lightweight same-agent self-review (five lenses); critical steps (architecture finalized / large implementation milestone / pre-PR) require an additional independent review delegated to a sub-agent via the evaluator skill
- **improvement** — A meta-skill that revises `SKILL.md` itself. Triggers on user feedback after a skill ran, mid-run failure / interruption, post-skill self-reflection, or explicit request; targets both the plugin's skills and a repo-local `.claude/skills/`; edits, commits, and opens a PR with the trigger recorded
- **direction** — The product-direction skill for an agent harness. Filters new-skill / new-rule / new-hook proposals through the four harness-engineering axes (context / behavior / feedback / operation), centralization fit, and whether existing assets already cover the need
- **progress-log** — Cross-session progress file convention for long-running tasks. Externalizes goal, acceptance criteria, phases, session history, and "next action" into `.claude/progress/<task-slug>.md` so a new session can resume by reading it
- **evaluator** — Generator-Evaluator separation: spin up a sub-agent to critique your own output from independent lenses. Plugged into implementation as the mandatory second-layer self-review at critical steps
- **observability** — A self-serve observability skill for agents to look up their own past PRs, CI logs, monitoring data, automation-tool run history, and progress files before making decisions

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
