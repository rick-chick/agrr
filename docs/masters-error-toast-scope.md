# フロント マスタ管理 エラーメッセージのトースト化 — 対象洗い出し

## 現状

- **表示方法**: 各マスタ画面で `control.error` を `<p class="master-error">{{ control.error }}</p>` としてインライン表示している。
- **エラー設定箇所**: 各 Presenter の `onError(dto)` で `view.control = { ...view.control, error: dto.message }` をセットしている。
- **既存のトースト系**:
  - `UndoToastService` … 削除後の Undo 用（成功メッセージ＋Undo ボタン）
  - `FlashMessageService` … グローバルメッセージ（`type: 'info' | 'success' | 'warning' | 'error'`）、`app-flash-message` で表示

## トースト化の方針（案）

- エラー時は **インラインの `master-error` 表示をやめ、トースト（または既存の FlashMessage）で表示する**。
- Presenter の `onError` で `view.control.error` をセットする代わりに（または併用せず）、**エラー用トースト／FlashMessage を 1 回表示**する。

---

## 1. 修正対象 Presenter（onError で control.error をセットしているもの）

`onError(dto)` 内で `this.view.control = { ..., error: dto.message }` をしているファイル。  
トースト化時はここで「エラー用トースト／FlashMessage を表示」し、`control.error` はセットしない（または null のまま）にする。

| # | ファイル | 備考 |
|---|----------|------|
| 1 | `app/adapters/crops/crop-list.presenter.ts` | 一覧 |
| 2 | `app/adapters/crops/crop-detail.presenter.ts` | 詳細 |
| 3 | `app/adapters/crops/crop-create.presenter.ts` | 作成 |
| 4 | `app/adapters/crops/crop-edit.presenter.ts` | 編集 |
| 5 | `app/adapters/pests/pest-list.presenter.ts` | 一覧 |
| 6 | `app/adapters/pests/pest-detail.presenter.ts` | 詳細 |
| 7 | `app/adapters/pests/pest-create.presenter.ts` | 作成 |
| 8 | `app/adapters/pests/pest-edit.presenter.ts` | 編集 |
| 9 | `app/adapters/pesticides/pesticide-list.presenter.ts` | 一覧 |
| 10 | `app/adapters/pesticides/pesticide-detail.presenter.ts` | 詳細 |
| 11 | `app/adapters/pesticides/pesticide-create.presenter.ts` | 作成 |
| 12 | `app/adapters/pesticides/pesticide-edit.presenter.ts` | 編集 |
| 13 | `app/adapters/fertilizes/fertilize-list.presenter.ts` | 一覧 |
| 14 | `app/adapters/fertilizes/fertilize-detail.presenter.ts` | 詳細 |
| 15 | `app/adapters/fertilizes/fertilize-create.presenter.ts` | 作成 |
| 16 | `app/adapters/fertilizes/fertilize-edit.presenter.ts` | 編集 |
| 17 | `app/adapters/agricultural-tasks/agricultural-task-list.presenter.ts` | 一覧 |
| 18 | `app/adapters/agricultural-tasks/agricultural-task-detail.presenter.ts` | 詳細 |
| 19 | `app/adapters/agricultural-tasks/agricultural-task-create.presenter.ts` | 作成 |
| 20 | `app/adapters/agricultural-tasks/agricultural-task-edit.presenter.ts` | 編集 |
| 21 | `app/adapters/interaction-rules/interaction-rule-list.presenter.ts` | 一覧 |
| 22 | `app/adapters/interaction-rules/interaction-rule-detail.presenter.ts` | 詳細 |
| 23 | `app/adapters/interaction-rules/interaction-rule-create.presenter.ts` | 作成 |
| 24 | `app/adapters/interaction-rules/interaction-rule-edit.presenter.ts` | 編集 |
| 25 | `app/adapters/farms/farm-list.presenter.ts` | 一覧 |
| 26 | `app/adapters/farms/farm-detail.presenter.ts` | 詳細 |
| 27 | `app/adapters/farms/farm-create.presenter.ts` | 作成 |
| 28 | `app/adapters/farms/farm-edit.presenter.ts` | 編集 |
| 29 | `app/adapters/farms/create-field.presenter.ts` | 圃場作成 |
| 30 | `app/adapters/farms/update-field.presenter.ts` | 圃場更新 |
| 31 | `app/adapters/farms/delete-field.presenter.ts` | 圃場削除 |

**合計: 31 ファイル（Presenter 層）**

---

## 2. 修正対象 コンポーネント（master-error を表示しているテンプレート）

`control.error` を表示しているマスタ用コンポーネント。  
トースト化後は **`@if (control.error)` ブロックごと削除**（または残すなら「トーストに任せるので通常は表示しない」運用でも可）。

