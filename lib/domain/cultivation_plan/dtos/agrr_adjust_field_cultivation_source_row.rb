# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # AR 読み取り後の 1 作付行（Agrr current allocation 行組み立て用）。
      class AgrrAdjustFieldCultivationSourceRow
        attr_reader :field_cultivation_id,
                    :field_id,
                    :crop_id,
                    :crop_name,
                    :variety,
                    :area,
                    :start_date,
                    :completion_date,
                    :cultivation_days,
                    :estimated_cost,
                    :revenue,
                    :accumulated_gdd,
                    :has_growth_stages

        def initialize(
          field_cultivation_id:,
          field_id:,
          crop_id:,
          crop_name:,
          variety:,
          area:,
          start_date:,
          completion_date:,
          cultivation_days:,
          estimated_cost:,
          revenue:,
          accumulated_gdd:,
          has_growth_stages:
        )
          @field_cultivation_id = field_cultivation_id
          @field_id = field_id
          @crop_id = crop_id.to_s
          @crop_name = crop_name
          @variety = variety
          @area = area
          @start_date = start_date
          @completion_date = completion_date
          @cultivation_days = cultivation_days
          @estimated_cost = estimated_cost
          @revenue = revenue
          @accumulated_gdd = accumulated_gdd
          @has_growth_stages = has_growth_stages
          freeze
        end
      end
    end
  end
end
