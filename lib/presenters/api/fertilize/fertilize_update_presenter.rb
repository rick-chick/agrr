# frozen_string_literal: true

module Presenters
  module Api
    module Fertilize
      class FertilizeUpdatePresenter < Domain::Fertilize::Ports::FertilizeUpdateOutputPort
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
          @view.render_response(json: json, status: :ok)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          status = (msg == I18n.t('fertilizes.flash.no_permission')) ? :forbidden : ((msg == 'Fertilize not found') ? :not_found : :unprocessable_entity)
          json = (status == :not_found || status == :forbidden) ? { error: msg } : { errors: [msg] }
          @view.render_response(json: json, status: status)
        end
      end
    end
  end
end
