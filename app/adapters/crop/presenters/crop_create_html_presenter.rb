# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropCreateHtmlPresenter < Domain::Crop::Ports::CropCreateOutputPort
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

          @view.flash.now[:alert] = msg
          @view.after_crop_create_failure
          @view.render_form(:new, status: :unprocessable_entity)
        end
      end
    end
  end
end
