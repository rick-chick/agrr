# 作物重複要件

## 概要
AGRRプロジェクトにおける作物の重複に関する正しい要件定義

## 基本要件

### 作物名重複の扱い
- **作物名の重複は許容する**
- 同じ名前の作物でも、異なる品種や異なる設定を持つ場合は別々の作物として扱う
- ユーザーが同じ名前の作物を複数作成することを制限しない

### 実装方針
1. **PlanSaveService**: 計画コピー時に同じ名前の作物でも新規作成
2. **CultivationPlanCrop**: 同じ作物名でも複数のCultivationPlanCropを作成可能
3. **重複制御の削除**: 名前による重複チェックは行わない

## 技術的詳細

### PlanSaveServiceでの処理
```ruby
# 正しい実装（重複制御なし）
reference_crops.each do |reference_crop|
  # 新しい作物を作成（名前重複は許容）
  new_crop = @user.crops.build(
    name: reference_crop.name,
    variety: reference_crop.variety,
    # ... その他の属性
  )
  new_crop.save!
end
```

### CultivationPlanCropでの処理
```ruby
# 正しい実装（重複制御なし）
reference_plan.cultivation_plan_crops.each do |reference_crop_plan|
  crop_plan_data << {
    cultivation_plan_id: new_plan.id,
    crop_id: crop.id,
    name: reference_crop_plan.name,
    variety: reference_crop_plan.variety,
    # ... その他の属性
  }
end
```

## テスト要件

### 単体テスト
- 同じ名前の作物が複数作成されることを確認
- CultivationPlanCropが重複して作成されることを確認
- 品種情報が適切に保持されることを確認

### 統合テスト
- 計画コピー時に名前重複が許容されることを確認
- ユーザーが同じ名前の作物を複数作成できることを確認

## 過去の誤解

### 誤解されていた仕様
- 「Crop: 名前で重複チェック」→ これは誤解
- 「重複を避ける」→ これは仕様違反
- 「同じ作物名は1つまで」→ これは制限しすぎ

### 修正された実装
- 重複チェックロジックの削除
- 名前重複許容の実装
- テストケースの修正

## 関連ドキュメント
- [REQUIREMENTS_COMPARISON.md](./project_management/REQUIREMENTS_COMPARISON.md)
- [PUBLIC_PLANS_SAVE_STATUS.md](./implementation/PUBLIC_PLANS_SAVE_STATUS.md)
- [PUBLIC_PLANS_SAVE_REQUIREMENTS.md](./design/PUBLIC_PLANS_SAVE_REQUIREMENTS.md)

## 更新履歴
- 2025-01-27: 正しい要件定義を作成
- 2025-01-27: 誤解された仕様を修正
- 2025-01-27: 実装とテストを正しい要件に合わせて修正
