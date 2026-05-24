# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class RecordFarmWeatherBlockCompletedInput
        attr_reader :farm_id, :current_time

        def initialize(farm_id:, current_time:)
          @farm_id = farm_id
          @current_time = current_time
        end
      end
    end
  end
end
