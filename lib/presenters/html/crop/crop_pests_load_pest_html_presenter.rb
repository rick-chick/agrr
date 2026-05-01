# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropPestsLoadPestHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(pest)
          @view.instance_variable_set(:@pest, pest)
        end

        def on_not_found(crop)
          @view.redirect_to @view.crop_pests_path(crop), alert: I18n.t("crops.pests.flash.not_found")
        end
      end
    end
  end
end
