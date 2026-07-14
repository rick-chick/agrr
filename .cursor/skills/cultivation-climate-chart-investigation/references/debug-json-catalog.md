# tmp/debug JSON カタログ

非 production のみ `Rails.root/tmp/debug/`（Rust API は `agrr_daemon_debug_dump` 経由で同パス）。  
ファイル名: `{接頭辞}_{unix_ts}.json`。同一操作は **同じ ts** で揃うことが多い。

## 気象・予測

| 接頭辞 | 生成元 | 内容 |
|--------|--------|------|
| `prediction_input_*` | `prediction_daemon_gateway` / `FieldCultivationClimateAgrrGateway#predict` | agrr `predict --input`（長期観測） |
| `prediction_output_*` | 同上（出力ファイル読取後） | predict 生出力 |
| `prediction_transformed_*` | 同上（正規化後） | プラン保存形に近い payload |
| `allocation_weather_*` | `AllocationDaemonGateway` / `PlanAllocationAllocateAgrrDaemonGateway` | allocate 用 **マージ済み**気象 |
| `adjust_weather_*` | `AdjustDaemonGateway` / `PlanAllocationAdjustAgrrDaemonGateway` | adjust 用気象 |
| `progress_weather_*` | `ProgressDaemonGateway` / `FieldCultivationClimateAgrrGateway#calculate_progress` | 進捗チャート用気象 |
| `optimization_weather_*` | `EntryScheduleOptimizationGateway` | スケジュール最適化用（別系統） |

### 気象 payload のよくあるメタキー

| キー | 意味 |
|------|------|
| `data[].time` | 日次（`YYYY-MM-DD`） |
| `prediction_start_date` | 予測ブロックの論理開始（**当日 clamp され data より後ろのことがある**） |
| `prediction_end_date` / `target_end_date` | 予測終了・計画目標 |
| `generated_at` / `predicted_at` | 生成時刻（unix または ISO） |
| `model` | 例: `lightgbm` |

## 作物・割当

| 接頭辞 | 内容 |
|--------|------|
| `allocation_fields_*` / `allocation_crops_*` / `allocation_rules_*` | allocate 入力 |
| `adjust_fields_*` / `adjust_crops_*` / `adjust_moves_*` / `adjust_rules_*` | adjust 入力 |
| `adjust_allocation_*` | 現在割当（adjust 入力・`current_allocation` のコピー） |
| `adjust_current_allocation_*` | 同上（domain debug dump） |
| `progress_crop_*` | agrr 作物プロファイル（`stage_requirements` / `required_gdd`） |
| `candidates_*` | `optimize candidates` 一式 |

## 開始日・終了日の読み取り先

| 目的 | 見るファイル | フィールド |
|------|--------------|------------|
| 栽培（DB 意図） | `progress_crop` は無し → API/DB | `field_cultivation` の start/completion |
| adjust 結果 | `adjust_allocation` 内 `allocations[]` | `start_date`, `completion_date`, `growth_days`, `accumulated_gdd` |
| adjust 移動指示 | `adjust_moves_*` | `to_start_date` |
| 計画評価窓 | `allocation_*` + interactor ログ | `planning_start` / `planning_end`（allocate 引数） |
| progress 実効 | `progress_weather_*` + CLI 再実行 | `data` の min/max date; `--start-date` 引数 |

## add_crop

専用 dump なし。`AddCropInteractor` → **adjust** → 同タイムスタンプの `adjust_*` / `progress_*` を追う。
