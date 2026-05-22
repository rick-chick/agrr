# frozen_string_literal: true

require "test_helper"

# 作付け計画表セルの描画責務（view レイヤ）。
# arrange 済みデータ → cells への変換（rowspan/colspan の算出ロジック）は
# test/adapters/cultivation_plan/presenters/schedule_table_field_arranger_test.rb が担保する。
# ここは cell 情報を <td> HTML（rowspan/colspan 属性・作物名・期間表記）へ
# どう写すかだけを検証する。
class PlanningSchedulesHelperTest < ActionView::TestCase
  Cultivation = Struct.new(:crop_name, :start_date, :completion_date, keyword_init: true)

  def cultivation_info(rowspan:, start_period_index:, crop_name: "トマト")
    {
      cultivation: Cultivation.new(
        crop_name: crop_name,
        start_date: Date.new(2026, 1, 15),
        completion_date: Date.new(2026, 3, 20)
      ),
      rowspan: rowspan,
      start_period_index: start_period_index
    }
  end

  test "rowspan_attributes は rowspan>1 のときだけ rowspan を含む" do
    assert_equal({ rowspan: 3 }, rowspan_attributes(3))
    assert_equal({}, rowspan_attributes(1))
  end

  test "render_cultivation_cell は開始期間でないとき空文字を返す" do
    html = render_cultivation_cell(
      cultivation_info: cultivation_info(rowspan: 1, start_period_index: 2),
      colspan: 1,
      period_index: 0
    )

    assert_equal "", html
  end

  test "render_cultivation_cell は開始期間で td・colspan・作物名・期間表記を描画する" do
    html = render_cultivation_cell(
      cultivation_info: cultivation_info(rowspan: 1, start_period_index: 0, crop_name: "トマト"),
      colspan: 2,
      period_index: 0
    )
    cell = Nokogiri::HTML.fragment(html).at_css("td")

    assert cell, "td が描画されていない"
    assert_equal "2", cell["colspan"]
    assert_nil cell["rowspan"], "rowspan=1 では rowspan 属性を付けない"
    assert_equal "トマト", cell.at_css(".cultivation-crop-name").text.strip
    assert_includes cell.at_css(".cultivation-period").text, I18n.l(Date.new(2026, 1, 15), format: :short)
  end

  test "render_cultivation_cell は rowspan>1 のとき rowspan 属性を付与する" do
    html = render_cultivation_cell(
      cultivation_info: cultivation_info(rowspan: 4, start_period_index: 0),
      colspan: 1,
      period_index: 0
    )
    cell = Nokogiri::HTML.fragment(html).at_css("td")

    assert_equal "4", cell["rowspan"]
  end

  test "render_empty_cell は colspan 付きの td と作付なしラベルを描画する" do
    html = render_empty_cell(colspan: 2, show_label: true)
    cell = Nokogiri::HTML.fragment(html).at_css("td")

    assert_equal "2", cell["colspan"]
    assert_equal I18n.t("planning_schedules.schedule.no_cultivation"),
                 cell.at_css(".cultivation-empty").text.strip
  end

  test "render_empty_cell は show_label:false のときラベルを描画しない" do
    html = render_empty_cell(colspan: 1, show_label: false)
    cell = Nokogiri::HTML.fragment(html).at_css("td")

    assert_equal "", cell.at_css(".cultivation-empty").text.strip
  end
end
