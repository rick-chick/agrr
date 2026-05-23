# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanAdjustPlanGrowthReadActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanAdjustPlanGrowthReadGateway
        def initialize(logger:)
          super(logger: logger)
        end

        def load(auth:, plan_id:)
          cultivation_plan = ::Adapters::CultivationPlan::RestAuthorizedCultivationPlanLoader.find!(auth, plan_id)
          crop_rows = cultivation_plan.cultivation_plan_crops.filter_map do |plan_crop|
            crop = plan_crop.crop
            next if crop.nil?

            Domain::CultivationPlan::Dtos::CultivationPlanAdjustCropGrowthRow.new(
              crop_name: crop.name,
              growth_stage_count: crop.crop_stages.size
            )
          end

          { kind: :success, plan_id: cultivation_plan.id, crop_rows: crop_rows }
        rescue ActiveRecord::RecordNotFound
          { kind: :not_found }
        rescue ActiveRecord::RecordInvalid => e
          logger.error "❌ [Adjust growth read] Record invalid: #{e.message}"
          { kind: :record_invalid, message: e.message }
        rescue ActiveRecord::ActiveRecordError => e
          logger.error "❌ [Adjust growth read] ActiveRecord error: #{e.message}"
          { kind: :unexpected, message: e.message }
        end
      end
    end
  end
end
