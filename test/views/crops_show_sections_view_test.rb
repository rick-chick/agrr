# frozen_string_literal: true

require "test_helper"

# crops/show 配下セクションパーシャルの描画責務。
# どの害虫がどの順で並ぶか（関連付け・並び順のユースケース判定）は
# CropDetailInteractor のユニットテストが担保する。ここは Interactor が渡した
# 害虫エンティティ配列をテンプレートがどう HTML カードに写すかだけを検証する。
class CropsShowSectionsViewTest < ActiveSupport::TestCase
  def crop_entity(id: 1)
    Domain::Crop::Entities::CropEntity.new(
      id: id, name: "トマト", variety: nil, user_id: 1, is_reference: false, region: nil
    )
  end

  def pest_entity(id:, name:, name_scientific:)
    Domain::Pest::Entities::PestEntity.new(
      id: id, user_id: 1, name: name, name_scientific: name_scientific,
      family: nil, order: nil, description: nil, occurrence_season: nil,
      region: nil, is_reference: false,
      created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 1, 1)
    )
  end

  test "_pests_section は pests 配列の各害虫を pest-card として描画する" do
    aphid = pest_entity(id: 1, name: "アブラムシ", name_scientific: "Aphidoidea")
    whitefly = pest_entity(id: 2, name: "コナジラミ", name_scientific: "Aleyrodidae")

    html = CropsController.renderer.render(
      partial: "crops/pests_section",
      locals: { crop: crop_entity, pests: [ aphid, whitefly ] }
    )
    doc = Nokogiri::HTML(html)

    assert_equal 2, doc.css(".pests-grid .pest-card").size
    assert_equal "アブラムシ", doc.at_css(".pest-card:first-child .pest-card__name").text.strip
    assert_equal "Aphidoidea", doc.at_css(".pest-card:first-child .pest-card__scientific").text.strip
    assert_equal I18n.t("crops.show.manage_pests"),
                 doc.at_css(".pests-section__header .pests-section__action").text.strip
  end

  test "_pests_section は害虫が無いとき pest-card を描画しない" do
    html = CropsController.renderer.render(
      partial: "crops/pests_section",
      locals: { crop: crop_entity, pests: [] }
    )
    doc = Nokogiri::HTML(html)

    assert_empty doc.css(".pest-card")
    assert doc.at_css(".no-pests"), "害虫なしメッセージが描画されていない"
  end
end
