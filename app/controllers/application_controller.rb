# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Rails 8+ uses built-in forgery protection differently; explicit macro is unnecessary
  
  # Authentication
  before_action :authenticate_user!
  
  private
  
  def current_user
    return @current_user if defined?(@current_user)
    
    session_id = cookies[:session_id]
    unless session_id
      # 未ログインの場合はアノニマスユーザーを返す
      return @current_user = User.anonymous_user
    end
    
    # Validate session ID format for security
    unless Session.valid_session_id?(session_id)
      # セッションIDが無効な場合はアノニマスユーザーを返す
      return @current_user = User.anonymous_user
    end
    
    session = Session.active.find_by(session_id: session_id)
    unless session
      # セッションが見つからない場合はアノニマスユーザーを返す
      return @current_user = User.anonymous_user
    end
    
    # Extend session if it's close to expiring
    session.extend_expiration if session.expires_at < 1.week.from_now
    
    @current_user = session.user
  end
  
  def authenticate_user!
    # アノニマスユーザーの場合は認証が必要
    return if current_user && !current_user.anonymous?
    
    if request.format.json?
      render json: { error: 'Please log in to access this resource.' }, status: :unauthorized
    else
      redirect_to auth_login_path, alert: 'Please log in to access this page.'
    end
  end
  
  def logged_in?
    current_user.present? && !current_user.anonymous?
  end

  def admin_user?
    current_user&.admin?
  end

  def authenticate_admin!
    return if admin_user?
    
    if request.format.json?
      render json: { error: 'Admin access required.' }, status: :forbidden
    else
      redirect_to root_path, alert: 'Admin access required.'
    end
  end
  
  helper_method :current_user, :logged_in?, :admin_user?
end
