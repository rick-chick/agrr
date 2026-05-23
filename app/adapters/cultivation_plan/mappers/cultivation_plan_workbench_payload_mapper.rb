# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module CultivationPlanWorkbenchPayloadMapper
        module_function

        # @param snapshot [Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot]
        # @return [Hash] REST workbench JSON（render json にそのまま渡す）
        def to_json_body(snapshot)
          p = snapshot.plan
          {
            success: true,
            data: {
              id: p.id,
              plan_year: p.plan_year,
              plan_name: p.plan_name,
              plan_type: p.plan_type,
              status: p.status,
              total_area: p.total_area,
              planning_start_date: p.planning_start_date,
              planning_end_date: p.planning_end_date,
              fields: snapshot.fields.map { |r| field_row_to_h(r) },
              crops: snapshot.crops.map { |r| crop_row_to_h(r) },
              available_crops: snapshot.available_crop_rows.map(&:to_h),
              cultivations: snapshot.cultivations.map { |r| cultivation_row_to_h(r) }
            },
            total_profit: p.total_profit,
            total_revenue: p.total_revenue,
            total_cost: p.total_cost
          }
        end

        def field_row_to_h(row)
          {
            id: row.id,
            field_id: row.field_id,
            name: row.name,
            area: row.area,
            daily_fixed_cost: row.daily_fixed_cost
          }
        end
        private_class_method :field_row_to_h

        def crop_row_to_h(row)
          {
            id: row.id,
            name: row.name,
            area_per_unit: row.area_per_unit,
            revenue_per_area: row.revenue_per_area
          }
        end
        private_class_method :crop_row_to_h

        def cultivation_row_to_h(row)
          {
            id: row.id,
            field_id: row.field_id,
            field_name: row.field_name,
            crop_id: row.crop_id,
            crop_name: row.crop_name,
            area: row.area,
            start_date: row.start_date,
            completion_date: row.completion_date,
            cultivation_days: row.cultivation_days,
            estimated_cost: row.estimated_cost,
            revenue: row.revenue,
            profit: row.profit,
            status: row.status
          }
        end
        private_class_method :cultivation_row_to_h
      end
    end
  end
end
