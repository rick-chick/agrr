# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module PrivatePlanIndexRowsMapper
        module_function

        def plan_row_snapshots_with_counts(plan_snapshots, crops_count_hash:, fields_count_hash:)
          plan_snapshots.map do |snapshot|
            Dtos::PlanRowSnapshot.new(
              id: snapshot.id,
              farm_display_name: snapshot.farm_display_name,
              total_area: snapshot.total_area,
              crops_count: crops_count_hash[snapshot.id] || 0,
              fields_count: fields_count_hash[snapshot.id] || 0,
              status: snapshot.status,
              display_name: snapshot.display_name,
              created_at: snapshot.created_at
            )
          end
        end

        # @param plan_rows [Array<Dtos::PlanRowSnapshot>]
        # @return [Array<Dtos::PrivatePlanIndexPlanRow>]
        def to_index_rows(plan_rows)
          plan_rows.map do |row|
            Dtos::PrivatePlanIndexPlanRow.new(
              id: row.id,
              farm_display_name: row.farm_display_name,
              total_area: row.total_area,
              crops_count: row.crops_count,
              fields_count: row.fields_count,
              status: row.status,
              display_name: row.display_name,
              created_at: row.created_at
            )
          end
        end
      end
    end
  end
end
