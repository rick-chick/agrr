# frozen_string_literal: true

require 'test_helper'

class ScheduleTableFieldArrangerTest < ActiveSupport::TestCase
  def build_periods
    # 降順（最新→過去）で3期間
    [
      { label: 'P3', start_date: Date.new(2026, 3, 1), end_date: Date.new(2026, 3, 31) },
      { label: 'P2', start_date: Date.new(2026, 2, 1), end_date: Date.new(2026, 2, 28) },
      { label: 'P1', start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 31) }
    ]
  end

  test 'two_columns_required? returns true when current has two' do
    assert ScheduleTableFieldArranger.two_columns_required?(2, 0, 0)
  end

  test 'two_columns_required? returns true when prev has two' do
    assert ScheduleTableFieldArranger.two_columns_required?(1, 2, 0)
  end

  test 'two_columns_required? returns true when next has two' do
    assert ScheduleTableFieldArranger.two_columns_required?(1, 0, 2)
  end

  test 'periods_overlap? returns false for empty arrays' do
    refute ScheduleTableFieldArranger.periods_overlap?([], [])
  end

  test 'periods_overlap? returns true when a period is shared' do
    p = build_periods
    assert ScheduleTableFieldArranger.periods_overlap?([p[0]], [p[0]])
  end

  test 'count_cultivations_in_period handles out of bounds' do
    p = build_periods
    assert_equal 0, ScheduleTableFieldArranger.count_cultivations_in_period(sorted_cultivations: [], periods: p, period_index: -1)
    assert_equal 0, ScheduleTableFieldArranger.count_cultivations_in_period(sorted_cultivations: [], periods: p, period_index: 99)
  end

  test 'build_period_layout returns colspan=1 when two cultivations in current' do
    periods = build_periods
    # 両方P3に属する2作付（slot 0,1）
    arranged = [
      { cultivation: {}, start_period_index: 0, periods: [periods[0]], rowspan: 1, is_spanning: false, slot_index: 0 },
      { cultivation: {}, start_period_index: 0, periods: [periods[0]], rowspan: 1, is_spanning: false, slot_index: 1 }
    ]
    layout = ScheduleTableFieldArranger.build_period_layout(arranged_cultivations: arranged, periods: periods, period_index: 0)
    assert_equal 1, layout[:colspan]
    assert layout[:slots][0]
    assert layout[:slots][1]
  end

  test 'build_period_cells returns empty cell when no cultivation in period' do
    periods = build_periods
    cells = ScheduleTableFieldArranger.build_period_cells(arranged_cultivations: [], periods: periods, period_index: 0)
    assert_equal 1, cells.size
    cell = cells.first
    assert_equal :empty, cell[ScheduleTableFieldArranger::CELL_TYPE_KEY]
    assert_equal 2, cell[ScheduleTableFieldArranger::CELL_COLSPAN_KEY]
    assert_equal true, cell[ScheduleTableFieldArranger::CELL_SHOW_LABEL_KEY]
  end
end


