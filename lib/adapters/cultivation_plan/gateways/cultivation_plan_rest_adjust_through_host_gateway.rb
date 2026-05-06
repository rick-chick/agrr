# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      # adjust: / AgrrOptimization#adjust_with_db_weather へのブリッジ（単一 Authorized load）。
      class CultivationPlanRestAdjustThroughHostGateway < Domain::CultivationPlan::Gateways::CultivationPlanRestAdjustGateway
        def initialize(host_controller:, logger:)
          super(logger: logger)
          @host = host_controller
        end

        def execute(auth:, plan_id:, moves:)
          cultivation_plan = ::Adapters::CultivationPlan::RestAuthorizedPlanAccess.find!(auth, plan_id)

          cultivation_plan.cultivation_plan_crops.each do |plan_crop|
            crop = plan_crop.crop
            logger.info(
              "🔍 [Validate Growth Stages] plan_crop_id=#{plan_crop.id} crop_id=#{crop&.id} crop_stages_loaded=#{crop&.association(:crop_stages)&.loaded? rescue 'n/a'}"
            )
            logger.info(
              "🔍 [Validate Growth Stages] crop_stages_count=#{crop&.crop_stages&.size rescue 'n/a'}"
            )
            if crop.crop_stages.empty?
              return { kind: :crop_missing_growth_stages, crop_name: crop.name }
            end
          end

          @host.instance_variable_set(:@cultivation_plan, cultivation_plan)

          logger.info "🔧 [Adjust] Processed moves with type conversion: #{moves.inspect}"
          adjust_hash = @host.adjust_with_db_weather(cultivation_plan, moves)
          { kind: :adjust_result, adjust_hash: adjust_hash }
        rescue ActiveRecord::RecordNotFound
          { kind: :not_found }
        rescue ActiveRecord::RecordInvalid => e
          logger.error "❌ [Adjust] Record invalid: #{e.message}"
          { kind: :record_invalid, message: e.message }
        rescue StandardError => e
          logger.error "❌ [Adjust] Error: #{e.message}"
          { kind: :unexpected, message: e.message }
        end
      end
    end
  end
end
