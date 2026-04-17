# frozen_string_literal: true

require_relative '../dtos/create_contact_message_input'
require_relative '../dtos/create_contact_message_success'
require_relative '../dtos/create_contact_message_failure'

module ContactMessages
  module Interactors
    class CreateContactMessageInteractor
      Result = Struct.new(:success, :contact_message, :errors, keyword_init: true) do
        def success?
          success
        end
      end

      def initialize(gateway: nil)
        @gateway = gateway
      end

      # input: ContactMessages::Dtos::CreateContactMessageInput
      # returns: Result with success flag, entity, and optional errors
      def call(input, output_port: nil)
        entity = gateway_with_defaults.create(input)

        success_dto = Dtos::CreateContactMessageSuccess.new(contact_message: entity)
        output_port&.on_success(success_dto)

        Result.new(success: true, contact_message: entity)
      rescue ActiveRecord::RecordInvalid => e
        failure_dto = Dtos::CreateContactMessageFailure.new(errors: e.record.errors)
        output_port&.on_failure(failure_dto)

        Result.new(success: false, errors: e.record.errors)
      rescue StandardError => e
        failure_dto = Domain::Shared::Dtos::ErrorDto.new(e.message)
        output_port&.on_failure(failure_dto)
        raise
      end

      private

      def gateway_with_defaults
        @gateway ||= Adapters::ContactMessages::Gateways::ContactMessageActiveRecordGateway.new
      end
    end
  end
end
