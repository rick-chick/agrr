# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module CultivationPlanRestPlanSnapshotMapper
        module_function

        # @param header [Dtos::CultivationPlanRestPlanHeaderSnapshot]
        # @param field_rows [Array<Dtos::CultivationPlanRestPlanFieldRowSnapshot>]
        # @param crop_rows [Array<Dtos::CultivationPlanRestPlanCropRowSnapshot>]
        # @param cultivation_rows [Array<Dtos::CultivationPlanRestPlanCultivationRowSnapshot>]
        # @param palette_crop_ids [Array<Integer>]
        # @return [Dtos::CultivationPlanRestPlanSnapshot]
        def from_snapshots(header:, field_rows:, crop_rows:, cultivation_rows:, palette_crop_ids:)
          Dtos::CultivationPlanRestPlanSnapshot.new(
            id: header.id,
            user_id: header.user_id,
            plan_year: header.plan_year,
            plan_name: header.plan_name,
            display_name: header.display_name,
            plan_type: header.plan_type,
            status: header.status,
            total_area: header.total_area,
            planning_start_date: header.planning_start_date,
            planning_end_date: header.planning_end_date,
            calculated_planning_start_date: header.calculated_planning_start_date,
            prediction_target_end_date: header.prediction_target_end_date,
            total_profit: header.total_profit,
            total_revenue: header.total_revenue,
            total_cost: header.total_cost,
            farm_display_name: header.farm_display_name,
            farm_region: header.farm_region,
            field_rows: field_rows,
            crop_rows: crop_rows,
            cultivation_rows: cultivation_rows,
            palette_crop_ids: palette_crop_ids
          )
        end

        # @param read_gateway [Gateways::CultivationPlanRestPlanReadGateway]
        # @param plan_id [Integer]
        def load_snapshot(read_gateway:, plan_id:)
          from_snapshots(
            header: read_gateway.find_plan_header_snapshot_by_plan_id(plan_id: plan_id),
            field_rows: read_gateway.list_rest_plan_field_row_snapshots_by_plan_id(plan_id: plan_id),
            crop_rows: read_gateway.list_rest_plan_crop_row_snapshots_by_plan_id(plan_id: plan_id),
            cultivation_rows: read_gateway.list_rest_plan_cultivation_row_snapshots_by_plan_id(plan_id: plan_id),
            palette_crop_ids: read_gateway.list_palette_crop_ids_by_plan_id(plan_id: plan_id)
          )
        end
      end
    end
  end
end
