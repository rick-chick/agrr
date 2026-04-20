# 作物スケジュール（エントリ）機能の基盤技術整理・実現可能性

**ステータス**: ドラフト（事実調査・決定案を反映）  
**最終更新**: 2026-04-15  
**関連**: [crop_schedule_entry_product_requirements.md](./crop_schedule_entry_product_requirements.md)

---

## 1. 目的

- [企画要件](./crop_schedule_entry_product_requirements.md) を満たすための**既存基盤の整理**。
- **研究レポート（reports）系資産の派生**として追加する想定での位置づけ。
- **公開作物・地域をDBから利用**し、**予測・最適化も既存パイプラインから流用できるか**の整理と**未検証事項**の列挙。

---

## 2. 「reports」的なものの本リポジトリでの意味

| レイヤ | 実体 | 本機能との関係 |
|--------|------|----------------|
| **研究レポート（オフライン）** | `public/research/` 配下の研究手順・`crop_variables.yaml`・AI による温度/GDD/NPK/害虫レポート | **作物パラメータのソース候補**。運用は手作業寄り。アプリ実行時のAPIではない。 |
| **実行時の「解析・レポート」** | `GET .../field_cultivations/:id/climate_data`（GDD・気象）、計画詳細のチャート系（[gdd-chart-contract.md](../contracts/gdd-chart-contract.md)） | **圃場・作付けが既にある前提**の気象/GDD可視化。 |
| **作業スケジュール生成** | `TaskScheduleGeneratorService` + `CropTaskScheduleBlueprint` + AGRR `progress` | **栽培計画 + 予測気象 + テンプレート**からタスク日付を生成。 |
| **期間最適化** | `Agrr::OptimizationGateway#optimize`（CLI `optimize period`） | **評価期間内の開始日**等の最適化。作物プロファイル + 気象ファイル。 |

**位置づけ案**: エントリ向け「一覧・詳細」は、**研究レポートのMarkdownそのものではなく**、同じ作物知見を**DBの参照作物（`Crop`）と AGRR CLI** に載せた上での**軽量派生**とする。研究パイプラインは**マスタ更新の上流**として接続可能。

---

## 3. 既存の核となるデータモデル（DB）

### 3.1 地域・地点

| モデル | 役割 |
|--------|------|
| **`Farm`** (`is_reference: true`) | **参照農場＝栽培地域の代理**。`latitude` / `longitude` / `region`（`jp` / `us` / `in`）。公開プランナー（`PublicPlansController`, `WizardController#farms`）で選択。 |
| **`WeatherLocation`** | 過去気象・予測の紐づけ先。`predicted_weather_data` を保持しうる。 |
| **`Crop#region`** | 参照作物の地域区分。`CropPolicy.reference_scope` で **農場の region に合わせて作物一覧**を絞る実装あり（ウィザード `crops`）。 |

**ドロップダウン地域**の実装案: UIの「地域」は **参照 `Farm` 1件に1:1でマップ**するのが既存パターンに近い（名前表示・lat/lon取得・気象取得に使える）。**市区町村だけの独立マスタ**は、現状は **Farm 経由で間接的**に表現されている。

### 3.2 作物（公開・参照）

| モデル | 役割 |
|--------|------|
| **`Crop`** (`is_reference: true`, `user` は参照農場と同様のルール) | 名称、`crop_stages`、AGRR向け `to_agrr_requirement`。 |
| **`CropTaskScheduleBlueprint`** | 作業テンプレ（`gdd_trigger` 等）。`TaskScheduleGeneratorService` が必須。 |
| **`CropTaskTemplate` / `AgriculturalTask`** | テンプレと農業作業マスタの結合。 |

### 3.3 気象・予測

