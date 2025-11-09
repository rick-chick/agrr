# Pest user_id機能のテスト設計書

## 📋 変更概要

### 実装した機能
1. **データベース**: `pests`テーブルに`user_id`カラムを追加
2. **モデル**: `Pest`モデルに`user_id`関連のバリデーションとスコープを追加
3. **コントローラー**: `PestsController`にユーザー権限チェックを追加

### 変更の目的
- 他のユーザーの害虫が参照できないようにする
- 参照害虫（`is_reference: true`）とユーザー害虫（`is_reference: false`）を適切に区別
- ユーザーは自分の害虫のみ管理可能

---

## 🎯 テスト設計の全体像

### テストカテゴリ

```
テスト設計
├── 1. モデル層テスト (Pest Model)
│   ├── バリデーションテスト
│   ├── スコープテスト
│   └── 関連テスト
│
├── 2. コントローラー層テスト (PestsController)
│   ├── 一覧表示 (index)
│   ├── 詳細表示 (show)
│   ├── 新規作成 (create)
│   ├── 更新 (update)
│   └── 削除 (destroy)
│
└── 3. 統合テスト
    ├── 権限の組み合わせテスト
    ├── データ整合性テスト
    └── エッジケーステスト
```

---

## 1. モデル層テスト (Pest Model)

### 1.1 バリデーションテスト

#### ✅ 必須: user_idのバリデーション

```ruby
test "should validate user presence when is_reference is false" do
  pest = Pest.new(name: "テスト害虫", is_reference: false, user_id: nil)
  assert_not pest.valid?
  assert_includes pest.errors[:user], "を入力してください"
end

test "should allow nil user_id when is_reference is true" do
  pest = Pest.new(name: "テスト害虫", is_reference: true, user_id: nil)
  assert pest.valid?
end

test "should allow user_id when is_reference is false" do
  user = create(:user)
  pest = Pest.new(name: "テスト害虫", is_reference: false, user_id: user.id)
  assert pest.valid?
end
```

#### ✅ 必須: is_referenceとuser_idの組み合わせバリデーション

```ruby
test "should require user_id when is_reference changes from true to false" do
  user = create(:user)
  pest = create(:pest, is_reference: true, user_id: nil)
  
  pest.is_reference = false
  assert_not pest.valid?
  assert_includes pest.errors[:user], "を入力してください"
  
  pest.user_id = user.id
  assert pest.valid?
end
```

### 1.2 スコープテスト

#### ✅ 必須: reference スコープ

```ruby
test "reference scope should return only reference pests" do
  reference_pest = create(:pest, is_reference: true, user_id: nil)
  user_pest = create(:pest, :user_owned, user: create(:user))
  
  reference_pests = Pest.reference
  
  assert_includes reference_pests, reference_pest
  assert_not_includes reference_pests, user_pest
end
```

#### ✅ 必須: user_owned スコープ

```ruby
test "user_owned scope should return only user-owned pests" do
  user = create(:user)
  reference_pest = create(:pest, is_reference: true, user_id: nil)
  user_pest = create(:pest, :user_owned, user: user)
  
  user_owned_pests = Pest.user_owned
  
  assert_includes user_owned_pests, user_pest
  assert_not_includes user_owned_pests, reference_pest
end
```

#### ✅ 必須: 複合条件でのスコープ

```ruby
test "should filter pests by is_reference and user_id combination" do
  user1 = create(:user)
  user2 = create(:user)
  
  ref_pest = create(:pest, is_reference: true, user_id: nil)
  user1_pest = create(:pest, :user_owned, user: user1)
  user2_pest = create(:pest, :user_owned, user: user2)
  
  # 一般ユーザーの視点
  visible_pests = Pest.where("is_reference = ? OR user_id = ?", true, user1.id)
  
  assert_includes visible_pests, ref_pest
  assert_includes visible_pests, user1_pest
  assert_not_includes visible_pests, user2_pest
end
```

---

## 2. コントローラー層テスト (PestsController)

### 2.1 一覧表示 (index)

#### ✅ 必須: 一般ユーザーの一覧表示

