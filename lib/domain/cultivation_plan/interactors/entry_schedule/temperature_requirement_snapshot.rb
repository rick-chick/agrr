# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      module EntrySchedule
        TemperatureRequirementSnapshot = Struct.new(
          :frost_threshold,
          :optimal_min,
          :optimal_max,
          :base_temperature,
          keyword_init: true
        )
      end
    end
  end
end
