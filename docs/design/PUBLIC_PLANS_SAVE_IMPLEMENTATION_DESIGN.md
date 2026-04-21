# Public Plans 保存機能 実装設計書

## アーキテクチャ概要

### 1. コンポーネント構成
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Controller    │    │    Service      │    │     Model       │
│                 │    │                 │    │                 │
│ PublicPlansCtrl │───▶│ PlanSaveService │───▶│ CultivationPlan │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   View Layer    │    │  Business Logic │    │   Data Layer    │
│                 │    │                 │    │                 │
│ results.html.erb│    │ MasterDataCopy  │    │     Database    │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 2. データフロー
```
1. ユーザーが保存ボタンをクリック
   ↓
2. 未ログインの場合、セッションにデータ保存してログイン画面へ
   ↓
3. ログイン・サインイン成功後、PlanSaveServiceを呼び出し
   ↓
4. マスタデータの作成・取得（Farm, Crop, Field, InteractionRule）
   ↓
5. マスタデータ間の関連付け（Farm↔Field, Crop↔InteractionRule）
   ↓
6. CultivationPlanのコピー（public → private）
   ↓
7. 関連データのコピー（CultivationPlanField, CultivationPlanCrop, FieldCultivation）
   ↓
8. 成功時はplans一覧画面へリダイレクト
```

#### 2.1 サインイン（新規登録）フロー
```
1. 保存ボタンクリック → セッション保存 → ログイン画面
   ↓
2. Google OAuth2認証
   ↓
3. 新規ユーザー作成（User.from_omniauth）
   ↓
4. セッション作成（Session.create_for_user）
   ↓
5. 保存処理実行（既存ユーザーと同じフロー）
```

## 実装詳細

### 1. Controller層

#### 1.1 PublicPlansController の拡張
```ruby
# app/controllers/public_plans_controller.rb
class PublicPlansController < ApplicationController
  # 既存のメソッド...
  
  # 保存ボタンクリック時の処理
  def save_plan
    @cultivation_plan = find_cultivation_plan
    return unless @cultivation_plan
    
    if user_signed_in?
      # ログイン済みの場合、直接保存処理を実行
      save_plan_to_user_account
    else
      # 未ログインの場合、セッションに保存してログイン画面へ
      save_plan_data_to_session
      redirect_to auth_login_path, notice: I18n.t('public_plans.save.login_required')
    end
  end
  
  # ログイン後の保存処理
  def process_saved_plan
    return unless session[:public_plan_save_data]
    
    begin
      result = PlanSaveService.new(
        user: current_user,
        session_data: session[:public_plan_save_data]
      ).call
      
      if result.success?
        session.delete(:public_plan_save_data)
        redirect_to plans_path, notice: I18n.t('public_plans.save.success')
      else
        redirect_to results_public_plans_path, alert: result.error_message
      end
    rescue => e
      Rails.logger.error "Plan save error: #{e.message}"
      redirect_to results_public_plans_path, alert: I18n.t('public_plans.save.error')
    end
  end
  
  private
  
  def save_plan_data_to_session
    session[:public_plan_save_data] = {
      plan_id: @cultivation_plan.id,
      farm_id: @cultivation_plan.farm_id,
      crop_ids: @cultivation_plan.cultivation_plan_crops.pluck(:crop_id),
      field_data: extract_field_data(@cultivation_plan),
      created_at: Time.current
    }
  end
  
  def extract_field_data(plan)
    plan.cultivation_plan_fields.map do |field|
      {
        name: field.name,
        area: field.area,
        coordinates: field.coordinates
      }
    end
  end
end
```

#### 1.2 AuthController の拡張
```ruby
# app/controllers/auth_controller.rb
class AuthController < ApplicationController
  # 既存のメソッド...
  
  def google_oauth2_callback
    # 既存のログイン処理...
    
    if user.persisted?
      # 既存のセッション作成処理...
      
      # 保存データがある場合は保存処理を実行
      if session[:public_plan_save_data]
        redirect_to process_saved_plan_public_plans_path
      else
        redirect_to root_path, notice: I18n.t('auth.flash.login_success')
      end
    end
  end
end
```

### 2. Service層

