# Agent ビジュアルレビュー結果

## メタ

- **レビュー日**: 2026-06-17（UTC）
- **対象**: `route-to-png.md` **#1–48**（全ルート・**ja / en / in** 各 1 枚）
- **キャプチャ**: `npm run e2e:capture-for-agent`（`E2E_CAPTURE_DEV_SESSION=1` `E2E_STRANGLER=1`）。AuthTest モックログイン・`/api/v1/auth/me` 非モック。`verify-capture-complete` **144 PNG**（48 ルート × 3 言語）。キャプチャ日: **2026-06-17**（全 144 枚更新済み・`capture-locale-playwright` localStorage 固定 fix 適用後）。
- **前提**: development SQLite・実データ。CSS トークンは `npm run audit:css-tokens`（var 外 7 件・主に gantt-chart）。本レビューでは CSS 列挙は行わない。

## P0/P1 修正サマリ（#14–#22 対応後）

| 旧 P0/P1 指摘 | Issue | ja | en | in | 判定 |
|---------------|-------|----|----|-----|------|
| about 運営者生キー | #16 | OK | OK | 要確認 | **大部分解消**（ja/en は自然文・リンク） |
| entry-schedule 詳細 API キー | #15 | OK | 注意 | 注意 | **ja のみ解消**（en/in は `api.entry_schedule.*` 残存） |
| plans/task_schedule 全面キー | #14 | 要確認 | 要確認 | 要確認 | **未解消**（3 言語とも生キー） |
| privacy/terms `{{contact_link}}` | #18 | OK | 注意 | 注意 | **privacy ja のみ解消** / terms は 3 言語残存 |
| public-plans/optimizing 失敗 UI・生キー | #19 | OK | 注意 | 注意 | **ja 解消**（作成失敗 UI）/ en/in は生キー・バッジ併存 |
| public-plans/results 英語プレースホルダ | #20 | OK | OK | OK | **解消** |
| interaction_rules コード・生キー | #17 | 注意 | 注意 | 注意 | **未解消** |
| マスタ en「地域」ラベル | #21 | — | 注意 | — | **agricultural_tasks のみ解消** / fertilizes・interaction_rules は残存 |
| crops en フォームラベル日本語 | #21 | — | 注意 | — | **未解消** |
| pesticides/:id 汎用 ID 表示 | #22 | 注意 | 注意 | 注意 | **未解消**（`Crop (ID: …)` 等） |

**i18n 要確認**: **1 件**（#47 plans/:id/task_schedule）。残り P1 は **注意** として継続（新 Issue 化候補）。

## サマリ表

