# CLAUDE.md

Agent entry — **routing only**. Details are linked; do not duplicate L2 rules here.

## Project

AGRR: **Angular 21 SPA** + **agrr-server** (Rust API/WS/OAuth on Cloud Run) + SQLite (Litestream → GCS). Optimization/weather via **agrr** Python binary (`lib/core/agrr`). Rails shell is **dev/local only** (SPA fallback, static pages)—not production API.

## Norm priority

1. [`ARCHITECTURE.md`](ARCHITECTURE.md) — L1 codemap, R0–R9 summary
2. [`docs/architecture/LAYER-RULES.md`](docs/architecture/LAYER-RULES.md) — L2 What we require / prohibited patterns (gate: 1–39)
3. Observable tests (`run-rust-contract-tests.sh`, frontend/cargo runners)
4. [`.cursor/rules/*.mdc`](.cursor/rules/) — alwaysApply / contextual rules

Touching `crates/agrr-domain`, gateways, or composition: re-read LAYER-RULES for the affected layer.

## Always-apply rules

@.cursor/rules/git-operational-constraints.mdc
@.cursor/rules/tdd-on-edit.mdc
@.cursor/rules/docker-dev-agrr-server-rebuild.mdc
@.cursor/rules/test-common-entry.mdc

## Contextual rules

@.cursor/rules/agent-conventions.mdc
@.cursor/rules/automation-philosophy-priority.mdc
@.cursor/rules/ca-violation-fix-architecture-gate.mdc
@.cursor/rules/dont-finish-task-while-process-is-running.mdc
@.cursor/rules/evidence-before-design-and-implementation.mdc
@.cursor/rules/feature-orchestrator.mdc
@.cursor/rules/gcp-available.mdc
@.cursor/rules/i18n-completion-orchestrator.mdc
@.cursor/rules/implementation-consistency-with-existing.mdc
@.cursor/rules/no-convenience-tech-debt.mdc
@.cursor/rules/project-necessary-code-only.mdc
@.cursor/rules/rails-clean-architecture.mdc
@.cursor/rules/rails-testing-workflow.mdc
@.cursor/rules/skill-authoring.mdc
@.cursor/rules/test-quality-core.mdc
@.cursor/rules/test-quality-checklist.mdc
@.cursor/rules/user-request-project-alignment.mdc
@.cursor/rules/use-skills-on-edit.mdc

## Architecture (minimal)

**Production slice:** Axum handler → input DTO → `crates/agrr-domain` interactor → gateway traits → presenter (output port) → JSON.

- Domain: `crates/agrr-domain/src/<context>/` (interactors, policies, gateway traits, ports)
- Edge: `crates/agrr-server/src/` (routes, `composition.rs`, presenter wiring)
- Adapters: `crates/agrr-adapters-*`
- Frontend: `frontend/src/app/` — `components → usecase → domain`, HTTP in `adapters/`

**Common violations:** service locators in domain, gateway authorization, presenter data loading, rescue-as-control-flow. See LAYER-RULES.

## Commands

| Task | Command |
| ---- | ------- |
| Docker dev | [`.cursor/skills/dev-docker/SKILL.md`](.cursor/skills/dev-docker/SKILL.md) — `up.sh`, `rebuild-restart.sh` after `crates/*` changes |
| R4 contracts | `scripts/run-rust-contract-tests.sh` |
| Domain tests | `.cursor/skills/test-common/scripts/run-test-rust-domain.sh` |
| Frontend tests | `.cursor/skills/test-common/scripts/run-test-frontend.sh` |

構造クエリ: `tools/agrr-repo-mcp`（MCP `list_bounded_contexts` 等）

**Tests:** always via [test-common](.cursor/skills/test-common/SKILL.md). Individual file GREEN → full suite → slow-test check ([test-slow-detection](.cursor/skills/test-slow-detection/SKILL.md)).

**Shell:** use [process-monitor](.cursor/skills/process-monitor/SKILL.md) before reporting success on long commands.

## Workflows

CA violation fix / new features: [clean-architecture-violation-fix-workflow](.cursor/skills/clean-architecture-violation-fix-workflow/SKILL.md) sections 0–6. TDD: [tdd-on-edit](.cursor/skills/tdd-on-edit/SKILL.md).

**Git:** no `checkout` / `switch` / `reset` / `restore` without explicit user permission ([git-operational-constraints](.cursor/rules/git-operational-constraints.mdc)).

## Docs index

- [README.md](README.md) — quickstart
- [docs/README.md](docs/README.md) — supplementary index
- [docs/migration/app-rust-stack/](docs/migration/app-rust-stack/) — P6–P8 migration (historical detail in [archive](docs/migration/archive/))
