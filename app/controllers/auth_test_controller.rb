# frozen_string_literal: true

class AuthTestController < ApplicationController
  before_action :ensure_development_or_test, only: [ :mock_login, :mock_login_as, :mock_logout ]

  def mock_login
    mock_login_as_user(:google_oauth2)
  end

  def mock_login_as
    user_type = params[:user]
    case user_type
    when "developer"
      mock_login_as_user(:developer)
    when "farmer"
      mock_login_as_user(:google_oauth2_farmer)
    when "researcher"
      mock_login_as_user(:google_oauth2_researcher)
    else
      redirect_to root_path(locale: I18n.default_locale), alert: I18n.t("auth_test.invalid_user_type")
    end
  end

  def mock_logout
    presenter = Adapters::Auth::Presenters::AuthTestLogoutHtmlPresenter.new(view: self)
    if logged_in?
      CompositionRoot.user_session_revocation_gateway.delete_all_sessions_for_user!(user_id: current_user.id)
      presenter.on_success
    else
      presenter.on_not_logged_in
    end
  end

  public

  def auth_test_clear_session_cookies!
    cookies.delete(:session_id)
    cookies.delete(:session_id, path: "/")
    cookie_domain = request.cookie_domain.presence if request.respond_to?(:cookie_domain, true)
    cookies.delete(:session_id, domain: cookie_domain, path: "/") if cookie_domain
    cookies.delete(:session_id, domain: :all, path: "/")
  end

  def auth_test_assign_session_cookie!(session_id:, expires_at:)
    cookies[:session_id] = {
      value: session_id,
      expires: expires_at,
      httponly: true,
      secure: false,
      same_site: :lax
    }
  end

  private

  def mock_login_as_user(auth_key)
    auth_hash = OmniAuth.config.mock_auth[auth_key]

    unless auth_hash.present? && auth_hash["info"].present?
      redirect_to root_path(locale: I18n.default_locale), alert: I18n.t("auth_test.mock_data_missing")
      return
    end

    unless Rails.env.development? || Rails.env.test?
      redirect_to root_path(locale: I18n.default_locale), alert: I18n.t("auth_test.env_only")
      return
    end

    return_to = params[:return_to].presence || session.delete(:return_to)
    pending_allowed = return_to.present? && Adapters::Auth::SpaAuthRedirect.allowed_return_to?(
      return_to,
      request_base_url: request.base_url
    )
    stashed = session[:public_plan_save_data].present?

    input = Adapters::Auth::AuthTestMockLoginInput.new(
      google_id: auth_hash["uid"],
      email: auth_hash.dig("info", "email"),
      name: auth_hash.dig("info", "name"),
      avatar_source_url: auth_hash.dig("info", "image").to_s,
      grant_admin: [ :google_oauth2, :developer ].include?(auth_key),
      stashed_public_plan: stashed,
      pending_return_to: return_to,
      pending_return_to_allowed: pending_allowed
    )

    if input.google_id.blank?
      redirect_to root_path(locale: I18n.default_locale), alert: I18n.t("auth_test.mock_data_missing")
      return
    end

    result = CompositionRoot.auth_test_login_gateway.persist_mock_user_and_session!(input)
    presenter = Adapters::Auth::Presenters::AuthTestMockLoginHtmlPresenter.new(view: self)

    case result.status
    when :success
      if input.stashed_public_plan
        presenter.on_success_process_saved_plan(session_id: result.session_id, expires_at: result.expires_at)
      elsif input.pending_return_to && input.pending_return_to_allowed
        url = CompositionRoot.oauth_conversion_url_appender.append(input.pending_return_to)
        presenter.on_success_return_to(
          url: url,
          session_id: result.session_id,
          expires_at: result.expires_at,
          user_name: result.user_name
        )
      else
        presenter.on_success_root(
          session_id: result.session_id,
          expires_at: result.expires_at,
          user_name: result.user_name
        )
      end
    when :user_not_persisted, :record_invalid
      presenter.on_create_failed(error_messages: Array(result.error_messages).compact)
    else
      presenter.on_create_failed(error_messages: [ "unknown" ])
    end
  end

  def ensure_development_or_test
    return if Rails.env.development? || Rails.env.test?

    redirect_to root_path(locale: I18n.default_locale), alert: I18n.t("auth_test.env_only")
  end
end
