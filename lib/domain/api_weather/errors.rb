# frozen_string_literal: true

module Domain
  module ApiWeather
    module Errors
      class DaemonUnavailable < StandardError; end

      class CommandFailed < StandardError; end

      class InvalidJsonResponse < StandardError; end
    end
  end
end
