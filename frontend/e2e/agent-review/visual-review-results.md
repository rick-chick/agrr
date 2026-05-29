# Agent ビジュアルレビュー結果

## メタ

- **レビュー日**: 2026-05-30（ローカル）
- **対象行**: `route-to-png.md` 表の **#1–52**（全ルート）
- **キャプチャ**: `cd frontend && npm run e2e:capture-for-agent`（`E2E_CAPTURE_DEV_SESSION=1` `E2E_STRANGLER=1` `E2E_API_ORIGIN=http://127.0.0.1:3000`）。Playwright が **既存**の strangler（nginx :3000 → agrr-server :8080）と `ng serve`（:4200）を利用。`globalSetup` が **AuthTest モックログイン**で `e2e/.auth/dev-session.json` を生成。**`/api/v1/auth/me` はモックしない**。`resolve-capture-urls.ts` で実 ID に差し替え。
- **検証ログ**: `tmp/e2e-capture-agent-r2.log` — **50 passed / 2 skipped / 52 PNG**、`verify-capture-complete.mjs` OK。skip は `auth/login`・`login`（ログアウトセッション必須・既存 PNG 維持）。
- **前提の一言**: development SQLite（`storage/development.sqlite3`）・Rust API（`AGRR_RUST_API=1` 想定のスタック）。CSS トークン監査は `npm run audit:css-tokens` を正とし、本レビューは PNG のレイアウト・重なり・包含のみ。

## サマリ表

