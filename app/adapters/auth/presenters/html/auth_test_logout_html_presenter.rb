# frozen_string_literal: true

module Adapters
  module Auth
    module Presenters
      module Html
        class AuthTestLogoutHtmlPresenter
          include Domain::Auth::Ports::AuthUserLogoutOutputPort

          def initialize(view:)
            @view = view
          end

          def on_success
            @view.auth_test_clear_session_cookies!
            @view.redirect_to @view.root_path(locale: I18n.default_locale), notice: I18n.t("auth_test.mock_logout_success")
          end

          def on_not_logged_in
            @view.redirect_to @view.root_path(locale: I18n.default_locale), alert: I18n.t("auth_test.not_logged_in")
          end
        end
      end
    end
  end
end
