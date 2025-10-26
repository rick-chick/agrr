# Public Plans 保存機能 テスト計画書

## 概要
マスタデータ移送図に基づいて、public_plans保存機能の包括的なテスト計画を作成します。

## テスト戦略

### 1. テストレベル
- **単体テスト**: 各コンポーネントの個別テスト
- **統合テスト**: コンポーネント間の連携テスト
- **E2Eテスト**: ユーザーフロー全体のテスト

### 2. テストデータ
- **参照データ**: 既存の参照農場・作物・連作ルール
- **計画データ**: テスト用のCultivationPlan
- **ユーザーデータ**: テスト用のUser

## テストケース一覧

### 1. セッション管理テスト

#### 1.1 セッションデータ保存テスト
```ruby
test "should save plan data to session when not logged in" do
  # 未ログイン状態で保存ボタンをクリック
  get results_public_plans_path
  post save_plan_public_plans_path
  
  # セッションデータが保存されているかチェック
  assert_not_nil session[:public_plan_save_data]
  assert_equal 123, session[:public_plan_save_data][:plan_id]
  assert_equal 456, session[:public_plan_save_data][:farm_id]
  assert_equal [789, 790, 791], session[:public_plan_save_data][:crop_ids]
  assert_not_nil session[:public_plan_save_data][:field_data]
  assert_not_nil session[:public_plan_save_data][:created_at]
end
```

#### 1.2 セッションデータ有効期限テスト
```ruby
test "should handle expired session data" do
  # 24時間前のセッションデータを設定
  session[:public_plan_save_data] = {
    plan_id: 123,
    farm_id: 456,
    crop_ids: [789, 790, 791],
    field_data: [{ name: "Field A", area: 100, coordinates: [35.0, 139.0] }],
    created_at: 24.hours.ago
  }
  
  # 保存処理を実行
  get process_saved_plan_public_plans_path
  
  # エラーが発生するかチェック
  assert_redirected_to results_public_plans_path
  assert_match /セッションが期限切れ/, flash[:alert]
end
```

### 2. 認証フローテスト

#### 2.1 ログイン成功後の保存処理テスト
```ruby
test "should process saved plan after login" do
  # 未ログイン状態で保存ボタンをクリック
  get results_public_plans_path
  post save_plan_public_plans_path
  
  # ログイン
  user = users(:one)
  post auth_login_path, params: { user: { email: user.email } }
  
  # 保存処理の実行
  get process_saved_plan_public_plans_path
  
  assert_redirected_to plans_path
  assert_nil session[:public_plan_save_data]
  assert_match /計画が正常に保存されました/, flash[:notice]
end
```

#### 2.2 サインイン成功後の保存処理テスト
```ruby
test "should process saved plan after signup" do
  # 未ログイン状態で保存ボタンをクリック
  get results_public_plans_path
  post save_plan_public_plans_path
  
  # 新規ユーザー作成（Google OAuth2シミュレーション）
  auth_hash = {
    'uid' => '123456789',
    'info' => {
      'email' => 'newuser@example.com',
      'name' => 'New User',
      'image' => 'avatar.jpg'
    }
  }
  
  # 認証コールバックをシミュレーション
  post '/auth/google_oauth2/callback', params: auth_hash
  
  # 保存処理の実行
  get process_saved_plan_public_plans_path
  
  assert_redirected_to plans_path
  assert_nil session[:public_plan_save_data]
  
  # 新規ユーザーが作成されているかチェック
  new_user = User.find_by(email: 'newuser@example.com')
  assert_not_nil new_user
  assert new_user.cultivation_plans.count > 0
end
```

### 3. マスタデータ作成テスト

#### 3.1 農場の新規作成テスト
```ruby
test "should create new user farm from reference farm" do
  reference_farm = farms(:reference_farm)
  user = users(:one)
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: 123,
      farm_id: reference_farm.id,
      crop_ids: [789, 790, 791],
      field_data: [{ name: "Field A", area: 100, coordinates: [35.0, 139.0] }]
    }
  )
  
  result = service.call
  
  assert result.success?
  
  # 個人農場が作成されているかチェック
  user_farm = user.farms.last
  assert_not_nil user_farm
  assert_equal false, user_farm.is_reference
  assert_equal user.id, user_farm.user_id
  assert_equal reference_farm.latitude, user_farm.latitude
  assert_equal reference_farm.longitude, user_farm.longitude
  assert_equal reference_farm.region, user_farm.region
  
  # 天気データ取得ジョブが実行されているかチェック
  assert_not_nil user_farm.weather_location_id
end
```

