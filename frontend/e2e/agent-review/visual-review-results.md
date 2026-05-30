# Agent ビジュアルレビュー結果

## メタ

- **レビュー日**: 2026-05-30（UTC）
- **対象**: `route-to-png.md` **#1–52**（全ルート・**ja / en / in** 各 1 枚）
- **キャプチャ**: `npm run e2e:capture-for-agent`（`E2E_CAPTURE_DEV_SESSION=1` `E2E_STRANGLER=1` `E2E_API_ORIGIN=http://127.0.0.1:3000`）。AuthTest モックログイン・`/api/v1/auth/me` 非モック。`verify-capture-complete` **150 PNG**（`auth/login`・`login` は dev-session 仕様で未撮影・verify 除外）。**補足**: 全件キャプチャは `pests` 一覧で 1 回失敗後も継続（49 passed）。`crops` / `api-keys` は i18n 修正後に部分再キャプチャ済み。
- **前提**: development SQLite・実データ（作物名など英日混在はマスタデータ由来）。CSS トークンは `npm run audit:css-tokens` を正とし、本レビューはレイアウト・読み込み状態・**i18n** のみ。機械チェック `npm run check-hardcoded-i18n` は **high: 0**（`tmp/visual-i18n-baseline.md` 参照）。

## サマリ表

