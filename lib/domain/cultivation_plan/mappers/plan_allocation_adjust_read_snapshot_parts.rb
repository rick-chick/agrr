# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      # PlanAllocationAdjustReadSnapshot 組み立ての純粋部分（I/O なし）。
      module PlanAllocationAdjustReadSnapshotParts
        module_function

        # @param plan_fields [Array<#id,#name,#area,#daily_fixed_cost>]
        # @param field_cultivations [Array<#field_cultivation_id,#field_id,#crop_id,...>]
        # @return [Array<Domain::CultivationPlan::Dtos::AgrrAdjustFieldSourceRow>]
        def build_field_source_rows(plan_fields:, field_cultivations:)
          cultivations_by_field = field_cultivations.group_by(&:field_id)

          plan_fields.map do |field|
            cultivations = cultivations_by_field[field.id] || []
            source_rows = cultivations.map { |fc| field_cultivation_source_row(fc) }

            Dtos::AgrrAdjustFieldSourceRow.new(
              field_id: field.id,
              field_name: field.name,
              field_area: field.area,
              cultivations: source_rows
            )
          end
        end

        # @param field_cultivation [Object] optimization_result を持つ行
        def field_cultivation_source_row(field_cultivation)
          Dtos::AgrrAdjustFieldCultivationSourceRow.new(
            field_cultivation_id: field_cultivation.field_cultivation_id,
            field_id: field_cultivation.field_id,
            crop_id: field_cultivation.crop_id,
            crop_name: field_cultivation.crop_name,
            variety: field_cultivation.variety,
            area: field_cultivation.area,
            start_date: field_cultivation.start_date,
            completion_date: field_cultivation.completion_date,
            cultivation_days: field_cultivation.cultivation_days,
            estimated_cost: field_cultivation.estimated_cost,
            revenue: revenue_from_optimization_result(field_cultivation.optimization_result),
            accumulated_gdd: accumulated_gdd_from_optimization_result(field_cultivation.optimization_result),
            has_growth_stages: field_cultivation.has_growth_stages
          )
        end
        private_class_method :field_cultivation_source_row

        def revenue_from_optimization_result(opt)
          return 0.0 unless opt.is_a?(Hash)

          (opt["revenue"] || opt["expected_revenue"] || 0.0).to_f
        end

        def accumulated_gdd_from_optimization_result(opt)
          return 0.0 unless opt.is_a?(Hash)

          value = opt["accumulated_gdd"]
          value = opt.dig("raw", "total_gdd") if value.nil?
          value.to_f
        end

        # @param weather_location [Domain::WeatherData::Contracts::WeatherLocationPredictionInput, nil]
        def weather_location_facts(weather_location)
          return {} if weather_location.nil?

          {
            latitude: weather_location.latitude.to_f,
            longitude: weather_location.longitude.to_f,
            elevation: (weather_location.elevation || 0.0).to_f,
            timezone: weather_location.timezone
          }
        end
      end
    end
  end
end
