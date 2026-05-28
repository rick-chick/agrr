# frozen_string_literal: true

require "set"

module Domain
  module FieldCultivation
    module Mappers
      module FieldCultivationSyncTargetSnapshotMapper
        module_function

        # @param sync_input [Dtos::FieldCultivationSyncInput]
        # @param plan_snapshot [Dtos::FieldCultivationSyncPlanSnapshot]
        # @return [Dtos::FieldCultivationSyncTargetSnapshot]
        def to_target_snapshot(sync_input:, plan_snapshot:)
          referenced_crop_ids = Set.new
          field_cultivation_rows = []

          sync_input.field_schedules.each do |field_schedule|
            field_id = field_schedule.field_id
            next unless field_id

            plan_field_id = plan_snapshot.plan_fields_by_id[field_id.to_i]
            unless plan_field_id
              raise Errors::FieldCultivationSyncReferenceError.new(
                kind: Errors::FieldCultivationSyncReferenceError::KIND_FIELD_MISSING,
                message: "plan field missing",
                field_id: field_id
              )
            end

            next if field_schedule.allocations.empty?

            field_schedule.allocations.each do |allocation|
              referenced_crop_ids.add(allocation.crop_id)

              plan_crop_id = FieldCultivationSyncPlanCropResolver.resolve_plan_crop_id(
                plan_snapshot: plan_snapshot,
                allocation: allocation
              )
              unless plan_crop_id
                raise Errors::FieldCultivationSyncReferenceError.new(
                  kind: Errors::FieldCultivationSyncReferenceError::KIND_PLAN_CROP_MISSING,
                  message: "plan crop missing",
                  crop_id: allocation.crop_id
                )
              end

              allocation_id_raw = allocation.resolved_allocation_raw
              field_cultivation_id = allocation_id_raw.present? ? allocation_id_raw.to_i : nil

              start_date = parse_date!(
                allocation.start_date,
                field: :start_date,
                allocation_id: allocation_id_raw
              )
              completion_date = parse_date!(
                allocation.completion_date,
                field: :completion_date,
                allocation_id: allocation_id_raw
              )

              field_cultivation_rows << Dtos::FieldCultivationSyncDesiredRow.new(
                field_cultivation_id: field_cultivation_id,
                cultivation_plan_field_id: plan_field_id,
                cultivation_plan_crop_id: plan_crop_id,
                start_date: start_date,
                completion_date: completion_date,
                cultivation_days: (completion_date - start_date).to_i + 1,
                area: allocation.area_used || allocation.area,
                estimated_cost: allocation.total_cost || allocation.cost,
                optimization_result: {
                  revenue: allocation.expected_revenue || allocation.revenue,
                  profit: allocation.profit,
                  accumulated_gdd: allocation.accumulated_gdd
                }
              )
            end
          end

          cultivation_plan_summary = Dtos::FieldCultivationSyncCultivationPlanSummary.new(
            optimization_summary: sync_input.optimization_summary,
            total_profit: sync_input.total_profit,
            total_revenue: sync_input.total_revenue,
            total_cost: sync_input.total_cost,
            optimization_time: sync_input.optimization_time,
            algorithm_used: sync_input.algorithm_used,
            is_optimal: sync_input.is_optimal
          )

          Dtos::FieldCultivationSyncTargetSnapshot.new(
            field_cultivation_rows: field_cultivation_rows,
            cultivation_plan_summary: cultivation_plan_summary,
            referenced_crop_ids: referenced_crop_ids.to_a
          )
        end

        def parse_date!(raw_value, field:, allocation_id:)
          return raw_value if raw_value.is_a?(Date)

          Date.parse(raw_value.to_s)
        rescue ArgumentError
          kind =
            if field == :start_date
              Errors::FieldCultivationSyncReferenceError::KIND_START_DATE_INVALID
            else
              Errors::FieldCultivationSyncReferenceError::KIND_COMPLETION_DATE_INVALID
            end
          raise Errors::FieldCultivationSyncReferenceError.new(
            kind: kind,
            message: "invalid date",
            allocation_id: allocation_id,
            raw_value: raw_value
          )
        end
        private_class_method :parse_date!
      end
    end
  end
end
