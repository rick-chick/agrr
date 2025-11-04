# Pesticide関連テスト 批判的レビュー

## 🔴 重大な問題点

### 1. **from_agrr_outputの削除処理テストの不足**

#### usage_constraintsとapplication_detailsの削除テストがない
```ruby
# app/models/pesticide.rb:49-61, 63-73
if pesticide_data['usage_constraints']
  # 作成または更新
end

if pesticide_data['application_details']
  # 作成または更新
end
```
**問題**: 
- `usage_constraints`が`nil`の場合、既存のレコードが削除されない（Pestの`control_methods`と異なり、明示的な削除処理がない）
- 既存のusage_constraintsがある状態で、`usage_constraints`キーが存在しないデータで更新した場合の動作がテストされていない
- `accepts_nested_attributes_for`に`allow_destroy: true`が設定されているが、`_destroy`フラグを使った削除のテストがない

**影響**: agrrコアから取得したデータに制約情報が含まれていない場合、既存の制約データが残り続ける可能性がある

**推奨テスト**:
```ruby
test "from_agrr_output should handle nil usage_constraints when existing record exists" do
  existing_pesticide = create(:pesticide, pesticide_id: "acetamiprid", :with_usage_constraint)
  
  pesticide_data_without_constraints = @pesticide_data.dup
  pesticide_data_without_constraints.delete("usage_constraints")
  
  pesticide = Pesticide.from_agrr_output(pesticide_data: pesticide_data_without_constraints, is_reference: true)
  
  # 既存のusage_constraintsが残っているか、削除されるかのどちらかを明確にテスト
  # 実装によるが、nilが渡された場合の動作を明確にする必要がある
end
```

### 2. **ネスト属性の_destroyフラグのテストがない**

```ruby
# app/models/pesticide.rb:20-21
accepts_nested_attributes_for :pesticide_usage_constraint, allow_destroy: true
accepts_nested_attributes_for :pesticide_application_detail, allow_destroy: true
```
**問題**: `allow_destroy: true`が設定されているが、`_destroy`フラグを使った削除のテストが存在しない

**推奨テスト**:
```ruby
test "should destroy usage_constraint with _destroy flag" do
  pesticide = create(:pesticide, :with_usage_constraint)
  constraint_id = pesticide.pesticide_usage_constraint.id
  
  pesticide.update(
    pesticide_usage_constraint_attributes: {
      id: constraint_id,
      _destroy: '1'
    }
  )
  
  assert_not PesticideUsageConstraint.exists?(constraint_id)
end
```

### 3. **バリデーションエラーハンドリングのテスト不足**

#### from_agrr_outputでのバリデーションエラーのテストがない
```ruby
# app/models/pesticide.rb:47, 60, 72
pesticide.save!
usage_constraints.save!
application_details.save!
```
**問題**: 
- `save!`はバリデーションエラー時に例外を投げるが、その場合のテストがない
- 例えば、usage_constraintsで`min_temperature > max_temperature`の場合のエラーハンドリングがテストされていない

**推奨テスト**:
```ruby
test "from_agrr_output should raise error when usage_constraints validation fails" do
  invalid_data = @pesticide_data.dup
  invalid_data["usage_constraints"]["min_temperature"] = 40.0
  invalid_data["usage_constraints"]["max_temperature"] = 35.0
  
  assert_raises(ActiveRecord::RecordInvalid) do
    Pesticide.from_agrr_output(pesticide_data: invalid_data, is_reference: true)
  end
end
```

## 🟡 中程度の問題点

### 4. **to_agrr_outputのエッジケーステストの不足**

#### すべてのフィールドがnilの場合のテストがない
```ruby
# app/models/pesticide.rb:86-92
'usage_constraints' => pesticide_usage_constraint ? {
  'min_temperature' => pesticide_usage_constraint.min_temperature,
  # ...
} : nil
```
**問題**: usage_constraintsは存在するが、すべてのフィールドがnilの場合の出力がテストされていない

**推奨テスト**:
```ruby
test "to_agrr_output should handle usage_constraints with all nil values" do
  pesticide = create(:pesticide, pesticide_id: "test_pesticide")
  create(:pesticide_usage_constraint, 
         pesticide: pesticide,
         min_temperature: nil,
         max_temperature: nil,
         max_wind_speed_m_s: nil,
         max_application_count: nil,
         harvest_interval_days: nil,
         other_constraints: nil)
  
  output = pesticide.to_agrr_output
  
  assert_not_nil output["usage_constraints"]
  assert_nil output["usage_constraints"]["min_temperature"]
  assert_nil output["usage_constraints"]["max_temperature"]
end
```