#### 3.2 作物のコピーテスト
```ruby
test "should create user crops from plan crops" do
  plan = cultivation_plans(:public_plan)
  user = users(:one)
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: plan.id,
      farm_id: plan.farm_id,
      crop_ids: plan.cultivation_plan_crops.pluck(:crop_id),
      field_data: []
    }
  )
  
  result = service.call
  
  assert result.success?
  
  # 個人作物が作成されているかチェック
  user_crops = user.crops.where(is_reference: false)
  assert user_crops.count > 0
  
  # 作物ステージがコピーされているかチェック
  user_crop = user_crops.first
  assert user_crop.crop_stages.count > 0
  
  # 要件データがコピーされているかチェック
  stage = user_crop.crop_stages.first
  assert stage.temperature_requirement.present? || stage.thermal_requirement.present?
end
```

#### 3.3 圃場の作成テスト
```ruby
test "should create user fields from plan fields" do
  plan = cultivation_plans(:public_plan)
  user = users(:one)
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: plan.id,
      farm_id: plan.farm_id,
      crop_ids: [],
      field_data: [
        { name: "Field A", area: 100, coordinates: [35.0, 139.0] },
        { name: "Field B", area: 200, coordinates: [35.1, 139.1] }
      ]
    }
  )
  
  result = service.call
  
  assert result.success?
  
  # 個人圃場が作成されているかチェック
  user_farm = user.farms.last
  assert user_farm.fields.count == 2
  
  field_a = user_farm.fields.find_by(name: "Field A")
  assert_not_nil field_a
  assert_equal 100, field_a.area
  assert_equal [35.0, 139.0], field_a.coordinates
end
```

#### 3.4 連作ルールのコピーテスト
```ruby
test "should create user interaction rules from plan rules" do
  plan = cultivation_plans(:public_plan)
  user = users(:one)
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: plan.id,
      farm_id: plan.farm_id,
      crop_ids: plan.cultivation_plan_crops.pluck(:crop_id),
      field_data: []
    }
  )
  
  result = service.call
  
  assert result.success?
  
  # 個人連作ルールが作成されているかチェック
  user_rules = user.interaction_rules
  assert user_rules.count > 0
  
  # ルールの詳細がコピーされているかチェック
  rule = user_rules.first
  assert_not_nil rule.crop1
  assert_not_nil rule.crop2
  assert_not_nil rule.interaction_type
  assert_not_nil rule.description
end
```

### 4. マスタデータ間の関連付けテスト

#### 4.1 農場と圃場の関連付けテスト
```ruby
test "should establish farm-field relationships" do
  plan = cultivation_plans(:public_plan)
  user = users(:one)
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: plan.id,
      farm_id: plan.farm_id,
      crop_ids: [],
      field_data: [
        { name: "Field A", area: 100, coordinates: [35.0, 139.0] }
      ]
    }
  )
  
  result = service.call
  
  assert result.success?
  
  # 農場と圃場の関連付けをチェック
  user_farm = user.farms.last
  field = user_farm.fields.first
  
  assert_equal user_farm.id, field.farm_id
  assert user_farm.fields.include?(field)
end
```

#### 4.2 作物と連作ルールの関連付けテスト
```ruby
test "should establish crop-interaction rule relationships" do
  plan = cultivation_plans(:public_plan)
  user = users(:one)
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: plan.id,
      farm_id: plan.farm_id,
      crop_ids: plan.cultivation_plan_crops.pluck(:crop_id),
      field_data: []
    }
  )
  
  result = service.call
  
  assert result.success?
  
  # 作物と連作ルールの関連付けをチェック
  user_crops = user.crops.where(is_reference: false)
  user_rules = user.interaction_rules
  
  assert user_rules.count > 0
  
  # ルールの作物が正しく関連付けられているかチェック
  rule = user_rules.first
  assert user_crops.include?(rule.crop1)
  assert user_crops.include?(rule.crop2)
end
```

