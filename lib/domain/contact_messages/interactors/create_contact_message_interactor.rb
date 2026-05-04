# frozen_string_literal: true

module Domain
  module ContactMessages
    module Interactors
      class CreateContactMessageInteractor
        def initialize(gateway:, logger: nil)
          @gateway = gateway
          @logger = logger
        end

        # input: Domain::ContactMessages::Dtos::CreateContactMessageInput
        # HTTP / JSON の成否は output_port（Presenter）へ委ねる（ARCHITECTURE.md の canonical vertical slice）。
        def call(input, output_port: nil)
          entity = @gateway.create(input)

          success_dto = Dtos::CreateContactMessageSuccess.new(contact_message: entity)
          output_port&.on_success(success_dto)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          failure_dto = Dtos::CreateContactMessageFailure.new(errors: e.errors)
          output_port&.on_failure(failure_dto)
        rescue StandardError => e
          log_unexpected_error(e) if @logger
          failure_dto = Domain::Shared::Dtos::ErrorDto.new(e.message)
          output_port&.on_failure(failure_dto)
        end

        private

        def log_unexpected_error(error)
          bt = error.backtrace&.first(20)&.join("\n").to_s
          @logger.error(
            "[CreateContactMessageInteractor] #{error.class}: #{error.message}\n/backtrace:\n#{bt}"
          )
        end
      end
    end
  end
end
