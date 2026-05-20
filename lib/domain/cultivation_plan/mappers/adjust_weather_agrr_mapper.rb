# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      # AdjustWithDbWeather* DTO を agrr adjust / candidates が期待する Array<Hash> / 単一 Hash に戻す。
      module AdjustWeatherAgrrMapper
        module_function

        # @param dto [Domain::CultivationPlan::Dtos::AdjustWithDbWeatherCurrentAllocation]
        # @return [Hash]
        def current_allocation_to_agrr_hash(dto)
          return {} if dto.optimization_result.nil?

          opt = dto.optimization_result
          {
            optimization_result: {
              optimization_id: opt.optimization_id,
              total_cost: opt.total_cost,
              total_revenue: opt.total_revenue,
              total_profit: opt.total_profit,
              field_schedules: opt.field_schedules.map { |fs| field_schedule_to_hash(fs) }
            }
          }
        end

        # @param dto [Domain::CultivationPlan::Dtos::AdjustWithDbWeatherFieldsConfig]
        # @return [Array<Hash>]
        def fields_config_to_agrr_array(dto)
          dto.rows.map do |r|
            {
              field_id: r.field_id,
              name: r.name,
              area: r.area,
              daily_fixed_cost: r.daily_fixed_cost
            }
          end
        end

        # @param dto [Domain::CultivationPlan::Dtos::AdjustWithDbWeatherCropConfigs]
        # @return [Array<Hash>]
        def crops_config_to_agrr_array(dto)
          dto.rows.map(&:mutable_document_dup)
        end

        # @param dto [Domain::CultivationPlan::Dtos::AdjustWithDbWeatherInteractionRulesConfig]
        # @return [Array<Hash>]
        def interaction_rules_to_agrr_array(dto)
          dto.rows.map do |r|
            {
              rule_id: r.rule_id,
              rule_type: r.rule_type,
              source_group: r.source_group,
              target_group: r.target_group,
              impact_ratio: r.impact_ratio,
              is_directional: r.is_directional,
              description: r.description
            }
          end
        end

        def field_schedule_to_hash(fs)
          {
            field_id: fs.field_id,
            field_name: fs.field_name,
            total_cost: fs.total_cost,
            total_revenue: fs.total_revenue,
            total_profit: fs.total_profit,
            utilization_rate: fs.utilization_rate,
            allocations: fs.allocations.map { |a| allocation_row_to_hash(a) }
          }
        end
        private_class_method :field_schedule_to_hash

        def allocation_row_to_hash(a)
          {
            allocation_id: a.allocation_id,
            crop_id: a.crop_id,
            crop_name: a.crop_name,
            variety: a.variety,
            area_used: a.area_used,
            start_date: a.start_date,
            completion_date: a.completion_date,
            growth_days: a.growth_days,
            accumulated_gdd: a.accumulated_gdd,
            total_cost: a.total_cost,
            expected_revenue: a.expected_revenue,
            profit: a.profit
          }
        end
        private_class_method :allocation_row_to_hash
      end
    end
  end
end
