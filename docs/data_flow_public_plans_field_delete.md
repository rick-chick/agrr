# public_plans 栽培スケジュール削除→圃場削除 データフロー図

## 全体フロー概観図

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    【栽培スケジュール削除→圃場削除】                           │
│                          データフロー全体図                                    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ 【1. JavaScript層 - 栽培スケジュール削除】                                    │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ ユーザーが栽培スケジュールを削除
         ▼
    ┌─────────────────┐
    │ removeCultivation│
    │   (cultivation_id) │
    └────────┬──────────┘
             │
             │ 1. ganttState.movesに追加
             │    {action: 'remove', allocation_id: id}
             │
             │ 2. ローカルUI再描画（楽観的更新）
             │
             ▼
    ┌──────────────────┐
    │executeReoptimization│
    └────────┬──────────┘
             │
             │ POST /api/.../adjust
             │ body: { moves: [...] }
             │
             ▼

┌─────────────────────────────────────────────────────────────────────────────┐
│ 【2. JavaScript層 - 圃場削除】                                                │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ ユーザーが圃場削除ボタンクリック
         ▼
    ┌────────────────┐
    │ removeField     │
    │   (field_id)    │
    └────────┬───────┘
             │
             │ 1. field_id正規化
             │    normalizeFieldId(field_id)
             │
             │ 2. field_cultivation_ids取得
             │
             ▼
    ┌────────────────────┐
    │ DELETE /api/.../   │
    │ remove_field/:id   │
    │ body: {            │
    │   field_cultivation│
    │   _ids: [...]      │
    │ }                  │
    └────────┬───────────┘
             │
             ▼

┌─────────────────────────────────────────────────────────────────────────────┐
│ 【3. Backend API層 - 検証&削除処理】                                         │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ API: remove_field
         ▼
    ┌────────────────┐
    │ 圃場存在確認    │
    └────────┬───────┘
             │
             ▼
    ┌──────────────────────────┐
    │ 栽培スケジュールチェック   │
    │ plan_field.field_cultivat │
    │ ions.any?                 │
    └────────┬─────────────────┘
             │
             ▼
    ┌────────────────────────┐
    │ 最後の圃場チェック       │
    │ fields.count <= 1      │
    └────────┬───────────────┘
             │
             ▼
    ┌──────────────────┐
    │ plan_field.destroy! │
    └────────┬──────────┘
             │
             ▼
    ┌─────────────────────────┐
    │ total_area更新           │
    │ cultivation_plan         │
    │ .update!(total_area)     │
    └────────┬────────────────┘
             │
             ▼
    ┌─────────────────────────┐
    │ adjust_with_db_weather   │
    │ moves: [{action: 'remove'│
    │         allocation_id}]  │
    └────────┬────────────────┘
             │
             ▼

┌─────────────────────────────────────────────────────────────────────────────┐
│ 【4. AGRR層 - 再最適化処理】                                                 │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ adjust_with_db_weather
         ▼
    ┌──────────────────────────┐
    │ current_allocation構築    │
    │ build_current_allocation  │
    └────────┬─────────────────┘
             │
             ▼
    ┌────────────────────────┐
    │ fields/crops設定構築    │
    │ build_fields_config     │
    │ build_crops_config      │
    └────────┬───────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │ 既存天気データ取得         │
    │ WeatherPredictionService  │
    │ .get_existing_prediction  │
    └────────┬─────────────────┘
             │
             ▼
    ┌──────────────────────┐
    │ AdjustGateway.adjust  │
    │ - current_allocation │
    │ - moves              │
    │ - fields             │
    │ - crops              │
    │ - weather_data       │
    │ - interaction_rules  │
    └────────┬─────────────┘
             │
             ▼
    ┌────────────────────┐
    │ AGRR再最適化計算    │
    │ （Python処理）      │
    └────────┬───────────┘
             │
             ▼
    ┌──────────────────────────┐
    │ save_adjusted_result      │
    │ save_to_db(result)        │
    └────────┬─────────────────┘
             │
             ▼

