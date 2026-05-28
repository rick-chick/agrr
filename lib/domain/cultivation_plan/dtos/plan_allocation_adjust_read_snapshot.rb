# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # plan_allocation_adjust 用: Gateway が返す計画読取スナップショット（唯一の読取契約 DTO）。
      class PlanAllocationAdjustReadSnapshot
        PlanFieldSnapshot = Struct.new(
          :id,
          :name,
          :area,
          :daily_fixed_cost,
          keyword_init: true
        )

        PlanCropSnapshot = Struct.new(
          :crop_id,
          :crop_name,
          :groups,
          :has_growth_stages,
          :agrr_requirement,
          keyword_init: true
        )

        attr_reader :plan_id,
                    :field_source_snapshots,
                    :plan_field_snapshots,
                    :plan_crop_snapshots,
                    :cultivation_planning_periods,
                    :planning_period_boundaries,
                    :cultivation_plan_weather_dto,
                    :weather_prediction_targets,
                    :weather_location_facts,
                    :farm_without_weather_location

        def initialize(
          plan_id:,
          field_source_snapshots:,
          plan_field_snapshots:,
          plan_crop_snapshots:,
          cultivation_planning_periods:,
          planning_period_boundaries:,
          cultivation_plan_weather_dto:,
          weather_prediction_targets:,
          weather_location_facts:,
          farm_without_weather_location:
        )
          @plan_id = plan_id
          @field_source_snapshots = Array(field_source_snapshots).freeze
          @plan_field_snapshots = Array(plan_field_snapshots).freeze
          @plan_crop_snapshots = Array(plan_crop_snapshots).freeze
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
