# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanAddCropOptimizeAttachActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanAddCropOptimizeAttachGateway
        def initialize(logger:)
          super(logger: logger)
        end

        def attach_plan!(auth:, plan_id:, optimization_host:)
          cultivation_plan = ::Adapters::CultivationPlan::RestAuthorizedCultivationPlanLoader.find!(auth, plan_id)
          optimization_host.attach_plan_for_candidates(cultivation_plan)
          { kind: :success }
        rescue ActiveRecord::RecordNotFound
          { kind: :not_found }
        rescue ActiveRecord::RecordInvalid => e
          logger.error "❌ [Add Crop attach] Record invalid: #{e.message}"
          { kind: :record_invalid, message: e.message }
        rescue ActiveRecord::ActiveRecordError => e
          logger.error "❌ [Add Crop attach] ActiveRecord error: #{e.message}"
          { kind: :unexpected, message: e.message }
        end
      end
    end
  end
end
