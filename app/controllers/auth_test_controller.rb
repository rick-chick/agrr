# frozen_string_literal: true

class AuthTestController < ApplicationController
  # Skip authentication for test endpoints
  skip_before_action :authenticate_user!, only: [:mock_login, :mock_login_as, :mock_logout]
  
  # Only available in development
  before_action :ensure_development, only: [:mock_login, :mock_login_as, :mock_logout]
  
  def mock_login
    # Default developer login
    mock_login_as_user(:google_oauth2)
  end
  
  def mock_login_as
    user_type = params[:user]
    case user_type
    when 'developer'
      mock_login_as_user(:google_oauth2)
    when 'farmer'
      mock_login_as_user(:google_oauth2_farmer)
    when 'researcher'
      mock_login_as_user(:google_oauth2_researcher)
    else
      redirect_to auth_login_path, alert: 'Invalid user type.'
    end
  end
  
  private
  
  def mock_login_as_user(auth_key)
    # Get mock auth data
    auth_hash = OmniAuth.config.mock_auth[auth_key]
    
    # Create or find user
    user = User.find_or_create_by(google_id: auth_hash['uid']) do |u|
      u.email = auth_hash['info']['email']
      u.name = auth_hash['info']['name']
      u.avatar_url = auth_hash['info']['image']
    end
    
    # Create session
    session = Session.create_for_user(user)
    cookies[:session_id] = {
      value: session.session_id,
      expires: session.expires_at,
      httponly: true,
      secure: false, # Development only
      same_site: :lax
    }
    
    redirect_to root_path, notice: "Mock login successful as #{user.name}!"
  end
  
  def mock_logout
    if current_user
      current_user.sessions.destroy_all
      cookies.delete(:session_id)
      redirect_to auth_login_path, notice: 'Mock logout successful!'
    else
      redirect_to auth_login_path, alert: 'Not logged in.'
    end
  end
  
  private
  
  def ensure_development
    unless Rails.env.development?
      redirect_to root_path, alert: 'Test endpoints only available in development.'
    end
  end
end