```ruby
test "regular user should see only reference pests and own pests" do
  user = create(:user)
  sign_in_as user
  
  ref_pest = create(:pest, is_reference: true, user_id: nil)
  my_pest = create(:pest, :user_owned, user: user)
  other_user = create(:user)
  other_pest = create(:pest, :user_owned, user: other_user)
  
  get pests_path
  
  assert_response :success
  assert_select '.crop-card', minimum: 2
  
  # 自分の害虫と参照害虫のみ表示
  assert_includes assigns(:pests), ref_pest
  assert_includes assigns(:pests), my_pest
  assert_not_includes assigns(:pests), other_pest
end
```

#### ✅ 必須: 管理者の一覧表示

```ruby
test "admin should see all pests including other users" do
  admin = create(:user, admin: true)
  sign_in_as admin
  
  user1 = create(:user)
  user2 = create(:user)
  
  ref_pest = create(:pest, is_reference: true, user_id: nil)
  user1_pest = create(:pest, :user_owned, user: user1)
  user2_pest = create(:pest, :user_owned, user: user2)
  
  get pests_path
  
  assert_response :success
  # 管理者は参照害虫と自分の害虫のみ表示（現状の実装）
  assert_select '.crop-card', minimum: 2
end
```

#### ⚠️ 境界条件: 空のリスト

```ruby
test "should handle empty pest list gracefully" do
  user = create(:user)
  sign_in_as user
  
  get pests_path
  
  assert_response :success
  assert_select '.empty-state'
end
```

### 2.2 詳細表示 (show)

#### ✅ 必須: 参照害虫の閲覧権限

```ruby
test "any user should view reference pest" do
  user = create(:user)
  sign_in_as user
  
  ref_pest = create(:pest, is_reference: true, user_id: nil)
  
  get pest_path(ref_pest)
  
  assert_response :success
end
```

#### ✅ 必須: 自分の害虫の閲覧権限

```ruby
test "user should view own pest" do
  user = create(:user)
  sign_in_as user
  
  my_pest = create(:pest, :user_owned, user: user)
  
  get pest_path(my_pest)
  
  assert_response :success
end
```

#### ✅ 必須: 他のユーザーの害虫の閲覧拒否

```ruby
test "user should not view other user pest" do
  user = create(:user)
  other_user = create(:user)
  sign_in_as user
  
  other_pest = create(:pest, :user_owned, user: other_user)
  
  get pest_path(other_pest)
  
  assert_redirected_to pests_path
  assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
end
```

#### ✅ 必須: 管理者の閲覧権限

```ruby
test "admin should view any pest" do
  admin = create(:user, admin: true)
  sign_in_as admin
  
  user = create(:user)
  user_pest = create(:pest, :user_owned, user: user)
  
  get pest_path(user_pest)
  
  assert_response :success
end
```

#### ⚠️ 境界条件: 存在しない害虫ID

```ruby
test "should handle non-existent pest id" do
  user = create(:user)
  sign_in_as user
  
  get pest_path(99999)
  
  assert_redirected_to pests_path
  assert_equal I18n.t('pests.flash.not_found'), flash[:alert]
end
```

### 2.3 新規作成 (create)

#### ✅ 必須: 一般ユーザーの害虫作成

```ruby
test "regular user should create pest with user_id set" do
  user = create(:user)
  sign_in_as user
  
  assert_difference('Pest.count') do
    post pests_path, params: { pest: {
      name: 'テスト害虫',
      is_reference: false
    } }
  end
  
  pest = Pest.last
  assert_equal user.id, pest.user_id
  assert_equal false, pest.is_reference
end
```

#### ✅ 必須: 一般ユーザーが参照害虫を作成できない

```ruby
test "regular user should not create reference pest" do
  user = create(:user)
  sign_in_as user
  
  assert_no_difference('Pest.count') do
    post pests_path, params: { pest: {
      name: '参照害虫',
      is_reference: true
    } }
  end
  
  assert_redirected_to pests_path
  assert_equal I18n.t('pests.flash.reference_only_admin'), flash[:alert]
end
```

#### ✅ 必須: 管理者の参照害虫作成

