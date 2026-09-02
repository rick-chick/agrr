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

## Wizard progress flex — test layer matrix

`FunnelShell variant="wizard"` と `.compact-progress` の flex レイアウトは **3 層** で観測できるが、**責務を重複させない**。  
`ci-design-audit-gates`（#1273 再発防止）と sequential-cleanup §B（`component.spec` は View バインディング主責務）のトレードオフを本表で固定する。

| 層 | ファイル / ゲート | 観測するもの | 観測しないもの（他層へ委譲） |
|----|-------------------|--------------|------------------------------|
| **Component unit** | `entry-schedule-*.component.spec.ts`, `funnel-shell.component.spec.ts` | DOM 構造（`.funnel-shell-header--wizard`, `.compact-progress` の存在）、`activeStep` バインディング、完了ステップの `routerLink` | `getComputedStyle(display:flex)`、`min-height`、viewport 折り返し |
| **E2E smoke** | `wizard-progress-style.spec.ts` + [`assert-wizard-progress-lib.mjs`](../../frontend/e2e/smoke/assert-wizard-progress-lib.mjs) | 実ブラウザの `display: flex` と `min-height >= 40px`（`.compact-progress`）、ルート間 `compareWizardProgressLayouts` | UseCase 分岐、i18n キー網羅 |
| **Layout contract** | `layout-archetype-design-contract-browser-eval.mjs` の `wizardProgressSelectors`（`funnel-hub` / `wizard-step`） | スモーク経路での `display: flex` のみ（構造ゲート） | `min-height` 閾値（E2E lib が正本。粒度統一は #1286） |

### 方針

1. **`*.component.spec.ts` に `getComputedStyle` による flex 断言を追加しない** — jsdom は CSS 適用が不完全で、#1273 系の再発防止には E2E / layout contract の方が信頼できる。
2. **E2E が flex + 密度（min-height）の正本** — 契約定数は `assert-wizard-progress-lib.mjs` に集約し、Playwright spec は lib を呼ぶだけにする。
3. **Layout contract は横断スモークの薄いゲート** — `display:flex` のみ。`min-height` を layout contract に持ち込む場合は #1286 で lib と単一ソース化してから行う。
4. **`funnel-shell.component.spec.ts` の `getComputedStyle`** — overflow/ellipsis（hub タイトル）のみ許容。wizard flex には使わない。

### frontend-test 高速ゲートとして component.spec を維持しない理由

component.spec で flex を見ても **スタイルの単一ソース（`public-plan.component.css` の `.compact-progress`）を検証できない**（entry-schedule は同クラスを共有参照）。  
高速フィードバックが必要なのは **スロット投影とステップ状態** であり、CSS レイアウトは E2E smoke（`npm run test:e2e:smoke:wizard-progress`、#1286 で追加予定）に委譲する。

## Related

- [layout-contracts.md](layout-contracts.md) — L2 layout smoke archetypes（`wizardProgressSelectors` フィールド）
- [pattern-manifest.json](pattern-manifest.json) — Pattern catalog metadata (committed)
- [EVIDENCE-CHAIN.md](../../frontend/e2e/agent-review/EVIDENCE-CHAIN.md) — PNG review tmp-only
- [`assert-wizard-progress-lib.mjs`](../../frontend/e2e/smoke/assert-wizard-progress-lib.mjs) — E2E wizard flex 契約（ユニットテスト: `assert-wizard-progress-lib.test.mjs`）
