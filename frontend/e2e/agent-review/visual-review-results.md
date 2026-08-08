# Agent ビジュアルレビュー結果

## メタ

- **captureRunId**: `2026-08-08T06:43:15.096Z-35b481c`（agent-review-bundle.json と一致必須。PNG 根拠の有効期限）

- **レビュー日**: 2026-08-08（UTC）— **#713** manifest 全 57 ルート増分追従（未レビュー 7 pattern を本キャプチャでレビュー）
- **対象**: `route-to-png.md` **#1–57**（全ルート・**ja / en / in** 各 1 枚）
- **キャプチャ**: `npm run e2e:capture-for-agent`（`E2E_CAPTURE_DEV_SESSION=1` `E2E_STRANGLER=1` `AGRR_DEV_API_URL=http://127.0.0.1:8080`）。AuthTest モックログイン・`/api/v1/auth/me` 非モック。`verify-capture-complete` **171 PNG**（57 ルート × 3 言語）。キャプチャ日: 2026-08-08。
- **前提**: development SQLite・参照データ + E2E Baseline Plan。CSS トークンは `npm run audit:css-tokens:enforce` exit 0（var 外 0 件）。本レビューでは CSS 列挙は行わない。

## 追記メタ（#738 visual-review 残件の受け入れ確認）

- **レビュー日**: 2026-08-08（UTC）
- **対象**: `route-to-png.md` **#9, #13, #16, #28, #36, #53**（ja / en / in）
- **根拠キャプチャ**: 上記メタ `captureRunId` `2026-08-08T06:47:18.593Z-35b481c`（#713 全件キャプチャ）。本 run では Agent 環境に Docker / `lib/core/agrr` が無く PNG 再取得不可のため、**catalog spec + component spec**（183 tests GREEN）で受け入れ確認。
- **確認 spec**: `agricultural-task-detail.component.spec.ts`（hours_suffix 非露出）、`interaction-rule-detail.component.spec.ts`（show.region 非露出・region 値翻訳）、`farm-detail.component.spec.ts`（`farms.form.region_*` 表示）、`public-plan-create.component.spec.ts`（`localizePublicPlanReferenceFarmName`）、`plans-new-locale.catalog.spec.ts`（3 言語 subtitle 整合・年言及なし）、`masters-detail-region-locale.catalog.spec.ts` GREEN。
- **関連修正 issue**: #170, #171, #172, #577, #673（すべて CLOSED）

### マスタデータ言語スコープ（#738 記録）

| 層 | 例 | 解決経路 |
|----|-----|----------|
| **frontend UI ラベル** | `hours_suffix`, `show.region`, `region_select.*` | `assets/i18n` + catalog spec（本 issue で受け入れ確認済み） |
| **frontend 参照農場名** | public-plans カードの北海道等 | `localizePublicPlanReferenceFarmName` + `public_plans.reference_farms.*`（#172） |
| **frontend 地域コード→ラベル** | farms/:id の `jp` →「日本」等 | テンプレ `farms.form.region_*` + `masters-detail-region-locale.catalog.spec.ts`（#577, #673） |
| **API / DB マスタ本文** | 害虫説明・発生季節・作物ステージ名の英語混在 | **API またはデータ移行**で多言語化。frontend のみでは解決不可（#44–45, #24 等はデータ由来として残存） |
| **固有名詞（地名）** | in カード「Punjab」 | 参照農場の地理名。`reference_farms` カタログで UI 言語化可能だが英字地名自体は許容 |

## 追記メタ（作業テンプレート / blueprint UI）

- **レビュー日**: 2026-07-03（UTC）
- **対象**: `route-to-png.md` **#20** `crops/:id`（ja / en / in）、コードレビュー補足 **#47** 導線
- **キャプチャ**: `playwright test route-manifest-visual.spec.ts --grep "crops/:id"`（`E2E_CAPTURE_DEV_SESSION=1` `E2E_STRANGLER=1`）。`crops_id.{ja,en,in}.png` を再取得（実装後 UI を反映）。

