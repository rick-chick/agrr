# frozen_string_literal: true

# 計画スケジュール表の1ほ場の作付配置を決定するサービス
# アルゴリズム:
# 1. すべての作付について、専有する期間を決定する（rowspan）
# 2. 作付を上から順に並べて、重なったら保留する。重ならないものだけ並べる
# 3. 保留していた作付をつける。保留の作付同士で重なったらエラー
# 4. 期ごとに作付を数える
# 5. 1つの場合はcolspan=2
# 6. 2つある場合はcolspan=1を2つ
class ScheduleTableFieldArranger
  class OverlappingError < StandardError; end

  # @param cultivations [Array<Hash>] 作付情報の配列。各要素は以下のキーを持つ:
  #   - :cultivation [Object] 栽培情報オブジェクト
  #   - :start_date [Date] 開始日
  #   - :completion_date [Date] 終了日
  #   - :crop_name [String] 作物名
  #   - :periods [Array<Hash>] 専有する期間の配列
  # @param periods [Array<Hash>] すべての期間の配列（降順）。各要素は以下のキーを持つ:
  #   - :label [String] 期間ラベル
  #   - :start_date [Date] 期間の開始日
  #   - :end_date [Date] 期間の終了日
  # @return [Array<Hash>] 配置された作付情報の配列。各要素は以下のキーを持つ:
  #   - :cultivation [Object] 栽培情報オブジェクト
  #   - :start_period_index [Integer] 開始期間のインデックス
  #   - :periods [Array<Hash>] 専有する期間の配列
  #   - :rowspan [Integer] rowspanの値
  #   - :is_spanning [Boolean] 期間またぎかどうか
  #   - :slot_index [Integer] 配置スロットのインデックス（0または1）
  def self.arrange(cultivations:, periods:)
    # ステップ1: すべての作付について、専有する期間を決定する（rowspan）
    cultivations_with_periods = cultivations.map do |cultivation|
      periods_for_cultivation = periods.select do |period|
        # 作付が期間と重なるかどうか
        cultivation[:start_date] <= period[:end_date] && cultivation[:completion_date] >= period[:start_date]
      end

      # 開始日を含む最初の期間（最も新しい期間）を取得
      # periodsは降順なので、start_dateが最も大きい期間を取得
      # HTMLテーブルのrowspanは下方向（より古い期間）にマージされるため、
      # 最新の期間にセルを配置し、そこから下方向にrowspanでマージする
      start_period = periods_for_cultivation.max_by { |p| p[:start_date] }
      start_period_index = start_period ? periods.find_index { |p| p[:start_date] == start_period[:start_date] && p[:end_date] == start_period[:end_date] } : nil
      
      # 期ごとに作付を数えて、colspanを決定
      # その期に作付が2つある場合はcolspan=1、1つある場合はcolspan=2
      # ただし、前後の期間で作付が2つある場合、列数を一致させるため、colspan=1を2つ使う
      rowspan = periods_for_cultivation.size
      
      {
        cultivation: cultivation,
        start_period_index: start_period_index,
        periods: periods_for_cultivation,  # 属している期のリスト
        rowspan: rowspan,  # rowspan（作付ビューの情報）
        is_spanning: periods_for_cultivation.size > 1
        # colspanとslot_indexは後で決定される
      }
    end

    # ステップ2: 作付を上から順に並べて、重なったら保留する。重ならないものだけ並べる
    # 期間を上から（新しい期間から）順に見て、各期間に作付を配置する
    placed_cultivations = []
    pending_cultivations = []

    # 期間を上から順に処理（periodsは降順なので、そのまま処理）
    periods.each_with_index do |period, period_index|
      # この期間で開始する作付を取得
      starting_in_period = cultivations_with_periods.select do |c|
        c[:start_period_index] == period_index && !placed_cultivations.include?(c) && !pending_cultivations.include?(c)
      end

      starting_in_period.each do |cultivation_info|
        # 既に配置された作付と重なる期間があるかどうかを確認
        overlaps = placed_cultivations.any? do |placed|
          periods_overlap?(cultivation_info[:periods], placed[:periods])
        end

        if overlaps
          pending_cultivations << cultivation_info
        else
          cultivation_info[:slot_index] = 0
          cultivation_info[:colspan] = nil  # 後で期間ごとに決定
          placed_cultivations << cultivation_info
        end
      end
    end

    # ステップ3: 保留していた作付をつける。保留の作付同士で重なったらエラー
    pending_cultivations.each do |pending|
      # 保留の作付同士で重なるかどうかを確認
      overlaps_with_pending = pending_cultivations.any? do |other_pending|
        other_pending != pending && periods_overlap?(pending[:periods], other_pending[:periods])
      end

      if overlaps_with_pending
        raise OverlappingError, "保留の作付同士が重なっています: #{pending[:cultivation][:crop_name]}"
      end

      # slot_index=1に配置
      pending[:slot_index] = 1
      pending[:colspan] = nil  # 後で決定
      placed_cultivations << pending
    end

    # 配置された作付を開始期間順にソート
    sorted_cultivations = placed_cultivations.sort_by { |c| c[:start_period_index] || 999 }
    
    # 各期間ごとに作付を数えて、各作付のcolspanを決定
    periods.each_with_index do |period, period_index|
      # この期間に表示される作付を取得
      cultivations_in_period = cultivations_for_period_in_sorted(
        sorted_cultivations: sorted_cultivations,
        period: period
      )
      
      # 前後の期間で作付が2つあるかどうかを確認
      prev_total_count = count_cultivations_in_period(
        sorted_cultivations: sorted_cultivations,
        periods: periods,
        period_index: period_index + 1
      )
      
      next_total_count = count_cultivations_in_period(
        sorted_cultivations: sorted_cultivations,
        periods: periods,
        period_index: period_index - 1
      )
      
      # この期間でcolspanを決定
      # その期に作付が2つある場合、または前後の期間で作付が2つある場合はcolspan=1
      # そうでない場合はcolspan=2
      total_count = cultivations_in_period.size
      target_colspan = (total_count == 2 || prev_total_count == 2 || next_total_count == 2) ? 1 : 2
      
      cultivations_in_period.each do |c|
        c[:colspan] = target_colspan if c[:colspan].nil?
      end
    end
    
    sorted_cultivations
  end

  # 期間レイアウト情報を構築（ビューはこの情報のみで描画可能）
  # @param arranged_cultivations [Array<Hash>] arrangeメソッドで配置された作付情報
  # @param periods [Array<Hash>] 期間配列（降順）
  # @param period_index [Integer] 対象期間のインデックス
  # @return [Hash] { colspan: Integer, slots: [slot0, slot1] }
  def self.build_period_layout(arranged_cultivations:, periods:, period_index:)
    current_period = periods[period_index]

    # この期間に属する作付（開始/継続どちらも含む）
    cultivations_in_period = cultivations_for_period_in_sorted(
      sorted_cultivations: arranged_cultivations,
      period: current_period
    )

    # 前後の期間の総数を見て、この期間のcolspanを決める（既存ロジックと同一）
    prev_total = count_cultivations_in_period(
      sorted_cultivations: arranged_cultivations,
      periods: periods,
      period_index: period_index + 1
    )
    next_total = count_cultivations_in_period(
      sorted_cultivations: arranged_cultivations,
      periods: periods,
      period_index: period_index - 1
    )
    total = cultivations_in_period.size
    colspan = (total == 2 || prev_total == 2 || next_total == 2) ? 1 : 2

    # スロットに割り当て（開始セルのみ描画するための情報は各作付のstart_period_indexに保持済み）
    slot0 = cultivations_in_period.find { |c| c[:slot_index] == 0 }
    slot1 = cultivations_in_period.find { |c| c[:slot_index] == 1 }

    { colspan: colspan, slots: [slot0, slot1] }
  end

  # 2つの期間配列が重なるかどうかを判定
  # @param periods1 [Array<Hash>] 期間の配列
  # @param periods2 [Array<Hash>] 期間の配列
  # @return [Boolean] 重なる場合はtrue
  def self.periods_overlap?(periods1, periods2)
    # 期間の配列が空の場合は重ならない
    return false if periods1.empty? || periods2.empty?
    
    # 期間の配列に共通の期間があるかどうかを確認
    periods1.any? do |p1|
      periods2.any? do |p2|
        p1[:start_date] == p2[:start_date] && p1[:end_date] == p2[:end_date]
      end
    end
  end

  # 各期間ごとにこの期間に表示される作付を取得
  # @param arranged_cultivations [Array<Hash>] arrangeメソッドで配置された作付情報の配列
  # @param periods [Array<Hash>] すべての期間の配列（降順）
  # @param period_index [Integer] 現在の期間のインデックス
  # @return [Array<Hash>] この期間に表示される作付情報の配列（slot_index順）
  def self.cultivations_for_period(arranged_cultivations:, periods:, period_index:)
    current_period = periods[period_index]
    cultivations_in_period = cultivations_for_period_in_sorted(
      sorted_cultivations: arranged_cultivations,
      period: current_period
    )

    # slot_index順にソート（slot_index=0を先に、slot_index=1を後に）
    cultivations_in_period.sort_by { |c| c[:slot_index] || 0 }
  end

  # 期間に表示される作付を取得（内部メソッド）
  # @param sorted_cultivations [Array<Hash>] 配置された作付情報の配列
  # @param period [Hash] 期間情報
  # @return [Array<Hash>] この期間に表示される作付情報の配列
  def self.cultivations_for_period_in_sorted(sorted_cultivations:, period:)
    sorted_cultivations.select do |c|
      c[:periods].any? { |p| p[:start_date] == period[:start_date] && p[:end_date] == period[:end_date] }
    end
  end

  # 指定期間の作付数を取得
  # @param sorted_cultivations [Array<Hash>] 配置された作付情報の配列
  # @param periods [Array<Hash>] すべての期間の配列（降順）
  # @param period_index [Integer] 期間のインデックス（範囲外の場合は0を返す）
  # @return [Integer] この期間に表示される作付数
  def self.count_cultivations_in_period(sorted_cultivations:, periods:, period_index:)
    return 0 if period_index < 0 || period_index >= periods.size
    
    period = periods[period_index]
    cultivations_for_period_in_sorted(
      sorted_cultivations: sorted_cultivations,
      period: period
    ).size
  end
end