| # | ファイル | 表示箇所数 |
|---|----------|------------|
| 1 | `components/masters/crops/crop-list.component.ts` | 1 |
| 2 | `components/masters/crops/crop-detail.component.ts` | 1 |
| 3 | `components/masters/crops/crop-create.component.ts` | 1 |
| 4 | `components/masters/crops/crop-edit.component.ts` | 2 |
| 5 | `components/masters/pests/pest-list.component.ts` | 1 |
| 6 | `components/masters/pests/pest-detail.component.ts` | 1 |
| 7 | `components/masters/pests/pest-create.component.ts` | 1 |
| 8 | `components/masters/pests/pest-edit.component.ts` | 2 |
| 9 | `components/masters/pesticides/pesticide-list.component.ts` | 1 |
| 10 | `components/masters/pesticides/pesticide-detail.component.ts` | 1 |
| 11 | `components/masters/pesticides/pesticide-create.component.ts` | 1 |
| 12 | `components/masters/pesticides/pesticide-edit.component.ts` | 2 |
| 13 | `components/masters/fertilizes/fertilize-list.component.ts` | 1 |
| 14 | `components/masters/fertilizes/fertilize-detail.component.ts` | 1 |
| 15 | `components/masters/fertilizes/fertilize-create.component.ts` | 1 |
| 16 | `components/masters/fertilizes/fertilize-edit.component.ts` | 2 |
| 17 | `components/masters/agricultural-tasks/agricultural-task-list.component.ts` | 1 |
| 18 | `components/masters/agricultural-tasks/agricultural-task-detail.component.ts` | 1 |
| 19 | `components/masters/agricultural-tasks/agricultural-task-create.component.ts` | 1 |
| 20 | `components/masters/agricultural-tasks/agricultural-task-edit.component.ts` | 2 |
| 21 | `components/masters/interaction-rules/interaction-rule-list.component.ts` | 1 |
| 22 | `components/masters/interaction-rules/interaction-rule-detail.component.ts` | 1 |
| 23 | `components/masters/interaction-rules/interaction-rule-create.component.ts` | 1 |
| 24 | `components/masters/interaction-rules/interaction-rule-edit.component.ts` | 2 |
| 25 | `components/masters/farms/farm-list.component.ts` | 1 |
| 26 | `components/masters/farms/farm-detail.component.ts` | 1 |
| 27 | `components/masters/farms/farm-create.component.ts` | 1 |
| 28 | `components/masters/farms/farm-edit.component.ts` | 2 |

**合計: 28 コンポーネント、表示ブロック約 36 箇所**

※ 圃場（create/update/delete field）は farm-detail 内で扱うため、上記の farm-detail / farm-edit に含まれる。

---

## 3. 共通・インフラ

| 種別 | ファイル | 対応内容 |
|------|----------|----------|
| CSS | `components/masters/_master-layout.css` | `.master-error` はトースト化後も他で使わなければ削除可（任意）。 |
| サービス | 新規 or 既存 | **エラー表示用**のどれを使うかで変わる（下記）。 |

---

## 4. エラー表示の実装パターン（選択肢）

### A. 既存の FlashMessageService を使う（推奨）

- `FlashMessageService.show({ type: 'error', text: dto.message })` を各 Presenter の `onError` で呼ぶ。
- 既存の `app-flash-message` がそのままエラー表示になる。見た目を「トースト風」にしたい場合は `FlashMessageComponent` のスタイルを調整。
- **追加ファイルなし**で済む。

### B. エラー専用トーストサービスを新規作成

- 例: `ErrorToastService`（signal で 1 件のメッセージを保持し、数秒で自動非表示など）。
- 新規コンポーネント＋サービスが必要。UndoToast と似た配置（画面上部 or 下部のバナー）にできる。

### C. UndoToastService を拡張

- `showError(message: string)` のようなメソッドを追加し、Undo ボタンなしのトーストとして表示。
- 既存の Undo トーストと UI を統一できるが、役割が混在する。

---

## 5. テストの影響

- **Presenter のテスト**: `onError` で「view.control.error がセットされること」に加え（または代わりに）、**トースト／FlashMessage が 1 回呼ばれること**を検証する必要がある。
- **Component のテスト**: `control.error` を表示する前提のテストがあれば削除 or 変更（例: farm-create.component.spec.ts, farm-edit.component.spec.ts で `control.error` を期待している箇所）。

対象になり得るテストファイル（マスタ関連 Presenter / Component の spec）は、上記 1・2 の一覧に含まれる各 `*.presenter.spec.ts` および `*.component.spec.ts`。

---

## 6. 対象外（今回スコープ外）

- **public-plans**（`public-plan-create`, `public-plan-select-crop`, `public-plan-results`, `public-plan-optimizing`）の `error-message` / `control.error` はマスタ管理ではないため、本スコープでは触れない。
- マスタ以外の画面で `control.error` やインラインエラー表示をしている箇所も、今回の「マスタ管理エラーのトースト化」の対象外とする。

---

## 7. 作業順序の提案

1. **エラー表示手段の決定**（A/B/C のいずれか）。
2. **1 つのマスタでパイロット**（例: crops の list/detail/create/edit と対応する Presenter 4 本＋コンポーネント 4 つ）。
3. パイロットで問題なければ、**残り 27 コンポーネント・対応 Presenter** に同様の変更を展開。
4. **Presenter テスト**で `onError` 時のトースト／FlashMessage 呼び出しを検証。
5. **Component テスト**で `control.error` 前提を削除 or 修正。
6. （任意）`.master-error` の削除や FlashMessage のスタイル調整。

以上が、フロントのマスタ管理エラーメッセージをトースト化する際の対象洗い出しです。