| # | pattern | PNG | 結果 | 指摘 |
| --- | --- | --- | --- | --- |
| 1 | `(home)` | `home.png` | OK | なし |
| 2 | `**` | `not-found.png` | OK | なし |
| 3 | `about` | `about.png` | OK | なし |
| 4 | `auth/login` | `auth_login.png` | OK | なし（キャプチャ skip・前回 PNG 維持） |
| 5 | `contact` | `contact.png` | OK | なし |
| 6 | `entry-schedule` | `entry-schedule.png` | OK | なし |
| 7 | `entry-schedule/crop/:cropId` | `entry-schedule_crop_cropId.png` | OK | なし |
| 8 | `login` | `login.png` | OK | なし（キャプチャ skip・前回 PNG 維持） |
| 9 | `privacy` | `privacy.png` | OK | なし |
| 10 | `public-plans/new` | `public-plans_new.png` | OK | なし |
| 11 | `public-plans/optimizing` | `public-plans_optimizing.png` | OK | なし |
| 12 | `public-plans/results` | `public-plans_results.png` | OK | なし |
| 13 | `public-plans/select-crop` | `public-plans_select-crop.png` | OK | なし |
| 14 | `public-plans/select-farm-size` | `public-plans_select-farm-size.png` | OK | なし |
| 15 | `terms` | `terms.png` | OK | なし |
| 16 | `agricultural_tasks` | `agricultural_tasks.png` | OK | なし（`.section-card` がカード列を包含。スキルレベルは API 値の英語表記） |
| 17 | `agricultural_tasks/:id` | `agricultural_tasks_id.png` | OK | なし |
| 18 | `agricultural_tasks/:id/edit` | `agricultural_tasks_id_edit.png` | OK | なし |
| 19 | `agricultural_tasks/new` | `agricultural_tasks_new.png` | OK | なし |
| 20 | `api-keys` | `api-keys.png` | 注意 | 本文は `max-width` 中央寄せだが、他マスタより左に寄って見える。コード例のコントラストは許容範囲 |
| 21 | `crops` | `crops.png` | OK | なし |
| 22 | `crops/:id` | `crops_id.png` | OK | なし |
| 23 | `crops/:id/edit` | `crops_id_edit.png` | OK | なし |
| 24 | `crops/new` | `crops_new.png` | OK | なし |
| 25 | `dashboard` | `dashboard.png` | OK | なし |
| 26 | `farms` | `farms.png` | OK | なし（3 列グリッド・カード内ボタン折返しは整列） |
| 27 | `farms/:id` | `farms_id.png` | OK | なし |
| 28 | `farms/:id/edit` | `farms_id_edit.png` | OK | なし |
| 29 | `farms/new` | `farms_new.png` | OK | なし |
| 30 | `fertilizes` | `fertilizes.png` | OK | なし（空状態も枠内に収まる） |
| 31 | `fertilizes/:id` | `fertilizes_id.png` | OK | なし |
| 32 | `fertilizes/:id/edit` | `fertilizes_id_edit.png` | OK | なし |
| 33 | `fertilizes/new` | `fertilizes_new.png` | OK | なし |
| 34 | `interaction_rules` | `interaction_rules.png` | OK | なし |
| 35 | `interaction_rules/:id` | `interaction_rules_id.png` | OK | なし |
| 36 | `interaction_rules/:id/edit` | `interaction_rules_id_edit.png` | OK | なし |
| 37 | `interaction_rules/new` | `interaction_rules_new.png` | OK | なし |
| 38 | `pesticides` | `pesticides.png` | OK | なし（作成ボタンとリスト枠の重なり解消） |
| 39 | `pesticides/:id` | `pesticides_id.png` | OK | なし |
| 40 | `pesticides/:id/edit` | `pesticides_id_edit.png` | OK | なし |
| 41 | `pesticides/new` | `pesticides_new.png` | OK | なし |
| 42 | `pests` | `pests.png` | OK | なし |
| 43 | `pests/:id` | `pests_id.png` | OK | なし |
| 44 | `pests/:id/edit` | `pests_id_edit.png` | OK | なし |
| 45 | `pests/new` | `pests_new.png` | OK | なし |
| 46 | `plans` | `plans.png` | OK | なし（カード重なり・はみ出し解消） |
| 47 | `plans/:id` | `plans_id.png` | 注意 | ガント内ラベルと削除ボタンの距離・省略は要 UX 確認 |
| 48 | `plans/:id/optimizing` | `plans_id_optimizing.png` | 注意 | 短コンテンツでフッター手前に余白（`page-main--fit` 適用済みだが大きめ） |
| 49 | `plans/:id/task_schedule` | `plans_id_task_schedule.png` | 注意 | 同上 |
| 50 | `plans/new` | `plans_new.png` | OK | なし（ラベル・セレクトの重なり解消、i18n キー整合） |
| 51 | `plans/select-crop` | `plans_select-crop.png` | OK | なし |
| 52 | `weather` | `weather.png` | 注意 | 見出し・チャート枠は表示されるが、チャート本体が空（気象 API／データ未供給の可能性） |

## 集計（任意）

| 結果 | 件数 |
| --- | --- |
| OK | 47 |
| 注意 | 5 |
| 要確認 | 0 |

## 指摘の詳細（注意のみ）

### #20 `api-keys.png`

設定画面は `page-content-container` で幅制限。マスタ一覧と視覚的な揃え方が異なるが、破綻はなし。

### #47–49 計画詳細・最適化・タスク予定

レイアウト破綻なし。ガントの視認性（#47）と短ページの下余白（#48–49）はデータ量・チャート実装に依存。

### #52 `weather.png`

i18n キー（`weather.page.*` / `weather.temperature.chart.*`）は解消。チャート未描画は `/weather` 用データ取得・Chart.js 初期化の別調査が必要。

---

## 総評（表の後）

**52 PNG は verify 済み**。マスタ一覧の **`.section-card` 包含崩れ・計画一覧カード重なり・農薬一覧の縦ずれ**は `_master-layout.css` と `plan-list.component.css` の修正で解消。あわせて **navbar / 一覧 description / plans.new / weather** の翻訳キー不足を補い、キャプチャ上の生キー表示を解消した。残る **注意** は API キー画面の幅感、計画ガントの密度、気象チャートのデータ欠如に限定される。
