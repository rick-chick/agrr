# frozen_string_literal: true

module Api
  module Crop
    class CropStageUpdatePresenter < Domain::Crop::Ports::CropStageUpdateOutputPort
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
        stage = dto.stage
        {
          id: stage.id,
          crop_id: stage.crop_id,
          name: stage.name,
          order: stage.order
        }
      end
    end
  end
end