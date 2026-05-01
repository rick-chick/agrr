# frozen_string_literal: true

module Presenters
  module Html
    module Pest
      class PestLoadForEditHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(pest)
          @view.instance_variable_set(:@pest, pest)
        end

        def on_failure(reason)
          alert = case reason
          when :no_permission
            I18n.t("pests.flash.no_permission")
          else
            I18n.t("pests.flash.not_found")
          end
          @view.redirect_to @view.pests_path, alert: alert
        end
      end
    end
  end
end
