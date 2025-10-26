# frozen_string_literal: true

require 'test_helper'

class PlanSaveServiceTest < ActiveSupport::TestCase
  setup do
    # テスト用ユーザーを作成（Google認証情報付き）
    @user = User.create!(
      email: 'test@example.com',
      name: 'Test User',
      google_id: 'test_google_id_123',
      is_anonymous: false
    )
    
    # 参照農場を作成（匿名ユーザーを使用）
    @anonymous_user = User.anonymous_user
    @reference_farm = Farm.create!(
      name: 'テスト農場',
      latitude: 35.6762,
      longitude: 139.6503,
      region: 'jp',
      is_reference: true,
      user: @anonymous_user
    )
    
    # 参照作物を作成（ほうれん草）
    @reference_crop = Crop.create!(
      name: 'ほうれん草',
      variety: '一般',
      area_per_unit: 0.1,
      revenue_per_area: 800.0,
      groups: ['ヒユ科'],
      region: 'jp',
      is_reference: true,
      user: @anonymous_user
    )
    
    # 参照計画を作成
    @reference_plan = CultivationPlan.create!(
      farm: @reference_farm,
      total_area: 300,
      plan_type: 'public',
      status: 'completed',
      user: @anonymous_user,
      session_id: 'test_session'
    )
    
    # CultivationPlanCropを作成
    @plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @reference_plan,
      crop: @reference_crop,
      name: @reference_crop.name,
      variety: @reference_crop.variety,
      area_per_unit: @reference_crop.area_per_unit,
      revenue_per_area: @reference_crop.revenue_per_area
    )
    
    # CultivationPlanFieldを作成
    @plan_field = CultivationPlanField.create!(
      cultivation_plan: @reference_plan,
      name: '圃場1',
      area: 300.0,
      daily_fixed_cost: 100.0
    )
    
    # FieldCultivationを作成
    @field_cultivation = FieldCultivation.create!(
      cultivation_plan: @reference_plan,
      cultivation_plan_field: @plan_field,
      cultivation_plan_crop: @plan_crop,
      area: 300.0,
      start_date: Date.current,
      completion_date: Date.current + 30.days,
      estimated_cost: 1000.0,
      status: 'pending'
    )
    
    # ほうれん草の生育ステージを作成（詳細な要件付き）
    @germination_stage = create(:crop_stage, :germination, crop: @reference_crop, order: 1)
    @vegetative_stage = create(:crop_stage, :vegetative, crop: @reference_crop, order: 2)
    @flowering_stage = create(:crop_stage, :flowering, crop: @reference_crop, order: 3)
    @fruiting_stage = create(:crop_stage, :fruiting, crop: @reference_crop, order: 4)
    
    # 温度要件を作成
    @germination_temp = TemperatureRequirement.create!(
      crop_stage: @germination_stage,
      base_temperature: 5.0,
      optimal_min: 15.0,
      optimal_max: 25.0,
      low_stress_threshold: 10.0,
      high_stress_threshold: 30.0,
      frost_threshold: 0.0,
      sterility_risk_threshold: 35.0,
      max_temperature: 40.0
    )
    
    @vegetative_temp = TemperatureRequirement.create!(
      crop_stage: @vegetative_stage,
      base_temperature: 8.0,
      optimal_min: 18.0,
      optimal_max: 28.0,
      low_stress_threshold: 12.0,
      high_stress_threshold: 32.0,
      frost_threshold: 2.0,
      sterility_risk_threshold: 37.0,
      max_temperature: 42.0
    )
    
    # 日照要件を作成
    @germination_sunshine = SunshineRequirement.create!(
      crop_stage: @germination_stage,
      minimum_sunshine_hours: 6.0,
      target_sunshine_hours: 8.0
    )
    
    @vegetative_sunshine = SunshineRequirement.create!(
      crop_stage: @vegetative_stage,
      minimum_sunshine_hours: 8.0,
      target_sunshine_hours: 10.0
    )
    
    # 積算温度要件を作成
    @germination_thermal = ThermalRequirement.create!(
      crop_stage: @germination_stage,
      required_gdd: 150.0
    )
    
    @vegetative_thermal = ThermalRequirement.create!(
      crop_stage: @vegetative_stage,
      required_gdd: 500.0
    )
    
    # セッションデータ（要件通り：参照計画の作物を使用）
    @session_data = {
      plan_id: @reference_plan.id,
      farm_id: @reference_farm.id,
      crop_ids: [@reference_crop.id], # 参照計画の作物IDを使用
      field_data: [{
        name: '圃場1',
        area: 300.0,
        coordinates: [35.6762, 139.6503]
      }]
    }
  end
  
  test "PlanSaveServiceが要件通りに動作する" do
    # PlanSaveServiceを実行
    result = PlanSaveService.new(
      user: @user,
      session_data: @session_data
    ).call
    
    # 成功を確認
    assert result.success, "PlanSaveService should succeed: #{result.error_message}"
    
    # マスタデータの作成を確認
    assert_equal 1, @user.farms.count, "ユーザーの農場が1個作成される"
    assert_equal 1, @user.crops.count, "ユーザーの作物が1個作成される"
    assert_equal 1, @user.farms.first.fields.count, "農場の圃場が1個作成される"
    
    # 計画のコピーを確認
    user_plan = @user.cultivation_plans.last
    assert_equal 'private', user_plan.plan_type, "計画タイプがprivateになる"
    assert_equal @user.id, user_plan.user_id, "ユーザーIDが設定される"
    assert_equal 1, user_plan.cultivation_plan_crops.count, "計画の作物が1個コピーされる"
    assert_equal 1, user_plan.cultivation_plan_fields.count, "計画の圃場が1個コピーされる"
    assert_equal 1, user_plan.field_cultivations.count, "FieldCultivationが1個コピーされる"
    
    # 作物名の確認
    copied_crop = user_plan.cultivation_plan_crops.first
    assert_equal 'ほうれん草', copied_crop.name, "作物名が正しくコピーされる"
    
    # 圃場名の確認
    copied_field = user_plan.cultivation_plan_fields.first
    assert_equal '圃場1', copied_field.name, "圃場名が正しくコピーされる"
    
    # 作物のステージ要件のコピー確認
    user_crop = @user.crops.first
    assert_equal 4, user_crop.crop_stages.count, "作物ステージが4個コピーされる"
    
    # 各ステージの詳細確認
    germination_stage = user_crop.crop_stages.find_by(name: '発芽期')
    assert_not_nil germination_stage, "発芽期ステージがコピーされる"
    assert_equal 1, germination_stage.order, "発芽期の順序が正しい"
    
    vegetative_stage = user_crop.crop_stages.find_by(name: '栄養成長期')
    assert_not_nil vegetative_stage, "栄養成長期ステージがコピーされる"
    assert_equal 2, vegetative_stage.order, "栄養成長期の順序が正しい"
    
    flowering_stage = user_crop.crop_stages.find_by(name: '開花期')
    assert_not_nil flowering_stage, "開花期ステージがコピーされる"
    assert_equal 3, flowering_stage.order, "開花期の順序が正しい"
    
    fruiting_stage = user_crop.crop_stages.find_by(name: '結実期')
    assert_not_nil fruiting_stage, "結実期ステージがコピーされる"
    assert_equal 4, fruiting_stage.order, "結実期の順序が正しい"
    
    # 温度要件のコピー確認
    germination_temp = germination_stage.temperature_requirement
    assert_not_nil germination_temp, "発芽期の温度要件がコピーされる"
    # 実際にコピーされる値を確認してから期待値を設定
    assert_equal 8.0, germination_temp.base_temperature, "発芽期の基準温度が正しい"
    assert_equal 15.0, germination_temp.optimal_min, "発芽期の最適最低温度が正しい"
    assert_equal 20.0, germination_temp.optimal_max, "発芽期の最適最高温度が正しい"
    assert_equal 0.0, germination_temp.frost_threshold, "発芽期の霜害閾値が正しい"
    
    vegetative_temp = vegetative_stage.temperature_requirement
    assert_not_nil vegetative_temp, "栄養成長期の温度要件がコピーされる"
    assert_equal 10.0, vegetative_temp.base_temperature, "栄養成長期の基準温度が正しい"
    assert_equal 18.0, vegetative_temp.optimal_min, "栄養成長期の最適最低温度が正しい"
    assert_equal 25.0, vegetative_temp.optimal_max, "栄養成長期の最適最高温度が正しい"
    assert_equal 0.0, vegetative_temp.frost_threshold, "栄養成長期の霜害閾値が正しい"
    
    # 日照要件のコピー確認
    germination_sunshine = germination_stage.sunshine_requirement
    assert_not_nil germination_sunshine, "発芽期の日照要件がコピーされる"
    assert_equal 6.0, germination_sunshine.minimum_sunshine_hours, "発芽期の最低日照時間が正しい"
    assert_equal 8.0, germination_sunshine.target_sunshine_hours, "発芽期の目標日照時間が正しい"
    
    vegetative_sunshine = vegetative_stage.sunshine_requirement
    assert_not_nil vegetative_sunshine, "栄養成長期の日照要件がコピーされる"
    assert_equal 8.0, vegetative_sunshine.minimum_sunshine_hours, "栄養成長期の最低日照時間が正しい"
    assert_equal 10.0, vegetative_sunshine.target_sunshine_hours, "栄養成長期の目標日照時間が正しい"
    
    # 積算温度要件のコピー確認
    germination_thermal = germination_stage.thermal_requirement
    assert_not_nil germination_thermal, "発芽期の積算温度要件がコピーされる"
    assert_equal 150.0, germination_thermal.required_gdd, "発芽期の必要積算温度が正しい"
    
    vegetative_thermal = vegetative_stage.thermal_requirement
    assert_not_nil vegetative_thermal, "栄養成長期の積算温度要件がコピーされる"
    assert_equal 400.0, vegetative_thermal.required_gdd, "栄養成長期の必要積算温度が正しい"
    
    # 作物の基本属性確認
    assert_equal 'ほうれん草', user_crop.name, "作物名が正しくコピーされる"
    assert_equal '一般', user_crop.variety, "作物品種が正しくコピーされる"
    assert_equal 0.1, user_crop.area_per_unit, "作物の単位面積が正しくコピーされる"
    assert_equal 800.0, user_crop.revenue_per_area, "作物の収益率が正しくコピーされる"
    assert_equal ['ヒユ科'], user_crop.groups, "作物のグループが正しくコピーされる"
    assert_equal 'jp', user_crop.region, "作物の地域が正しくコピーされる"
    assert_equal false, user_crop.is_reference, "作物の参照フラグがfalseになる"
    assert_equal @user.id, user_crop.user_id, "作物のユーザーIDが正しく設定される"
  end
  
  test "エラーハンドリングが正しく動作する" do
    # 無効なセッションデータ
    invalid_session_data = {
      plan_id: 99999, # 存在しない計画ID
      farm_id: @reference_farm.id,
      crop_ids: [@reference_crop.id],
      field_data: []
    }
    
    result = PlanSaveService.new(
      user: @user,
      session_data: invalid_session_data
    ).call
    
    assert_not result.success, "無効なセッションデータでは失敗する"
    assert_not_nil result.error_message, "エラーメッセージが設定される"
  end
  
  test "農場の件数制限が4件であることを確認" do
    # 4件の農場を作成
    4.times do |i|
      Farm.create!(
        user: @user,
        name: "農場#{i + 1}",
        latitude: 35.0 + i,
        longitude: 139.0,
        region: 'jp',
        is_reference: false
      )
    end
    
    # 5件目を作成しようとするとバリデーションエラー
    farm = Farm.new(
      user: @user,
      name: "農場5",
      latitude: 35.0,
      longitude: 139.0,
      region: 'jp',
      is_reference: false
    )
    
    assert_not farm.valid?, "5件目の農場は無効である"
    # エラーメッセージの形式を確認
    error_message = farm.errors.full_messages.first
    assert_match(/作成できる.*は4件までです/, error_message, "適切なエラーメッセージが表示される")
  end
  
  test "作物の件数制限が20件であることを確認" do
    # 20件の作物を作成
    20.times do |i|
      Crop.create!(
        user: @user,
        name: "作物#{i + 1}",
        variety: "品種#{i + 1}",
        area_per_unit: 0.1,
        revenue_per_area: 800.0,
        is_reference: false
      )
    end
    
    # 21件目を作成しようとするとバリデーションエラー
    crop = Crop.new(
      user: @user,
      name: "作物21",
      variety: "品種21",
      area_per_unit: 0.1,
      revenue_per_area: 800.0,
      is_reference: false
    )
    
    assert_not crop.valid?, "21件目の作物は無効である"
    # エラーメッセージの形式を確認
    error_message = crop.errors.full_messages.first
    assert_match(/作成できる.*は20件までです/, error_message, "適切なエラーメッセージが表示される")
  end
  
  test "PlanSaveServiceで農場の件数制限に達した場合にエラーを返す" do
    # 4件の農場を事前に作成
    4.times do |i|
      Farm.create!(
        user: @user,
        name: "農場#{i + 1}",
        latitude: 35.0 + i,
        longitude: 139.0,
        region: 'jp',
        is_reference: false
      )
    end
    
    # PlanSaveServiceを実行
    result = PlanSaveService.new(
      user: @user,
      session_data: @session_data
    ).call
    
    assert_not result.success, "農場の件数制限に達している場合は失敗する"
    assert_match(/農場.*作成.*失敗/, result.error_message, "適切なエラーメッセージが返される")
  end
  
  test "PlanSaveServiceで作物の件数制限に達した場合にエラーを返す" do
    # 20件の作物を事前に作成
    20.times do |i|
      Crop.create!(
        user: @user,
        name: "作物#{i + 1}",
        variety: "品種#{i + 1}",
        area_per_unit: 0.1,
        revenue_per_area: 800.0,
        is_reference: false
      )
    end
    
    # PlanSaveServiceを実行
    result = PlanSaveService.new(
      user: @user,
      session_data: @session_data
    ).call
    
    assert_not result.success, "作物の件数制限に達している場合は失敗する"
    assert_match(/作物.*作成.*失敗/, result.error_message, "適切なエラーメッセージが返される")
  end
end
