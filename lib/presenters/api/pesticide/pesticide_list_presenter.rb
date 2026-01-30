# frozen_string_literal: true

module Presenters
  module Api
    module Pesticide
      class PesticideListPresenter < Domain::Pesticide::Ports::PesticideListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pesticides)
          json = pesticides.is_a?(Array) ? pesticides.map { |e| entity_to_json(e) } : []
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
            active_ingredient: entity.active_ingredient,
            description: entity.description,
            crop_id: entity.crop_id,
            pest_id: entity.pest_id,
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
