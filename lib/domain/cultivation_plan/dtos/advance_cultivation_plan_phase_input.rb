# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class AdvanceCultivationPlanPhaseInput
        attr_reader :plan_id, :phase_name, :channel_class, :failure_subphase

        def initialize(plan_id:, phase_name:, channel_class: nil, failure_subphase: nil)
          @plan_id = plan_id
          @phase_name = phase_name
          @channel_class = channel_class
          @failure_subphase = failure_subphase
        end
      end
    end
  end
end