#### 2.1 PlanSaveService
```ruby
# app/services/plan_save_service.rb
class PlanSaveService
  include ActiveModel::Model
  
  attr_accessor :user, :session_data, :result
  
  def initialize(user:, session_data:)
    @user = user
    @session_data = session_data
    @result = OpenStruct.new(success: false, error_message: nil)
  end
  
  def call
    ActiveRecord::Base.transaction do
      # 1. マスタデータの作成・取得
      farm = create_or_get_user_farm
      crops = create_user_crops_from_plan
      fields = create_user_fields(farm)
      interaction_rules = create_interaction_rules(crops)
      
      # 2. 計画のコピー
      new_plan = copy_cultivation_plan(farm, crops, fields)
      
      # 3. マスタデータ間の関連付け
      establish_master_data_relationships(farm, crops, fields, interaction_rules)
      
      # 4. 関連データのコピー
      copy_plan_relations(new_plan)
      
      @result.success = true
    end
    
    @result
  rescue => e
    Rails.logger.error "PlanSaveService error: #{e.message}"
    @result.error_message = e.message
    @result
  end
  
  private
  
  def create_or_get_user_farm
    reference_farm = Farm.find(@session_data[:farm_id])
    
    # 既存の農場があるかチェック
    existing_farm = @user.farms.find_by(
      latitude: reference_farm.latitude,
      longitude: reference_farm.longitude
    )
    
    return existing_farm if existing_farm
    
    # 新しい農場を作成
    @user.farms.create!(
      name: "#{reference_farm.name} (コピー)",
      latitude: reference_farm.latitude,
      longitude: reference_farm.longitude,
      region: reference_farm.region,
      is_reference: false
    )
  end
  
  def create_user_crops_from_plan
    reference_crops = Crop.where(id: @session_data[:crop_ids])
    user_crops = []
    
    reference_crops.each do |reference_crop|
      # 既存の作物があるかチェック
      existing_crop = @user.crops.find_by(name: reference_crop.name)
      
      if existing_crop
        user_crops << existing_crop
      else
        # 新しい作物を作成
        new_crop = @user.crops.create!(
          name: reference_crop.name,
          variety: reference_crop.variety,
          area_per_unit: reference_crop.area_per_unit,
          revenue_per_area: reference_crop.revenue_per_area,
          groups: reference_crop.groups,
          is_reference: false
        )
        
        # 作物ステージをコピー
        copy_crop_stages(reference_crop, new_crop)
        
        user_crops << new_crop
      end
    end
    
    user_crops
  end
  
  def create_user_fields(farm)
    fields = []
    
    @session_data[:field_data].each do |field_data|
      field = farm.fields.create!(
        name: field_data[:name],
        area: field_data[:area],
        coordinates: field_data[:coordinates]
      )
      fields << field
    end
    
    fields
  end
  
  def create_interaction_rules(crops)
    # 作物の組み合わせから連作ルールを作成
    interaction_rules = []
    
    # 2つの作物の組み合わせで連作ルールを作成
    crops.combination(2).each do |crop1, crop2|
      # 既存の連作ルールをチェック
      existing_rule = @user.interaction_rules.find_by(
        crop1: crop1, crop2: crop2
      ) || @user.interaction_rules.find_by(
        crop1: crop2, crop2: crop1
      )
      
      unless existing_rule
        # 新しい連作ルールを作成
        rule = @user.interaction_rules.create!(
          crop1: crop1,
          crop2: crop2,
          interaction_type: 'neutral', # デフォルトは中立
          description: "#{crop1.name} と #{crop2.name} の連作ルール"
        )
        interaction_rules << rule
      else
        interaction_rules << existing_rule
      end
    end
    
    interaction_rules
  end
  
  def copy_cultivation_plan(farm, crops, fields)
    original_plan = CultivationPlan.find(@session_data[:plan_id])
    
    new_plan = @user.cultivation_plans.create!(
      farm: farm,
      total_area: original_plan.total_area,
      plan_type: 'private',
      plan_year: Date.current.year,
      planning_start_date: Date.current.beginning_of_year,
      planning_end_date: Date.current.end_of_year,
      status: 'completed',
      user: @user
    )
    
    new_plan
  end
  
  def copy_plan_relations(new_plan)
    original_plan = CultivationPlan.find(@session_data[:plan_id])
    
    # CultivationPlanFieldのコピー
    original_plan.cultivation_plan_fields.each do |original_field|
      new_plan.cultivation_plan_fields.create!(
        name: original_field.name,
        area: original_field.area,
        coordinates: original_field.coordinates
      )
    end
    
    # CultivationPlanCropのコピー
    original_plan.cultivation_plan_crops.each do |original_crop|
      new_plan.cultivation_plan_crops.create!(
        crop: find_user_crop_by_reference(original_crop.crop),
        quantity: original_crop.quantity
      )
    end
    
    # FieldCultivationのコピー
    original_plan.field_cultivations.each do |original_cultivation|
      new_plan.field_cultivations.create!(
        cultivation_plan_field: find_new_plan_field(original_cultivation.cultivation_plan_field),
        cultivation_plan_crop: find_new_plan_crop(original_cultivation.cultivation_plan_crop),
        start_date: original_cultivation.start_date,
        end_date: original_cultivation.end_date,
        status: original_cultivation.status
      )
    end
  end
  
  def copy_crop_stages(reference_crop, new_crop)
    reference_crop.crop_stages.includes(:temperature_requirement, :thermal_requirement, :sunshine_requirement).each do |stage|
      new_stage = new_crop.crop_stages.create!(
        name: stage.name,
        order: stage.order
      )
      
      # TemperatureRequirementのコピー
      if stage.temperature_requirement
        new_stage.create_temperature_requirement!(
          base_temperature: stage.temperature_requirement.base_temperature,
          optimal_min: stage.temperature_requirement.optimal_min,
          optimal_max: stage.temperature_requirement.optimal_max,
          low_stress_threshold: stage.temperature_requirement.low_stress_threshold,
          high_stress_threshold: stage.temperature_requirement.high_stress_threshold,
          frost_threshold: stage.temperature_requirement.frost_threshold,
          max_temperature: stage.temperature_requirement.max_temperature
        )
      end
      
      # ThermalRequirementのコピー
      if stage.thermal_requirement
        new_stage.create_thermal_requirement!(
          required_gdd: stage.thermal_requirement.required_gdd
        )
      end
      
      # SunshineRequirementのコピー
      if stage.sunshine_requirement
        new_stage.create_sunshine_requirement!(
          minimum_sunshine_hours: stage.sunshine_requirement.minimum_sunshine_hours,
          target_sunshine_hours: stage.sunshine_requirement.target_sunshine_hours
        )
      end
    end
  end
  
  def find_user_crop_by_reference(reference_crop)
    @user.crops.find_by(name: reference_crop.name)
  end
  
  def find_new_plan_field(original_field)
    new_plan.cultivation_plan_fields.find_by(name: original_field.name)
  end
  
  def find_new_plan_crop(original_crop)
    new_plan.cultivation_plan_crops.find_by(crop: find_user_crop_by_reference(original_crop.crop))
  end
  
  # マスタデータ間の関連付けを実行
  def establish_master_data_relationships(farm, crops, fields, interaction_rules)
    Rails.logger.info "🔗 Establishing master data relationships"
    
    # 農場と圃場の関連付け
    fields.each do |field|
      field.update!(farm: farm)
      Rails.logger.info "  ✅ Field '#{field.name}' linked to Farm '#{farm.name}'"
    end
    
    # 作物と連作ルールの関連付け
    interaction_rules.each do |rule|
      Rails.logger.info "  ✅ InteractionRule created: #{rule.crop1.name} ↔ #{rule.crop2.name}"
    end
    
    # データ整合性チェック
    validate_master_data_relationships(farm, crops, fields, interaction_rules)
  end
  
  def validate_master_data_relationships(farm, crops, fields, interaction_rules)
    # 農場に圃場が正しく紐付けられているかチェック
    farm.fields.reload
    unless farm.fields.count == fields.count
      raise "Field count mismatch: expected #{fields.count}, got #{farm.fields.count}"
    end
    
    # 作物が正しく作成されているかチェック
    unless crops.all?(&:persisted?)
      raise "Some crops failed to be created"
    end
    
    # 連作ルールが正しく作成されているかチェック
    unless interaction_rules.all?(&:persisted?)
      raise "Some interaction rules failed to be created"
    end
    
    Rails.logger.info "✅ All master data relationships validated successfully"
  end
end
```

