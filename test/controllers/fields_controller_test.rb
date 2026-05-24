# frozen_string_literal: true

require "test_helper"

class FieldsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user)
  end

  # index / show のテンプレート描画は test/views/fields_view_test.rb が担保する。
  # ここは Interactor + Presenter の配線が通ることのみ確認する。
  test "index_renders_successfully" do
    sign_in_as @user
    create(:field, farm: @farm, user: @user, name: "Alpha Plot")

    get farm_fields_path(@farm)
    assert_response :success
  end

  test "index_redirects_when_user_cannot_access_farm" do
    other = create(:user)
    sign_in_as other
    get farm_fields_path(@farm)
    assert_redirected_to farms_path
    assert_predicate flash[:alert], :present?
  end

  test "show_renders_successfully" do
    sign_in_as @user
    field = create(:field, farm: @farm, user: @user, name: "Beta Row")

    get farm_field_path(@farm, field)
    assert_response :success
  end

  test "show_redirects_when_field_not_found" do
    sign_in_as @user
    get farm_field_path(@farm, 99_999_999)
    assert_redirected_to farm_fields_path(@farm)
    assert_predicate flash[:alert], :present?
  end

  test "new_renders_successfully" do
    sign_in_as @user
    get new_farm_field_path(@farm)
    assert_response :success
  end

  test "new_redirects_when_user_cannot_access_farm" do
    other = create(:user)
    sign_in_as other
    get new_farm_field_path(@farm)
    assert_redirected_to farms_path
    assert_predicate flash[:alert], :present?
  end

  test "edit_renders_successfully" do
    sign_in_as @user
    field = create(:field, farm: @farm, user: @user, name: "Edit Plot")

    get edit_farm_field_path(@farm, field)
    assert_response :success
  end

  test "edit_redirects_when_field_not_found" do
    sign_in_as @user
    get edit_farm_field_path(@farm, 99_999_999)
    assert_redirected_to farm_fields_path(@farm)
    assert_predicate flash[:alert], :present?
  end

  test "destroy_via_html_redirects_with_undo_notice" do
    sign_in_as @user
    field = create(:field, farm: @farm, user: @user, name: "テスト圃場")
    display_name = field.display_name

    assert_difference -> { Field.count }, -1 do
      assert_difference "DeletionUndoEvent.count", +1 do
        delete farm_field_path(@farm, field) # HTMLリクエスト
        assert_redirected_to farm_fields_path(@farm)
      end
    end

    expected_notice = I18n.t(
      "deletion_undo.redirect_notice",
      resource: display_name
    )
    assert_equal expected_notice, flash[:notice]
  end
end
