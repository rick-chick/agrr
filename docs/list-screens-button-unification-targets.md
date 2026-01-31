# 一覧画面のボタン統一対応 — 対象洗い出し

一覧画面におけるボタンの配置・種類・表記を統一するための対象一覧と差異一覧。

## 参照

- 共通レイアウト: [frontend/src/app/components/masters/_master-layout.css](../frontend/src/app/components/masters/_master-layout.css)
- ボタンクラス: `.btn-primary`, `.btn-secondary`, `.btn-danger`
- 登録・編集画面の洗い出し: [masters-register-edit-screens-list.md](masters-register-edit-screens-list.md)

---

## 一覧画面の対象一覧（9 画面）

| # | 画面名 | コンポーネント | ルート例 |
|---|--------|----------------|----------|
| 1 | 農場一覧 | `masters/farms/farm-list` | `/farms` |
| 2 | 作物一覧 | `masters/crops/crop-list` | `/crops` |
| 3 | 肥料一覧 | `masters/fertilizes/fertilize-list` | `/fertilizes` |
| 4 | 農作業一覧 | `masters/agricultural-tasks/agricultural-task-list` | `/agricultural_tasks` |
| 5 | 病害虫一覧 | `masters/pests/pest-list` | `/pests` |
| 6 | 農薬一覧 | `masters/pesticides/pesticide-list` | `/pesticides` |
| 7 | 相互作用ルール一覧 | `masters/interaction-rules/interaction-rule-list` | `/interaction_rules` |
| 8 | 計画一覧 | `plans/plan-list` | `/plans` |

※ 計画一覧はマスタ外だが一覧UIとして対象に含める。

---

## ボタン配置の現状

### 1. ページヘッダー直下の「新規作成」ボタン

| 画面 | 配置 | クラス | ラベル例 |
|------|------|--------|----------|
| 農場 | `section-card__header-actions` | `btn-primary` | Create Farm |
| 作物 | `section-card__header-actions` | `btn-primary` | translate |
| 肥料 | `section-card__header-actions` | `btn-primary` | Create Fertilize |
| 農作業 | `section-card__header-actions` | `btn-primary` | New Agricultural Task |
| 病害虫 | `section-card__header-actions` | `btn-primary` | Create Pest |
| 農薬 | `section-card__header-actions` | `btn-primary` | Create Pesticide |
| 相互作用ルール | `section-card__header-actions` | `btn-primary` | translate |
| **計画** | **`page-actions`（page-header 内）** | `btn-primary` | 新規計画 |

**差異**: 計画一覧のみ「新規」ボタンが `page-header` 内の `page-actions` にあり、他はすべて `section-card` 内の `section-card__header-actions`。統一する場合は計画一覧を `section-card__header-actions` に揃える。

### 2. 行内アクション（item-card__actions）

**方針**: 詳細ボタンは設けず、詳細へはカード本文（`.item-card__body`）クリックで遷移する。行内アクションは「編集」「削除」のみとする。

| 画面 | Detail | Edit | Delete | 備考 |
|------|--------|------|--------|------|
| 農場 | 不要（カード本文で遷移） | ○ btn-secondary | ○ btn-danger | 行内は Edit + Delete のみ |
| 作物 | 不要（カード本文で遷移） | ○ btn-secondary | ○ btn-danger | |
| 肥料 | 不要（カード本文で遷移） | ○ btn-secondary | ○ btn-danger | |
| 農作業 | 不要（カード本文で遷移） | ○ btn-secondary | ○ btn-danger | |
| 病害虫 | 不要（カード本文で遷移） | ○ btn-secondary | ○ btn-danger | |
| 農薬 | 不要（カード本文で遷移） | ○ btn-secondary | ○ btn-danger | |
| 相互作用ルール | 不要（カード本文で遷移） | ○ btn-secondary | ○ btn-danger | |
| 計画 | 不要（カード本文で遷移） | なし | なし | 行内アクションなし（カード本文クリックで詳細へ） |

**差異**:
- 全一覧で Detail ボタンは設けない。詳細へはカード本文（`item-card__body`）のクリックで遷移する。
- **計画一覧**: 編集・削除を一覧から行わないため、行内に `item-card__actions` は設けない。

---

## 表記・i18n の現状