## 追記メタ（plans optimizing #49、#640）

- **レビュー日**: 2026-08-07（UTC）
- **対象**: `route-to-png.md` **#49** `plans/:id/optimizing`（ja / en / in）
- **キャプチャ**: `playwright test route-manifest-visual.spec.ts --grep "plans/:id/optimizing"`（`E2E_CAPTURE_DEV_SESSION=1` `E2E_STRANGLER=1` `AGRR_DEV_API_URL=http://127.0.0.1:8080`）。`plans_id_optimizing.{ja,en,in}.png` を再取得。agrr-server 開発 DB・AuthTest モックログイン。
- **備考**: agrr デーモン未起動のためキャプチャは気象取得失敗 UI（再試行・`back_to_hub` 導線）。見出し二重は解消。0% 待機説明（`duration_hint`）は `plan-optimizing.component.spec.ts` で確認。

## 追記メタ（#635 / #660 ガント en 圃場ラベル）

- **レビュー日**: 2026-08-07（UTC）
- **対象**: `route-to-png.md` **#48** `plans/:id`（ja / en / in）、follow-up **#660**（親 **#635** PR #647 マージ後）
- **キャプチャ**: `playwright test route-manifest-visual.spec.ts --grep "capture-for-agent: plans/:id$"`（`E2E_CAPTURE_DEV_SESSION=1` `AGRR_DEV_API_URL=http://127.0.0.1:8080`）。`plans_id.{ja,en,in}.png` を再取得。
- **確認**: en で圃場ラベル（`text-anchor: end`・clipPath）が縦線（divider x=70）より左（label anchor x=62）— 重なり解消。**修正済**: #635 / PR #647。回帰: `gantt-chart.component.spec.ts`「anchors field labels before the row divider without overlap」GREEN。

## 追記メタ（#648 entry-schedule visual-review #6）

- **レビュー日**: 2026-08-07（UTC）
- **対象**: `route-to-png.md` **#6** `entry-schedule`・`entry-schedule/crop/:cropId`（ja / en / in）、follow-up **#648**（親 **#632** PR #649 マージ後）
- **キャプチャ**: `playwright test route-manifest-visual.spec.ts --grep "entry-schedule"`（`E2E_CAPTURE_DEV_SESSION=1` `E2E_STRANGLER=1` `AGRR_DEV_API_URL=http://127.0.0.1:8080`）。`entry-schedule*.{ja,en,in}.png` を再取得。agrr-server 開発 DB・AuthTest モックログイン。
- **確認**: ja 成長段階リストの二重番号（「1. 1.」）解消。en/in の UI ラベル・免責文は各言語で表示（作物名・成長段階名は API マスタ由来）。回帰: `entry-schedule-detail.component.spec.ts`「renders growth stages without duplicate list numbering」GREEN、`entry-schedule-locale.catalog.spec.ts` GREEN。

## 追記メタ（#758 setup_proposal L0 UX 再キャプチャ）

- **レビュー日**: 2026-08-08（UTC）
- **対象**: `route-to-png.md` **#23** `crops/:id/setup_proposal`（ja / en / in）、follow-up **#758**（親 **#733** PR #759）
- **キャプチャ**: `playwright test route-manifest-visual.spec.ts --grep "capture-for-agent: crops/:id/setup_proposal"`（`E2E_CAPTURE_DEV_SESSION=1` `E2E_STRANGLER=1` `AGRR_DEV_API_URL=http://127.0.0.1:8080`）。`crops_id_setup_proposal.{ja,en,in}.png` を再取得。agrr-server 開発 DB・AuthTest モックログイン。
- **確認**: #733 L0 透明性 3 要素リスト（外部 AI/MCP・dry-run 確認・上書き警告）が 3 言語で表示。JSON 貼付・プレビューボタン UI 正常。回帰: `crop-setup-proposal-import.component.spec.ts` GREEN。

## サマリ表

