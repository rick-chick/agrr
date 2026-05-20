# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      module Html
        class CropPestsLoadCropHtmlPresenter
          def initialize(view:)
            @view = view
          end

          def on_success(crop)
            @view.instance_variable_set(:@crop, crop)
          end

          def on_failure(reason)
            alert = reason == :no_permission ? I18n.t("crops.flash.no_permission") : I18n.t("crops.flash.not_found")
            @view.redirect_to @view.crops_path, alert: alert
          end
        end
      end
    end
  end
end
