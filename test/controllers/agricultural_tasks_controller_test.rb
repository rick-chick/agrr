# frozen_string_literal: true

require "test_helper"

# HTML 応答形の境界のみ。作物関連付けの永続化は domain/adapters テストが担保する。
class AgriculturalTasksControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  setup do
    @user = create(:user)
    @admin_user = create(:user, admin: true)

    @reference_task = create(:agricultural_task)
    @user_task = create(:agricultural_task, :user_owned, user: @user)
    @admin_task = create(:agricultural_task, :user_owned, user: @admin_user)
  end

  test "一般ユーザーは自分の作業のみ一覧表示できる" do
    sign_in_as @user

    get agricultural_tasks_path

    assert_response :success
    assert_select ".agricultural-task-name", text: @user_task.name
    assert_select ".agricultural-task-name", text: @reference_task.name, count: 0
    assert_select ".agricultural-task-name", text: @admin_task.name, count: 0
  end

  test "管理者は参照作業と自分の作業を一覧表示できる" do
    sign_in_as @admin_user

    get agricultural_tasks_path

    assert_response :success
    assert_select ".agricultural-task-name", text: @reference_task.name
    assert_select ".agricultural-task-name", text: @admin_task.name
  end

  test "一般ユーザーは自身の作業詳細を表示できる" do
    sign_in_as @user

    crop = create(:crop, user: @user, variety: "桃太郎")
    CropTaskTemplate.create!(
      crop: crop,
      agricultural_task: @user_task,
      name: @user_task.name,
      description: @user_task.description,
      time_per_sqm: @user_task.time_per_sqm,
      weather_dependency: @user_task.weather_dependency,
      required_tools: @user_task.required_tools,
      skill_level: @user_task.skill_level
    )

    get agricultural_task_path(@user_task)

    assert_response :success
    assert_select "h1", text: @user_task.name
    assert_select ".associated-crops-grid .associated-crop-card", count: 1
    assert_select ".associated-crop-card__name", text: crop.name
    assert_select ".associated-crop-card__variety", text: "(#{crop.variety})"
  end

  # is_reference（admin のみ設定・変更可）の認可は
  # AgriculturalTaskCreate/UpdateInteractor が判定する
  #   → test/domain/agricultural_task/interactors/agricultural_task_{create,update}_interactor_test.rb
  # 以下の controller テストは認可失敗の HTTP 応答（redirect + flash）の境界のみ検証する。
  test "一般ユーザーの参照作業作成失敗は redirect + flash へマッピングされる" do
    sign_in_as @user

    post agricultural_tasks_path, params: {
      agricultural_task: {
        name: "参照作業",
        is_reference: true
      }
    }

    assert_redirected_to agricultural_tasks_path
    assert_equal I18n.t("agricultural_tasks.flash.reference_only_admin"), flash[:alert]
  end

  test "一般ユーザーの is_reference 変更失敗は redirect + flash へマッピングされる" do
    sign_in_as @user
    task = create(:agricultural_task, :user_owned, user: @user, is_reference: false)

    patch agricultural_task_path(task), params: {
      agricultural_task: {
        name: task.name,
        is_reference: true
      }
    }

    assert_redirected_to agricultural_task_path(task)
    assert_equal I18n.t("agricultural_tasks.flash.reference_flag_admin_only"), flash[:alert]
  end

  test "destroy_via_html_redirects_with_undo_notice" do
    sign_in_as @user
    task = create(:agricultural_task, :user_owned, user: @user, name: "テスト作業")
    task_name = task.name

    assert_difference -> { AgriculturalTask.count }, -1 do
      assert_difference "DeletionUndoEvent.count", +1 do
        delete agricultural_task_path(task) # HTMLリクエスト
        assert_redirected_to agricultural_tasks_path
      end
    end

    expected_notice = I18n.t(
      "deletion_undo.redirect_notice",
      resource: task_name
    )
    assert_equal expected_notice, flash[:notice]
  end

  # ========== region 認可 ==========
  #
  # region（admin のみ設定・更新可）の認可は AgriculturalTaskPolicy.normalize_attrs_for_*
  # が判定する（Controller の strong params は mass-assignment 許可のみ）。
  #   → test/policies/agricultural_task_policy_test.rb
  # このため region 系の controller テストは policy テストへ切り離した。

  test "作成時に必須項目が欠けていると一覧へリダイレクトし flash を付与する" do
    sign_in_as @user

    assert_no_difference("AgriculturalTask.count") do
      post agricultural_tasks_path, params: {
        agricultural_task: {
          name: "" # 必須項目を空にする
        }
      }
    end

    assert_redirected_to agricultural_tasks_path
    assert flash[:alert].present?
  end
end
