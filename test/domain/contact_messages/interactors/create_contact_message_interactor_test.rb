# frozen_string_literal: true

require "test_helper"

module Domain
  module ContactMessages
    module Interactors
      class CreateContactMessageInteractorTest < ActiveSupport::TestCase
        def noop_recaptcha
          Class.new do
            def verify(**)
              :ok
            end
          end.new
        end

        def noop_rate_limiter
          Class.new do
            def track
              :ok
            end
          end.new
        end

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

          interactor = CreateContactMessageInteractor.new(
            gateway: gateway,
            recaptcha_verifier: noop_recaptcha,
            rate_limiter: noop_rate_limiter
          )

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
            errors: Domain::Shared::ValidationErrors.from_errors_like(record.errors)
          )

          gateway = Minitest::Mock.new
          gateway.expect(:create, nil) { raise invalid_exception }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |dto| received = dto }

          interactor = CreateContactMessageInteractor.new(
            gateway: gateway,
            recaptcha_verifier: noop_recaptcha,
            rate_limiter: noop_rate_limiter
          )

          interactor.call(input, output_port: output_port)

          assert_instance_of Domain::ContactMessages::Dtos::CreateContactMessageFailure, received
          assert received.validation?
          assert_instance_of Domain::Shared::ValidationErrors, received.errors
          assert_equal(
            Domain::Shared::ValidationErrors.from_errors_like(record.errors).messages,
            received.errors.messages
          )

          gateway.verify
          output_port.verify
        end

        test "propagates StandardError from gateway (no on_failure)" do
          input = Domain::ContactMessages::Dtos::CreateContactMessageInput.new(
            name: "Taro",
            email: "taro@example.com",
            subject: "Hello",
            message: "Hi"
          )

          gateway = Minitest::Mock.new
          gateway.expect(:create, nil) { raise StandardError, "boom" }

          interactor = CreateContactMessageInteractor.new(
            gateway: gateway,
            recaptcha_verifier: noop_recaptcha,
            rate_limiter: noop_rate_limiter
          )

          error = assert_raises(StandardError) do
            interactor.call(input, output_port: nil)
          end
          assert_equal "boom", error.message

          gateway.verify
        end

        test "calls on_failure when rate limited" do
          input = Domain::ContactMessages::Dtos::CreateContactMessageInput.new(
            name: "Taro",
            email: "taro@example.com",
            subject: "Hello",
            message: "Hi"
          )

          gateway = Minitest::Mock.new
          limiter = Class.new do
            def track
              :rate_limited
            end
          end.new

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |dto| received = dto }

          interactor = CreateContactMessageInteractor.new(
            gateway: gateway,
            recaptcha_verifier: noop_recaptcha,
            rate_limiter: limiter
          )

          interactor.call(input, output_port: output_port)

          assert_instance_of Domain::ContactMessages::Dtos::CreateContactMessageFailure, received
          assert received.rate_limit?

          gateway.verify
          output_port.verify
        end

        test "calls on_failure when recaptcha fails" do
          input = Domain::ContactMessages::Dtos::CreateContactMessageInput.new(
            name: "Taro",
            email: "taro@example.com",
            subject: "Hello",
            message: "Hi"
          )

          gateway = Minitest::Mock.new
          verifier = Class.new do
            def verify(**)
              [ :error, "bad captcha" ]
            end
          end.new

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |dto| received = dto }

          interactor = CreateContactMessageInteractor.new(
            gateway: gateway,
            recaptcha_verifier: verifier,
            rate_limiter: noop_rate_limiter
          )

          interactor.call(input, output_port: output_port)

          assert_instance_of Domain::ContactMessages::Dtos::CreateContactMessageFailure, received
          assert received.recaptcha?
          assert_equal "bad captcha", received.message

          gateway.verify
          output_port.verify
        end
      end
    end
  end
end
