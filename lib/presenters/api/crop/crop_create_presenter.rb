# frozen_string_literal: true

module Presenters
  module Api
    module Crop
      class CropCreatePresenter < Domain::Crop::Ports::CropCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crop_entity)
          json = {
            id: crop_entity.id,
            name: crop_entity.name,
            variety: crop_entity.variety,
            area_per_unit: crop_entity.area_per_unit,
            revenue_per_area: crop_entity.revenue_per_area,
            region: crop_entity.region,
            groups: crop_entity.groups,
            user_id: crop_entity.user_id,
            created_at: crop_entity.created_at,
            updated_at: crop_entity.updated_at,
            is_reference: crop_entity.is_reference
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
