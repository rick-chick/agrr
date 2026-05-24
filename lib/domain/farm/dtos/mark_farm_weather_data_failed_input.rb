# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class MarkFarmWeatherDataFailedInput
        attr_reader :farm_id, :error_message

        def initialize(farm_id:, error_message:)
          @farm_id = farm_id
          @error_message = error_message
        end
      end
    end
  end
end
