# frozen_string_literal: true

require 'test_helper'

class AgriculturalTasksControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
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
    assert_select '.agricultural-task-name', text: @user_task.name
    assert_select '.agricultural-task-name', text: @reference_task.name, count: 0
    assert_select '.agricultural-task-name', text: @admin_task.name, count: 0
  end

  test '管理者は参照作業と自分の作業を一覧表示できる' do
    sign_in_as @admin_user

    get agricultural_tasks_path

    assert_response :success
    assert_select '.agricultural-task-name', text: @reference_task.name
    assert_select '.agricultural-task-name', text: @admin_task.name
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

  test 'destroy_returns_undo_token_json' do
    sign_in_as @user
    task = create(:agricultural_task, :user_owned, user: @user)

    assert_difference -> { AgriculturalTask.count }, -1 do
      assert_difference 'DeletionUndoEvent.count', +1 do
        delete agricultural_task_path(task), as: :json
        assert_response :success
      end
    end

    body = JSON.parse(@response.body)
    %w[undo_token undo_deadline toast_message undo_path auto_hide_after redirect_path resource_dom_id resource].each do |key|
      assert body.key?(key), "JSONレスポンスに#{key}が含まれていません"
      assert body[key].present?, "#{key} が空です"
    end

    undo_token = body.fetch('undo_token')
    event = DeletionUndoEvent.find(undo_token)
    assert_equal 'AgriculturalTask', event.resource_type
    assert_equal task.id.to_s, event.resource_id
    assert event.scheduled?
    assert_equal undo_deletion_path(undo_token: undo_token), body.fetch('undo_path')
    assert_equal agricultural_tasks_path(locale: I18n.locale), body.fetch('redirect_path')
    assert_equal dom_id(task), body.fetch('resource_dom_id')
    assert_equal task.name, body.fetch('resource')
  end

  test 'undo_endpoint_restores_agricultural_task' do
    sign_in_as @user
    task = create(:agricultural_task, :user_owned, user: @user)

    delete agricultural_task_path(task), as: :json
    assert_response :success

    body = JSON.parse(@response.body)
    undo_token = body.fetch('undo_token')

    assert_not AgriculturalTask.exists?(task.id), '削除後にAgriculturalTaskが残っています'

    assert_difference -> { AgriculturalTask.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    undo_body = JSON.parse(@response.body)
    assert_equal 'restored', undo_body.fetch('status')
    assert_equal undo_token, undo_body.fetch('undo_token')

    restored_event = DeletionUndoEvent.find(undo_token)
    assert restored_event.restored?
    assert AgriculturalTask.exists?(task.id), 'Undo後にAgriculturalTaskが復元されていません'
  end

  # TODO: destroyアクションのHTMLレスポンスに対するリダイレクトとflashのテストを追加する
end


