# frozen_string_literal: true

require "test_helper"

class Domain::CultivationPlan::Dtos::TaskScheduleItemCompleteInputDtoTest < ActiveSupport::TestCase
  FakeClock = Struct.new(:today_val, :now_val) do
    def today
      today_val
    end

    def now
      now_val
    end
  end

  setup do
    @now = Time.zone.local(2026, 3, 1, 12, 0, 0)
    @clock = FakeClock.new(Date.new(2026, 3, 1), @now)
  end

  test "actual_date が空なら clock.today を使う" do
    dto = Domain::CultivationPlan::Dtos::TaskScheduleItemCompleteInputDto.from_completion_params(
      {},
      clock: @clock
    )
    assert_equal Date.new(2026, 3, 1), dto.actual_date
    assert_equal @now, dto.completed_at
  end

  test "実施日が Date のときそのまま使う" do
    d = Date.new(2026, 4, 10)
    dto = Domain::CultivationPlan::Dtos::TaskScheduleItemCompleteInputDto.from_completion_params(
      { actual_date: d },
      clock: @clock
    )
    assert_equal d, dto.actual_date
  end

  test "不正な日付文字列は RecordInvalid" do
    err = assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
      Domain::CultivationPlan::Dtos::TaskScheduleItemCompleteInputDto.from_completion_params(
        { "actual_date" => "bogus" },
        clock: @clock
      )
    end
    assert err.errors.key?("actual_date")
  end
end
