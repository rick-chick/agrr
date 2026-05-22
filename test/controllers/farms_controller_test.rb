# frozen_string_literal: true

require "test_helper"

# destroy の undo JSON と使用中 422 は境界契約。認可拒否の網羅は FarmDestroyInteractor 等の単体に寄せる。
class FarmsControllerTest < ActionDispatch::IntegrationTest
  include Rails.application.routes.url_helpers
  include ActionView::RecordIdentifier
  setup do
    @user = create(:user)
  end

  test "destroy_returns_undo_token_json" do
    sign_in_as @user
    farm = create(:farm, user: @user)

    assert_difference -> { Farm.count }, -1 do
      assert_difference "DeletionUndoEvent.count", +1 do
        delete Rails.application.routes.url_helpers.farm_path(farm), as: :json
        assert_response :success
      end
    end

    body = JSON.parse(@response.body)
    %w[undo_token undo_deadline toast_message undo_path auto_hide_after redirect_path resource_dom_id resource].each do |key|
      assert body.key?(key), "JSONレスポンスに#{key}が含まれていません"
      assert body[key].present?, "#{key} が空です"
    end

    undo_token = body["undo_token"]
    event = DeletionUndoEvent.find(undo_token)
    assert_equal "Farm", event.resource_type
    assert_equal farm.id.to_s, event.resource_id
    assert event.scheduled?
    assert_equal undo_deletion_path(undo_token: undo_token), body.fetch("undo_path")
    assert_equal farms_path(locale: I18n.locale), body.fetch("redirect_path")
    assert_equal dom_id(farm), body.fetch("resource_dom_id")
    assert_equal farm.display_name, body.fetch("resource")
  end

  test "destroy as JSON returns 422 when farm has free_crop_plans" do
    sign_in_as @user
    farm = create(:farm, user: @user)
    crop = create(:crop, user: @user)
    FreeCropPlan.create!(farm: farm, crop: crop, area_sqm: 100, session_id: "sess_block_json")

    assert_no_difference -> { Farm.count } do
      delete farm_path(farm), as: :json
    end
    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert body["error"].present?
  end

  test "undo_endpoint_restores_farm" do
    sign_in_as @user
    farm = create(:farm, user: @user)

    delete farm_path(farm), as: :json
    assert_response :success

    body = JSON.parse(@response.body)
    undo_token = body.fetch("undo_token")

    assert_not Farm.exists?(farm.id), "削除後にFarmが残っています"

    assert_difference -> { Farm.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    undo_body = JSON.parse(@response.body)
    assert_equal "restored", undo_body["status"]
    assert_equal undo_token, undo_body["undo_token"]

    restored_event = DeletionUndoEvent.find(undo_token)
    assert restored_event.restored?
    assert Farm.exists?(farm.id), "Undo後にFarmが復元されていません"
  end

  test "destroy_via_html_redirects_with_undo_notice" do
    sign_in_as @user
    farm = create(:farm, user: @user, name: "テスト農場")
    display_name = farm.display_name

    assert_difference -> { Farm.count }, -1 do
      assert_difference "DeletionUndoEvent.count", +1 do
        delete farm_path(farm) # HTMLリクエスト
        assert_redirected_to farms_path
      end
    end

    expected_notice = I18n.t(
      "deletion_undo.redirect_notice",
      resource: display_name
    )
    assert_equal expected_notice, flash[:notice]
  end

  test "GET index as JSON returns farms and reference_farms arrays" do
    sign_in_as @user
    farm = create(:farm, user: @user, name: "JSON Listed Farm")

    get farms_path(format: :json)
    assert_response :success
    body = response.parsed_body
    assert_kind_of Array, body["farms"]
    assert_kind_of Array, body["reference_farms"]
    farm_ids = body["farms"].map { |h| h["id"] }
    assert_includes farm_ids, farm.id
  end

  test "GET show as JSON returns farm fields payload via interactor" do
    sign_in_as @user
    farm = create(:farm, user: @user, name: "Detail JSON Farm")

    get farm_path(farm, format: :json)
    assert_response :success
    body = response.parsed_body
    assert_equal farm.id, body["id"]
    assert_equal "Detail JSON Farm", body["name"]
    assert_kind_of Array, body["fields"]
  end

  test "PATCH update as JSON updates farm via interactor" do
    sign_in_as @user
    farm = create(:farm, user: @user, name: "Before Patch")

    patch farm_path(farm, format: :json), params: { farm: { name: "After Patch" } }
    assert_response :success
    body = response.parsed_body
    assert_equal "After Patch", body["name"]
    assert_equal farm.id, body["id"]
    farm.reload
    assert_equal "After Patch", farm.name
  end

  # HTML index の行絞り込み（自分の農場のみ／管理者の参照農場）は
  # FarmListRowsBundleInteractor のユニットテスト、テンプレート描画は
  # test/views/farms_index_view_test.rb が担保する。ここは配線が通ることのみ確認する。
  test "GET index HTML renders successfully" do
    sign_in_as @user
    create(:farm, user: @user, name: "My Listed Farm")

    get farms_path
    assert_response :success
  end

  # ========== region 認可 ==========
  #
  # region（admin のみ設定・更新可）の認可は FarmPolicy.normalize_attrs_for_* が
  # 判定する（Controller の strong params は mass-assignment 許可のみ）。
  #   → test/policies/farm_policy_test.rb
  # このため region 系の controller テストは policy テストへ切り離した。
end
