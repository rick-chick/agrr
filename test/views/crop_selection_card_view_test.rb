# frozen_string_literal: true

require "test_helper"

# shared/_crop_selection_card パーシャルの描画責務。
# どの作物がカードとして提示されるか（所有者・参照・地域による絞り込み）は
# pests / agricultural_tasks の各 Interactor が担保する。ここは Interactor が組んだ
# crop_card（{ crop:, selected: }）をパーシャルがどう HTML に写すかだけを検証する。
class CropSelectionCardViewTest < ActiveSupport::TestCase
  def render_card(crop:, selected:, heading_tag: "h3")
    ApplicationController.renderer.render(
      partial: "shared/crop_selection_card",
      locals: { card: { crop: crop, selected: selected }, heading_tag: heading_tag }
    )
  end

  test "未選択カードは data-crop-id / data-selected=false と作物名を描画する" do
    crop = create(:crop, name: "トマト", variety: nil, is_reference: false)
    doc = Nokogiri::HTML(render_card(crop: crop, selected: false))
    card = doc.at_css('article[data-role="crop-card"]')

    assert_equal crop.id.to_s, card["data-crop-id"]
    assert_equal "false", card["data-selected"]
    assert_not_includes card["class"], "is-selected"
    assert_equal "トマト", card.at_css(".crop-selection-card__title").text.strip
    assert_nil card.at_css(".crop-selection-card__state")
  end

  test "選択済みカードは data-selected=true・is-selected クラス・選択状態ラベルを描画する" do
    crop = create(:crop, name: "ナス", is_reference: false)
    doc = Nokogiri::HTML(render_card(crop: crop, selected: true))
    card = doc.at_css('article[data-role="crop-card"]')

    assert_equal "true", card["data-selected"]
    assert_includes card["class"], "is-selected"
    assert_equal I18n.t("agricultural_tasks.form.crop_selection.selected_state"),
                 card.at_css(".crop-selection-card__state").text.strip
  end

  test "ユーザー作物バッジと参照作物バッジを is_reference? で出し分ける" do
    user_crop = create(:crop, is_reference: false)
    reference_crop = create(:crop, :reference)

    user_badge = Nokogiri::HTML(render_card(crop: user_crop, selected: false))
                 .at_css(".crop-selection-card__badge")
    reference_badge = Nokogiri::HTML(render_card(crop: reference_crop, selected: false))
                      .at_css(".crop-selection-card__badge")

    assert_includes user_badge["class"], "is-user"
    assert_includes reference_badge["class"], "is-reference"
  end

  test "variety があるときだけ品種を描画する" do
    with_variety = create(:crop, variety: "桃太郎", is_reference: false)
    without_variety = create(:crop, variety: nil, is_reference: false)

    assert_equal "桃太郎",
                 Nokogiri::HTML(render_card(crop: with_variety, selected: false))
                 .at_css(".crop-selection-card__variety")&.text&.strip
    assert_nil Nokogiri::HTML(render_card(crop: without_variety, selected: false))
               .at_css(".crop-selection-card__variety")
  end

  test "heading_tag でカードタイトルの見出しタグを切り替える" do
    crop = create(:crop, name: "トマト", is_reference: false)

    h3 = Nokogiri::HTML(render_card(crop: crop, selected: false, heading_tag: "h3"))
    h4 = Nokogiri::HTML(render_card(crop: crop, selected: false, heading_tag: "h4"))

    assert h3.at_css("h3.crop-selection-card__title"), "h3 見出しが描画されていない"
    assert h4.at_css("h4.crop-selection-card__title"), "h4 見出しが描画されていない"
  end
end
