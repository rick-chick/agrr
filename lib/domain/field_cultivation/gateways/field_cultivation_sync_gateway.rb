# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      # 計画単位で field_cultivation 集合を目標状態に同期する（オーケストレーションは Interactor）。
      class FieldCultivationSyncGateway
        # @param plan_id [Integer]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationSyncPlanSnapshot]
        def find_sync_plan_snapshot_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @param plan_id [Integer]
        # @param sync_apply [Domain::FieldCultivation::Dtos::FieldCultivationSyncApply]
        def sync_by_plan_id(plan_id:, sync_apply:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
