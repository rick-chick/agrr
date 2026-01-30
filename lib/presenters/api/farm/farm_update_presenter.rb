# frozen_string_literal: true

module Presenters
  module Api
    module Farm
      class FarmUpdatePresenter < Domain::Farm::Ports::FarmUpdateOutputPort
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
          @view.render_response(json: json, status: :ok)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          status = (msg == 'Farm not found') ? :not_found : :unprocessable_entity
          json = (status == :not_found) ? { error: msg } : { errors: [msg] }
          @view.render_response(json: json, status: status)
        end
      end
    end
  end
end
