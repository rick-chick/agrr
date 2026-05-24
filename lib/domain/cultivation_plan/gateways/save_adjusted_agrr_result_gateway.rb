# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # Agrr adjust 結果の FieldCultivation CRUD と CultivationPlan サマリ更新（オーケストレーションは Interactor）。
      class SaveAdjustedAgrrResultGateway
        # @param plan_id [Integer]
        # @return [Domain::CultivationPlan::Dtos::SaveAdjustedAgrrPersistContext]
        def load_persist_context(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @param plan_id [Integer]
        # @param bundle [Domain::CultivationPlan::Dtos::SaveAdjustedAgrrPersistBundle]
        def apply_persist_bundle!(plan_id:, bundle:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
