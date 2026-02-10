require 'ostruct'
require 'test_helper'

module Api
  module V1
    class ContactMessagesControllerTest < ActionDispatch::IntegrationTest
      setup do
        ENV['CONTACT_DESTINATION_EMAIL'] = 'admin@example.com'
        ActiveJob::Base.queue_adapter = :test
      end

      test 'creates contact message and returns 201 with payload' do
        fake_contact_message = OpenStruct.new(
          id: 123,
          status: 'queued',
          created_at: Time.current.utc,
          sent_at: Time.current.utc
        )
        fake_success_dto = OpenStruct.new(contact_message: fake_contact_message)
        fake_result = OpenStruct.new(success?: true, contact_message: fake_contact_message)
        fake_class = Class.new do
          define_method(:initialize) {}
          define_method(:call) do |_input, output_port: nil|
            output_port&.on_success(fake_success_dto)
            fake_result
          end
        end

        with_controller_constants(
          INTERACTOR_CLASS: fake_class,
          RATE_LIMITER_CLASS: NoopRateLimiter,
          RECAPTCHA_VERIFIER_CLASS: NoopRecaptchaVerifier
        ) do
          post api_v1_contact_messages_path, params: {
            name: 'Taro',
            email: 'taro@example.com',
            subject: 'Hello',
            message: 'Hi there',
            source: 'landing_page'
          }, as: :json

          assert_response :created
          json = JSON.parse(response.body)
          assert_equal fake_contact_message.id, json['id']
          assert_equal fake_contact_message.status, json['status']
          assert_equal fake_contact_message.created_at.iso8601, json['created_at']
          assert_equal fake_contact_message.sent_at.iso8601, json['sent_at']
        end
      end

      test 'returns 422 and field_errors on validation failure' do
        fake_errors = OpenStruct.new(messages: { 'email' => ['is invalid'], 'message' => ["can't be blank"] })
        fake_failure_dto = OpenStruct.new(errors: fake_errors)
        fake_result = OpenStruct.new(success?: false, errors: fake_errors)
        fake_class = Class.new do
          define_method(:initialize) {}
          define_method(:call) do |_input, output_port: nil|
            output_port&.on_failure(fake_failure_dto)
            fake_result
          end
        end

        with_controller_constants(
          INTERACTOR_CLASS: fake_class,
          RATE_LIMITER_CLASS: NoopRateLimiter,
          RECAPTCHA_VERIFIER_CLASS: NoopRecaptchaVerifier
        ) do
          post api_v1_contact_messages_path, params: {
            name: 'Taro',
            email: 'invalid-email',
            subject: 'Hello',
            message: ''
          }, as: :json

          assert_response :unprocessable_entity
          json = JSON.parse(response.body)
          assert_equal 'Validation failed', json['error']
          assert json['field_errors'].is_a?(Hash)
          assert json['field_errors']['email'].present? || json['field_errors']['message'].present?
        end
      end

      test 'returns too many requests when rate limit exceeded' do
        rate_limiter = Class.new do
          def initialize(**); end
          def track!; raise ::ContactMessages::Services::ContactMessageRateLimiter::RateLimitExceeded; end
        end

        with_controller_constants(
          RATE_LIMITER_CLASS: rate_limiter,
          RECAPTCHA_VERIFIER_CLASS: NoopRecaptchaVerifier
        ) do
          post api_v1_contact_messages_path, params: {
            name: 'Taro',
            email: 'taro@example.com',
            subject: 'Hello',
            message: 'Hi there'
          }, as: :json

          assert_response :too_many_requests
          json = JSON.parse(response.body)
          assert_equal 'Too many requests', json['error']
        end
      end

      test 'returns forbidden when recaptcha fails' do
        recaptcha_verifier = Class.new do
          def initialize(**); end
          def verify!(**); raise ::ContactMessages::Services::RecaptchaVerifier::VerificationError, 'recaptcha failed'; end
        end

        with_controller_constants(
          RATE_LIMITER_CLASS: NoopRateLimiter,
          RECAPTCHA_VERIFIER_CLASS: recaptcha_verifier
        ) do
          post api_v1_contact_messages_path, params: {
            name: 'Taro',
            email: 'taro@example.com',
            subject: 'Hello',
            message: 'Hi there'
          }, as: :json

          assert_response :forbidden
          json = JSON.parse(response.body)
          assert_equal 'recaptcha failed', json['error']
        end
      end

      test 'returns internal server error when unexpected exception bubbles up' do
        failing_interactor = Class.new do
          define_method(:initialize) {}
          define_method(:call) { |_input, **| raise 'boom' }
        end

        with_controller_constants(
          INTERACTOR_CLASS: failing_interactor,
          RATE_LIMITER_CLASS: NoopRateLimiter,
          RECAPTCHA_VERIFIER_CLASS: NoopRecaptchaVerifier
        ) do
          post api_v1_contact_messages_path, params: {
            name: 'Taro',
            email: 'taro@example.com',
            subject: 'Hello',
            message: 'Hi there'
          }, as: :json

          assert_response :internal_server_error
          json = JSON.parse(response.body)
          assert_equal 'Internal server error', json['error']
        end
      end

      private

      def with_controller_constants(overrides)
        originals = {}
        overrides.each do |const_name, override|
          originals[const_name] = Api::V1::ContactMessagesController.const_get(const_name)
          Api::V1::ContactMessagesController.const_set(const_name, override)
        end
        yield
      ensure
        originals.each do |const_name, original|
          Api::V1::ContactMessagesController.const_set(const_name, original)
        end
      end

      class NoopRateLimiter
        def initialize(**); end
        def track!; true; end
      end

      class NoopRecaptchaVerifier
        def initialize(**); end
        def verify!(**); true; end
      end
    end
  end
end

