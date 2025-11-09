# frozen_string_literal: true

require 'test_helper'

class Plans::TaskSchedulesControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    travel_to Time.zone.local(2025, 3, 10, 9, 0, 0)

    @user = create(:user)
    session_id = create_session_for(@user)
    @headers = session_cookie_header(session_id)

    @plan = create(:cultivation_plan, :completed, user: @user, farm: create(:farm, user: @user))
    @field_cultivation = create(:field_cultivation, cultivation_plan: @plan)

    @general_schedule = create(:task_schedule, cultivation_plan: @plan, field_cultivation: @field_cultivation, category: 'general')

    create(:task_schedule_item,
           task_schedule: @general_schedule,
           scheduled_date: Date.current + 1.day,
           name: '本週作業')

    create(:task_schedule_item,
           task_schedule: @general_schedule,
           scheduled_date: Date.current + 9.days,
           name: '来週作業')

    create(:task_schedule_item,
           task_schedule: @general_schedule,
           scheduled_date: nil,
           name: '未確定作業')
  end

  teardown do
    travel_back
  end

  test '週タイムラインAPIが指定週の作業と未確定作業を返す' do
    get plan_task_schedule_path(@plan, format: :json), headers: @headers

    assert_response :success

    data = JSON.parse(response.body)
    assert_equal @plan.id, data['plan']['id']
    assert_equal '2025-03-10', data['week']['start_date']

    assert_equal 1, data['fields'].size

    field_entry = data['fields'].first
    general_tasks = field_entry.dig('schedules', 'general')
    unscheduled_tasks = field_entry.dig('schedules', 'unscheduled')

    assert_equal ['本週作業'], general_tasks.map { |task| task['name'] }
    assert_equal ['未確定作業'], unscheduled_tasks.map { |task| task['name'] }
  end

  test '週開始日を指定すると対象週のみが含まれる' do
    next_week_start = (Date.current + 7.days).beginning_of_week

    get plan_task_schedule_path(@plan, format: :json, params: { week_start: next_week_start.iso8601 }), headers: @headers

    assert_response :success

    data = JSON.parse(response.body)
    field_entry = data['fields'].first
    general_tasks = field_entry.dig('schedules', 'general')

    task_names = general_tasks.map { |task| task['name'] }
    assert_includes task_names, '来週作業'
    assert_not_includes task_names, '本週作業'
  end

  test '作業予定が存在しない場合は空の結果を返す' do
    plan_without_schedule = create(:cultivation_plan, :completed, user: @user, farm: create(:farm, user: @user))

    get plan_task_schedule_path(plan_without_schedule, format: :json), headers: @headers

    assert_response :success

    data = JSON.parse(response.body)
    assert_equal [], data['fields']
    assert_equal plan_without_schedule.id, data['plan']['id']
  end
end


