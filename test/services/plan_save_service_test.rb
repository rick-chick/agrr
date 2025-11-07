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

  test "should allow CultivationPlanCrop duplication when same crop appears multiple times" do
    # 参照計画を作成（同じ作物を複数含む - 名前重複は許容）
    plan = CultivationPlan.create!(
      farm: @farm,
      user: nil, # 参照計画
      total_area: 300.0,
      plan_type: 'public',
      plan_year: Date.current.year,
      plan_name: '重複許容テスト計画',
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
      field_data: [
        { name: '重複許容テスト圃場1', area: 100.0, coordinates: [35.0, 139.0] },
        { name: '重複許容テスト圃場2', area: 200.0, coordinates: [35.1, 139.1] }
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

    # 仕様に従い、名前重複は許容される（重複チェックを削除）
    # CultivationPlanCropが2つ作成されることを確認（重複許容）
    assert_equal 2, new_plan.cultivation_plan_crops.count, 
      "Two CultivationPlanCrops should be created (duplicates allowed)"
  end

  test "reuses existing user farm when same reference farm is copied twice" do
    plan = CultivationPlan.create!(
      farm: @farm,
      user: nil,
      total_area: 300.0,
      plan_type: 'public',
      plan_year: Date.current.year,
      plan_name: 'Farm再利用テスト計画',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: 'completed'
    )

    # 参照計画に少なくとも1つの作物を含める
    CultivationPlanCrop.create!(
      cultivation_plan: plan,
      crop: @crops[0],
      name: @crops[0].name,
      variety: @crops[0].variety,
      area_per_unit: @crops[0].area_per_unit,
      revenue_per_area: @crops[0].revenue_per_area
    )

    session_data = {
      plan_id: plan.id,
      farm_id: @farm.id,
      field_data: [
        { name: '再利用圃場1', area: 120.0 },
        { name: '再利用圃場2', area: 180.0 }
      ]
    }

    before_crops_count = @user.crops.count
    first_result = PlanSaveService.new(user: @user, session_data: session_data).call
    assert first_result.success, "Initial copy should succeed: #{first_result.error_message}"
    assert_not first_result.skipped?, 'First copy should not report skips'

    original_farm = @user.farms.where(source_farm_id: @farm.id).first
    assert_not_nil original_farm, 'User farm copied from reference should exist'

    original_fields = original_farm.fields.order(:id).to_a
    assert_equal 2, original_fields.size, 'Two fields should be created on first copy'

    farm_count = @user.farms.count

    before_second_crops_count = @user.crops.count
    second_result = PlanSaveService.new(user: @user, session_data: session_data).call
    assert second_result.success, "Second copy should also succeed: #{second_result.error_message}"
    assert second_result.skipped?, 'Second copy should report skips when reusing farm'
    assert_includes second_result.skipped_items[:farm], original_farm.id
    assert_equal original_fields.map(&:id).sort, second_result.skipped_items[:fields].sort

    assert_equal farm_count, @user.farms.count, 'Farm count should not increase on second copy'
    assert_equal original_farm.id, @user.farms.where(source_farm_id: @farm.id).pluck(:id).uniq.first,
                 'Existing farm should be reused on second copy'

    reused_fields = original_farm.fields.order(:id).to_a
    assert_equal original_fields.map(&:id), reused_fields.map(&:id), 'Existing fields should be reused'

    # 作物も再利用される（source_crop_id対応後）
    assert_equal before_second_crops_count, @user.crops.count, 'Crop count should not increase on second copy when reusing'
    original_crop = @user.crops.where(source_crop_id: @crops[0].id).first
    assert_not_nil original_crop, 'User crop copied from reference should exist'
    assert_includes second_result.skipped_items[:crops], original_crop.id, 'Crop should be reported as skipped'
  end

  test "reuses existing user crop when same reference crop is copied twice" do
    plan = CultivationPlan.create!(
      farm: @farm,
      user: nil,
      total_area: 300.0,
      plan_type: 'public',
      plan_year: Date.current.year,
      plan_name: 'Crop再利用テスト計画',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: 'completed'
    )

    # 参照計画に作物を含める
    CultivationPlanCrop.create!(
      cultivation_plan: plan,
      crop: @crops[0],
      name: @crops[0].name,
      variety: @crops[0].variety,
      area_per_unit: @crops[0].area_per_unit,
      revenue_per_area: @crops[0].revenue_per_area
    )

    session_data = {
      plan_id: plan.id,
      farm_id: @farm.id,
      field_data: []
    }

    first_result = PlanSaveService.new(user: @user, session_data: session_data).call
    assert first_result.success, "Initial copy should succeed: #{first_result.error_message}"

    original_crop = @user.crops.where(source_crop_id: @crops[0].id).first
    assert_not_nil original_crop, 'User crop copied from reference should exist'

    crop_count = @user.crops.count

    second_result = PlanSaveService.new(user: @user, session_data: session_data).call
    assert second_result.success, "Second copy should also succeed: #{second_result.error_message}"
    assert second_result.skipped?, 'Second copy should report skips when reusing crop'
    assert_includes second_result.skipped_items[:crops], original_crop.id

    assert_equal crop_count, @user.crops.count, 'Crop count should not increase on second copy'
    assert_equal original_crop.id, @user.crops.where(source_crop_id: @crops[0].id).pluck(:id).uniq.first,
                 'Existing crop should be reused on second copy'
  end

  test "reuses existing interaction rule when same crop combination is copied twice" do
    # 参照連作ルールを用意
    reference_rule = InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'GroupA',
      target_group: 'GroupB',
      impact_ratio: 0.8,
      is_directional: false,
      is_reference: true,
      region: 'jp'
    )

    # 参照作物にグループを設定
    @crops[0].update!(groups: ['GroupA'])
    @crops[1].update!(groups: ['GroupB'])

    plan = CultivationPlan.create!(
      farm: @farm,
      user: nil,
      total_area: 300.0,
      plan_type: 'public',
      plan_year: Date.current.year,
      plan_name: 'Interaction再利用テスト計画',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: 'completed'
    )

    [@crops[0], @crops[1]].each do |crop|
      CultivationPlanCrop.create!(
        cultivation_plan: plan,
        crop: crop,
        name: crop.name,
        variety: crop.variety,
        area_per_unit: crop.area_per_unit,
        revenue_per_area: crop.revenue_per_area
      )
    end

    session_data = {
      plan_id: plan.id,
      farm_id: @farm.id,
      field_data: []
    }

    first_result = PlanSaveService.new(user: @user, session_data: session_data).call
    assert first_result.success, "Initial copy should succeed: #{first_result.error_message}"

    original_rule = @user.interaction_rules.where(rule_type: 'continuous_cultivation', source_group: 'GroupA', target_group: 'GroupB').first
    assert_not_nil original_rule, 'User interaction rule should be created from reference'

    rule_count = @user.interaction_rules.count

    second_result = PlanSaveService.new(user: @user, session_data: session_data).call
    assert second_result.success, "Second copy should also succeed: #{second_result.error_message}"
    assert second_result.skipped?, 'Second copy should report skips when reusing interaction rule'
    assert_includes second_result.skipped_items[:interaction_rules], original_rule.id

    assert_equal rule_count, @user.interaction_rules.count, 'Interaction rule count should not increase on second copy'
  end

  test "copies all reference interaction rules for user region" do
    InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'RefGroupA',
      target_group: 'RefGroupB',
      impact_ratio: 0.75,
      is_directional: true,
      is_reference: true,
      region: @farm.region
    )

    InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'RefGroupC',
      target_group: 'RefGroupD',
      impact_ratio: 1.1,
      is_directional: false,
      is_reference: true,
      region: @farm.region
    )

    InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'OtherRegionA',
      target_group: 'OtherRegionB',
      impact_ratio: 0.5,
      is_directional: true,
      is_reference: true,
      region: 'us'
    )

    plan = CultivationPlan.create!(
      farm: @farm,
      user: nil,
      total_area: 100.0,
      plan_type: 'public',
      plan_year: Date.current.year,
      plan_name: 'InteractionRulesCopyAll',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: 'completed'
    )

    CultivationPlanCrop.create!(
      cultivation_plan: plan,
      crop: @crops[0],
      name: @crops[0].name,
      variety: @crops[0].variety,
      area_per_unit: @crops[0].area_per_unit,
      revenue_per_area: @crops[0].revenue_per_area
    )

    session_data = {
      plan_id: plan.id,
      farm_id: @farm.id,
      field_data: []
    }

    result = PlanSaveService.new(user: @user, session_data: session_data).call
    assert result.success, result.error_message

    user_rules = @user.interaction_rules.where(is_reference: false)
    assert_equal 2, user_rules.count, 'All reference rules for region should be copied'

    copied_pairs = user_rules.map { |rule| [rule.source_group, rule.target_group] }.sort
    expected_pairs = [['RefGroupA', 'RefGroupB'], ['RefGroupC', 'RefGroupD']].sort
    assert_equal expected_pairs, copied_pairs

    user_rules.each do |rule|
      assert_not_nil rule.source_interaction_rule_id, 'Copied rule should keep source reference'
    end
  end

  test "copies all reference crops for user region regardless of plan selection" do
    reference_crop_a = Crop.create!(
      user: nil,
      name: '地域参照作物A',
      variety: 'A1',
      is_reference: true,
      area_per_unit: 0.2,
      revenue_per_area: 4000.0,
      region: @farm.region
    )

    reference_crop_b = Crop.create!(
      user: nil,
      name: '地域参照作物B',
      variety: 'B1',
      is_reference: true,
      area_per_unit: 0.25,
      revenue_per_area: 4500.0,
      region: @farm.region
    )

    Crop.create!(
      user: nil,
      name: '他地域参照作物',
      variety: 'X1',
      is_reference: true,
      area_per_unit: 0.3,
      revenue_per_area: 4700.0,
      region: 'us'
    )

    plan = CultivationPlan.create!(
      farm: @farm,
      user: nil,
      total_area: 50.0,
      plan_type: 'public',
      plan_year: Date.current.year,
      plan_name: '地域参照作物コピー',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: 'completed'
    )

    CultivationPlanCrop.create!(
      cultivation_plan: plan,
      crop: reference_crop_a,
      name: reference_crop_a.name,
      variety: reference_crop_a.variety,
      area_per_unit: reference_crop_a.area_per_unit,
      revenue_per_area: reference_crop_a.revenue_per_area
    )

    session_data = {
      plan_id: plan.id,
      farm_id: @farm.id,
      field_data: []
    }

    result = PlanSaveService.new(user: @user, session_data: session_data).call
    assert result.success, result.error_message

    user_crops = @user.crops.where(is_reference: false)
    copied_names = user_crops.map(&:name)

    assert_includes copied_names, reference_crop_a.name
    assert_includes copied_names, reference_crop_b.name
    refute_includes copied_names, '他地域参照作物'

    user_crops.each do |crop|
      next unless [reference_crop_a.name, reference_crop_b.name].include?(crop.name)
      assert_not_nil crop.source_crop_id, 'Copied crop should keep source reference'
    end
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

  test "should preserve crop variety information when allowing duplication" do
    # 同じ作物で異なる品種を作成（名前重複は許容）
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

    # CultivationPlanCropが2つ作成されることを確認（重複許容）
    assert_equal 2, new_plan.cultivation_plan_crops.count,
      "Two CultivationPlanCrops should be created for the same crop (duplicates allowed)"

    # 品種情報が保持されることを確認
    created_crops = new_plan.cultivation_plan_crops.order(:created_at)
    assert_equal '品種A', created_crops[0].variety, "First variety should be preserved"
    assert_equal '品種B', created_crops[1].variety, "Second variety should be preserved"
  end

  test "maps crops by registration order and links field cultivations correctly" do
    # 参照作物A/B
    crop_a = Crop.create!(user: nil, name: '参照作物A', variety: 'A1', is_reference: true, area_per_unit: 0.2, revenue_per_area: 4000.0, region: 'jp')
    crop_b = Crop.create!(user: nil, name: '参照作物B', variety: 'B1', is_reference: true, area_per_unit: 0.3, revenue_per_area: 6000.0, region: 'jp')

    # 参照計画
    plan = CultivationPlan.create!(
      farm: @farm,
      user: nil,
      total_area: 300.0,
      plan_type: 'public',
      plan_year: Date.current.year,
      plan_name: '順序マッピング検証',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: 'completed'
    )

    # 参照CPC（登録順: A -> B）
    cpc_a = CultivationPlanCrop.create!(cultivation_plan: plan, crop: crop_a, name: crop_a.name, variety: crop_a.variety, area_per_unit: crop_a.area_per_unit, revenue_per_area: crop_a.revenue_per_area)
    cpc_b = CultivationPlanCrop.create!(cultivation_plan: plan, crop: crop_b, name: crop_b.name, variety: crop_b.variety, area_per_unit: crop_b.area_per_unit, revenue_per_area: crop_b.revenue_per_area)

    # 参照フィールド
    field1 = CultivationPlanField.create!(cultivation_plan: plan, name: 'F1', area: 150, daily_fixed_cost: 10)
    field2 = CultivationPlanField.create!(cultivation_plan: plan, name: 'F2', area: 150, daily_fixed_cost: 10)

    # 参照FieldCultivation（A: 面積10, B: 面積20）
    FieldCultivation.create!(
      cultivation_plan: plan,
      cultivation_plan_field: field1,
      cultivation_plan_crop: cpc_a,
      area: 10,
      start_date: Date.current,
      completion_date: Date.current + 10,
      cultivation_days: 11,
      estimated_cost: 1000,
      status: 'completed'
    )
    FieldCultivation.create!(
      cultivation_plan: plan,
      cultivation_plan_field: field2,
      cultivation_plan_crop: cpc_b,
      area: 20,
      start_date: Date.current + 1,
      completion_date: Date.current + 12,
      cultivation_days: 12,
      estimated_cost: 2000,
      status: 'completed'
    )

    # セッションデータ（plan_idのみ）
    session_data = {
      plan_id: plan.id,
      farm_id: @farm.id,
      field_data: [
        { name: 'F1', area: 150.0, coordinates: [35.0, 139.0] },
        { name: 'F2', area: 150.0, coordinates: [35.1, 139.1] }
      ]
    }

    # 実行
    result = PlanSaveService.new(user: @user, session_data: session_data).call
    assert result.success, result.error_message

    new_plan = @user.cultivation_plans.where(plan_type: 'private').order(:created_at).last
    assert_not_nil new_plan

    # 新規CPCの作成順が参照CPCの順（A->B）に対応していること
    new_cpcs = new_plan.cultivation_plan_crops.order(:id)
    assert_equal ['参照作物A', '参照作物B'], new_cpcs.map(&:name)
    # 各CPCがユーザー作物を参照していること
    assert new_cpcs.all? { |cpc| cpc.crop.user_id == @user.id }

    # FieldCultivationが対応する新規CPCに紐付くこと（作物名で検証）
    fc_a = new_plan.field_cultivations.find { |fc| fc.cultivation_plan_crop.name == '参照作物A' }
    fc_b = new_plan.field_cultivations.find { |fc| fc.cultivation_plan_crop.name == '参照作物B' }
    assert_not_nil fc_a
    assert_not_nil fc_b
  end

  test "copies interaction rule impact_ratio from reference when available" do
    # 参照作物A/B（同じregion）
    crop_a = Crop.create!(user: nil, name: '参照A', variety: 'A1', is_reference: true, area_per_unit: 0.2, revenue_per_area: 4000.0, region: 'jp')
    crop_b = Crop.create!(user: nil, name: '参照B', variety: 'B1', is_reference: true, area_per_unit: 0.3, revenue_per_area: 6000.0, region: 'jp')

    # 参照連作ルール（グループは名前を使用）impact_ratio=0.7 を登録
    InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: crop_a.name,
      target_group: crop_b.name,
      impact_ratio: 0.7,
      is_directional: true,
      is_reference: true,
      user: nil,
      region: 'jp'
    )

    # 参照計画
    plan = CultivationPlan.create!(
      farm: @farm,
      user: nil,
      total_area: 100.0,
      plan_type: 'public',
      plan_year: Date.current.year,
      plan_name: '連作係数コピー検証',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: 'completed'
    )

    # 参照CPC
    CultivationPlanCrop.create!(cultivation_plan: plan, crop: crop_a, name: crop_a.name, variety: crop_a.variety, area_per_unit: crop_a.area_per_unit, revenue_per_area: crop_a.revenue_per_area)
    CultivationPlanCrop.create!(cultivation_plan: plan, crop: crop_b, name: crop_b.name, variety: crop_b.variety, area_per_unit: crop_b.area_per_unit, revenue_per_area: crop_b.revenue_per_area)

    # セッションデータ
    session_data = {
      plan_id: plan.id,
      farm_id: @farm.id,
      field_data: [
        { name: 'F1', area: 100.0, coordinates: [35.0, 139.0] }
      ]
    }

    # 実行
    result = PlanSaveService.new(user: @user, session_data: session_data).call
    assert result.success, result.error_message

    # 作成されたユーザーの連作ルールを取得
    user_rules = @user.interaction_rules.where(rule_type: 'continuous_cultivation')
    assert user_rules.exists?, 'User interaction rules should be created'

    # A->B のルールが impact_ratio=0.7 で作成されていること
    rule = user_rules.find_by(source_group: crop_a.name, target_group: crop_b.name)
    assert_not_nil rule, 'Interaction rule A->B should exist'
    assert_in_delta 0.7, rule.impact_ratio.to_f, 0.0001, 'impact_ratio should be copied from reference rule'
  end

  test "should prevent farm creation when user has reached farm limit" do
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
      farm_id: @farm.id,
      crop_ids: [@crops[0].id],
      field_data: [{ name: 'テスト圃場', area: 100.0, coordinates: [35.0, 139.0] }]
    }
    
    # 計画を作成
    plan = CultivationPlan.create!(
      farm: @farm,
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

  test "should prevent duplicate interaction rules for same crop combination" do
    # 異なる作物を選択
    crop_a = Crop.create!(
      user: nil,
      name: 'テスト作物A',
      variety: '品種A',
      is_reference: true,
      area_per_unit: 0.25,
      revenue_per_area: 5000.0,
      region: 'jp'
    )
    crop_b = Crop.create!(
      user: nil,
      name: 'テスト作物B',
      variety: '品種B',
      is_reference: true,
      area_per_unit: 0.30,
      revenue_per_area: 6000.0,
      region: 'jp'
    )
    
    # 参照連作ルールを作成（参照ルールがない場合はルールが作成されないため）
    InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: crop_a.name,
      target_group: crop_b.name,
      impact_ratio: 0.8,
      is_directional: true,
      is_reference: true,
      user: nil,
      region: 'jp'
    )
    
    # 参照計画を作成
    plan = CultivationPlan.create!(
      farm: @farm,
      user: nil,
      total_area: 300.0,
      plan_type: 'public',
      plan_year: Date.current.year,
      plan_name: '連作重複防止テスト計画',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: 'completed'
    )

    # 各作物のCultivationPlanCropを作成
    CultivationPlanCrop.create!(
      cultivation_plan: plan,
      crop: crop_a,
      name: crop_a.name,
      variety: crop_a.variety,
      area_per_unit: crop_a.area_per_unit,
      revenue_per_area: crop_a.revenue_per_area
    )
    CultivationPlanCrop.create!(
      cultivation_plan: plan,
      crop: crop_b,
      name: crop_b.name,
      variety: crop_b.variety,
      area_per_unit: crop_b.area_per_unit,
      revenue_per_area: crop_b.revenue_per_area
    )

    # セッションデータを構築
    session_data = {
      plan_id: plan.id,
      farm_id: @farm.id,
      field_data: [
        { name: '連作重複防止テスト圃場1', area: 100.0, coordinates: [35.0, 139.0] },
        { name: '連作重複防止テスト圃場2', area: 200.0, coordinates: [35.1, 139.1] }
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

    # 連作ルールが1つだけ作成されることを確認（重複防止）
    user_interaction_rules = @user.interaction_rules.where(rule_type: 'continuous_cultivation')
    assert_equal 1, user_interaction_rules.count, "Only one interaction rule should be created for two crops"

    # ルールの内容を確認
    rule = user_interaction_rules.first
    assert_includes [crop_a.name, crop_b.name], rule.source_group, "Source group should be one of the crops"
    assert_includes [crop_a.name, crop_b.name], rule.target_group, "Target group should be one of the crops"
    assert_not_equal rule.source_group, rule.target_group, "Source and target groups should be different"
  end
end