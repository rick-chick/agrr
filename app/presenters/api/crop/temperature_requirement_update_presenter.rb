# frozen_string_literal: true

# frozen_string_literal: true

module Api
  module Crop
    class TemperatureRequirementUpdatePresenter < Domain::Crop::Ports::TemperatureRequirementUpdateOutputPort
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
          base_temperature: requirement.base_temperature,
          optimal_min: requirement.optimal_min,
          optimal_max: requirement.optimal_max,
          low_stress_threshold: requirement.low_stress_threshold,
          high_stress_threshold: requirement.high_stress_threshold,
          frost_threshold: requirement.frost_threshold,
          sterility_risk_threshold: requirement.sterility_risk_threshold,
          max_temperature: requirement.max_temperature
        }
      end
    end
  end
end