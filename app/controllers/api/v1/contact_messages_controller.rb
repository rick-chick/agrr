module Api
  module V1
    class ContactMessagesController < Api::V1::BaseController
      INTERACTOR_CLASS = ::Domain::ContactMessages::Interactors::CreateContactMessageInteractor
      PRESENTER_CLASS = ::Presenters::Api::ContactMessages::ContactMessageCreatePresenter
      RATE_LIMITER_CLASS = ::Adapters::ContactMessages::Services::ContactMessageRateLimiter
      RECAPTCHA_VERIFIER_CLASS = ::Adapters::ContactMessages::Services::RecaptchaVerifier

      include Views::Api::ContactMessages::CreateView

      protect_from_forgery with: :null_session
      # Allow anonymous clients to submit contact messages
      skip_before_action :authenticate_api_request, only: [ :create ]

      def create
        return unless verify_recaptcha!
        return unless enforce_rate_limit!

        presenter = self.class::PRESENTER_CLASS.new(view: self)
        interactor = self.class::INTERACTOR_CLASS.new(
          gateway: CompositionRoot.contact_message_gateway,
          logger: CompositionRoot.logger
        )
        interactor.call(contact_message_input, output_port: presenter)
      end

      def render_response(json:, status:)
        render json: json, status: status unless performed?
      end

      private

      def contact_message_input
        ::Domain::ContactMessages::Dtos::CreateContactMessageInput.new(
          name: contact_message_params[:name],
          email: contact_message_params[:email],
          subject: contact_message_params[:subject],
          message: contact_message_params[:message],
          source: contact_message_params[:source]
        )
      end

      def contact_message_params
        root = params[:contact_message] || params
        root.permit(:name, :email, :subject, :message, :source)
      end

      def verify_recaptcha!
        self.class::RECAPTCHA_VERIFIER_CLASS.new.verify!(token: params[:recaptcha_token], remote_ip: request.remote_ip)
        true
      rescue ::Adapters::ContactMessages::Services::RecaptchaVerifier::VerificationError => e
        render_response(json: { error: e.message }, status: :forbidden)
        false
      end

      def enforce_rate_limit!
        self.class::RATE_LIMITER_CLASS.new(request: request).track!
        true
      rescue ::Adapters::ContactMessages::Services::ContactMessageRateLimiter::RateLimitExceeded
        render_response(json: { error: "Too many requests" }, status: :too_many_requests)
        false
      end

    end
  end
end
