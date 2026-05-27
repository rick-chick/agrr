# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # 参照 AgriculturalTask id → ユーザー task id（共有マップ + GW フォールバック、見つかったら map に書き戻す）。
    module PlanSaveAgriculturalTaskIdLookup
      module_function

      # @param reference_task_id [Integer]
      # @param user_id [Integer]
      # @param map [Hash{Integer=>Integer}] mutated on fallback hit
      # @param plan_save_user_agricultural_task_gateway [Domain::CultivationPlan::Gateways::PlanSaveUserAgriculturalTaskGateway]
      # @return [Integer, nil]
      def resolve(reference_task_id:, user_id:, map:, plan_save_user_agricultural_task_gateway:)
        ref_id = reference_task_id.to_i
        return map[ref_id] if map.key?(ref_id)

        snapshot = plan_save_user_agricultural_task_gateway.find_by_user_id_and_source_agricultural_task_id(
          user_id: user_id.to_i,
          source_agricultural_task_id: ref_id
        )
        return nil unless snapshot

        map[ref_id] = snapshot.id
        snapshot.id
      end
    end
  end
end
