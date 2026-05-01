# frozen_string_literal: true

module Presenters
  module Html
    module Fertilize
      class FertilizeLoadForViewHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(bundle)
          @view.instance_variable_set(:@fertilize, bundle.persisted_fertilize)
        end

        def on_permission_denied
          @view.redirect_to @view.fertilizes_path, alert: I18n.t("fertilizes.flash.no_permission")
        end

        def on_not_found
          @view.redirect_to @view.fertilizes_path, alert: I18n.t("fertilizes.flash.not_found")
        end
      end
    end
  end
end
