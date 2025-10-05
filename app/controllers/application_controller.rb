# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Rails 8+ uses built-in forgery protection differently; explicit macro is unnecessary
  
  # Authentication
  before_action :authenticate_user!
  
  private
  
  def current_user
    return @current_user if defined?(@current_user)
    
    session_id = cookies[:session_id]
    return @current_user = nil unless session_id
    
    # Validate session ID format for security
    return @current_user = nil unless Session.valid_session_id?(session_id)
    
    session = Session.active.find_by(session_id: session_id)
    return @current_user = nil unless session
    
    # Extend session if it's close to expiring
    session.extend_expiration if session.expires_at < 1.week.from_now
    
    @current_user = session.user
  end
  
  def authenticate_user!
    return if current_user
    
    if request.format.json?
      render json: { error: 'Please log in to access this resource.' }, status: :unauthorized
    else
      redirect_to auth_login_path, alert: 'Please log in to access this page.'
    end
  end
  
  def logged_in?
    current_user.present?
  end
  
  helper_method :current_user, :logged_in?
end
