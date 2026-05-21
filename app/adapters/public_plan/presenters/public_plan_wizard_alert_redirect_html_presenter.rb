# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      # 公開プランウィザード用: 単純な redirect + I18n アラート
      class PublicPlanWizardAlertRedirectHtmlPresenter
        def initialize(view:, path_helper:)
          @view = view
          @path_helper = path_helper
        end

        def redirect(alert_i18n_key:)
          @view.redirect_to @view.send(@path_helper), alert: I18n.t(alert_i18n_key)
        end
      end
    end
  end
end
