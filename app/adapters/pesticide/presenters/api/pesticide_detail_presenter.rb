# frozen_string_literal: true

module Adapters
  module Pesticide
    module Presenters
      module Api
        class PesticideDetailPresenter < Domain::Pesticide::Ports::PesticideDetailOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(pesticide_detail_dto)
            json = entity_to_json(pesticide_detail_dto.pesticide)
            @view.render_response(json: json, status: :ok)
          end

          def on_failure(error_dto)
            if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
              @view.render_response(
                json: { error: I18n.t("pesticides.flash.no_permission") },
                status: :forbidden
              )
              return
            end

            msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
            status = (msg == "Pesticide not found") ? :not_found : :unprocessable_entity
            @view.render_response(json: { error: msg }, status: status)
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
end
