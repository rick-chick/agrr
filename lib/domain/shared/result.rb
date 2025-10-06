# frozen_string_literal: true

module Domain
  module Shared
    class Result
      attr_reader :data, :error

      def initialize(success, data = nil, error = nil)
        @success = success
        @data = data
        @error = error
      end

      def success?
        @success
      end

      def failure?
        !@success
      end

      def self.success(data = nil)
        new(true, data)
      end

      def self.failure(error)
        new(false, nil, error)
      end
    end
  end
end