```ruby
test "admin should create reference pest with nil user_id" do
  admin = create(:user, admin: true)
  sign_in_as admin
  
  assert_difference('Pest.count') do
    post pests_path, params: { pest: {
      name: '参照害虫',
      is_reference: true
    } }
  end
  
  pest = Pest.last
  assert_nil pest.user_id
  assert_equal true, pest.is_reference
end
```

#### ✅ 必須: 管理者のユーザー害虫作成

```ruby
test "admin should create user pest with admin user_id" do
  admin = create(:user, admin: true)
  sign_in_as admin
  
  assert_difference('Pest.count') do
    post pests_path, params: { pest: {
      name: 'ユーザー害虫',
      is_reference: false
    } }
  end
  
  pest = Pest.last
  assert_equal admin.id, pest.user_id
  assert_equal false, pest.is_reference
end
```

#### ⚠️ 境界条件: バリデーションエラー

```ruby
test "should not create pest without required fields" do
  user = create(:user)
  sign_in_as user
  
  assert_no_difference('Pest.count') do
    post pests_path, params: { pest: {
      name: ''
    } }
  end
  
  assert_response :unprocessable_entity
  assert_select '.errors'
end
```

#### ⚠️ 境界条件: ネスト属性を含む作成

```ruby
test "should create pest with nested temperature_profile" do
  user = create(:user)
  sign_in_as user
  
  assert_difference(['Pest.count', 'PestTemperatureProfile.count']) do
    post pests_path, params: { pest: {
      name: 'テスト害虫',
      pest_temperature_profile_attributes: {
        base_temperature: 10.0,
        max_temperature: 30.0
      }
    } }
  end
  
  pest = Pest.last
  assert_not_nil pest.pest_temperature_profile
  assert_equal 10.0, pest.pest_temperature_profile.base_temperature
end
```

### 2.4 更新 (update)

#### ✅ 必須: 自分の害虫の更新

```ruby
test "user should update own pest" do
  user = create(:user)
  sign_in_as user
  
  my_pest = create(:pest, :user_owned, user: user, name: '元の名前')
  
  patch pest_path(my_pest), params: { pest: {
    name: '更新された名前'
  } }
  
  assert_redirected_to pest_path(my_pest)
  my_pest.reload
  assert_equal '更新された名前', my_pest.name
end
```

#### ✅ 必須: 他のユーザーの害虫の更新拒否

```ruby
test "user should not update other user pest" do
  user = create(:user)
  other_user = create(:user)
  sign_in_as user
  
  other_pest = create(:pest, :user_owned, user: other_user, name: '元の名前')
  
  patch pest_path(other_pest), params: { pest: {
    name: '変更しようとした名前'
  } }
  
  assert_redirected_to pests_path
  assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
  
  other_pest.reload
  assert_equal '元の名前', other_pest.name
end
```

#### ✅ 必須: 参照害虫の更新権限

```ruby
test "admin should update reference pest" do
  admin = create(:user, admin: true)
  sign_in_as admin
  
  ref_pest = create(:pest, is_reference: true, user_id: nil, name: '元の名前')
  
  patch pest_path(ref_pest), params: { pest: {
    name: '更新された名前'
  } }
  
  assert_redirected_to pest_path(ref_pest)
  ref_pest.reload
  assert_equal '更新された名前', ref_pest.name
end

test "regular user should not update reference pest" do
  user = create(:user)
  sign_in_as user
  
  ref_pest = create(:pest, is_reference: true, user_id: nil, name: '元の名前')
  
  patch pest_path(ref_pest), params: { pest: {
    name: '変更しようとした名前'
  } }
  
  assert_redirected_to pests_path
  assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
end
```

#### ⚠️ 境界条件: is_referenceフラグの変更

