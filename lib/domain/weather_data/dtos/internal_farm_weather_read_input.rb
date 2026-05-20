# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # internal 農場天気読み取りの入力（farm_id のみ）。
      class InternalFarmWeatherReadInput
        attr_reader :farm_id

        def initialize(farm_id:)
          @farm_id = farm_id
        end
      end
    end
  end
end