| モデル / サービス | 役割 |
|-------------------|------|
| **`CultivationPlan#predicted_weather_data`** | **JSON**。作業生成・最適化の入力として利用。 |
| **`Farm#predicted_weather_data`** | 農場単位の予測キャッシュ。 |
| **`WeatherPredictionService`** | `WeatherLocation` を起点に予測を実行し、`CultivationPlan` または `Farm` に保存。内部で **`Agrr::PredictionGateway`**。 |
| **`WeatherDatum`** | 日別気象（`weather_location` 配下）。 |

### 3.4 計算ゲートウェイ（AGRR CLI）

| Gateway | 用途 |
|-----------|------|
| **`Agrr::PredictionGateway`** | 将来区間の気象予測ペイロード生成（保存前処理を含む）。 |
| **`Agrr::ProgressGateway`** | `crop` + `start_date` + `weather_data` → 日別進捗（GDD 等）。`TaskScheduleGeneratorService` が使用。 |
| **`Agrr::OptimizationGateway`** | `optimize period` — **評価開始・終了・気象・作物プロファイル**から**最適な開始付近**を取得。 |
| **`Agrr::ScheduleGateway`** | `schedule` コマンド（作業系列の生成系。別フロー）。 |

---

## 4. 既存フローとの対応（要件へのマッピング）

| 企画要件 | 既存で近いもの | ギャップ |
|----------|----------------|----------|
| 一覧で **植え時・まき時** + **ざっくりスケジュール** | 単一ソースの「ラベル」としては **最適化結果** または **ステージ境界 + 暦** の合成が必要。参照作物は **ステージ** と **AGRR要件** を持つ。 | **「植え」「まき」をUI用に2窓で出す**明示スキーマはDBにない可能性。CLI/中間DTOで **播種日 vs 定植日** を分けて返せるかは **要確認**。 |
| **選択地域の最新気象・予測** | `WeatherPredictionService` + 参照 `Farm` の `weather_location` / 座標。 | **栽培計画なし**で Farm だけ選んだときに、**どのオブジェクトに `predicted_weather_data` を載せるか**（セッション用の一時構造 vs Farm 更新）は**設計選択**。 |
| 詳細で **今後の作業がざっくり** | `TaskScheduleGeneratorService` 出力、`crop_task_schedule_blueprints`。 | **CultivationPlan / FieldCultivation が無い**エントリ単体では **生成ジョブの前提が欠ける**。 |
| **透明性（FR-TRUST）** | ログ・デバッグ用にCLI入出力を `tmp/debug` に保存するコードあり。 | ユーザー向け **1行説明** は**新規**。 |

---

## 5. 想定アーキテクチャ（派生機能として）

```
[ ドロップダウン: 参照 Farm または region+Farm リスト ]
        ↓
[ WeatherPredictionService または 既存キャッシュ ]
        ↓ predicted_weather_data（日次系列）
[ 参照 Crop 一覧（CropPolicy.reference_scope）]
        ↓ 作物ごと
[ ルートA: 軽量ヒューリスティック ]  OR  [ ルートB: OptimizationGateway ]
        ↓
一覧DTO: まき窓・植え窓（または統合「始め窓」）+ ざっくりフェーズ
        ↓
詳細: 同Cropに対し Progress または Schedule で作業系列のざっくり
```

- **ルートA**: 閾値（最低気温、霜）を **crop_stages / 要件JSON** から読み、**予測系列をスキャン**するのみ。AGRR呼び出し少、説明しやすい。
- **ルートB**: **既存 `OptimizationGateway`** で「最適開始付近」を取得し、一覧の主指標にする。**作物×回数**のコストと**CLI仕様の解釈**が課題。

**作業スケジュールの完全再利用**（`TaskScheduleGeneratorService`）は、**仮想の `CultivationPlan`（メモリ上）**を用意するか、**サービスを分割リファクタ**して **plan なし**でも `predicted_weather + crop + start_date` で動くようにする、のどちらかが必要。

---

## 6. 調査項目（INV）— 事実と決定案

以下は **本リポジトリのコード・開発DB** に基づく事実調査（2026-04-15）。外部 AGRR バイナリのソースはリポジトリ外のため、CLI の入出力仕様は **Rails ゲートウェイが解釈している形**で確定している。

