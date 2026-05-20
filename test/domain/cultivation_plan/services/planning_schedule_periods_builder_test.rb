# frozen_string_literal: true

require "domain_lib_test_helper"

class PlanningSchedulePeriodsBuilderTest < DomainLibTestCase
  Translator = Struct.new(:dummy) do
    def l(date, format:)
      date.strftime(format)
    end

    def t(key, **opts)
      case key.to_s
      when "controllers.planning_schedules.half.first" then "前半"
      when "controllers.planning_schedules.half.second" then "後半"
      else
        key.to_s
      end
    end
  end

  setup do
    @builder = Domain::CultivationPlan::Services::PlanningSchedulePeriodsBuilder.new(translator: Translator.new(nil))
  end

  test "month granularity walks partial start month then full months until end_date" do
    start_date = Date.new(2024, 3, 15)
    end_date = Date.new(2024, 5, 20)
    periods = @builder.call(start_date: start_date, end_date: end_date, granularity: "month")

    assert_equal 3, periods.size
    assert_equal Date.new(2024, 3, 15), periods[0][:start_date]
    assert_equal Date.new(2024, 3, 31), periods[0][:end_date]
    assert_equal Date.new(2024, 4, 1), periods[1][:start_date]
    assert_equal Date.new(2024, 4, 30), periods[1][:end_date]
    assert_equal Date.new(2024, 5, 1), periods[2][:start_date]
    assert_equal Date.new(2024, 5, 20), periods[2][:end_date]
  end

  test "month granularity crosses year boundary" do
    periods = @builder.call(
      start_date: Date.new(2024, 12, 1),
      end_date: Date.new(2025, 1, 15),
      granularity: "month"
    )

    assert_equal 2, periods.size
    assert_equal Date.new(2024, 12, 1), periods[0][:start_date]
    assert_equal Date.new(2024, 12, 31), periods[0][:end_date]
    assert_equal Date.new(2025, 1, 1), periods[1][:start_date]
    assert_equal Date.new(2025, 1, 15), periods[1][:end_date]
  end

  test "quarter granularity returns bounded segments within end_date" do
    periods = @builder.call(
      start_date: Date.new(2024, 1, 10),
      end_date: Date.new(2024, 4, 5),
      granularity: "quarter"
    )

    assert_equal 2, periods.size
    assert_equal Date.new(2024, 1, 10), periods[0][:start_date]
    assert_equal Date.new(2024, 3, 31), periods[0][:end_date]
    assert_equal "2024 Q1", periods[0][:label]
    assert_equal Date.new(2024, 4, 1), periods[1][:start_date]
    assert_equal Date.new(2024, 4, 5), periods[1][:end_date]
  end

  test "half granularity first half of year" do
    periods = @builder.call(
      start_date: Date.new(2024, 2, 1),
      end_date: Date.new(2024, 5, 10),
      granularity: "half"
    )

    assert_equal 1, periods.size
    assert_equal Date.new(2024, 2, 1), periods[0][:start_date]
    assert_equal Date.new(2024, 5, 10), periods[0][:end_date]
  end
end
