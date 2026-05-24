# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      module CultivationPlanPhaseBroadcastPort
        def broadcast_phase_update(plan_id:, channel_class:, payload:)
          raise NotImplementedError, "#{self.class}#broadcast_phase_update"
        end
      end
    end
  end
end
