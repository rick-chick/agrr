# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      # 計画単位で field_cultivation 集合を永続化同期する（read は FieldCultivationSyncPlanReadGateway）。
      class FieldCultivationSyncGateway
        # @param plan_id [Integer]
        # @param sync_apply [Domain::FieldCultivation::Dtos::FieldCultivationSyncApply]
        def sync_by_plan_id(plan_id:, sync_apply:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
