# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropCreateHtmlPresenter < Domain::Crop::Ports::CropCreateOutputPort
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        def on_success(crop_entity)
          @view.redirect_to @view.crop_path(crop_entity.id), notice: I18n.t("crops.flash.created")
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          if msg == I18n.t("crops.flash.reference_only_admin")
            @view.redirect_to @view.crops_path, alert: msg
            return
          end

          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.crops_path,
                               alert: I18n.t("crops.flash.no_permission")
            return
          end

          if error_dto.is_a?(Domain::Crop::Dtos::CropCreateLimitExceededFailure)
            @view.redirect_to @view.crops_path, alert: error_dto.message
            return
          end

          @view.redirect_to @view.crops_path, alert: msg
        end
      end
    end
  end
end
