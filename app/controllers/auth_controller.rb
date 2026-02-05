# frozen_string_literal: true

class AuthController < ApplicationController
  layout 'auth', only: [:login]
  
  # Skip CSRF protection for OAuth endpoints
  skip_before_action :verify_authenticity_token, only: [:google_oauth2_callback, :failure]
  
  # Public endpoints
  skip_before_action :authenticate_user!, only: [:login, :google_oauth2_callback, :failure]
  
  # Production環境での認証機能制限を解除
  # before_action :check_production_environment

  def login
    # Store return_to for redirect after OAuth (e.g. Angular dev server at 4200)
    if params[:return_to].present?
      return_to = params[:return_to].strip
      session[:return_to] = return_to if allowed_return_to?(return_to)
    end

    # Check if Google OAuth is properly configured
    unless ENV['GOOGLE_CLIENT_ID'].present? && ENV['GOOGLE_CLIENT_SECRET'].present?
      Rails.logger.error "🚨 Google OAuth not configured for login attempt"
      Rails.logger.error "   GOOGLE_CLIENT_ID: #{ENV['GOOGLE_CLIENT_ID'].present? ? 'SET (value exists)' : 'NOT SET or EMPTY'}"
      Rails.logger.error "   GOOGLE_CLIENT_SECRET: #{ENV['GOOGLE_CLIENT_SECRET'].present? ? 'SET (value exists)' : 'NOT SET or EMPTY'}"
      Rails.logger.error "   Environment: #{Rails.env}"
      flash[:alert] = I18n.t('auth.flash.oauth_not_configured', default: 'Google OAuth認証が設定されていません。管理者にお問い合わせください。')
    end
    # Display login page with Google OAuth button
  end

  # Google OAuth2 initiation - handled by OmniAuth middleware
  def google_oauth2
    # This should not be reached as OmniAuth middleware handles /auth/google_oauth2
    # If reached, there's a configuration issue
    Rails.logger.error "🚨 OAuth: google_oauth2 action reached - OmniAuth middleware not working"
    redirect_to auth_login_path, alert: 'OAuth認証の設定に問題があります。'
  end

  def google_oauth2_callback
    begin
      # Get auth hash from OmniAuth
      auth_hash = request.env['omniauth.auth']
      
      if auth_hash.nil?
        redirect_to auth_failure_path, alert: I18n.t('auth.flash.no_data')
        return
      end

      # Find or create user
      user = User.from_omniauth(auth_hash)
      
      if user.persisted?
        # Create session (avoid shadowing Rails session hash)
        user_session = Session.create_for_user(user)
        cookies[:session_id] = {
          value: user_session.session_id,
          expires: user_session.expires_at,
          httponly: true,
          secure: Rails.env.production?,
          same_site: :lax
        }

        # Continue saved-plan flow if present
        if session[:public_plan_save_data]
          redirect_to process_saved_plan_public_plans_path and return
        end

        # Redirect back to frontend (e.g. Angular 4200) if return_to was set
        if session[:return_to].present?
          return_to = session.delete(:return_to)
          redirect_to return_to, allow_other_host: true, notice: I18n.t('auth.flash.login_success')
        else
          redirect_to root_path, notice: I18n.t('auth.flash.login_success')
        end
      else
        redirect_to auth_failure_path, alert: I18n.t('auth.flash.create_user_failed')
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "OAuth callback error: #{e.message}"
      redirect_to auth_failure_path, alert: I18n.t('auth.flash.invalid_data')
    rescue StandardError => e
      Rails.logger.error "OAuth callback error: #{e.message}"
      redirect_to auth_failure_path, alert: I18n.t('auth.flash.unexpected_error')
    end
  end

  def failure
    error_message = params[:message] || I18n.t('auth.flash.authentication_failed')
    redirect_to auth_login_path, alert: error_message
  end

  def logout
    if current_user
      # Destroy all sessions for the user
      current_user.sessions.destroy_all
      
      # Clear session cookie (ensure deletion in production as well)
      clear_session_cookie
      
      redirect_to auth_login_path, notice: I18n.t('auth.flash.logout_success')
    else
      redirect_to auth_login_path, alert: I18n.t('auth.flash.not_logged_in')
    end
  end

  private
  
  # Delete session cookie robustly across environments and domains
  def clear_session_cookie
    # Default deletion (matches cookies set without domain/path)
    cookies.delete(:session_id)
    
    # Ensure deletion when a domain/path is involved (some proxies/CDNs alter host)
    begin
      cookie_domain = request.cookie_domain.presence
    rescue NoMethodError
      cookie_domain = nil
    end
    
    # Try explicit path root
    cookies.delete(:session_id, path: '/')
    
    # Try with current host domain if available
    if cookie_domain
      cookies.delete(:session_id, domain: cookie_domain, path: '/')
    end
    
    # Also try wildcard domain deletion for subdomain cookies
    cookies.delete(:session_id, domain: :all, path: '/')
  end
  
  def check_production_environment
    if Rails.env.production?
      if request.format.json?
        render json: { error: I18n.t('auth.flash.disabled_in_production_json') }, status: :forbidden
      else
        redirect_to root_path, alert: I18n.t('auth.flash.disabled_in_production')
      end
    end
  end

  def auth_failure_path
    '/auth/failure'
  end

  def allowed_return_to?(url)
    return false if url.blank?
    uri = URI.parse(url)
    return false unless %w[http https].include?(uri.scheme)
    origin = build_origin(uri)

    allowed_origins = frontend_allowed_origins
    return true if allowed_origins.include?(origin)
    return true if matches_request_origin?(origin)
    return true if matches_allowed_host?(uri.host)

    false
  rescue URI::InvalidURIError
    false
  end

  def frontend_allowed_origins
    allowed = ENV.fetch('FRONTEND_URL', 'http://localhost:4200').split(',').map(&:strip).reject(&:empty?)
    allowed.filter_map { |base| build_origin(URI.parse(base)) rescue nil }
  end

  def matches_request_origin?(origin)
    request_base = URI.parse(request.base_url)
    build_origin(request_base) == origin
  rescue URI::InvalidURIError
    false
  end

  def matches_allowed_host?(host)
    return false unless host.present?
    allowed = ENV.fetch('ALLOWED_HOSTS', '').split(',').map(&:strip).reject(&:empty?)
    allowed.any? { |allowed_host| host_match?(host, allowed_host) }
  end

  def host_match?(host, allowed_host)
    return false unless host.present? && allowed_host.present?

    normalized = allowed_host.strip
    if normalized.start_with?('.')
      host.end_with?(normalized.delete_prefix('.'))
    else
      host.casecmp?(normalized)
    end
  end

  def build_origin(uri)
    "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if uri.port && uri.port != uri.default_port}"
  end
end

