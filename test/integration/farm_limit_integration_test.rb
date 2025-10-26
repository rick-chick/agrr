# frozen_string_literal: true

require 'test_helper'

class FarmLimitIntegrationTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: 'farm_limit_integration_test@example.com',
      name: 'Farm Limit Integration Test User',
      google_id: 'farm_limit_integration_test_123',
      is_anonymous: false
    )
    
    @ref_farm = Farm.reference.first
    @ref_crop = Crop.reference.first
    
    # 参照農場がない場合は作成
    if @ref_farm.nil?
      anonymous_user = User.anonymous_user
      @ref_farm = Farm.create!(
        user: anonymous_user,
        name: 'テスト参照農場',
        latitude: 35.0,
        longitude: 139.0,
        is_reference: true,
        region: 'jp'
      )
    end
    
    # 参照作物がない場合は作成
    if @ref_crop.nil?
      @ref_crop = Crop.create!(
        user: nil,
        name: 'テスト参照作物',
        variety: 'テスト品種',
        is_reference: true,
        area_per_unit: 0.25,
        revenue_per_area: 5000.0,
        region: 'jp'
      )
    end
  end

  def teardown
    @user.destroy if @user.persisted?
  end

  test "should allow creating up to 4 farms per user" do
    # 農場を4つまで作成
    (1..4).each do |i|
      farm = Farm.create!(
        user: @user,
        name: "テスト農場 #{i}",
        latitude: 35.0 + i * 0.1,
        longitude: 135.0 + i * 0.1,
        is_reference: false
      )
      assert farm.persisted?, "Farm #{i} should be created successfully"
    end
    
    assert_equal 4, @user.farms.where(is_reference: false).count
  end

  test "should prevent creating 5th farm" do
    # 農場を4つ作成
    4.times do |i|
      Farm.create!(
        user: @user,
        name: "既存農場 #{i + 1}",
        latitude: 35.0 + i * 0.1,
        longitude: 135.0 + i * 0.1,
        is_reference: false
      )
    end
    
    # 5つ目の農場作成を試行
    farm5 = Farm.new(
      user: @user,
      name: 'テスト農場 5',
      latitude: 35.5,
      longitude: 135.5,
      is_reference: false
    )
    
    assert_not farm5.valid?, "5th farm should not be valid"
    assert_includes farm5.errors[:user], "作成できるFarmは4件までです"
  end

  test "should allow unlimited reference farms" do
    anonymous_user = User.anonymous_user
    initial_count = anonymous_user.farms.where(is_reference: true).count
    
    # 参照農場を複数作成
    5.times do |i|
      ref_farm = Farm.create!(
        user: anonymous_user,
        name: "参照農場テスト #{i + 1}",
        latitude: 36.0 + i * 0.1,
        longitude: 136.0 + i * 0.1,
        is_reference: true
      )
      assert ref_farm.persisted?, "Reference farm #{i + 1} should be created successfully"
    end
    
    expected_count = initial_count + 5
    assert_equal expected_count, anonymous_user.farms.where(is_reference: true).count
  end

  test "should prevent farm creation in PlanSaveService when limit reached" do
    # ユーザーが4つの農場を持っている状態を作成
    4.times do |i|
      Farm.create!(
        user: @user,
        name: "既存農場 #{i + 1}",
        latitude: 35.0 + i * 0.1,
        longitude: 135.0 + i * 0.1,
        is_reference: false
      )
    end
    
    # セッションデータを準備
    session_data = {
      farm_id: @ref_farm.id,
      crop_ids: [@ref_crop.id],
      field_data: [{ name: 'テスト圃場', area: 100.0, coordinates: [35.0, 139.0] }]
    }
    
    # 計画を作成
    plan = CultivationPlan.create!(
      farm: @ref_farm,
      user: nil,
      total_area: 100.0,
      status: 'completed',
      plan_type: 'public',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year
    )
    session_data[:plan_id] = plan.id
    
    # PlanSaveServiceを実行（失敗するはず）
    result = PlanSaveService.new(user: @user, session_data: session_data).call
    
    # 失敗することを確認
    assert_not result.success, "PlanSaveService should fail when farm limit is reached"
    assert_includes result.error_message, "作成できるFarmは4件までです", "Error message should mention farm limit"
  end

  test "should work correctly with existing farms" do
    # 既存の農場がある状態で新しい農場を作成
    existing_farm = Farm.create!(
      user: @user,
      name: "既存農場",
      latitude: 35.0,
      longitude: 135.0,
      is_reference: false
    )
    
    # 残り3つの農場を作成
    3.times do |i|
      farm = Farm.create!(
        user: @user,
        name: "追加農場 #{i + 1}",
        latitude: 35.1 + i * 0.1,
        longitude: 135.1 + i * 0.1,
        is_reference: false
      )
      assert farm.persisted?, "Additional farm #{i + 1} should be created successfully"
    end
    
    assert_equal 4, @user.farms.where(is_reference: false).count
    
    # 5つ目の農場作成を試行
    farm5 = Farm.new(
      user: @user,
      name: '制限テスト農場',
      latitude: 35.5,
      longitude: 135.5,
      is_reference: false
    )
    
    assert_not farm5.valid?, "5th farm should not be valid"
  end
end
