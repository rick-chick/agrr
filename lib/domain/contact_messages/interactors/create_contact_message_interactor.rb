# frozen_string_literal: true

module Domain
  module ContactMessages
    module Interactors
      class CreateContactMessageInteractor
        def initialize(gateway:)
          @gateway = gateway
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
        end
      end
    end
  end
end