### 3. View層

#### 3.1 保存ボタンの追加
```erb
<!-- app/views/public_plans/results.html.erb -->
<div class="results-container">
  <!-- 既存の結果表示 -->
  
  <div class="save-plan-section">
    <h3>計画を保存する</h3>
    <p>この計画をあなたのアカウントに保存して、後で編集・管理できます。</p>
    
    <%= form_with url: save_plan_public_plans_path, method: :post, local: true, class: "save-plan-form" do |form| %>
      <%= form.submit "計画を保存する", class: "btn btn-primary btn-lg" %>
    <% end %>
  </div>
</div>
```

#### 3.2 スタイルの追加
```css
/* app/assets/stylesheets/public_plans.css */
.save-plan-section {
  margin-top: 2rem;
  padding: 1.5rem;
  background-color: #f8f9fa;
  border-radius: 8px;
  border: 1px solid #dee2e6;
}

.save-plan-section h3 {
  color: #495057;
  margin-bottom: 0.5rem;
}

.save-plan-section p {
  color: #6c757d;
  margin-bottom: 1rem;
}

.save-plan-form .btn {
  width: 100%;
  max-width: 300px;
}
```

### 4. ルーティング

#### 4.1 ルートの追加
```ruby
# config/routes.rb
resources :public_plans, only: [:create] do
  collection do
    get :new, path: ''
    get :select_farm_size
    get :select_crop
    get :optimizing
    get :results
    post :save_plan  # 新規追加
    get :process_saved_plan  # 新規追加
  end
end
```

