module Api
  module V1
    class ContactMessagesController < Api::V1::BaseController
      INTERACTOR_CLASS = ::ContactMessages::Interactors::CreateContactMessageInteractor
      PRESENTER_CLASS = ::Api::ContactMessages::ContactMessageCreatePresenter
      RATE_LIMITER_CLASS = ::ContactMessages::Services::ContactMessageRateLimiter
      RECAPTCHA_VERIFIER_CLASS = ::ContactMessages::Services::RecaptchaVerifier

      include Views::Api::ContactMessages::CreateView

      protect_from_forgery with: :null_session
      # Allow anonymous clients to submit contact messages
      skip_before_action :authenticate_api_request, only: [:create]

      def create
        return unless verify_recaptcha!
        return unless enforce_rate_limit!

        presenter = self.class::PRESENTER_CLASS.new(view: self)
        interactor = self.class::INTERACTOR_CLASS.new
        interactor.call(contact_message_input, output_port: presenter)
      rescue StandardError => e
        log_unexpected_error(e)
        render_response(json: { error: 'Internal server error' }, status: :internal_server_error)
      end

      def render_response(json:, status:)
        render json: json, status: status
      end

      private

      def contact_message_input
        ::ContactMessages::Dtos::CreateContactMessageInput.new(
          name: contact_message_params[:name],
          email: contact_message_params[:email],
          subject: contact_message_params[:subject],
          message: contact_message_params[:message],
          source: contact_message_params[:source]
        )
      end

      def contact_message_params
        params.permit(:name, :email, :subject, :message, :source)
      end

      def verify_recaptcha!
        self.class::RECAPTCHA_VERIFIER_CLASS.new.verify!(token: params[:recaptcha_token], remote_ip: request.remote_ip)
        true
      rescue ::ContactMessages::Services::RecaptchaVerifier::VerificationError => e
        render_response(json: { error: e.message }, status: :forbidden)
        false
      end

      def enforce_rate_limit!
        self.class::RATE_LIMITER_CLASS.new(request: request).track!
        true
      rescue ::ContactMessages::Services::ContactMessageRateLimiter::RateLimitExceeded
        render_response(json: { error: 'Too many requests' }, status: :too_many_requests)
        false
      end

      def log_unexpected_error(error)
        Rails.logger.error("[ContactMessagesController#create] unexpected error: #{error.class} #{error.message}\n#{error.backtrace.join("\n")}")
      end
    end
  end
end

