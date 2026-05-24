# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # 気象・進捗取得前の圃場栽培コンテキスト（永続層からの読取スナップショット）。
      class FieldCultivationClimateContextSnapshot
        attr_reader :field_cultivation_id, :field_name, :crop_name,
                    :start_date, :completion_date,
                    :farm_id, :farm_name, :farm_latitude, :farm_longitude,
                    :plan_id, :plan_type_public, :plan_predicted_weather_present,
                    :prediction_target_end_date, :calculated_planning_end_date,
                    :predicted_weather_data,
                    :crop_id, :base_temperature, :optimal_temperature_range, :stages

        def initialize(
          field_cultivation_id:,
          field_name:,
          crop_name:,
          start_date:,
          completion_date:,
          farm_id:,
          farm_name:,
          farm_latitude:,
          farm_longitude:,
          plan_id:,
          plan_type_public:,
          plan_predicted_weather_present:,
          prediction_target_end_date:,
          calculated_planning_end_date:,
          predicted_weather_data:,
          crop_id:,
          base_temperature:,
          optimal_temperature_range:,
          stages:
        )
          @field_cultivation_id = field_cultivation_id
          @field_name = field_name
          @crop_name = crop_name
          @start_date = start_date
          @completion_date = completion_date
          @farm_id = farm_id
          @farm_name = farm_name
          @farm_latitude = farm_latitude
          @farm_longitude = farm_longitude
          @plan_id = plan_id
          @plan_type_public = plan_type_public
          @plan_predicted_weather_present = plan_predicted_weather_present
          @prediction_target_end_date = prediction_target_end_date
          @calculated_planning_end_date = calculated_planning_end_date
          @predicted_weather_data = predicted_weather_data
          @crop_id = crop_id
          @base_temperature = base_temperature
          @optimal_temperature_range = optimal_temperature_range
          @stages = stages
          freeze
        end
      end
    end
  end
end
