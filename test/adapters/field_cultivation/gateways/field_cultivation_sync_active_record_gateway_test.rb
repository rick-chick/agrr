# frozen_string_literal: true

require "test_helper"

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationSyncActiveRecordGatewayTest < ActiveSupport::TestCase
        def setup
          @gateway = FieldCultivationSyncActiveRecordGateway.new(
            logger: Rails.logger,
            clock: Adapters::Shared::Ports::RailsClockAdapter.new
          )
        end

        # snapshot 読取・FC update/create/delete は integration（agrr_optimization_diff_save_test）と
        # domain-lib（interactor / mapper）が証明。adapter は plan_crop 削除の永続化のみ。
        test "sync_by_plan_id deletes cultivation_plan_crops listed in sync_apply" do
          plan = create(:cultivation_plan)
          crop = create(:crop, :with_stages)
          referenced = create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)
          orphan = create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)

          sync_apply = build_sync_apply(
            cultivation_plan_crop_ids_to_delete: [ orphan.id ]
          )

          @gateway.sync_by_plan_id(plan_id: plan.id, sync_apply: sync_apply)

          assert CultivationPlanCrop.exists?(referenced.id)
          refute CultivationPlanCrop.exists?(orphan.id)
        end

        private

        def build_sync_apply(**overrides)
          defaults = {
            field_cultivations_to_update: [],
            field_cultivations_to_create: [],
            field_cultivation_ids_to_delete: [],
            cultivation_plan_crop_ids_to_delete: [],
            cultivation_plan_summary: build_plan_summary
          }
          Domain::FieldCultivation::Dtos::FieldCultivationSyncApply.new(**defaults.merge(overrides))
        end

        def build_plan_summary(**attrs)
          Domain::FieldCultivation::Dtos::FieldCultivationSyncCultivationPlanSummary.new(
            optimization_summary: { "ok" => true },
            total_profit: 0.0,
            total_revenue: 0.0,
            total_cost: 0.0,
            optimization_time: 0.0,
            algorithm_used: "adapter-test",
            is_optimal: false,
            status: "completed",
            **attrs
          )
        end
      end
    end
  end
end
