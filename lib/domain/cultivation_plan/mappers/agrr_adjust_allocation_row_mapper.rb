# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      # 読み取りスナップショットから AgrrCurrentAllocationCalculator 向け field_rows を組み立てる。
      module AgrrAdjustAllocationRowMapper
        module_function

        # @param cultivation_plan_id [Integer]
        # @param field_snapshots [Array<Domain::CultivationPlan::Dtos::PlanAllocationAdjustFieldSourceSnapshot>]
        # @param exclude_ids [Array<Integer>]
        # @return [Hash] AgrrCurrentAllocationCalculator.build と同形
        def build_current_allocation(cultivation_plan_id:, field_snapshots:, exclude_ids: [])
          prepared = Array(field_snapshots).map do |field_snapshot|
            cultivations = field_snapshot.cultivations
            filtered = cultivations.reject { |row| exclude_ids.include?(row.field_cultivation_id) }
              .select(&:has_growth_stages)

            allocations = filtered.map do |snapshot|
              revenue = (snapshot.revenue || 0.0).to_f
              cost = (snapshot.estimated_cost || 0.0).to_f
              growth_days = snapshot.cultivation_days

              {
                allocation_id: snapshot.field_cultivation_id,
                crop_id: snapshot.crop_id,
                crop_name: snapshot.crop_name,
                variety: snapshot.variety,
                area_used: snapshot.area,
                start_date: snapshot.start_date,
                completion_date: snapshot.completion_date,
                growth_days: growth_days,
                accumulated_gdd: (snapshot.accumulated_gdd || 0.0).to_f,
                total_cost: cost,
                expected_revenue: revenue
              }
            end

            {
              field_id: field_snapshot.field_id,
              field_name: field_snapshot.field_name,
              field_area: field_snapshot.field_area,
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
