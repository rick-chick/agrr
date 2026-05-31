# frozen_string_literal: true

class ApplicationController < ActionController::Base
  around_action :switch_locale

  private

  def switch_locale(&action)
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

    locale = I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(locale.to_s)

    if Rails.env.development? || Rails.env.test?
      Rails.logger.debug "🌐 [Locale] path=#{explicit_locale_from_path}, query[:locale]=#{request.query_parameters[:locale]}, cookies[:locale]=#{cookies[:locale]}, Accept-Language locale=#{extract_locale_from_accept_language_header.inspect}, final locale=#{locale}"
    end

    cookies[:locale] = { value: locale.to_s, expires: 1.year.from_now }

    I18n.with_locale(locale, &action)
  end

  def explicit_locale_from_path
    path = request.path
    return unless path.present?

    match = path.match(%r{\A/(ja|us|in)(?:/|\z)})
    match&.[](1)
  end

  private def extract_locale_from_accept_language_header
    accept_language = request.headers["Accept-Language"].presence || request.env["HTTP_ACCEPT_LANGUAGE"].presence
    return nil unless accept_language

    accepted_languages = accept_language
      .split(",")
      .map do |lang|
        parts = lang.strip.split(";")
        language = parts[0]
        quality = parts[1]&.match(/q=([\d.]+)/)&.[](1)&.to_f || 1.0
        { language: language, quality: quality }
      end
      .sort_by { |l| -l[:quality] }

    top_language = accepted_languages.first[:language]

    return "ja" if top_language.start_with?("ja")
    return "us" if top_language.start_with?("en")
    return "in" if top_language.start_with?("hi")

    nil
  end

  def default_url_options
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

  def spa_login_url(return_to: nil)
    Adapters::Auth::SpaAuthRedirect.login_url(
      return_to: return_to,
      request_base_url: request.base_url
    )
  end
  helper_method :spa_login_url

  def logged_in?
    current_user.present? && !current_user.anonymous?
  end

  helper_method :current_user, :logged_in?, :available_locales

  def available_locales
    [
      { code: "ja", name: "日本語", flag: "🇯🇵" },
      { code: "us", name: "English", flag: "🇺🇸" },
      { code: "in", name: "हिंदी", flag: "🇮🇳" }
    ]
  end
end
