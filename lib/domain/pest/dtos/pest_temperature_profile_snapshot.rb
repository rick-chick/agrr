# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class PestTemperatureProfileSnapshot
        attr_reader :base_temperature, :max_temperature

        def initialize(base_temperature:, max_temperature:)
          @base_temperature = base_temperature
          @max_temperature = max_temperature
        end
      end
    end
  end
end
