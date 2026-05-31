# Agent ビジュアルレビュー結果

## メタ

- **レビュー日**: 2026-05-31（UTC）
- **対象**: `route-to-png.md` **#1–52**（全ルート・**ja / en / in** 各 1 枚）
- **キャプチャ**: `npm run e2e:capture-for-agent`（`E2E_CAPTURE_DEV_SESSION=1` `E2E_STRANGLER=1` `E2E_API_ORIGIN=http://127.0.0.1:3000`）。AuthTest モックログイン・`/api/v1/auth/me` 非モック。`verify-capture-complete` **156 PNG**（52 ルート × 3 言語 + `auth_login` / `login` ログアウト storageState）。**54 passed**（約 1.5h）。
- **前提**: development SQLite・実データ。CSS トークンは `npm run audit:css-tokens`（var 外 0 件）。テンプレート/HTML・API 返却キーは PNG レビューで確認。

## サマリ表

| # | pattern | ja | en | in | 結果 | i18n | 指摘 |
|---|---------|----|----|-----|------|------|------|
| 1 | `(home)` | `home.ja.png` | `home.en.png` | `home.in.png` | OK | OK | なし |
| 2 | `**` | `not-found.ja.png` | `not-found.en.png` | `not-found.in.png` | OK | OK | なし |
| 3 | `about` | `about.ja.png` | `about.en.png` | `about.in.png` | OK | 要確認 | i18n: `pages.about.operator.contact` / `ads_notice` が生キー（3 言語） |
| 4 | `auth/login` | `auth_login.ja.png` | `auth_login.en.png` | `auth_login.in.png` | OK | OK | なし（ログアウト storageState で撮影済み） |
| 5 | `contact` | `contact.ja.png` | `contact.en.png` | `contact.in.png` | OK | OK | なし |
| 6 | `entry-schedule` | `entry-schedule.ja.png` | `entry-schedule.en.png` | `entry-schedule.in.png` | OK | OK | 農場未選択の空状態は意図どおり |
| 7 | `entry-schedule/crop/:cropId` | `entry-schedule_crop_cropId.ja.png` | `entry-schedule_crop_cropId.en.png` | `entry-schedule_crop_cropId.in.png` | OK | 要確認 | i18n: `api.entry_schedule.*` 複数キー露出（disclaimer / reason / label 等） |
| 8 | `login` | `login.ja.png` | `login.en.png` | `login.in.png` | OK | OK | なし |
| 9 | `privacy` | `privacy.ja.png` | `privacy.en.png` | `privacy.in.png` | OK | 注意 | i18n: §8 `{{contact_link}}` 未展開（ja/en 確認） |
| 10 | `public-plans/new` | `public-plans_new.ja.png` | `public-plans_new.en.png` | `public-plans_new.in.png` | OK | OK | なし |
| 11 | `public-plans/optimizing` | `public-plans_optimizing.ja.png` | `public-plans_optimizing.en.png` | `public-plans_optimizing.in.png` | 注意 | 注意 | layout: 失敗 UI と「最適化中」バッジ併存。i18n: `models.cultivation_plan.phases.completed` 生キー |
| 12 | `public-plans/results` | `public-plans_results.ja.png` | `public-plans_results.en.png` | `public-plans_results.in.png` | OK | 注意 | i18n: 気候インサイト欄が ja で英語固定文（`Select a cultivation bar…`） |
| 13 | `public-plans/select-crop` | `public-plans_select-crop.ja.png` | `public-plans_select-crop.en.png` | `public-plans_select-crop.in.png` | OK | OK | `/select-crop`→`/new` リダイレクトは仕様 |
| 14 | `public-plans/select-farm-size` | `public-plans_select-farm-size.ja.png` | `public-plans_select-farm-size.en.png` | `public-plans_select-farm-size.in.png` | OK | OK | なし |
| 15 | `terms` | `terms.ja.png` | `terms.en.png` | `terms.in.png` | OK | 注意 | i18n: 第10条 `{{contact_link}}` 未展開（privacy と同型） |
| 16 | `agricultural_tasks` | `agricultural_tasks.ja.png` | `agricultural_tasks.en.png` | `agricultural_tasks.in.png` | OK | OK | マスタ混在・skill 英語表記はデータ由来 |
| 17 | `agricultural_tasks/:id` | `agricultural_tasks_id.ja.png` | `agricultural_tasks_id.en.png` | `agricultural_tasks_id.in.png` | OK | OK | なし |
| 18 | `agricultural_tasks/:id/edit` | `agricultural_tasks_id_edit.ja.png` | `agricultural_tasks_id_edit.en.png` | `agricultural_tasks_id_edit.in.png` | OK | 注意 | i18n: en で「地域」ラベルのみ日本語 |
| 19 | `agricultural_tasks/new` | `agricultural_tasks_new.ja.png` | `agricultural_tasks_new.en.png` | `agricultural_tasks_new.in.png` | OK | 注意 | 同上（en） |
| 20 | `api-keys` | `api-keys.ja.png` | `api-keys.en.png` | `api-keys.in.png` | OK | OK | なし |
| 21 | `crops` | `crops.ja.png` | `crops.en.png` | `crops.in.png` | OK | OK | 参照作物名の多言語混在はマスタ由来 |
| 22 | `crops/:id` | `crops_id.ja.png` | `crops_id.en.png` | `crops_id.in.png` | OK | 注意 | i18n: en で行ラベルが日本語のまま等 |
| 23 | `crops/:id/edit` | `crops_id_edit.ja.png` | `crops_id_edit.en.png` | `crops_id_edit.in.png` | OK | 注意 | i18n: en でフォームラベル日本語混在 |
| 24 | `crops/new` | `crops_new.ja.png` | `crops_new.en.png` | `crops_new.in.png` | OK | 注意 | 同上（en） |
| 25 | `dashboard` | `dashboard.ja.png` | `dashboard.en.png` | `dashboard.in.png` | OK | OK | ホーム相当 |
| 26 | `farms` | `farms.ja.png` | `farms.en.png` | `farms.in.png` | OK | OK | 長大リストだがグリッド破綻なし |
| 27 | `farms/:id` | `farms_id.ja.png` | `farms_id.en.png` | `farms_id.in.png` | OK | OK | なし |
| 28 | `farms/:id/edit` | `farms_id_edit.ja.png` | `farms_id_edit.en.png` | `farms_id_edit.in.png` | OK | OK | なし |
| 29 | `farms/new` | `farms_new.ja.png` | `farms_new.en.png` | `farms_new.in.png` | OK | OK | なし |
| 30 | `fertilizes` | `fertilizes.ja.png` | `fertilizes.en.png` | `fertilizes.in.png` | OK | OK | なし |
| 31 | `fertilizes/:id` | `fertilizes_id.ja.png` | `fertilizes_id.en.png` | `fertilizes_id.in.png` | OK | OK | なし |
| 32 | `fertilizes/:id/edit` | `fertilizes_id_edit.ja.png` | `fertilizes_id_edit.en.png` | `fertilizes_id_edit.in.png` | OK | 注意 | i18n: en で「地域」ラベルのみ日本語 |
| 33 | `fertilizes/new` | `fertilizes_new.ja.png` | `fertilizes_new.en.png` | `fertilizes_new.in.png` | OK | 注意 | 同上（en） |
| 34 | `interaction_rules` | `interaction_rules.ja.png` | `interaction_rules.en.png` | `interaction_rules.in.png` | OK | 注意 | i18n: カード内 `continuous_cultivation` が生コード風 |
| 35 | `interaction_rules/:id` | `interaction_rules_id.ja.png` | `interaction_rules_id.en.png` | `interaction_rules_id.in.png` | OK | 注意 | i18n: `interaction_rules.show.is_directional` 等の生キー |
| 36 | `interaction_rules/:id/edit` | `interaction_rules_id_edit.ja.png` | `interaction_rules_id_edit.en.png` | `interaction_rules_id_edit.in.png` | OK | 注意 | layout: なし。i18n: ルール種類が `continuous_cultivation` コード表示 |
| 37 | `interaction_rules/new` | `interaction_rules_new.ja.png` | `interaction_rules_new.en.png` | `interaction_rules_new.in.png` | OK | 注意 | #36 と同系統想定 |
| 38 | `pesticides` | `pesticides.ja.png` | `pesticides.en.png` | `pesticides.in.png` | OK | OK | なし |
| 39 | `pesticides/:id` | `pesticides_id.ja.png` | `pesticides_id.en.png` | `pesticides_id.in.png` | OK | 注意 | i18n: 関連名が「作物 (ID:…)」等の汎用表示 |
| 40 | `pesticides/:id/edit` | `pesticides_id_edit.ja.png` | `pesticides_id_edit.en.png` | `pesticides_id_edit.in.png` | OK | OK | 他マスタ edit 同型・目視で重大な破綻なし |
| 41 | `pesticides/new` | `pesticides_new.ja.png` | `pesticides_new.en.png` | `pesticides_new.in.png` | OK | OK | なし |
| 42 | `pests` | `pests.ja.png` | `pests.en.png` | `pests.in.png` | OK | OK | 多言語マスタ混在はデータ由来 |
| 43 | `pests/:id` | `pests_id.ja.png` | `pests_id.en.png` | `pests_id.in.png` | OK | OK | なし |
| 44 | `pests/:id/edit` | `pests_id_edit.ja.png` | `pests_id_edit.en.png` | `pests_id_edit.in.png` | OK | OK | なし |
| 45 | `pests/new` | `pests_new.ja.png` | `pests_new.en.png` | `pests_new.in.png` | OK | OK | なし |
| 46 | `plans` | `plans.ja.png` | `plans.en.png` | `plans.in.png` | OK | OK | なし |
| 47 | `plans/:id` | `plans_id.ja.png` | `plans_id.en.png` | `plans_id.in.png` | OK | OK | ガント表示（実 ID 解決済みキャプチャ） |
| 48 | `plans/:id/optimizing` | `plans_id_optimizing.ja.png` | `plans_id_optimizing.en.png` | `plans_id_optimizing.in.png` | OK | OK | 進捗 100% 表示（ステータス文言は要 UX 確認） |
| 49 | `plans/:id/task_schedule` | `plans_id_task_schedule.ja.png` | `plans_id_task_schedule.en.png` | `plans_id_task_schedule.in.png` | OK | 要確認 | i18n: `plans.task_schedule.*` が全面生キー |
| 50 | `plans/new` | `plans_new.ja.png` | `plans_new.en.png` | `plans_new.in.png` | OK | OK | 農場選択ウィザード正常 |
| 51 | `plans/select-crop` | `plans_select-crop.ja.png` | `plans_select-crop.en.png` | `plans_select-crop.in.png` | OK | 要確認 | i18n: `plans.select_crop.*` 多数生キー |
| 52 | `weather` | `weather.ja.png` | `weather.en.png` | `weather.in.png` | 注意 | OK | layout: 気温チャート領域が空（データ/API 要因の可能性） |

