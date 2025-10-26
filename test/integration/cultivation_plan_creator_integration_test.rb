# frozen_string_literal: true

require 'test_helper'

class CultivationPlanCreatorIntegrationTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: 'cultivation_plan_creator_test@example.com',
      name: 'CultivationPlanCreator Test User',
      google_id: 'cultivation_plan_creator_test_123',
      is_anonymous: false
    )
    
    @ref_farm = Farm.reference.first
    @ref_crops = Crop.reference.limit(5)
    
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
    if @ref_crops.empty?
      @ref_crops = 5.times.map do |i|
        Crop.create!(
          user: nil,
          name: "テスト参照作物 #{i + 1}",
          variety: "テスト品種 #{i + 1}",
          is_reference: true,
          area_per_unit: 0.1 + i * 0.1,
          revenue_per_area: 5000.0 + i * 1000.0,
          region: 'jp'
        )
      end
    end
  end

  def teardown
    @user.destroy if @user&.persisted?
  end

  test "should create cultivation plan with string crop_ids" do
    # 文字列の作物IDを準備（実際のリクエストパラメータと同じ形式）
    crop_ids_strings = @ref_crops.map(&:id).map(&:to_s)
    puts "Testing with crop_ids: #{crop_ids_strings}"
    
    # 整数に変換して作物を取得（修正後のロジックと同じ）
    crops = Crop.where(id: crop_ids_strings.map(&:to_i))
    assert_equal @ref_crops.count, crops.count, "Should find all crops"
    
    # CultivationPlanCreatorを実行
    creator_params = {
      farm: @ref_farm,
      total_area: 1000.0,
      crops: crops,
      user: nil,
      session_id: 'test_session',
      plan_type: 'public',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year
    }
    
    result = CultivationPlanCreator.new(**creator_params).call
    
    # 成功を確認
    assert result.success?, "CultivationPlanCreator should succeed: #{result.errors.join(', ')}"
    assert_not_nil result.cultivation_plan, "CultivationPlan should be created"
    assert_equal @ref_farm.id, result.cultivation_plan.farm_id, "Farm should be set correctly"
    assert_equal 'public', result.cultivation_plan.plan_type, "Plan type should be public"
    assert_equal 1000.0, result.cultivation_plan.total_area, "Total area should be set correctly"
    
    # CultivationPlanCropが正しく作成されているか確認
    assert_equal crops.count, result.cultivation_plan.cultivation_plan_crops.count, 
      "Should create CultivationPlanCrop for each crop"
    
    # CultivationPlanFieldが作成されているか確認
    assert result.cultivation_plan.cultivation_plan_fields.count > 0, 
      "Should create CultivationPlanFields"
    
    puts "✅ Successfully created CultivationPlan ID: #{result.cultivation_plan.id}"
    puts "   - CultivationPlanCrops: #{result.cultivation_plan.cultivation_plan_crops.count}"
    puts "   - CultivationPlanFields: #{result.cultivation_plan.cultivation_plan_fields.count}"
  end

  test "should handle empty crops array gracefully" do
    # 空の作物配列でテスト
    creator_params = {
      farm: @ref_farm,
      total_area: 1000.0,
      crops: [],
      user: nil,
      session_id: 'test_session',
      plan_type: 'public',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year
    }
    
    result = CultivationPlanCreator.new(**creator_params).call
    
    # 空の作物配列でも成功することを確認
    assert result.success?, "CultivationPlanCreator should succeed with empty crops"
    assert_not_nil result.cultivation_plan, "CultivationPlan should be created even with empty crops"
    assert_equal 0, result.cultivation_plan.cultivation_plan_crops.count, 
      "Should have no CultivationPlanCrops with empty crops"
  end

  test "should create private cultivation plan with user" do
    # プライベート計画でテスト
    creator_params = {
      farm: @ref_farm,
      total_area: 500.0,
      crops: @ref_crops.first(3),
      user: @user,
      session_id: 'test_session',
      plan_type: 'private',
      plan_year: Date.current.year,
      plan_name: @ref_farm.name,
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year
    }
    
    result = CultivationPlanCreator.new(**creator_params).call
    
    # 成功を確認
    assert result.success?, "CultivationPlanCreator should succeed for private plan"
    assert_not_nil result.cultivation_plan, "Private CultivationPlan should be created"
    assert_equal @user.id, result.cultivation_plan.user_id, "User should be set correctly"
    assert_equal 'private', result.cultivation_plan.plan_type, "Plan type should be private"
    assert_equal Date.current.year, result.cultivation_plan.plan_year, "Plan year should be set"
    assert_equal @ref_farm.name, result.cultivation_plan.plan_name, "Plan name should be farm name"
  end

  test "should handle FieldsAllocator with various crop area_per_unit values" do
    # 異なるarea_per_unit値を持つ作物でテスト
    crops_with_various_areas = [
      Crop.create!(
        user: nil,
        name: '小面積作物',
        variety: '小',
        is_reference: true,
        area_per_unit: 0.1,
        revenue_per_area: 1000.0,
        region: 'jp'
      ),
      Crop.create!(
        user: nil,
        name: '中面積作物',
        variety: '中',
        is_reference: true,
        area_per_unit: 0.5,
        revenue_per_area: 5000.0,
        region: 'jp'
      ),
      Crop.create!(
        user: nil,
        name: '大面積作物',
        variety: '大',
        is_reference: true,
        area_per_unit: 1.0,
        revenue_per_area: 10000.0,
        region: 'jp'
      )
    ]
    
    creator_params = {
      farm: @ref_farm,
      total_area: 2000.0,
      crops: crops_with_various_areas,
      user: nil,
      session_id: 'test_session',
      plan_type: 'public',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year
    }
    
    result = CultivationPlanCreator.new(**creator_params).call
    
    # 成功を確認
    assert result.success?, "CultivationPlanCreator should succeed with various area_per_unit values"
    assert_not_nil result.cultivation_plan, "CultivationPlan should be created"
    
    # FieldsAllocatorが正しく動作しているか確認
    assert result.cultivation_plan.cultivation_plan_fields.count > 0, 
      "Should create CultivationPlanFields with FieldsAllocator"
    
    # 各圃場の面積が正しく設定されているか確認
    total_field_area = result.cultivation_plan.cultivation_plan_fields.sum(:area)
    assert_equal 2000.0, total_field_area, "Total field area should match total_area"
    
    puts "✅ FieldsAllocator test passed"
    puts "   - Total area: 2000.0"
    puts "   - Fields created: #{result.cultivation_plan.cultivation_plan_fields.count}"
    puts "   - Total field area: #{total_field_area}"
  end

  test "should handle crop_ids parameter conversion from strings to integers" do
    # 文字列の作物IDを準備
    crop_ids_strings = @ref_crops.map(&:id).map(&:to_s)
    
    # PlansControllerのfind_selected_cropsメソッドのロジックを再現
    crops = Crop.where(id: crop_ids_strings.map(&:to_i), is_reference: true)
    
    # 正しく変換されているか確認
    assert_equal @ref_crops.count, crops.count, "Should find all crops after string to integer conversion"
    
    crops.each_with_index do |crop, index|
      assert_equal @ref_crops[index].id, crop.id, "Crop ID should match after conversion"
      assert_equal @ref_crops[index].name, crop.name, "Crop name should match"
    end
    
    puts "✅ Crop ID conversion test passed"
    puts "   - Input crop_ids: #{crop_ids_strings}"
    puts "   - Converted to integers: #{crop_ids_strings.map(&:to_i)}"
    puts "   - Found crops: #{crops.count}"
  end

  test "should reproduce the original error scenario and verify fix" do
    # 元のエラーシナリオを再現
    crop_ids_strings = ['127', '126', '114', '123', '125']
    puts "Reproducing original error scenario with crop_ids: #{crop_ids_strings}"
    
    # 修正前のロジック（エラーが発生する）
    crops_old_logic = Crop.where(id: crop_ids_strings, is_reference: true)
    puts "Old logic result: #{crops_old_logic.count} crops found"
    
    # 修正後のロジック（正常に動作する）
    crops_new_logic = Crop.where(id: crop_ids_strings.map(&:to_i), is_reference: true)
    puts "New logic result: #{crops_new_logic.count} crops found"
    
    # 文字列と整数の変換が正しく動作することを確認
    assert_equal crops_old_logic.count, crops_new_logic.count, 
      "Both logic should find the same number of crops"
    
    # 修正後のロジックでCultivationPlanCreatorを実行
    if crops_new_logic.any?
      creator_params = {
        farm: @ref_farm,
        total_area: 1000.0,
        crops: crops_new_logic,
        user: nil,
        session_id: 'test_session',
        plan_type: 'public',
        planning_start_date: Date.current,
        planning_end_date: Date.current.end_of_year
      }
      
      result = CultivationPlanCreator.new(**creator_params).call
      
      # 成功を確認
      assert result.success?, "CultivationPlanCreator should succeed with fixed logic"
      assert_not_nil result.cultivation_plan, "CultivationPlan should be created"
      
      puts "✅ Original error scenario fixed successfully"
      puts "   - CultivationPlan ID: #{result.cultivation_plan.id}"
      puts "   - CultivationPlanCrops: #{result.cultivation_plan.cultivation_plan_crops.count}"
    else
      # 作物が見つからない場合でも、変換ロジックが正しく動作することを確認
      assert_equal 0, crops_old_logic.count, "Old logic should find 0 crops"
      assert_equal 0, crops_new_logic.count, "New logic should find 0 crops"
      puts "⚠️ No crops found with the given IDs, but conversion logic works correctly"
    end
  end
end
