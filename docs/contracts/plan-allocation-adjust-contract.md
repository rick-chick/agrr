# 契約: 栽培計画割当 adjust（Plan Allocation Adjust）



## 1. 機能名・スコープ



- **機能**: 手修正（moves）後に agrr optimize adjust を実行し、FieldCultivation と計画サマリを更新する

- **スコープ**: `PlanAllocationAdjustInteractor`（adjust 本体 + REST 経路の成長段階チェック）



## 2. ドメイン契約



### 2.1 Input



- `PlanAllocationAdjustInput`: `{ plan_id: Integer, moves: Array<Hash>, auth: CultivationPlanRestAuth|nil }`

- `auth` あり（REST adjust）— 成長段階チェックを先に実行

- `auth` なし（add_crop / integration レガシー）— 成長段階チェックをスキップ



### 2.2 Success Output



- `PlanAllocationAdjustOutput`: `{ message: String, cultivation_plan: Hash|nil, skipped: Boolean }`

- `skipped: true` — moves が空のとき（調整スキップ）



### 2.3 Failure



- `PlanAllocationAdjustFailure` の `kind`:



| kind | 意味 |

|---|---|

| `:no_weather_location` | 農場に WeatherLocation なし |

| `:invalid_date` | 日付形式不正 |

| `:calculate_period_failed` | 計画期間算出失敗 |

| `:weather_fetch_failed` | 天気予測取得失敗 |

| `:adjust_execution_failed` | agrr adjust 実行失敗（`AdjustExecutionError`） |

| `:result_empty` | agrr 結果に field_schedules なし |

| `:crop_missing_growth_stages` | 計画作物に生育段階が未設定（REST 成長段階ゲート） |

| `:not_found` | 計画が存在しない、または REST 認可で取得不可 |

| `:unexpected` | その他の予期しない失敗（REST 経路の rescue 含む） |



HTTP ステータスは Presenter / `PlanAllocationAdjustFailureHttpMapper` が決定（domain は kind + message のみ）。



### 2.4 Output port



- `PlanAllocationAdjustOutputPort#on_success(output:)`

- `PlanAllocationAdjustOutputPort#on_failure(failure:)`



### 2.5 Debug dump（開発のみ）



- `PlanAllocationAdjustDebugDumpGateway#dump_payload!` — adjust 直前の allocation / moves / fields / crops をファイルへ書き出す（非本番のみ `PlanAllocationAdjustDebugDumpFileGateway`）

- 本番は `PlanAllocationAdjustDebugDumpNullGateway`（no-op）



## 3. API



### POST `/api/v1/{plans|public_plans}/cultivation_plans/:id/adjust`



- **Request**: `{ moves: Array<{ allocation_id, to_field_id, to_start_date, ... }> }`

- **Success (200)**: `{ success: true, message: string, cultivation_plan?: object }`

- **Failure**: `{ success: false, message: string }` + HTTP status（kind により 400/404/500）



## 4. 例外写像（adapter / interactor）



- `BaseGatewayV2::ExecutionError` → `Domain::CultivationPlan::Errors::AdjustExecutionError`（`PlanAdjustActiveRecordGateway`）

- Interactor は `AdjustExecutionError` およびその他の modeled 失敗を **`PlanAllocationAdjustFailure` に変換**して `on_failure` へ（Controller の `rescue` 主導にしない）

- REST 経路（`auth` あり）の未捕捉 `StandardError` も `kind: :unexpected` の Failure に変換



## 5. レガシー Hash 経路（暫定・R8）



### 5.1 現状



`CompositionRoot#plan_allocation_adjust_legacy` は `PlanAllocationAdjustInteractor` を `PlanAllocationAdjustLegacyHashCollector` 経由で呼び、**Hash**（`success` / `message` / `cultivation_plan?` / `status?`）を返す。



**呼び出し元（リポジトリ内）**:



| 経路 | ファイル |

|---|---|

| add_crop REST | `RestAddCropOptimizationHostBridge#plan_allocation_adjust` → `AddCropInteractor` が Hash の `success` を判定 |

| integration テスト | `test/integration/adjust_weather_data_insufficient_test.rb` |



REST adjust API（§3）は本契約の typed port 経路を使用し、**legacy は経由しない**。



### 5.2 置換先（Definition of done）



legacy 削除の条件（すべて満たすこと）:



1. **add_crop**: `CultivationPlanAddCropAdjustInvokeGateway`（または同等 adapter）が `PlanAllocationAdjustInteractor` を直接呼び、`PlanAllocationAdjustOutput` / `PlanAllocationAdjustFailure` を `AddCropOutputPort` へ写す（`on_adjust_failed(adjust_payload: Hash)` を廃止）

2. **integration**: adjust 検証は `PlanAllocationAdjustInteractor` + output port テスト、または Controller 経由の edge テストに移行

3. `plan_allocation_adjust_legacy` と `PlanAllocationAdjustLegacyHashCollector` を削除



### 5.3 寿命



- **追加禁止**: legacy Hash 形状への, new API、Presenter、フロントへ拡張しない

- **削除目標**: add_crop typed 化 PR マージ後、同一リリースまたは直後の PR で legacy 経路を削除

- **それまで**: 本セクションと §2.1 の `auth: nil` 経路を正とする



## 6. テスト



- `test/domain/cultivation_plan/interactors/plan_allocation_adjust_interactor_test.rb`

- `test/domain/cultivation_plan/interactors/cultivation_plan_rest_interactors_test.rb`（成長段階ゲート）

- `test/adapters/cultivation_plan/gateways/plan_adjust_active_record_gateway_test.rb`

- `test/integration/adjust_weather_data_insufficient_test.rb`（legacy 経路・移行後は削除または edge 化）