### 5. 計画のコピーテスト

#### 5.1 CultivationPlanのコピーテスト
```ruby
test "should copy cultivation plan from public to private" do
  plan = cultivation_plans(:public_plan)
  user = users(:one)
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: plan.id,
      farm_id: plan.farm_id,
      crop_ids: plan.cultivation_plan_crops.pluck(:crop_id),
      field_data: []
    }
  )
  
  result = service.call
  
  assert result.success?
  
  # 個人計画が作成されているかチェック
  user_plan = user.cultivation_plans.last
  assert_not_nil user_plan
  assert_equal "private", user_plan.plan_type
  assert_equal user.id, user_plan.user_id
  assert_nil user_plan.session_id
  assert_equal Date.current.year, user_plan.plan_year
  assert_equal Date.current.beginning_of_year, user_plan.planning_start_date
  assert_equal Date.current.end_of_year, user_plan.planning_end_date
end
```

#### 5.2 関連データのコピーテスト
```ruby
test "should copy plan relations" do
  plan = cultivation_plans(:public_plan)
  user = users(:one)
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: plan.id,
      farm_id: plan.farm_id,
      crop_ids: plan.cultivation_plan_crops.pluck(:crop_id),
      field_data: []
    }
  )
  
  result = service.call
  
  assert result.success?
  
  # 関連データがコピーされているかチェック
  user_plan = user.cultivation_plans.last
  
  # CultivationPlanFieldのコピー
  assert user_plan.cultivation_plan_fields.count > 0
  
  # CultivationPlanCropのコピー
  assert user_plan.cultivation_plan_crops.count > 0
  
  # FieldCultivationのコピー
  assert user_plan.field_cultivations.count > 0
end
```

### 6. データ整合性テスト

#### 6.1 農場チェックテスト
```ruby
test "should validate farm relationships" do
  plan = cultivation_plans(:public_plan)
  user = users(:one)
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: plan.id,
      farm_id: plan.farm_id,
      crop_ids: [],
      field_data: [
        { name: "Field A", area: 100, coordinates: [35.0, 139.0] }
      ]
    }
  )
  
  result = service.call
  
  assert result.success?
  
  # 農場の整合性をチェック
  user_farm = user.farms.last
  assert user_farm.fields.count == 1
  assert user_farm.fields.first.name == "Field A"
end
```

#### 6.2 作物チェックテスト
```ruby
test "should validate crop relationships" do
  plan = cultivation_plans(:public_plan)
  user = users(:one)
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: plan.id,
      farm_id: plan.farm_id,
      crop_ids: plan.cultivation_plan_crops.pluck(:crop_id),
      field_data: []
    }
  )
  
  result = service.call
  
  assert result.success?
  
  # 作物の整合性をチェック
  user_crops = user.crops.where(is_reference: false)
  assert user_crops.count > 0
  assert user_crops.all?(&:persisted?)
  
  # 作物ステージの整合性をチェック
  user_crop = user_crops.first
  assert user_crop.crop_stages.count > 0
  assert user_crop.crop_stages.all?(&:persisted?)
end
```

#### 6.3 連作ルールチェックテスト
```ruby
test "should validate interaction rule relationships" do
  plan = cultivation_plans(:public_plan)
  user = users(:one)
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: plan.id,
      farm_id: plan.farm_id,
      crop_ids: plan.cultivation_plan_crops.pluck(:crop_id),
      field_data: []
    }
  )
  
  result = service.call
  
  assert result.success?
  
  # 連作ルールの整合性をチェック
  user_rules = user.interaction_rules
  assert user_rules.count > 0
  assert user_rules.all?(&:persisted?)
  
  # ルールの作物が正しく関連付けられているかチェック
  rule = user_rules.first
  assert_not_nil rule.crop1
  assert_not_nil rule.crop2
  assert rule.crop1.persisted?
  assert rule.crop2.persisted?
end
```

### 7. エラーハンドリングテスト

