# frozen_string_literal: true

require "domain_lib_test_helper"

class DomainSharedDateCalendarTest < DomainLibTestCase
  test "beginning_of_month" do
    d = Date.new(2024, 6, 15)
    assert_equal Date.new(2024, 6, 1), Domain::Shared::DateCalendar.beginning_of_month(d)
  end

  test "end_of_month" do
    assert_equal Date.new(2024, 2, 29), Domain::Shared::DateCalendar.end_of_month(Date.new(2024, 2, 1))
    assert_equal Date.new(2023, 2, 28), Domain::Shared::DateCalendar.end_of_month(Date.new(2023, 2, 15))
  end

  test "beginning_and_end_of_year" do
    d = Date.new(2024, 7, 1)
    assert_equal Date.new(2024, 1, 1), Domain::Shared::DateCalendar.beginning_of_year(d)
    assert_equal Date.new(2024, 12, 31), Domain::Shared::DateCalendar.end_of_year(d)
  end

  test "first_day_of_next_calendar_month" do
    assert_equal Date.new(2024, 4, 1), Domain::Shared::DateCalendar.first_day_of_next_calendar_month(Date.new(2024, 3, 5))
    assert_equal Date.new(2024, 4, 1), Domain::Shared::DateCalendar.first_day_of_next_calendar_month(Date.new(2024, 3, 1))
  end
end