```ruby
test "admin should change is_reference flag" do
  admin = create(:user, admin: true)
  sign_in_as admin
  
  pest = create(:pest, :user_owned, user: admin, is_reference: false)
  
  patch pest_path(pest), params: { pest: {
    is_reference: true
  } }
  
  assert_redirected_to pest_path(pest)
  pest.reload
  assert_equal true, pest.is_reference
  assert_nil pest.user_id
end

test "regular user should not change is_reference flag" do
  user = create(:user)
  sign_in_as user
  
  pest = create(:pest, :user_owned, user: user, is_reference: false)
  
  patch pest_path(pest), params: { pest: {
    is_reference: true
  } }
  
  assert_redirected_to pest_path(pest)
  assert_equal I18n.t('pests.flash.reference_flag_admin_only'), flash[:alert]
  
  pest.reload
  assert_equal false, pest.is_reference
end
```

### 2.5 削除 (destroy)

#### ✅ 必須: 自分の害虫の削除

```ruby
test "user should delete own pest" do
  user = create(:user)
  sign_in_as user
  
  my_pest = create(:pest, :user_owned, user: user)
  
  assert_difference('Pest.count', -1) do
    delete pest_path(my_pest)
  end
  
  assert_redirected_to pests_path
end
```

#### ✅ 必須: 他のユーザーの害虫の削除拒否

```ruby
test "user should not delete other user pest" do
  user = create(:user)
  other_user = create(:user)
  sign_in_as user
  
  other_pest = create(:pest, :user_owned, user: other_user)
  
  assert_no_difference('Pest.count') do
    delete pest_path(other_pest)
  end
  
  assert_redirected_to pests_path
  assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
end
```

#### ✅ 必須: 参照害虫の削除権限

```ruby
test "admin should delete reference pest" do
  admin = create(:user, admin: true)
  sign_in_as admin
  
  ref_pest = create(:pest, is_reference: true, user_id: nil)
  
  assert_difference('Pest.count', -1) do
    delete pest_path(ref_pest)
  end
  
  assert_redirected_to pests_path
end

test "regular user should not delete reference pest" do
  user = create(:user)
  sign_in_as user
  
  ref_pest = create(:pest, is_reference: true, user_id: nil)
  
  assert_no_difference('Pest.count') do
    delete pest_path(ref_pest)
  end
  
  assert_redirected_to pests_path
  assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
end
```

#### ⚠️ 境界条件: 外部参照制約エラー

```ruby
test "should handle foreign key constraint error on delete" do
  user = create(:user)
  sign_in_as user
  
  pest = create(:pest, :user_owned, user: user)
  crop = create(:crop)
  CropPest.create!(crop: crop, pest: pest)
  
  delete pest_path(pest)
  
  # 外部参照制約エラーの場合の処理を確認
  # 実装によっては削除できない場合がある
end
```

---

## 3. 統合テスト

### 3.1 権限の組み合わせテスト

#### ✅ 必須: 複数ユーザー間での権限確認

```ruby
test "multiple users should only see their own pests" do
  user1 = create(:user)
  user2 = create(:user)
  user3 = create(:user)
  
  # 各ユーザーの害虫を作成
  user1_pest = create(:pest, :user_owned, user: user1)
  user2_pest = create(:pest, :user_owned, user: user2)
  user3_pest = create(:pest, :user_owned, user: user3)
  ref_pest = create(:pest, is_reference: true, user_id: nil)
  
  # user1でログイン
  sign_in_as user1
  get pests_path
  visible_pests = assigns(:pests)
  assert_includes visible_pests, ref_pest
  assert_includes visible_pests, user1_pest
  assert_not_includes visible_pests, user2_pest
  assert_not_includes visible_pests, user3_pest
  
  # user2でログイン
  sign_in_as user2
  get pests_path
  visible_pests = assigns(:pests)
  assert_includes visible_pests, ref_pest
  assert_includes visible_pests, user2_pest
  assert_not_includes visible_pests, user1_pest
  assert_not_includes visible_pests, user3_pest
end
```

### 3.2 データ整合性テスト

#### ✅ 必須: user_idの自動設定確認

```ruby
test "user_id should be automatically set on creation" do
  user = create(:user)
  sign_in_as user
  
  # user_idをパラメータに含めない
  post pests_path, params: { pest: {
    name: 'テスト害虫'
  } }
  
  pest = Pest.last
  assert_equal user.id, pest.user_id, "user_id should be automatically set to current_user.id"
end
```

#### ✅ 必須: 参照害虫のuser_idはnil