### 5. **関連モデルのバリデーションエラーの統合テストがない**

#### PesticideUsageConstraintの温度制約エラーがPesticide経由で検出されるかのテストがない
```ruby
# app/models/pesticide_usage_constraint.rb:25-31
def min_temperature_must_be_less_than_max
  # ...
end
```
**問題**: Pesticide経由でusage_constraintを作成する際に、バリデーションエラーが適切に検出されるかテストされていない

**推奨テスト**:
```ruby
test "should validate usage_constraint temperature constraints through pesticide" do
  pesticide = build(:pesticide, pesticide_id: "test_pesticide")
  pesticide.build_pesticide_usage_constraint(
    min_temperature: 40.0,
    max_temperature: 35.0
  )
  
  assert_not pesticide.valid?
  assert_includes pesticide.pesticide_usage_constraint.errors[:min_temperature], 
                  "must be less than or equal to max_temperature"
end
```

### 6. **Entityテストとモデルテストの重複**

#### Entityテストでテストしているバリデーションがモデルテストでもテストされている
**問題**: 
- `PesticideEntityTest`で`pesticide_id`と`name`の必須チェックをテスト
- `PesticideTest`でも同様のバリデーションをテスト
- バリデーションロジックがEntity層とモデル層で重複している

**推奨**: 
- Entity層はビジネスロジックの検証
- モデル層はActiveRecordのバリデーションとデータベース制約の検証
- 役割を明確に分離する

### 7. **from_agrr_outputの更新テストの不十分**

#### is_referenceの更新がテストされていない
```ruby
# app/models/pesticide.rb:40-47
pesticide = find_or_initialize_by(pesticide_id: pesticide_data['pesticide_id'])
pesticide.assign_attributes(
  # ...
  is_reference: is_reference
)
```
**問題**: 
- 既存のpesticideの`is_reference`を変更するケースがテストされていない
- 参照データから非参照データへの変更、またはその逆のケースがテストされていない

**推奨テスト**:
```ruby
test "from_agrr_output should update is_reference flag" do
  existing_pesticide = create(:pesticide, pesticide_id: "acetamiprid", is_reference: false)
  
  pesticide = Pesticide.from_agrr_output(pesticide_data: @pesticide_data, is_reference: true)
  
  assert_equal true, pesticide.is_reference
  assert_equal existing_pesticide.id, pesticide.id
end
```

## 🟢 軽微な改善点

### 8. **テストの可読性**

#### setupブロックの@pesticide_dataが長すぎる
```ruby
# test/models/pesticide_test.rb:7-26
@pesticide_data = {
  # 長いハッシュ構造
}
```
**改善案**: ヘルパーメソッドやファクトリトレイトを使用して、テストデータの構築を簡潔にする

### 9. **テストの整理**

#### from_agrr_outputとto_agrr_outputのテストが混在
**改善案**: `context`ブロックでグループ化
```ruby
context "from_agrr_output" do
  # 関連するテスト
end

context "to_agrr_output" do
  # 関連するテスト
end
```

### 10. **アサーションの詳細度**

#### to_agrr_outputテストで一部のフィールドのみ検証
```ruby
# test/models/pesticide_test.rb:193-199
assert_not_nil output["usage_constraints"]
assert_equal pesticide.pesticide_usage_constraint.min_temperature, output["usage_constraints"]["min_temperature"]
# 他のフィールドは検証されていない
```
**改善案**: すべてのフィールドを検証するか、重要なフィールドのみ検証するかの意図を明確にする

### 11. **Entityテストの重複テスト削除**

#### PesticideApplicationDetailsEntityTestで同じエラーケースを2回テスト
```ruby
# test/domain/pesticide/entities/pesticide_application_details_entity_test.rb:77-90, 154-167
# "should raise error when amount_unit is present but amount_per_m2 is nil" が2回定義されている
```
**問題**: 同じテストケースが重複している

## 📊 カバレッジ分析

### テストされている機能 ✅
- [x] 基本バリデーション（pesticide_id, name, is_reference）
- [x] 関連モデルの基本的な作成・削除
- [x] from_agrr_outputの基本的な作成・更新
- [x] to_agrr_outputの基本的な変換
- [x] スコープ（reference, recent）
- [x] pesticide_id形式の多様性
- [x] nil値の処理

