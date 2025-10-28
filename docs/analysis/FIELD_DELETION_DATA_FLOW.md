# Public Plans 圃場削除時のデータ移送フロー解析

## 概要
public_plansで栽培スケジュールを削除する圃場を削除する際のデータ移送をコンポーネントごとに解析した結果をまとめます。

## コンポーネント構成

### 1. フロントエンド（JavaScript）
- **ファイル**: `app/assets/javascripts/custom_gantt_chart.js`
- **主要関数**: `removeField()`, `getFieldCultivationIds()`, `removeCultivation()`

### 2. API層（Controller）
- **ファイル**: `app/controllers/concerns/cultivation_plan_api.rb`
- **主要メソッド**: `remove_field()`

### 3. 最適化エンジン（AGRR）
- **ファイル**: `app/controllers/concerns/agrr_optimization.rb`
- **主要メソッド**: `adjust_with_db_weather()`, `build_current_allocation()`

### 4. AGRR調整ゲートウェイ
- **ファイル**: `app/gateways/agrr/adjust_gateway.rb`
- **主要メソッド**: `adjust()`

### 5. データベース層
- **ファイル**: `app/controllers/concerns/agrr_optimization.rb`
- **主要メソッド**: `save_adjusted_result()`

## データ移送フロー

### Phase 1: フロントエンドでの圃場削除準備
1. **ユーザー操作**: ガントチャートで圃場削除ボタンをクリック
2. **圃場ID正規化**: `normalizeFieldId()`で圃場IDを統一形式に変換
3. **栽培スケジュールID収集**: `getFieldCultivationIds()`で削除対象圃場内の栽培スケジュールIDを取得
4. **削除操作記録**: `window.ganttState.moves`に削除操作を記録

### Phase 2: APIリクエスト送信
1. **HTTP DELETE リクエスト**: `/api/v1/public_plans/cultivation_plans/:id/remove_field/:field_id`
2. **リクエストボディ**: `{ field_cultivation_ids: [栽培スケジュールID配列] }`
3. **CSRF トークン**: セキュリティ認証

### Phase 3: API層での検証・削除
1. **圃場存在確認**: `CultivationPlanField`の存在チェック
2. **削除可能性検証**:
   - 圃場に栽培スケジュールが存在する場合は削除不可
   - 最後の圃場は削除不可
3. **圃場削除**: `plan_field.destroy!`
4. **総面積更新**: `total_area`を再計算
5. **調整指示作成**: 削除された栽培スケジュールの`moves`配列を作成

### Phase 4: 最適化エンジンでの調整処理
1. **現在の割り当て構築**: `build_current_allocation()`でAGRR形式に変換
2. **圃場・作物設定構築**: `build_fields_config()`, `build_crops_config()`
3. **天気データ取得**: DBに保存された天気データを再利用
4. **AGRR調整実行**: `AdjustGateway.adjust()`でPython最適化エンジンを呼び出し

### Phase 5: AGRR調整ゲートウェイ
1. **ファイル作成**: 各種設定ファイルを一時ファイルとして作成
2. **Pythonコマンド実行**: `agrr optimize adjust`コマンドを実行
3. **結果パース**: JSON形式の調整結果をパース

### Phase 6: データベース更新
1. **既存データ削除**: `cultivation_plan.field_cultivations.destroy_all`
2. **新しい栽培スケジュール作成**: AGRR結果に基づいて`FieldCultivation`を再作成
3. **未使用作物削除**: 使われていない`CultivationPlanCrop`をクリーンアップ
4. **最適化結果更新**: `total_profit`, `total_revenue`, `total_cost`などを更新

### Phase 7: フロントエンド通知
1. **ActionCable通知**: `OptimizationChannel`経由で圃場削除完了を通知
2. **UI更新**: ガントチャートの表示を更新
3. **ローディング解除**: 処理完了フラグをリセット

## データ移送の詳細

### フロントエンド → API
```javascript
{
  field_cultivation_ids: [123, 456, 789]  // 削除対象の栽培スケジュールID
}
```

### API → 最適化エンジン
```ruby
moves = [
  { allocation_id: 123, action: 'remove' },
  { allocation_id: 456, action: 'remove' },
  { allocation_id: 789, action: 'remove' }
]
```

### 最適化エンジン → AGRR
```ruby
current_allocation = {
  field_schedules: [
    {
      field_id: 1,
      allocations: [
        {
          allocation_id: 123,
          crop_id: "crop_1",
          area_used: 100.0,
          start_date: "2024-01-01",
          completion_date: "2024-03-31",
          profit: 50000.0
        }
      ]
    }
  ]
}
```

### AGRR → データベース
```ruby
result = {
  field_schedules: [
    {
      field_id: 2,  # 削除された圃場以外の圃場
      allocations: [
        {
          allocation_id: 123,
          crop_id: "crop_1",
          area_used: 100.0,
          start_date: "2024-01-01",
          completion_date: "2024-03-31",
          profit: 50000.0
        }
      ]
    }
  ],
  total_profit: 150000.0,
  total_revenue: 200000.0,
  total_cost: 50000.0
}
```

## 重要なポイント

### 1. データ整合性の保証
- **トランザクション処理**: `ActiveRecord::Base.transaction`で原子性を保証
- **重複チェック**: `allocation_id`の重複を検出してエラーを防止
- **キャッシュクリア**: `cultivation_plan.reload`でダブル送信対策

### 2. パフォーマンス最適化
- **天気データ再利用**: DBに保存された天気データを再利用してAPI呼び出しを削減
- **並列処理**: AGRRエンジンで`enable_parallel: true`を設定
- **ファイルベース通信**: 一時ファイル経由でPythonプロセスと通信

### 3. エラーハンドリング
- **段階的検証**: フロントエンド、API、最適化エンジン各段階でエラーチェック
- **ロールバック**: エラー時はデータベースの状態を元に戻す
- **ユーザーフレンドリー**: 日本語のエラーメッセージを提供

### 4. リアルタイム通知
- **ActionCable**: WebSocket経由でリアルタイム更新
- **チャンネル分離**: `OptimizationChannel`（public_plans用）と`PlansOptimizationChannel`（private plans用）を分離

## セキュリティ考慮事項

### 1. CSRF保護
- **トークン検証**: `X-CSRF-Token`ヘッダーでCSRF攻撃を防止

### 2. 権限チェック
- **計画所有権**: `find_api_cultivation_plan`でユーザーの所有する計画のみアクセス可能

### 3. 入力検証
- **型変換**: `field_id`を整数に変換してSQLインジェクションを防止
- **存在確認**: 圃場と栽培スケジュールの存在を事前に確認

## まとめ

public_plansでの圃場削除処理は、フロントエンドからデータベースまで5つのコンポーネントが連携して動作する複雑なシステムです。各コンポーネントは明確な責任を持ち、データの整合性とパフォーマンスを両立させています。特に、AGRR最適化エンジンとの連携により、圃場削除後の栽培スケジュールを自動的に最適化し直す仕組みが実装されています。