### INV-01: `optimize period` は播種・定植を分けて返すか

| 事実 | `Agrr::OptimizationGateway#parse_optimization_result` は `optimal_periods` の **先頭1件**から `optimal_start_date`, `completion_date`, `growth_days`, `gdd`, `total_cost` を取り出すのみ（[`optimization_gateway.rb`](../../app/gateways/agrr/optimization_gateway.rb)）。**単一の最適栽培開始日**として扱っている。 |
|------|------|
| **解釈** | Rails が利用している JSON には **「まき用」「植え用」の2つの独立した最適日**を読み分ける処理は**ない**。 |

**決定案（最適）**

1. **一覧の「まき時・植え時」**は、**最適化1回の日付を二つに割ることはしない**。
2. **帯（適期ウィンドウ）**は、まず **ルートA**: `predicted_weather_data` の日次気温と、`Crop` の **第1生育ステージ（播種・発芽相当）**および **定植に相当するステージ**の `temperature_requirement`（`frost_threshold`, `optimal_min` 等）を使い、**系列を走査して連続日をマージ**して求める（CLI 呼び出しなしでも実装可能）。
3. **OptimizationGateway** は **「参考：コスト最適な開始の1点」**として任意利用し、帯表示の主軸にはしない（CLI 負荷・意味の単一性に合わせる）。

---

### INV-02: Progress を複数回呼んで帯を近似できるか

| 事実 | `ProgressGateway#calculate_progress` は **作物 + 開始日 + 気象JSON** ごとに CLI を起動するステートレスAPI。同一気象に対し開始日だけ変えて **複数回呼ぶことは技術的に可能**。 |
|------|------|

**決定案（最適）**

- **MVP の帯推定**には使わない（呼び出し回数 × 作物数が爆発しやすい）。
- **用途を限定**するなら、(1) 詳細画面の **GDD 曲線の補助**、(2) ルートA の結果の **スポット検証**（週1サンプル程度）にとどめる。
- 帯の本体は **気象系列 + ステージ閾値のスキャン**（INV-01 のルートA）に寄せる。

---

### INV-03: 参照作物に `crop_task_schedule_blueprints` は揃っているか

| 事実 | **開発環境 DB** では `CropTaskScheduleBlueprint.count == 0`、参照作物 45 件は **いずれもブループリント未紐付け**（`rails runner` で確認）。本番・ステージングは別途確認が必要。 |
|------|------|
| **コード** | `TaskScheduleGeneratorService` はブループリント必須（無いと `TemplateMissingError`）。テストでは Factory で明示作成。 |

**決定案（最適）**

1. **エントリ一覧・植え/まき帯**は **`Crop` + `crop_stages` + 気象**に依存させ、**ブループリント非依存**で動かす（INV-01 ルートA）。
2. **「今後の作業のざっくり」**をテンプレ日付まで落とす場合のみブループリント（または `crop_task_templates` 経由）を要する。**未整備作物**は **ステージ名＋目安文言**にフォールバックする。
3. 本番データでカバー率を KPI 化し、`bin/generate_crop_task_schedule_blueprints.rb` 等で **欠損を埋める**運用と併用。

---

### INV-04: JP 参照 Farm の粒度

| 事実 | `Farm.where(is_reference: true, region: 'jp').count` は **47**（都道府県数と一致）。名前は **北海道・青森・…** のように **1都道府県あたり1代表地点**（`latitude`/`longitude` 付き）。 |
|------|------|

**決定案（最適）**

- ドロップダウン「地域」は **参照 `Farm`（JP）をそのまま選択肢**とする（既存 `WizardController#farms` と同型）。
- **市区町村までの細分化**はデータが無い。**UI 文言**で「都道府県代表地点の気象」と明示し、FR-TRUST と整合させる。

---

### INV-05: 予測の長さ・更新

