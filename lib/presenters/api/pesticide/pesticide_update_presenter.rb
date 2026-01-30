# frozen_string_literal: true

module Presenters
  module Api
    module Pesticide
      class PesticideUpdatePresenter < Domain::Pesticide::Ports::PesticideUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pesticide_entity)
          json = {
            id: pesticide_entity.id,
            user_id: pesticide_entity.user_id,
            name: pesticide_entity.name,
            active_ingredient: pesticide_entity.active_ingredient,
            description: pesticide_entity.description,
            crop_id: pesticide_entity.crop_id,
            pest_id: pesticide_entity.pest_id,
            region: pesticide_entity.region,
            is_reference: pesticide_entity.is_reference,
            created_at: pesticide_entity.created_at,
            updated_at: pesticide_entity.updated_at
          }
          @view.render_response(json: json, status: :ok)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          status = (msg == I18n.t('pesticides.flash.no_permission')) ? :forbidden : ((msg == 'Pesticide not found') ? :not_found : :unprocessable_entity)
          json = (status == :not_found || status == :forbidden) ? { error: msg } : { errors: [msg] }
          @view.render_response(json: json, status: status)
        end
      end
    end
  end
end
