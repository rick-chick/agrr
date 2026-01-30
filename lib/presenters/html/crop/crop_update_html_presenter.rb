# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropUpdateHtmlPresenter < Domain::Crop::Ports::CropUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crop_entity)
          @view.redirect_to @view.crop_path(crop_entity.id), notice: I18n.t('crops.flash.updated')
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          # @crop はコントローラでセットされている前提
          @view.render_form(:edit, status: :unprocessable_entity)
        end
      end
    end
  end
end