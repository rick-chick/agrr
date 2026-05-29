# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      # 計画に紐づく field_cultivation 集合を望ましい状態へ同期する。
      class FieldCultivationSyncInteractor < Domain::FieldCultivation::Ports::FieldCultivationSyncInputPort
        def initialize(sync_gateway:, sync_plan_read_gateway:, logger:)
          @sync_gateway = sync_gateway
          @sync_plan_read_gateway = sync_plan_read_gateway
          @logger = logger
        end

        # @param plan_id [Integer]
        # @param sync_input [Dtos::FieldCultivationSyncInput]
        def call(plan_id:, sync_input:)
          Policies::FieldCultivationSyncPolicy.validate!(sync_input)

          plan_snapshot = load_sync_plan_snapshot(plan_id: plan_id)
          target_snapshot = Mappers::FieldCultivationSyncTargetSnapshotMapper.to_target_snapshot(
            sync_input: sync_input,
            plan_snapshot: plan_snapshot
          )
          sync_apply = Mappers::FieldCultivationSyncApplyMapper.to_apply(
            plan_snapshot: plan_snapshot,
            target_snapshot: target_snapshot
          )

          @logger.info "🛠️ [FieldCultivationSync] to_update: #{sync_apply.field_cultivations_to_update.size}, " \
                        "to_create: #{sync_apply.field_cultivations_to_create.size}, " \
                        "to_delete: #{sync_apply.field_cultivation_ids_to_delete.size}, " \
                        "plan_crop_delete: #{sync_apply.cultivation_plan_crop_ids_to_delete.size}"

          @sync_gateway.sync_by_plan_id(plan_id: plan_id, sync_apply: sync_apply)
        end

        private

        def load_sync_plan_snapshot(plan_id:)
          plan_field_ids = @sync_plan_read_gateway.list_sync_plan_field_ids_by_plan_id(plan_id: plan_id)
          plan_crop_rows = @sync_plan_read_gateway.list_sync_plan_crop_entries_by_plan_id(plan_id: plan_id)
          existing_entries =
            @sync_plan_read_gateway.list_sync_existing_field_cultivation_entries_by_plan_id(plan_id: plan_id)

          Mappers::FieldCultivationSyncPlanSnapshotMapper.from_snapshots(
            plan_id: plan_id,
            plan_field_ids: plan_field_ids,
            plan_crop_rows: plan_crop_rows,
            existing_field_cultivation_entries: existing_entries
          )
        end
      end
    end
  end
end
