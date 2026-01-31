# frozen_string_literal: true

module Api
  module Crop
    class SunshineRequirementUpdatePresenter < Domain::Crop::Ports::SunshineRequirementUpdateOutputPort
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
          minimum_sunshine_hours: requirement.minimum_sunshine_hours,
          target_sunshine_hours: requirement.target_sunshine_hours
        }
      end
    end
  end
end