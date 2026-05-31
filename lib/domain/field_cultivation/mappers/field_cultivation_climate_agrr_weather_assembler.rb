# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      # プラン保存予測と観測 DB を、栽培期間ベースで AGRR 用 series にまとめる。
      module FieldCultivationClimateAgrrWeatherAssembler
        module_function

        # @param observed_weather_dtos [Array] 日次観測 DTO
        # @param weather_location_meta [Hash] :latitude, :longitude, :elevation, :timezone
        # @return [Hash] AGRR 互換 payload（観測が無ければ cached をそのまま返す）
        def assemble_plan_weather_with_observed(
          cached_weather_payload:,
          observed_weather_dtos:,
          weather_location_meta:,
          cultivation_start_date:,
          cultivation_end_date:,
          today:,
          display_start_date: nil,
          display_end_date: nil
        )
          decision = Policies::FieldCultivationClimateObservedMergeRangePolicy.resolve(
            display_start_date: display_start_date,
            display_end_date: display_end_date,
            cultivation_start_date: cultivation_start_date,
            cultivation_end_date: cultivation_end_date,
            today: today
          )
          return cached_weather_payload if decision.skip?

          observed_dtos = Array(observed_weather_dtos)
          return cached_weather_payload if observed_dtos.empty?

          observed_formatted = FieldCultivationClimateWeatherPayloadMapper.build_observed_agrr_payload(
            weather_location_meta: weather_location_meta,
            observed_weather_dtos: observed_dtos
          )

          FieldCultivationClimateWeatherPayloadMapper.merge_cached_with_observed(
            cached_weather_payload: cached_weather_payload,
            observed_formatted: observed_formatted
          )
        end
      end
    end
  end
end
