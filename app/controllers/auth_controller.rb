# frozen_string_literal: true

class AuthController < ApplicationController
  # Skip CSRF protection for OAuth endpoints
  skip_before_action :verify_authenticity_token, only: [ :google_oauth2_callback, :failure ]

  # Public endpoints
  skip_before_action :authenticate_user!, only: [ :login, :google_oauth2_callback, :failure ]

  def login
    return_to = params[:return_to]&.strip
    redirect_to spa_login_url(return_to: return_to), allow_other_host: true
  end

  def google_oauth2_callback
    auth_hash = request.env["omniauth.auth"]

    if auth_hash.nil?
      redirect_to auth_failure_path, alert: I18n.t("auth.flash.no_data")
      return
    end

    result = CompositionRoot.auth_omniauth_session_gateway.process_google_callback(auth_hash, logger: Rails.logger)

    case result.status
    when :success
      user_session = result.session
      cookies[:session_id] = {
        value: user_session.session_id,
        expires: user_session.expires_at,
        httponly: true,
        secure: Rails.env.production?,
        same_site: :lax
      }

      if session[:public_plan_save_data]
        redirect_to_spa_public_plan_results_after_save!(session.delete(:public_plan_save_data))
        return
      end

      if session[:return_to].present?
        return_to = CompositionRoot.oauth_conversion_url_appender.append(session.delete(:return_to))
        redirect_to return_to, allow_other_host: true, notice: I18n.t("auth.flash.login_success")
      else
        redirect_to root_path, notice: I18n.t("auth.flash.login_success")
      end
    when :user_not_persisted
      redirect_to auth_failure_path, alert: I18n.t("auth.flash.create_user_failed")
    when :record_invalid
      redirect_to auth_failure_path, alert: I18n.t("auth.flash.invalid_data")
    when :omniauth_error, :infrastructure_error
      redirect_to auth_failure_path, alert: I18n.t("auth.flash.unexpected_error")
    else
      redirect_to auth_failure_path, alert: I18n.t("auth.flash.unexpected_error")
    end
  end

  def failure
    error_message = params[:message] || I18n.t("auth.flash.authentication_failed")
    redirect_to spa_login_url, allow_other_host: true, alert: error_message
  end

  def logout
    presenter = Adapters::Auth::Presenters::AuthUserLogoutHtmlPresenter.new(view: self)
    Domain::Auth::Interactors::AuthUserLogoutInteractor.new(
      output_port: presenter,
      session_revocation_gateway: CompositionRoot.user_session_revocation_gateway
    ).call(authenticated: logged_in?, user_id: current_user.id)
  end

  private

  # Delete session cookie robustly across environments and domains
  def clear_session_cookie
    cookies.delete(:session_id)
    cookies.delete(:session_id, path: "/")
    cookie_domain = request.cookie_domain.presence if request.respond_to?(:cookie_domain, true)
    cookies.delete(:session_id, domain: cookie_domain, path: "/") if cookie_domain
    cookies.delete(:session_id, domain: :all, path: "/")
  end

  def auth_failure_path
    "/auth/failure"
  end

  def redirect_to_spa_public_plan_results_after_save!(save_data)
    plan_id = save_data[:plan_id] || save_data["plan_id"]
    redirect_to "#{Adapters::Auth::SpaAuthRedirect.default_origin}/public-plans/results?planId=#{plan_id}",
                allow_other_host: true,
                notice: I18n.t("auth.flash.login_success")
  end

  public :clear_session_cookie
end
