# frozen_string_literal: true

module Domain
  module InternalJobs
    module Gateways
      module SchedulerWeatherFarmListGateway
        def list_reference_farms_for_weather_update
          raise NotImplementedError
        end

        def list_user_farms_for_weather_update
          raise NotImplementedError
        end
      end
    end
  end
end
