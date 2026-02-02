# frozen_string_literal: true

require 'test_helper'
require_relative '../support/agrr_mock_helper'

class PlansDragDropTaskScheduleTest < ActionDispatch::IntegrationTest
  include AgrrMockHelper
  
  setup do
    @user = create(:user)
    sign_in_as @user
    
    # AGRRコマンドをモック化
    stub_all_agrr_commands
    
    # 農場を作成
    @farm = create(:farm, user: @user, name: 'テスト農場')
    
    # 作物を作成（成長ステージ付き）
    @crop = create(:crop, :tomato, :with_stages, user: @user)
    
    # 計画を作成（年度ベース）
    @plan = create(:cultivation_plan, user: @user, farm: @farm, plan_type: 'private')
    
    # 計画圃場を作成
    @plan_field = create(:cultivation_plan_field, 
      cultivation_plan: @plan, 
      name: '圃場1', 
      area: 100.0
    )
    
    # 計画作物を作成
    @plan_crop = create(:cultivation_plan_crop,
      cultivation_plan: @plan,
      crop: @crop,
      name: @crop.name
    )
    
    # field_cultivationを作成
    @field_cultivation = create(:field_cultivation,
      cultivation_plan: @plan,
      cultivation_plan_field: @plan_field,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.current + 30.days,
      completion_date: Date.current + 90.days,
      area: 50.0
    )
    
    # task_scheduleを作成（field_cultivationに紐付ける）
    @task_schedule = create(:task_schedule,
      cultivation_plan: @plan,
      field_cultivation: @field_cultivation,
      category: 'general',
      status: TaskSchedule::STATUSES[:active]
    )
    
    # task_schedule_itemを作成
    @task_schedule_item = create(:task_schedule_item,
      task_schedule: @task_schedule,
      name: '潅水',
      scheduled_date: Date.current + 40.days
    )
    
    # 天気データを作成（adjust処理に必要）
    @weather_location = create(:weather_location,
      latitude: @farm.latitude || 35.0,
      longitude: @farm.longitude || 139.0
    )
    
    # 天気データを追加（adjust処理に必要）
    # NOTE: 過去20年分は重いためテストではサンプル化して短縮する
    end_date = Date.current
    start_date = [end_date - 365.days, end_date - 20.years.to_i.days].max
    (start_date..end_date).each do |date|
      create(:weather_datum,
        weather_location: @weather_location,
        date: date,
        temperature_max: 25.0,
        temperature_min: 15.0,
        temperature_mean: 20.0
      )
    end
    
    @farm.update!(weather_location: @weather_location)
    
    # 既存の予測データを設定（adjust処理で新規予測を実行しないようにするため）
    prediction_end_date = @plan.planning_end_date || (Date.current + 1.year).end_of_year
    mock_prediction_data = mock_weather_data(
      @weather_location.latitude,
      @weather_location.longitude,
      Date.current,
      prediction_end_date
    )
    @plan.update!(
      predicted_weather_data: {
        'data' => mock_prediction_data['data'],
        'target_end_date' => prediction_end_date.to_s,
        'prediction_start_date' => Date.current.to_s,
        'prediction_days' => mock_prediction_data['data'].count
      }
    )
  end
  
  test "plansでドラッグアンドドロップ後もtask_scheduleが存在すること" do
    # 事前確認: task_scheduleが存在することを確認
    assert TaskSchedule.exists?(@task_schedule.id), "事前確認: task_scheduleが存在すること"
    assert_equal @field_cultivation.id, @task_schedule.reload.field_cultivation_id
    
    # ドラッグアンドドロップをシミュレート（adjust APIを呼び出す）
    # 移動指示を作成（同じ圃場内で日付を少し変更）
    moves = [{
      allocation_id: @field_cultivation.id,
      action: 'move',
      to_field_id: @plan_field.id,
      to_start_date: (Date.current + 35.days).iso8601
    }]
    
    # adjust APIを呼び出す
    post "/api/v1/plans/cultivation_plans/#{@plan.id}/adjust",
      params: { moves: moves },
      headers: { 'Content-Type' => 'application/json' },
      as: :json
    
    # レスポンスを確認
    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data['success'], "adjust APIが成功すること: #{response_data.inspect}"
    
    # 新しいfield_cultivationが作成されていることを確認
    new_field_cultivations = @plan.reload.field_cultivations
    assert new_field_cultivations.any?, "新しいfield_cultivationが作成されていること"
    
    # ⭐ 重要: task_scheduleが存在することを確認
    # 元のtask_scheduleは削除されるが、新しいfield_cultivationに対応するtask_scheduleが存在するか、
    # または元のtask_scheduleが保持されているかを確認
    task_schedules = @plan.reload.task_schedules
    assert task_schedules.any?, "task_scheduleが存在すること（現在: #{task_schedules.count}件）"
    
    # task_schedule_itemも存在することを確認
    task_schedule_items = TaskScheduleItem.joins(:task_schedule)
      .where(task_schedules: { cultivation_plan_id: @plan.id })
    assert task_schedule_items.any?, "task_schedule_itemが存在すること（現在: #{task_schedule_items.count}件）"
  end

  test "通年計画でドラッグアンドドロップ後もtask_scheduleが存在すること" do
    # 通年計画を作成（plan_yearがnull）
    # 新しい一意制約により、同じ農場・ユーザで複数の計画を作成できないため、異なる農場を使用
    annual_farm = create(:farm, user: @user, name: '通年計画用農場')
    # adjust APIで気象データが必要なため、weather_locationを設定
    annual_farm.update!(weather_location: @weather_location)
    annual_plan = create(:cultivation_plan, :annual_planning, user: @user, farm: annual_farm, plan_type: 'private')
    
    # 計画圃場を作成
    plan_field = create(:cultivation_plan_field, 
      cultivation_plan: annual_plan, 
      name: '圃場1', 
      area: 100.0
    )
    
    # 計画作物を作成
    plan_crop = create(:cultivation_plan_crop,
      cultivation_plan: annual_plan,
      crop: @crop,
      name: @crop.name
    )
    
    # field_cultivationを作成
    field_cultivation = create(:field_cultivation,
      cultivation_plan: annual_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.current + 30.days,
      completion_date: Date.current + 90.days,
      area: 50.0
    )
    
    # task_scheduleを作成（field_cultivationに紐付ける）
    task_schedule = create(:task_schedule,
      cultivation_plan: annual_plan,
      field_cultivation: field_cultivation,
      category: 'general',
      status: TaskSchedule::STATUSES[:active]
    )
    
    # task_schedule_itemを作成
    task_schedule_item = create(:task_schedule_item,
      task_schedule: task_schedule,
      name: '潅水',
      scheduled_date: Date.current + 40.days
    )
    
    # 既存の予測データを設定
    prediction_end_date = annual_plan.planning_end_date || (Date.current + 1.year).end_of_year
    mock_prediction_data = mock_weather_data(
      @weather_location.latitude,
      @weather_location.longitude,
      Date.current,
      prediction_end_date
    )
    annual_plan.update!(
      predicted_weather_data: {
        'data' => mock_prediction_data['data'],
        'target_end_date' => prediction_end_date.to_s,
        'prediction_start_date' => Date.current.to_s,
        'prediction_days' => mock_prediction_data['data'].count
      }
    )
    
    # 事前確認: task_scheduleが存在することを確認
    assert TaskSchedule.exists?(task_schedule.id), "事前確認: task_scheduleが存在すること"
    assert_equal field_cultivation.id, task_schedule.reload.field_cultivation_id
    
    # ドラッグアンドドロップをシミュレート（adjust APIを呼び出す）
    # 移動指示を作成（同じ圃場内で日付を少し変更）
    moves = [{
      allocation_id: field_cultivation.id,
      action: 'move',
      to_field_id: plan_field.id,
      to_start_date: (Date.current + 35.days).iso8601
    }]
    
    # adjust APIを呼び出す
    post "/api/v1/plans/cultivation_plans/#{annual_plan.id}/adjust",
      params: { moves: moves },
      headers: { 'Content-Type' => 'application/json' },
      as: :json
    
    # レスポンスを確認
    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data['success'], "adjust APIが成功すること: #{response_data.inspect}"
    
    # 新しいfield_cultivationが作成されていることを確認
    new_field_cultivations = annual_plan.reload.field_cultivations
    assert new_field_cultivations.any?, "新しいfield_cultivationが作成されていること"
    
    # task_scheduleが存在することを確認
    task_schedules = annual_plan.reload.task_schedules
    assert task_schedules.any?, "task_scheduleが存在すること（現在: #{task_schedules.count}件）"
    
    # task_schedule_itemも存在することを確認
    task_schedule_items = TaskScheduleItem.joins(:task_schedule)
      .where(task_schedules: { cultivation_plan_id: annual_plan.id })
    assert task_schedule_items.any?, "task_schedule_itemが存在すること（現在: #{task_schedule_items.count}件）"
  end
end

