# マスタ登録・編集画面一覧（洗い出し）

デザインスキル（`design-angular-material`）に従った登録・編集画面の対象一覧と、テンプレート（SAMPLES.md 7. 登録・編集画面テンプレート）との対応チェック用。

## 参照

- スキル: [.cursor/skills/design-angular-material/SKILL.md](../.cursor/skills/design-angular-material/SKILL.md)
- テンプレート: [.cursor/skills/design-angular-material/references/SAMPLES.md](../.cursor/skills/design-angular-material/references/SAMPLES.md) の「7. 登録・編集画面テンプレート」
- 共通レイアウト: [frontend/src/app/components/masters/_master-layout.css](../frontend/src/app/components/masters/_master-layout.css)

---

## 登録・編集画面一覧（14 画面）

| # | マスタ | 登録（Create） | 編集（Edit） | コンポーネントパス |
|---|--------|----------------|--------------|--------------------|
| 1 | 農場 (farms) | ○ | ○ | `masters/farms/farm-create`, `farm-edit` |
| 2 | 作物 (crops) | ○ | ○ | `masters/crops/crop-create`, `crop-edit` |
| 3 | 肥料 (fertilizes) | ○ | ○ | `masters/fertilizes/fertilize-create`, `fertilize-edit` |
| 4 | 農作業 (agricultural-tasks) | ○ | ○ | `masters/agricultural-tasks/agricultural-task-create`, `agricultural-task-edit` |
| 5 | 病害虫 (pests) | ○ | ○ | `masters/pests/pest-create`, `pest-edit` |
| 6 | 農薬 (pesticides) | ○ | ○ | `masters/pesticides/pesticide-create`, `pesticide-edit` |
| 7 | 相互作用ルール (interaction-rules) | ○ | ○ | `masters/interaction-rules/interaction-rule-create`, `interaction-rule-edit` |

**合計**: 7 マスタ × 2（登録 + 編集）= **14 画面**

---

## テンプレート要件（7a〜7d）との対応

### 7a. 一般構造

- **page-main**: ラッパー。カード中央配置のため `display: flex; flex-direction: column; align-items: center;` を推奨。
- **form-card**: 1 画面 1 枚。見出し・ローディング or フォーム・`form-card__actions` を内包。
- **form-card__title**: 見出し（新規登録 / 編集など）。
- **form-card__form** / **form-card__field** / **form-card__actions**: フォーム本体と送信・戻る。

### 7b. カードの役割

- form-card は 1 画面 1 枚。サブセクションが必要な場合は `section-card` をネスト。

### 7c. レスポンシブ

- `page-main` の padding、`form-card` の max-width / padding をブレークポイント（768px, 480px）で調整。
- 共通レイアウト（`_master-layout.css`）で定義済み。

### 7d. スマホ

- ボタン・戻るリンク: `min-height: var(--touch-target-min)`（44px）と十分な padding。
- 入力欄: `font-size` 16px 以上推奨（`--font-size-md`）。
- アクション: 小画面で `form-card__actions` を sticky で固定（共通で定義済み）。

---

## 画面別チェック項目（共通）

各登録・編集画面で以下を確認する。

- [ ] **HTML**: `<main class="page-main">` → `<section class="form-card">` → 見出し → フォーム → `form-card__actions`
- [ ] **ローディング**: 編集画面で `control.loading` がある場合、テンプレートに `@if (control.loading) { ... } @else { フォーム }` を用意
- [ ] **ラベルと input**: `<label>` と `input` を `for` / `id` で紐付け（placeholder をラベル代わりにしない）
- [ ] **見出し階層**: ページ内で `h2` を飛ばさない
- [ ] **ボタン**: 送信は `button type="submit"`、戻るは `a routerLink`（`.btn-secondary`）
- [ ] **CSS**: コンポーネント CSS は `@import '../_master-layout.css'` し、トークンのみ使用。フォームフィールドの input/textarea スタイルは必要に応じてコンポーネントで追加

---

## ファイル一覧（登録・編集）

| マスタ | Create (ts / css) | Edit (ts / css) |
|--------|-------------------|-----------------|
| farms | farm-create.component.ts, .css | farm-edit.component.ts, .css |
| crops | crop-create.component.ts, .css | crop-edit.component.ts, .css |
| fertilizes | fertilize-create.component.ts, .css | fertilize-edit.component.ts, .css |
| agricultural-tasks | agricultural-task-create.component.ts, .css | agricultural-task-edit.component.ts, .css |
| pests | pest-create.component.ts, .css | pest-edit.component.ts, .css |
| pesticides | pesticide-create.component.ts, .css | pesticide-edit.component.ts, .css |
| interaction-rules | interaction-rule-create.component.ts, .css | interaction-rule-edit.component.ts, .css |

※ テンプレートは各コンポーネントの `template: \`...\`` にインラインで記述されている。

---

## TODO（デザイン修正・画面単位）

- [x] **d1** farms: farm-create / farm-edit（label for/id、編集ローディング、トークンのみ）
- [x] **d2** crops: crop-create / crop-edit
- [x] **d3** fertilizes: fertilize-create / fertilize-edit
- [x] **d4** agricultural-tasks: agricultural-task-create / agricultural-task-edit
- [x] **d5** pests: pest-create / pest-edit
- [x] **d6** pesticides: pesticide-create / pesticide-edit
- [x] **d7** interaction-rules: interaction-rule-create / interaction-rule-edit

## デザイン修正の適用方針

1. **共通レイアウト**: `_master-layout.css` で `page-main` にカード中央配置（`display: flex; flex-direction: column; align-items: center;`）、`form-card` に `width: 100%` を追加済み。
2. **画面単位**: 上記チェック項目に沿い、各コンポーネントの template / CSS を修正。TODO d1〜d7 を cursor-agent で並列実行して対応可能。

## 注意：一覧への CSS 影響

**登録・編集画面のスタイルが一覧画面に効かないようにする。**

- フォーム用の `input` / `select` / `textarea` スタイルは **必ず `.form-card` の子**（例: `.form-card__field input`）で定義する。
- `_master-layout.css` は一覧・詳細・登録・編集の全画面で import されるため、フォーム専用ルールは `.form-card` 配下にのみ書く。
- 禁止: `main input`, `.page-main input`, `.section-card input` など、一覧とフォームの両方に当たり得る広いセレクタでフォーム用スタイルを書かない。
- スキル: [design-angular-material SKILL.md 4.6 一覧と登録・編集のスタイル分離](../.cursor/skills/design-angular-material/SKILL.md) を参照。