┌─────────────────────────────────────────────────────────────────────────────┐
│ 【5. Database層 - データ保存】                                               │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ save_adjusted_result
         ▼
    ┌──────────────────────────┐
    │ 既存FieldCultivation全削除│
    │ field_cultivations        │
    │   .destroy_all            │
    └────────┬─────────────────┘
             │
             ▼
    ┌────────────────────────┐
    │ 使用されていない作物削除│
    │ unused_crops.each       │
    │   (&:destroy)          │
    └────────┬───────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │ 新規FieldCultivation作成  │
    │ result[:field_schedules]  │
    │ .each do |field_schedule| │
    │   FieldCultivation.create │
    └────────┬─────────────────┘
             │
             ▼

┌─────────────────────────────────────────────────────────────────────────────┐
│ 【6. Action Cable層 - リアルタイム通知】                                      │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ broadcast_optimization_complete
         ▼
    ┌──────────────────────┐
    │ OptimizationChannel   │
    │ .broadcast_to         │
    │ {                     │
    │   status: 'adjusted'  │
    │   cultivation_plan_id │
    │ }                     │
    └────────┬─────────────┘
             │
             ▼ (WebSocket経由)
             │

┌─────────────────────────────────────────────────────────────────────────────┐
│ 【7. JavaScript層 - データ再取得&UI更新】                                     │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ ActionCable受信 or removeField成功
         ▼
    ┌────────────────────┐
    │ fetchAndUpdateChart│
    └────────┬───────────┘
             │
             │ GET /api/.../data
             ▼
    ┌────────────────────┐
    │ データ取得           │
    │ payload = response │
    │   .data             │
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────────┐
    │ ganttState更新          │
    │ - cultivationData      │
    │ - fields               │
    │ - fieldGroups          │
    │ - moves = []           │
    │ - removedIds = []      │
    └────────┬───────────────┘
             │
             ▼
    ┌────────────────────┐
    │ renderGanttChart    │
    │ (UI再描画)          │
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ ganttChartReady    │
    │ イベント発火        │
    └────────┬───────────┘
             │
             ▼
         ┌───────┐
         │ 完了   │
         └───────┘
```

## 詳細データ構造

### 1. JavaScript層 状態管理

```javascript
window.ganttState = {
  cultivation_plan_id: 123,
  cultivationData: [
    {
      id: 1,
      field_id: "field_100",
      field_name: "圃場A",
      crop_name: "トマト",
      start_date: "2025-01-01",
      completion_date: "2025-03-31",
      // ...
    }
  ],
  fields: [
    {
      id: 100,
      field_id: "field_100",
      name: "圃場A",
      area: 1000
    }
  ],
  fieldGroups: [...],  // 圃場ごとにグループ化
  moves: [             // 変更履歴
    {
      allocation_id: 1,
      action: 'remove'
    }
  ],
  removedIds: [1]      // 削除済みID
}
```

### 2. API リクエスト/レスポンス

#### adjust API (栽培スケジュール削除時)
```
POST /api/v1/public_plans/cultivation_plans/123/adjust

Request:
{
  "moves": [
    {
      "allocation_id": 1,
      "action": "remove"
    }
  ]
}

Response:
{
  "success": true,
  "message": "調整が完了しました"
}
```

#### remove_field API (圃場削除時)
```
DELETE /api/v1/public_plans/cultivation_plans/123/remove_field/100

Request:
{
  "field_cultivation_ids": [1, 2, 3]
}

Response:
{
  "success": true,
  "message": "圃場を削除しました",
  "field_id": 100,
  "total_area": 900
}
```

#### data API (データ取得)
```
GET /api/v1/public_plans/cultivation_plans/123/data

Response:
{
  "success": true,
  "data": {
    "fields": [...],
    "cultivations": [...],
    "crops": [...]
  },
  "totals": {
    "profit": 1000000,
    "revenue": 5000000,
    "cost": 4000000
  }
}
```

### 3. Backend 処理フロー

```
remove_field
├─ 検証処理
│  ├─ 圃場存在確認
│  ├─ 栽培スケジュールチェック
│  └─ 最後の圃場チェック
├─ DB削除
│  ├─ plan_field.destroy!
│  └─ total_area更新
└─ 再最適化
   └─ adjust_with_db_weather
      ├─ データ準備
      │  ├─ current_allocation構築
      │  ├─ fields/crops設定構築
      │  └─ 天気データ取得
      ├─ AGRR処理
      │  └─ AdjustGateway.adjust
      └─ 保存
         └─ save_adjusted_result
            ├─ 既存データ削除
            └─ 新規データ作成
