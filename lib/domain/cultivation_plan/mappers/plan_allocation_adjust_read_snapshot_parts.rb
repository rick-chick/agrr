# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      # PlanAllocationAdjustReadSnapshot 組み立ての純粋部分（I/O なし）。
      module PlanAllocationAdjustReadSnapshotParts
        module_function

        # @param stored_days [Integer, nil]
        # @param start_date [Date]
        # @param completion_date [Date]
        # @return [Integer]
        def effective_cultivation_days(stored_days:, start_date:, completion_date:)
          return stored_days if stored_days

          (completion_date - start_date).to_i + 1
        end

        # @param crop_stage_count [Integer]
        # @return [Boolean]
        def has_growth_stages?(crop_stage_count:)
          crop_stage_count.to_i.positive?
        end

        # @param estimated_cost [Numeric, nil]
        # @return [Float]
        def effective_estimated_cost(estimated_cost:)
          (estimated_cost || 0.0).to_f
        end

        # @param plan_field_snapshots [Array<#id,#name,#area,#daily_fixed_cost>]
        # @param field_cultivation_snapshots [Array<Dtos::PlanAllocationAdjustFieldCultivationSnapshot>]
        # @return [Array<Dtos::PlanAllocationAdjustFieldSourceSnapshot>]
        def build_field_source_snapshots(plan_field_snapshots:, field_cultivation_snapshots:)
          cultivations_by_field = field_cultivation_snapshots.group_by(&:field_id)

          plan_field_snapshots.map do |field|
            cultivations = cultivations_by_field[field.id] || []
            allocation_snapshots = cultivations.map { |fc| field_cultivation_allocation_snapshot(fc) }

            Dtos::PlanAllocationAdjustFieldSourceSnapshot.new(
              field_id: field.id,
              field_name: field.name,
              field_area: field.area,
              cultivations: allocation_snapshots
            )
          end
        end

        # @param crop_id [Integer]
        # @param crop_name [String]
        # @param groups [Object]
        # @param crop_stage_count [Integer]
        # @param build_agrr_requirement [Proc, nil] 生育ステージありのときだけ呼ばれる
        # @return [Dtos::PlanAllocationAdjustReadSnapshot::PlanCropSnapshot]
        def plan_crop_snapshot(crop_id:, crop_name:, groups:, crop_stage_count:, build_agrr_requirement: nil)
          has_growth = has_growth_stages?(crop_stage_count: crop_stage_count)
          requirement = has_growth && build_agrr_requirement ? build_agrr_requirement.call : nil

          Dtos::PlanAllocationAdjustReadSnapshot::PlanCropSnapshot.new(
            crop_id: crop_id,
            crop_name: crop_name,
            groups: groups,
            has_growth_stages: has_growth,
            agrr_requirement: requirement
          )
        end

        # @param field_cultivation [Dtos::PlanAllocationAdjustFieldCultivationSnapshot]
        def field_cultivation_allocation_snapshot(field_cultivation)
          Dtos::PlanAllocationAdjustFieldCultivationAllocationSnapshot.new(
            field_cultivation_id: field_cultivation.field_cultivation_id,
            field_id: field_cultivation.field_id,
            crop_id: field_cultivation.crop_id,
            crop_name: field_cultivation.crop_name,
            variety: field_cultivation.variety,
            area: field_cultivation.area,
            start_date: field_cultivation.start_date,
            completion_date: field_cultivation.completion_date,
            cultivation_days: effective_cultivation_days(
              stored_days: field_cultivation.stored_cultivation_days,
              start_date: field_cultivation.start_date,
              completion_date: field_cultivation.completion_date
            ),
            estimated_cost: effective_estimated_cost(estimated_cost: field_cultivation.estimated_cost),
            revenue: revenue_from_optimization_result(field_cultivation.optimization_result),
            accumulated_gdd: accumulated_gdd_from_optimization_result(field_cultivation.optimization_result),
            has_growth_stages: has_growth_stages?(crop_stage_count: field_cultivation.crop_stage_count)
          )
        end
        private_class_method :field_cultivation_allocation_snapshot

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
