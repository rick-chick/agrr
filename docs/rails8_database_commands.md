# Rails 8 データベースコマンド完全ガイド

## Rails 8の主要なデータベースコマンド

### 1. rails db:prepare（推奨 - 本番環境）

**AGRRで使用中**: `scripts/start_app.sh`の35行目

```bash
bundle exec rails db:prepare
```

**動作**:
```ruby
if database_exists?
  # データベースがある場合
  run_migrations  # ← マイグレーション実行
else
  # データベースがない場合
  create_database
  load_schema     # schema.rbから読み込み（高速）
end

# シードは実行されない
```

**特徴**:
- ✅ 冪等性がある（何度実行しても安全）
- ✅ 本番環境に最適（スキーマロードが高速）
- ✅ マイグレーション履歴を保持
- ❌ シードは実行されない

**使用場面**:
- 本番環境の起動時
- CI/CDパイプライン
- コンテナ起動時

### 2. rails db:setup（初回のみ）

```bash
bundle exec rails db:setup
```

**動作**:
```ruby
create_database
load_schema      # schema.rbから読み込み
run_seeds        # ← db:seedを実行
```

**特徴**:
- ✅ シードも実行される
- ✅ 初回セットアップに便利
- ⚠️ 既存のデータベースでは使用不可（エラー）

**使用場面**:
- 開発環境の初回セットアップ
- 新しいチームメンバーのオンボーディング

### 3. rails db:seed（シードのみ）

```bash
bundle exec rails db:seed
```

**動作**:
```ruby
# db/seeds.rbを実行
load 'db/seeds.rb'
```

**特徴**:
- ✅ 冪等性がある（適切に書かれていれば）
- ✅ マイグレーションは実行されない
- ✅ 何度でも実行可能（AGRRの場合）

**使用場面**:
- 参照データの更新
- 本番環境へのデータ投入
- テストデータの再投入

### 4. rails db:reset（開発環境のみ）

```bash
bundle exec rails db:reset
```

**動作**:
```ruby
drop_database
create_database
load_schema
run_seeds
```

**特徴**:
- ⚠️ すべてのデータが削除される
- ✅ クリーンな状態から再構築
- ❌ 本番環境では絶対に使用禁止

**使用場面**:
- 開発環境のデータリセット
- テストデータの再生成

### 5. rails db:migrate（マイグレーションのみ）

```bash
bundle exec rails db:migrate
```

**動作**:
```ruby
run_pending_migrations  # 未適用のマイグレーションのみ
update_schema_rb        # schema.rbを更新
```

**特徴**:
- ✅ 古典的な方法（Rails 1.x〜）
- ✅ マイグレーション履歴を保持
- ❌ schema.rbがないと使えない（初回）

**使用場面**:
- ローカル開発でのマイグレーション適用
- `db:prepare`の代替

## Rails 8での推奨パターン

### 開発環境

```bash
# 初回セットアップ
bin/rails db:setup

# 日常的な開発
bin/rails db:migrate  # または db:prepare
bin/rails db:seed     # 必要に応じて

# リセット
bin/rails db:reset
```

### 本番環境（AGRRの場合）

```bash
# コンテナ起動時（自動）
bin/rails db:prepare  # ← start_app.shで自動実行

# シード（手動）
bin/rails db:seed     # ← 意図的なタイミングで実行
```

## AGRRの設計判断

### なぜstart_app.shでdb:prepareを使うのか？

#### 理由1: マイグレーションの自動適用

```
デプロイフロー:
1. 新しいコードがデプロイされる
2. コンテナが起動する
3. start_app.shが実行される
4. db:prepareでマイグレーション自動実行 ✅
5. アプリケーション起動

→ マイグレーションを別途実行する必要がない
```

#### 理由2: データベースがない場合の自動作成

```
初回デプロイ時:
1. GCSからデータベースを復元できない
2. db:prepareがデータベースを作成
3. schema.rbから構造を復元
4. 正常に起動

→ 手動でdb:createする必要がない
```

#### 理由3: 冪等性

```
2回目以降のデプロイ:
1. GCSからデータベースを復元
2. db:prepareでマイグレーションのみ実行
3. 既存データは保持
4. スキーマは最新に更新

→ 何度デプロイしても安全
```

### なぜシードをコメントアウトするのか？

#### 理由1: 起動時間の短縮

```
シード実行時間:
- 天気データ投入: 10-30秒
- 作物データ投入: 5-10秒
- 合計: 15-40秒

Cloud Runの制約:
- 起動タイムアウト: 60秒
- ヘルスチェック: 40秒以内に応答必要

→ シード実行で起動が遅延するリスク
```

