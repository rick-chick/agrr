# frozen_string_literal: true

module Presenters
  module Api
    module Field
      class FieldDetailPresenter < Domain::Field::Ports::FieldDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(detail_dto)
          json = entity_to_json(detail_dto.field)
          @view.render_response(json: json, status: :ok)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          status = (msg == 'Field not found') ? :not_found : :unprocessable_entity
          @view.render_response(json: { error: msg }, status: status)
        end

        private

        def entity_to_json(entity)
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
