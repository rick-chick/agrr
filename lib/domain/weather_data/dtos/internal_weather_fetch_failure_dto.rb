# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      class InternalWeatherFetchFailureDto
        attr_reader :message, :http_status

        def initialize(message:, http_status:)
          @message = message
          @http_status = http_status
        end
      end
    end
  end
end
