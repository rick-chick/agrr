# frozen_string_literal: true

module Presenters
  module Html
    module Crop
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

          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          if msg == I18n.t("crops.flash.reference_flag_admin_only")
            @view.redirect_to @view.crop_path(@view.params[:id]), alert: msg
            return
          end

          @view.flash.now[:alert] = msg
          @view.after_crop_update_failure
          @view.render_form(:edit, status: :unprocessable_entity)
        end
      end
    end
  end
end
