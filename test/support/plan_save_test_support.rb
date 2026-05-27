# frozen_string_literal: true

# PlanSave / PlanCopy 系テストの共通セットアップ（mapper・gateway・integration 共有）。
module PlanSaveTestSupport
  def unique_test_user
    User.create!(
      email: "plan_save_test_#{SecureRandom.hex(8)}@example.com",
      name: "PlanSave Test #{SecureRandom.hex(4)}",
      google_id: "plan_save_google_#{SecureRandom.hex(8)}",
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
      name: "PlanSave Ref Farm #{SecureRandom.hex(4)}",
      latitude: 35.0,
      longitude: 139.0,
      is_reference: true,
      region: region
    )
  end

  def build_public_reference_plan(farm:, ref_crop:, plan_name: "PlanSave plan")
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
    )
  end

  # PlanCopy gateway 等: session_data の参照農場からユーザー農場を AR で用意
  def stub_user_farm_for_plan_save_test(ctx, reuse_existing: false)
    raw_farm_id = ctx.session_data[:farm_id] || ctx.session_data["farm_id"]
    reference_farm = Farm.find(raw_farm_id)
    existing = ctx.user.farms.find_by(source_farm_id: reference_farm.id)

    if existing
      if reuse_existing
        ctx.farm_reused = true
        ctx.result.add_skip(:farm, existing.id)
      end
      return existing
    end

    ctx.user.farms.create!(
      name: "#{reference_farm.name} (plan save test #{SecureRandom.hex(3)})",
      latitude: reference_farm.latitude,
      longitude: reference_farm.longitude,
      region: reference_farm.region,
      is_reference: false,
      weather_location_id: reference_farm.weather_location_id,
      source_farm_id: reference_farm.id
    )
  end

  # 圃場・作付・CPC を持つ参照公開計画（PlanCopy gateway / integration 用）
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

  # ctx に作物 ID マップを載せる（PlanSaveEnsureUserCropsInteractor を経由しない PlanCopy 系セットアップ）
  def stub_plan_save_crop_context(ctx, ref_crop:, cpc_id: nil)
    plan_id = ctx.session_data[:plan_id] || ctx.session_data["plan_id"]
    resolved_cpc_id = cpc_id || CultivationPlanCrop.find_by(cultivation_plan_id: plan_id, crop_id: ref_crop.id)&.id

    user_crop = ctx.user.crops.find_by(source_crop_id: ref_crop.id)
    if user_crop
      ctx.result.add_skip(:crops, user_crop.id)
    else
      user_crop = ctx.user.crops.create!(
        name: ref_crop.name,
        variety: ref_crop.variety,
        area_per_unit: ref_crop.area_per_unit,
        revenue_per_area: ref_crop.revenue_per_area,
        groups: ref_crop.groups,
        is_reference: false,
        region: ref_crop.region,
        source_crop_id: ref_crop.id
      )
    end

    ctx.reference_crop_id_to_user_crop_id = { ref_crop.id => user_crop.id }
    ctx.ref_cpc_id_to_user_crop_id = resolved_cpc_id ? { resolved_cpc_id => user_crop.id } : {}
    user_crop
  end

  def stub_plan_save_user_crops_for_plan_save_test(ctx, ref_crop:, cpc_id: nil)
    [ stub_plan_save_crop_context(ctx, ref_crop: ref_crop, cpc_id: cpc_id) ]
  end

  def ensure_agricultural_tasks_for_plan_save_test(ctx:, user:, region:, user_ag_gateway:)
    translator = Object.new
    translator.define_singleton_method(:t) { |key, **_opts| key.to_s }

    output = Domain::CultivationPlan::Interactors::PlanSaveEnsureUserAgriculturalTasksInteractor.new(
      read_gateway: Adapters::CultivationPlan::Gateways::PublicPlanSaveReadActiveRecordGateway.new,
      user_agricultural_task_gateway: user_ag_gateway,
      logger: CapturingLogger.new,
      translator: translator
    ).call(
      Domain::CultivationPlan::Dtos::PlanSaveEnsureUserAgriculturalTasksInput.new(
        user_id: user.id,
        region: region,
        reference_crop_id_to_user_crop_id: ctx.reference_crop_id_to_user_crop_id
      )
    )

    ctx.reference_agricultural_task_id_to_user_task_id =
      output.reference_agricultural_task_id_to_user_task_id
    output
  end

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
