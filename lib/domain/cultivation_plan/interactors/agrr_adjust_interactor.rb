# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class AgrrAdjustInteractor
        def initialize(gateway:, logger:)
          @logger = logger
          @gateway = gateway
        end

        def call(current_allocation:, moves:, fields:, crops:, weather_data:, planning_start:, planning_end:, interaction_rules:, objective:, enable_parallel:)
          @gateway.adjust(
            current_allocation: current_allocation,
            moves: moves,
            fields: fields,
            crops: crops,
            weather_data: weather_data,
            planning_start: planning_start,
            planning_end: planning_end,
            interaction_rules: interaction_rules,
            objective: objective,
            enable_parallel: enable_parallel
          )
        end
      end
    end
  end
end
