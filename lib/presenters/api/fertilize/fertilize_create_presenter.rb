# frozen_string_literal: true

module Presenters
  module Api
    module Fertilize
      class FertilizeCreatePresenter < Domain::Fertilize::Ports::FertilizeCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(fertilize_entity)
          json = {
            id: fertilize_entity.id,
            user_id: fertilize_entity.user_id,
            name: fertilize_entity.name,
            n: fertilize_entity.n,
            p: fertilize_entity.p,
            k: fertilize_entity.k,
            description: fertilize_entity.description,
            package_size: fertilize_entity.package_size,
            region: fertilize_entity.region,
            is_reference: fertilize_entity.is_reference,
            created_at: fertilize_entity.created_at,
            updated_at: fertilize_entity.updated_at
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
