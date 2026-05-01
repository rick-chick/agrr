# frozen_string_literal: true

module Presenters
  module Html
    module Pesticide
      class PesticideLoadForViewHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(pesticide)
          @view.instance_variable_set(:@pesticide, pesticide)
        end

        def on_failure
          @view.redirect_to @view.pesticides_path, alert: I18n.t("pesticides.flash.not_found")
        end
      end
    end
  end
end
