# frozen_string_literal: true

module Presenters
  module Api
    module Crop
      class CropListPresenter < Domain::Crop::Ports::CropListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crops)
          json = crops.is_a?(Array) ? crops.map { |e| entity_to_json(e) } : []
          @view.render_response(json: json, status: :ok)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.render_response(json: { error: msg }, status: :unprocessable_entity)
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
