# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module CultivationPlanWorkbenchSnapshotMapper
        module_function

        # @param rest_plan_snapshot [Domain::CultivationPlan::Dtos::CultivationPlanRestPlanSnapshot]
        # @param available_crop_rows [Array]
        # @return [Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot]
        def from_snapshots(rest_plan_snapshot:, available_crop_rows:)
          base = from_rest_plan_snapshot(rest_plan_snapshot)
          Dtos::CultivationPlanWorkbenchSnapshot.new(
            plan: base.plan,
            fields: base.fields,
            crops: base.crops,
            cultivations: base.cultivations,
            available_crop_rows: available_crop_rows,
            farm_region: base.farm_region
          )
        end

        # @param snapshot [Domain::CultivationPlan::Dtos::CultivationPlanRestPlanSnapshot]
        # @return [Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot]
        def from_rest_plan_snapshot(snapshot)
          plan_header = Dtos::CultivationPlanWorkbenchPlanHeader.new(
            id: snapshot.id,
            user_id: snapshot.user_id,
            plan_year: snapshot.plan_year,
            plan_name: snapshot.plan_name,
            plan_type: snapshot.plan_type,
            status: snapshot.status,
            total_area: snapshot.total_area,
            planning_start_date: snapshot.calculated_planning_start_date,
            planning_end_date: snapshot.prediction_target_end_date,
            total_profit: snapshot.total_profit,
            total_revenue: snapshot.total_revenue,
            total_cost: snapshot.total_cost
          )

          field_rows = snapshot.field_rows.map do |field|
            Dtos::CultivationPlanWorkbenchFieldRow.new(
              id: field.id,
              field_id: field.id,
              name: field.display_name,
              area: field.area,
              daily_fixed_cost: field.daily_fixed_cost
            )
          end

          crop_rows = snapshot.crop_rows.map do |crop|
            Dtos::CultivationPlanWorkbenchCropRow.new(
              id: crop.id,
              name: crop.display_name,
              area_per_unit: crop.area_per_unit,
              revenue_per_area: crop.revenue_per_area
            )
          end

          cultivation_rows = snapshot.cultivation_rows.map do |fc|
            Dtos::CultivationPlanWorkbenchCultivationRow.new(
              id: fc.id,
              field_id: fc.cultivation_plan_field_id,
              field_name: fc.field_display_name,
              crop_id: fc.cultivation_plan_crop_id,
              crop_name: fc.crop_display_name,
              area: fc.area,
              start_date: fc.start_date,
              completion_date: fc.completion_date,
              cultivation_days: fc.cultivation_days,
              estimated_cost: fc.estimated_cost,
              revenue: fc.optimization_result&.dig("revenue") || 0.0,
              profit: fc.optimization_result&.dig("profit") || 0.0,
              status: fc.status
            )
          end

          Dtos::CultivationPlanWorkbenchSnapshot.new(
            plan: plan_header,
            fields: field_rows,
            crops: crop_rows,
            cultivations: cultivation_rows,
            available_crop_rows: [],
            farm_region: snapshot.farm_region
          )
        end
      end
    end
  end
end
