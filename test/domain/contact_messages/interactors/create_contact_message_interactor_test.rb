# frozen_string_literal: true

require "test_helper"

module Domain
  module ContactMessages
    module Interactors
      class CreateContactMessageInteractorTest < ActiveSupport::TestCase
        test "on success notifies output port" do
          entity = Domain::ContactMessages::Entities::ContactMessage.new(
            id: 1,
            status: "queued"
          )
          input = Domain::ContactMessages::Dtos::CreateContactMessageInput.new(
            name: "Taro",
            email: "taro@example.com",
            subject: "Hello",
            message: "Hi"
          )

          gateway = Minitest::Mock.new
          gateway.expect(:create, entity, [ input ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |dto| received = dto }

          interactor = CreateContactMessageInteractor.new(gateway: gateway)

          interactor.call(input, output_port: output_port)

          assert_instance_of Domain::ContactMessages::Dtos::CreateContactMessageSuccess, received
          assert_equal entity, received.contact_message

          gateway.verify
          output_port.verify
        end

        test "calls on_failure when validation fails" do
          input = Domain::ContactMessages::Dtos::CreateContactMessageInput.new(
            name: "Taro",
            email: "invalid",
            subject: "Hello",
            message: ""
          )

          record = ::ContactMessage.new(email: "invalid", message: "")
          record.valid?
          invalid_exception = Domain::Shared::Exceptions::RecordInvalid.new(
            "Validation failed",
            errors: record.errors,
            record: record
          )

          gateway = Minitest::Mock.new
          gateway.expect(:create, nil) { raise invalid_exception }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |dto| received = dto }

          interactor = CreateContactMessageInteractor.new(gateway: gateway)

          interactor.call(input, output_port: output_port)

          assert_instance_of Domain::ContactMessages::Dtos::CreateContactMessageFailure, received
          assert_equal record.errors, received.errors

          gateway.verify
          output_port.verify
        end

        test "calls on_failure with ErrorDto on unexpected errors and logs when logger given" do
          input = Domain::ContactMessages::Dtos::CreateContactMessageInput.new(
            name: "Taro",
            email: "taro@example.com",
            subject: "Hello",
            message: "Hi"
          )

          gateway = Minitest::Mock.new
          gateway.expect(:create, nil) { raise StandardError, "boom" }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |dto| received = dto }

          logger = Minitest::Mock.new
          logger.expect(:error, nil) do |msg|
            assert_kind_of String, msg
            assert_includes msg, "boom"
          end

          interactor = CreateContactMessageInteractor.new(gateway: gateway, logger: logger)

          interactor.call(input, output_port: output_port)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "boom"

          gateway.verify
          output_port.verify
          logger.verify
        end
      end
    end
  end
end
