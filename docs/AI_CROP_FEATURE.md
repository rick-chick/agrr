# 🤖 AI作物情報取得機能

## 📋 概要

作物名を入力するだけで、AIが自動的に以下の情報を取得して保存する機能です：
- 単位あたりの面積（㎡）
- 面積あたりの収益（円/㎡）
- 生育ステージ情報（将来実装予定）

## ✨ 実装内容

### 重要な仕様

**agrr_crop_idによる作物の識別:**
- agrrが返す `crop_id` をデータベースの `agrr_crop_id` カラムに保存
- 更新時は `agrr_crop_id` で検索（名前ではなくIDで正確に識別）
- 参照作物・ユーザー作物に関係なく、同じagrr_crop_idなら更新

**更新 vs 新規作成:**
1. `agrr_crop_id` で検索 → 見つかれば**更新**
2. 見つからない場合、名前で検索（参照作物 OR そのユーザーの作物） → 見つかれば**更新**
3. どちらでも見つからない → **新規作成**

### 1. バックエンド

#### APIエンドポイント
```
POST /api/v1/crops/ai_create
```

**リクエスト:**
```json
{
  "name": "トマト",
  "variety": "アイコ"  // オプション
}
```

**レスポンス（成功時）:**
```json
{
  "success": true,
  "crop_id": 123,
  "crop_name": "トマト",
  "variety": "アイコ",
  "area_per_unit": 0.2,
  "revenue_per_area": 1500.0,
  "message": "AIで作物「トマト」の情報を取得して保存しました"
}
```

**レスポンス（エラー時）:**
```json
{
  "error": "作物名を入力してください"
}
```

#### 実装ファイル
- `app/controllers/api/v1/crops_controller.rb` - APIコントローラー
- `config/routes.rb` - ルート定義

#### 処理フロー
1. 作物名を受け取る
2. `agrr crop crop --query "作物名" --json` を実行
3. 取得したJSONをパース（`crop_id`, `area_per_unit`, `revenue_per_area`, `stages`）
4. **agrr_crop_idで既存作物を検索**
   - 見つかった → **更新**（参照作物でもユーザー作物でも）
   - 見つからない → 名前で検索
     - 見つかった → **更新** + agrr_crop_idを設定
     - 見つからない → **新規作成**
5. 生育ステージも保存/更新
6. レスポンスを返す

#### agrrコマンドの実行
```ruby
agrr_path = Rails.root.join('lib', 'core', 'agrr').to_s
command = [
  agrr_path,
  'crop',
  'crop',
  '--query', crop_name,
  '--json'
]
stdout, stderr, status = Open3.capture3(*command)
```

#### ログ出力（更新の場合）
```
🤖 [AI Crop] Querying crop info for: トマト
🔧 [AGRR Crop Query] /app/lib/core/agrr crop crop --query トマト --json
📥 [AGRR Crop Output] {"success": true, "data": {...}}
📊 [AGRR Crop Data] Retrieved data: agrr_id=トマト, area=0.2, revenue=1500.0, stages=4
🔄 [AI Crop] Existing crop found: トマト (DB_ID: 14, agrr_id: トマト, is_reference: true)
🔄 [AI Crop] Updating crop with latest data from agrr
🌱 [AI Crop] Updated 4 stages for crop#14
```

#### ログ出力（新規作成の場合）
```
🤖 [AI Crop] Querying crop info for: ピーマン
🔧 [AGRR Crop Query] /app/lib/core/agrr crop crop --query ピーマン --json
📊 [AGRR Crop Data] Retrieved data: agrr_id=ピーマン, area=0.15, revenue=800.0, stages=3
🆕 [AI Crop] Creating new crop: ピーマン (agrr_id: ピーマン)
✅ [AI Crop] Created crop#25: ピーマン
🌱 [AI Crop] Saved 3 stages for crop#25
```

### 2. フロントエンド

#### JavaScriptコントローラー
- `app/javascript/controllers/crop_ai_controller.js` - Stimulus controller

#### ユーザーインターフェース
- `app/views/crops/_form.html.erb` - 作物フォーム

#### 処理フロー
1. 作物名を入力
2. 「🤖 AIで作物情報を取得・保存」ボタンをクリック
3. `POST /api/v1/crops/ai_create` を呼び出し
4. 成功メッセージを表示
5. 作物詳細ページにリダイレクト

## 🚀 使い方

### Webブラウザから

1. `/crops/new` にアクセス
2. 作物名を入力（例：トマト）
3. 品種を入力（オプション、例：アイコ）
4. 「🤖 AIで作物情報を取得・保存」ボタンをクリック
5. 自動的に情報が取得・保存されます

