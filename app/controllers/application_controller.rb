# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include DeletionUndoResponder
  # Rails 8+ uses built-in forgery protection differently; explicit macro is unnecessary
  
  # I18n locale setting
  around_action :switch_locale
  
  # Authentication (enabled in all environments)
  before_action :authenticate_user!
  
  private

  def translator
    @translator ||= Adapters::Translators::RailsTranslator.new
  end

  def switch_locale(&action)
    # 優先順位:
    # 1. URLパスに明示的な locale セグメント
    # 2. Cookie の locale（前回の選択）
    # 3. Accept-Language ヘッダー（ブラウザ設定）
    # 4. デフォルト（ja）
    locale = explicit_locale_from_path ||
             cookies[:locale] ||
             extract_locale_from_accept_language_header ||
             I18n.default_locale
    
    # Validate locale
    locale = I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(locale.to_s)
    
    # Debug log (development/test only)
    if Rails.env.development? || Rails.env.test?
      Rails.logger.debug "🌐 [Locale] params[:locale]=#{params[:locale]}, cookies[:locale]=#{cookies[:locale]}, Accept-Language locale=#{extract_locale_from_accept_language_header}, final locale=#{locale}"
    end
    
    # Save locale to cookie
    cookies[:locale] = { value: locale.to_s, expires: 1.year.from_now }
    
    I18n.with_locale(locale, &action)
  end

  def explicit_locale_from_path
    path = request.path
    return unless path.present?

    match = path.match(%r{\A/(ja|us|in)(?:/|\z)})
    match&.[](1)
  end
  
  # Accept-Languageヘッダーから言語を抽出
  # 例: "ja,en-US;q=0.9,en;q=0.8" → "ja"
  # 例: "en-US,en;q=0.9,ja;q=0.8" → "us"
  def extract_locale_from_accept_language_header
    return nil unless request.env['HTTP_ACCEPT_LANGUAGE']
    
    # Accept-Languageヘッダーをパース（q値を考慮）
    # 形式: "ja,en-US;q=0.9,en;q=0.8"
    accepted_languages = request.env['HTTP_ACCEPT_LANGUAGE']
      .split(',')
      .map do |lang|
        parts = lang.strip.split(';')
        language = parts[0]
        quality = parts[1]&.match(/q=([\d.]+)/)&.[](1)&.to_f || 1.0
        { language: language, quality: quality }
      end
      .sort_by { |l| -l[:quality] } # q値の高い順にソート
    
    # 最も優先度の高い言語を取得
    top_language = accepted_languages.first[:language]
    
    # 言語コードをlocaleにマッピング
    # ja または ja-JP → ja
    return 'ja' if top_language.start_with?('ja')
    
    # en-* (英語圏全般) → us
    # 注: AGRRでは現在usのみサポート。将来的にeu等を追加時に再検討
    return 'us' if top_language.start_with?('en')

    # hi-* (ヒンディー) → in
    return 'in' if top_language.start_with?('hi')
    
    # その他の言語はデフォルト（ja）を返さずnilを返す
    # → デフォルトに委ねる
    nil
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
      { code: 'us', name: 'English', flag: '🇺🇸' },
      { code: 'in', name: 'हिंदी', flag: '🇮🇳' }
    ]
  end
end
