# 再最適化エラー修正サマリー

## エラー内容

```
再最適化に失敗しました: 調整に失敗しました: Command returned error: Error adjusting allocation: Invalid optimization result file format: 'area_used'
```

## 原因

`agrr optimize adjust`コマンドは、`agrr optimize allocate`の出力形式をそのまま受け取ることを期待していますが、`build_current_allocation`メソッドが不完全な形式を生成していました。

### 欠けていたフィールド

`field_schedules`の各要素に以下のフィールドが不足：
- `total_area`: 圃場の総面積
- `area_used`: その圃場で使用されている面積の合計

### agrr optimize adjustが期待する形式

```json
{
  "optimization_result": {
    "optimization_id": "opt_001",
    "field_schedules": [
      {
        "field_id": "field_1",
        "field_name": "圃場1",
        "total_area": 100.0,      // ← 必須（追加）
        "area_used": 50.0,        // ← 必須（追加）
        "allocations": [
          {
            "allocation_id": "alloc_001",
            "crop_id": "tomato",
            "crop_name": "トマト",
            "start_date": "2025-05-01",
            "completion_date": "2025-08-15",
            "area": 50.0,
            "revenue": 100000.0,
            "cost": 50000.0,
            "profit": 50000.0
          }
        ]
      }
    ],
    "total_profit": 50000.0
  }
}
```

## 修正内容

### 1. `build_current_allocation`メソッドの修正

**ファイル**: `app/controllers/api/v1/public_plans/cultivation_plans_controller.rb`

**変更箇所**: 105-148行目

**修正前**:
```ruby
field_schedules << {
  field_id: "field_#{field.id}",
  field_name: field.name,
  allocations: allocations
}
```

**修正後**:
```ruby
# area_usedを計算（その圃場で使用されている面積の合計）
area_used = allocations.sum { |a| a[:area] }

field_schedules << {
  field_id: "field_#{field.id}",
  field_name: field.name,
  total_area: field.area,        # 追加
  area_used: area_used,          # 追加
  allocations: allocations
}
```

### 2. area_usedの計算ロジック

- **area_used**: その圃場のすべての栽培（allocations）の面積の合計
- **計算式**: `allocations.sum { |a| a[:area] }`
- **注意**: 時間的に重複する栽培があっても、単純に合計する
  - 理由: agrrコマンドが内部で重複を考慮して検証するため

### 3. テストの追加

#### 単体テスト（Gateway）
**ファイル**: `test/gateways/agrr/adjust_gateway_format_test.rb`
- `area_used`と`total_area`が含まれることを確認
- `area_used`の計算ロジックをテスト
- JSONシリアライズが正しく動作することを確認

#### 統合テスト（Controller）
**ファイル**: `test/integration/adjust_allocation_format_test.rb`
- `build_current_allocation`が正しい形式を生成することを確認
- agrrコマンドが期待する形式と互換性があることを確認
- 複数の栽培がある場合の`area_used`計算を確認

#### Controller単体テスト
**ファイル**: `test/controllers/api/v1/public_plans/adjust_current_allocation_test.rb`
- `build_current_allocation`のprivateメソッドを直接テスト
- 単一および複数の栽培での動作を確認

## 動作確認方法

1. **ガントチャートで操作**:
   - バーをドラッグして移動
   - または右クリックで削除

2. **自動再最適化が実行される**:
   - 操作後、自動的に`/api/v1/public_plans/cultivation_plans/:id/adjust`が呼ばれる
   - バックエンドで`agrr optimize adjust`が実行される

3. **デバッグファイルで確認**:
   ```bash
   # 最新の調整用allocation.jsonを確認
   cat tmp/debug/adjust_allocation_*.json | tail -1 | python3 -m json.tool
   
   # total_areaとarea_usedが含まれていることを確認
   ```

4. **期待される動作**:
   - エラーなく再最適化が完了
   - ページがリロードされる
   - 新しい最適化結果が表示される

## 影響範囲

- **変更ファイル**: 1ファイル（controller）
- **追加テスト**: 3ファイル
- **既存コードへの影響**: なし（後方互換性あり）

## 今後の改善ポイント

1. **area_usedの精緻化**:
   - 現在は単純合計だが、時間的重複を考慮した実面積を計算することも可能
   - ただし、agrrコマンドが内部で検証するため現状で問題なし

2. **バリデーション**:
   - `area_used <= total_area`のチェックを追加することも検討可能
   - ただし、これもagrrコマンド側で検証されるため必須ではない

3. **テストの自動化**:
   - Dockerテスト環境のSQLite権限問題を解決
   - CI/CDでの自動テスト実行を確立

