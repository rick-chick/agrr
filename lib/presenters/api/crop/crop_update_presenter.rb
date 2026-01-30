# frozen_string_literal: true

module Presenters
  module Api
    module Crop
      class CropUpdatePresenter < Domain::Crop::Ports::CropUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crop_entity)
          json = {
            id: crop_entity.id,
            name: crop_entity.name,
            variety: crop_entity.variety,
            area_per_unit: crop_entity.area_per_unit,
            revenue_per_area: crop_entity.revenue_per_area,
            region: crop_entity.region,
            groups: crop_entity.groups,
            user_id: crop_entity.user_id,
            created_at: crop_entity.created_at,
            updated_at: crop_entity.updated_at,
            is_reference: crop_entity.is_reference
          }
          @view.render_response(json: json, status: :ok)
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.render_response(json: { error: I18n.t('crops.flash.no_permission') }, status: :forbidden)
            return
          end

          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          status = (msg == 'Crop not found') ? :not_found : :unprocessable_entity
          json = (status == :not_found) ? { error: msg } : { errors: [msg] }
          @view.render_response(json: json, status: status)
        end
      end
    end
  end
end
