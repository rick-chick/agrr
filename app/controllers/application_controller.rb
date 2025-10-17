# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Rails 8+ uses built-in forgery protection differently; explicit macro is unnecessary
  
  # I18n locale setting
  around_action :switch_locale
  
  # Authentication (disabled in production)
  before_action :authenticate_user!, unless: -> { Rails.env.production? }
  
  private
  
  def switch_locale(&action)
    locale = params[:locale] || cookies[:locale] || I18n.default_locale
    # Validate locale
    locale = I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(locale.to_s)
    
    # Save locale to cookie
    cookies[:locale] = { value: locale.to_s, expires: 1.year.from_now }
    
    I18n.with_locale(locale, &action)
  end
  
  def default_url_options
    { locale: I18n.locale }
  end
  
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
    # Production環境では認証を強制しない（全員アノニマスユーザーとして扱う）
    return if Rails.env.production?
    
    # アノニマスユーザーの場合は認証が必要
    return if current_user && !current_user.anonymous?
    
    if request.format.json?
      render json: { error: I18n.t('auth.messages.login_required') }, status: :unauthorized
    else
      redirect_to auth_login_path, alert: I18n.t('auth.messages.login_required_page')
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
      render json: { error: I18n.t('auth.messages.admin_required') }, status: :forbidden
    else
      redirect_to root_path, alert: I18n.t('auth.messages.admin_required')
    end
  end
  
  helper_method :current_user, :logged_in?, :admin_user?, :available_locales
  
  def available_locales
    [
      { code: 'ja', name: '日本語', flag: '🇯🇵' },
      { code: 'us', name: 'English', flag: '🇺🇸' }
    ]
  end
end
