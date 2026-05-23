# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CultivationPlanWorkbenchCultivationRow
        attr_reader :id, :field_id, :field_name, :crop_id, :crop_name, :area,
                    :start_date, :completion_date, :cultivation_days, :estimated_cost,
                    :revenue, :profit, :status

        def initialize(
          id:, field_id:, field_name:, crop_id:, crop_name:, area:,
          start_date:, completion_date:, cultivation_days:, estimated_cost:,
          revenue:, profit:, status:
        )
          @id = id
          @field_id = field_id
          @field_name = field_name
          @crop_id = crop_id
          @crop_name = crop_name
          @area = area
          @start_date = start_date
          @completion_date = completion_date
          @cultivation_days = cultivation_days
          @estimated_cost = estimated_cost
          @revenue = revenue
          @profit = profit
          @status = status
          freeze
        end
      end
    end
  end
end
