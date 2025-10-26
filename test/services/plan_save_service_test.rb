# frozen_string_literal: true

require 'test_helper'

class PlanSaveServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.where(is_anonymous: false).first
    if @user.nil?
      @user = User.create!(
        email: 'test@example.com',
        name: 'Test User',
        google_id: 'test_google_id_123',
        is_anonymous: false
      )
    end
    
    # 理想的な移送方法: セッションデータから農場IDを取得
    # 実際のフローでは、ユーザーが選択した農場IDがセッションデータに保存される
    # テスト環境では参照農場を動的に取得する
    @farm = Farm.reference.first
    if @farm.nil?
      @farm = Farm.create!(
        user: User.anonymous_user,
        name: 'Test Reference Farm',
        latitude: 35.0,
        longitude: 139.0,
        is_reference: true,
        region: 'jp'
      )
    end
    
    puts "Test farm: #{@farm.name} (ID: #{@farm.id})"
    
    @crops = [Crop.reference.first, Crop.reference.first] # 参照作物を2回
    if @crops[0].nil?
      @crops = [
        Crop.create!(
          user: nil,
          name: 'テスト作物',
          variety: 'テスト品種',
          is_reference: true,
          area_per_unit: 0.25,
          revenue_per_area: 5000.0,
          region: 'jp'
        ),
        Crop.create!(
          user: nil,
          name: 'テスト作物',
          variety: 'テスト品種',
          is_reference: true,
          area_per_unit: 0.25,
          revenue_per_area: 5000.0,
          region: 'jp'
        )
      ]
    end
  end

  test "should prevent CultivationPlanCrop duplication when same crop appears multiple times" do
    # 参照計画を作成（同じ作物を複数含む）
    plan = CultivationPlan.create!(
      farm: @farm,
      user: nil, # 参照計画
      total_area: 300.0,
      plan_type: 'public',
      plan_year: Date.current.year,
      plan_name: '重複防止テスト計画',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: 'completed'
    )

    # CultivationPlanCropを手動で作成（同じ名前の作物を複数）
    CultivationPlanCrop.create!(
      cultivation_plan: plan,
      crop: @crops[0],
      name: @crops[0].name,
      variety: '品種A',
      area_per_unit: @crops[0].area_per_unit,
      revenue_per_area: @crops[0].revenue_per_area
    )

    CultivationPlanCrop.create!(
      cultivation_plan: plan,
      crop: @crops[1],
      name: @crops[1].name,
      variety: '品種B',
      area_per_unit: @crops[1].area_per_unit,
      revenue_per_area: @crops[1].revenue_per_area
    )

    # セッションデータを構築
    session_data = {
      plan_id: plan.id,
      farm_id: @farm.id,
      crop_ids: @crops.map(&:id),
      field_data: [
        { name: '重複防止テスト圃場1', area: 100.0, coordinates: [35.0, 139.0] },
        { name: '重複防止テスト圃場2', area: 200.0, coordinates: [35.1, 139.1] }
      ]
    }

    # PlanSaveServiceを実行
    service = PlanSaveService.new(user: @user, session_data: session_data)
    result = service.call
    
    # 成功を確認
    assert result.success, "PlanSaveService should succeed: #{result.error_message}"
    
    # 作成された計画を取得
    new_plan = @user.cultivation_plans.where(plan_type: 'private').order(:created_at).last
    assert_not_nil new_plan, "New plan should be created"

    # CultivationPlanCropの重複チェック
    crop_names = new_plan.cultivation_plan_crops.map(&:name)
    duplicate_names = crop_names.select { |name| crop_names.count(name) > 1 }.uniq

    assert_empty duplicate_names, 
      "No duplicate crop names should exist. Found: #{duplicate_names.join(', ')}"

    # 同じcrop_idのCultivationPlanCropが1つだけであることを確認
    crop_ids = new_plan.cultivation_plan_crops.map(&:crop_id)
    duplicate_crop_ids = crop_ids.select { |crop_id| crop_ids.count(crop_id) > 1 }.uniq

    assert_empty duplicate_crop_ids, 
      "No duplicate crop_ids should exist. Found: #{duplicate_crop_ids.join(', ')}"

    # CultivationPlanCropが1つだけ作成されることを確認
    assert_equal 1, new_plan.cultivation_plan_crops.count, 
      "Only one CultivationPlanCrop should be created for the same crop"
  end

  test "should handle multiple different crops without duplication" do
    # 異なる作物を選択
    different_crops = [
      Crop.create!(
        user: nil,
        name: 'テスト作物1',
        variety: 'テスト品種1',
        is_reference: true,
        area_per_unit: 0.25,
        revenue_per_area: 5000.0,
        region: 'jp'
      ),
      Crop.create!(
        user: nil,
        name: 'テスト作物2',
        variety: 'テスト品種2',
        is_reference: true,
        area_per_unit: 0.30,
        revenue_per_area: 6000.0,
        region: 'jp'
      )
    ]
    
    # 参照計画を作成
    plan = CultivationPlan.create!(
      farm: @farm,
      user: nil,
      total_area: 300.0,
      plan_type: 'public',
      plan_year: Date.current.year,
      plan_name: '複数作物テスト計画',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: 'completed'
    )

    # 各作物のCultivationPlanCropを作成
    different_crops.each do |crop|
      CultivationPlanCrop.create!(
        cultivation_plan: plan,
        crop: crop,
        name: crop.name,
        variety: crop.variety,
        area_per_unit: crop.area_per_unit,
        revenue_per_area: crop.revenue_per_area
      )
    end

    # セッションデータを構築
    session_data = {
      plan_id: plan.id,
      farm_id: @farm.id,
      crop_ids: different_crops.map(&:id),
      field_data: [
        { name: '複数作物テスト圃場1', area: 100.0, coordinates: [35.0, 139.0] },
        { name: '複数作物テスト圃場2', area: 200.0, coordinates: [35.1, 139.1] }
      ]
    }

    # PlanSaveServiceを実行
    service = PlanSaveService.new(user: @user, session_data: session_data)
    result = service.call

    # 成功を確認
    assert result.success, "PlanSaveService should succeed: #{result.error_message}"

    # 作成された計画を取得
    new_plan = @user.cultivation_plans.where(plan_type: 'private').order(:created_at).last
    assert_not_nil new_plan, "New plan should be created"

    # 各作物に対して1つずつCultivationPlanCropが作成されることを確認
    assert_equal different_crops.count, new_plan.cultivation_plan_crops.count,
      "Should create one CultivationPlanCrop for each different crop"

    # 重複がないことを確認
    crop_ids = new_plan.cultivation_plan_crops.map(&:crop_id)
    duplicate_crop_ids = crop_ids.select { |crop_id| crop_ids.count(crop_id) > 1 }.uniq

    assert_empty duplicate_crop_ids,
      "No duplicate crop_ids should exist for different crops"
  end

  test "should preserve crop variety information when preventing duplication" do
    # 同じ作物で異なる品種を作成
    same_crop = @crops[0]
    
    # 参照計画を作成
    plan = CultivationPlan.create!(
      farm: @farm,
      user: nil,
      total_area: 300.0,
      plan_type: 'public',
      plan_year: Date.current.year,
      plan_name: '品種保持テスト計画',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: 'completed'
    )

    # 同じ作物で異なる品種のCultivationPlanCropを作成
    CultivationPlanCrop.create!(
      cultivation_plan: plan,
      crop: same_crop,
      name: same_crop.name,
      variety: '品種A',
      area_per_unit: same_crop.area_per_unit,
      revenue_per_area: same_crop.revenue_per_area
    )

    CultivationPlanCrop.create!(
      cultivation_plan: plan,
      crop: same_crop,
      name: same_crop.name,
      variety: '品種B',
      area_per_unit: same_crop.area_per_unit,
      revenue_per_area: same_crop.revenue_per_area
    )

    # セッションデータを構築
    session_data = {
      plan_id: plan.id,
      farm_id: @farm.id,
      crop_ids: [same_crop.id, same_crop.id],
      field_data: [
        { name: '品種保持テスト圃場1', area: 100.0, coordinates: [35.0, 139.0] }
      ]
    }
    
    # PlanSaveServiceを実行
    service = PlanSaveService.new(user: @user, session_data: session_data)
    result = service.call

    # 成功を確認
    assert result.success, "PlanSaveService should succeed: #{result.error_message}"

    # 作成された計画を取得
    new_plan = @user.cultivation_plans.where(plan_type: 'private').order(:created_at).last
    assert_not_nil new_plan, "New plan should be created"

    # CultivationPlanCropが1つだけ作成されることを確認
    assert_equal 1, new_plan.cultivation_plan_crops.count,
      "Only one CultivationPlanCrop should be created for the same crop"

    # 品種情報が保持されることを確認（最初に見つかった品種が使用される）
    created_crop = new_plan.cultivation_plan_crops.first
    # crop_idは新しく作成されたユーザー作物のIDになる
    assert_not_nil created_crop.crop_id,
      "Crop ID should be present"
    assert_not_nil created_crop.variety,
      "Variety information should be preserved"
  end
end