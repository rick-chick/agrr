module Api
  module V1
    class ContactMessagesController < Api::V1::BaseController
      INTERACTOR_CLASS = ::Domain::ContactMessages::Interactors::CreateContactMessageInteractor
      PRESENTER_CLASS = ::Adapters::ContactMessages::Presenters::ContactMessageCreateApiPresenter
      RATE_LIMITER_CLASS = ::Adapters::ContactMessages::Services::ContactMessageRateLimiter
      RECAPTCHA_VERIFIER_CLASS = ::Adapters::ContactMessages::Services::RecaptchaVerifier


      protect_from_forgery with: :null_session
      # Allow anonymous clients to submit contact messages
      skip_before_action :authenticate_api_request, only: [ :create ]

      def create
        presenter = self.class::PRESENTER_CLASS.new(view: self)
        interactor = self.class::INTERACTOR_CLASS.new(
          output_port: presenter,
          gateway: CompositionRoot.contact_message_gateway,
          recaptcha_verifier: self.class::RECAPTCHA_VERIFIER_CLASS.new,
          rate_limiter: self.class::RATE_LIMITER_CLASS.new(request: request)
        )
        interactor.call(contact_message_input)
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
          source: contact_message_params[:source],
          recaptcha_token: params[:recaptcha_token],
          remote_ip: request.remote_ip
        )
      end

      def contact_message_params
        root = params[:contact_message] || params
        root.permit(:name, :email, :subject, :message, :source)
      end

    end
  end
end
