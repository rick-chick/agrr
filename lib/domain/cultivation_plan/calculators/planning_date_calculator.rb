# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Calculators
      class PlanningDateCalculator
        # @param as_of [Date]
        def self.calculate_public_planning_dates(as_of:)
          {
            start_date: as_of,
            end_date: Date.new(as_of.year + 1, 12, 31)
          }
        end

        def self.normalize_decimal(value)
          return nil if value.nil?
          decimal = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
          decimal.to_s("F")
        end

        # @param cultivation_periods [Array<Hash>] 各要素は :start_date / :completion_date（Date）
        # @param as_of [Date] 期間リストが空のときの「今年」の基準（adapter が注入）
        def self.calculate_plan_year_from_cultivations(cultivation_periods:, logger:, as_of:)
          periods = normalized_periods(cultivation_periods)

          if periods.empty?
            logger.info "⚠️ [PlanSaveService] No field_cultivations found, using as_of year: #{as_of.year}"
            return as_of.year
          end

          midpoints = periods.map do |cultivation|
            start_date = cultivation[:start_date]
            completion_date = cultivation[:completion_date]
            days_diff = (completion_date - start_date).to_i
            start_date + days_diff / 2
          end

          julian_days = midpoints.map(&:jd)
          avg_julian_day = julian_days.sum / julian_days.size
          avg_date = Date.jd(avg_julian_day.round)
          plan_year = avg_date.year

          logger.debug "📊 [PlanSaveService] Field cultivations count: #{periods.size}"
          logger.debug "📊 [PlanSaveService] Average midpoint date: #{avg_date}"
          logger.debug "📊 [PlanSaveService] Calculated plan_year: #{plan_year}"

          plan_year
        end

        # @param cultivation_periods [Array<Hash>] :start_date / :completion_date
        # @param as_of [Date] 期間リストが空のときのデフォルト通年窓の基準
        def self.calculate_planning_dates_from_cultivations(cultivation_periods:, logger:, as_of:)
          periods = normalized_periods(cultivation_periods)

          if periods.empty?
            logger.info "⚠️ [PlanSaveService] No field_cultivations found, using default 2-year window from as_of: #{as_of}"
            return {
              start_date: Date.new(as_of.year, 1, 1),
              end_date: Date.new(as_of.year + 1, 12, 31)
            }
          end

          start_dates = periods.map { |p| p[:start_date] }.compact
          end_dates = periods.map { |p| p[:completion_date] }.compact

          min_start_date = start_dates.min
          max_end_date = end_dates.max

          planning_start_date = Date.new(min_start_date.year, 1, 1)
          planning_end_date = Date.new(max_end_date.year, 12, 31)

          logger.debug "📊 [PlanSaveService] Field cultivations count: #{periods.size}"
          logger.debug "📊 [PlanSaveService] Min start date: #{min_start_date}, Max end date: #{max_end_date}"
          logger.debug "📊 [PlanSaveService] Calculated planning dates: #{planning_start_date} to #{planning_end_date}"

          {
            start_date: planning_start_date,
            end_date: planning_end_date
          }
        end

        def self.calculate_planning_dates(plan_year)
          {
            start_date: Date.new(plan_year, 1, 1),
            end_date: Date.new(plan_year + 1, 12, 31)
          }
        end

        def self.normalized_periods(cultivation_periods)
          Array(cultivation_periods).filter_map do |row|
            next unless row.is_a?(Hash)

            sd = row[:start_date] || row["start_date"]
            cd = row[:completion_date] || row["completion_date"]
            next if sd.nil? || cd.nil?

            { start_date: sd, completion_date: cd }
          end
        end
        private_class_method :normalized_periods
      end
    end
  end
end