| # | pattern | ja | en | in | 結果 | i18n | 指摘 |
|---|---------|----|----|-----|------|------|------|
| 1 | `(home)` | `home.ja.png` | `home.en.png` | `home.in.png` | OK | OK | なし（ヒーロー・機能カード・CTA が各言語で表示） |
| 2 | `**` | `not-found.ja.png` | `not-found.en.png` | `not-found.in.png` | OK | OK | なし（`pages.notFound.*` 解決済み） |
| 3 | `about` | `about.ja.png` | `about.en.png` | `about.in.png` | OK | OK | なし（`contact_html` / `ads_notice_html`・in ナビヒンディー） |
| 4 | `auth/login` | — | — | — | 要確認 | 要確認 | **キャプチャなし**（ログアウトセッション要・dev-session では skip） |
| 5 | `contact` | `contact.ja.png` | `contact.en.png` | `contact.in.png` | OK | OK | なし（`contact_form.*` 解決済み） |
| 6 | `entry-schedule` | `entry-schedule.ja.png` | `entry-schedule.en.png` | `entry-schedule.in.png` | OK | OK | なし（`entrySchedule.*` 解決済み） |
| 7 | `entry-schedule/crop/:cropId` | `entry-schedule_crop_cropId.ja.png` | `entry-schedule_crop_cropId.en.png` | `entry-schedule_crop_cropId.in.png` | OK | OK | なし（#6 同系・目視でキー露出なし） |
| 8 | `login` | — | — | — | 要確認 | 要確認 | **キャプチャなし**（#4 同様） |
| 9 | `privacy` | `privacy.ja.png` | `privacy.en.png` | `privacy.in.png` | OK | OK | なし |
| 10 | `public-plans/new` | `public-plans_new.ja.png` | `public-plans_new.en.png` | `public-plans_new.in.png` | OK | OK | なし（`AVAILABLE FARMS` 英語表示・dev ユーザー名 locale 追従） |
| 11 | `public-plans/optimizing` | `public-plans_optimizing.ja.png` | `public-plans_optimizing.en.png` | `public-plans_optimizing.in.png` | OK | OK | なし（`plans.optimizing_live.*` 解決済み・目視） |
| 12 | `public-plans/results` | `public-plans_results.ja.png` | `public-plans_results.en.png` | `public-plans_results.in.png` | OK | OK | なし（ウィザード各言語・キー露出なし） |
| 13 | `public-plans/select-crop` | `public-plans_select-crop.ja.png` | `public-plans_select-crop.en.png` | `public-plans_select-crop.in.png` | OK | OK | なし |
| 14 | `public-plans/select-farm-size` | `public-plans_select-farm-size.ja.png` | `public-plans_select-farm-size.en.png` | `public-plans_select-farm-size.in.png` | OK | OK | なし |
| 15 | `terms` | `terms.ja.png` | `terms.en.png` | `terms.in.png` | OK | OK | なし（in で `%{contact_link}` 解消・第10条ヒンディー） |
| 16 | `agricultural_tasks` | `agricultural_tasks.ja.png` | `agricultural_tasks.en.png` | `agricultural_tasks.in.png` | OK | OK | なし（マスタ一覧同型・ナビ locale 追従） |
| 17 | `agricultural_tasks/:id` | `agricultural_tasks_id.ja.png` | `agricultural_tasks_id.en.png` | `agricultural_tasks_id.in.png` | OK | OK | なし |
| 18 | `agricultural_tasks/:id/edit` | `agricultural_tasks_id_edit.ja.png` | `agricultural_tasks_id_edit.en.png` | `agricultural_tasks_id_edit.in.png` | OK | OK | なし |
| 19 | `agricultural_tasks/new` | `agricultural_tasks_new.ja.png` | `agricultural_tasks_new.en.png` | `agricultural_tasks_new.in.png` | OK | OK | なし |
| 20 | `api-keys` | `api-keys.ja.png` | `api-keys.en.png` | `api-keys.in.png` | OK | 注意 | layout: なし。i18n: in の `usage.endpoints.list_html` 内説明に日本語行が残る可能性（見出し・手順はヒンディー化済み・再キャプチャ後） |
| 21 | `crops` | `crops.ja.png` | `crops.en.png` | `crops.in.png` | OK | OK | なし（見出し locale 追従。行データの英日混在はマスタ由来） |
| 22 | `crops/:id` | `crops_id.ja.png` | `crops_id.en.png` | `crops_id.in.png` | OK | OK | なし |
| 23 | `crops/:id/edit` | `crops_id_edit.ja.png` | `crops_id_edit.en.png` | `crops_id_edit.in.png` | OK | OK | なし |
| 24 | `crops/new` | `crops_new.ja.png` | `crops_new.en.png` | `crops_new.in.png` | OK | OK | なし |
| 25 | `dashboard` | `dashboard.ja.png` | `dashboard.en.png` | `dashboard.in.png` | OK | OK | なし（`HomeComponent` 再利用・#1 と同内容で翻訳済み） |
| 26 | `farms` | `farms.ja.png` | `farms.en.png` | `farms.in.png` | OK | OK | なし |
| 27 | `farms/:id` | `farms_id.ja.png` | `farms_id.en.png` | `farms_id.in.png` | OK | OK | なし |
| 28 | `farms/:id/edit` | `farms_id_edit.ja.png` | `farms_id_edit.en.png` | `farms_id_edit.in.png` | OK | OK | なし |
| 29 | `farms/new` | `farms_new.ja.png` | `farms_new.en.png` | `farms_new.in.png` | OK | OK | なし |
| 30 | `fertilizes` | `fertilizes.ja.png` | `fertilizes.en.png` | `fertilizes.in.png` | OK | OK | なし |
| 31 | `fertilizes/:id` | `fertilizes_id.ja.png` | `fertilizes_id.en.png` | `fertilizes_id.in.png` | OK | OK | なし |
| 32 | `fertilizes/:id/edit` | `fertilizes_id_edit.ja.png` | `fertilizes_id_edit.en.png` | `fertilizes_id_edit.in.png` | OK | OK | なし |
| 33 | `fertilizes/new` | `fertilizes_new.ja.png` | `fertilizes_new.en.png` | `fertilizes_new.in.png` | OK | OK | なし |
| 34 | `interaction_rules` | `interaction_rules.ja.png` | `interaction_rules.en.png` | `interaction_rules.in.png` | OK | OK | なし |
| 35 | `interaction_rules/:id` | `interaction_rules_id.ja.png` | `interaction_rules_id.en.png` | `interaction_rules_id.in.png` | OK | OK | なし |
| 36 | `interaction_rules/:id/edit` | `interaction_rules_id_edit.ja.png` | `interaction_rules_id_edit.en.png` | `interaction_rules_id_edit.in.png` | OK | OK | なし |
| 37 | `interaction_rules/new` | `interaction_rules_new.ja.png` | `interaction_rules_new.en.png` | `interaction_rules_new.in.png` | OK | OK | なし |
| 38 | `pesticides` | `pesticides.ja.png` | `pesticides.en.png` | `pesticides.in.png` | OK | OK | なし |
| 39 | `pesticides/:id` | `pesticides_id.ja.png` | `pesticides_id.en.png` | `pesticides_id.in.png` | OK | OK | なし |
| 40 | `pesticides/:id/edit` | `pesticides_id_edit.ja.png` | `pesticides_id_edit.en.png` | `pesticides_id_edit.in.png` | OK | OK | なし |
| 41 | `pesticides/new` | `pesticides_new.ja.png` | `pesticides_new.en.png` | `pesticides_new.in.png` | OK | OK | なし |
| 42 | `pests` | `pests.ja.png` | `pests.en.png` | `pests.in.png` | OK | OK | なし（初回キャプチャで一覧ホスト待機失敗あり・PNG は verify 充足） |
| 43 | `pests/:id` | `pests_id.ja.png` | `pests_id.en.png` | `pests_id.in.png` | OK | OK | なし |
| 44 | `pests/:id/edit` | `pests_id_edit.ja.png` | `pests_id_edit.en.png` | `pests_id_edit.in.png` | OK | OK | なし |
| 45 | `pests/new` | `pests_new.ja.png` | `pests_new.en.png` | `pests_new.in.png` | OK | OK | なし |
| 46 | `plans` | `plans.ja.png` | `plans.en.png` | `plans.in.png` | OK | OK | なし |
| 47 | `plans/:id` | `plans_id.ja.png` | `plans_id.en.png` | `plans_id.in.png` | OK | 注意 | layout: なし。i18n: 解決済みキーだが **plan id=1 が存在せず**「リソースが見つかりません」表示（ガント未検証・E2E 実 ID 差し替え要） |
| 48 | `plans/:id/optimizing` | `plans_id_optimizing.ja.png` | `plans_id_optimizing.en.png` | `plans_id_optimizing.in.png` | OK | OK | なし（`plans.optimizing_live.*` 日本語 UI 確認） |
| 49 | `plans/:id/task_schedule` | `plans_id_task_schedule.ja.png` | `plans_id_task_schedule.en.png` | `plans_id_task_schedule.in.png` | OK | OK | なし（#47 と同様データ依存の可能性・キー露出なし） |
| 50 | `plans/new` | `plans_new.ja.png` | `plans_new.en.png` | `plans_new.in.png` | OK | OK | なし |
| 51 | `plans/select-crop` | `plans_select-crop.ja.png` | `plans_select-crop.en.png` | `plans_select-crop.in.png` | OK | OK | なし |
| 52 | `weather` | `weather.ja.png` | `weather.en.png` | `weather.in.png` | 注意 | OK | layout: チャート領域プレースホルダ（実 API 未接続・**既知制限**）。i18n: in 含めラベル・ナビは各言語 |