```

### 4. Action Cable 通知

```ruby
# 通知内容
{
  type: 'optimization_complete',
  status: 'adjusted',
  cultivation_plan_id: 123,
  total_profit: 1000000,
  field_cultivations_count: 10
}
```

## 重要なポイント

1. **差分送信方式**: 全データを送らず、変更内容(moves)のみを送信
2. **楽観的更新**: 削除後すぐローカルUI更新、その後DB同期
3. **検証処理**: 圃場削除前に複数のビジネスロジックチェック
4. **再最適化**: 削除後に自動でAGRR再最適化を実行
5. **リアルタイム更新**: Action Cableで非同期通知
6. **データ正規化**: field_idを"field_123"形式に統一
7. **エラーハンドリング**: 各層で適切なエラー処理

## adjust API の詳細仕様

### エンドポイント
```
POST /api/v1/public_plans/cultivation_plans/:id/adjust
POST /api/v1/plans/cultivation_plans/:id/adjust
```

### リクエスト例

#### 栽培スケジュール削除時
```json
{
  "moves": [
    {
      "allocation_id": 1,
      "action": "remove"
    }
  ]
}
```

#### 栽培スケジュール移動時
```json
{
  "moves": [
    {
      "allocation_id": 1,
      "action": "move",
      "to_field_id": 100,
      "to_start_date": "2025-02-01"
    }
  ]
}
```

### レスポンス例

#### 成功時
```json
{
  "success": true,
  "message": "調整が完了しました",
  "cultivation_plan": {
    "id": 123,
    "total_profit": 1000000,
    "field_cultivations_count": 10
  }
}
```

#### 失敗時
```json
{
  "success": false,
  "message": "調整に失敗しました: {エラー詳細}",
  "status": 500
}
```

### API処理フロー

```ruby
def adjust
  # 1. 計画取得
  @cultivation_plan = find_api_cultivation_plan
  
  # 2. movesパラメータを受信・検証
  moves_raw = params[:moves] || []
  
  # 3. パラメータ変換（型統一）
  moves = moves_raw.map do |move|
    move.symbolize_keys
  end.map do |move|
    # allocation_id, to_field_idを数値に変換
    move[:allocation_id] = move[:allocation_id].to_i if move[:allocation_id]
    move[:to_field_id] = move[:to_field_id].to_i if move[:to_field_id]
    move
  end
  
  # 4. 再最適化実行
  result = adjust_with_db_weather(@cultivation_plan, moves)
  
  # 5. レスポンス返却
  render json: result
end
```

### adjust_with_db_weather処理

1. **空の移動チェック**: `moves.empty?` → スキップ
2. **割り当てデータ構築**: `build_current_allocation`
3. **設定構築**: `build_fields_config`, `build_crops_config`
4. **天気データ取得**: 既存データを再利用
5. **AGRR実行**: `AdjustGateway.adjust`
6. **結果保存**: `save_adjusted_result`
7. **通知送信**: `broadcast_optimization_complete`

### AdjustGateway.adjust パラメータ

```ruby
adjust_gateway.adjust(
  current_allocation: {...},    # 現在の割り当て
  moves: [...],                 # 移動指示
  fields: {...},                # 圃場設定
  crops: {...},                 # 作物設定
  weather_data: {...},          # 天気データ
  planning_start: Date,         # 計画開始日
  planning_end: Date,           # 計画終了日
  interaction_rules: {...},     # 交互作用ルール（オプション）
  objective: 'maximize_profit', # 目的関数
  enable_parallel: true         # 並列処理
)
```

## 処理時間目安

- JavaScript処理: 1-5ms
- API処理: 10-50ms
- DB削除: 10-20ms
- AGRR再最適化: 1000-5000ms
- データ保存: 50-200ms
- Action Cable送信: 5-10ms
- **合計: 約1.1-5.3秒**

