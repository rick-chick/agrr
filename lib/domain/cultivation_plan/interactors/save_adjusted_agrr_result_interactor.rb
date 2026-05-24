# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class SaveAdjustedAgrrResultInteractor
        def initialize(save_gateway:, logger:)
          @save_gateway = save_gateway
          @logger = logger
        end

        # @param plan_id [Integer]
        # @param result [Dtos::SaveAdjustedAgrrResultInput]
        def call(plan_id:, result:)
          Policies::AdjustResultSavePolicy.validate!(result)

          context = @save_gateway.load_persist_context(plan_id: plan_id)
          bundle = Mappers::SaveAdjustedAgrrPersistMapper.build_bundle(result: result, context: context)

          @logger.info "🛠️ [Save] to_update: #{bundle.upserts.size}, to_create: #{bundle.creates.size}, " \
                        "to_delete: #{bundle.delete_field_cultivation_ids.size}"

          @save_gateway.apply_persist_bundle!(plan_id: plan_id, bundle: bundle)
        end
      end
    end
  end
end
