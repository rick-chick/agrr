# frozen_string_literal: true

module Adapters
  module Auth
    module Presenters
      class AuthTestMockLoginHtmlPresenter
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
          save_data = @view.session[:public_plan_save_data]
          @view.session.delete(:public_plan_save_data)
          plan_id = save_data[:plan_id] || save_data["plan_id"]
          origin = ENV.fetch("FRONTEND_URL", "http://localhost:4200").split(",").map(&:strip).reject(&:empty?).first
          @view.redirect_to "#{origin}/public-plans/results?planId=#{plan_id}", allow_other_host: true
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
