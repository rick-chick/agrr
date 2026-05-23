# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class TaskScheduleTimelineMapper
        def self.call(read_model, today:)
          new(read_model, today).call
        end

        def initialize(read_model, today)
          @read_model = read_model
          @today = today
        end

        def call
          Domain::CultivationPlan::Dtos::TaskScheduleTimeline.new(
            plan: @read_model.plan,
            fields: @read_model.fields,
            scheduled_dates: @read_model.scheduled_dates,
            today: @today
          )
        end
      end
    end
  end
end
