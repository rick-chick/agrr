# frozen_string_literal: true

module Domain
  module ContactMessages
    module Interactors
      class CreateContactMessageInteractor
        def initialize(gateway:, recaptcha_verifier:, rate_limiter:)
          @gateway = gateway
          @recaptcha_verifier = recaptcha_verifier
          @rate_limiter = rate_limiter
        end

        # input: Domain::ContactMessages::Dtos::CreateContactMessageInput
        # HTTP / JSON の成否は output_port（Presenter）へ委ねる（ARCHITECTURE.md の canonical vertical slice）。
        def call(input, output_port: nil)
          if @rate_limiter.track == :rate_limited
            output_port&.on_failure(Dtos::CreateContactMessageFailure.rate_limit)
            return
          end

          vr = @recaptcha_verifier.verify(token: input.recaptcha_token, remote_ip: input.remote_ip)
          unless vr == :ok
            msg = vr.is_a?(Array) ? vr[1].to_s : "reCAPTCHA verification failed"
            output_port&.on_failure(Dtos::CreateContactMessageFailure.recaptcha(message: msg))
            return
          end

          entity = @gateway.create(input)

          success_dto = Dtos::CreateContactMessageSuccess.new(contact_message: entity)
          output_port&.on_success(success_dto)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          failure_dto = Dtos::CreateContactMessageFailure.validation(errors: e.errors)
          output_port&.on_failure(failure_dto)
        end
      end
    end
  end
end
