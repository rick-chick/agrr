# frozen_string_literal: true

require "test_helper"

# HTML 応答形（redirect / 一覧描画）の境界のみ。認可・永続化・ネスト属性・作物関連付けの網羅は
# test/domain/pest/interactors/*、test/adapters/pest/gateways/*、
# test/controllers/api/v1/masters/pests_controller_test.rb、
# test/integration/pest_crop_association_test.rb が担保する。
class PestsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    @user = create(:user)
    sign_in_as @user
    @pest = create(:pest, :complete, is_reference: true)
  end

  test "index は正常に描画される" do
    get pests_path
    assert_response :success
    assert_select "h1", text: I18n.t("pests.index.title")
  end

  test "show は正常に描画される" do
    get pest_path(@pest)
    assert_response :success
    assert_select "h1", text: @pest.name
  end

  test "create は redirect する（配線）" do
    assert_difference("Pest.count", 1) do
      post pests_path, params: { pest: {
        name: "テスト害虫",
        is_reference: false
      } }
    end

    assert_redirected_to pest_path(Pest.last)
  end

  test "destroy_via_html_redirects_with_undo_notice" do
    pest = create(:pest, :user_owned, user: @user)

    assert_difference -> { Pest.count }, -1 do
      assert_difference -> { DeletionUndoEvent.count }, +1 do
        delete pest_path(pest)
      end
    end

    assert_redirected_to pests_path
    assert_equal I18n.t("deletion_undo.redirect_notice", resource: pest.name), flash[:notice]

    event = DeletionUndoEvent.find_by!(resource_type: "Pest", resource_id: pest.id.to_s)
    assert_equal I18n.t("pests.undo.toast", name: pest.name), event.toast_message
  end

  test "一般ユーザーの参照害虫作成失敗は redirect + flash へマッピングされる" do
    post pests_path, params: { pest: {
      pest_id: "test_pest_ref",
      name: "参照害虫",
      is_reference: true
    } }

    assert_redirected_to pests_path
    assert_equal I18n.t("pests.flash.reference_only_admin"), flash[:alert]
  end

  test "一般ユーザーの is_reference 変更失敗は redirect + flash へマッピングされる" do
    pest = create(:pest, :user_owned, user: @user)

    patch pest_path(pest), params: { pest: {
      name: pest.name,
      is_reference: true
    } }

    assert_redirected_to pest_path(pest)
    assert_equal I18n.t("pests.flash.reference_flag_admin_only"), flash[:alert]
  end

  test "参照害虫は一般ユーザーが destroy できない" do
    assert_no_difference("Pest.count") do
      delete pest_path(@pest)
    end

    assert_redirected_to pests_path
    assert_equal I18n.t("pests.flash.no_permission"), flash[:alert]
  end

  test "should handle RecordNotFound in show" do
    get pest_path(id: 99_999)
    assert_redirected_to pests_path
    assert_equal I18n.t("pests.flash.not_found"), flash[:alert]
  end

  test "should handle RecordNotFound in update" do
    patch pest_path(id: 99_999), params: { pest: { name: "Test" } }
    assert_redirected_to pests_path
    assert_equal I18n.t("pests.flash.not_found"), flash[:alert]
  end

  test "should handle RecordNotFound in destroy" do
    delete pest_path(id: 99_999)
    assert_redirected_to pests_path
    assert_equal I18n.t("pests.flash.not_found"), flash[:alert]
  end
end
