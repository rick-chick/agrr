# Layer rules (L2 — index)

**Status:** canonical layer-boundary index. **L1 codemap:** [ARCHITECTURE.md](../../ARCHITECTURE.md).

Production runtime: `crates/agrr-server` (Axum) + `crates/agrr-domain` + `crates/agrr-adapters-*`. Frontend: `frontend/src/app/` (`components → usecase → domain`; HTTP in the adapters layer).

Detailed prohibited patterns are enforced by `scripts/run-architecture-guard.sh` and related tests — consult those for mechanical gate coverage.

## Layer rules summary (R0–R10)

| Rule | Summary |
| ---- | ------- |
| **R0** | Policies decide auth/validation; Interactors orchestrate; Gateways never authorize |
| **R1** | Domain is framework-free (`agrr-domain` — no HTTP, ORM, or hidden globals) |
| **R2** | Constructor injection only; no service locators |
| **R3** | Gateways = narrow persistence/I/O; no presenter-shaped blobs |
| **R4** | One user-facing use case = one top-level interactor; HTML/API share it |
| **R5** | Outcomes via output port `on_success` / `on_failure`; no rescue-as-control-flow |
| **R6** | Presenters shape HTTP only; no data loading or side effects |
| **R7** | Thin HTTP edge: map params → input DTO, wire deps, `interactor.call` |
| **R8** | Refactors must fix dependency direction, not relocate smells |
| **R9** | Contract-first: ports/DTOs + observable tests |
| **R10** | Safe implementation order: port contract → interactor → gateway → presenter → handler |

## Vertical slice

One JSON action → one interactor call + one output port (presenter). Sub-steps use **input ports** injected at the edge in `crates/agrr-server/src/composition.rs`.

## Backend layout

| Layer | Path |
| ----- | ---- |
| Domain interactors, policies, gateway traits | `crates/agrr-domain/src/<context>/` |
| HTTP handlers, composition wiring | `crates/agrr-server/src/` |
| Gateway adapters, presenters | `crates/agrr-adapters-*/` |

Each bounded context under `crates/agrr-domain/src/` typically has: `entities/`, `dtos/`, `gateways/` (traits), `interactors/`, `policies/`, `ports/`, `mappers/`.

## Frontend layout

| Layer | Path |
| ----- | ---- |
| Types and pure rules | `frontend/src/app/domain/` |
| Use cases, gateway tokens, ports | `frontend/src/app/usecase/` |
| HTTP implementations, DTO → view state | adapters layer under `frontend/src/app/` |
| Routes, templates | `frontend/src/app/components/` |

Dependency direction: `components → usecase → domain`; `adapters → gateway tokens`.

## What we require (high level)

- **Policies** (`crates/agrr-domain/src/<context>/policies/`) own authorization and validation decisions.
- **Interactors** (`crates/agrr-domain/src/<context>/interactors/`) orchestrate one use case; call gateways and output ports only.
- **Gateway traits** (`crates/agrr-domain/src/<context>/gateways/`) define narrow persistence/I/O contracts.
- **Presenters** (in `crates/agrr-adapters-*`) implement output ports; shape HTTP responses only.
- **Handlers** (`crates/agrr-server/src/`) are thin: request mapper → input DTO → wire deps → `interactor.call`.

## Prohibited patterns (index)

Full ❌ list (rules 1–39) is enforced mechanically — see `scripts/run-architecture-guard.sh`. Common violations:

- Service locators or hidden globals in domain
- Gateway authorization or presenter-shaped gateway returns
- Presenter data loading or side effects
- Rescue-as-control-flow instead of output port callbacks
- Skipping port/DTO contracts when adding behavior

## Related docs

- [ARCHITECTURE.md](../../ARCHITECTURE.md) — L1 codemap and system overview
- Migration-era detail: docs/migration/ (historical; not normative for new code)
