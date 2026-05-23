# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanAddCropPlanCropDeleteActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanAddCropPlanCropDeleteGateway
        def initialize(logger:)
          super(logger: logger)
        end

        def destroy_plan_crop!(plan_crop_id:)
          record = ::CultivationPlanCrop.find_by(id: plan_crop_id)
          unless record
            return { kind: :not_found }
          end

          record.destroy!
          { kind: :success }
        rescue ActiveRecord::RecordNotFound
          { kind: :not_found }
        rescue ActiveRecord::ActiveRecordError => e
          logger.error "❌ [Add Crop delete] ActiveRecord error: #{e.message}"
          { kind: :unexpected, message: e.message }
        end
      end
    end
  end
end
