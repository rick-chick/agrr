# frozen_string_literal: true

module Presenters
  module Api
    module Pest
      class PestListPresenter < Domain::Pest::Ports::PestListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pests)
          json = pests.is_a?(Array) ? pests.map { |e| entity_to_json(e) } : []
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
            user_id: entity.user_id,
            name: entity.name,
            name_scientific: entity.name_scientific,
            family: entity.family,
            order: entity.order,
            description: entity.description,
            occurrence_season: entity.occurrence_season,
            region: entity.region,
            is_reference: entity.is_reference,
            created_at: entity.created_at,
            updated_at: entity.updated_at
          }
        end
      end
    end
  end
end
