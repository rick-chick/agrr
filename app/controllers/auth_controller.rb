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
        redirect_to auth_failure_path, alert: 'Authentication failed. No data received.'
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
        
        redirect_to root_path, notice: 'Successfully logged in!'
      else
        redirect_to auth_failure_path, alert: 'Failed to create user account.'
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "OAuth callback error: #{e.message}"
      redirect_to auth_failure_path, alert: 'Invalid user data received from Google.'
    rescue StandardError => e
      Rails.logger.error "OAuth callback error: #{e.message}"
      redirect_to auth_failure_path, alert: 'An unexpected error occurred during authentication.'
    end
  end

  def failure
    error_message = params[:message] || 'Authentication failed. Please try again.'
    redirect_to auth_login_path, alert: error_message
  end

  def logout
    if current_user
      # Destroy all sessions for the user
      current_user.sessions.destroy_all
      
      # Clear session cookie
      cookies.delete(:session_id)
      
      redirect_to auth_login_path, notice: 'Logged out successfully.'
    else
      redirect_to auth_login_path, alert: 'You are not logged in.'
    end
  end

  private
  
  def check_production_environment
    if Rails.env.production?
      if request.format.json?
        render json: { error: 'Authentication is disabled in production environment.' }, status: :forbidden
      else
        redirect_to root_path, alert: 'Authentication is disabled in production environment.'
      end
    end
  end

  def auth_failure_path
    '/auth/failure'
  end
end

