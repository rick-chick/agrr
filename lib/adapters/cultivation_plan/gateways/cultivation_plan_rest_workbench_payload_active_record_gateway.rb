# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanRestWorkbenchPayloadActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanRestWorkbenchPayloadGateway
        def initialize(logger:, available_crop_rows_gateway:)
          super(logger: logger, available_crop_rows_gateway: available_crop_rows_gateway)
        end

        def build(auth:, plan_id:)
          cultivation_plan = ::Adapters::CultivationPlan::RestAuthorizedCultivationPlanLoader.find!(auth, plan_id)
          available_crop_rows = available_crop_rows_gateway.rows(
            auth: auth,
            farm_region: cultivation_plan.farm&.region
          )

          fields_data = cultivation_plan.cultivation_plan_fields.map do |field|
            {
              id: field.id,
              field_id: field.id,
              name: field.display_name,
              area: field.area,
              daily_fixed_cost: field.daily_fixed_cost
            }
          end

          crops_data = cultivation_plan.cultivation_plan_crops.map do |crop|
            {
              id: crop.id,
              name: crop.display_name,
              area_per_unit: crop.area_per_unit,
              revenue_per_area: crop.revenue_per_area
            }
          end

          cultivations_data = cultivation_plan.field_cultivations.map do |fc|
            {
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
            }
          end

          body = {
            success: true,
            data: {
              id: cultivation_plan.id,
              plan_year: cultivation_plan.plan_year,
              plan_name: cultivation_plan.plan_name,
              plan_type: cultivation_plan.plan_type,
              status: cultivation_plan.status,
              total_area: cultivation_plan.total_area,
              planning_start_date: cultivation_plan.calculated_planning_start_date,
              planning_end_date: cultivation_plan.prediction_target_end_date,
              fields: fields_data,
              crops: crops_data,
              available_crops: available_crop_rows,
              cultivations: cultivations_data
            },
            total_profit: cultivation_plan.total_profit,
            total_revenue: cultivation_plan.total_revenue,
            total_cost: cultivation_plan.total_cost
          }

          { kind: :success, body: body }
        rescue ActiveRecord::RecordNotFound
          { kind: :not_found }
        rescue ActiveRecord::RecordInvalid => e
          logger.error "❌ [Data] Record invalid: #{e.message}"
          { kind: :record_invalid, message: e.message }
        rescue ActiveRecord::ActiveRecordError => e
          logger.error "❌ [Data] ActiveRecord error: #{e.message}"
          { kind: :unexpected, message: e.message }
        end
      end
    end
  end
end
