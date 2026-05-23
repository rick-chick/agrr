# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Rails 8+ uses built-in forgery protection differently; explicit macro is unnecessary

  # I18n locale setting
  around_action :switch_locale

  # Authentication (enabled in all environments)
  before_action :authenticate_user!

  private

  # Composition Root 経由（lib/composition_root.rb）で Adapter を取得する。
  def translator
    CompositionRoot.translator
  end

  def logger_adapter
    CompositionRoot.logger
  end

  def user_lookup_adapter
    CompositionRoot.user_lookup
  end

  def switch_locale(&action)
    # 優先順位:
    # 1. URLパスに明示的な locale セグメント（ユーザーの明示的なナビゲーション選択）
    # 2. クエリパラメータの locale（明示的な言語選択）
    # 3. Cookie の locale（前回の選択を記憶）
    # 4. Accept-Language ヘッダー（ブラウザ設定 - ユーザーが明示的に選んでいない場合のみ）
    # 5. デフォルト（ja）
    #
    # 注: 明示的なユーザー選択（パス・クエリ）はブラウザの自動設定（Accept-Language）より
    #     常に優先される。例: /ja/... にアクセスした場合は Accept-Language が en-US でも ja を使用
    locale = if (path_locale = explicit_locale_from_path)
               path_locale
             elsif request.query_parameters[:locale].present?
               request.query_parameters[:locale].to_s
             elsif cookies[:locale]
               cookies[:locale].to_s
             elsif (al = extract_locale_from_accept_language_header)
               al
             else
               I18n.default_locale.to_s
             end

    # Validate locale
    locale = I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(locale.to_s)

    # Debug log (development/test only)
    if Rails.env.development? || Rails.env.test?
      Rails.logger.debug "🌐 [Locale] path=#{explicit_locale_from_path}, query[:locale]=#{request.query_parameters[:locale]}, cookies[:locale]=#{cookies[:locale]}, Accept-Language locale=#{extract_locale_from_accept_language_header.inspect}, final locale=#{locale}"
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
  private def extract_locale_from_accept_language_header
    # request.headers と request.env の両方をチェック（IntegrationTest 対応）
    accept_language = request.headers["Accept-Language"].presence || request.env["HTTP_ACCEPT_LANGUAGE"].presence
    return nil unless accept_language

    # Accept-Languageヘッダーをパース（q値を考慮）
    # 形式: "ja,en-US;q=0.9,en;q=0.8"
    accepted_languages = accept_language
      .split(",")
      .map do |lang|
        parts = lang.strip.split(";")
        language = parts[0]
        quality = parts[1]&.match(/q=([\d.]+)/)&.[](1)&.to_f || 1.0
        { language: language, quality: quality }
      end
      .sort_by { |l| -l[:quality] } # q値の高い順にソート

    # 最も優先度の高い言語を取得
    top_language = accepted_languages.first[:language]

    # 言語コードをlocaleにマッピング
    # ja または ja-JP → ja
    return "ja" if top_language.start_with?("ja")

    # en-* (英語圏全般) → us
    # 注: AGRRでは現在usのみサポート。将来的にeu等を追加時に再検討
    return "us" if top_language.start_with?("en")

    # hi-* (ヒンディー) → in
    return "in" if top_language.start_with?("hi")

    # その他の言語はデフォルト（ja）を返さずnilを返す
    # → デフォルトに委ねる
    nil
  end

  def default_url_options
    # In test environment, avoid injecting locale param automatically
    # to allow Accept-Language header based locale detection in tests
    if Rails.env.test?
      {}
    else
      { locale: I18n.locale }
    end
  end

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = CompositionRoot.session_cookie_user_gateway.user_for_session_cookie(cookies[:session_id])
  end

  def authenticate_user!
    # アノニマスユーザーの場合は認証が必要
    return if current_user && !current_user.anonymous?

    if request.format.json?
      render json: { error: I18n.t("auth.messages.login_required") }, status: :unauthorized
    else
      redirect_to auth_login_path, alert: I18n.t("auth.messages.login_required_page")
    end
  end

  def logged_in?
    current_user.present? && !current_user.anonymous?
  end

  def admin_user?
    current_user&.admin?
  end

  def master_form_html_display_capabilities
    Domain::Shared::Dtos::ResourceDisplayCapabilities.for_referencable_form(
      current_user,
      crop_is_reference: false,
      crop_user_id: current_user.id
    )
  end

  def authenticate_admin!
    return if admin_user?

    if request.format.json?
      render json: { error: I18n.t("auth.messages.admin_required") }, status: :forbidden
    else
      redirect_to root_path, alert: I18n.t("auth.messages.admin_required")
    end
  end

  helper_method :current_user, :logged_in?, :admin_user?, :available_locales

  def available_locales
    [
      { code: "ja", name: "日本語", flag: "🇯🇵" },
      { code: "us", name: "English", flag: "🇺🇸" },
      { code: "in", name: "हिंदी", flag: "🇮🇳" }
    ]
  end

  # Presenter が controller を明示レシーバで呼ぶための公開フック（それ以外はこのクラスの private ブロックに従う）
  public

  # 削除 Undo: Presenter が組み立てたペイロードをそのまま二形式で返す（業務フィールドの決定は lib/domain）
  def render_deletion_undo_dual_success(json:, html_notice:, fallback_location:, status: :ok)
    respond_to do |format|
      format.json { render json: json, status: status }
      format.html do
        redirect_back fallback_location: fallback_location, notice: html_notice
      end
    end
  end

  def render_deletion_undo_dual_failure(json:, html_alert:, fallback_location:, status: :unprocessable_entity)
    respond_to do |format|
      format.json { render json: json, status: status }
      format.html do
        redirect_back fallback_location: fallback_location, alert: html_alert
      end
    end
  end
end
