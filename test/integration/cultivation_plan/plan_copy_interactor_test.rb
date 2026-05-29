# frozen_string_literal: true

require "test_helper"

class CultivationPlan::PlanCopyInteractorIntegrationTest < ActiveSupport::TestCase
  include PlanSaveTestSupport

  test "copy_private_plan_for_year creates private plan with relations" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "YrCp#{SecureRandom.hex(4)}")
    source_plan, _cpf, _cpc, _fc = build_public_plan_with_field_cultivation(
      farm: ref_farm,
      ref_crop: ref_crop,
      plan_name: "YrPlan#{SecureRandom.hex(4)}"
    )

    new_year = Date.current.year + 1
    log = CapturingLogger.new
    interactor = Domain::CultivationPlan::Interactors::PlanCopyInteractor.new(
      plan_copy_gateway: CompositionRoot.plan_copy_gateway,
      logger: log
    )
    new_entity = interactor.call(
      Domain::CultivationPlan::Dtos::PlanCopyInput.new(
        source_cultivation_plan_id: source_plan.id,
        new_year: new_year,
        user_id: user.id
      )
    )
    new_plan = ::CultivationPlan.find(new_entity.id)

    assert new_plan.persisted?
    assert new_plan.plan_type_private?
    assert_equal user.id, new_plan.user_id
    assert_equal new_year, new_plan.plan_year
    assert_equal ref_farm.id, new_plan.farm_id
    assert_equal source_plan.cultivation_plan_fields.count, new_plan.cultivation_plan_fields.count
    assert_equal source_plan.cultivation_plan_crops.count, new_plan.cultivation_plan_crops.count
    assert_equal source_plan.field_cultivations.count, new_plan.field_cultivations.count
    assert(
      log.entries.any? { |lvl, msg| lvl == :info && msg.include?("Plan copy completed") },
      "注入 logger に年度コピー完了ログが残ること"
    )
  end

  test "copy_private_plan_for_year sets session_id when given" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "SessCp#{SecureRandom.hex(4)}")
    source_plan, = build_public_plan_with_field_cultivation(
      farm: ref_farm,
      ref_crop: ref_crop,
      plan_name: "SessPlan#{SecureRandom.hex(4)}"
    )

    sid = "ws-sess-#{SecureRandom.hex(8)}"
    new_entity = CompositionRoot.plan_copy_interactor.call(
      Domain::CultivationPlan::Dtos::PlanCopyInput.new(
        source_cultivation_plan_id: source_plan.id,
        new_year: Date.current.year + 1,
        user_id: user.id,
        session_id: sid
      )
    )
    new_plan = ::CultivationPlan.find(new_entity.id)

    assert_equal sid, new_plan.session_id
  end

end
