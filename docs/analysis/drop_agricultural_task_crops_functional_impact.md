# DropAgriculturalTaskCrops による機能への影響

## 概要
`agricultural_task_crops`テーブルが削除されたことで、実際のアプリケーション機能で問題が発生する可能性がある箇所を特定しました。

## 影響を受ける機能

### 1. ❌ CropTaskTemplateBackfillService（即座にエラー）

**ファイル**: `app/services/crop_task_template_backfill_service.rb`

**問題箇所**: 9行目
```ruby
scope = AgriculturalTaskCrop.includes(:crop, :agricultural_task)
```

**影響**:
- このサービスが実行されると、`AgriculturalTaskCrop`テーブルが存在しないため`ActiveRecord::StatementInvalid`エラーが発生
- サービス自体の目的は`AgriculturalTaskCrop`から`CropTaskTemplate`への移行だったが、テーブルが既に削除されているため実行不可能

**使用箇所**:
- `lib/tasks/crop_task_templates.rake` - Rakeタスクから呼び出される
- テストファイル: `test/services/crop_task_template_backfill_service_test.rb`

**修正方針**:
- このサービスは既に不要（移行が完了しているため）
- サービスを削除するか、`CropTaskTemplate`を直接操作するように変更
- または、サービスを非推奨としてマークし、実行時に警告を出す

### 2. ⚠️ AgriculturalTaskCropモデル（潜在的な問題）

**ファイル**: `app/models/agricultural_task_crop.rb`

**影響**:
- モデルファイルが存在するが、対応するテーブルが存在しない
- どこかで`AgriculturalTaskCrop`クラスが参照されると`ActiveRecord::StatementInvalid`エラーが発生
- 現在のアプリケーションコードでは直接使用されていないが、削除しておくべき

**修正方針**:
- モデルファイルを削除

### 3. ✅ コントローラー（既に移行済み）

**ファイル**: `app/controllers/agricultural_tasks_controller.rb`

**状況**:
- 80-108行目で既に`CropTaskTemplate`を使用して関連付けを管理
- `AgriculturalTaskCrop`は使用されていない
- **問題なし**

**確認箇所**:
- `update`アクション（65-115行目）: `CropTaskTemplate`で作物の追加・削除を管理
- `prepare_crop_cards`（260-274行目）: `CropTaskTemplate`から選択済み作物を取得

### 4. ✅ その他のコントローラー（影響なし）

以下のコントローラーは`AgriculturalTaskCrop`を使用していない:
- `app/controllers/crops_controller.rb` - `CropTaskTemplate`を使用
- `app/controllers/plans_controller.rb` - 作物選択のみ（関連付けなし）
- その他のコントローラー - 関連なし

## 実行時にエラーが発生する可能性がある操作

### 1. Rakeタスクの実行
```bash
rails crop_task_templates:backfill
```
- `CropTaskTemplateBackfillService`が呼び出される
- `AgriculturalTaskCrop`テーブルが存在しないためエラー

### 2. テストの実行
- `test/services/crop_task_template_backfill_service_test.rb`が実行されるとエラー
- その他のテストでも`AgriculturalTaskCrop`を使用している箇所でエラー

## 修正が必要なファイル（機能への影響）

### 即座に修正が必要
1. **`app/services/crop_task_template_backfill_service.rb`**
   - 9行目: `AgriculturalTaskCrop`を使用
   - サービスを削除するか、`CropTaskTemplate`を直接操作するように変更

2. **`app/models/agricultural_task_crop.rb`**
   - モデルファイルを削除

3. **`lib/tasks/crop_task_templates.rake`**
   - `CropTaskTemplateBackfillService`を呼び出している
   - サービスが不要なら、Rakeタスクも削除または非推奨化

## 修正不要（既に移行済み・確認済み）

### コントローラー
- `app/controllers/agricultural_tasks_controller.rb`
  - 80-108行目: `CropTaskTemplate`で作物の追加・削除を管理
  - 264行目: `CropTaskTemplate`から選択済み作物を取得
  - `AgriculturalTaskCrop`への参照なし ✅

- `app/controllers/crops_controller.rb`
  - 27-29行目: `CropTaskTemplate`から選択済みタスクIDを取得
  - 142-183行目: `toggle_task_template`アクションで`CropTaskTemplate`を使用
  - `AgriculturalTaskCrop`への参照なし ✅

- `app/controllers/crops/agricultural_tasks_controller.rb`
  - 11行目: `@crop.crop_task_templates`を使用
  - 42-54行目: `CropTaskTemplate`を作成
  - `AgriculturalTaskCrop`への参照なし ✅

### モデル
- `app/models/agricultural_task.rb`
  - 26-27行目: `has_many :crop_task_templates` と `has_many :crops, through: :crop_task_templates`
  - `AgriculturalTaskCrop`への参照なし ✅

- `app/models/crop.rb`
  - 27-28行目: `has_many :crop_task_templates` と `has_many :agricultural_tasks, through: :crop_task_templates`
  - `AgriculturalTaskCrop`への参照なし ✅

### ビュー
- `app/views/**/*.erb` - `AgriculturalTaskCrop`への参照なし ✅

## まとめ

**即座に問題が発生する機能**:
1. `CropTaskTemplateBackfillService`の実行（Rakeタスク経由）
2. 該当サービスのテスト実行

**潜在的な問題**:
1. `AgriculturalTaskCrop`モデルが存在するため、誤って参照される可能性

**既に移行済みで問題なし**:
1. 農業タスクと作物の関連付け機能（`AgriculturalTasksController`）
2. 作物詳細画面でのテンプレート表示（`CropsController`）

