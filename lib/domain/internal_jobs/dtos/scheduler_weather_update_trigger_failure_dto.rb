# frozen_string_literal: true

module Domain
  module InternalJobs
    module Dtos
      class SchedulerWeatherUpdateTriggerFailureDto
        attr_reader :message

        def initialize(message:)
          @message = message.to_s
        end
      end
    end
  end
end
