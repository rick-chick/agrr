# Agent ビジュアルレビュー結果

## メタ

- **レビュー日**: 2026-06-18（UTC）
- **対象**: `route-to-png.md` **#1–50**（全ルート・**ja / en / in** 各 1 枚）
- **キャプチャ**: `npm run e2e:capture-for-agent`（`E2E_CAPTURE_DEV_SESSION=1` `E2E_STRANGLER=1` `AGRR_DEV_API_URL=http://127.0.0.1:8080`）。AuthTest モックログイン・`/api/v1/auth/me` 非モック。`verify-capture-complete` **150 PNG**（50 ルート × 3 言語）。キャプチャ日: 2026-06-18。
- **前提**: development SQLite・参照データ + E2E Baseline Plan。CSS トークンは `npm run audit:css-tokens:enforce` exit 0（var 外 0 件）。本レビューでは CSS 列挙は行わない。

## サマリ表

| # | pattern | ja | en | in | 結果 | i18n | 指摘 |
|---|---------|----|----|-----|------|------|------|
| 1 | `(home)` | `home.ja.png` | `home.en.png` | `home.in.png` | OK | OK | なし |
| 2 | `**` | `not-found.ja.png` | `not-found.en.png` | `not-found.in.png` | OK | OK | なし |
| 3 | `about` | `about.ja.png` | `about.en.png` | `about.in.png` | OK | OK | なし |
| 4 | `contact` | `contact.ja.png` | `contact.en.png` | `contact.in.png` | OK | OK | なし |
| 5 | `entry-schedule` | `entry-schedule.ja.png` | `entry-schedule.en.png` | `entry-schedule.in.png` | OK | 注意 | i18n: in の農場ドロップダウン値「Punjab」が英字のまま |
| 6 | `entry-schedule/crop/:cropId` | `entry-schedule_crop_cropId.ja.png` | `entry-schedule_crop_cropId.en.png` | `entry-schedule_crop_cropId.in.png` | 注意 | 要確認 | layout: ja 成長段階リストが「1. 1.」の二重番号。i18n: en/in に作物名・成長段階・免責文など日本語が残存 |
| 7 | `login` | `login.ja.png` | `login.en.png` | `login.in.png` | OK | OK | なし |
| 8 | `privacy` | `privacy.ja.png` | `privacy.en.png` | `privacy.in.png` | OK | OK | なし |
| 9 | `public-plans/new` | `public-plans_new.ja.png` | `public-plans_new.en.png` | `public-plans_new.in.png` | OK | 要確認 | i18n: ja 農場名カードが文字化け（mojibake）。in カードラベル「Punjab」が英字 |
| 10 | `public-plans/optimizing` | `public-plans_optimizing.ja.png` | `public-plans_optimizing.en.png` | `public-plans_optimizing.in.png` | 注意 | OK | layout: 最適化進行ではなく気象データ取得失敗のエラー画面 |
| 11 | `public-plans/results` | `public-plans_results.ja.png` | `public-plans_results.en.png` | `public-plans_results.in.png` | 要確認 | 要確認 | layout: 同一 HTTP 404 エラーが二重表示・本文未描画。i18n: ja/in でも生の英語 HTTP エラー文字列 |
| 12 | `public-plans/select-crop` | `public-plans_select-crop.ja.png` | `public-plans_select-crop.en.png` | `public-plans_select-crop.in.png` | 要確認 | 要確認 | layout: 作物選択(step 2)ではなく地域選択(step 1)が表示。i18n: ja 農場名文字化け。in「Punjab」英字 |
| 13 | `public-plans/select-farm-size` | `public-plans_select-farm-size.ja.png` | `public-plans_select-farm-size.en.png` | `public-plans_select-farm-size.in.png` | OK | 要確認 | i18n: ja 農場名カードが文字化け。in カードラベル「Punjab」が英字 |
| 14 | `terms` | `terms.ja.png` | `terms.en.png` | `terms.in.png` | OK | OK | なし |
| 15 | `agricultural_tasks` | `agricultural_tasks.ja.png` | `agricultural_tasks.en.png` | `agricultural_tasks.in.png` | OK | OK | なし |
| 16 | `agricultural_tasks/:id` | `agricultural_tasks_id.ja.png` | `agricultural_tasks_id.en.png` | `agricultural_tasks_id.in.png` | 注意 | 要確認 | i18n: `agricultural_tasks.show.hours_suffix` 生キー（3 言語） |
| 17 | `agricultural_tasks/:id/edit` | `agricultural_tasks_id_edit.ja.png` | `agricultural_tasks_id_edit.en.png` | `agricultural_tasks_id_edit.in.png` | OK | OK | なし |
| 18 | `agricultural_tasks/new` | `agricultural_tasks_new.ja.png` | `agricultural_tasks_new.en.png` | `agricultural_tasks_new.in.png` | OK | OK | なし |
| 19 | `crops` | `crops.ja.png` | `crops.en.png` | `crops.in.png` | OK | 注意 | i18n: en で品種名と「Reference Crop」がスペースなしで連結 |
| 20 | `crops/:id` | `crops_id.ja.png` | `crops_id.en.png` | `crops_id.in.png` | OK | 注意 | i18n: ja/in で作成日・更新日が英語日時形式のまま |
| 21 | `crops/:id/edit` | `crops_id_edit.ja.png` | `crops_id_edit.en.png` | `crops_id_edit.in.png` | OK | OK | なし |
| 22 | `crops/new` | `crops_new.ja.png` | `crops_new.en.png` | `crops_new.in.png` | OK | OK | なし |
| 23 | `dashboard` | `dashboard.ja.png` | `dashboard.en.png` | `dashboard.in.png` | OK | OK | なし |
| 24 | `farms` | `farms.ja.png` | `farms.en.png` | `farms.in.png` | OK | OK | なし |
| 25 | `farms/:id` | `farms_id.ja.png` | `farms_id.en.png` | `farms_id.in.png` | OK | 注意 | i18n: 地域がコード `jp` のまま（ja/en/in 共通） |
| 26 | `farms/:id/edit` | `farms_id_edit.ja.png` | `farms_id_edit.en.png` | `farms_id_edit.in.png` | OK | OK | なし |
| 27 | `farms/new` | `farms_new.ja.png` | `farms_new.en.png` | `farms_new.in.png` | OK | OK | なし |
| 28 | `fertilizes` | `fertilizes.ja.png` | `fertilizes.en.png` | `fertilizes.in.png` | OK | OK | なし |
| 29 | `fertilizes/:id` | `fertilizes_id.ja.png` | `fertilizes_id.en.png` | `fertilizes_id.in.png` | 要確認 | 注意 | layout: API 404 で本文未表示。i18n: エラー文言が英語の生 HTTP メッセージ |
| 30 | `fertilizes/:id/edit` | `fertilizes_id_edit.ja.png` | `fertilizes_id_edit.en.png` | `fertilizes_id_edit.in.png` | 要確認 | 注意 | layout: 404 でフォーム空。i18n: 見出し欠落・エラー英語 |
| 31 | `fertilizes/new` | `fertilizes_new.ja.png` | `fertilizes_new.en.png` | `fertilizes_new.in.png` | OK | OK | なし |
| 32 | `interaction_rules` | `interaction_rules.ja.png` | `interaction_rules.en.png` | `interaction_rules.in.png` | OK | OK | なし |
| 33 | `interaction_rules/:id` | `interaction_rules_id.ja.png` | `interaction_rules_id.en.png` | `interaction_rules_id.in.png` | OK | 要確認 | i18n: `interaction_rules.show.region` 生キー（3 言語） |
| 34 | `interaction_rules/:id/edit` | `interaction_rules_id_edit.ja.png` | `interaction_rules_id_edit.en.png` | `interaction_rules_id_edit.in.png` | OK | OK | なし |
| 35 | `interaction_rules/new` | `interaction_rules_new.ja.png` | `interaction_rules_new.en.png` | `interaction_rules_new.in.png` | OK | OK | なし |
| 36 | `pesticides` | `pesticides.ja.png` | `pesticides.en.png` | `pesticides.in.png` | OK | OK | なし |
| 37 | `pesticides/:id` | `pesticides_id.ja.png` | `pesticides_id.en.png` | `pesticides_id.in.png` | 要確認 | 注意 | layout: API 500 で本文未表示。i18n: エラー文言が英語の生 HTTP メッセージ |
| 38 | `pesticides/:id/edit` | `pesticides_id_edit.ja.png` | `pesticides_id_edit.en.png` | `pesticides_id_edit.in.png` | 要確認 | 要確認 | layout: 500 でフォーム空。i18n: `pesticides.edit.title_default` 生キー（3 言語） |
| 39 | `pesticides/new` | `pesticides_new.ja.png` | `pesticides_new.en.png` | `pesticides_new.in.png` | OK | OK | なし |
| 40 | `pests` | `pests.ja.png` | `pests.en.png` | `pests.in.png` | OK | OK | マスタ害虫名の多言語混在はデータ由来 |
| 41 | `pests/:id` | `pests_id.ja.png` | `pests_id.en.png` | `pests_id.in.png` | OK | 注意 | i18n: Region が `us` コード。説明・発生季節は英語データのまま |
| 42 | `pests/:id/edit` | `pests_id_edit.ja.png` | `pests_id_edit.en.png` | `pests_id_edit.in.png` | OK | 注意 | i18n: 説明・発生季節フィールドが ja/in でも英語 |
| 43 | `pests/new` | `pests_new.ja.png` | `pests_new.en.png` | `pests_new.in.png` | OK | OK | なし |
| 44 | `plans` | `plans.ja.png` | `plans.en.png` | `plans.in.png` | OK | OK | 計画名「E2E Baseline Plan」はテストデータ |
| 45 | `plans/:id` | `plans_id.ja.png` | `plans_id.en.png` | `plans_id.in.png` | 注意 | OK | layout: en でガント左端縦線が「Baseline Field」と重なる |
| 46 | `plans/:id/optimizing` | `plans_id_optimizing.ja.png` | `plans_id_optimizing.en.png` | `plans_id_optimizing.in.png` | 注意 | 注意 | layout: 進捗 0% 待機。i18n: 見出しが二重（例: ja「最適化中 最適化中」） |
| 47 | `plans/:id/task_schedule` | `plans_id_task_schedule.ja.png` | `plans_id_task_schedule.en.png` | `plans_id_task_schedule.in.png` | OK | OK | なし |
| 48 | `plans/:id/work` | `plans_id_work.ja.png` | `plans_id_work.en.png` | `plans_id_work.in.png` | OK | OK | なし |
| 49 | `plans/:id/work_records` | `plans_id_work_records.ja.png` | `plans_id_work_records.en.png` | `plans_id_work_records.in.png` | OK | OK | なし |
| 50 | `plans/new` | `plans_new.ja.png` | `plans_new.en.png` | `plans_new.in.png` | OK | 注意 | i18n: ja は農場のみ言及、en/in は「年と農場」— 見出し意味がずれる |

