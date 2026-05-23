# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropUpdateHtmlPresenter < Domain::Crop::Ports::CropUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crop_entity)
          @view.redirect_to @view.crop_path(crop_entity.id), notice: I18n.t("crops.flash.updated")
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.flash[:alert] = I18n.t("crops.flash.no_permission")
            @view.redirect_to @view.crops_path
            return
          end

          if error_dto.is_a?(Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure)
            @view.redirect_to @view.crop_path(error_dto.resource_id), alert: error_dto.message
            return
          end

          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s

          @view.flash.now[:alert] = msg
          if error_dto.is_a?(Domain::Crop::Dtos::CropMasterFormFailure)
            @view.instance_variable_set(:@crop, Forms::CropMasterForm.from_snapshot(error_dto.master_form_snapshot))
          end
          @view.render_form(:edit, status: :unprocessable_entity)
        end
      end
    end
  end
end