| # | pattern | ja | en | in | 結果 | i18n | 指摘 |
|---|---------|----|----|-----|------|------|------|
| 1 | `(home)` | `home.ja.png` | `home.en.png` | `home.in.png` | OK | OK | なし |
| 2 | `**` | `not-found.ja.png` | `not-found.en.png` | `not-found.in.png` | OK | OK | なし |
| 3 | `about` | `about.ja.png` | `about.en.png` | `about.in.png` | OK | OK | なし |
| 4 | `contact` | `contact.ja.png` | `contact.en.png` | `contact.in.png` | OK | OK | なし |
| 5 | `en` | `en.ja.png` | `en.en.png` | `en.in.png` | OK | OK | **#713 再キャプチャ**: `/en` ミラーは enLocaleResolver で常に英語 UI（3 言語 PNG とも英語表示は仕様どおり）。ガントデモ・CTA 正常 |
| 6 | `entry-schedule` | `entry-schedule.ja.png` | `entry-schedule.en.png` | `entry-schedule.in.png` | OK | OK | **#648 再キャプチャ**: 3 言語 UI OK。in 農場名「Punjab」は地名（マスタデータ） |
| 6 | `entry-schedule/crop/:cropId` | `entry-schedule_crop_cropId.ja.png` | `entry-schedule_crop_cropId.en.png` | `entry-schedule_crop_cropId.in.png` | OK | OK | **#648 再キャプチャ**: #632/PR #649 後。ja 二重番号解消。en/in UI ラベル各言語（作物名・段階名は API 由来） |
| 7 | `login` | `login.ja.png` | `login.en.png` | `login.in.png` | OK | OK | なし |
| 8 | `privacy` | `privacy.ja.png` | `privacy.en.png` | `privacy.in.png` | OK | OK | なし |
| 9 | `public-plans/new` | `public-plans_new.ja.png` | `public-plans_new.en.png` | `public-plans_new.in.png` | OK | OK | **#738 受け入れ確認**: mojibake は #172 `localizePublicPlanReferenceFarmName` で解消（spec GREEN）。in「Punjab」は参照農場の地名（データ層・許容） |
| 10 | `public-plans/optimizing` | `public-plans_optimizing.ja.png` | `public-plans_optimizing.en.png` | `public-plans_optimizing.in.png` | 注意 | OK | layout: 最適化進行ではなく気象データ取得失敗のエラー画面 |
| 11 | `public-plans/results` | `public-plans_results.ja.png` | `public-plans_results.en.png` | `public-plans_results.in.png` | 要確認 | 要確認 | layout: 同一 HTTP 404 エラーが二重表示・本文未描画。i18n: ja/in でも生の英語 HTTP エラー文字列 |
| 12 | `public-plans/select-crop` | `public-plans_select-crop.ja.png` | `public-plans_select-crop.en.png` | `public-plans_select-crop.in.png` | OK | OK | layout: step2 作物選択 UI（2026-08-07 再キャプチャ・`route-manifest-visual` step2 assertion GREEN）。i18n: ja 農場名「北海道」表示 |
| 13 | `public-plans/select-farm-size` | `public-plans_select-farm-size.ja.png` | `public-plans_select-farm-size.en.png` | `public-plans_select-farm-size.in.png` | OK | OK | **#738 受け入れ確認**: #9 と同根因。#172 後 mojibake 解消（`public-plan-create.component.spec.ts` GREEN） |
| 14 | `terms` | `terms.ja.png` | `terms.en.png` | `terms.in.png` | OK | OK | なし |
| 14a | `account` | `account.ja.png` | `account.en.png` | `account.in.png` | OK | OK | **#713 再キャプチャ**: エクスポート・削除（危険ゾーン）UI 正常。3 言語ラベル整合 |
| 15 | `agricultural_tasks` | `agricultural_tasks.ja.png` | `agricultural_tasks.en.png` | `agricultural_tasks.in.png` | OK | OK | なし |
| 16 | `agricultural_tasks/:id` | `agricultural_tasks_id.ja.png` | `agricultural_tasks_id.en.png` | `agricultural_tasks_id.in.png` | OK | OK | **#738 受け入れ確認**: #170 修正済。`hours_suffix` は翻訳表示（`agricultural-task-detail.component.spec.ts` GREEN） |
| 17 | `agricultural_tasks/:id/edit` | `agricultural_tasks_id_edit.ja.png` | `agricultural_tasks_id_edit.en.png` | `agricultural_tasks_id_edit.in.png` | OK | OK | なし |
| 18 | `agricultural_tasks/new` | `agricultural_tasks_new.ja.png` | `agricultural_tasks_new.en.png` | `agricultural_tasks_new.in.png` | OK | OK | なし |
| 19 | `api-keys` | `api-keys.ja.png` | `api-keys.en.png` | `api-keys.in.png` | OK | OK | **#713 再キャプチャ**: 未生成状態・生成ボタン・使用方法・エンドポイント一覧が 3 言語で表示 |
| 20 | `crops` | `crops.ja.png` | `crops.en.png` | `crops.in.png` | OK | 注意 | i18n: en で品種名と「Reference Crop」がスペースなしで連結 |
| 21 | `crops/:id` | `crops_id.ja.png` | `crops_id.en.png` | `crops_id.in.png` | OK | OK | layout: 3 カード縦積み・空状態は明瞭。i18n: 作業予定セクションの用語統一・作成日/更新日のロケール表示（2026-07-03 修正） |
| 22 | `crops/:id/edit` | `crops_id_edit.ja.png` | `crops_id_edit.en.png` | `crops_id_edit.in.png` | OK | OK | なし |
| 23 | `crops/:id/setup_proposal` | `crops_id_setup_proposal.ja.png` | `crops_id_setup_proposal.en.png` | `crops_id_setup_proposal.in.png` | OK | OK | **#758 再キャプチャ**（#733 L0 追加分込み）: L0 AI 透明性 3 要素リスト（外部 AI/MCP・dry-run 確認・上書き警告）が ja/en/in で表示。JSON 貼付・プレビュー UI 正常 |
| 24 | `crops/:id/stages` | `crops_id_stages.ja.png` | `crops_id_stages.en.png` | `crops_id_stages.in.png` | OK | 注意 | **#713 再キャプチャ**: ステージ一覧 UI 正常。i18n: ステージ名が英語（Almonds マスタ由来） |
| 25 | `crops/:id/stages/:stageId/edit` | `crops_id_stages_stageId_edit.ja.png` | `crops_id_stages_stageId_edit.en.png` | `crops_id_stages_stageId_edit.in.png` | OK | OK | **#713 再キャプチャ**: 生育ステージ編集フォーム（温度・GDD）正常表示 |
| 26 | `crops/:id/task_schedule_blueprints` | `crops_id_task_schedule_blueprints.ja.png` | `crops_id_task_schedule_blueprints.en.png` | `crops_id_task_schedule_blueprints.in.png` | 注意 | OK | **#713 再キャプチャ**: テンプレート DnD UI 正常。layout: 全カード「タイミング未設定」警告（データ未入力） |
| 27 | `crops/new` | `crops_new.ja.png` | `crops_new.en.png` | `crops_new.in.png` | OK | OK | なし |
| 27 | `farms` | `farms.ja.png` | `farms.en.png` | `farms.in.png` | OK | OK | なし |
| 28 | `farms/:id` | `farms_id.ja.png` | `farms_id.en.png` | `farms_id.in.png` | OK | OK | **#738 受け入れ確認**: #673 修正済。`farms.form.region_jp` 等で表示（`farm-detail.component.spec.ts` GREEN） |
| 29 | `farms/:id/edit` | `farms_id_edit.ja.png` | `farms_id_edit.en.png` | `farms_id_edit.in.png` | OK | OK | なし |
| 30 | `farms/new` | `farms_new.ja.png` | `farms_new.en.png` | `farms_new.in.png` | OK | OK | なし |
| 31 | `fertilizes` | `fertilizes.ja.png` | `fertilizes.en.png` | `fertilizes.in.png` | OK | OK | なし |
| 32 | `fertilizes/:id` | `fertilizes_id.ja.png` | `fertilizes_id.en.png` | `fertilizes_id.in.png` | OK | OK | **#658 再キャプチャ**: E2E Baseline 正常表示。エラー回復 UI（MasterLoadErrorPanel + i18n）は component/presenter spec で検証済み |
| 33 | `fertilizes/:id/edit` | `fertilizes_id_edit.ja.png` | `fertilizes_id_edit.en.png` | `fertilizes_id_edit.in.png` | OK | OK | **#658 再キャプチャ**: 編集フォーム正常表示。`title_default` 生キー解消（PR #659） |
| 34 | `fertilizes/new` | `fertilizes_new.ja.png` | `fertilizes_new.en.png` | `fertilizes_new.in.png` | OK | OK | なし |
| 35 | `interaction_rules` | `interaction_rules.ja.png` | `interaction_rules.en.png` | `interaction_rules.in.png` | OK | OK | なし |
| 36 | `interaction_rules/:id` | `interaction_rules_id.ja.png` | `interaction_rules_id.en.png` | `interaction_rules_id.in.png` | OK | OK | **#738 受け入れ確認**: #171 修正済。ラベル・値とも翻訳（`interaction-rule-detail.component.spec.ts` GREEN） |
| 37 | `interaction_rules/:id/edit` | `interaction_rules_id_edit.ja.png` | `interaction_rules_id_edit.en.png` | `interaction_rules_id_edit.in.png` | OK | OK | なし |
| 38 | `interaction_rules/new` | `interaction_rules_new.ja.png` | `interaction_rules_new.en.png` | `interaction_rules_new.in.png` | OK | OK | なし |
| 39 | `pesticides` | `pesticides.ja.png` | `pesticides.en.png` | `pesticides.in.png` | OK | OK | なし |
| 40 | `pesticides/:id` | `pesticides_id.ja.png` | `pesticides_id.en.png` | `pesticides_id.in.png` | OK | OK | **#658 再キャプチャ**: E2E Baseline 正常表示。エラー回復 UI は component/presenter spec で検証済み |
| 41 | `pesticides/:id/edit` | `pesticides_id_edit.ja.png` | `pesticides_id_edit.en.png` | `pesticides_id_edit.in.png` | OK | OK | **#658 再キャプチャ**: 編集フォーム正常表示。`title_default` 生キー解消（PR #659） |
| 42 | `pesticides/new` | `pesticides_new.ja.png` | `pesticides_new.en.png` | `pesticides_new.in.png` | OK | OK | なし |
| 43 | `pests` | `pests.ja.png` | `pests.en.png` | `pests.in.png` | OK | OK | マスタ害虫名の多言語混在はデータ由来 |
| 44 | `pests/:id` | `pests_id.ja.png` | `pests_id.en.png` | `pests_id.in.png` | OK | 注意 | i18n: Region が `us` コード。説明・発生季節は英語データのまま |
| 45 | `pests/:id/edit` | `pests_id_edit.ja.png` | `pests_id_edit.en.png` | `pests_id_edit.in.png` | OK | 注意 | i18n: 説明・発生季節フィールドが ja/in でも英語 |
| 46 | `pests/new` | `pests_new.ja.png` | `pests_new.en.png` | `pests_new.in.png` | OK | OK | なし |
| 47 | `plans` | `plans.ja.png` | `plans.en.png` | `plans.in.png` | OK | OK | 計画名「E2E Baseline Plan」はテストデータ |
| 48 | `plans/:id` | `plans_id.ja.png` | `plans_id.en.png` | `plans_id.in.png` | OK | OK | **修正済** (#635/#660): en 圃場ラベルと縦線の重なり解消（2026-08-07 再キャプチャ） |
| 49 | `plans/:id/optimizing` | `plans_id_optimizing.ja.png` | `plans_id_optimizing.en.png` | `plans_id_optimizing.in.png` | OK | OK | **#640 再キャプチャ**: 見出し二重解消。失敗時「再読み込み」・`back_to_hub` 導線を 3 言語で確認。0% 待機説明は spec 確認 |
| 50 | `plans/:id/task_schedule` | `plans_id_task_schedule.ja.png` | `plans_id_task_schedule.en.png` | `plans_id_task_schedule.in.png` | OK | OK | layout: `back_to_hub` 導線・ナビ非 active は意図どおり。**修正済**: ステータス i18n・エラー再試行 |
| 51 | `plans/:id/work` | `plans_id_work.ja.png` | `plans_id_work.en.png` | `plans_id_work.in.png` | OK | OK | **修正済**: 記録ボタンをリスト下静的配置・エラー再試行。`back_to_hub`・ナビ active は OK |
| 52 | `plans/:id/work_records` | `plans_id_work_records.ja.png` | `plans_id_work_records.en.png` | `plans_id_work_records.in.png` | OK | OK | **修正済**: エラー再試行追加。`back_to_hub`・ナビ active は OK。**#234**: サムネイル横並び（案 A）確定・4:3 横長（履歴 4rem / シート 4.5rem 幅）。PNG 再キャプチャは写真付きデータ要 |
| 53 | `plans/new` | `plans_new.ja.png` | `plans_new.en.png` | `plans_new.in.png` | OK | OK | **#738 受け入れ確認**: #636 後 3 言語 subtitle 整合（農場選択のみ・年言及なし）。`plans-new-locale.catalog.spec.ts` GREEN |
| 54 | `work` | `work.ja.png` | `work.en.png` | `work.in.png` | 注意 | OK | **#713 再キャプチャ**: 単一農場時は `/plans/:id/work` へ自動遷移（work-hub-init）。作業計画未生成の空状態 UI・再生成導線は意図どおり |

## 集計（レイアウト・読み込み）

| 結果 | 件数 |
|------|------|
| OK | 48 |
| 注意 | 9 |
| 要確認 | 2 |

## 集計（i18n）

| i18n | 件数 |
|------|------|
| OK | 46 |
| 注意 | 9 |
| 要確認 | 2 |

## 指摘の詳細

### P0/P1 修正後の確認（前回レビュー比）

- **#3 about** — `pages.about.operator.*` 生キーは **解消**（OK）。
- **#8 privacy / #14 terms** — `{{contact_link}}` 未展開は **解消**（OK）。
- **#47 plans/:id/task_schedule** — `plans.task_schedules.*` 生キーは **解消**（OK）。
- **#17–22 crops / agricultural_tasks en ラベル** — フォーム・一覧の日本語混在は **概ね解消**（残: #19 Reference Crop 連結）。**#16 hours_suffix は #738 で受け入れ確認済み**。
- **#37 pesticides/:id** — **#658 解消**: E2E Baseline 正常表示。エラー回復 UI は spec 検証済み。

### 新規・残存の i18n / レイアウト

1. **#6 entry-schedule** — **2026-08-07 解消**（#648）: ja 二重番号解消・en/in UI ラベル各言語。作物名・成長段階は API マスタ由来。
2. **#9–13 public-plans** — **#738 受け入れ確認**: mojibake は #172 で解消。in「Punjab」は地名（データ層）。**残**: results は 404 二重表示（#11・本 issue スコープ外）。
3. **#10 public-plans/optimizing** — 気象取得失敗エラー（planId=1 のデータ/API 要因）。
4. **#16 agricultural_tasks/:id** — **#738 受け入れ確認済み**（#170）。
5. **#25 farms/:id** — **#738 受け入れ確認済み**（#673）。
6. **#29–30 fertilizes/:id** — **#658 解消**: E2E Baseline 正常表示。エラー回復 UI は spec 検証済み。
7. **#33 interaction_rules/:id** — **#738 受け入れ確認済み**（#171）。
8. **#37–38 pesticides/:id** — **#658 解消**: E2E Baseline 正常表示。`title_default` 生キー解消。
9. **#49 plans/:id/optimizing** — **2026-08-07 解消**（#640）: 見出し二重解消・失敗時再試行・3 言語 i18n OK。0% 待機説明は spec で確認。
10. **#50 plans/new** — **#738 受け入れ確認済み**（#636）。3 言語 subtitle 整合。
11. **#51 work** — キャプチャ時 `GET /api/v1/work/hub` が 501 のため農場カード未表示。エラー＋「再読み込み」UI・ナビ active は意図どおり。API 応答後の農場一覧は別途再キャプチャ推奨。

### 作業ハブ修正後（#47–51、2026-06-25）

1. **#47 plans/:id/task_schedule** — `back_to_hub` 導線は 3 言語で表示。ナビは計画・作業記録とも非 active（仕様どおり）。ステータスバッジ「PLANNED」が ja でも英字。
2. **#48 plans/:id/work** — タブ切替・戻り導線・ナビ作業記録 active は良好。「+ 作業を記録」がリスト中腹に固定され、上下タスクがフェードで欠ける見え方。
3. **#49 plans/:id/work_records** — エラー時に文言のみでリトライ不可（#51 と UX 不統一）。`back_to_hub` は表示。キャプチャは API 失敗時の状態。
4. **#51 work** — 見出し・説明・エラー・リトライは 3 言語で整合。農場カード・空状態・圃場警告はキャプチャ未検証（API 要因）。

### 作業テンプレート / blueprint UI（#20 再レビュー 2026-07-03）

1. **#20 crops/:id** — layout: 作物詳細＋「作業テンプレート」＋「作業予定」の 3 段構成は意図が読み取れる。**2026-07-03 修正**: 作業予定セクションの用語統一、作成日/更新日を `formatIsoDateTimeForDisplay` でアプリ言語に合わせて表示。

### フロー（コード + #47 導線）

- `missing_crop_templates` バナーは単一作物時 `/crops/:id`、複数時 `/crops` へリンク（**2026-07-03 修正**）。

### データ・キャプチャ環境（Issue 化は任意）

- マスタ一覧の多言語混在（作物名・害虫名等）は参照データ由来。
- public-plans / optimizing・results は planId=1 の公開計画データ依存。
- E2E baseline の fertilizes/pesticides id=1 が DB に存在しない場合 404/500 となる。

## 総評

**CSS**: `audit:css-tokens:enforce` exit 0（var 外 0 件）。前回指摘の gantt-chart 等はトークン化済み。

**キャプチャ**: 2026-08-08 に manifest 全 57 ルート × 3 言語（171 PNG）を `e2e:capture-for-agent` で取得。`verify-capture-complete` GREEN。`/work` は E2E Baseline により plan work へリダイレクト後の画面を撮影。

**ビジュアル**: #713 で未レビューだった 7 pattern（`en`・`account`・`api-keys`・crops 系 4 ルート）を追従。新規画面は概ね OK。`task_schedule_blueprints` はタイミング未設定警告が全カードに表示（データ未入力由来）。

**i18n**: P0/P1 系（about・privacy/terms・task_schedule・マスタ en ラベル）は **大幅改善**。**#658**: fertilizes/pesticides detail+edit の HTTP エラー英語露出・`title_default` 生キーは **解消**。**#738**: hours_suffix・interaction_rules.show.region・public-plans mojibake・farms 地域コード・plans/new subtitle は **受け入れ確認済み**（catalog/component spec）。**残 i18n 要確認 2 件**（#11 public-plans/results 404、#20 Reference Crop 連結）— データ層・別 issue 候補。

成果物: `frontend/e2e/agent-review/visual-review-results.md`（本ファイル）。PNG は `frontend/e2e/agent-review/out/`（gitignore）。