## 集計（レイアウト・読み込み）

| 結果 | 件数 |
|------|------|
| OK | 36 |
| 注意 | 8 |
| 要確認 | 6 |

## 集計（i18n）

| i18n | 件数 |
|------|------|
| OK | 30 |
| 注意 | 12 |
| 要確認 | 8 |

## 指摘の詳細

### P0/P1 修正後の確認（前回レビュー比）

- **#3 about** — `pages.about.operator.*` 生キーは **解消**（OK）。
- **#8 privacy / #14 terms** — `{{contact_link}}` 未展開は **解消**（OK）。
- **#47 plans/:id/task_schedule** — `plans.task_schedules.*` 生キーは **解消**（OK）。
- **#17–22 crops / agricultural_tasks en ラベル** — フォーム・一覧の日本語混在は **概ね解消**（残: #16 hours_suffix、#19 Reference Crop 連結）。
- **#37 pesticides/:id** — 関連名表示はキャプチャ不能（API 500）。別途データ/API 要因。

### 新規・残存の i18n / レイアウト

1. **#6 entry-schedule/crop/:cropId** — en/in に日本語コンテンツ混在。ja 成長段階の二重番号。
2. **#9–13 public-plans** — ja 農場名 mojibake。in「Punjab」英字。results は 404 二重表示。
3. **#10 public-plans/optimizing** — 気象取得失敗エラー（planId=1 のデータ/API 要因）。
4. **#16 agricultural_tasks/:id** — `agricultural_tasks.show.hours_suffix` 生キー。
5. **#25 farms/:id** — 地域コード `jp` 表示（編集画面は翻訳済み）。
6. **#29–30 fertilizes/:id** — マスタ id=1 が 404（キャプチャ URL リゾルブ要確認）。
7. **#33 interaction_rules/:id** — `interaction_rules.show.region` 生キー。
8. **#37–38 pesticides/:id** — API 500 + `pesticides.edit.title_default` 生キー。
9. **#46 plans/:id/optimizing** — 見出し二重表示（バッジ + タイトル）。
10. **#50 plans/new** — 3 言語で見出し文言の意味不一致（年の有無）。

