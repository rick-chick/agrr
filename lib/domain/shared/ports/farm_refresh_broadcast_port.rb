# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      module FarmRefreshBroadcastPort
        def broadcast_farm_weather_progress(farm_id:, payload:)
          raise NotImplementedError, "#{self.class}#broadcast_farm_weather_progress"
        end
      end
    end
  end
end
