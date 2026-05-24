# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      module FieldCultivationClimateDataMapper
        module_function

        # @param context [Domain::FieldCultivation::Dtos::FieldCultivationClimateContextSnapshot]
        # @param weather_records [Array<Hash>]
        # @param progress_result [Hash]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationClimateDataOutput]
        def build_output(context:, weather_records:, progress_result:)
          weather_records = Array(weather_records)
          base_temp = context.base_temperature
          daily_gdd, baseline_gdd, filtered_records, progress_records = build_daily_gdd(
            progress_result,
            weather_records,
            context.start_date,
            context.completion_date,
            base_temp
          )

          Dtos::FieldCultivationClimateDataOutput.new(
            field_cultivation: {
              id: context.field_cultivation_id,
              field_name: context.field_name,
              crop_name: context.crop_name,
              start_date: context.start_date,
              completion_date: context.completion_date
            },
            farm: {
              id: context.farm_id,
              name: context.farm_name,
              latitude: context.farm_latitude,
              longitude: context.farm_longitude
            },
            crop_requirements: {
              base_temperature: base_temp,
              optimal_temperature_range: context.optimal_temperature_range
            },
            weather_data: weather_records.map do |datum|
              {
                "date" => datum["date"],
                "temperature_max" => datum["temperature_max"],
                "temperature_min" => datum["temperature_min"],
                "temperature_mean" => datum["temperature_mean"]
              }
            end,
            gdd_data: daily_gdd,
            stages: context.stages,
            progress_result: progress_result,
            debug_info: {
              baseline_gdd: baseline_gdd,
              progress_records_count: progress_records.length,
              filtered_records_count: filtered_records.length,
              using_agrr_progress: progress_records.any?,
              sample_raw_data: progress_records.first(3)
            }
          )
        end

        def extract_weather_records(weather_payload, start_date, end_date)
          return [] unless weather_payload && weather_payload["data"]

          weather_payload["data"].filter_map do |datum|
            next unless datum

            time_value = datum["time"] || datum["date"]
            next unless time_value

            datum_date = Date.parse(time_value)
            next unless datum_date.between?(start_date, end_date)

            temp_mean = datum["temperature_2m_mean"]
            if temp_mean.nil? && datum["temperature_2m_max"] && datum["temperature_2m_min"]
              temp_mean = (datum["temperature_2m_max"] + datum["temperature_2m_min"]) / 2.0
            end

            {
              "date" => time_value,
              "temperature_max" => datum.fetch("temperature_2m_max", datum[:temperature_2m_max] || nil),
              "temperature_min" => datum.fetch("temperature_2m_min", datum[:temperature_2m_min] || nil),
              "temperature_mean" => temp_mean
            }
          rescue ArgumentError, TypeError
            nil
          end
        end

        def build_daily_gdd(progress_result, weather_data_records, start_date, completion_date, base_temp)
          weather_data_records = Array(weather_data_records)
          progress_records = progress_result["progress_records"] || []
          baseline_gdd = 0.0
          filtered_records = []
          daily_gdd = []

          if progress_records.empty?
            daily_gdd = calculate_gdd_manually(weather_data_records, base_temp)
          else
            filtered_records = progress_records.select do |record|
              record_date = Date.parse(record["date"])
              (start_date..completion_date).cover?(record_date)
            rescue ArgumentError, TypeError
              false
            end

            start_index = progress_records.index do |record|
              Date.parse(record["date"]) == start_date
            rescue ArgumentError, TypeError
              false
            end
            baseline_gdd = start_index && start_index.positive? ? (progress_records[start_index - 1]["cumulative_gdd"] || 0.0) : 0.0

            filtered_records.each_with_index do |day, index|
              current_cumulative_raw = day["cumulative_gdd"] || 0.0
              current_cumulative = current_cumulative_raw - baseline_gdd
              prev_cumulative = index.positive? ? (filtered_records[index - 1]["cumulative_gdd"] - baseline_gdd) : 0.0
              daily_gdd_value = current_cumulative - prev_cumulative

              daily_gdd << {
                date: day["date"],
                gdd: daily_gdd_value.round(2),
                cumulative_gdd: current_cumulative.round(2),
                temperature: nil,
                current_stage: day["stage_name"]
              }
            end
          end

          [ daily_gdd, baseline_gdd, filtered_records, progress_records ]
        end

        def calculate_gdd_manually(weather_data_records, base_temp)
          daily_gdd = []
          cumulative_gdd = 0.0

          weather_data_records.each do |datum|
            avg_temp = if datum["temperature_mean"]
              datum["temperature_mean"]
            elsif datum["temperature_max"] && datum["temperature_min"]
              (datum["temperature_max"] + datum["temperature_min"]) / 2.0
            end
            next unless avg_temp

            gdd_value = [ avg_temp - base_temp, 0 ].max
            cumulative_gdd += gdd_value

            daily_gdd << {
              date: datum["date"],
              gdd: gdd_value.round(2),
              cumulative_gdd: cumulative_gdd.round(2),
              temperature: avg_temp.round(2),
              current_stage: nil
            }
          end

          daily_gdd
        end
      end
    end
  end
end