#### 7.1 バリデーションエラーテスト
```ruby
test "should handle validation errors" do
  user = users(:one)
  
  # 無効なセッションデータを設定
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: nil,
      farm_id: nil,
      crop_ids: [],
      field_data: []
    }
  )
  
  result = service.call
  
  assert_not result.success?
  assert_not_nil result.error_message
end
```

#### 7.2 データ不整合エラーテスト
```ruby
test "should handle data inconsistency errors" do
  user = users(:one)
  
  # 存在しない計画IDを設定
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: 999999,
      farm_id: 1,
      crop_ids: [],
      field_data: []
    }
  )
  
  result = service.call
  
  assert_not result.success?
  assert_not_nil result.error_message
end
```

#### 7.3 権限エラーテスト
```ruby
test "should handle permission errors" do
  # 他のユーザーの計画を保存しようとする
  other_user = users(:two)
  plan = cultivation_plans(:public_plan)
  
  service = PlanSaveService.new(
    user: other_user,
    session_data: {
      plan_id: plan.id,
      farm_id: plan.farm_id,
      crop_ids: [],
      field_data: []
    }
  )
  
  result = service.call
  
  # 権限エラーが発生するかチェック
  assert_not result.success?
  assert_match /権限がありません/, result.error_message
end
```

### 8. パフォーマンステスト

#### 8.1 大量データ処理テスト
```ruby
test "should handle large datasets efficiently" do
  user = users(:one)
  
  # 大量の作物データを設定
  large_crop_ids = (1..100).to_a
  large_field_data = (1..50).map do |i|
    {
      name: "Field #{i}",
      area: 100 + i,
      coordinates: [35.0 + i * 0.001, 139.0 + i * 0.001]
    }
  end
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: 123,
      farm_id: 1,
      crop_ids: large_crop_ids,
      field_data: large_field_data
    }
  )
  
  # 実行時間を測定
  start_time = Time.current
  result = service.call
  end_time = Time.current
  
  assert result.success?
  assert (end_time - start_time) < 30.seconds # 30秒以内に完了
end
```

#### 8.2 メモリ使用量テスト
```ruby
test "should handle memory usage efficiently" do
  user = users(:one)
  
  # メモリ使用量を測定
  memory_before = `ps -o rss= -p #{Process.pid}`.to_i
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: 123,
      farm_id: 1,
      crop_ids: [1, 2, 3],
      field_data: [
        { name: "Field A", area: 100, coordinates: [35.0, 139.0] }
      ]
    }
  )
  
  result = service.call
  
  memory_after = `ps -o rss= -p #{Process.pid}`.to_i
  memory_increase = memory_after - memory_before
  
  assert result.success?
  assert memory_increase < 100_000_000 # 100MB以内のメモリ増加
end
```

### 9. 統合テスト

#### 9.1 完全なユーザーフローテスト
```ruby
test "should complete full user flow" do
  # 1. 未ログイン状態で保存ボタンをクリック
  get results_public_plans_path
  post save_plan_public_plans_path
  
  # 2. ログイン画面にリダイレクト
  assert_redirected_to auth_login_path
  assert_not_nil session[:public_plan_save_data]
  
  # 3. ログイン
  user = users(:one)
  post auth_login_path, params: { user: { email: user.email } }
  
  # 4. 保存処理の実行
  get process_saved_plan_public_plans_path
  
  # 5. 成功時のリダイレクト
  assert_redirected_to plans_path
  assert_nil session[:public_plan_save_data]
  assert_match /計画が正常に保存されました/, flash[:notice]
  
  # 6. データが正しく作成されているかチェック
  assert user.cultivation_plans.count > 0
  assert user.farms.count > 0
  assert user.crops.count > 0
  assert user.fields.count > 0
  assert user.interaction_rules.count > 0
