# ADR 0009: Gateway interface naming stays presentation-agnostic

- **Status**: Accepted
- **Date**: 2026-05-08

## Context

[`ARCHITECTURE.md`](../../ARCHITECTURE.md) requires gateways to remain **presentation-agnostic** and discourages method names that encode a delivery channel or screen identifier (`*_html`, `*_page`, etc.) when the intent is really domain persistence or a domain-meaningful read snapshot.

Historically, server-rendered master CRUD flows named gateway operations `*_for_html_form`, and public-plan flows used `public_plan_html_*` / `*_page_read_model`, which reads as UI-channel vocabulary at the domain boundary.

## Decision

- **Public plan (cultivation plan gateway)**  
  - `public_plan_html_save_session_payload` → `public_plan_wizard_save_session_payload` (wizard save-step session payload).  
  - `public_plan_results_page_read_model` → `public_plan_results_read_model` (results-flow read model; no `page` in the name).

- **Master CRUD form assembly** (crop, farm, field, fertilize, agricultural task, pesticide)  
  - Replace `*_for_html_form` (and related pesticide helpers) with **`*_for_master_form`**, meaning “Rails master CRUD form wiring” without naming a markup channel.

Implementations ([`lib/adapters/.../gateways/`](../../lib/adapters)), HTML controllers, interactors, and tests move in lockstep with the interface renames. Presenters do not gain new business rules; naming-only change.

## Consequences

- Call sites read as **domain/use-case** language first; HTML vs API remains an edge/presenter concern.
- Future gateways should prefer **why** (wizard, master form snapshot, authorized read model) over **where** (HTML, page).

## Alternatives considered

- **Keep `html` in names** for grep-ability from views — rejected: violates the stated gateway boundary and invites more presentation coupling.
- **Introduce separate HTML/API gateway interfaces** — rejected for these flows: same use case must share one interactor per [`ARCHITECTURE.md`](../../ARCHITECTURE.md); format differs only at presenters.
