# frozen_string_literal: true

module Presenters
  module Api
    module Farm
      class FarmCreatePresenter < Domain::Farm::Ports::FarmCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farm_entity)
          json = {
            id: farm_entity.id,
            name: farm_entity.name,
            latitude: farm_entity.latitude,
            longitude: farm_entity.longitude,
            region: farm_entity.region,
            user_id: farm_entity.user_id,
            created_at: farm_entity.created_at,
            updated_at: farm_entity.updated_at,
            is_reference: farm_entity.is_reference
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
