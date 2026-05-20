# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class TaskScheduleTimeline
        attr_reader :plan, :fields, :scheduled_dates, :today

        def initialize(plan:, fields:, scheduled_dates:, today:)
          @plan = plan
          @fields = fields
          @scheduled_dates = scheduled_dates
          @today = today
        end
      end
    end
  end
end
