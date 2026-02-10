# frozen_string_literal: true

require 'test_helper'

module ContactMessages
  module Interactors
    class CreateContactMessageInteractorTest < ActiveSupport::TestCase
      test 'on success notifies output port and returns entity' do
        entity = ContactMessages::Entities::ContactMessage.new(
          id: 1,
          status: 'queued'
        )
        input = ContactMessages::Dtos::CreateContactMessageInput.new(
          name: 'Taro',
          email: 'taro@example.com',
          subject: 'Hello',
          message: 'Hi'
        )

        gateway = Minitest::Mock.new
        gateway.expect(:create, entity, [input])

        received = nil
        output_port = Minitest::Mock.new
        output_port.expect(:on_success, nil) { |dto| received = dto }

        interactor = CreateContactMessageInteractor.new(
          gateway: gateway,
          destination_email: 'admin@example.com'
        )

        result = interactor.call(input, output_port: output_port)

        assert result.success?
        assert_equal entity, result.contact_message
        assert_instance_of ContactMessages::Dtos::CreateContactMessageSuccess, received
        assert_equal entity, received.contact_message

        gateway.verify
        output_port.verify
      end

      test 'calls on_failure when validation fails' do
        input = ContactMessages::Dtos::CreateContactMessageInput.new(
          name: 'Taro',
          email: 'invalid',
          subject: 'Hello',
          message: ''
        )

        record = ::ContactMessage.new(email: 'invalid', message: '')
        record.valid?
        invalid_exception = ActiveRecord::RecordInvalid.new(record)

        gateway = Minitest::Mock.new
        gateway.expect(:create, nil) { raise invalid_exception }

        received = nil
        output_port = Minitest::Mock.new
        output_port.expect(:on_failure, nil) { |dto| received = dto }

        interactor = CreateContactMessageInteractor.new(
          gateway: gateway,
          destination_email: 'admin@example.com'
        )

        result = interactor.call(input, output_port: output_port)

        refute result.success?
        assert_equal invalid_exception.record.errors, result.errors
        assert_instance_of ContactMessages::Dtos::CreateContactMessageFailure, received
        assert_equal invalid_exception.record.errors, received.errors

        gateway.verify
        output_port.verify
      end

      test 'notifies output port on unexpected errors and re-raises' do
        input = ContactMessages::Dtos::CreateContactMessageInput.new(
          name: 'Taro',
          email: 'taro@example.com',
          subject: 'Hello',
          message: 'Hi'
        )

        gateway = Minitest::Mock.new
        gateway.expect(:create, nil) { raise StandardError, 'boom' }

        received = nil
        output_port = Minitest::Mock.new
        output_port.expect(:on_failure, nil) do |dto|
          received = dto
        end

        interactor = CreateContactMessageInteractor.new(
          gateway: gateway,
          destination_email: 'admin@example.com'
        )

        assert_raises(StandardError) do
          interactor.call(input, output_port: output_port)
        end

        assert_instance_of Domain::Shared::Dtos::ErrorDto, received
        assert_includes received.message, 'boom'

        gateway.verify
        output_port.verify
      end
    end
  end
end
