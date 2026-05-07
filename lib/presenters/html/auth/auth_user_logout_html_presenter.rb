# frozen_string_literal: true

module Presenters
  module Html
    module Auth
      class AuthUserLogoutHtmlPresenter
        include Domain::Auth::Ports::AuthUserLogoutOutputPort

        def initialize(view:)
          @view = view
        end

        def on_success
          @view.clear_session_cookie
          @view.redirect_to @view.auth_login_path, notice: I18n.t("auth.flash.logout_success")
        end

        def on_not_logged_in
          @view.redirect_to @view.auth_login_path, alert: I18n.t("auth.flash.not_logged_in")
        end
      end
    end
  end
end
