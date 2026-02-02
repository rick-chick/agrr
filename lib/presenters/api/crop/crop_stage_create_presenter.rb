# frozen_string_literal: true

module Presenters
  module Api
    module Crop
      class CropStageCreatePresenter < Domain::Crop::Ports::CropStageCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crop_stage_output_dto)
          stage = crop_stage_output_dto.stage
          json = {
            id: stage.id,
            crop_id: stage.crop_id,
            name: stage.name,
            order: stage.order,
            created_at: stage.created_at,
            updated_at: stage.updated_at
          }
          @view.render_response(json: json, status: :created)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.render_response(json: { errors: [msg] }, status: :unprocessable_entity)
        end
      end
    end
  end
end