```ruby
test "reference pest should have nil user_id" do
  admin = create(:user, admin: true)
  sign_in_as admin
  
  post pests_path, params: { pest: {
    name: '参照害虫',
    is_reference: true
  } }
  
  pest = Pest.last
  assert_nil pest.user_id, "Reference pest should have nil user_id"
end
```

### 3.3 エッジケーステスト

#### ⚠️ 境界条件: user_idが不正な値

```ruby
test "should handle invalid user_id gracefully" do
  user = create(:user)
  sign_in_as user
  
  # 存在しないuser_idを指定しようとする（フォームからは送られないが）
  pest = build(:pest, :user_owned, user_id: 99999)
  
  assert_not pest.valid?
end
```

#### ⚠️ 境界条件: 同時操作

```ruby
test "should handle concurrent pest creation" do
  user1 = create(:user)
  user2 = create(:user)
  
  # 同時に害虫を作成
  sign_in_as user1
  post pests_path, params: { pest: { name: 'User1 Pest' } }
  
  sign_in_as user2
  post pests_path, params: { pest: { name: 'User2 Pest' } }
  
  # それぞれのユーザーIDが正しく設定されている
  pests = Pest.all
  assert_equal 2, pests.count
  assert_equal user1.id, pests.find_by(name: 'User1 Pest').user_id
  assert_equal user2.id, pests.find_by(name: 'User2 Pest').user_id
end
```

---

## 4. テスト実装の優先順位

### 高優先度（必須）
1. ✅ バリデーションテスト（user_id必須チェック）
2. ✅ 一覧表示の権限フィルタリング
3. ✅ 詳細表示の権限チェック
4. ✅ 作成時のuser_id自動設定
5. ✅ 更新・削除の権限チェック

### 中優先度（推奨）
1. ⚠️ スコープテスト
2. ⚠️ 境界条件テスト
3. ⚠️ ネスト属性を含む操作

### 低優先度（オプション）
1. ⚠️ エッジケーステスト
2. ⚠️ パフォーマンステスト

---

## 5. テストカバレッジの確認項目

### モデル層
- [ ] user_idのバリデーション（is_referenceとの組み合わせ）
- [ ] referenceスコープ
- [ ] user_ownedスコープ
- [ ] belongs_to :userの動作確認

### コントローラー層
- [ ] index: 一般ユーザーは自分の害虫+参照害虫のみ
- [ ] index: 管理者は全て表示
- [ ] show: 権限チェック（参照/自分の/他のユーザーの）
- [ ] create: user_idの自動設定
- [ ] create: 参照害虫作成の権限チェック
- [ ] update: 自分の害虫のみ更新可能
- [ ] update: 参照害虫は管理者のみ更新可能
- [ ] destroy: 自分の害虫のみ削除可能
- [ ] destroy: 参照害虫は管理者のみ削除可能

### 統合
- [ ] 複数ユーザー間での権限分離
- [ ] データ整合性（user_idの自動設定）
- [ ] エラーハンドリング

---

## 6. 既存テストの修正が必要な箇所

### 修正が必要なテスト
1. `create(:pest, is_reference: false)` → `create(:pest, :user_owned, user: user)`に変更
2. 参照害虫のテストは`user_id: nil`を明示的に指定
3. ユーザー害虫のテストは`:user_owned`トレイトを使用

---

## 7. テスト実行時の注意点

1. **データのクリーンアップ**: 各テスト間でデータが混在しないよう注意
2. **ユーザーセッション**: `sign_in_as`で正しくユーザーを切り替える
3. **ファクトリー**: `:user_owned`トレイトを適切に使用する
4. **アサーション**: `assigns(:pests)`を使った検証が有効

---

## 8. 追加で考慮すべきテストシナリオ

### セキュリティ関連
- SQLインジェクション対策（既にActiveRecordで保護）
- CSRFトークン（Rails標準機能）
- パラメータ改ざんの試行

### パフォーマンス
- 大量の害虫データでの一覧表示
- N+1クエリの有無

### データ移行
- 既存データへのuser_id追加の影響
- マイグレーション後の整合性確認








