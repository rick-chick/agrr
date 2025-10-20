# frozen_string_literal: true

class AuthController < ApplicationController
  layout 'auth', only: [:login]
  
  # Skip CSRF protection for OAuth endpoints
  skip_before_action :verify_authenticity_token, only: [:google_oauth2_callback, :failure]
  
  # Public endpoints
  skip_before_action :authenticate_user!, only: [:login, :google_oauth2_callback, :failure]
  
  # Production環境では認証機能を無効化
  before_action :check_production_environment

  def login
    # Display login page with Google OAuth button
  end

  # /auth/google_oauth2 is handled by OmniAuth middleware, no action needed

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
        # Create session
        session = Session.create_for_user(user)
        cookies[:session_id] = {
          value: session.session_id,
          expires: session.expires_at,
          httponly: true,
          secure: Rails.env.production?,
          same_site: :strict
        }
        
        redirect_to root_path, notice: I18n.t('auth.flash.login_success')
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
      
      # Clear session cookie
      cookies.delete(:session_id)
      
      redirect_to auth_login_path, notice: I18n.t('auth.flash.logout_success')
    else
      redirect_to auth_login_path, alert: I18n.t('auth.flash.not_logged_in')
    end
  end

  private
  
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
end

