# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module ContactMessages
  module Services
    class RecaptchaVerifier
      class VerificationError < StandardError; end

      VERIFY_URI = URI('https://www.google.com/recaptcha/api/siteverify')

      def initialize(secret_key: ENV['RECAPTCHA_SECRET_KEY'])
        @secret_key = secret_key
      end

      def verify!(token:, remote_ip:)
        return true if verification_disabled?(token)

        response = Net::HTTP.post_form(VERIFY_URI, request_payload(token: token, remote_ip: remote_ip))
        payload = parse_response(response.body)

        return true if payload['success']

        raise VerificationError, error_message(payload)
      rescue VerificationError
        raise
      rescue StandardError => e
        raise VerificationError, "reCAPTCHA verification error: #{e.message}"
      end

      private

      attr_reader :secret_key

      def verification_disabled?(token)
        secret_key.to_s.strip.empty? || token.to_s.strip.empty?
      end

      def request_payload(token:, remote_ip:)
        {
          secret: secret_key,
          response: token,
          remoteip: remote_ip.to_s
        }
      end

      def parse_response(raw_body)
        JSON.parse(raw_body.to_s)
      rescue JSON::ParserError => e
        raise VerificationError, "reCAPTCHA verification failed: #{e.message}"
      end

      def error_message(payload)
        errors = Array(payload['error-codes']).map(&:to_s)
        return 'reCAPTCHA verification failed' if errors.empty?

        "reCAPTCHA failure: #{errors.join(', ')}"
      end
    end
  end
end

