# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanAdjustPlanGrowthReadActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanAdjustPlanGrowthReadGateway
        def initialize(logger:)
          super(logger: logger)
        end

        def list_by_plan_id_and_user_id(plan_id:, user_id:)
          cultivation_plan = Persistence::CultivationPlanRestPlanPreload.find_by_plan_id_and_user_id(
            plan_id: plan_id,
            user_id: user_id
          )
          snapshots_from_plan(cultivation_plan)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::RecordInvalid => e
          logger.error "❌ [Adjust growth read] Record invalid: #{e.message}"
          raise Domain::Shared::Exceptions::RecordInvalid.new(nil, errors: e.record.errors.full_messages)
        rescue ActiveRecord::ActiveRecordError => e
          logger.error "❌ [Adjust growth read] ActiveRecord error: #{e.message}"
          raise
        end

        def list_by_plan_id(plan_id:)
          cultivation_plan = Persistence::CultivationPlanRestPlanPreload.find_by_plan_id_public(
            plan_id: plan_id
          )
          snapshots_from_plan(cultivation_plan)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::RecordInvalid => e
          logger.error "❌ [Adjust growth read] Record invalid: #{e.message}"
          raise Domain::Shared::Exceptions::RecordInvalid.new(nil, errors: e.record.errors.full_messages)
        rescue ActiveRecord::ActiveRecordError => e
          logger.error "❌ [Adjust growth read] ActiveRecord error: #{e.message}"
          raise
        end

        private

        def snapshots_from_plan(cultivation_plan)
          cultivation_plan.cultivation_plan_crops.filter_map do |plan_crop|
            crop = plan_crop.crop
            next if crop.nil?

            Domain::CultivationPlan::Dtos::CultivationPlanAdjustPlanCropGrowthSnapshot.new(
              crop_name: crop.name,
              growth_stage_count: crop.crop_stages.size
            )
          end
        end
      end
    end
  end
end