### 5. 国際化

#### 5.1 日本語ロケール
```yaml
# config/locales/views/public_plans.ja.yml
ja:
  public_plans:
    save:
      login_required: "計画を保存するにはログインが必要です"
      success: "計画が正常に保存されました"
      error: "計画の保存中にエラーが発生しました"
      button_text: "計画を保存する"
      section_title: "計画を保存する"
      section_description: "この計画をあなたのアカウントに保存して、後で編集・管理できます。"
```

#### 5.2 英語ロケール
```yaml
# config/locales/views/public_plans.us.yml
us:
  public_plans:
    save:
      login_required: "Login required to save plan"
      success: "Plan saved successfully"
      error: "Error occurred while saving plan"
      button_text: "Save Plan"
      section_title: "Save Plan"
      section_description: "Save this plan to your account for future editing and management."
```

### 6. テスト

#### 6.1 単体テスト
```ruby
# test/domain/cultivation_plan/interactors/plan_save_session_test.rb
require 'test_helper'

class Domain::CultivationPlan::Interactors::PlanSaveSessionTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @session_data = {
      plan_id: cultivation_plans(:public_plan).id,
      farm_id: farms(:reference_farm).id,
      crop_ids: [crops(:reference_crop).id],
      field_data: [{ name: "Field 1", area: 100, coordinates: [35.0, 139.0] }]
    }
  end
  
  test "should save plan successfully" do
    session = Domain::CultivationPlan::Interactors::PlanSaveSession.new(user: @user, session_data: @session_data)
    result = session.call
    
    assert result.success?
    assert @user.cultivation_plans.count > 0
  end
  
  test "should create user farm from reference farm" do
    session = Domain::CultivationPlan::Interactors::PlanSaveSession.new(user: @user, session_data: @session_data)
    result = session.call
    
    assert result.success?
    assert @user.farms.count > 0
    assert_equal false, @user.farms.last.is_reference
  end
  
  test "should create user crops from reference crops" do
    session = Domain::CultivationPlan::Interactors::PlanSaveSession.new(user: @user, session_data: @session_data)
    result = session.call
    
    assert result.success?
    assert @user.crops.count > 0
    assert_equal false, @user.crops.last.is_reference
  end
  
  test "should establish master data relationships" do
    session = Domain::CultivationPlan::Interactors::PlanSaveSession.new(user: @user, session_data: @session_data)
    result = session.call
    
    assert result.success?
    
    # 農場と圃場の関連付けをチェック
    farm = @user.farms.last
    assert farm.fields.count > 0
    
    # 作物と連作ルールの関連付けをチェック
    assert @user.interaction_rules.count > 0
  end
  
  test "should copy crop stages with requirements" do
    session = Domain::CultivationPlan::Interactors::PlanSaveSession.new(user: @user, session_data: @session_data)
    result = session.call
    
    assert result.success?
    
    # 作物ステージがコピーされているかチェック
    user_crop = @user.crops.last
    assert user_crop.crop_stages.count > 0
    
    # 要件データがコピーされているかチェック
    stage = user_crop.crop_stages.first
    assert stage.temperature_requirement.present? || stage.thermal_requirement.present?
  end
end
```

#### 6.2 統合テスト
```ruby
# test/integration/public_plans_save_test.rb
require 'test_helper'

class PublicPlansSaveTest < ActionDispatch::IntegrationTest
  test "should redirect to login when not authenticated" do
    get results_public_plans_path
    post save_plan_public_plans_path
    
    assert_redirected_to auth_login_path
    assert_not_nil session[:public_plan_save_data]
  end
  
  test "should save plan after login" do
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
  end
  
  test "should save plan after signup" do
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
end
```

## 実装順序

### Phase 1: 基本機能（1週間）
1. 保存ボタンの追加
2. セッション管理の実装
3. 基本的な保存処理

### Phase 2: マスタデータ処理（1週間）
1. 農場のコピー処理
2. 作物のコピー処理（作物ステージ・要件データ含む）
3. 圃場の作成処理
4. 連作ルールの作成処理
5. マスタデータ間の関連付け処理

### Phase 3: 高度な機能（1週間）
1. サインイン（新規登録）フローの実装
2. エラーハンドリングの強化
3. テストの実装

### Phase 4: 最適化（1週間）
1. パフォーマンス最適化
2. UI/UXの改善
3. ドキュメントの整備

## 注意事項

### 1. セキュリティ
- セッションデータの検証
- ユーザー権限の確認
- SQLインジェクション対策

### 2. パフォーマンス
- 大量データの処理
- メモリ使用量の最適化
- データベースクエリの最適化

### 3. エラーハンドリング
- トランザクションの適切な使用
- ロールバック処理
- ユーザーフレンドリーなエラーメッセージ
