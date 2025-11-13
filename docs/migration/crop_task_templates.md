# Crop Task Template Migration Guide

既存の `AgriculturalTask` と `Crop` の関連データから `CropTaskTemplate` を生成するためのマイグレーションです。テンプレート化により、予定作成やAIスケジュール生成が安定して再利用できるようになります。

## 概要

`agricultural_task_crops` テーブルが削除され、代わりに `crop_task_templates` テーブルが使用されるようになりました。`CropTaskTemplate` は、作物ごとにカスタマイズされた作業テンプレート情報を保持し、`AgriculturalTask` の属性（説明、所要時間、天候依存度、必要工具、スキルレベルなど）を直接保存します。

## マイグレーション

### 日本の参照タスク用マイグレーション

**ファイル**: `db/migrate/20251113211624_data_migration_japan_reference_crop_task_templates.rb`

このマイグレーションは、既存の `AgriculturalTask`（`DataMigrationJapanReferenceTasks` で作成されたもの）と `Crop` を参照して、`CropTaskTemplate` を作成します。

#### 実行方法

マイグレーションは通常の Rails マイグレーションとして実行されます：

```bash
# マイグレーション実行
bundle exec rails db:migrate

# ロールバック（必要に応じて）
bundle exec rails db:rollback
```

#### 動作

1. **既存データの参照**: 
   - `AgriculturalTask`（`region='jp'`, `is_reference=true`）を参照
   - `Crop`（`region='jp'`, `is_reference=true`）を参照

2. **CropTaskTemplate の作成**:
   - 各タスクと作物の組み合わせで `CropTaskTemplate` を作成
   - `AgriculturalTask` の属性（`description`, `time_per_sqm`, `weather_dependency`, `required_tools`, `skill_level`）をコピー
   - `is_reference=true` として作成

3. **エラーハンドリング**:
   - 存在しない `AgriculturalTask` はスキップ（警告メッセージを出力）
   - 存在しない `Crop` はスキップ（警告メッセージを出力）
   - 既存の `CropTaskTemplate` は削除してから再作成

#### 対象タスクと作物

マイグレーションは以下の17種類のタスクと、各タスクに適用される作物の組み合わせを処理します：

- **必須タスク（8項目）**: 耕耘、基肥、播種、定植、灌水、除草、収穫、出荷準備
- **条件付き必須タスク（9項目）**: マルチング、トンネル設置、支柱立て、防虫ネット張り、間引き、剪定、誘引、規格選別、箱詰め・袋詰め

詳細なタスク定義と適用作物のリストは `docs/migration/task.md` を参照してください。

## 確認方法

### 1. データベースでの確認

```ruby
# Rails コンソールで確認
rails console

# CropTaskTemplate の数を確認
CropTaskTemplate.where(is_reference: true).count

# 特定の作物のテンプレートを確認
crop = Crop.find_by(name: 'トマト', region: 'jp', is_reference: true)
CropTaskTemplate.where(crop: crop, is_reference: true).pluck(:name)

# 特定のタスクのテンプレートを確認
task = AgriculturalTask.find_by(name: '灌水', region: 'jp', is_reference: true)
CropTaskTemplate.where(agricultural_task: task, is_reference: true).count
```

### 2. アプリケーションでの確認

- 作物詳細画面でテンプレート一覧が表示されることを確認
- 予定作成モーダルでテンプレートが候補として表示されることを確認

## ロールバック

マイグレーションをロールバックすると、作成された `CropTaskTemplate`（`is_reference=true`）が削除されます。`AgriculturalTask` と `Crop` は削除されません。

```bash
# ロールバック
bundle exec rails db:rollback

# 再度実行
bundle exec rails db:migrate
```

## 注意事項

1. **既存データの前提**: 
   - このマイグレーションは、`DataMigrationJapanReferenceTasks` で作成された `AgriculturalTask` が存在することを前提としています
   - 参照作物（`Crop`）が存在することを前提としています

2. **重複実行**:
   - マイグレーションを再実行すると、既存の `CropTaskTemplate` は削除されてから再作成されます
   - データの整合性は保たれますが、ID は変更される可能性があります

3. **他の地域への対応**:
   - 現在のマイグレーションは日本（`region='jp'`）のみを対象としています
   - 他の地域（`'us'`, `'in'` など）に対応する場合は、別のマイグレーションを作成してください

## 関連ドキュメント

- `docs/migration/task.md` - タスク定義と適用作物の詳細
- `docs/analysis/crop_task_template_usage.md` - CropTaskTemplate の使用方法
- `docs/analysis/drop_agricultural_task_crops_impact.md` - テーブル削除の影響範囲
