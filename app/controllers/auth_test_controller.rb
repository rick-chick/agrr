# frozen_string_literal: true

class AuthTestController < ApplicationController
  # Skip authentication for test endpoints
  skip_before_action :authenticate_user!, only: [:mock_login, :mock_login_as, :mock_logout]
  
  # Only available in development and test
  before_action :ensure_development_or_test, only: [:mock_login, :mock_login_as, :mock_logout]
  
  def mock_login
    # Default developer login
    mock_login_as_user(:google_oauth2)
  end
  
  def mock_login_as
    user_type = params[:user]
    case user_type
    when 'developer'
      mock_login_as_user(:developer)
    when 'farmer'
      mock_login_as_user(:google_oauth2_farmer)
    when 'researcher'
      mock_login_as_user(:google_oauth2_researcher)
    else
      redirect_to root_path(locale: I18n.default_locale), alert: I18n.t('auth_test.invalid_user_type')
    end
  end
  
  def mock_logout
    if current_user
      current_user.sessions.destroy_all
      # Robustly clear session cookie for development/test parity with production behavior
      cookies.delete(:session_id)
      cookies.delete(:session_id, path: '/')
      begin
        cookie_domain = request.cookie_domain.presence
      rescue NoMethodError
        cookie_domain = nil
      end
      if cookie_domain
        cookies.delete(:session_id, domain: cookie_domain, path: '/')
      end
      cookies.delete(:session_id, domain: :all, path: '/')
      redirect_to root_path(locale: I18n.default_locale), notice: I18n.t('auth_test.mock_logout_success')
    else
      redirect_to root_path(locale: I18n.default_locale), alert: I18n.t('auth_test.not_logged_in')
    end
  end
  
  private
  
  def mock_login_as_user(auth_key)
    # Get mock auth data
    auth_hash = OmniAuth.config.mock_auth[auth_key]
    
    # Handle missing mock data gracefully
    unless auth_hash.present? && auth_hash['info'].present?
      redirect_to root_path(locale: I18n.default_locale), alert: I18n.t('auth_test.mock_data_missing')
      return
    end
    
    # Process avatar URL using User model's method
    # This converts '/assets/dev-avatar.svg' to 'dev-avatar.svg'
    processed_avatar_url = User.process_avatar_url(auth_hash['info']['image'])
    
    # Create or find user
    user = User.find_or_create_by(google_id: auth_hash['uid']) do |u|
      u.email = auth_hash['info']['email']
      u.name = auth_hash['info']['name']
      u.avatar_url = processed_avatar_url
      # 開発者（developer）は管理者権限を付与
      u.admin = [:google_oauth2, :developer].include?(auth_key)
    end
    
    # 既存ユーザーの場合も管理者権限を更新
    if user.persisted? && [:google_oauth2, :developer].include?(auth_key) && !user.admin?
      user.update!(admin: true)
    end
    
    # Check if user was successfully persisted
    unless user.persisted?
      redirect_to root_path(locale: I18n.default_locale), alert: I18n.t('auth_test.create_user_failed', errors: user.errors.full_messages.join(', '))
      return
    end
    
    # Create user session (avoid shadowing Rails session hash)
    user_session = Session.create_for_user(user)
    cookies[:session_id] = {
      value: user_session.session_id,
      expires: user_session.expires_at,
      httponly: true,
      secure: false, # Development only
      same_site: :lax
    }

    # If user came from public_plans save flow, continue that flow
    if session[:public_plan_save_data]
      redirect_to process_saved_plan_public_plans_path and return
    end

    # Redirect back to frontend (e.g. Angular 4200) if return_to from params or session
    return_to = params[:return_to].presence || session.delete(:return_to)
    if return_to.present? && allowed_return_to?(return_to)
      redirect_to return_to, allow_other_host: true, notice: I18n.t('auth_test.mock_login_success', name: user.name)
    else
      redirect_to root_path(locale: I18n.default_locale), notice: I18n.t('auth_test.mock_login_success', name: user.name)
    end
  end

  def allowed_return_to?(url)
    return false if url.blank?
    uri = URI.parse(url)
    return false unless %w[http https].include?(uri.scheme)
    origin = build_origin(uri)
    allowed = ENV.fetch('FRONTEND_URL', 'http://localhost:4200').split(',').map(&:strip).reject(&:empty?)
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
      redirect_to root_path(locale: I18n.default_locale), alert: I18n.t('auth_test.env_only')
    end
  end
end
