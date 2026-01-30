# frozen_string_literal: true

module Presenters
  module Api
    module Farm
      class FarmListPresenter < Domain::Farm::Ports::FarmListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farms)
          json = farms.is_a?(Array) ? farms.map { |e| entity_to_json(e) } : []
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
            latitude: entity.latitude,
            longitude: entity.longitude,
            region: entity.region,
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
