# frozen_string_literal: true

module PlanningSchedulesHelper
  # CSSクラス定数（見通し向上・タイポ防止）
  CLASS_SCHEDULE_CELL     = 'schedule-table-cell'.freeze
  CLASS_SCHEDULE_CELL_TOP = 'schedule-table-cell--top'.freeze

  # 期間のcolspanを決定
  # @param cultivations_in_period [Array<Hash>] この期間に表示される作付情報の配列
  # @param arranged_cultivations [Array<Hash>] arrangeメソッドで配置された作付情報の配列
  # @param periods [Array<Hash>] すべての期間の配列（降順）
  # @param period_index [Integer] 現在の期間のインデックス
  # @return [Integer] 1または2（1の場合はcolspan=1を2つ使う、2の場合はcolspan=2を1つ使う）
  def calculate_period_colspan(cultivations_in_period:, arranged_cultivations:, periods:, period_index:)
    # 前後の期間で作付が2つあるかどうかを確認
    prev_period_index = period_index + 1
    prev_total_count = 0
    if prev_period_index < periods.size
      prev_period = periods[prev_period_index]
      prev_cultivations_in_period = arranged_cultivations.select do |c|
        c[:periods].any? { |p| p[:start_date] == prev_period[:start_date] && p[:end_date] == prev_period[:end_date] }
      end
      prev_total_count = prev_cultivations_in_period.size
    end
    
    next_period_index = period_index - 1
    next_total_count = 0
    if next_period_index >= 0
      next_period = periods[next_period_index]
      next_cultivations_in_period = arranged_cultivations.select do |c|
        c[:periods].any? { |p| p[:start_date] == next_period[:start_date] && p[:end_date] == next_period[:end_date] }
      end
      next_total_count = next_cultivations_in_period.size
    end
    
    total_count = cultivations_in_period.size
    if total_count == 2 || prev_total_count == 2 || next_total_count == 2
      1  # colspan=1を2つ使う
    else
      2  # colspan=2を1つ使う
    end
  end

  # rowspan属性を生成
  # @param rowspan [Integer] rowspanの値
  # @return [Hash] rowspan属性のハッシュ（rowspan > 1の場合のみrowspanを含む）
  def rowspan_attributes(rowspan)
    rowspan > 1 ? { rowspan: rowspan } : {}
  end

  # rowspan属性をHTML属性文字列に変換
  # @param rowspan [Integer] rowspanの値
  # @return [String] HTML属性文字列（例: 'rowspan="3"' または ''）
  # （未使用のため将来のために残す場合はコメントアウト）
  # def rowspan_attr_string(rowspan)
  #   attrs = rowspan_attributes(rowspan)
  #   return '' if attrs.empty?
  #   attrs.map { |k, v| "#{k}=\"#{v}\"" }.join(' ')
  # end

  # 作付が開始する期間かどうかを判定
  # @param cultivation_info [Hash] 作付情報
  # @param period_index [Integer] 現在の期間のインデックス
  # @return [Boolean] 開始する期間の場合true
  def cultivation_starts_in_period?(cultivation_info, period_index)
    cultivation_info[:start_period_index] == period_index
  end

  # 作付セルを描画
  # @param cultivation_info [Hash] 作付情報（:cultivation, :rowspan, :start_period_indexを含む）
  # @param colspan [Integer] colspanの値（1または2）
  # @param period_index [Integer] 現在の期間のインデックス
  # @return [String] HTML文字列（開始する期間でない場合は空文字列）
  def render_cultivation_cell(cultivation_info:, colspan:, period_index:)
    return '' unless cultivation_starts_in_period?(cultivation_info, period_index)

    cultivation = cultivation_info[:cultivation]
    crop_color = get_crop_color_for_schedule(cultivation[:crop_name].to_s)
    rowspan_attrs = rowspan_attributes(cultivation_info[:rowspan])

    tag_attrs = {
      class: "#{CLASS_SCHEDULE_CELL} #{CLASS_SCHEDULE_CELL_TOP}",
      colspan: colspan,
      style: nil
    }.merge(rowspan_attrs)

    content_tag(:td, tag_attrs) do
      content_tag(:div, class: 'cultivation-items') do
        content_tag(:div, class: 'cultivation-item', style: "background-color: #{crop_color[:fill]}; border-left: 4px solid #{crop_color[:stroke]}; color: #{crop_color[:text]};") do
          content_tag(:div, cultivation[:crop_name], class: 'cultivation-crop-name') +
          content_tag(:div, class: 'cultivation-period') do
            "#{I18n.l(cultivation[:start_date], format: :short)} - #{I18n.l(cultivation[:completion_date], format: :short)}"
          end
        end
      end
    end
  end

  # 空白セルを描画
  # @param colspan [Integer] colspanの値（1または2）
  # @param show_label [Boolean] 「作付なし」ラベルを表示するかどうか（デフォルト: true）
  # @return [String] HTML文字列
  def render_empty_cell(colspan:, show_label: true)
    content_tag(:td,
      content_tag(:div, class: 'cultivation-empty') do
        show_label ? t('planning_schedules.schedule.no_cultivation') : ''
      end,
      class: 'schedule-table-cell',
      colspan: colspan
    )
  end
end

