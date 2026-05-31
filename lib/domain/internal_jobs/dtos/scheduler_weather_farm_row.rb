# frozen_string_literal: true

module Domain
  module InternalJobs
    module Dtos
      SchedulerWeatherFarmRow = Struct.new(
        :farm_id,
        :latitude,
        :longitude,
        :latest_weather_date,
        keyword_init: true
      )
    end
  end
end
