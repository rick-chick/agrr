# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      # 読み取り DTO から AgrrCurrentAllocationCalculator 向け field_rows を組み立てる。
      module AgrrAdjustAllocationRowMapper
        module_function

        # @param cultivation_plan_id [Integer]
        # @param field_rows [Array<Domain::CultivationPlan::Dtos::AgrrAdjustFieldSourceRow>]
        # @param exclude_ids [Array<Integer>]
        # @return [Hash] AgrrCurrentAllocationCalculator.build と同形
        def build_current_allocation(cultivation_plan_id:, field_rows:, exclude_ids: [])
          prepared = Array(field_rows).map do |field_row|
            cultivations = field_row.cultivations
            filtered = cultivations.reject { |row| exclude_ids.include?(row.field_cultivation_id) }
              .select(&:has_growth_stages)

            allocations = filtered.map do |row|
              revenue = (row.revenue || 0.0).to_f
              cost = (row.estimated_cost || 0.0).to_f
              growth_days = row.cultivation_days || ((row.completion_date - row.start_date).to_i + 1)

              {
                allocation_id: row.field_cultivation_id,
                crop_id: row.crop_id,
                crop_name: row.crop_name,
                variety: row.variety,
                area_used: row.area,
                start_date: row.start_date,
                completion_date: row.completion_date,
                growth_days: growth_days,
                accumulated_gdd: (row.accumulated_gdd || 0.0).to_f,
                total_cost: cost,
                expected_revenue: revenue
              }
            end

            {
              field_id: field_row.field_id,
              field_name: field_row.field_name,
              field_area: field_row.field_area,
              allocations: allocations
            }
          end

          Calculators::AgrrCurrentAllocationCalculator.build(
            cultivation_plan_id: cultivation_plan_id,
            field_rows: prepared
          )
        end
      end
    end
  end
end
