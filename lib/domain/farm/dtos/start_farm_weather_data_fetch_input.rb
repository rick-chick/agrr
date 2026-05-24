# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class StartFarmWeatherDataFetchInput
        attr_reader :farm_id, :as_of

        def initialize(farm_id:, as_of:)
          @farm_id = farm_id
          @as_of = as_of
        end
      end
    end
  end
end