## 集計（レイアウト・読み込み）

| 結果 | 件数 |
|------|------|
| OK | 48 |
| 注意 | 2（#20 api-keys・#52 weather） |
| 要確認 | 2（#4・#8 未撮影） |

## 集計（i18n）

| i18n | 件数 |
|------|------|
| OK | 48 |
| 注意 | 2（#20・#47） |
| 要確認 | 2（#4・#8 未撮影） |

## 指摘の詳細

### 解消済み（前回レビューからの主な改善）

1. **キー欠落** — `home.index.*` / `pages.notFound.*` / `contact_form.*` / `entrySchedule.*` / `public_plans.select_farm.*` / `plans.gantt.*` / `js.gantt.*` / `plans.optimizing_live.*` を 3 言語 JSON に追加。
2. **about / terms** — `*_html` + `{{param}}` + `innerHTML` に統一。in の `%{contact_link}` 字面表示を解消。
3. **en 作物一覧見出し** — トップレベル `crops.index.*` を en に追加（再キャプチャで「Crops」確認）。
4. **in ナビ・マスタ** — `nav` / `crops` / `weather` ブロック追加。about・weather・crops 一覧でヒンディー UI を確認。
5. **開発者表示名** — navbar で `developer@agrr.dev` 等を locale 短縮ラベルにマップ（`Login as Developer` → `Developer` / `डेवलपर` 等）。

### #20 `api-keys`（in）

画面ラベル・使用方法・注意文はヒンディー化済み（再キャプチャ確認）。`api_keys.usage.endpoints.list_html` のエンドポイント説明行に日本語が残る場合は HTML ブロック全体の in 翻訳が別途必要（優先度低・技術リファレンス）。

### #47 `plans/:id`

manifest の `/plans/1` が開発 DB に無くエラー画面。i18n キー露出ではなく **E2E 実 plan id 解決**の課題。ガント UI の再検証は resolved id 取得後。

### #52 `weather`

見出し・ナビは locale ごとに OK。チャートはダミー／空（`temperature-chart` プレースホルダ）— **データ接続はスコープ外**。

### #4 `auth/login` / #8 `login`

dev-session キャプチャでは未撮影。未ログイン UI の 3 言語レビューは別 spec／storage 要。

## 総評

i18n 修正後の再キャプチャ・目視により、**P0/P1 で挙がっていたキー露出・in ナビ未切替・terms 補間・en 作物見出しは概ね解消**（48/50 ルートで i18n OK）。残りは **未撮影ログイン 2 ルート**、**api-keys の HTML エンドポイント一覧の in 完全化**（任意）、**plan 詳細の E2E 実 ID**、**気象チャート実データ**（別タスク）。機械チェック `check-hardcoded-i18n` は high 0 を維持。