### APIから

```bash
curl -X POST http://localhost:3000/api/v1/crops/ai_create \
  -H "Content-Type: application/json" \
  -d '{"name":"トマト","variety":"アイコ"}'
```

### コマンドラインから（デバッグ用）

```bash
# Dockerコンテナ内で実行
docker-compose exec web /app/lib/core/agrr crop crop --query "トマト" --json
```

## 🧪 テスト

### 統合テスト
- `test/integration/crop_ai_create_test.rb`

### テスト実行
```bash
docker compose run --rm test bundle exec rails test test/integration/crop_ai_create_test.rb
```

### テストケース
1. ✅ APIエンドポイントが存在する
2. ✅ 作物名が必須
3. ✅ AI情報を取得して保存できる
4. ✅ 品種を指定できる
5. ✅ user_idが正しく保存される
6. ✅ エラーハンドリングが適切

## 📊 agrrコマンドの出力例

```json
{
  "success": true,
  "data": {
    "crop_id": "トマト",
    "crop_name": "トマト",
    "variety": null,
    "area_per_unit": 0.2,
    "revenue_per_area": 1500.0,
    "stages": [
      {
        "name": "育苗期",
        "order": 1,
        "temperature": {
          "base_temperature": 10.0,
          "optimal_min": 18.0,
          "optimal_max": 30.0,
          "low_stress_threshold": 12.0,
          "high_stress_threshold": 35.0,
          "frost_threshold": 0.0,
          "sterility_risk_threshold": null
        },
        "sunshine": {
          "minimum_sunshine_hours": 6.0,
          "target_sunshine_hours": 8.0
        },
        "thermal": {
          "required_gdd": 300.0
        }
      },
      // ... 他のステージ
    ]
  }
}
```

## 🔧 デバッグ

### ログの確認
```bash
# すべてのログ
docker-compose logs -f web

# AI作物ログのみ
docker-compose logs -f web | grep -E "(AI Crop|AGRR Crop)"
```

### agrrコマンドの直接実行
```bash
docker-compose exec web /app/lib/core/agrr crop crop --query "トマト" --json | python3 -m json.tool
```

### Railsコンソールで確認
```bash
docker-compose exec web rails console
```

```ruby
# 最後に作成された作物
crop = Crop.last
puts "Name: #{crop.name}"
puts "Area: #{crop.area_per_unit}"
puts "Revenue: #{crop.revenue_per_area}"
```

## 🐛 トラブルシューティング

### 問題1: agrrコマンドが見つからない

**症状:**
```
Failed to query crop info from agrr: No such file or directory
```

**確認:**
```bash
docker-compose exec web ls -la /app/lib/core/agrr
```

**対処:**
```bash
# 権限を確認
docker-compose exec web chmod +x /app/lib/core/agrr
```

### 問題2: JSON解析エラー

**症状:**
```
JSON::ParserError: unexpected token
```

**確認:**
agrrコマンドの出力を確認
```bash
docker-compose exec web /app/lib/core/agrr crop crop --query "トマト" --json
```

### 問題3: データが保存されない

**確認:**
- Railsログでエラーを確認
- データベースのバリデーションエラーを確認

```ruby
# Railsコンソール
crop = Crop.new(name: "トマト", area_per_unit: 0.2)
crop.valid?
crop.errors.full_messages
```

## 🎯 将来の拡張

### 生育ステージの保存
現在はコメントアウトされていますが、将来的に実装予定：

```ruby
def save_crop_stages(crop_id, stages_data)
  stages_data.each do |stage|
    CropStage.create!(
      crop_id: crop_id,
      name: stage['name'],
      order: stage['order'],
      # ... 温度・日照・熱量要件
    )
  end
end
```

### 対応作物の拡充
agrrコマンド側で対応作物を増やす

### キャッシュの実装
同じ作物の情報を繰り返し取得しないようキャッシュ

## 📝 関連ドキュメント

- [デバッグガイド](DEBUG_GUIDE.md)
- [テストガイド](TEST_GUIDE.md)
- [API仕様](../README.md#api-エンドポイント)

## ✅ チェックリスト

実装完了:
- [x] バックエンドAPIエンドポイント
- [x] agrrコマンドの統合
- [x] フロントエンドUI
- [x] エラーハンドリング
- [x] ログ出力
- [x] 統合テスト
- [x] ドキュメント

今後の課題:
- [ ] 生育ステージの保存
- [ ] キャッシュ機能
- [ ] 対応作物の拡充
- [ ] システムテスト（E2E）

