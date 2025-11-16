# frozen_string_literal: true

require 'test_helper'

class PlanningSchedulePresenterTest < ActiveSupport::TestCase
  def build_periods
    # 降順（最新→過去）で2期間
    [
      { label: '2026年02月', start_date: Date.new(2026, 2, 1), end_date: Date.new(2026, 2, 28) },
      { label: '2026年01月', start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 31) }
    ]
  end

  test 'period_cells returns empty when no cultivations' do
    presenter = PlanningSchedulePresenter.new(periods: build_periods)
    cells = presenter.period_cells(arranged_cultivations: [], period_index: 0)
    assert_kind_of Array, cells
  end

  test 'period_cells handles single cultivation within a period' do
    periods = build_periods
    presenter = PlanningSchedulePresenter.new(periods: periods)
    # arrange風データ（slot_index=0、開始はperiod_index=0）
    arranged = [
      {
        cultivation: { crop_name: 'トマト', start_date: Date.new(2026, 2, 10), completion_date: Date.new(2026, 2, 20) },
        start_period_index: 0,
        periods: [periods[0]],
        rowspan: 1,
        is_spanning: false,
        slot_index: 0
      }
    ]
    cells = presenter.period_cells(arranged_cultivations: arranged, period_index: 0)
    assert_equal 1, cells.size
    cell = cells.first
    assert_equal :cultivation, cell[ScheduleTableFieldArranger::CELL_TYPE_KEY]
    assert_equal 2, cell[ScheduleTableFieldArranger::CELL_COLSPAN_KEY]
    assert_equal true, cell[ScheduleTableFieldArranger::CELL_RENDER_KEY]
  end
end