| 画面 | 新規ボタン | 行内ラベル | 備考 |
|------|------------|------------|------|
| 農場 | 英語ハードコード | Edit, Delete | |
| 作物 | translate | common.detail, common.edit, common.delete | |
| 肥料 | 英語ハードコード | Detail, Edit, Delete | |
| 農作業 | 英語ハードコード | Detail, Edit, Delete | |
| 病害虫 | 英語ハードコード | Detail, Edit, Delete | |
| 農薬 | 英語ハードコード | Detail, Edit, Delete | |
| 相互作用ルール | translate | common.* | |
| 計画 | 日本語ハードコード「新規計画」 | Detail | |

**統一方針の候補**: マスタ一覧はすべて translate に揃える、または「新規」は「Create XXX」「New XXX」のどちらかに表記を揃える。

---

## アクセシビリティ（aria-label）の現状

| 画面 | Delete ボタン aria-label |
|------|---------------------------|
| 農場 | `'Delete farm'`（文字列） |
| 作物 | `'common.delete' \| translate` |
| 肥料 | `aria-label="Delete fertilize"` |
| 農作業 | `aria-label="Delete agricultural task"` |
| 病害虫 | `aria-label="Delete pest"` |
| 農薬 | `aria-label="Delete pesticide"` |
| 相互作用ルール | `'common.delete' \| translate` |

**差異**: 属性の書き方が `aria-label="..."` と `[attr.aria-label]="..."` が混在。translate を使う場合は `[attr.aria-label]` で統一するのがよい。

---

## 統一対応のチェックリスト（案）

### レイアウト・配置

- [x] **L1** 計画一覧の「新規計画」を `section-card__header-actions` 内に移動し、他一覧と同じ構造にする。（対応済み: design-angular-material）
- [x] **L2** 農場一覧を行内「Detail / Edit / Delete」3本に揃える。（対応済み: Detail ボタン追加）

### ボタン種類・順序

- [x] **B1** 行内ボタンの順序を全画面で統一（Detail → Edit → Delete）。（対応済み）
- [ ] **B2** 新規ボタンのラベル表記を統一（Create XXX / New XXX のどちらか、または i18n キーで統一）。
- [x] **B3** 一覧の行内から詳細ボタンを削除する（詳細はカード本文クリックで遷移）。対象: 農場・作物・肥料・農作業・病害虫・農薬・相互作用ルール・計画の 8 コンポーネント。（対応済み）

### 表記・i18n

- [ ] **I1** マスタ一覧の新規・Detail/Edit/Delete をすべて translate に統一するか、英語ハードコードで揃えるか方針を決める。
- [ ] **I2** 計画一覧の「新規計画」を i18n に載せるかどうか。

### アクセシビリティ

- [x] **A1** Delete ボタンの `aria-label` を統一。（対応済み: translate 使用画面は `[attr.aria-label]="'common.delete' | translate"`、他は `aria-label="Delete"`）

---

## ファイル一覧（修正対象になり得るもの）

| 画面 | コンポーネント TS |
|------|-------------------|
| 農場 | `frontend/src/app/components/masters/farms/farm-list.component.ts` |
| 作物 | `frontend/src/app/components/masters/crops/crop-list.component.ts` |
| 肥料 | `frontend/src/app/components/masters/fertilizes/fertilize-list.component.ts` |
| 農作業 | `frontend/src/app/components/masters/agricultural-tasks/agricultural-task-list.component.ts` |
| 病害虫 | `frontend/src/app/components/masters/pests/pest-list.component.ts` |
| 農薬 | `frontend/src/app/components/masters/pesticides/pesticide-list.component.ts` |
| 相互作用ルール | `frontend/src/app/components/masters/interaction-rules/interaction-rule-list.component.ts` |
| 計画 | `frontend/src/app/components/plans/plan-list.component.ts` |

必要に応じて各コンポーネントの CSS（例: `plan-list.component.css` の `page-actions`）および `frontend/src/assets/i18n/ja.json`, `en.json` のキー追加も対象。

---

## まとめ

- **対象**: 一覧画面 **8 画面**（マスタ 7 + 計画 1）。
- **主な差異**: (1) 計画のみ新規ボタンが `page-actions`、(2) 農場のみ行内に Detail なし、(3) 新規・行内ラベルの i18n 有無、(4) Delete の aria-label の書き方。
- 上記チェックリストに沿って「配置」「ボタン種類・順序」「表記」「aria-label」を方針決定し、一括または画面単位で修正する。
