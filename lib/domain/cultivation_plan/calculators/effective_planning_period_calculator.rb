# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Calculators
      class EffectivePlanningPeriodCalculator
        # @param current_allocation [Hash]
        # @param moves [Array<Hash>]
        # @param cultivation_periods [Array<Hash>] :start_date / :completion_date (Date)
        # @param planning_start_date [Date, nil]
        # @param planning_end_date [Date, nil]
        # @param as_of [Date]
        # @return [Array<Date, Date>]
        def self.calculate(current_allocation:, moves:, cultivation_periods:, planning_start_date:, planning_end_date:, as_of:)
          all_dates = []
          append_allocation_dates(all_dates, current_allocation)
          append_move_dates(all_dates, moves)

          if all_dates.empty?
            cultivation_periods.each do |cultivation|
              all_dates << cultivation[:start_date] if cultivation[:start_date]
              all_dates << cultivation[:completion_date] if cultivation[:completion_date]
            end
          end

          if all_dates.any?
            min_date = all_dates.min
            max_date = all_dates.max
            # Pure Date math (no ActiveSupport duration / ambient time — ARCHITECTURE.md domain 4).
            start_anchor = min_date - 365
            effective_start = Date.new(start_anchor.year, 1, 1)
            end_anchor = max_date + 365
            effective_end = Date.new(end_anchor.year, 12, 31)
          else
            effective_start = planning_start_date || as_of
            effective_end = planning_end_date || two_years_later_end_of_year(effective_start)
            effective_end = two_years_later_end_of_year(effective_start) if effective_start > effective_end
          end

          [effective_start, effective_end]
        end

        def self.append_allocation_dates(all_dates, current_allocation)
          field_schedules = current_allocation.dig(:optimization_result, :field_schedules)
          return unless field_schedules

          field_schedules.each do |field_schedule|
            field_schedule[:allocations]&.each do |allocation|
              append_date(all_dates, allocation[:start_date], field: :start_date, allocation_id: allocation[:allocation_id])
              append_date(all_dates, allocation[:completion_date], field: :completion_date, allocation_id: allocation[:allocation_id])
            end
          end
        end
        private_class_method :append_allocation_dates

        def self.append_move_dates(all_dates, moves)
          Array(moves).each do |move|
            append_date(all_dates, move[:to_start_date], field: :to_start_date, move: move)
          end
        end
        private_class_method :append_move_dates

        def self.two_years_later_end_of_year(date)
          advanced = date >> 24
          Date.new(advanced.year, 12, 31)
        end
        private_class_method :two_years_later_end_of_year

        def self.append_date(all_dates, raw_value, field:, allocation_id: nil, move: nil)
          return if raw_value.nil?

          parsed =
            case raw_value
            when Date then raw_value
            when Time then raw_value.to_date
            else
              Date.parse(raw_value.to_s)
            end
          all_dates << parsed
        rescue ArgumentError
          raise Domain::CultivationPlan::Errors::EffectivePlanningPeriodInvalidDateError.new(
            raw_value: raw_value,
            field: field,
            allocation_id: allocation_id,
            move: move
          )
        end
        private_class_method :append_date
      end
    end
  end
end
