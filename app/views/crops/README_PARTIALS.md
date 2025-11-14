# 作物詳細画面パーシャル一覧

このディレクトリには、作物詳細画面（`show.html.erb`）をパーシャル化した各セクションが含まれています。
各パーシャルは独立して使用でき、詳細画面に依存しません。

## パーシャル一覧

### 1. `_header.html.erb` - ヘッダー部分

**必要なデータ:**
- `crop.name` - 作物名
- `crop.is_reference` - 参照作物フラグ（オプション）

**使用例:**
```erb
<%= render 'crops/header', crop: Crop.find(1) %>
<%= render 'crops/header', crop: @my_crop_object %>
```

**独立性:** ✅ 完全に独立。任意のCropオブジェクトで使用可能

---

### 2. `_basic_info.html.erb` - 基本情報セクション

**必要なデータ:**
- `crop.name` - 作物名（必須）
- `crop.variety` - 品種（オプション）
- `crop.area_per_unit` - 単位面積（オプション）
- `crop.revenue_per_area` - 単位面積あたりの収益（オプション）
- `crop.groups` - グループ（オプション、配列または文字列）
- `crop.created_at` - 作成日時（必須）
- `crop.updated_at` - 更新日時（必須）

**使用例:**
```erb
<%= render 'crops/basic_info', crop: Crop.find(1) %>
<%= render 'crops/basic_info', crop: @custom_crop %>
```

**独立性:** ✅ 完全に独立。任意のCropオブジェクトで使用可能

---

### 3. `_pests_section.html.erb` - 害虫セクション

**必要なデータ:**
- `crop.id` - 作物ID（パス生成用）
- `crop.pests` - 害虫のコレクション（`recent`メソッドでアクセス可能）

**使用例:**
```erb
<%= render 'crops/pests_section', crop: Crop.find(1) %>
<%= render 'crops/pests_section', crop: @selected_crop %>
```

**独立性:** ✅ 完全に独立。任意のCropオブジェクトで使用可能

---

### 4. `_task_schedule_blueprints_section.html.erb` - 作業スケジュールブループリントセクション

**必要なデータ:**
- `crop.id` - 作物ID（パス生成用）
- `crop.crop_stages` - 作物ステージのコレクション（GDD計算用）
- `task_schedule_blueprints` - 作業スケジュールブループリントの配列
  - 各要素は `gdd_trigger`, `priority`, `task_type`, `agricultural_task` を持つ必要がある

**使用例:**
```erb
<%= render 'crops/task_schedule_blueprints_section', 
           crop: Crop.find(1), 
           task_schedule_blueprints: Crop.find(1).crop_task_schedule_blueprints %>

<%= render 'crops/task_schedule_blueprints_section', 
           crop: @my_crop, 
           task_schedule_blueprints: @custom_blueprints %>
```

**独立性:** ✅ 完全に独立。任意のCropオブジェクトとブループリント配列で使用可能

---

### 5. `_available_task_templates_section.html.erb` - 利用可能な作業テンプレートセクション

**必要なデータ:**
- `crop.id` - 作物ID（パス生成用）
- `available_agricultural_tasks` - 利用可能な農業タスクの配列
  - 各要素は `id`, `name`, `description` を持つ必要がある
- `selected_task_ids` - 選択されているタスクIDの配列（整数の配列）

**使用例:**
```erb
<%= render 'crops/available_task_templates_section',
           crop: Crop.find(1),
           available_agricultural_tasks: AgriculturalTask.all,
           selected_task_ids: [1, 3] %>

<%= render 'crops/available_task_templates_section',
           crop: @my_crop,
           available_agricultural_tasks: @custom_tasks,
           selected_task_ids: @selected_ids %>
```

**独立性:** ✅ 完全に独立。任意のCropオブジェクト、タスク配列、選択ID配列で使用可能

---

### 6. `_stages_section.html.erb` - ステージセクション

**必要なデータ:**
- `crop.crop_stages` - 作物ステージのコレクション
  - 各ステージは `name`, `order` を持つ必要がある
  - オプション: `temperature_requirement`, `thermal_requirement`, `sunshine_requirement`, `nutrient_requirement`

**使用例:**
```erb
<%= render 'crops/stages_section', crop: Crop.find(1) %>
<%= render 'crops/stages_section', crop: @custom_crop_with_stages %>
```

**独立性:** ✅ 完全に独立。任意のCropオブジェクトで使用可能

---

### 7. `_actions.html.erb` - アクションボタンセクション

**必要なデータ:**
- `crop.id` - 作物ID（パス生成用）
- `crop.name` - 作物名（削除確認メッセージ用）
- `crop.is_reference` - 参照作物フラグ（権限判定用）

**使用例:**
```erb
<%= render 'crops/actions', crop: Crop.find(1) %>
<%= render 'crops/actions', crop: @my_crop_object %>
```

**独立性:** ✅ 完全に独立。任意のCropオブジェクトで使用可能

---

## 独立性の確認

すべてのパーシャルは以下の点で独立しています：

1. **コントローラーのインスタンス変数に依存しない**
   - すべてのデータは明示的にパラメータとして渡される
   - `@crop` などのインスタンス変数を直接参照しない

2. **他のパーシャルに依存しない**
   - 各パーシャルは単独で動作可能
   - パーシャル間の依存関係がない

3. **詳細画面に依存しない**
   - `show.html.erb` 以外のビューでも使用可能
   - 任意のコントローラーやビューから呼び出し可能

4. **データソースに依存しない**
   - データベースから取得したオブジェクトでも、モックオブジェクトでも使用可能
   - 必要な属性さえあれば動作する

## 使用上の注意

- 各パーシャルは必要なデータが揃っていることを前提としています
- オプションのデータがない場合は、該当する表示がスキップされます
- 翻訳キーは `crops.show.*` 形式を使用しています

