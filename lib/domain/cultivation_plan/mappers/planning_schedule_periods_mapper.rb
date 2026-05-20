# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      # 作付計画表の期間行生成（表示粒度）。時刻は呼び出し側が Date を渡す。
      module PlanningSchedulePeriodsMapper
        module_function

        # @param translator [I18nRansack::Translate]
        # @param start_date [Date]
        # @param end_date [Date]
        # @param granularity [String] "month", "quarter", "half"
        # @return [Array<Hash>] :label, :start_date, :end_date
        def build(translator:, start_date:, end_date:, granularity:)
          periods = []

          case granularity
          when "month"
            current = start_date
            while current <= end_date
              period_end = [current.end_of_month, end_date].min
              periods << {
                label: translator.l(current, format: "%Y年%m月"),
                start_date: current,
                end_date: period_end
              }
              current = current.next_month.beginning_of_month
            end
          when "quarter"
            current = start_date
            while current <= end_date
              quarter_num = ((current.month - 1) / 3) + 1
              quarter_end_month = quarter_num * 3
              quarter_end = [Date.new(current.year, quarter_end_month, -1), end_date].min
              periods << {
                label: "#{current.year} Q#{quarter_num}",
                start_date: current,
                end_date: quarter_end
              }
              if quarter_end_month == 12
                current = Date.new(current.year + 1, 1, 1)
              else
                current = Date.new(current.year, quarter_end_month + 1, 1)
              end
            end
          when "half"
            current = start_date
            while current <= end_date
              half_end_month = current.month <= 6 ? 6 : 12
              half_end = [Date.new(current.year, half_end_month, -1), end_date].min
              half_key = current.month <= 6 ? "first" : "second"
              half_label = translator.t("controllers.planning_schedules.half.#{half_key}")
              periods << {
                label: translator.t(
                  "controllers.planning_schedules.half_label",
                  year: current.year,
                  half: half_label
                ),
                start_date: current,
                end_date: half_end
              }
              if current.month <= 6
                current = Date.new(current.year, 7, 1)
              else
                current = Date.new(current.year + 1, 1, 1)
              end
            end
          end

          periods
        end
      end
    end
  end
end
