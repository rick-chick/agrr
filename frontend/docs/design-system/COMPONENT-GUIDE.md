# AGRR Component Guide（AI-ready）

エージェント・新規実装者向けのコンポーネント利用仕様。色・余白は **CSS カスタムプロパティ（デザイントークン）** のみを使い、コンポーネント CSS への直書きは禁止する。

| 正本 | パス |
|------|------|
| デザイントークン | `frontend/src/styles.css`（`:root`） |
| ボタン primitive | `frontend/src/app/components/shared/_button-primitives.css` |
| マスタ画面レイアウト | `frontend/src/app/components/masters/_master-layout.css` |
| トークン監査 | `npm run audit:css-tokens:enforce` |
| ボタン基底クラス監査 | `npm run check:btn-base-class:enforce` |

## ボタン variant（primary / secondary / danger）

**必須**: すべてのボタン・ボタン風リンクは `btn` 基底クラスと variant を併用する（`class="btn btn-primary"`）。variant 単体（`class="btn-primary"` のみ）は CI で失敗する。

| Variant | 用途 | 見た目（要約） |
|---------|------|----------------|
| `btn btn-primary` | 画面の**主アクション**（保存・作成・次へ・CTA） | filled primary |
| `btn btn-secondary` | **副アクション**（キャンセル・戻る・再試行） | outline neutral |
| `btn btn-danger` | **破壊的操作**（削除・アカウント削除） | outline error（surface 背景 + error 文字 + border） |

定義場所:

- `btn` / `btn-primary` / `btn-secondary` → `_button-primitives.css`
- `btn-danger` → `_master-layout.css`（マスタ一覧・詳細の削除ボタン規約）

### Do

- 1 画面・1 ダイアログに **primary は 1 つ**（最も重要な前進アクション）
- 削除は必ず `btn-danger`（画面固有の赤スタイルを新規定義しない）
- ダイアログの actions 行は `form-card__actions` 内に primary / secondary / danger を並べる（`form-dialog-shared.css` 参照）

### アンチパターン

| 禁止 | 理由 | 正しい例 |
|------|------|----------|
| primary を 2 つ横並び | ユーザーが「どちらが本筋か」迷う | 片方を secondary にするか、リンクテキストに格下げ |
| `btn-primary` のみ（`btn` なし） | `check:btn-base-class:enforce` 違反 | `class="btn btn-primary"` |
| 削除に primary や独自 `.delete-btn` | 誤タップリスク・スタイル分散 | `class="btn btn-danger"` |
| 色の hex / rgb 直書き | トークン単一ソース破壊 | `var(--color-primary)` 等 |
| 破壊的操作を primary で強調 | 意図と逆の視覚優先度 | danger + 確認ダイアログ |

## 空状態（empty state）

一覧・ハブでデータが 0 件のときのパターン。文言は i18n キー、レイアウトは `section-card` 内の専用ブロック。

| 画面 | コンポーネント | パス | ルート |
|------|----------------|------|--------|
| 作業ハブ（農場なし） | `WorkHubComponent` | `frontend/src/app/components/work-hub/work-hub.component.ts` | `/work` |
| 計画一覧（計画なし） | `PlanListComponent` | `frontend/src/app/components/plans/plan-list.component.ts` | `/plans` |

**構造（共通）**:

1. 説明文（`no_*` 系 i18n）
2. 補足ヒント（`*-hint` クラス）
3. **単一の** `btn btn-primary` CTA（作成・新規へ）
4. 任意: セカンダリリンク（`plan-list-empty-secondary` など。primary は増やさない）

## エラーパネル

| 種別 | コンポーネント | パス | 使い分け |
|------|----------------|------|----------|
| マスタ CRUD 読み込み失敗 | `MasterLoadErrorPanelComponent` | `frontend/src/app/components/masters/master-load-error-panel/master-load-error-panel.component.ts` | 詳細画面の fetch 失敗。一覧へ戻る + 再試行 |
| 一覧・ハブのインラインエラー | `page-alert-error` ブロック | 各コンポーネント template 内 | `work-hub` / `plan-list` のリスト取得失敗 |

`MasterLoadErrorPanel` は **secondary のみ**（戻る・再試行）。primary を置かない。

## パンくず（breadcrumb）

| 文脈 | コンポーネント | パス |
|------|----------------|------|
| マスタ CRUD（作物・農場等） | `MasterContextHeaderComponent` | `frontend/src/app/components/masters/master-context-header/master-context-header.component.ts` |
| 公開プラン wizard | `PublicPlanContextHeaderComponent` | `frontend/src/app/components/public-plans/public-plan-context-header.component.ts` |

`MasterContextCrumb` で `labelKey` + `routerLink` を渡す。`aria-label` は `common.breadcrumb_label`（i18n カタログ: `common-breadcrumb-locale.catalog.spec.ts`）。

## トークン直書き禁止

- コンポーネント CSS で `#2563eb` 等のリテラル色・余白を**新規追加しない**
- 既存トークンで足りない場合は **まず `styles.css` にセマンティックトークンを追加**し、コンポーネントは `var(--*)` のみ参照
- CI: `npm run audit:css-tokens:enforce`（違反は `--enforce` で fail）
- ボタン: `npm run check:btn-base-class:enforce`

## 参照実装（模範画面）

実装前に以下の **実ファイル** を読むこと。

| ルート | コンポーネント | 模範とする点 |
|--------|----------------|--------------|
| `/crops/:id` | [`crop-detail.component.ts`](../src/app/components/masters/crops/crop-detail.component.ts) | パンくず + `MasterLoadErrorPanel` + 詳細カード + アクション配置 |
| `/work` | [`work-hub.component.ts`](../src/app/components/work-hub/work-hub.component.ts) | 空状態 + インラインエラー + primary CTA 1 つ |
| `/plans` | [`plan-list.component.ts`](../src/app/components/plans/plan-list.component.ts) | 空状態 + 一覧カード + primary/secondary/danger の役割分担 |

E2E ルート定義: `frontend/e2e/route-manifest.json`。

## ダークモード

方針の正本は [`DARK-MODE-POLICY.md`](./DARK-MODE-POLICY.md)。現時点では **ライトテーマのみ実装**。OS ダークモード追従は未実装（#712 参照）。

## 関連 issue・スキル

- UX 観点 2（デザインシステム）— #731
- CSS トークン監査 — `.cursor/skills/frontend-css-route-audit/SKILL.md`
- ビジュアルレビュー — `.cursor/skills/frontend-agent-visual-review/SKILL.md`
