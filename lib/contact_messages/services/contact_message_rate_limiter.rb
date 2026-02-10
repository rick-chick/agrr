# frozen_string_literal: true

module ContactMessages
  module Services
    class ContactMessageRateLimiter
      class RateLimitExceeded < StandardError; end

      DEFAULT_CONFIG = '10/min'.freeze
      DEFAULT_PERIOD_IN_SECONDS = 60
      PERIOD_MAP = {
        'second' => 1,
        'minute' => 60,
        'hour' => 3_600,
        'day' => 86_400
      }.freeze

      def initialize(request:, limit_config: ENV['CONTACT_RATE_LIMIT'])
        @request = request
        @limit_config = (limit_config.presence || DEFAULT_CONFIG).to_s
      end

      def track!
        limit, period = parse_limit(@limit_config)
        return true if limit <= 0

        value = increment_counter(cache_key, period)
        raise RateLimitExceeded if value > limit

        true
      end

      private

      attr_reader :request

      def cache_key
        ip = request.remote_ip.presence || request.ip.presence || 'unknown'
        "contact_message_rate:#{ip}"
      end

      def increment_counter(key, expires_in)
        if Rails.cache.respond_to?(:increment)
          Rails.cache.fetch(key, expires_in: expires_in) { 0 }
          Rails.cache.increment(key, 1, expires_in: expires_in) || 1
        else
          current = Rails.cache.read(key) || 0
          current += 1
          Rails.cache.write(key, current, expires_in: expires_in)
          current
        end
      end

      def parse_limit(value)
        if value =~ /\A(\d+)\s*\/\s*(\w+)\z/
          limit = Regexp.last_match(1).to_i
          period = PERIOD_MAP.fetch(Regexp.last_match(2).downcase, DEFAULT_PERIOD_IN_SECONDS)
        elsif value =~ /\A(\d+)\z/
          limit = Regexp.last_match(1).to_i
          period = DEFAULT_PERIOD_IN_SECONDS
        else
          limit = DEFAULT_CONFIG.to_i
          period = DEFAULT_PERIOD_IN_SECONDS
        end

        [limit, period]
      end
    end
  end
end

