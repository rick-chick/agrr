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

    assert_response :no_content

    @task.reload
    assert_equal 'cancelled', @task.read_attribute('status')
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

  test '作業予定のキャンセルが失敗した場合は422とエラー詳細を返す' do
    invalid_item = @task.dup
    invalid_item.source = 'agrr'
    invalid_item.gdd_trigger = nil
    invalid_item.validate
    expected_error_messages = invalid_item.errors.full_messages_for(:gdd_trigger)
    expected_base = ["Validation failed: #{invalid_item.errors.full_messages.first}"]

    @task.update_columns(source: 'agrr', gdd_trigger: nil)

    delete plan_task_schedule_item_path(@plan, @task), headers: @headers, as: :json

    assert_response :unprocessable_entity

    body = JSON.parse(response.body)
    assert_equal expected_error_messages.first, body['error']
    assert_equal expected_base, body.dig('errors', 'base')
    assert_equal expected_error_messages, body.dig('errors', 'gdd_trigger')
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
