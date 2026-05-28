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

        test "find_sync_plan_snapshot_by_plan_id lists every cultivation_plan_crop row" do
          plan = create(:cultivation_plan)
          crop = create(:crop, :with_stages)
          plan_crop_a = create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)
          plan_crop_b = create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)

          snapshot = @gateway.find_sync_plan_snapshot_by_plan_id(plan_id: plan.id)

          assert_equal plan.id, snapshot.plan_id
          assert_equal 2, snapshot.plan_crop_rows.size
          assert_equal [ plan_crop_a.id, plan_crop_b.id ].sort,
                       snapshot.plan_crop_rows.map(&:plan_crop_id).sort
          assert_equal [ crop.id.to_s, crop.id.to_s ].sort,
                       snapshot.plan_crop_rows.map(&:crop_id).sort
        end

        test "find_sync_plan_snapshot_by_plan_id maps existing field_cultivations by id" do
          plan = create(:cultivation_plan)
          field = create(:cultivation_plan_field, cultivation_plan: plan)
          crop = create(:crop, :with_stages)
          plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)
          fc = create(
            :field_cultivation,
            cultivation_plan: plan,
            cultivation_plan_field: field,
            cultivation_plan_crop: plan_crop,
            start_date: Date.current,
            completion_date: Date.current + 3
          )

          snapshot = @gateway.find_sync_plan_snapshot_by_plan_id(plan_id: plan.id)

          entry = snapshot.existing_field_cultivations_by_id[fc.id]
          assert_equal fc.id, entry.field_cultivation_id
          assert_equal plan_crop.id, entry.cultivation_plan_crop_id
          assert_equal crop.id.to_s, entry.crop_id
        end

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
