# frozen_string_literal: true

module Presenters
  module Api
    module Crop
      class CropStageDeletePresenter < Domain::Crop::Ports::CropStageDeleteOutputPort
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
          { success: dto.success }
        end
      end
    end
  end
end