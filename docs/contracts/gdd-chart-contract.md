# Feature Contract: Plan Detail GDD Chart（Angular）

**作成日**: 2026-02-03  
**作成者**: GPT-5.1 Codex Mini  
**機能概要**: Rails版ガントチャートと同じ「気温・GDD分析チャート」をAngular版作付計画詳細で再現し、作物選択時に当該圃場のGDD推移・要求GDDを明示して意思決定を支援する。  
**ステータス**: draft

## ビジネス要件

- Rails版と同様に、作付計画をクリックした（Angular上のガントチャート内の栽培帯を選択した）ユーザーに対し、日別気温、累積GDD、要求GDD、成長ステージを可視化したチャートを提示する。
- 作物ごとの気象解析結果（GDDとステージ閾値）を、作付計画の「詳細パネル」内で即時表示し意思決定を支援する。
- API契約とUI間のレスポンス/エラー形式を明確にして、バックエンド/フロントエンドの並列実装が可能な状態にする。

## 技術要件

- 既存の `GET /api/v1/plans/field_cultivations/:id/climate_data`（および public plan 用 `GET /api/v1/public_plans/field_cultivations/:id/climate_data`）をAngular側で再利用し、Cloud Socket API 呼び出しを新たに追加しない。
- GDDチャートは Chart.js 相当のコンポーネントで描画し、日付軸・ステージ域・累積/日別GDD / 要求GDD・温度データを含む複数系列の線グラフとして構成する。
- APIレスポンスの各プロパティ（`weather_data`, `gdd_data`, `stages`, `crop_requirements` など）を型定義し、Angularの UseCase/Presenter を経由してビューへ渡す。
- エラー時には統一的なエラートーストやフェイルセーフ表示を出し、ユーザーに再試行手段を示す。

## Use Case: Field Cultivation Climate Chart

### 概要
Angular版作付計画詳細画面で、ユーザーが表示された栽培帯（Gantt内の作物バーまたは一覧）の「気象/成長チャートを表示」アクションを実行すると、該当 `field_cultivation_id` に紐づく気象・積算温度データをロードしチャートを描画する。

### アクター
- **Primary Actor**: `PlanDetailComponent`を閲覧するログイン済みユーザー
- **Supporting Actors**: `GanttChartComponent`（選択イベント伝搬）、`PlanService`（API呼び出し）、`PlanDetailPresenter`/新規 `ClimateChartPresenter`

### 事前条件
- Angular 側で `LoadPlanDetailUseCase` により `CultivationPlanData` が取得済みで、`CultivationData.id` が対応する `field_cultivation_id` として利用可能である。
- APIトークン/セッションによって `field_cultivation` にアクセスする権限が存在し、該当計画が private plan/ public plan 両方で正しく識別されている。
- Rails 側で `FieldCultivation#start_date` `#completion_date` が設定済み。

### 基本フロー
1. ユーザーが Angular ガントチャート上の作物バーまたは一覧項目をクリックし、対象 `cultivation.id` を `ClimateChartComponent`（仮称）に委譲する。
2. `PlanDetailUseCase` または専用 `LoadFieldClimateUseCase` が `PLAN_GATEWAY.fetchFieldClimateData(planType, fieldCultivationId)` を呼び出す。
3. Gateway が Angular router のコンテキスト（`planType` ＝ 'private' / 'public'）からエンドポイントを組み立てて `GET /api/v1/{public_}plans/field_cultivations/:id/climate_data` を叩く。
4. API が `success: true` かつ `gdd_data`, `weather_data`, `stages` 等を含む JSON を返し、Presenter が Chart.js コンポーネントに渡す。
5. チャートが画面上に表示され、日別気温、日別GDD、累積GDD、要求GDD、ステージ境界などの系列／アノテーションを描画する。
6. チャートを閉じる操作（閉じるボタン／バー外クリック）でチャートコンテナ領域が隠れ、再度別のバーを選んだときには APIを再度取得する。

### 代替フロー
- **Alt-1**: APIが `success: false` を返した場合、Presenter はユーザーへエラーメッセージを表示し、チャート領域には再試行ボタンを表示する。
- **Alt-2**: Chart.js の描画処理が失敗した場合、チャート領域には「データの解析に失敗しました」などのフォールバック UI を出し、エラーログを残す。

