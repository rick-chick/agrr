# frozen_string_literal: true

module Adapters
  module Fertilize
    module Presenters
      module Api
        class FertilizeDetailPresenter < Domain::Fertilize::Ports::FertilizeDetailOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(fertilize_detail_dto)
            json = entity_to_json(fertilize_detail_dto.display_dto)
            @view.render_response(json: json, status: :ok)
          end

          def on_failure(error_dto)
            if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
              @view.render_response(
                json: { error: I18n.t("fertilizes.flash.no_permission") },
                status: :forbidden
              )
              return
            end

            msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
            not_found_msg = I18n.t("fertilizes.flash.not_found")
            status = if msg == not_found_msg || msg == "Fertilize not found"
              :not_found
            else
              :unprocessable_entity
            end
            @view.render_response(json: { error: msg }, status: status)
          end

          private

          def entity_to_json(entity)
            {
              id: entity.id,
              user_id: entity.respond_to?(:user_id) ? entity.user_id : nil,
              name: entity.name,
              n: entity.n,
              p: entity.p,
              k: entity.k,
              description: entity.description,
              package_size: entity.package_size,
              region: entity.respond_to?(:region) ? entity.region : nil,
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
