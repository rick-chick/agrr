# AGRR Component Guide (AI-ready)

エージェント・新規実装者向けの最小コンポーネント仕様。トークン定義の正本は [`frontend/src/styles.css`](../../src/styles.css)。ボタン primitive は [`_button-primitives.css`](../../src/app/components/shared/_button-primitives.css)、マスタ画面のレイアウト・ボタンは [`_master-layout.css`](../../src/app/components/masters/_master-layout.css) を参照する。

## Button variants

| Variant | Class | 用途 |
|---------|-------|------|
| **primary** | `btn btn-primary` | 画面の主アクション（1 画面に 1 つ）。例: 新規作成、保存、次へ |
| **secondary** | `btn btn-secondary` | 主アクション以外の操作。例: 一覧へ戻る、再試行、キャンセル相当 |
| **danger** | `btn btn-danger` | 破壊的操作（削除・アカウント削除）。**outline スタイル**（赤塗りつぶし禁止） |

### ルール

1. **必ず `.btn` ベースクラスを付ける** — `btn-primary` 単体は禁止。CI の `check:btn-base-class:enforce` が検出する。
2. **primary は 1 画面 1 つ** — 複数の同等重要度ボタンがある場合は secondary に落とす。
3. **danger は確認を伴う** — 削除は confirm ダイアログまたは専用フローで誤操作を防ぐ。
4. **トークンを使う** — 色・余白は `var(--color-*)` / `var(--space-*)`。ハードコード HEX は `audit:css-tokens:enforce` で拒否される。

### 参照 CSS

- グローバル primitive: [`_button-primitives.css`](../../src/app/components/shared/_button-primitives.css)
- マスタ一覧・詳細: [`_master-layout.css`](../../src/app/components/masters/_master-layout.css)（`btn-danger` は outline）

## Anti-patterns

| 禁止 | 理由 | 正しい代替 |
|------|------|------------|
| primary を 2 つ横並び | ユーザーが主アクションを迷う | 1 つを primary、もう 1 つを secondary |
| `btn-danger` に赤背景（filled） | マスタ UI の danger は outline が規約 | `_master-layout.css` の outline `btn-danger` |
| `btn-primary` なしで variant のみ | タップ領域・focus が欠落 | `class="btn btn-primary"` |
| コンポーネント CSS に `#2563eb` 等を直書き | トークン単一ソース違反 | `var(--color-primary)` |
| 画面下部の固定「戻る」ボタン | パンくず統一キャンペーンで廃止 | `MasterContextHeaderComponent` のパンくず |

## Shared components

| 用途 | コンポーネント | ファイル |
|------|----------------|----------|
| **空状態** | 画面固有テンプレート（共通コンポーネントなし） | 例: `plan-list-empty`（[`plan-list.component.ts`](../../src/app/components/plans/plan-list.component.ts)）、`work-hub-empty`（[`work-hub.component.ts`](../../src/app/components/work-hub/work-hub.component.ts)） |
| **エラーパネル（マスタ）** | `MasterLoadErrorPanelComponent` | [`master-load-error-panel.component.ts`](../../src/app/components/masters/master-load-error-panel/master-load-error-panel.component.ts) |
| **エラーパネル（一覧インライン）** | `page-alert-error` + retry ボタン | 例: [`plan-list.component.ts`](../../src/app/components/plans/plan-list.component.ts) |
| **パンくず（マスタ）** | `MasterContextHeaderComponent` | [`master-context-header.component.ts`](../../src/app/components/masters/master-context-header/master-context-header.component.ts) |
| **パンくず（計画）** | `PlanPlanContextHeaderComponent` | [`plan-plan-context-header.component.ts`](../../src/app/components/plans/plan-plan-context-header.component.ts) |

### 空状態のパターン

- 見出し + 説明 + **primary CTA 1 つ**（例: 計画一覧の「新規計画」）
- secondary リンクは 1 つまで（例: 公開プランへの導線）
- i18n キーは `*.empty.*` または `*.no_*` 命名に揃える

## Design tokens

- **正本**: [`frontend/src/styles.css`](../../src/styles.css) の `:root`
- **監査**: `npm run audit:css-tokens:enforce` — コンポーネント CSS のハードコード色・余白を拒否
- **ボタン監査**: `npm run check:btn-base-class:enforce` — `btn-*` に `.btn` ベース必須
- **追加検証**: `npm run verify:primary-color-tokens` — primary / brand トークン分離

新規トークンが必要なときは **まず `styles.css` にセマンティック名で追加**し、コンポーネントから `var(--*)` で参照する。コンポーネント側にフォールバック HEX を書かない。

## Reference implementations

模範画面（エージェントは実装前に読むこと）:

| 画面 | ルート | コンポーネント | 学ぶこと |
|------|--------|----------------|----------|
| 作物詳細 | `/crops/:id` | [`crop-detail.component.ts`](../../src/app/components/masters/crops/crop-detail.component.ts) | 3 段パンくず、ロードエラーパネル、primary/secondary 配置 |
| 作業ハブ | `/work` | [`work-hub.component.ts`](../../src/app/components/work-hub/work-hub.component.ts) | 空状態、エラー + retry、カード一覧 |
| 計画一覧 | `/plans` | [`plan-list.component.ts`](../../src/app/components/plans/plan-list.component.ts) | 空状態 + primary CTA、danger outline 削除、インラインエラー |

## Dark mode policy

**方針 (B): 将来対応予定。** 現時点ではライトテーマのみ。`prefers-color-scheme: dark` の実装はない。

詳細はリポジトリルートの [ADR-003](../../../docs/adr/ADR-003-dark-mode-policy.md) を参照。ダークモード実装時は `styles.css` のセマンティックトークンを `@media (prefers-color-scheme: dark)` または `data-theme` で上書きする設計とする（コンポーネント直書きは禁止）。
