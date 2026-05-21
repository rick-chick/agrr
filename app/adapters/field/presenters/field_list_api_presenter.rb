# frozen_string_literal: true

module Adapters
  module Field
    module Presenters
      class FieldListApiPresenter < Domain::Field::Ports::FieldListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farm_fields_list)
          fields = farm_fields_list.fields
          json = fields.is_a?(Array) ? fields.map { |e| entity_to_json(e) } : []
          @view.render_response(json: json, status: :ok)
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.render_response(
              json: { error: I18n.t("fields.flash.no_permission") },
              status: :forbidden
            )
            return
          end

          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          status = case msg
          when "Farm not found" then :not_found
          when "User not found" then :unauthorized
          else :unprocessable_entity
          end
          @view.render_response(json: { error: msg }, status: status)
        end

        private

        def entity_to_json(entity)
          {
            id: entity.id,
            name: entity.name,
            area: entity.area,
            daily_fixed_cost: entity.daily_fixed_cost,
            region: entity.region,
            farm_id: entity.farm_id,
            user_id: entity.user_id,
            created_at: entity.created_at,
            updated_at: entity.updated_at
          }
        end
      end
    end
  end
end
