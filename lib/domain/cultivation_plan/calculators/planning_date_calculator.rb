# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Calculators
      class PlanningDateCalculator
        def self.normalize_decimal(value)
          return nil if value.nil?
          decimal = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
          decimal.to_s("F")
        end

        # 作付け期間の平均から年度を算出（既存データ用）
        def self.calculate_plan_year_from_cultivations(reference_plan)
          field_cultivations = reference_plan.field_cultivations.where.not(start_date: nil, completion_date: nil)

          if field_cultivations.empty?
            Rails.logger.info "⚠️ [PlanSaveService] No field_cultivations found, using current year: #{Date.current.year}"
            return Date.current.year
          end

          midpoints = field_cultivations.map do |cultivation|
            start_date = cultivation.start_date
            completion_date = cultivation.completion_date
            days_diff = (completion_date - start_date).to_i
            start_date + days_diff / 2
          end

          julian_days = midpoints.map(&:jd)
          avg_julian_day = julian_days.sum / julian_days.size
          avg_date = Date.jd(avg_julian_day.round)
          plan_year = avg_date.year

          Rails.logger.debug "📊 [PlanSaveService] Field cultivations count: #{field_cultivations.count}"
          Rails.logger.debug "📊 [PlanSaveService] Average midpoint date: #{avg_date}"
          Rails.logger.debug "📊 [PlanSaveService] Calculated plan_year: #{plan_year}"

          plan_year
        end

        # 作付け期間から計画期間を計算（通年計画用）
        def self.calculate_planning_dates_from_cultivations(reference_plan)
          field_cultivations = reference_plan.field_cultivations.where.not(start_date: nil, completion_date: nil)

          if field_cultivations.empty?
            Rails.logger.info "⚠️ [PlanSaveService] No field_cultivations found, using default 2-year period from current date"
            return {
              start_date: Date.current.beginning_of_year,
              end_date: Date.new(Date.current.year + 1, 12, 31)
            }
          end

          start_dates = field_cultivations.pluck(:start_date).compact
          end_dates = field_cultivations.pluck(:completion_date).compact

          min_start_date = start_dates.min
          max_end_date = end_dates.max

          planning_start_date = min_start_date.beginning_of_year
          planning_end_date = max_end_date.end_of_year

          Rails.logger.debug "📊 [PlanSaveService] Field cultivations count: #{field_cultivations.count}"
          Rails.logger.debug "📊 [PlanSaveService] Min start date: #{min_start_date}, Max end date: #{max_end_date}"
          Rails.logger.debug "📊 [PlanSaveService] Calculated planning dates: #{planning_start_date} to #{planning_end_date}"

          {
            start_date: planning_start_date,
            end_date: planning_end_date
          }
        end
      end
    end
  end
end
