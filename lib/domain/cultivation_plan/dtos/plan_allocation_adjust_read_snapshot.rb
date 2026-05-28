# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # plan_allocation_adjust 用: Gateway が返す計画読取スナップショット（唯一の読取契約 DTO）。
      class PlanAllocationAdjustReadSnapshot
        PlanFieldEntry = Struct.new(
          :id,
          :name,
          :area,
          :daily_fixed_cost,
          keyword_init: true
        )

        PlanCropEntry = Struct.new(
          :crop_id,
          :crop_name,
          :groups,
          :has_growth_stages,
          :agrr_requirement,
          keyword_init: true
        )

        attr_reader :plan_id,
                    :field_source_rows,
                    :plan_fields,
                    :plan_crop_entries,
                    :cultivation_planning_periods,
                    :planning_period_boundaries,
                    :cultivation_plan_weather_dto,
                    :weather_prediction_targets,
                    :weather_location_facts,
                    :farm_without_weather_location

        def initialize(
          plan_id:,
          field_source_rows:,
          plan_fields:,
          plan_crop_entries:,
          cultivation_planning_periods:,
          planning_period_boundaries:,
          cultivation_plan_weather_dto:,
          weather_prediction_targets:,
          weather_location_facts:,
          farm_without_weather_location:
        )
          @plan_id = plan_id
          @field_source_rows = Array(field_source_rows).freeze
          @plan_fields = Array(plan_fields).freeze
          @plan_crop_entries = Array(plan_crop_entries).freeze
          @cultivation_planning_periods = Array(cultivation_planning_periods).freeze
          @planning_period_boundaries = planning_period_boundaries
          @cultivation_plan_weather_dto = cultivation_plan_weather_dto
          @weather_prediction_targets = weather_prediction_targets
          @weather_location_facts = weather_location_facts.freeze
          @farm_without_weather_location = farm_without_weather_location
          freeze
        end

        def farm_without_weather_location?
          farm_without_weather_location
        end
      end
    end
  end
end
