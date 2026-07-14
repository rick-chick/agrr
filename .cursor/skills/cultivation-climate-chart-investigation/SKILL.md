---
name: cultivation-climate-chart-investigation
description: >-
  Investigates field-cultivation climate chart period misalignment, cumulative GDD vs required GDD,
  and tmp/debug JSON from agrr progress, adjust, allocate, prediction, and add_crop flows.
  Use when the user mentions chart end date, GDD shortfall, weather gaps, progress vs adjust mismatch,
  or tmp/debug weather/crop files.
disable-model-invocation: false
---

# 栽培進捗チャート・気象デバッグ調査

## 適用場面

- 進捗チャートが **要求 GDD 未達** で終わる、栽培期間と表示期間がずれる
- `tmp/debug/` の **progress / adjust / allocation / prediction** JSON を突き合わせる
- **add_crop** 後の期間・GDD がおかしい（内部で adjust 経路）

## 調査手順

1. **症状を 1 文で固定する**（例: 「完了日 7/13 なのに積算 GDD 642 / 要求 1900」）。
2. **直近の debug を時刻で揃える**（同一 `{unix_ts}` または ±数秒）:
   ```bash
   ls -lt tmp/debug/{progress,adjust,allocation,prediction}_* 2>/dev/null | head -30
   ```
3. **気象 JSON の日付連続性を確認**（必須）:
   ```bash
   python3 .cursor/skills/cultivation-climate-chart-investigation/scripts/analyze_debug_weather.py \
     tmp/debug/progress_weather_<ts>.json \
     --start-date 2026-02-17 --completion-date 2026-07-13
   ```
   adjust / allocation 用 weather にも同コマンドを実行し、**同一栽培で series が一致するか**比較する。
4. **経路ごとに「何が agrr に渡ったか」を分ける**（詳細は [references/code-paths.md](references/code-paths.md)）。
5. **原因候補を [references/symptom-cause-tree.md](references/symptom-cause-tree.md) から絞る**。コード変更は根拠ゲート（再現 or 説明）後。
6. ドメイン修正の候補は `test-common` の `run-test-domain-lib.sh` で RED→GREEN（関連: `FieldCultivationClimateObservedMergeRangePolicy`, `FieldCultivationClimateAgrrWeatherAssembler`, `AdjustObservedWeatherWindowMapper`）。

## ファイル名の読み方

| 接頭辞 | 意味 | 開始日・終了日の主な出所 |
|--------|------|---------------------------|
| `prediction_input_*` | agrr predict の学習用観測 | DB 長期系列（末尾＝学習終了） |
| `prediction_transformed_*` / `prediction_output_*` | 予測直後の payload | `prediction_start_date`, `data[]` 末尾 |
| `allocation_weather_*` | **optimize allocate** に渡した気象 | プラン保存予測＋当年観測マージ後 |
| `adjust_weather_*` | **optimize adjust** に渡した気象 | 観測再マージ＋予測（allocate と別経路） |
| `progress_weather_*` / `progress_crop_*` | **agrr progress** 入力 | `FieldCultivationClimateDataInteractor` が組み立てた payload |
| `adjust_allocation_*` / `adjust_moves_*` | adjust 入出力 | moves の `to_start_date`; 結果の `start_date` / `completion_date` |
| `candidates_*` | 候補探索 | planning 期間・allocation スナップショット |

`add_crop` 単体の debug 接頭辞はない。**adjust_* が同時刻で出ていれば add_crop 内 adjust とみなす**。

一覧: [references/debug-json-catalog.md](references/debug-json-catalog.md)

## チャート期間の決まり方（要約）

| 層 | 効くもの |
|----|----------|
| DB | `field_cultivations.start_date` / `completion_date`（adjust 結果が保存される） |
| 気象 | `predicted_weather_data` + 観測マージ（ギャップがあると progress が開始日以降をスキップ） |
| agrr | `progress --start-date` + weather-file の **実在する日次のみ** |
| マッパ | `build_daily_gdd` は `start_date..completion_date` で **progress_records を切る** |
| API 表示 | `apply_display_range` がガント表示範囲との **交差**で weather / gdd を再フィルタ |

要求 GDD 到達前に切れる典型: **気象欠損** + **completion_date 打ち切り**（[references/symptom-cause-tree.md](references/symptom-cause-tree.md)）。

## 禁止・注意

- `git diff` だけで気象の連続性を断定しない。**debug JSON または CLI 再実行**で確認する。
- allocate 実行中は **新規 predict しない**（`CultivationPlanOptimizeInteractor` はキャッシュ読み）。欠損は **予測ジョブ以前** または **progress/adjust マージ** を疑う。
- `optimize adjust` の `accumulated_gdd` / `completion_date` と `agrr progress` は **同一 weather でも一致しないことがある**（agrr サブコマンド差）。チャートは **progress 結果**を正とする。

## 参照

- [references/debug-json-catalog.md](references/debug-json-catalog.md) — 全 debug 接頭辞・メタデータキー
- [references/code-paths.md](references/code-paths.md) — ジョブチェーンとマージ経路
- [references/symptom-cause-tree.md](references/symptom-cause-tree.md) — 症状→原因候補
