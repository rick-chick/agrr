# frozen_string_literal: true

module Adapters
  module Shared
    module Ports
      # Time.zone 上の「今日」（Infrastructure Port 実装）。
      # interface: Domain::Shared::Ports::ClockPort
      class RailsClockAdapter
        include Domain::Shared::Ports::ClockPort

        def today
          Time.zone.today
        end

        def now
          Time.zone.now
        end
      end
    end
  end
end
