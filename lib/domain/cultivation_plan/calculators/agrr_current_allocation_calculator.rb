# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Calculators
      # Pure assembly of the AGRR "current allocation" payload from edge-prepared rows (no AR).
      class AgrrCurrentAllocationCalculator
        # @param cultivation_plan_id [Integer]
        # @param field_rows [Array<Hash>] Each row: :field_id, :field_name, :field_area, :allocations
        # @option row [Array<Hash>] :allocations — :allocation_id, :crop_id, :crop_name, :variety,
        #   :area_used, :start_date, :completion_date, :growth_days, :accumulated_gdd,
        #   :total_cost, :expected_revenue
        # @return [Hash] Same shape as the former { optimization_result: { ... } } from the concern
        def self.build(cultivation_plan_id:, field_rows:)
          field_schedules = Array(field_rows).map do |row|
            field_area = row.fetch(:field_area)
            allocations = Array(row[:allocations]).map do |a|
              revenue = (a[:expected_revenue] || 0.0).to_f
              cost = (a[:total_cost] || 0.0).to_f
              profit = revenue - cost
              {
                allocation_id: a.fetch(:allocation_id),
                crop_id: a.fetch(:crop_id).to_s,
                crop_name: a.fetch(:crop_name),
                variety: a[:variety],
                area_used: a.fetch(:area_used),
                start_date: format_optional_date(a[:start_date]),
                completion_date: format_optional_date(a[:completion_date]),
                growth_days: a.fetch(:growth_days),
                accumulated_gdd: (a[:accumulated_gdd] || 0.0).to_f,
                total_cost: cost,
                expected_revenue: revenue,
                profit: profit
              }
            end

            field_total_cost = allocations.sum { |x| x[:total_cost] }
            field_total_revenue = allocations.sum { |x| x[:expected_revenue] }
            field_total_profit = allocations.sum { |x| x[:profit] }
            field_area_used = allocations.sum { |x| x[:area_used].to_f }
            field_utilization_rate = field_area_used / field_area.to_f

            {
              field_id: row.fetch(:field_id).to_s,
              field_name: row.fetch(:field_name),
              total_cost: field_total_cost,
              total_revenue: field_total_revenue,
              total_profit: field_total_profit,
              utilization_rate: field_utilization_rate,
              allocations: allocations
            }
          end

          total_cost = field_schedules.sum { |fs| fs[:total_cost] }
          total_revenue = field_schedules.sum { |fs| fs[:total_revenue] }
          total_profit = field_schedules.sum { |fs| fs[:total_profit] }

          {
            optimization_result: {
              optimization_id: "opt_#{cultivation_plan_id}",
              total_cost: total_cost,
              total_revenue: total_revenue,
              total_profit: total_profit,
              field_schedules: field_schedules
            }
          }
        end

        def self.format_optional_date(value)
          return nil if value.nil?

          value.respond_to?(:to_date) ? value.to_date.to_s : value.to_s
        end
        private_class_method :format_optional_date
      end
    end
  end
end
