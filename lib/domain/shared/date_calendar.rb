# frozen_string_literal: true

module Domain
  module Shared
    # ActiveSupport の Date 拡張（beginning_of_month / end_of_year 等）に依存しないカレンダー補助。
    module DateCalendar
      module_function

      def beginning_of_month(date)
        Date.new(date.year, date.month, 1)
      end

      # @return [Date] 当月最終日（Ruby 標準: 日にちに -1 を指定）
      def end_of_month(date)
        Date.new(date.year, date.month, -1)
      end

      def beginning_of_year(date)
        Date.new(date.year, 1, 1)
      end

      def end_of_year(date)
        Date.new(date.year, 12, 31)
      end

      # 翌月1日（当月任意の日から）
      def first_day_of_next_calendar_month(date)
        end_of_month(date) + 1
      end
    end
  end
end
