# frozen_string_literal: true

require 'test_helper'

class Plans::TaskScheduleItemsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    travel_to Time.zone.local(2026, 2, 20, 9, 0, 0)

    @user = create(:user)
    session_id = create_session_for(@user)
    @headers = session_cookie_header(session_id)

    farm = create(:farm, user: @user)
    @plan = create(:cultivation_plan, :completed, user: @user, farm: farm)
    @field_cultivation = create(:field_cultivation, cultivation_plan: @plan)
    @agricultural_task = create(:agricultural_task)

    @general_schedule = create(:task_schedule, cultivation_plan: @plan, field_cultivation: @field_cultivation, category: 'general')

    @task = create(:task_schedule_item,
                   task_schedule: @general_schedule,
                   scheduled_date: Date.current + 3.days,
                   name: '灌水')

    create(
      :crop_task_template,
      crop: @field_cultivation.cultivation_plan_crop.crop,
      agricultural_task: @agricultural_task,
      source_agricultural_task_id: @agricultural_task.id,
      name: @agricultural_task.name,
      description: @agricultural_task.description,
      time_per_sqm: @agricultural_task.time_per_sqm,
      weather_dependency: @agricultural_task.weather_dependency,
      required_tools: @agricultural_task.required_tools,
      skill_level: @agricultural_task.skill_level,
      task_type: @agricultural_task.task_type,
      task_type_id: @agricultural_task.task_type_id,
      is_reference: @agricultural_task.is_reference
    )

    @field_cultivation.cultivation_plan_crop.crop.agricultural_tasks << @agricultural_task
  end

  teardown do
    travel_back
  end

  test 'ユーザーは作業予定の日付を更新できる' do
    patch plan_task_schedule_item_path(@plan, @task),
          params: {
            task_schedule_item: {
              scheduled_date: (Date.current + 5.days).iso8601
            }
          },
          headers: @headers,
          as: :json

    assert_response :success

    body = JSON.parse(response.body)
    assert_equal((Date.current + 5.days).iso8601, body['scheduled_date'])

    @task.reload
    assert_equal Date.current + 5.days, @task.scheduled_date
    assert_equal 'rescheduled', @task.read_attribute('status')
  end

  test 'ユーザーは作業予定の実績を登録できる' do
    post complete_plan_task_schedule_item_path(@plan, @task),
         params: {
           completion: {
             actual_date: Date.current + 4.days,
             notes: '予定通り完了'
           }
         },
         headers: @headers,
         as: :json

    assert_response :success

    @task.reload
    assert_equal 'completed', @task.read_attribute('status')
    assert_equal Date.current + 4.days, @task.read_attribute('actual_date')
    assert_equal '予定通り完了', @task.read_attribute('actual_notes')
  end

  test 'ユーザーは圃場ごとに作業予定を追加できる' do
    assert_difference('TaskScheduleItem.count', 1) do
      post plan_task_schedule_items_path(@plan),
           params: {
             task_schedule_item: {
               field_cultivation_id: @field_cultivation.id,
               cultivation_plan_crop_id: @field_cultivation.cultivation_plan_crop_id,
               agricultural_task_id: @agricultural_task.id,
               name: '温室換気',
               task_type: 'field_work',
               scheduled_date: (Date.current + 6.days).iso8601,
               priority: 3
             }
           },
           headers: @headers,
           as: :json
    end

    assert_response :created

    created = TaskScheduleItem.find_by(name: '温室換気')
    assert_not_nil created
    assert_equal Date.current + 6.days, created.scheduled_date
    assert_equal 'planned', created.read_attribute('status')
    assert_equal @agricultural_task.id, created.agricultural_task_id
  end

  test 'ユーザーは作業テンプレートを適用して予定を追加できる' do
    template = @field_cultivation.cultivation_plan_crop.crop.crop_task_templates.first

    assert_difference('TaskScheduleItem.count', 1) do
      post plan_task_schedule_items_path(@plan),
           params: {
             task_schedule_item: {
               field_cultivation_id: @field_cultivation.id,
               cultivation_plan_crop_id: @field_cultivation.cultivation_plan_crop_id,
               crop_task_template_id: template.id,
               scheduled_date: (Date.current + 7.days).iso8601
             }
           },
           headers: @headers,
           as: :json
    end

    assert_response :created

    created = TaskScheduleItem.find_by(source: 'template_entry')
    assert_equal template.name, created.name
    assert_equal template.agricultural_task_id, created.agricultural_task_id
    assert_equal 'template_entry', created.source
    assert_equal template.weather_dependency, created.weather_dependency
    assert_equal template.time_per_sqm&.to_d, created.time_per_sqm
    assert_equal template.source_agricultural_task_id || template.agricultural_task_id, created.source_agricultural_task_id
  end

  test '休閑では作物選択が必要で未指定は422' do
    assert_no_difference('TaskScheduleItem.count') do
      post plan_task_schedule_items_path(@plan),
           params: {
             task_schedule_item: {
               field_cultivation_id: @field_cultivation.id,
               name: '除草',
               task_type: 'field_work',
               scheduled_date: (Date.current + 6.days).iso8601,
               priority: 3
             }
           },
           headers: @headers,
           as: :json
    end

    assert_response :unprocessable_entity
  end

  test '他の作物を指定すると422' do
    other_crop = create(:cultivation_plan_crop, cultivation_plan: @plan)

    assert_no_difference('TaskScheduleItem.count') do
      post plan_task_schedule_items_path(@plan),
           params: {
             task_schedule_item: {
               field_cultivation_id: @field_cultivation.id,
               cultivation_plan_crop_id: other_crop.id,
               agricultural_task_id: @agricultural_task.id,
               name: '水やり',
               task_type: 'field_work',
               scheduled_date: (Date.current + 4.days).iso8601,
               priority: 2
             }
           },
           headers: @headers,
           as: :json
    end

    assert_response :unprocessable_entity
  end

  test 'ユーザーは作業予定をキャンセルできる' do
    delete plan_task_schedule_item_path(@plan, @task), headers: @headers

    assert_redirected_to plan_task_schedule_path(@plan)
    assert_not TaskScheduleItem.exists?(@task.id), '削除後にTaskScheduleItemが残っています'
  end

  test '作業予定のキャンセルはUndo情報を返す' do
    assert_difference -> { TaskScheduleItem.count }, -1 do
      assert_difference 'DeletionUndoEvent.count', +1 do
        delete plan_task_schedule_item_path(@plan, @task), headers: @headers, as: :json
        assert_response :success
      end
    end

    body = JSON.parse(response.body)
    %w[undo_token undo_deadline toast_message undo_path auto_hide_after resource redirect_path resource_dom_id].each do |key|
      assert body.key?(key), "JSONレスポンスに#{key}が含まれていません"
      assert body.fetch(key).present?, "#{key} が空です"
    end

    undo_token = body.fetch('undo_token')
    event = DeletionUndoEvent.find(undo_token)

    assert_equal 'TaskScheduleItem', event.resource_type
    assert_equal @task.id.to_s, event.resource_id
    assert event.scheduled?
    assert_equal undo_deletion_path(undo_token: undo_token), body.fetch('undo_path')
    assert_equal ActionView::RecordIdentifier.dom_id(@task), body.fetch('resource_dom_id')
    assert_equal @task.name, body.fetch('resource')
    assert_equal plan_task_schedule_path(@plan), body.fetch('redirect_path')
  end

  test 'Undo APIで作業予定を復元できる' do
    delete plan_task_schedule_item_path(@plan, @task), headers: @headers, as: :json
    assert_response :success

    body = JSON.parse(response.body)
    undo_token = body.fetch('undo_token')

    assert_not TaskScheduleItem.exists?(@task.id), '削除後にTaskScheduleItemが残っています'

    assert_difference -> { TaskScheduleItem.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, headers: @headers, as: :json
      assert_response :success
    end

    undo_body = JSON.parse(response.body)
    assert_equal 'restored', undo_body.fetch('status')
    assert_equal undo_token, undo_body.fetch('undo_token')

    restored_event = DeletionUndoEvent.find(undo_token)
    assert restored_event.restored?
    assert TaskScheduleItem.exists?(@task.id), 'Undo後にTaskScheduleItemが復元されていません'
  end

  test 'Undo期限切れの場合はエラーを返す' do
    delete plan_task_schedule_item_path(@plan, @task), headers: @headers, as: :json
    assert_response :success

    undo_token = JSON.parse(response.body).fetch('undo_token')
    event = DeletionUndoEvent.find(undo_token)

    travel_to(event.expires_at + 1.minute) do
      post undo_deletion_path, params: { undo_token: undo_token }, headers: @headers, as: :json
    end

    assert_response :unprocessable_entity

    body = JSON.parse(response.body)
    assert_equal 'error', body.fetch('status')
    assert_equal I18n.t('deletion_undo.expired'), body.fetch('error')

    assert_equal 'expired', DeletionUndoEvent.find(undo_token).state
    assert_not TaskScheduleItem.exists?(@task.id), '期限切れ後にTaskScheduleItemが復元されています'
  end

  test '他ユーザーの作業予定は操作できない' do
    other_user = create(:user)
    other_session_id = create_session_for(other_user)
    other_headers = session_cookie_header(other_session_id)

    patch plan_task_schedule_item_path(@plan, @task),
          params: { task_schedule_item: { scheduled_date: (Date.current + 1.day).iso8601 } },
          headers: other_headers,
          as: :json

    assert_response :not_found
  end

  test 'RecordInvalid の場合は422とフィールド単位のエラーを返す' do
    assert_no_difference('TaskScheduleItem.count') do
      post plan_task_schedule_items_path(@plan),
           params: {
             task_schedule_item: {
               field_cultivation_id: @field_cultivation.id,
               name: '除草',
               task_type: 'field_work',
               scheduled_date: (Date.current + 6.days).iso8601,
               priority: 3
             }
           },
           headers: @headers,
           as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)

    assert_equal I18n.t('plans.task_schedules.detail.actions.crop_required'), body['error']
    assert_equal [I18n.t('plans.task_schedules.detail.actions.crop_required')], body.dig('errors', 'base')
  end

  test '作業予定のキャンセルが失敗した場合は統一メッセージを返す' do
    @task.update_columns(source: 'agrr', gdd_trigger: nil)

    delete plan_task_schedule_item_path(@plan, @task), headers: @headers, as: :json

    assert_response :unprocessable_entity

    body = JSON.parse(response.body)
    expected = I18n.t('controllers.plans.task_schedule_items.errors.cancel_failed')
    assert_equal expected, body['error']
    assert TaskScheduleItem.exists?(@task.id), '失敗時はレコードが削除されてはいけません'
  end

  test '作業予定の完了登録が失敗した場合は422とエラー詳細を返す' do
    invalid_item = @task.dup
    invalid_item.source = 'agrr'
    invalid_item.gdd_trigger = nil
    invalid_item.validate
    expected_error_messages = invalid_item.errors.full_messages_for(:gdd_trigger)
    expected_base = ["Validation failed: #{invalid_item.errors.full_messages.first}"]

    @task.update_columns(source: 'agrr', gdd_trigger: nil)

    post complete_plan_task_schedule_item_path(@plan, @task),
         params: {
           completion: {
             actual_date: Date.current,
             notes: 'テスト'
           }
         },
         headers: @headers,
         as: :json

    assert_response :unprocessable_entity

    body = JSON.parse(response.body)
    assert_equal expected_error_messages.first, body['error']
    assert_equal expected_base, body.dig('errors', 'base')
    assert_equal expected_error_messages, body.dig('errors', 'gdd_trigger')
  end

  test 'RecordNotFound の場合は404とエラーメッセージを返す' do
    patch plan_task_schedule_item_path(@plan, -1),
          params: { task_schedule_item: { scheduled_date: (Date.current + 1.day).iso8601 } },
          headers: @headers,
          as: :json

    assert_response :not_found

    body = JSON.parse(response.body)
    expected = I18n.t('controllers.plans.task_schedule_items.errors.not_found')
    assert_equal expected, body['error']
    assert_equal [expected], body.dig('errors', 'base')
  end

  test '必須パラメーター欠如の場合は400とエラーメッセージを返す' do
    post plan_task_schedule_items_path(@plan), headers: @headers, as: :json

    assert_response :bad_request

    body = JSON.parse(response.body)
    expected = I18n.t('controllers.plans.task_schedule_items.errors.parameter_missing')
    assert_equal expected, body['error']
    assert_equal [expected], body.dig('errors', 'base')
  end
end
