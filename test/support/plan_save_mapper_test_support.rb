# frozen_string_literal: true

require_relative "plan_save_test_support"

# 残存 PlanSave mapper 契約テスト用（ctx に ID マップだけ載せる）。
module PlanSaveMapperTestSupport
  include PlanSaveTestSupport

  # mapper 単体用: ctx に作物 ID マップだけ載せる（PlanSaveEnsureUserCropsInteractor は呼ばない）
  def stub_plan_save_crop_mappings_for_mapper_test(ctx, ref_crop:, cpc_id: nil)
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
    groups = [ ref_crop.name ]
    groups.concat(Array(ref_crop.groups)) if ref_crop.groups.present?
    ctx.reference_crop_groups = groups.compact.uniq
    user_crop
  end

  def stub_plan_save_user_crops_for_plan_save_test(ctx, ref_crop:, cpc_id: nil)
    [ stub_plan_save_crop_mappings_for_mapper_test(ctx, ref_crop: ref_crop, cpc_id: cpc_id) ]
  end

  # 指定カテゴリごとのスキップ id が一致し、それ以外のカテゴリは空であることを表明する
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