### テストされていない機能 ❌
- [ ] from_agrr_outputでのusage_constraints削除（nilが渡された場合）
- [ ] from_agrr_outputでのapplication_details削除（nilが渡された場合）
- [ ] _destroyフラグを使ったネスト属性の削除
- [ ] from_agrr_outputでのバリデーションエラーハンドリング
- [ ] is_referenceフラグの更新
- [ ] すべてのフィールドがnilのusage_constraintsのto_agrr_output
- [ ] Pesticide経由でのusage_constraintバリデーションエラー
- [ ] to_agrr_outputでのすべてのフィールドの検証

## 🎯 推奨される追加テスト

1. **from_agrr_outputの削除処理**
   ```ruby
   test "from_agrr_output should remove existing usage_constraints when nil" do
     existing_pesticide = create(:pesticide, pesticide_id: "acetamiprid", :with_usage_constraint)
     constraint_id = existing_pesticide.pesticide_usage_constraint.id
     
     pesticide_data = {
       "pesticide_id" => "acetamiprid",
       "name" => "アセタミプリド",
       "usage_constraints" => nil
     }
     
     pesticide = Pesticide.from_agrr_output(pesticide_data: pesticide_data, is_reference: true)
     
     # 実装によるが、削除されるかnilになるかのどちらかを明確にテスト
   end
   ```

2. **バリデーションエラーハンドリング**
   ```ruby
   test "from_agrr_output should raise error when usage_constraints validation fails" do
     invalid_data = @pesticide_data.dup
     invalid_data["usage_constraints"]["min_temperature"] = 40.0
     invalid_data["usage_constraints"]["max_temperature"] = 35.0
     
     assert_raises(ActiveRecord::RecordInvalid) do
       Pesticide.from_agrr_output(pesticide_data: invalid_data, is_reference: true)
     end
   end
   ```

3. **is_referenceの更新**
   ```ruby
   test "from_agrr_output should update is_reference flag when different" do
     existing_pesticide = create(:pesticide, pesticide_id: "acetamiprid", is_reference: false)
     
     pesticide = Pesticide.from_agrr_output(pesticide_data: @pesticide_data, is_reference: true)
     
     assert_equal true, pesticide.is_reference
   end
   ```

4. **_destroyフラグのテスト**
   ```ruby
   test "should destroy usage_constraint with nested attributes _destroy flag" do
     pesticide = create(:pesticide, :with_usage_constraint)
     constraint_id = pesticide.pesticide_usage_constraint.id
     
     pesticide.update(
       pesticide_usage_constraint_attributes: {
         id: constraint_id,
         _destroy: '1'
       }
     )
     
     assert_not PesticideUsageConstraint.exists?(constraint_id)
   end
   ```

5. **to_agrr_outputの完全性テスト**
   ```ruby
   test "to_agrr_output should include all usage_constraints fields" do
     pesticide = create(:pesticide, :with_usage_constraint, pesticide_id: "test_pesticide")
     
     output = pesticide.to_agrr_output
     
     constraints = output["usage_constraints"]
     assert_not_nil constraints
     assert_equal pesticide.pesticide_usage_constraint.min_temperature, constraints["min_temperature"]
     assert_equal pesticide.pesticide_usage_constraint.max_temperature, constraints["max_temperature"]
     assert_equal pesticide.pesticide_usage_constraint.max_wind_speed_m_s, constraints["max_wind_speed_m_s"]
     assert_equal pesticide.pesticide_usage_constraint.max_application_count, constraints["max_application_count"]
     assert_equal pesticide.pesticide_usage_constraint.harvest_interval_days, constraints["harvest_interval_days"]
     assert_equal pesticide.pesticide_usage_constraint.other_constraints, constraints["other_constraints"]
   end
   ```

## 📝 総評

**良い点**:
- 基本的なバリデーションテストは網羅されている
- from_agrr_outputとto_agrr_outputの基本的な機能はテストされている
- Entity層とモデル層の両方でテストが書かれている
- pesticide_id形式の多様性がテストされている

**改善が必要な点**:
- **from_agrr_outputでの削除処理のテストが不足**（最重要）
- _destroyフラグを使った削除のテストがない
- バリデーションエラーハンドリングのテストが不足
- to_agrr_outputの完全性テストが不足

**優先度**:
1. 🔴 高: from_agrr_outputでの削除処理テストの追加
2. 🔴 高: バリデーションエラーハンドリングテストの追加
3. 🟡 中: _destroyフラグのテスト追加
4. 🟡 中: to_agrr_outputの完全性テスト追加
5. 🟢 低: テスト構造の改善、可読性向上




