# frozen_string_literal: true

module Presenters
  module Api
    module Farm
      class FarmDetailPresenter < Domain::Farm::Ports::FarmDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farm_detail_dto)
          farm_json = entity_to_json(farm_detail_dto.farm)
          fields_json = farm_detail_dto.fields.map { |e| field_entity_to_json(e) }
          # API 契約: Response (200) は Farm（トップレベルに farm 属性 + fields）
          @view.render_response(json: farm_json.merge(fields: fields_json), status: :ok)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.render_response(json: { error: msg }, status: :not_found)
        end

        private

        def entity_to_json(entity)
          {
            id: entity.id,
            name: entity.name,
            latitude: entity.latitude,
            longitude: entity.longitude,
            region: entity.region,
            user_id: entity.user_id,
            created_at: entity.created_at,
            updated_at: entity.updated_at,
            is_reference: entity.is_reference
          }
        end

        def field_entity_to_json(entity)
          {
            id: entity.id,
            name: entity.name,
            area: entity.area,
            daily_fixed_cost: entity.daily_fixed_cost,
            region: entity.region,
            farm_id: entity.farm_id,
            user_id: entity.user_id,
            created_at: entity.created_at,
            updated_at: entity.updated_at
          }
        end
      end
    end
  end
end