### 例外フロー
- **Exc-1**: `field_cultivation` が存在しない、またはユーザーがアクセス権を持たない場合 → Rails は 404 を返し Angular 側は `NotFound` 相当のエラーメッセージを表示。
- **Exc-2**: `start_date` もしくは `completion_date` が欠けている場合 → Rails は 400 を返し `controllers.field_cultivations.errors.no_cultivation_period` を返す。
- **Exc-3**: 天気情報が存在しない（`farm.weather_location` が nil）の場合 → Rails は 404。
- **Exc-4**: AGRR Progress Gateway の実行が失敗した場合は 500。

### 事後条件
- Angular 側で該当 `field_cultivation_id` に対応するチャートデータが表示済みになる。
- 読み込みエラーが発生した場合、ユーザーに再読み込み／閉じる操作が提示される。

## API Specification

| メソッド | パス | 説明 |
|----------|------|------|
| GET | `/api/v1/plans/field_cultivations/:id/climate_data` | プライベート計画の作付圃場ごとの気象＆GDDデータ |
| GET | `/api/v1/public_plans/field_cultivations/:id/climate_data` | 公開計画の同等データ（`planType` が `public` のときに使用） |

### Request（共通）
- Path Parameter: `id` (integer, required)
- Headers: `Content-Type: application/json`, `Authorization: Bearer <token>`

### Success Response (200)

```json
{
  "success": true,
  "field_cultivation": {
    "id": 1,
    "field_name": "北区 北圃場",
    "crop_name": "トマト",
    "start_date": "2026-02-01",
    "completion_date": "2026-05-30"
  },
  "farm": {
    "id": 2,
    "name": "横浜ファーム",
    "latitude": 35.4,
    "longitude": 139.6
  },
  "crop_requirements": {
    "base_temperature": 12.0,
    "optimal_temperature_range": {
      "min": 18.0,
      "max": 28.0,
      "low_stress": 15.0,
      "high_stress": 33.0
    }
  },
  "weather_data": [
    {
      "date": "2026-02-01",
      "temperature_max": 20.5,
      "temperature_min": 9.3,
      "temperature_mean": 14.9
    }
  ],
  "gdd_data": [
    {
      "date": "2026-02-01",
      "gdd": 2.9,
      "cumulative_gdd": 2.9,
      "temperature": 14.9,
      "current_stage": "播種〜発芽"
    }
  ],
  "stages": [
    {
      "name": "播種〜発芽",
      "order": 1,
      "gdd_required": 75.0,
      "cumulative_gdd_required": 75.0,
      "optimal_temperature_min": 18.0,
      "optimal_temperature_max": 28.0,
      "low_stress_threshold": 15.0,
      "high_stress_threshold": 33.0
    }
  ],
  "progress_result": { /* agrr progressの生データ */ },
  "debug_info": {
    "baseline_gdd": 0.0,
    "progress_records_count": 90,
    "filtered_records_count": 90,
    "using_agrr_progress": true,
    "sample_raw_data": [{ "date": "2026-02-01", "cumulative_gdd": 2.9 }]
  }
}
```

### Error Responses

- **400 Bad Request**: `{"success": false, "message": "栽培期間が設定されていません"}`（`start_date` / `completion_date` が nil）
- **404 Not Found**: `{"success": false, "message": "項目が見つかりません"}`（認可エラー / 天気データなし）
- **500 Internal Server Error**: `{"success": false, "message": "AGRR Progress の計算に失敗しました"}`（Gateway実行失敗）

## データモデル

### TypeScript（フロント）

- `frontend/src/app/domain/plans/field-cultivation-climate-data.ts`
```ts
export interface ClimateTemperaturePoint {
  date: string;
  temperature_max?: number;
  temperature_min?: number;
  temperature_mean?: number;
}

export interface ClimateGddPoint {
  date: string;
  gdd: number;
  cumulative_gdd: number;
  temperature?: number;
  current_stage?: string | null;
}

export interface StageRequirement {
  name: string;
  order: number;
  gdd_required: number;
  cumulative_gdd_required: number;
  optimal_temperature_min?: number;
  optimal_temperature_max?: number;
  low_stress_threshold?: number;
  high_stress_threshold?: number;
}

export interface FieldCultivationClimateData {
  success: boolean;
  field_cultivation: { id: number; field_name: string; crop_name: string; start_date: string; completion_date: string };
  farm: { id: number; name: string; latitude: number; longitude: number };
  crop_requirements: {
    base_temperature: number;
    optimal_temperature_range?: {
      min: number;
      max: number;
      low_stress: number;
      high_stress: number;
    } | null;
  };
  weather_data: ClimateTemperaturePoint[];
  gdd_data: ClimateGddPoint[];
  stages: StageRequirement[];
  progress_result: Record<string, unknown>;
  debug_info: Record<string, unknown>;
}
```