### データ・キャプチャ環境（Issue 化は任意）

- マスタ一覧の多言語混在（作物名・害虫名等）は参照データ由来。
- public-plans / optimizing・results は planId=1 の公開計画データ依存。
- E2E baseline の fertilizes/pesticides id=1 が DB に存在しない場合 404/500 となる。

## 総評

**CSS**: `audit:css-tokens:enforce` exit 0（var 外 0 件）。前回指摘の gantt-chart 等はトークン化済み。

**キャプチャ**: 50 ルート × 3 言語で `verify-capture-complete` 通過（150 PNG）。`installCaptureLocale` が `localStorage` の `agrr.app.lang` を上書きする修正により en/in キャプチャが同一セッションで可能になった。

**ビジュアル**: ヘッダ・フッター・マスタ一覧のレイアウトは概ね一貫。API エラー画面・public-plans データ欠如による 404/気象失敗が複数ルートで `要確認`。

**i18n**: P0/P1 系（about・privacy/terms・task_schedule・マスタ en ラベル）は **大幅改善**。残件は生キー（hours_suffix・interaction_rules.show.region・pesticides.edit.title_default）、public-plans 農場名 mojibake、HTTP エラー英語露出、地域コード表示など。**i18n 要確認 8 件** — 新規 Issue 化を推奨（`ux-issue-creator` パイプライン）。

成果物: `frontend/e2e/agent-review/visual-review-results.md`（本ファイル）。PNG は `frontend/e2e/agent-review/out/`（gitignore）。
