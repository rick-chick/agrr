# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Mappers::InteractionRuleMapperTest < ActiveSupport::TestCase
  include PlanSaveMapperTestSupport

  test "copies continuous_cultivation rule when crop group matches reference plan" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    group_name = "RuleCrop#{SecureRandom.hex(4)}"
    ref_crop = build_reference_crop(name: group_name)
    plan = build_public_reference_plan(farm: ref_farm, ref_crop: ref_crop)

    ref_rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: group_name,
      target_group: "OtherGroup",
      impact_ratio: 0.55,
      is_directional: true,
      is_reference: true,
      region: "jp"
    )

    result = plan_save_result
    ctx = build_plan_save_context(
      user: user,
      session_data: { plan_id: plan.id },
      result: result
    )
    stub_plan_save_crop_mappings_for_mapper_test(ctx, ref_crop: ref_crop)

    rules = Adapters::CultivationPlan::Mappers::InteractionRuleMapper.new(ctx).copy_interaction_rules_for_region(ref_farm.region)
    assert_equal 1, rules.size
    ur = user.interaction_rules.find_by(source_interaction_rule_id: ref_rule.id)
    assert_not_nil ur
    assert_equal group_name, ur.source_group
  end

  test "skips when user already has matching interaction rule" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    group_name = "RuleCrop2_#{SecureRandom.hex(4)}"
    ref_crop = build_reference_crop(name: group_name)
    plan = build_public_reference_plan(farm: ref_farm, ref_crop: ref_crop, plan_name: "ir2")

    ref_rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: group_name,
      target_group: "Other2",
      impact_ratio: 0.4,
      is_directional: true,
      is_reference: true,
      region: "jp"
    )

    ctx1 = build_plan_save_context(
      user: user,
      session_data: { plan_id: plan.id },
      result: plan_save_result
    )
    stub_plan_save_crop_mappings_for_mapper_test(ctx1, ref_crop: ref_crop)
    Adapters::CultivationPlan::Mappers::InteractionRuleMapper.new(ctx1).copy_interaction_rules_for_region(ref_farm.region)
    existing = user.interaction_rules.find_by(source_interaction_rule_id: ref_rule.id)

    result2 = plan_save_result
    ctx2 = build_plan_save_context(
      user: user,
      session_data: { plan_id: plan.id },
      result: result2
    )
    stub_plan_save_crop_mappings_for_mapper_test(ctx2, ref_crop: ref_crop)
    Adapters::CultivationPlan::Mappers::InteractionRuleMapper.new(ctx2).copy_interaction_rules_for_region(ref_farm.region)

    existing_crop = user.crops.find_by(source_crop_id: ref_crop.id)
    assert_skipped_exact result2,
                         { crops: [ existing_crop.id ],
                           interaction_rules: user.interaction_rules.where.not(source_interaction_rule_id: nil).pluck(:id) }
  end
end