- UseCase / Presenter / Component はこの型を参照して Chart.js のデータセットを組み立てる。

### Ruby（サーバー）

- `app/controllers/api/v1/plans/field_cultivations_controller.rb` および `app/controllers/api/v1/public_plans/field_cultivations_controller.rb` が `FieldCultivation` オブジェクトに対して `climate_data` を返却。
- `daily_gdd` を `generate_mock_progress_records`（テスト環境）または `Agrr::ProgressGateway#calculate_progress` から構成。
- `stages` は `crop.crop_stages` から抽出した `TemperatureRequirement`/`ThermalRequirement` の `required_gdd`・`optimal_min/max` を累積した配列。
- `weather_data` は `WeatherPredictionService` から整形され、`temperature_mean`/`max`/`min` を日付付きで返す。

## Implementation Tasks

### Phase 1: UseCase層実装（並列）
- [ ] `usecase-server` スキルで `FieldCultivationClimateData` を返す Interactor/UseCase を実装し、`field_cultivation` に対する認可・エラーハンドリングを担保。
- [ ] `usecase-frontend` スキルで `LoadFieldClimateUseCase`（仮称）を追加し、`PLAN_GATEWAY` にチャート用メソッドを定義。Presenter はチャートコンポーネントに `FieldCultivationClimateData` を渡す。

### Phase 2: Adapter層実装（並列）
- [ ] `presenter-server` スキルで JSONレスポンスの整形を担当する Presenter を実装（`success`フラグと `debug_info` を付与）。
- [ ] `gateway-server` スキルで `FieldCultivationClimateGateway` を追加し `Agrr::ProgressGateway` の戻り値を整形。
- [ ] `controller-server` スキルで `/field_cultivations/:id/climate_data` エンドポイントを定義し、エラーハンドリングとステージデータの構築を記述。
- [ ] `presenter-frontend` スキルでチャート表示用の Presenter を作成し、エラー・ローディング状態を扱う。
- [ ] `gateway-frontend` スキルで `PlanApiGateway` の新メソッド `fetchFieldClimateData` を実装し、`planType` に応じて API URL を切り分ける。
- [ ] `controller-frontend` スキルで `ClimateChartComponent`（または既存の PlanDetailComponent）にイベントハンドラとチャート描画ロジックを追加。

### Phase 3: テスト実装
- [ ] Rails の `FieldCultivationClimateDataInteractor` と Controller の統合テストを追加。
- [ ] Angular の `LoadFieldClimateUseCase` / Presenter / Component のユニットテストを作成。
- [ ] End-to-End で Gantt Chart クリック → Chart 表示までのフローを簡易検証（必要なら Storybook）。

### Phase 4: 検証
- [ ] API契約通りのレスポンスとエラーコードが返るか（`rails test` / Postman）。
- [ ] Angular チャートがエラー・ローディング状態でも UI を破綻させないか。
- [ ] Chart 描画性能（100日分のデータ）でボトルネックが出ないか。

## Review Points

### 機能要件
- [ ] Gantt Chart から作物を選択したタイミングでチャートが開き、適切な `field_cultivation_id` のデータを取得しているか。
- [ ] GDD/ステージ/温度の系列が正しく描画される（昇順・累積差分など）。
- [ ] エラーメッセージや閉じる操作など UX が Rails 実装と同等の品質になっているか。

### 技術要件
- [ ] API の `success`, `debug_info`, `progress_result` などのキー名が Rails と一致し、 Angular 型定義もそれに追従しているか。
- [ ] Chart.js のキャンバス再描画（ウィンドウリサイズ・閉じる）処理が安定しているか。

### 設計品質
- [ ] Clean Architecture 層（UseCase / Gateway / Presenter / Controller）に責務が分離されているか。
- [ ] API依存部分（URL・クラウドトークン・JSONスキーマ）が定数化されており、再利用できるか。
- [ ] テスト可能な構造（DI された Gateway / Presenter / UseCase）になっているか。

## Change History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-02-03 | 1.0 | GPT-5.1 Codex Mini | Initial draft for Angular GDD chart feature |
