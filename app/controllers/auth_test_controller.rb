# frozen_string_literal: true

class AuthTestController < ApplicationController
  # Skip authentication for test endpoints
  skip_before_action :authenticate_user!, only: [ :mock_login, :mock_login_as, :mock_logout ]

  # Only available in development and test
  before_action :ensure_development_or_test, only: [ :mock_login, :mock_login_as, :mock_logout ]

  def mock_login
    # Default developer login
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
    presenter = Presenters::Html::Auth::AuthTestLogoutHtmlPresenter.new(view: self)
    Domain::Auth::Interactors::AuthUserLogoutInteractor.new(
      output_port: presenter,
      session_revocation_gateway: CompositionRoot.user_session_revocation_gateway
    ).call(authenticated: logged_in?, user_id: current_user.id)
  end

  public

  def auth_test_clear_session_cookies!
    cookies.delete(:session_id)
    cookies.delete(:session_id, path: "/")
    cookie_domain = if request.respond_to?(:cookie_domain, true)
      request.cookie_domain.presence
    end
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

    return_to = params[:return_to].presence || session.delete(:return_to)
    pending_allowed = return_to.present? && allowed_return_to?(return_to)
    stashed = session[:public_plan_save_data].present?

    input = Domain::Auth::Dtos::AuthTestMockLoginInputDto.new(
      google_id: auth_hash["uid"],
      email: auth_hash.dig("info", "email"),
      name: auth_hash.dig("info", "name"),
      avatar_source_url: auth_hash.dig("info", "image").to_s,
      grant_admin: [ :google_oauth2, :developer ].include?(auth_key),
      stashed_public_plan: stashed,
      pending_return_to: return_to,
      pending_return_to_allowed: pending_allowed
    )

    presenter = Presenters::Html::Auth::AuthTestMockLoginHtmlPresenter.new(view: self)
    Domain::Auth::Interactors::AuthTestMockLoginInteractor.new(
      output_port: presenter,
      gateway: CompositionRoot.auth_test_login_gateway,
      oauth_url_appender: CompositionRoot.oauth_conversion_url_appender
    ).call(
      input_dto: input,
      environment_allowed: Rails.env.development? || Rails.env.test?
    )
  end

  def allowed_return_to?(url)
    return false if url.blank?
    uri = URI.parse(url)
    return false unless %w[http https].include?(uri.scheme)
    origin = build_origin(uri)
    allowed = ENV.fetch("FRONTEND_URL", "http://localhost:4200").split(",").map(&:strip).reject(&:empty?)
    allowed_origins = allowed.filter_map { |base| build_origin(URI.parse(base)) rescue nil }
    allowed_origins.include?(origin)
  rescue URI::InvalidURIError
    false
  end

  def build_origin(uri)
    "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if uri.port && uri.port != uri.default_port}"
  end

  def ensure_development_or_test
    unless Rails.env.development? || Rails.env.test?
      redirect_to root_path(locale: I18n.default_locale), alert: I18n.t("auth_test.env_only")
    end
  end
end
