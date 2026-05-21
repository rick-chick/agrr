# frozen_string_literal: true

module Adapters
  module Auth
    module Presenters
      class AuthTestMockLoginHtmlPresenter
        include Domain::Auth::Ports::AuthTestMockLoginOutputPort

        def initialize(view:)
          @view = view
        end

        def on_environment_forbidden
          @view.redirect_to @view.root_path(locale: I18n.default_locale), alert: I18n.t("auth_test.env_only")
        end

        def on_missing_mock
          @view.redirect_to @view.root_path(locale: I18n.default_locale), alert: I18n.t("auth_test.mock_data_missing")
        end

        def on_create_failed(error_messages:)
          @view.redirect_to @view.root_path(locale: I18n.default_locale),
            alert: I18n.t("auth_test.create_user_failed", errors: error_messages.join(", "))
        end

        def on_success_process_saved_plan(session_id:, expires_at:)
          assign_session_cookie(session_id, expires_at)
          @view.redirect_to @view.process_saved_plan_public_plans_path
        end

        def on_success_return_to(url:, session_id:, expires_at:, user_name:)
          assign_session_cookie(session_id, expires_at)
          @view.redirect_to url, allow_other_host: true, notice: I18n.t("auth_test.mock_login_success", name: user_name)
        end

        def on_success_root(session_id:, expires_at:, user_name:)
          assign_session_cookie(session_id, expires_at)
          @view.redirect_to @view.root_path(locale: I18n.default_locale), notice: I18n.t("auth_test.mock_login_success", name: user_name)
        end

        private

        def assign_session_cookie(session_id, expires_at)
          @view.auth_test_assign_session_cookie!(session_id: session_id, expires_at: expires_at)
        end
      end
    end
  end
end
