# UI Composition Rules (Paved Road)

**Priority:** `LAYER-RULES` / CA boundaries > **this document** > `layout-contract` L2 > visual-review.

Angular pages compose **Shell + Pattern** components only. Do not assemble layout CSS (`compact-header-card`, `page-intro`, etc.) directly in page templates.

## Composition layers

| Layer | Location | Role |
|-------|----------|------|
| L0 | `styles.css`, `_button-primitives.css`, `_form-primitives.css` | Tokens and primitives |
| L1 | `components/shared/patterns/` | Dumb UI patterns (`loading` / `empty` / `error` / `ready`) |
| L2 | `components/shared/shells/` | Page shells (`app-funnel-shell`, `app-app-shell`) |
| L3 | `components/*/` pages | Shell + Pattern + UseCase wiring only |

## Shells

| Shell | Selector | Archetype | Variant |
|-------|----------|-----------|---------|
| Funnel | `app-funnel-shell` | `funnel-hub`, `wizard-step` | `hub` (title + description stacked), `wizard` (+ progress slot) |
| App | `app-app-shell` | `section-hub`, `master-*`, etc. | `page-main` + `page-header` |

- Use `titleKey` / `descriptionKey` with `translate` inside the shell.
- **Never** place `page-intro` inside `compact-header-card` (description belongs below the title, vertically).

## Patterns

- No Gateway / UseCase calls inside patterns.
- Expose `@Input() state` and display strings from the parent.
- Four-state component specs are required for L2 conformance.

## Conformance levels

| Level | Gate | Scope |
|-------|------|-------|
| L0 | SEO, a11y machine checks | Route exists, prerender h1 |
| L1 | Shell + `check:ui-composition` | Correct shell host, forbidden layout patterns |
| L2 | Pattern 4-state spec GREEN | loading / empty / error / ready |
| L3 | Funnel consistency | Same user action uses same pattern across routes |
| L4 | visual-review layout OK | Weekly / diff capture |

Levels are recorded in [`layout-conformance-bindings.mjs`](../../frontend/e2e/smoke/layout-conformance-bindings.mjs).

## Issue workflow

- User-facing UI work uses an **epic** with child issues per level (`[L1]`, `[L2]`, …).
- `[L0][SEO-only]` issues must not include user-facing layout changes.
- Exceptions: issue body `Exception:` section (deviation, reason, expiry). No ad-hoc layout hacks.

## Forbidden patterns (CI `check:ui-composition`)

1. `page-intro` inside `compact-header-card`
2. `link-inline` without a defined style in shared CSS
3. `public-plans-wrapper` + raw `form-control` + `btn-primary` for farm selection (use `FarmSelectionCardsPattern`)
4. `app-funnel-shell` with `variant="wizard"` without wizard progress projection (`UI-R4`)

## Wizard style scope (CI `check:wizard-style-scope`)

1. Inline `compact-progress` markup in page templates (`UI-R3`) — use a dedicated wizard progress component via FunnelShell `wizardProgress` slot

Scanned directories: `entry-schedule`, `public-plans`, `shared/shells` (see script `SCAN_DIRS`).

## Related

- [layout-contracts.md](layout-contracts.md) — L2 layout smoke archetypes
- [pattern-manifest.json](pattern-manifest.json) — Pattern catalog metadata (committed)
- [EVIDENCE-CHAIN.md](../../frontend/e2e/agent-review/EVIDENCE-CHAIN.md) — PNG review tmp-only
