# frozen_string_literal: true

module PlanningSchedulesHelper
  # CSSクラス定数（見通し向上・タイポ防止）
  CLASS_SCHEDULE_CELL     = "schedule-table-cell".freeze
  CLASS_SCHEDULE_CELL_TOP = "schedule-table-cell--top".freeze

  # 作付け計画表マトリクスで作物名ごとに一貫した色を返す（表示専用）
  CROP_SCHEDULE_DISPLAY_COLOR_PALETTE = [
    { fill: "rgba(154, 230, 180, 0.8)", stroke: "#48bb78", text: "#1a202c" },
    { fill: "rgba(251, 211, 141, 0.8)", stroke: "#f6ad55", text: "#1a202c" },
    { fill: "rgba(144, 205, 244, 0.8)", stroke: "#4299e1", text: "#1a202c" },
    { fill: "rgba(198, 246, 213, 0.8)", stroke: "#2f855a", text: "#1a202c" },
    { fill: "rgba(254, 235, 200, 0.8)", stroke: "#dd6b20", text: "#1a202c" },
    { fill: "rgba(254, 178, 178, 0.8)", stroke: "#fc8181", text: "#1a202c" },
    { fill: "rgba(254, 243, 199, 0.8)", stroke: "#d69e2e", text: "#1a202c" },
    { fill: "rgba(233, 213, 255, 0.8)", stroke: "#a78bfa", text: "#1a202c" },
    { fill: "rgba(191, 219, 254, 0.8)", stroke: "#60a5fa", text: "#1a202c" },
    { fill: "rgba(252, 231, 243, 0.8)", stroke: "#f472b6", text: "#1a202c" }
  ].freeze

  # rowspan属性を生成
  # @param rowspan [Integer] rowspanの値
  # @return [Hash] rowspan属性のハッシュ（rowspan > 1の場合のみrowspanを含む）
  def rowspan_attributes(rowspan)
    rowspan > 1 ? { rowspan: rowspan } : {}
  end

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
    return "" unless cultivation_starts_in_period?(cultivation_info, period_index)

    cultivation = cultivation_info[:cultivation]
    crop_color = get_crop_color_for_schedule(cultivation.crop_name.to_s)
    rowspan_attrs = rowspan_attributes(cultivation_info[:rowspan])

    tag_attrs = {
      class: "#{CLASS_SCHEDULE_CELL} #{CLASS_SCHEDULE_CELL_TOP}",
      colspan: colspan,
      style: nil
    }.merge(rowspan_attrs)

    content_tag(:td, tag_attrs) do
      content_tag(:div, class: "cultivation-items") do
        content_tag(:div, class: "cultivation-item", style: "background-color: #{crop_color[:fill]}; border-left: 4px solid #{crop_color[:stroke]}; color: #{crop_color[:text]};") do
          content_tag(:div, cultivation.crop_name, class: "cultivation-crop-name") +
          content_tag(:div, class: "cultivation-period") do
            "#{I18n.l(cultivation.start_date, format: :short)} - #{I18n.l(cultivation.completion_date, format: :short)}"
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
      content_tag(:div, class: "cultivation-empty") do
        show_label ? t("planning_schedules.schedule.no_cultivation") : ""
      end,
      class: "schedule-table-cell",
      colspan: colspan
    )
  end

  # 作物名から一貫した色を取得（スケジュール表示用）
  def get_crop_color_for_schedule(crop_name)
    key = crop_name.to_s
    @crop_color_cache ||= {}
    return @crop_color_cache[key] if @crop_color_cache.key?(key)

    color_index = key.hash.abs % CROP_SCHEDULE_DISPLAY_COLOR_PALETTE.size
    @crop_color_cache[key] = CROP_SCHEDULE_DISPLAY_COLOR_PALETTE[color_index]
  end
end
