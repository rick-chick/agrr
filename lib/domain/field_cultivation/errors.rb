# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Errors
      class NoWeatherLocationError < StandardError; end

      class NoCultivationPeriodError < StandardError; end

      class WeatherPayloadInvalidError < StandardError; end
    end
  end
end
