# frozen_string_literal: true

module Domain
  module InternalJobs
    module Ports
      module SchedulerWeatherFetchSchedulePort
        def schedule_fetch(farm_id:, latitude:, longitude:, start_date:, end_date:, delay_secs:)
          raise NotImplementedError, "#{self.class}#schedule_fetch"
        end

        def flush
          raise NotImplementedError, "#{self.class}#flush"
        end
      end
    end
  end
end
