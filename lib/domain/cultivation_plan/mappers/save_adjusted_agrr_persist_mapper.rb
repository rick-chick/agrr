# frozen_string_literal: true

require "set"

module Domain
  module CultivationPlan
    module Mappers
      module SaveAdjustedAgrrPersistMapper
        module_function

        # @param result [Dtos::SaveAdjustedAgrrResultInput]
        # @param context [Dtos::SaveAdjustedAgrrPersistContext]
        # @return [Dtos::SaveAdjustedAgrrPersistBundle]
        def build_bundle(result:, context:)
          used_crop_ids = Set.new
          desired_records = []

          result.field_schedules.each do |field_schedule|
            field_id = field_schedule.field_id
            next unless field_id

            plan_field = context.plan_fields_by_id[field_id.to_i]
            unless plan_field
              raise Errors::AdjustResultSaveReferenceError.new(
                kind: Errors::AdjustResultSaveReferenceError::KIND_FIELD_MISSING,
                message: "plan field missing",
                field_id: field_id
              )
            end

            next if field_schedule.allocations.empty?

            field_schedule.allocations.each do |allocation|
              used_crop_ids.add(allocation.crop_id)

              plan_crop = context.plan_crops_by_crop_id[allocation.crop_id]
              unless plan_crop
                raise Errors::AdjustResultSaveReferenceError.new(
                  kind: Errors::AdjustResultSaveReferenceError::KIND_PLAN_CROP_MISSING,
                  message: "plan crop missing",
                  crop_id: allocation.crop_id
                )
              end

              allocation_id_raw = allocation.resolved_allocation_raw
              allocation_id = allocation_id_raw.present? ? allocation_id_raw.to_i : nil

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

              attrs = Dtos::SaveAdjustedAgrrFieldCultivationUpsertAttrs.new(
                field_cultivation_id: allocation_id,
                cultivation_plan_field_id: plan_field,
                cultivation_plan_crop_id: plan_crop,
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

              desired_records << attrs
            end
          end

          existing_ids = context.existing_field_cultivation_ids.to_set
          upserts = desired_records.select do |rec|
            rec.field_cultivation_id.present? && existing_ids.include?(rec.field_cultivation_id)
          end
          creates = desired_records.reject do |rec|
            rec.field_cultivation_id.present? && existing_ids.include?(rec.field_cultivation_id)
          end
          desired_existing_ids = upserts.map(&:field_cultivation_id)
          delete_ids = existing_ids.to_a - desired_existing_ids

          summary = Dtos::SaveAdjustedAgrrPlanSummaryAttrs.new(
            summary: result.summary,
            total_profit: result.total_profit,
            total_revenue: result.total_revenue,
            total_cost: result.total_cost,
            optimization_time: result.optimization_time,
            algorithm_used: result.algorithm_used,
            is_optimal: result.is_optimal
          )

          Dtos::SaveAdjustedAgrrPersistBundle.new(
            upserts: upserts,
            creates: creates,
            delete_field_cultivation_ids: delete_ids,
            used_crop_ids: used_crop_ids.to_a,
            plan_summary: summary
          )
        end

        def parse_date!(raw_value, field:, allocation_id:)
          return raw_value if raw_value.is_a?(Date)

          Date.parse(raw_value.to_s)
        rescue ArgumentError
          kind =
            if field == :start_date
              Errors::AdjustResultSaveReferenceError::KIND_START_DATE_INVALID
            else
              Errors::AdjustResultSaveReferenceError::KIND_COMPLETION_DATE_INVALID
            end
          raise Errors::AdjustResultSaveReferenceError.new(
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
