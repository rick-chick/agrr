# frozen_string_literal: true

module Adapters
  module Farm
    module Ports
      class FarmRefreshBroadcastAdapter
        include Domain::Shared::Ports::FarmRefreshBroadcastPort

        def broadcast_farm_weather_progress(farm_id:, payload:)
          farm = ::Farm.find(farm_id)
          FarmChannel.broadcast_to(farm, payload)
        rescue ActiveRecord::RecordNotFound
          nil
        end
      end
    end
  end
end
