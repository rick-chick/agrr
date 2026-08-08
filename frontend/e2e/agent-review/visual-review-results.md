# Agent ビジュアルレビュー結果

## メタ

- **レビュー日**: 2026-08-08（UTC）
- **対象**: `route-to-png.md` **#1–57**（全ルート・**ja / en / in** 各 1 枚）
- **キャプチャ**: `npm run e2e:capture-for-agent`（`E2E_CAPTURE_DEV_SESSION=1` `E2E_STRANGLER=1` `AGRR_DEV_API_URL=http://127.0.0.1:8080`）。AuthTest モックログイン・`/api/v1/auth/me` 非モック。**171 PNG**（57 ルート × 3 言語）。キャプチャ日: 2026-08-08。
- **前提**: development SQLite・参照データ + E2E Baseline Plan。CSS トークンは `npm run audit:css-tokens:enforce` exit 0（var 外 0 件）。本レビューでは CSS 列挙は行わない。
- **captureRunId**: 未設定

## サマリ表

| # | pattern | ja | en | in | 結果 | i18n | 指摘 |
|---|---------|----|----|-----|------|------|------|
| 1 | `(home)` | `home.ja.png` | `home.en.png` | `home.in.png` | OK | OK | なし |
| 2 | `**` | `not-found.ja.png` | `not-found.en.png` | `not-found.in.png` | OK | OK | なし |
| 3 | `about` | `about.ja.png` | `about.en.png` | `about.in.png` | OK | OK | なし |
| 4 | `contact` | `contact.ja.png` | `contact.en.png` | `contact.in.png` | OK | OK | なし |
| 5 | `en` | `en.ja.png` | `en.en.png` | `en.in.png` | OK | OK | layout: `/en` hreflang ミラーランディング（#563）。3 言語 UI 整合 |
| 6 | `entry-schedule` | `entry-schedule.ja.png` | `entry-schedule.en.png` | `entry-schedule.in.png` | OK | OK | **#648 再キャプチャ**: 3 言語 UI OK。in 農場名「Punjab」は地名（マスタデータ） |
| 7 | `entry-schedule/crop/:cropId` | `entry-schedule_crop_cropId.ja.png` | `entry-schedule_crop_cropId.en.png` | `entry-schedule_crop_cropId.in.png` | OK | OK | **#648 再キャプチャ**: #632/PR #649 後。ja 二重番号解消。en/in UI ラベル各言語（作物名・段階名は API 由来） |
| 8 | `login` | `login.ja.png` | `login.en.png` | `login.in.png` | OK | OK | なし |
| 9 | `privacy` | `privacy.ja.png` | `privacy.en.png` | `privacy.in.png` | OK | OK | なし |
| 10 | `public-plans/new` | `public-plans_new.ja.png` | `public-plans_new.en.png` | `public-plans_new.in.png` | OK | 要確認 | i18n: ja 農場名カードが文字化け（mojibake）。in カードラベル「Punjab」が英字 |
| 11 | `public-plans/optimizing` | `public-plans_optimizing.ja.png` | `public-plans_optimizing.en.png` | `public-plans_optimizing.in.png` | 注意 | OK | layout: 最適化進行ではなく気象データ取得失敗のエラー画面 |
| 12 | `public-plans/results` | `public-plans_results.ja.png` | `public-plans_results.en.png` | `public-plans_results.in.png` | 要確認 | 要確認 | layout: 同一 HTTP 404 エラーが二重表示・本文未描画。i18n: ja/in でも生の英語 HTTP エラー文字列 |
| 13 | `public-plans/select-crop` | `public-plans_select-crop.ja.png` | `public-plans_select-crop.en.png` | `public-plans_select-crop.in.png` | OK | OK | layout: step2 作物選択 UI（2026-08-07 再キャプチャ・`route-manifest-visual` step2 assertion GREEN）。i18n: ja 農場名「北海道」表示 |
| 14 | `public-plans/select-farm-size` | `public-plans_select-farm-size.ja.png` | `public-plans_select-farm-size.en.png` | `public-plans_select-farm-size.in.png` | OK | 要確認 | i18n: ja 農場名カードが文字化け。in カードラベル「Punjab」が英字 |
| 15 | `terms` | `terms.ja.png` | `terms.en.png` | `terms.in.png` | OK | OK | なし |
| 16 | `account` | `account.ja.png` | `account.en.png` | `account.in.png` | OK | OK | layout: アカウント設定（#603）。3 言語 UI OK |
| 17 | `agricultural_tasks` | `agricultural_tasks.ja.png` | `agricultural_tasks.en.png` | `agricultural_tasks.in.png` | OK | OK | なし |
| 18 | `agricultural_tasks/:id` | `agricultural_tasks_id.ja.png` | `agricultural_tasks_id.en.png` | `agricultural_tasks_id.in.png` | 注意 | 要確認 | i18n: `agricultural_tasks.show.hours_suffix` 生キー（3 言語） |
| 19 | `agricultural_tasks/:id/edit` | `agricultural_tasks_id_edit.ja.png` | `agricultural_tasks_id_edit.en.png` | `agricultural_tasks_id_edit.in.png` | OK | OK | なし |
| 20 | `agricultural_tasks/new` | `agricultural_tasks_new.ja.png` | `agricultural_tasks_new.en.png` | `agricultural_tasks_new.in.png` | OK | OK | なし |
| 21 | `api-keys` | `api-keys.ja.png` | `api-keys.en.png` | `api-keys.in.png` | OK | OK | layout: API キー一覧・作成導線。3 言語 UI OK |
| 22 | `crops` | `crops.ja.png` | `crops.en.png` | `crops.in.png` | OK | 注意 | i18n: en で品種名と「Reference Crop」がスペースなしで連結 |
| 23 | `crops/:id` | `crops_id.ja.png` | `crops_id.en.png` | `crops_id.in.png` | OK | OK | layout: 3 カード縦積み・空状態は明瞭。i18n: 作業予定セクションの用語統一・作成日/更新日のロケール表示（2026-07-03 修正） |
| 24 | `crops/:id/edit` | `crops_id_edit.ja.png` | `crops_id_edit.en.png` | `crops_id_edit.in.png` | OK | OK | なし |
| 25 | `crops/:id/setup_proposal` | `crops_id_setup_proposal.ja.png` | `crops_id_setup_proposal.en.png` | `crops_id_setup_proposal.in.png` | OK | OK | layout: JSON インポート UI・プレビュー導線。3 言語 UI OK |
| 26 | `crops/:id/stages` | `crops_id_stages.ja.png` | `crops_id_stages.en.png` | `crops_id_stages.in.png` | OK | 注意 | i18n: 成長段階名・要件は英語マスタデータ（UI ラベルは各言語） |
| 27 | `crops/:id/stages/:stageId/edit` | `crops_id_stages_stageId_edit.ja.png` | `crops_id_stages_stageId_edit.en.png` | `crops_id_stages_stageId_edit.in.png` | OK | 注意 | i18n: 成長段階名・要件は英語マスタデータ（UI ラベルは各言語） |
| 28 | `crops/:id/task_schedule_blueprints` | `crops_id_task_schedule_blueprints.ja.png` | `crops_id_task_schedule_blueprints.en.png` | `crops_id_task_schedule_blueprints.in.png` | OK | OK | layout: GDD 軸・テンプレート一覧。3 言語 UI OK |
| 29 | `crops/new` | `crops_new.ja.png` | `crops_new.en.png` | `crops_new.in.png` | OK | OK | なし |
| 30 | `farms` | `farms.ja.png` | `farms.en.png` | `farms.in.png` | OK | OK | なし |
| 31 | `farms/:id` | `farms_id.ja.png` | `farms_id.en.png` | `farms_id.in.png` | OK | 注意 | i18n: 地域がコード `jp` のまま（ja/en/in 共通） |
| 32 | `farms/:id/edit` | `farms_id_edit.ja.png` | `farms_id_edit.en.png` | `farms_id_edit.in.png` | OK | OK | なし |
| 33 | `farms/new` | `farms_new.ja.png` | `farms_new.en.png` | `farms_new.in.png` | OK | OK | なし |
| 34 | `fertilizes` | `fertilizes.ja.png` | `fertilizes.en.png` | `fertilizes.in.png` | OK | OK | なし |
| 35 | `fertilizes/:id` | `fertilizes_id.ja.png` | `fertilizes_id.en.png` | `fertilizes_id.in.png` | OK | OK | **#658 再キャプチャ**: E2E Baseline 正常表示。エラー回復 UI（MasterLoadErrorPanel + i18n）は component/presenter spec で検証済み |
| 36 | `fertilizes/:id/edit` | `fertilizes_id_edit.ja.png` | `fertilizes_id_edit.en.png` | `fertilizes_id_edit.in.png` | OK | OK | **#658 再キャプチャ**: 編集フォーム正常表示。`title_default` 生キー解消（PR #659） |
| 37 | `fertilizes/new` | `fertilizes_new.ja.png` | `fertilizes_new.en.png` | `fertilizes_new.in.png` | OK | OK | なし |
| 38 | `interaction_rules` | `interaction_rules.ja.png` | `interaction_rules.en.png` | `interaction_rules.in.png` | OK | OK | なし |
| 39 | `interaction_rules/:id` | `interaction_rules_id.ja.png` | `interaction_rules_id.en.png` | `interaction_rules_id.in.png` | OK | 要確認 | i18n: `interaction_rules.show.region` 生キー（3 言語） |
| 40 | `interaction_rules/:id/edit` | `interaction_rules_id_edit.ja.png` | `interaction_rules_id_edit.en.png` | `interaction_rules_id_edit.in.png` | OK | OK | なし |
| 41 | `interaction_rules/new` | `interaction_rules_new.ja.png` | `interaction_rules_new.en.png` | `interaction_rules_new.in.png` | OK | OK | なし |
| 42 | `pesticides` | `pesticides.ja.png` | `pesticides.en.png` | `pesticides.in.png` | OK | OK | なし |
| 43 | `pesticides/:id` | `pesticides_id.ja.png` | `pesticides_id.en.png` | `pesticides_id.in.png` | OK | OK | **#658 再キャプチャ**: E2E Baseline 正常表示。エラー回復 UI は component/presenter spec で検証済み |
| 44 | `pesticides/:id/edit` | `pesticides_id_edit.ja.png` | `pesticides_id_edit.en.png` | `pesticides_id_edit.in.png` | OK | OK | **#658 再キャプチャ**: 編集フォーム正常表示。`title_default` 生キー解消（PR #659） |
| 45 | `pesticides/new` | `pesticides_new.ja.png` | `pesticides_new.en.png` | `pesticides_new.in.png` | OK | OK | なし |
| 46 | `pests` | `pests.ja.png` | `pests.en.png` | `pests.in.png` | OK | OK | マスタ害虫名の多言語混在はデータ由来 |
| 47 | `pests/:id` | `pests_id.ja.png` | `pests_id.en.png` | `pests_id.in.png` | OK | 注意 | i18n: Region が `us` コード。説明・発生季節は英語データのまま |
| 48 | `pests/:id/edit` | `pests_id_edit.ja.png` | `pests_id_edit.en.png` | `pests_id_edit.in.png` | OK | 注意 | i18n: 説明・発生季節フィールドが ja/in でも英語 |
| 49 | `pests/new` | `pests_new.ja.png` | `pests_new.en.png` | `pests_new.in.png` | OK | OK | なし |
| 50 | `plans` | `plans.ja.png` | `plans.en.png` | `plans.in.png` | OK | OK | 計画名「E2E Baseline Plan」はテストデータ |
| 51 | `plans/:id` | `plans_id.ja.png` | `plans_id.en.png` | `plans_id.in.png` | OK | OK | **修正済** (#635/#660): en 圃場ラベルと縦線の重なり解消（2026-08-07 再キャプチャ） |
| 52 | `plans/:id/optimizing` | `plans_id_optimizing.ja.png` | `plans_id_optimizing.en.png` | `plans_id_optimizing.in.png` | OK | OK | **#640 再キャプチャ**: 見出し二重解消。失敗時「再読み込み」・`back_to_hub` 導線を 3 言語で確認。0% 待機説明は spec 確認 |
| 53 | `plans/:id/task_schedule` | `plans_id_task_schedule.ja.png` | `plans_id_task_schedule.en.png` | `plans_id_task_schedule.in.png` | OK | OK | layout: `back_to_hub` 導線・ナビ非 active は意図どおり。**修正済**: ステータス i18n・エラー再試行 |
| 54 | `plans/:id/work` | `plans_id_work.ja.png` | `plans_id_work.en.png` | `plans_id_work.in.png` | OK | OK | **修正済**: 記録ボタンをリスト下静的配置・エラー再試行。`back_to_hub`・ナビ active は OK |
| 55 | `plans/:id/work_records` | `plans_id_work_records.ja.png` | `plans_id_work_records.en.png` | `plans_id_work_records.in.png` | OK | OK | **修正済**: エラー再試行追加。`back_to_hub`・ナビ active は OK。**#234**: サムネイル横並び（案 A）確定・4:3 横長（履歴 4rem / シート 4.5rem 幅）。PNG 再キャプチャは写真付きデータ要 |
| 56 | `plans/new` | `plans_new.ja.png` | `plans_new.en.png` | `plans_new.in.png` | OK | 注意 | i18n: ja は農場のみ言及、en/in は「年と農場」— 見出し意味がずれる |
| 57 | `work` | `work.ja.png` | `work.en.png` | `work.in.png` | 注意 | OK | layout: 単一農場時は `plans/:id/work` へ自動リダイレクト（キャプチャはリダイレクト先）。ハブ UI は未検証 |

## 集計（レイアウト・読み込み）

| 結果 | 件数 |
|------|------|
| OK | 53 |
| 注意 | 3 |
| 要確認 | 1 |

## 集計（i18n）

| i18n | 件数 |
|------|------|
| OK | 45 |
| 注意 | 7 |
| 要確認 | 5 |

## 指摘の詳細

### #713 増分ルート（2026-08-08）

1. **#5 en** — layout: `/en` hreflang ミラーランディング（#563）。3 言語 UI 整合
1. **#16 account** — layout: アカウント設定（#603）。3 言語 UI OK
1. **#21 api-keys** — layout: API キー一覧・作成導線。3 言語 UI OK
1. **#25 crops/:id/setup_proposal** — layout: JSON インポート UI・プレビュー導線。3 言語 UI OK
1. **#26 crops/:id/stages** — i18n: 成長段階名・要件は英語マスタデータ（UI ラベルは各言語）
1. **#27 crops/:id/stages/:stageId/edit** — i18n: 成長段階名・要件は英語マスタデータ（UI ラベルは各言語）
1. **#28 crops/:id/task_schedule_blueprints** — layout: GDD 軸・テンプレート一覧。3 言語 UI OK
1. **#57 work** — layout: 単一農場時は `plans/:id/work` へ自動リダイレクト（キャプチャはリダイレクト先）。ハブ UI は未検証

### 前回レビューからの継続

1. **#5 en** — layout: `/en` hreflang ミラーランディング（#563）。3 言語 UI 整合
1. **#6 entry-schedule** — **#648 再キャプチャ**: 3 言語 UI OK。in 農場名「Punjab」は地名（マスタデータ）
1. **#7 entry-schedule/crop/:cropId** — **#648 再キャプチャ**: #632/PR #649 後。ja 二重番号解消。en/in UI ラベル各言語（作物名・段階名は API 由来）
1. **#10 public-plans/new** — i18n: ja 農場名カードが文字化け（mojibake）。in カードラベル「Punjab」が英字
1. **#11 public-plans/optimizing** — layout: 最適化進行ではなく気象データ取得失敗のエラー画面
1. **#12 public-plans/results** — layout: 同一 HTTP 404 エラーが二重表示・本文未描画。i18n: ja/in でも生の英語 HTTP エラー文字列
1. **#13 public-plans/select-crop** — layout: step2 作物選択 UI（2026-08-07 再キャプチャ・`route-manifest-visual` step2 assertion GREEN）。i18n: ja 農場名「北海道」表示
1. **#14 public-plans/select-farm-size** — i18n: ja 農場名カードが文字化け。in カードラベル「Punjab」が英字
1. **#16 account** — layout: アカウント設定（#603）。3 言語 UI OK
1. **#18 agricultural_tasks/:id** — i18n: `agricultural_tasks.show.hours_suffix` 生キー（3 言語）
1. **#21 api-keys** — layout: API キー一覧・作成導線。3 言語 UI OK
1. **#22 crops** — i18n: en で品種名と「Reference Crop」がスペースなしで連結
1. **#23 crops/:id** — layout: 3 カード縦積み・空状態は明瞭。i18n: 作業予定セクションの用語統一・作成日/更新日のロケール表示（2026-07-03 修正）
1. **#25 crops/:id/setup_proposal** — layout: JSON インポート UI・プレビュー導線。3 言語 UI OK
1. **#26 crops/:id/stages** — i18n: 成長段階名・要件は英語マスタデータ（UI ラベルは各言語）
1. **#27 crops/:id/stages/:stageId/edit** — i18n: 成長段階名・要件は英語マスタデータ（UI ラベルは各言語）
1. **#28 crops/:id/task_schedule_blueprints** — layout: GDD 軸・テンプレート一覧。3 言語 UI OK
1. **#31 farms/:id** — i18n: 地域がコード `jp` のまま（ja/en/in 共通）
1. **#35 fertilizes/:id** — **#658 再キャプチャ**: E2E Baseline 正常表示。エラー回復 UI（MasterLoadErrorPanel + i18n）は component/presenter spec で検証済み
1. **#36 fertilizes/:id/edit** — **#658 再キャプチャ**: 編集フォーム正常表示。`title_default` 生キー解消（PR #659）
1. **#39 interaction_rules/:id** — i18n: `interaction_rules.show.region` 生キー（3 言語）
1. **#43 pesticides/:id** — **#658 再キャプチャ**: E2E Baseline 正常表示。エラー回復 UI は component/presenter spec で検証済み
1. **#44 pesticides/:id/edit** — **#658 再キャプチャ**: 編集フォーム正常表示。`title_default` 生キー解消（PR #659）
1. **#46 pests** — マスタ害虫名の多言語混在はデータ由来
1. **#47 pests/:id** — i18n: Region が `us` コード。説明・発生季節は英語データのまま
1. **#48 pests/:id/edit** — i18n: 説明・発生季節フィールドが ja/in でも英語
1. **#50 plans** — 計画名「E2E Baseline Plan」はテストデータ
1. **#51 plans/:id** — **修正済** (#635/#660): en 圃場ラベルと縦線の重なり解消（2026-08-07 再キャプチャ）
1. **#52 plans/:id/optimizing** — **#640 再キャプチャ**: 見出し二重解消。失敗時「再読み込み」・`back_to_hub` 導線を 3 言語で確認。0% 待機説明は spec 確認
1. **#53 plans/:id/task_schedule** — layout: `back_to_hub` 導線・ナビ非 active は意図どおり。**修正済**: ステータス i18n・エラー再試行
1. **#54 plans/:id/work** — **修正済**: 記録ボタンをリスト下静的配置・エラー再試行。`back_to_hub`・ナビ active は OK
1. **#55 plans/:id/work_records** — **修正済**: エラー再試行追加。`back_to_hub`・ナビ active は OK。**#234**: サムネイル横並び（案 A）確定・4:3 横長（履歴 4rem / シート 4.5rem 幅）。PNG 再キャプチャは写真付きデータ要
1. **#56 plans/new** — i18n: ja は農場のみ言及、en/in は「年と農場」— 見出し意味がずれる
1. **#57 work** — layout: 単一農場時は `plans/:id/work` へ自動リダイレクト（キャプチャはリダイレクト先）。ハブ UI は未検証

## 総評

**CSS**: `audit:css-tokens:enforce` exit 0（var 外 0 件）。

**キャプチャ**: 2026-08-08 に manifest 全 **57 ルート × 3 言語 = 171 PNG** を `e2e:capture-for-agent` で取得。証拠鎖用 `captureRunId` は未設定（`npm run e2e:agent-review:stamp-review` 要）。

**ビジュアル**: #713 増分（`en`・`account`・`api-keys`・作物 setup/stages/blueprints・`work` リダイレクト）をレビュー済み。public-plans results の 404 二重表示・optimizing 気象失敗・`work` ハブ未検証が残課題。

**i18n**: 増分ルートは UI ラベル OK。成長段階は英語マスタデータ由来（`stages` 系は **注意**）。残件は生キー（hours_suffix・interaction_rules.show.region）、public-plans 農場名 mojibake、地域コード表示など。

成果物: `frontend/e2e/agent-review/visual-review-results.md`（本ファイル）。PNG は `frontend/e2e/agent-review/out/`（gitignore）。
