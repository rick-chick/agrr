# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropCreateHtmlPresenter < Domain::Crop::Ports::CropCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crop_entity)
          @view.redirect_to @view.crop_path(crop_entity.id), notice: I18n.t('crops.flash.created')
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.render_form(:new, status: :unprocessable_entity)
        end
      end
    end
  end
end