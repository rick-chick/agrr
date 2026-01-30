# frozen_string_literal: true

module Presenters
  module Api
    module Pest
      class PestCreatePresenter < Domain::Pest::Ports::PestCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pest_entity)
          json = {
            id: pest_entity.id,
            user_id: pest_entity.user_id,
            name: pest_entity.name,
            name_scientific: pest_entity.name_scientific,
            family: pest_entity.family,
            order: pest_entity.order,
            description: pest_entity.description,
            occurrence_season: pest_entity.occurrence_season,
            region: pest_entity.region,
            is_reference: pest_entity.is_reference,
            created_at: pest_entity.created_at,
            updated_at: pest_entity.updated_at
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
