# frozen_string_literal: true

require 'test_helper'

class AgriculturalTasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @admin_user = create(:user, admin: true)

    @reference_task = create(:agricultural_task)
    @user_task = create(:agricultural_task, :user_owned, user: @user)
    @admin_task = create(:agricultural_task, :user_owned, user: @admin_user)
  end

  test '一般ユーザーは自分の作業のみ一覧表示できる' do
    sign_in_as @user

    get agricultural_tasks_path

    assert_response :success
    assert_select '.crop-name', text: @user_task.name
    assert_select '.crop-name', text: @reference_task.name, count: 0
    assert_select '.crop-name', text: @admin_task.name, count: 0
  end

  test '管理者は参照作業と自分の作業を一覧表示できる' do
    sign_in_as @admin_user

    get agricultural_tasks_path

    assert_response :success
    assert_select '.crop-name', text: @reference_task.name
    assert_select '.crop-name', text: @admin_task.name
  end

  test '一般ユーザーは新規作業フォームに必要項目を表示できる' do
    sign_in_as @user

    get new_agricultural_task_path

    assert_response :success
    assert_select 'form[action="' + agricultural_tasks_path + '"][method="post"]' do
      assert_select 'input[name="agricultural_task[name]"]'
      assert_select 'textarea[name="agricultural_task[description]"]'
      assert_select 'input[name="agricultural_task[time_per_sqm]"]'
      assert_select 'select[name="agricultural_task[weather_dependency]"]'
      assert_select 'textarea[name="agricultural_task[required_tools]"]'
      assert_select 'select[name="agricultural_task[skill_level]"]'
      assert_select 'input[name="agricultural_task[is_reference]"]', false
    end
  end

  test '管理者の新規作業フォームには参照フラグが表示される' do
    sign_in_as @admin_user

    get new_agricultural_task_path

    assert_response :success
    assert_select 'form[action="' + agricultural_tasks_path + '"][method="post"]' do
      assert_select 'input[name="agricultural_task[is_reference]"][type="checkbox"]'
    end
  end

  test '一般ユーザーは自身の作業詳細を表示できる' do
    sign_in_as @user

    get agricultural_task_path(@user_task)

    assert_response :success
    assert_select 'h1', text: @user_task.name
  end
end


