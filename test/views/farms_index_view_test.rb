# frozen_string_literal: true

require "test_helper"

# farms/index テンプレートと _farm_card パーシャルの描画責務。
# 「自分の農場のみ／参照農場の絞り込み」というユースケース判定は
# FarmListRowsBundleInteractor のユニットテストが担保する。ここは
# Interactor が渡した行 DTO をテンプレートがどう HTML に写すかだけを検証する。
class FarmsIndexViewTest < ActiveSupport::TestCase
  def turbo_stream_subscription_for(farm_id)
    Domain::Shared::Dtos::TurboStreamSubscription.for_farm(farm_id)
  end

  def farm_list_row(display_name:, id: 1, is_reference: false, user_id: 1)
    Domain::Farm::Dtos::FarmListRow.new(
      id: id,
      display_name: display_name,
      latitude: 35.0,
      longitude: 135.0,
      region: "jp",
      user_id: user_id,
      is_reference: is_reference,
      field_count: 0,
      weather_data_status: "pending",
      weather_data_progress: 0,
      weather_data_total_years: 0,
      weather_data_last_error: nil
    )
  end

  # index は farms/ 配下のパーシャル（_farm_card_wrapper 等）をベア名で render するため、
  # コントローラのビューパスが farms/ に解決される FarmsController.renderer を使う。
  test "_farm_card は農場の display_name を .farm-name に描画する" do
    row = farm_list_row(display_name: "私の農場")

    html = FarmsController.renderer.render(
      partial: "farms/farm_card",
      locals: { farm: row }
    )

    assert_match %r{<h3 class="farm-name">私の農場</h3>}, html
  end

  test "index は @farms の各行を farm-name カードとして描画する" do
    row = farm_list_row(display_name: "My Listed Farm", id: 5)
    html = FarmsController.renderer.render(
      template: "farms/index",
      layout: false,
      assigns: {
        farms: [ row ],
        reference_farms: []
      }
    )

    assert_match %r{<h3 class="farm-name">My Listed Farm</h3>}, html
    assert_includes html, Turbo::StreamsChannel.signed_stream_name(row.turbo_stream_subscription.streamables)
  end

  test "index は参照農場が存在するとき参照農場セクションヘッダを描画する" do
    html = FarmsController.renderer.render(
      template: "farms/index",
      layout: false,
      assigns: {
        farms: [],
        reference_farms: [ farm_list_row(display_name: "Ref Farm", id: 2, is_reference: true, user_id: nil) ]
      }
    )

    assert_match(/<h2 class="section-header">/, html)
    assert_includes html, I18n.t("farms.index.reference_farms")
    assert_match %r{<h3 class="farm-name">Ref Farm</h3>}, html
  end

  test "index は参照農場が無いとき参照農場セクションヘッダを描画しない" do
    html = FarmsController.renderer.render(
      template: "farms/index",
      layout: false,
      assigns: {
        farms: [ farm_list_row(display_name: "My Listed Farm") ],
        reference_farms: []
      }
    )

    assert_no_match(/<h2 class="section-header">/, html)
  end
end