end
```

#### 9.2 サインインフローテスト
```ruby
test "should complete signup flow" do
  # 1. 未ログイン状態で保存ボタンをクリック
  get results_public_plans_path
  post save_plan_public_plans_path
  
  # 2. ログイン画面にリダイレクト
  assert_redirected_to auth_login_path
  assert_not_nil session[:public_plan_save_data]
  
  # 3. 新規ユーザー作成
  auth_hash = {
    'uid' => '123456789',
    'info' => {
      'email' => 'newuser@example.com',
      'name' => 'New User',
      'image' => 'avatar.jpg'
    }
  }
  
  post '/auth/google_oauth2/callback', params: auth_hash
  
  # 4. 保存処理の実行
  get process_saved_plan_public_plans_path
  
  # 5. 成功時のリダイレクト
  assert_redirected_to plans_path
  assert_nil session[:public_plan_save_data]
  
  # 6. 新規ユーザーが作成されているかチェック
  new_user = User.find_by(email: 'newuser@example.com')
  assert_not_nil new_user
  assert new_user.cultivation_plans.count > 0
  assert new_user.farms.count > 0
  assert new_user.crops.count > 0
end
```

### 10. エッジケーステスト

#### 10.1 空の計画データテスト
```ruby
test "should handle empty plan data" do
  user = users(:one)
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: 123,
      farm_id: 1,
      crop_ids: [],
      field_data: []
    }
  )
  
  result = service.call
  
  # 空のデータでも正常に処理されるかチェック
  assert result.success?
  assert user.cultivation_plans.count > 0
  assert user.farms.count > 0
end
```

#### 10.2 重複データテスト
```ruby
test "should handle duplicate data" do
  user = users(:one)
  
  # 既存の作物と同じ名前の作物を作成
  existing_crop = user.crops.create!(
    name: "トマト",
    variety: "大玉",
    area_per_unit: 0.25,
    revenue_per_area: 5000.0,
    is_reference: false
  )
  
  service = PlanSaveService.new(
    user: user,
    session_data: {
      plan_id: 123,
      farm_id: 1,
      crop_ids: [existing_crop.id],
      field_data: []
    }
  )
  
  result = service.call
  
  # 重複データが適切に処理されるかチェック
  assert result.success?
  assert user.crops.where(name: "トマト").count == 1
end
```

## テスト実行計画

### Phase 1: 基本機能テスト（1週間）
1. セッション管理テスト
2. 認証フローテスト
3. 基本的なマスタデータ作成テスト

### Phase 2: マスタデータ処理テスト（1週間）
1. 農場の新規作成テスト
2. 作物のコピーテスト
3. 圃場の作成テスト
4. 連作ルールのコピーテスト

### Phase 3: 関連付けテスト（1週間）
1. マスタデータ間の関連付けテスト
2. 計画のコピーテスト
3. データ整合性テスト

### Phase 4: エラーハンドリングテスト（1週間）
1. バリデーションエラーテスト
2. データ不整合エラーテスト
3. 権限エラーテスト

### Phase 5: パフォーマンステスト（1週間）
1. 大量データ処理テスト
2. メモリ使用量テスト
3. 統合テスト

### Phase 6: エッジケーステスト（1週間）
1. 空の計画データテスト
2. 重複データテスト
3. 境界値テスト

## テスト環境

### 1. 開発環境
- **データベース**: SQLite（テスト用）
- **認証**: モック認証
- **外部API**: モック化

### 2. ステージング環境
- **データベース**: PostgreSQL
- **認証**: Google OAuth2（テスト用）
- **外部API**: 実際のAPI

### 3. 本番環境
- **データベース**: PostgreSQL
- **認証**: Google OAuth2（本番用）
- **外部API**: 実際のAPI

## テスト結果の評価基準

### 1. 機能テスト
- **成功率**: 100%
- **エラー率**: 0%
- **レスポンス時間**: 30秒以内

### 2. パフォーマンステスト
- **メモリ使用量**: 100MB以内
- **CPU使用率**: 80%以内
- **データベースクエリ**: 100クエリ以内

### 3. セキュリティテスト
- **認証**: 100%成功
- **認可**: 100%成功
- **データ保護**: 100%成功

## テスト自動化

### 1. CI/CDパイプライン
- **GitHub Actions**: プルリクエスト時の自動テスト
- **Docker**: テスト環境の自動構築
- **データベース**: テスト用データの自動生成

### 2. テストレポート
- **カバレッジ**: 90%以上
- **実行時間**: 10分以内
- **結果**: 自動レポート生成

### 3. 継続的テスト
- **毎日**: 基本機能テスト
- **毎週**: 統合テスト
- **毎月**: パフォーマンステスト
