# frozen_string_literal: true

# PlanSaveContext + CultivationPlan mappers 単体テスト用の共通セットアップ
module PlanSaveMapperTestSupport
  def unique_test_user
    User.create!(
      email: "mapper_test_#{SecureRandom.hex(8)}@example.com",
      name: "Mapper Test #{SecureRandom.hex(4)}",
      google_id: "mapper_google_#{SecureRandom.hex(8)}",
      is_anonymous: false
    )
  end

  def plan_save_result
    Adapters::CultivationPlan::Sessions::PlanSaveSession::Result.new
  end

  def ensure_reference_farm(region: "jp")
    existing = Farm.reference.where(region: region).first
    return existing if existing

    Farm.create!(
      user: User.anonymous_user,
      name: "Mapper Ref Farm #{SecureRandom.hex(4)}",
      latitude: 35.0,
      longitude: 139.0,
      is_reference: true,
      region: region
    )
  end

  def build_public_reference_plan(farm:, ref_crop:, plan_name: "Mapper plan")
    CultivationPlan.create!(
      farm: farm,
      user: nil,
      total_area: 10.0,
      plan_type: "public",
      plan_year: Date.current.year,
      plan_name: plan_name,
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: "completed"
    ).tap do |plan|
      CultivationPlanCrop.create!(
        cultivation_plan: plan,
        crop: ref_crop,
        name: ref_crop.name,
        variety: ref_crop.variety,
        area_per_unit: ref_crop.area_per_unit,
        revenue_per_area: ref_crop.revenue_per_area
      )
    end
  end

  def build_reference_crop(name:, region: "jp")
    Crop.create!(
      user: nil,
      name: name,
      variety: "v",
      is_reference: true,
      area_per_unit: 0.2,
      revenue_per_area: 1000.0,
      region: region
    )
  end

  def build_plan_save_context(user:, session_data:, result:)
    Adapters::CultivationPlan::Sessions::PlanSaveContext.new(
      user: user,
      session_data: session_data,
      result: result
    ).tap { |ctx| ctx.crop_stage_copy_interactor = CompositionRoot.crop_stage_copy_interactor }
  end

  # 圃場・作付・CPC を持つ参照公開計画（PlanCopyActiveRecordGateway 用）
  def build_public_plan_with_field_cultivation(farm:, ref_crop:, plan_name: "Gateway plan")
    plan = CultivationPlan.create!(
      farm: farm,
      user: nil,
      total_area: 10.0,
      plan_type: "public",
      plan_year: Date.current.year,
      plan_name: plan_name,
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: "completed"
    )
    cpf = CultivationPlanField.create!(
      cultivation_plan: plan,
      name: "Fld#{SecureRandom.hex(3)}",
      area: 10.0,
      daily_fixed_cost: 0
    )
    cpc = CultivationPlanCrop.create!(
      cultivation_plan: plan,
      crop: ref_crop,
      name: ref_crop.name,
      variety: ref_crop.variety,
      area_per_unit: ref_crop.area_per_unit,
      revenue_per_area: ref_crop.revenue_per_area
    )
    fc = FieldCultivation.create!(
      cultivation_plan: plan,
      cultivation_plan_field: cpf,
      cultivation_plan_crop: cpc,
      area: 10.0,
      status: :pending
    )
    [ plan, cpf, cpc, fc ]
  end

  # 指定カテゴリごとのスキップ id が一致し、それ以外のカテゴリは空であることを表明する
  # 例: assert_skipped_exact(result2, { farm: [1], fields: [2] })
  def assert_skipped_exact(result, expected_slices)
    actual = result.skipped_items
    expected_slices.each do |cat, ids|
      assert_equal Array(ids).sort, Array(actual[cat]).sort,
                   "expected skipped_items[#{cat.inspect}] to match"
    end
    actual.each do |key, values|
      next if expected_slices.key?(key)

      assert_empty Array(values), "unexpected skipped in #{key}: #{values.inspect}"
    end
  end
end
