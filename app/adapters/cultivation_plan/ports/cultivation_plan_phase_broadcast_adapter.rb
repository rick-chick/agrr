# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Ports
      class CultivationPlanPhaseBroadcastAdapter
        include Domain::Shared::Ports::CultivationPlanPhaseBroadcastPort

        def broadcast_phase_update(plan_id:, channel_class:, payload:)
          plan = ::CultivationPlan.find(plan_id)
          channel = resolve_channel(channel_class)
          channel.broadcast_to(plan, payload)
        rescue ActiveRecord::RecordNotFound
          nil
        end

        private

        def resolve_channel(channel_class)
          return channel_class unless channel_class.is_a?(String)

          channel_class.constantize
        end
      end
    end
  end
end