| # | pattern | ja | en | in | 結果 | i18n | 指摘 |
|---|---------|----|----|-----|------|------|------|
| 1 | `(home)` | `home.ja.png` | `home.en.png` | `home.in.png` | OK | OK | なし |
| 2 | `**` | `not-found.ja.png` | `not-found.en.png` | `not-found.in.png` | OK | OK | なし |
| 3 | `about` | `about.ja.png` | `about.en.png` | `about.in.png` | OK | OK | なし（#16 修正反映・運営者情報は自然文） |
| 4 | `contact` | `contact.ja.png` | `contact.en.png` | `contact.in.png` | OK | OK | なし |
| 5 | `entry-schedule` | `entry-schedule.ja.png` | `entry-schedule.en.png` | `entry-schedule.in.png` | OK | OK | 農場未選択の空状態は意図どおり |
| 6 | `entry-schedule/crop/:cropId` | `entry-schedule_crop_cropId.ja.png` | `entry-schedule_crop_cropId.en.png` | `entry-schedule_crop_cropId.in.png` | OK | 注意 | i18n: ja は disclaimer・理由・ラベル日本語化済み。en/in は `api.entry_schedule.*` 生キー残存 |
| 7 | `login` | `login.ja.png` | `login.en.png` | `login.in.png` | OK | 注意 | i18n: in で subtitle・dev 注記が英語残留。layout: 開発用モックログインは development 想定 |
| 8 | `privacy` | `privacy.ja.png` | `privacy.en.png` | `privacy.in.png` | OK | 注意 | i18n: ja §8 はお問い合わせリンク展開済み。en/in は `{{contact_link}}` 字面残存 |
| 9 | `public-plans/new` | `public-plans_new.ja.png` | `public-plans_new.en.png` | `public-plans_new.in.png` | OK | OK | なし |
| 10 | `public-plans/optimizing` | `public-plans_optimizing.ja.png` | `public-plans_optimizing.en.png` | `public-plans_optimizing.in.png` | OK | 注意 | i18n: ja は「作成失敗」＋日本語メッセージ。en/in は `models.cultivation_plan.phases.completed` 生キー＋最適化中バッジ併存 |
| 11 | `public-plans/results` | `public-plans_results.ja.png` | `public-plans_results.en.png` | `public-plans_results.in.png` | OK | OK | なし（#20 修正・気候プレースホルダは各言語化） |
| 12 | `public-plans/select-crop` | `public-plans_select-crop.ja.png` | `public-plans_select-crop.en.png` | `public-plans_select-crop.in.png` | OK | OK | `/select-crop`→`/new` リダイレクトは仕様 |
| 13 | `public-plans/select-farm-size` | `public-plans_select-farm-size.ja.png` | `public-plans_select-farm-size.en.png` | `public-plans_select-farm-size.in.png` | OK | OK | `/new` と同型の農場選択 UI |
| 14 | `terms` | `terms.ja.png` | `terms.en.png` | `terms.in.png` | OK | 注意 | i18n: 第10条 `{{contact_link}}` 未展開（3 言語・privacy.ja との不整合） |
| 15 | `agricultural_tasks` | `agricultural_tasks.ja.png` | `agricultural_tasks.en.png` | `agricultural_tasks.in.png` | OK | OK | マスタ混在・skill 表記はデータ由来 |
| 16 | `agricultural_tasks/:id` | `agricultural_tasks_id.ja.png` | `agricultural_tasks_id.en.png` | `agricultural_tasks_id.in.png` | OK | OK | なし |
| 17 | `agricultural_tasks/:id/edit` | `agricultural_tasks_id_edit.ja.png` | `agricultural_tasks_id_edit.en.png` | `agricultural_tasks_id_edit.in.png` | OK | OK | なし（#21 修正・en「Region」） |
| 18 | `agricultural_tasks/new` | `agricultural_tasks_new.ja.png` | `agricultural_tasks_new.en.png` | `agricultural_tasks_new.in.png` | OK | OK | 同上 |
| 19 | `crops` | `crops.ja.png` | `crops.en.png` | `crops.in.png` | OK | OK | 参照作物名の多言語混在はマスタ由来 |
| 20 | `crops/:id` | `crops_id.ja.png` | `crops_id.en.png` | `crops_id.in.png` | OK | 注意 | i18n: en で行ラベル（名前・品種等）が日本語のまま |
| 21 | `crops/:id/edit` | `crops_id_edit.ja.png` | `crops_id_edit.en.png` | `crops_id_edit.in.png` | OK | 注意 | i18n: en フォームラベル日本語混在 |
| 22 | `crops/new` | `crops_new.ja.png` | `crops_new.en.png` | `crops_new.in.png` | OK | 注意 | 同上（en） |
| 23 | `dashboard` | `dashboard.ja.png` | `dashboard.en.png` | `dashboard.in.png` | OK | OK | ホーム相当 |
| 24 | `farms` | `farms.ja.png` | `farms.en.png` | `farms.in.png` | OK | OK | 長大リストだがグリッド破綻なし |
| 25 | `farms/:id` | `farms_id.ja.png` | `farms_id.en.png` | `farms_id.in.png` | OK | OK | なし |
| 26 | `farms/:id/edit` | `farms_id_edit.ja.png` | `farms_id_edit.en.png` | `farms_id_edit.in.png` | OK | OK | なし |
| 27 | `farms/new` | `farms_new.ja.png` | `farms_new.en.png` | `farms_new.in.png` | OK | OK | なし |
| 28 | `fertilizes` | `fertilizes.ja.png` | `fertilizes.en.png` | `fertilizes.in.png` | OK | OK | なし |
| 29 | `fertilizes/:id` | `fertilizes_id.ja.png` | `fertilizes_id.en.png` | `fertilizes_id.in.png` | OK | OK | なし |
| 30 | `fertilizes/:id/edit` | `fertilizes_id_edit.ja.png` | `fertilizes_id_edit.en.png` | `fertilizes_id_edit.in.png` | OK | 注意 | i18n: en で「地域」ラベルのみ日本語 |
| 31 | `fertilizes/new` | `fertilizes_new.ja.png` | `fertilizes_new.en.png` | `fertilizes_new.in.png` | OK | 注意 | 同上（en） |
| 32 | `interaction_rules` | `interaction_rules.ja.png` | `interaction_rules.en.png` | `interaction_rules.in.png` | OK | 注意 | i18n: カード内 `continuous_cultivation` 等の生コード |
| 33 | `interaction_rules/:id` | `interaction_rules_id.ja.png` | `interaction_rules_id.en.png` | `interaction_rules_id.in.png` | OK | 注意 | i18n: `interaction_rules.show.is_directional` 生キー |
| 34 | `interaction_rules/:id/edit` | `interaction_rules_id_edit.ja.png` | `interaction_rules_id_edit.en.png` | `interaction_rules_id_edit.in.png` | OK | 注意 | i18n: Rule Type コード表示＋ en「地域」ラベル日本語 |
| 35 | `interaction_rules/new` | `interaction_rules_new.ja.png` | `interaction_rules_new.en.png` | `interaction_rules_new.in.png` | OK | 注意 | #34 同系統 |
| 36 | `pesticides` | `pesticides.ja.png` | `pesticides.en.png` | `pesticides.in.png` | OK | OK | なし |
| 37 | `pesticides/:id` | `pesticides_id.ja.png` | `pesticides_id.en.png` | `pesticides_id.in.png` | OK | 注意 | i18n: 関連名が「Crop (ID: …)」等の汎用表示（#22 未解消） |
| 38 | `pesticides/:id/edit` | `pesticides_id_edit.ja.png` | `pesticides_id_edit.en.png` | `pesticides_id_edit.in.png` | OK | OK | 他マスタ edit 同型 |
| 39 | `pesticides/new` | `pesticides_new.ja.png` | `pesticides_new.en.png` | `pesticides_new.in.png` | OK | OK | なし |
| 40 | `pests` | `pests.ja.png` | `pests.en.png` | `pests.in.png` | OK | OK | 多言語マスタ混在はデータ由来 |
| 41 | `pests/:id` | `pests_id.ja.png` | `pests_id.en.png` | `pests_id.in.png` | OK | OK | なし |
| 42 | `pests/:id/edit` | `pests_id_edit.ja.png` | `pests_id_edit.en.png` | `pests_id_edit.in.png` | OK | OK | なし |
| 43 | `pests/new` | `pests_new.ja.png` | `pests_new.en.png` | `pests_new.in.png` | OK | OK | なし |
| 44 | `plans` | `plans.ja.png` | `plans.en.png` | `plans.in.png` | OK | OK | なし |
| 45 | `plans/:id` | `plans_id.ja.png` | `plans_id.en.png` | `plans_id.in.png` | OK | OK | ガント表示（実 ID 解決済みキャプチャ） |
| 46 | `plans/:id/optimizing` | `plans_id_optimizing.ja.png` | `plans_id_optimizing.en.png` | `plans_id_optimizing.in.png` | 注意 | OK | layout: 進捗 100% なのに見出しが「最適化中 / Optimizing」のまま（3 言語） |
| 47 | `plans/:id/task_schedule` | `plans_id_task_schedule.ja.png` | `plans_id_task_schedule.en.png` | `plans_id_task_schedule.in.png` | OK | 要確認 | i18n: `plans.task_schedule.*` が全面生キー（3 言語・#14 未解消） |
| 48 | `plans/new` | `plans_new.ja.png` | `plans_new.en.png` | `plans_new.in.png` | OK | OK | 農場選択ウィザード正常 |

