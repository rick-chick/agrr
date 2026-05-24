# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # Gateway 読取直後の圃場栽培・計画メタ（作物解決・ステージ組立前）。
      class FieldCultivationClimateSourceSnapshot
        attr_reader :field_cultivation_id, :field_name, :crop_name,
                    :start_date, :completion_date,
                    :farm_id, :farm_name, :farm_latitude, :farm_longitude,
                    :weather_location_id, :weather_location_timezone,
                    :plan_id, :plan_type_public,
                    :prediction_target_end_date, :calculated_planning_end_date,
                    :predicted_weather_data, :plan_crop_crop_id

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
          weather_location_id:,
          weather_location_timezone:,
          plan_id:,
          plan_type_public:,
          prediction_target_end_date:,
          calculated_planning_end_date:,
          predicted_weather_data:,
          plan_crop_crop_id:
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
          @weather_location_id = weather_location_id
          @weather_location_timezone = weather_location_timezone
          @plan_id = plan_id
          @plan_type_public = plan_type_public
          @prediction_target_end_date = prediction_target_end_date
          @calculated_planning_end_date = calculated_planning_end_date
          @predicted_weather_data = predicted_weather_data
          @plan_crop_crop_id = plan_crop_crop_id
          freeze
        end
      end
    end
  end
end
