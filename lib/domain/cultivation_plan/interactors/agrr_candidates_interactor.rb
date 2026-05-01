# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class AgrrCandidatesInteractor
        def initialize(gateway:, logger:)
          @logger = logger
          @gateway = gateway
        end

        def call(current_allocation:, fields:, crops:, target_crop_id:, weather_data:, planning_start:, planning_end:, interaction_rules:)
          @gateway.candidates(
            current_allocation: current_allocation,
            fields: fields,
            crops: crops,
            target_crop: target_crop_id.to_s,
            weather_data: weather_data,
            planning_start: planning_start,
            planning_end: planning_end,
            interaction_rules: interaction_rules
          )
        end
      end
    end
  end
end