## 集計（レイアウト・読み込み）

| 結果 | 件数 |
|------|------|
| OK | 47 |
| 注意 | 1 |
| 要確認 | 0 |

## 集計（i18n）

| i18n | 件数 |
|------|------|
| OK | 33 |
| 注意 | 14 |
| 要確認 | 1 |

## 指摘の詳細

### 要確認（P0 相当・新 Issue 推奨）

1. **#47 plans/:id/task_schedule** — `plans.task_schedule.back_to_plan` / `title` / `timeline_empty` が 3 言語とも生キー（#14 対応未反映）。

### 注意 — i18n 残件（P1 相当）

2. **#6 entry-schedule/crop/:cropId** — en/in で `api.entry_schedule.*` 生キー（ja は #15 修正済み）。
3. **#8 privacy / #14 terms** — en/in privacy と 3 言語 terms で `{{contact_link}}` 字面（ja privacy のみ #18 修正済み）。
4. **#10 public-plans/optimizing** — en/in で `models.cultivation_plan.phases.completed` 生キー＋失敗 UI 併存（ja は #19 修正済み）。
5. **#20–22 crops** — en 詳細・編集でフォームラベル日本語混在（#21 部分対応）。
6. **#30–31 fertilizes / #34–35 interaction_rules** — en「地域」ラベル（agricultural_tasks は #21 で解消）。
7. **#32–35 interaction_rules** — ルール種類コード・show 用キー（#17 未解消）。
8. **#37 pesticides/:id** — 関連名の汎用 ID 表示（#22 未解消）。

### 注意 — layout（P2 UX）

9. **#46 plans/:id/optimizing** — 進捗 100% 表示だが文言は「最適化中」。完了遷移・CTA の UX 要確認。

## 総評

**CSS**: `audit:css-tokens` は var 外の直書き色 **7 件**（主に `gantt-chart.component.css`）。列挙の正は同コマンド。

**キャプチャ**: 48 ルート × 3 言語で `verify-capture-complete` 通過（144 PNG）。2026-06-17 再キャプチャ（`capture-locale-playwright` に localStorage 固定を追加し ja/en/in 切替を復旧）。

**ビジュアル**: ヘッダ・フッター・マスタ一覧のレイアウトは一貫。読み込みスピナー滞留は未検出。

**i18n（#14–#22 後）**: ja 中心の修正が進み **about / entry-schedule(ja) / privacy(ja) / public-plans(ja) / results / agricultural_tasks en** は改善。**未解消の中心**は **#47 task_schedule（要確認 1 件）**、**en/in カタログ不足**（entry-schedule・optimizing・privacy/terms）、**interaction_rules / crops en / pesticides 関連名**。

成果物: `frontend/e2e/agent-review/visual-review-results.md`（本ファイル）。PNG は `frontend/e2e/agent-review/out/`（gitignore）。
