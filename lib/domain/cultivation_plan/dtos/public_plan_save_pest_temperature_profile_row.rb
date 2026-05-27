# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PublicPlanSavePestTemperatureProfileRow
        attr_reader :base_temperature, :max_temperature

        def initialize(base_temperature:, max_temperature:)
          @base_temperature = base_temperature
          @max_temperature = max_temperature
          freeze
        end
      end
    end
  end
end
