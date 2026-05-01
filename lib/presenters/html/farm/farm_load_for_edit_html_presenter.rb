# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmLoadForEditHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(farm)
          @view.instance_variable_set(:@farm, farm)
        end

        def on_failure
          @view.redirect_to @view.farms_path, alert: I18n.t("farms.flash.not_found")
        end
      end
    end
  end
end
