# frozen_string_literal: true

module Domain
  module Farm
    module Policies
      module FarmBroadcastThrottlePolicy
        module_function

        def should_update_broadcast_time?(last_broadcast_at:, current_time:, throttle_seconds: 0.5)
          last_broadcast_at.nil? || (current_time - last_broadcast_at) >= throttle_seconds
        end
      end
    end
  end
end
