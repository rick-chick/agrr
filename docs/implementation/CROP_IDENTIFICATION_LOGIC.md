# 作物の同一判定条件

## 📋 概要

`PlanSaveService`における作物の同一判定条件と、既存作物の扱いについて説明します。

## 🔍 同一判定条件

### 判定方法

```ruby
existing_crop = @user.crops.includes(crop_stages: [...]).find_by(name: reference_crop.name)
```

### 判定基準

| 項目 | 条件 | 説明 |
|-----|------|------|
| **判定フィールド** | `name` | 作物名のみで判定 |
| **ユーザースコープ** | `@user.crops` | 対象ユーザーの作物のみ検索 |
| **参照フラグ** | `is_reference: false` | ユーザー所有の作物のみ |
| **地域** | 未使用 | 地域は判定に使用しない |
| **品種** | 未使用 | `variety`は判定に使用しない |
| **グループ** | 未使用 | `groups`は判定に使用しない |

### 重要なポイント

1. **`name`のみで判定**
   - `variety`（品種）は判定に使用されない
   - 例: 「トマト」と「トマト（大玉）」は**異なる作物**として扱われる

2. **ユーザースコープ**
   - 他ユーザーの作物は検索対象外
   - 参照用作物（`is_reference: true`）も対象外

3. **名称の一致**
   - 完全一致のみ
   - 部分一致や正規化なし

## 🔄 処理フロー

### 1. 既存作物が見つかった場合

```ruby
if existing_crop
  # ステージ要件のチェック
  missing_requirements = existing_crop.crop_stages.any? do |stage|
    !stage.temperature_requirement || !stage.thermal_requirement
  end
  
  if missing_requirements
    # ステージ要件が欠けている場合はコピー
    copy_crop_stages(reference_crop, existing_crop)
  end
  
  user_crops << existing_crop
end
```

**処理内容:**
1. 既存作物のステージ要件をチェック
2. 不足があれば参照作物からコピー
3. 既存作物をそのまま使用

### 2. 既存作物が見つからなかった場合

```ruby
else
  # 新しい作物を作成
  new_crop = @user.crops.create!(
    name: reference_crop.name,
    variety: reference_crop.variety,
    area_per_unit: reference_crop.area_per_unit,
    revenue_per_area: reference_crop.revenue_per_area,
    groups: reference_crop.groups,
    is_reference: false,
    region: reference_crop.region
  )
  
  # 作物ステージをコピー
  copy_crop_stages(reference_crop, new_crop)
  
  user_crops << new_crop
end
```

**処理内容:**
1. 新しい作物を作成
2. 参照作物から全属性をコピー
3. 作物ステージもコピー

## 📊 実装例

### 例1: 同名の作物が存在する場合

**参照作物:**
```ruby
# name: "トマト"
# variety: "桃太郎"
# area_per_unit: 0.5
```

**既存作物（ユーザー所有）:**
```ruby
# name: "トマト"
# variety: "ファースト"
# area_per_unit: 0.3
```

**判定結果:** ✅ 同一作物として扱われる
- 既存作物をそのまま使用
- `variety`や`area_per_unit`は更新されない
- ステージ要件があればそのまま使用

### 例2: 同名の作物が存在しない場合

**参照作物:**
```ruby
# name: "パプリカ"
# variety: "赤パプリカ"
# area_per_unit: 1.0
```

**既存作物:** なし

**判定結果:** ❌ 新規作成
- 新しい作物を作成
- 全属性をコピー
- ステージ要件もコピー

### 例3: 異なるユーザーの同名作物

**ユーザーAの作物:**
```ruby
# user_id: 1
# name: "トマト"
```

**ユーザーBの判定（同じname）:**
```ruby
# 検索対象: user_id: 2 の作物のみ
# 結果: nil（見つからない）
```

**判定結果:** ❌ 新規作成（ユーザーB用に新しい作物を作成）

## 🚨 注意事項

### 1. `variety`が異なっても同一判定

問題になる可能性がある場合:
- 同じ名前だが品種が異なる場合
- 例: 「トマト（桃太郎）」と「トマト（ファースト）」

**対応:**
- 作物名に品種を含める（例: "トマト 桃太郎"）
- または、`variety`も含めた判定ロジックに変更

### 2. 既存データの上書き

既存作物の属性は更新されない:
- 既に存在する作物の`area_per_unit`や`revenue_per_area`は変更されない
- ステージ要件のみ不足分が補充される

### 3. ステージ要件のチェック

`temperature_requirement`と`thermal_requirement`の両方が存在する場合のみ「要件あり」と判定:
```ruby
!stage.temperature_requirement || !stage.thermal_requirement
```
- どちらか一方でも欠けていれば、`copy_crop_stages`が実行される

## 💡 改善案

### より厳密な判定

```ruby
# 複数フィールドで判定
existing_crop = @user.crops.find_by(
  name: reference_crop.name,
  variety: reference_crop.variety
)
```

**メリット:**
- 品種まで考慮した厳密な判定

**デメリット:**
- 既存データとの互換性問題
- 品種が未設定の場合の扱い

### 柔軟な名称マッチング

```ruby
# 部分一致や正規化
existing_crop = @user.crops.where("name LIKE ?", "%#{reference_crop.name}%").first
```

**メリット:**
- 名称の揺れに対応

**デメリット:**
- 誤マッチの可能性
- パフォーマンス低下

## 📝 まとめ

| 項目 | 内容 |
|-----|------|
| **判定フィールド** | `name`のみ |
| **判定スコープ** | ユーザー所有の作物のみ |
| **判定方法** | 完全一致 |
| **既存作物の扱い** | そのまま使用（属性は更新されない） |
| **ステージ要件** | 不足分のみ補充 |

現在の実装はシンプルで理解しやすく、多くのケースで期待通りに動作します。ただし、品種が重要な場合や、より厳密な判定が必要な場合は、判定ロジックの拡張を検討してください。