| 事実 | `WeatherPredictionService#normalize_target_end_date` のデフォルトは **`Date.current + 6.months`**（[`weather_prediction_service.rb`](../../app/services/weather_prediction_service.rb)）。栽培計画側は `calculated_planning_end_date` 等を渡せる。訓練データは最大約20年分を要求。キャッシュは `WeatherLocation` / `Farm` / `CultivationPlan` の `predicted_weather_data` で、**`target_end_date` をカバーしていなければ再取得**。 |
|------|------|

**決定案（最適）**

- **年間スケジュール一覧**が必要なら、エントリAPIから **`target_end_date` を明示**（例：当年12/31 または +365日）。6ヶ月のみでは「翌春の植え」の比較が欠ける場合がある。
- **更新頻度**: 表示の `generated_at` / `predicted_at` をユーザー向けに出し、**気象キャッシュが古い場合は再予測**（既存ロジック準拠）。

---

### INV-06: 研究レポートと `to_agrr_requirement` の関係

| 事実 | 実行時の作物プロファイルは **`Crop#to_agrr_requirement`** が **`crop_stages` + `temperature_requirement` + `thermal_requirement`（等）**から生成（[`crop.rb`](../../app/models/crop.rb)）。研究レポート（`public/research/`）は **別パイプライン**で、**自動同期はコード上ない**。 |
|------|------|

**決定案（最適）**

- **ランタイムの正**は **DB のステージ・要件**。研究レポートは **マスタ更新の入力**（人間 or スクリプトが `CropStage` 等へ反映）と位置づける。
- ギャップ検知は **スポット比較**または **管理用レポート**で行い、本機能は **DB だけを読む**。

---

## 7. リスクと緩和

| リスク | 緩和 |
|--------|------|
| CLI 負荷（作物数×最適化） | キャッシュ、代表日のみ再計算、サーバ側バッチ。 |
| 予報ブレ | 要件 FR-TRUST に沿った **変更理由** と **更新時刻**。 |
| 参照データ欠損 | 一覧から欠損作物を除外 + 「準備中」表示。 |
| 研究レポートとDBの乖離 | パラメータ更新を **単一パイプライン**（CLI投入 or 管理画面）に寄せる。 |

---

## 8. 推奨する次ステップ（更新）

1. **スパイク**: 参照作物1つ・JP参照Farm1つで、`predicted_weather_data` から **ルートA（閾値スキャン）**で「まき帯・植え帯」をJSON出力するサービスオブジェクトを試作。  
2. **API**: `GET` で `reference_farm_id`（または `region=jp` + 県コード）+ 任意で `prediction_end_date`。既存ウィザードの `farms` / `crops` と並べてもよい。  
3. **本番確認**: `crop_task_schedule_blueprints` の件数・カバー率を本番またはステージングで1クエリ確認（開発は0件のため）。  
4. **MVP**: **ルートA + 6ヶ月超の予測はパラメータで延長**、**最適化はP1または補助表示**。

---

## 9. 関連ドキュメント

- [crop_schedule_entry_product_requirements.md](./crop_schedule_entry_product_requirements.md)
- [TASK_SCHEDULE_GENERATION.md](../implementation/TASK_SCHEDULE_GENERATION.md)
- [us_weather_regional_analysis.md](../analysis/us_weather_regional_analysis.md)（US参照気象の制約例）
- [gdd-chart-contract.md](../contracts/gdd-chart-contract.md)

---

## 10. 調査時に実行したコマンド（再現用）

```bash
# 参照作物数・ブループリント欠損（開発DB）
bundle exec rails runner "puts({ ref_crops: Crop.where(is_reference: true).count, blueprints: CropTaskScheduleBlueprint.count })"

# JP 参照農場数
bundle exec rails runner "puts Farm.where(is_reference: true, region: 'jp').count"
```

**注意**: 開発DBのブループリント0件は**環境依存**。本番の実データでは結果が異なる。
