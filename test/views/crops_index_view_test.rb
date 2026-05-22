# frozen_string_literal: true

require "test_helper"

# crops/index テンプレートのカード描画責務。
# 「一般ユーザーは自分の作物のみ／管理者は参照作物も」という絞り込み（ユースケース判定）は
# CropListInteractor のユニットテストが担保する。ここは Interactor が渡した作物エンティティを
# テンプレートがどう HTML カードに写すかだけを検証する。
class CropsIndexViewTest < ActiveSupport::TestCase
  def crop_entity(id:, name:, is_reference: false)
    Domain::Crop::Entities::CropEntity.new(
      id: id,
      name: name,
      variety: nil,
      user_id: is_reference ? nil : 1,
      is_reference: is_reference,
      region: nil
    )
  end

  test "index は @crops の各エンティティを crop-card として描画する" do
    html = CropsController.renderer.render(
      template: "crops/index",
      layout: false,
      assigns: { crops: [ crop_entity(id: 1, name: "トマト") ] }
    )
    doc = Nokogiri::HTML(html)

    assert_equal 1, doc.css(".crop-card").size
    assert_equal "トマト", doc.at_css(".crop-card .crop-name")&.text&.strip
    assert doc.at_css("#crop_1"), "crop dom id が描画されていない"
  end

  test "index は @crops の件数ぶん crop-card を描画する" do
    html = CropsController.renderer.render(
      template: "crops/index",
      layout: false,
      assigns: { crops: [ crop_entity(id: 1, name: "トマト"), crop_entity(id: 2, name: "ナス") ] }
    )

    assert_equal 2, Nokogiri::HTML(html).css(".crop-card").size
  end

  test "index は作物が無いとき crop-card を描画しない" do
    html = CropsController.renderer.render(
      template: "crops/index",
      layout: false,
      assigns: { crops: [] }
    )

    assert_empty Nokogiri::HTML(html).css(".crop-card")
  end
end
