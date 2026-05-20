# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # `InternalFarmWeatherReadGateway#weather_data_list_snapshot` の戻り（Hash の kind/dto を廃止）。
      class InternalFarmWeatherDataListResult
        OUTCOME_FARM_NOT_FOUND = :farm_not_found
        OUTCOME_WEATHER_LOCATION_NOT_FOUND = :weather_location_not_found
        OUTCOME_OK = :ok

        attr_reader :outcome, :success

        def initialize(outcome:, success: nil)
          @outcome = outcome
          @success = success
        end

        def self.farm_not_found
          new(outcome: OUTCOME_FARM_NOT_FOUND)
        end

        def self.weather_location_not_found
          new(outcome: OUTCOME_WEATHER_LOCATION_NOT_FOUND)
        end

        def self.ok(success_dto)
          new(outcome: OUTCOME_OK, success: success_dto)
        end

        def farm_not_found?
          outcome == OUTCOME_FARM_NOT_FOUND
        end

        def weather_location_not_found?
          outcome == OUTCOME_WEATHER_LOCATION_NOT_FOUND
        end

        def ok?
          outcome == OUTCOME_OK
        end
      end
    end
  end
end