#### 理由2: データ更新の制御

```ruby
# シードは属性を更新する
crop.update!(
  groups: crop_data['groups'],
  area_per_unit: crop_data['area_per_unit'],
  revenue_per_area: crop_data['revenue_per_area']
)

# 本番環境では：
# - 意図しないデータ更新を避けたい
# - データ更新のタイミングを制御したい
# - ログで確認したい

→ 手動実行にしている
```

#### 理由3: 条件分岐の不完全性

```bash
# データが空かどうかのチェック
if bundle exec rails runner "exit(User.count == 0 ? 0 : 1)"

# 問題点：
# - User.count == 0 でもFarmやCropは存在する可能性
# - 部分的にデータがある場合の判定が難しい

→ 手動実行の方が安全
```

## 冪等性のベストプラクティス

### Good: 冪等なシード

```ruby
# ✅ find_or_create_by!を使用
User.find_or_create_by!(email: 'admin@example.com') do |user|
  user.name = 'Admin'
  user.admin = true
end

# ✅ 複合キーで一意性を保証
InteractionRule.find_or_create_by!(
  rule_type: 'continuous_cultivation',
  source_group: 'Solanaceae',
  target_group: 'Solanaceae',
  region: 'jp'
) do |rule|
  rule.impact_ratio = 0.6
  rule.description = '...'
end

# ✅ 既存レコードも更新（常に最新）
crop.update!(
  groups: latest_data['groups'],
  area_per_unit: latest_data['area_per_unit']
)
```

### Bad: 冪等でないシード

```ruby
# ❌ 毎回新しいレコードが作成される
User.create!(email: 'admin@example.com', name: 'Admin')

# ❌ 重複チェックなし
Farm.create!(name: '北海道', is_reference: true)

# ❌ 条件なしで更新
Crop.all.update_all(region: 'jp')  # 全ユーザーデータも更新される！
```

## 実装の改善提案

### 現在のstart_app.sh

```bash
# Step 3: コメントアウト
echo "Step 3: Seed disabled for now (run manually after startup if needed)"
```

### 提案: 環境変数で制御

```bash
# Step 3: 環境変数で制御
echo "Step 3: Seed configuration..."

if [ "$RAILS_ENV" = "production" ]; then
    # 本番環境: データが空の場合のみ最小限のシード
    if bundle exec rails runner "exit(User.count == 0 ? 0 : 1)" 2>/dev/null; then
        echo "⚠️  Empty database detected. Creating admin user only..."
        bundle exec rails runner "User.find_or_create_by!(google_id: 'dev_user_001') { |u| u.email = 'admin@example.com'; u.admin = true }"
        echo "✅ Admin user created. Run 'rails db:seed' manually for full data."
    else
        echo "Database has data. Skipping auto-seed."
    fi
else
    # 開発環境: データが空なら完全なシード実行
    if bundle exec rails runner "exit(User.count == 0 ? 0 : 1)" 2>/dev/null; then
        echo "Database is empty. Running full seed..."
        bundle exec rails db:seed
        echo "Seed completed"
    else
        echo "Database already has data. Skipping seed."
    fi
fi
```

**利点**:
- ✅ 開発環境: 自動で完全なシード
- ✅ 本番環境: 最小限のシード + 手動制御
- ✅ 起動時間を短縮

## まとめ

### Rails 8の仕組み

| コマンド | マイグレーション | シード | 用途 |
|---------|----------------|--------|------|
| `db:prepare` | ✅ 実行 | ❌ なし | **本番起動時** |
| `db:setup` | ✅ 実行 | ✅ 実行 | 初回セットアップ |
| `db:seed` | ❌ なし | ✅ 実行 | データ投入 |
| `db:migrate` | ✅ 実行 | ❌ なし | 開発時 |
| `db:reset` | ✅ 実行 | ✅ 実行 | 開発時リセット |

### AGRRのシード設計

- ✅ **冪等性あり**: 何度実行しても安全
- ✅ **find_or_create_by!使用**: データ重複なし
- ✅ **既存データ更新**: 常に最新のデータに
- ✅ **コメントアウトは運用判断**: 技術的制約ではない

### 回答

> seedを最初行った後にコメントアウトしなければならない理由はある？

**回答**: 
- **技術的理由**: ❌ なし（冪等性があるため）
- **運用的理由**: ✅ あり（起動時間短縮、意図的制御）
- **結論**: コメントアウトは選択であり、必須ではない

---

**推奨**: 
- 開発環境: コメントを外して自動実行
- 本番環境: コメントのまま手動制御（現在の設計が適切）

