# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      class FieldCultivationApiSummarySnapshot
        attr_reader :id,
                    :field_name,
                    :crop_name,
                    :area,
                    :start_date,
                    :completion_date,
                    :cultivation_days,
                    :estimated_cost,
                    :gdd,
                    :status

        def initialize(
          id:,
          field_name:,
          crop_name:,
          area:,
          start_date:,
          completion_date:,
          cultivation_days:,
          estimated_cost:,
          gdd:,
          status:
        )
          @id = id
          @field_name = field_name
          @crop_name = crop_name
          @area = area
          @start_date = start_date
          @completion_date = completion_date
          @cultivation_days = cultivation_days
          @estimated_cost = estimated_cost
          @gdd = gdd
          @status = status
          freeze
        end
      end
    end
  end
end
