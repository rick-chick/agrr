# frozen_string_literal: true

module Domain
  module Farm
    module Policies
      module FarmCoordinateNormalizationPolicy
        module_function

        def normalized_longitude(longitude)
          Domain::Farm::Calculators::FarmWeatherProgressCalculator.normalize_longitude(longitude)
        end
      end
    end
  end
end
