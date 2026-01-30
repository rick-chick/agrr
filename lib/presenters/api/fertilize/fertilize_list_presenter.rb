# frozen_string_literal: true

module Presenters
  module Api
    module Fertilize
      class FertilizeListPresenter < Domain::Fertilize::Ports::FertilizeListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(fertilizes)
          json = fertilizes.is_a?(Array) ? fertilizes.map { |e| entity_to_json(e) } : []
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
            n: entity.n,
            p: entity.p,
            k: entity.k,
            description: entity.description,
            package_size: entity.package_size,
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
