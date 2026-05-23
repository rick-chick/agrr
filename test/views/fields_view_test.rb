# frozen_string_literal: true

require "test_helper"

# fields/index・show テンプレートと _field_card パーシャルの描画責務。
# 圃場の認可・絞り込み・未検出といったユースケース判定は
# FieldListInteractor / FieldDetailInteractor のユニットテストが担保する。
# ここは Interactor が渡したエンティティをテンプレートがどう HTML に写すかだけを検証する。
class FieldsViewTest < ActiveSupport::TestCase
  def farm_entity(id: 1, name: "テスト農場")
    Domain::Farm::Entities::FarmEntity.new(
      id: id, name: name, latitude: nil, longitude: nil, region: nil, user_id: 9,
      created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 1, 1), is_reference: false
    )
  end

  def field_entity(id: 2, farm_id: 1, name: "Alpha Plot")
    Domain::Field::Entities::FieldEntity.new(
      id: id, farm_id: farm_id, user_id: 9, name: name, description: nil,
      created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 1, 1),
      area: nil, daily_fixed_cost: nil, region: nil
    )
  end

  test "_field_card は圃場名と圃場 dom id を描画する" do
    farm = farm_entity
    field = field_entity(name: "Alpha Plot")

    html = FieldsController.renderer.render(
      partial: "fields/field_card",
      locals: { field: field, farm: farm }
    )

    assert_match %r{<h3 class="field-name">Alpha Plot</h3>}, html
    assert_includes html, %(id="field_#{field.id}")
  end

  test "index は農場名と各圃場カードを描画する" do
    farm = farm_entity(name: "テスト農場")
    field = field_entity(name: "Alpha Plot")
    turbo_stream_subscription = Domain::Shared::Dtos::TurboStreamSubscription.for_farm(farm.id)

    html = FieldsController.renderer.render(
      template: "fields/index",
      layout: false,
      assigns: { farm: farm, fields: [ field ], turbo_stream_subscription: turbo_stream_subscription }
    )

    assert_includes html, "テスト農場"
    assert_match %r{<h3 class="field-name">Alpha Plot</h3>}, html
    assert_includes html, %(id="field_#{field.id}")
    assert_includes html, Turbo::StreamsChannel.signed_stream_name(turbo_stream_subscription.streamables)
  end

  test "show は圃場詳細（圃場名と dom id）を描画する" do
    farm = farm_entity
    field = field_entity(name: "Beta Row")

    html = FieldsController.renderer.render(
      template: "fields/show",
      layout: false,
      assigns: { farm: farm, field: field }
    )

    assert_includes html, "Beta Row"
    assert_includes html, %(id="field_#{field.id}")
  end
end
