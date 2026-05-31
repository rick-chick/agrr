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
          final_cumulative_gdd_required = final_cumulative_gdd_required_from_stages(context.stages)

          daily_gdd, baseline_gdd, filtered_records, progress_records = build_daily_gdd(
            progress_result,
            weather_records,
            context.start_date,
            context.completion_date,
            base_temp,
            final_cumulative_gdd_required: final_cumulative_gdd_required
          )

          chart_weather_records = align_weather_records_to_gdd_span(weather_records, daily_gdd)

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
            weather_data: chart_weather_records.map do |datum|
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

        def final_cumulative_gdd_required_from_stages(stages)
          stages = Array(stages)
          return nil if stages.empty?

          stages.filter_map do |stage|
            stage[:cumulative_gdd_required] || stage["cumulative_gdd_required"]
          end.max
        end

        def build_daily_gdd(
          progress_result,
          weather_data_records,
          start_date,
          completion_date,
          base_temp,
          final_cumulative_gdd_required: nil
        )
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

          truncate_daily_gdd_at_requirement!(
            daily_gdd,
            final_cumulative_gdd_required: final_cumulative_gdd_required
          )

          [ daily_gdd, baseline_gdd, filtered_records, progress_records ]
        end

        def align_weather_records_to_gdd_span(weather_records, daily_gdd)
          weather_records = Array(weather_records)
          return weather_records if daily_gdd.empty?

          first_date = parse_gdd_datum_date(daily_gdd.first)
          last_date = parse_gdd_datum_date(daily_gdd.last)
          return weather_records unless first_date && last_date

          weather_records.select do |datum|
            datum_date = parse_gdd_datum_date(datum)
            next false unless datum_date

            datum_date >= first_date && datum_date <= last_date
          end
        end

        def parse_gdd_datum_date(datum)
          date_value = datum[:date] || datum["date"]
          return nil unless date_value

          Date.parse(date_value.to_s)
        rescue ArgumentError, TypeError
          nil
        end

        def truncate_daily_gdd_at_requirement!(daily_gdd, final_cumulative_gdd_required:)
          return daily_gdd unless final_cumulative_gdd_required&.positive?
          return daily_gdd if daily_gdd.empty?

          completion_index = daily_gdd.find_index do |datum|
            datum[:cumulative_gdd].to_f >= final_cumulative_gdd_required
          end
          return daily_gdd unless completion_index

          daily_gdd.replace(daily_gdd[0..completion_index])
          daily_gdd
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
