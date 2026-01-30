# frozen_string_literal: true

module Presenters
  module Api
    module Crop
      class CropDetailPresenter < Domain::Crop::Ports::CropDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crop_detail_dto)
          crop_json = entity_to_json(crop_detail_dto.crop)
          @view.render_response(json: crop_json, status: :ok)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          status = (msg == 'Crop not found') ? :not_found : :unprocessable_entity
          @view.render_response(json: { error: msg }, status: status)
        end

        private

        def entity_to_json(entity)
          {
            id: entity.id,
            name: entity.name,
            variety: entity.variety,
            area_per_unit: entity.area_per_unit,
            revenue_per_area: entity.revenue_per_area,
            region: entity.region,
            groups: entity.groups,
            user_id: entity.user_id,
            created_at: entity.created_at,
            updated_at: entity.updated_at,
            is_reference: entity.is_reference
          }
        end
      end
    end
  end
end
