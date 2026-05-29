# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      # 同期前の計画 read（1 表ずつ）。組立は Interactor + domain mapper。
      class FieldCultivationSyncPlanReadGateway
        # @param plan_id [Integer]
        # @return [Array<Integer>] cultivation_plan_field id（schedule field_id との対応用）
        def list_sync_plan_field_ids_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @param plan_id [Integer]
        # @return [Array<Dtos::FieldCultivationSyncPlanCropEntry>]
        def list_sync_plan_crop_entries_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @param plan_id [Integer]
        # @return [Array<Dtos::FieldCultivationSyncExistingFieldCultivationEntry>]
        def list_sync_existing_field_cultivation_entries_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
