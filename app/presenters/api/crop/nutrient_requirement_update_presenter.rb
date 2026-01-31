# frozen_string_literal: true

module Api
  module Crop
    class NutrientRequirementUpdatePresenter < Domain::Crop::Ports::NutrientRequirementUpdateOutputPort
      def initialize(view:)
        @view = view
      end

      def on_success(success_dto)
        @view.render_response(
          json: serialize_success(success_dto),
          status: :ok
        )
      end

      def on_failure(failure_dto)
        error_message = failure_dto.respond_to?(:message) ? failure_dto.message : failure_dto.to_s
        @view.render_response(
          json: { error: error_message },
          status: :unprocessable_entity
        )
      end

      private

      def serialize_success(dto)
        requirement = dto.requirement
        {
          id: requirement.id,
          crop_stage_id: requirement.crop_stage_id,
          daily_uptake_n: requirement.daily_uptake_n,
          daily_uptake_p: requirement.daily_uptake_p,
          daily_uptake_k: requirement.daily_uptake_k,
          region: requirement.region
        }
      end
    end
  end
end