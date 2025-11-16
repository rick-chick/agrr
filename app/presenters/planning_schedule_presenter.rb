# frozen_string_literal: true

# PlanningSchedulePresenter
# - Viewに渡すための純粋なデータ変換（Domain ViewModel）
# - 期間配列を保持し、FieldArrangerのcells結果を供給する
class PlanningSchedulePresenter
  # @return [Array<Hash>] 降順の期間配列
  attr_reader :periods

  # @param periods [Array<Hash>] 降順の期間配列
  def initialize(periods:)
    @periods = periods
  end

  # 指定期間のセル配列を返す（Viewはこの配列を反復描画するだけでよい）
  # @param arranged_cultivations [Array<Hash>] arrange済み作付配列
  # @param period_index [Integer] 期間インデックス
  # @return [Array<Hash>] cells
  def period_cells(arranged_cultivations:, period_index:)
    ScheduleTableFieldArranger.build_period_cells(
      arranged_cultivations: arranged_cultivations,
      periods: @periods,
      period_index: period_index
    )
  end
end


