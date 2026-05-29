# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module PrivatePlanReadSnapshotMapper
        module_function

        # @param snapshot [Domain::CultivationPlan::Dtos::CultivationPlanRestPlanSnapshot]
        # @return [Domain::CultivationPlan::Dtos::PrivatePlanReadSnapshot]
        def from_snapshot(snapshot)
          field_cultivations = snapshot.cultivation_rows.map do |fc|
            Dtos::PrivateCultivationPlanDetail::FieldCultivationRead.new(
              id: fc.id,
              cultivation_plan_field_id: fc.cultivation_plan_field_id,
              field_display_name: fc.field_display_name,
              cultivation_plan_crop_id: fc.cultivation_plan_crop_id,
              crop_display_name: fc.crop_display_name,
              start_date: fc.start_date,
              completion_date: fc.completion_date,
              cultivation_days: fc.cultivation_days,
              area: fc.area,
              estimated_cost: fc.estimated_cost,
              optimization_profit: GanttChartRowHashes.profit_from_optimization_result(fc.optimization_result)
            )
          end

          cultivation_plan_fields = snapshot.field_rows.map do |field|
            Dtos::PrivateCultivationPlanDetail::PlanFieldRead.new(
              id: field.id,
              name: field.name,
              area: field.area
            )
          end

          Dtos::PrivatePlanReadSnapshot.new(
            id: snapshot.id,
            display_name: snapshot.display_name,
            farm_display_name: snapshot.farm_display_name,
            total_area: snapshot.total_area,
            field_cultivations_count: snapshot.cultivation_rows.size,
            cultivation_plan_fields_count: snapshot.field_rows.size,
            planning_start_date: snapshot.planning_start_date,
            planning_end_date: snapshot.planning_end_date,
            status: snapshot.status,
            field_cultivations: field_cultivations,
            cultivation_plan_fields: cultivation_plan_fields,
            palette_used_crop_ids: snapshot.palette_crop_ids
          )
        end
      end
    end
  end
end