## 集計（レイアウト・読み込み）

| 結果 | 件数 |
|------|------|
| OK | 50 |
| 注意 | 2 |
| 要確認 | 0 |

## 集計（i18n）

| i18n | 件数 |
|------|------|
| OK | 35 |
| 注意 | 14 |
| 要確認 | 3 |

## 指摘の詳細

### P0 — 画面に生キーがそのまま出る

1. **#3 about** — 運営者情報の `pages.about.operator.contact` / `ads_notice`（翻訳 JSON 未定義または `translate` パラメータ未解決）。
2. **#7 entry-schedule/crop/:cropId** — API 応答キー `api.entry_schedule.*` がフロントでラベル化されていない。
3. **#49 plans/:id/task_schedule** — `plans.task_schedule.title` 等、画面全体がキー表示。
4. **#51 plans/select-crop** — 説明・農場情報・ボタンが `plans.select_crop.*` のまま。

### P1 — 補間・固定文言・失敗 UI

5. **#9 privacy / #15 terms** — `{{contact_link}}` が字面表示（`translate` の param 名不一致の可能性）。
6. **#11 public-plans/optimizing** — 失敗メッセージに `models.cultivation_plan.phases.completed`、ヘッダは「最適化中」のまま。
7. **#12 public-plans/results** — 気候インサイトのプレースホルダがコンポーネント内英語ハードコード。
8. **#18–19, #32–33** — en 画面で「地域」ラベルのみ日本語。
9. **#34–37 interaction_rules** — ルール種類コード・show 用キーの未翻訳。

### P2 — データ・機能（デザイン検証の範囲外に近いが注記）

10. **#52 weather** — 見出し・ナビは各言語 OK。チャート本体は空。
11. **マスタ一覧** — 作物名等の多言語混在は参照データ由来で UI 破綻ではない。

## 総評

**CSS**: `audit:css-tokens` は var 外の直書き色 **0 件**（フォールバック内 3 件のみ）。**キャプチャ**: 全 52 ルート × 3 言語 + ログイン 2 ルートで verify 通過。

**ビジュアル**: ヘッダ・フッター・マスタ一覧カードのレイアウトは概ね一貫。重大なはみ出し・読み込みスピナー滞留は今回の PNG では未検出。

**i18n**: **API キー・未登録 translate キー・`{{…}}` テンプレート・TS 内英語**は PNG で多数検出。優先修正は **about 運営者・entry-schedule 詳細・plans/task_schedule・plans/select-crop** の 4 画面。続いて **privacy/terms の contact_link**、**public-plans** の失敗文言と results プレースホルダ。

成果物: `frontend/e2e/agent-review/visual-review-results.md`（本ファイル）。PNG は `frontend/e2e/agent-review/out/`（gitignore）。
