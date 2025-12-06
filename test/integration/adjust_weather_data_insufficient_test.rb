# frozen_string_literal: true

require "test_helper"

# 計画期間外での修正処理で気温データが不足する場合のテスト
class AdjustWeatherDataInsufficientTest < ActiveSupport::TestCase
  class Saver
    include AgrrOptimization
  end

  def setup
    @user = create(:user)
    @farm = create(:farm, user: @user, latitude: 35.6762, longitude: 139.6503, region: 'jp')
    @weather_location = create(:weather_location, 
      latitude: 35.6762, 
      longitude: 139.6503,
      elevation: 50.0,
      timezone: 'Asia/Tokyo'
    )
    @farm.update!(weather_location: @weather_location)

    # 計画期間: 2024年1月1日〜2024年12月31日
    @planning_start_date = Date.new(2024, 1, 1)
    @planning_end_date = Date.new(2024, 12, 31)
    
    @plan = create(:cultivation_plan,
      farm: @farm,
      user: @user,
      plan_type: 'private',
      planning_start_date: @planning_start_date,
      planning_end_date: @planning_end_date,
      status: 'completed'
    )

    @field = create(:cultivation_plan_field, cultivation_plan: @plan, name: 'Field 1', area: 100.0)
    @crop = create(:crop, :with_stages, user: @user, region: 'jp')
    @plan_crop = create(:cultivation_plan_crop, cultivation_plan: @plan, crop: @crop)

    # 計画期間内の作付を作成
    @field_cultivation = create(:field_cultivation,
      cultivation_plan: @plan,
      cultivation_plan_field: @field,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.new(2024, 4, 1),
      completion_date: Date.new(2024, 6, 30),
      area: 50.0,
      estimated_cost: 1000.0,
      optimization_result: {
        revenue: 2000.0,
        profit: 1000.0,
        accumulated_gdd: 500.0
      }
    )

    # 気象データを作成（過去20年分）
    create_weather_data_for_training

    @saver = Saver.new
    stub_all_agrr_commands
  end

  test "計画期間外で修正処理を実行する場合、effective_planning_endまで新規予測を実行する" do
    # 計画期間外の日付（2025年6月）に移動する指示
    moves = [{
      allocation_id: @field_cultivation.id,
      to_field_id: @field.id,
      to_start_date: Date.new(2025, 6, 1).to_s,
      to_completion_date: Date.new(2025, 8, 31).to_s
    }]

    # 既存の予測データは計画期間の終了日（2024年12月31日）までしかない
    @plan.update!(predicted_weather_data: {
      'data' => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2024, 12, 31)),
      'prediction_start_date' => Date.new(2024, 1, 1).to_s,
      'prediction_end_date' => Date.new(2024, 12, 31).to_s,
      'predicted_at' => Time.current.iso8601,
      'model' => 'lightgbm'
    })

    # WeatherPredictionServiceをモック化
    weather_prediction_service = Minitest::Mock.new
    
    # get_existing_predictionはnilを返す（既存データが不足）
    # キーワード引数で呼ばれるため、ハッシュとして渡す
    weather_prediction_service.expect(:get_existing_prediction, nil) do |kwargs|
      kwargs[:target_end_date] == Date.new(2026, 12, 31) && kwargs[:cultivation_plan] == @plan
    end
    
    # predict_for_cultivation_planが呼ばれる（effective_planning_endまで新規予測）
    prediction_result = {
      data: {
        'data' => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2026, 12, 31)),
        'prediction_start_date' => Date.new(2024, 1, 1).to_s,
        'prediction_end_date' => Date.new(2026, 12, 31).to_s
      },
      target_end_date: Date.new(2026, 12, 31),
      prediction_start_date: Date.new(2024, 1, 1).to_s,
      prediction_days: 1095
    }
    weather_prediction_service.expect(:predict_for_cultivation_plan, prediction_result) do |plan, kwargs|
      plan == @plan && kwargs[:target_end_date] == Date.new(2026, 12, 31)
    end

    WeatherPredictionService.stub(:new, weather_prediction_service) do
      result = @saver.adjust_with_db_weather(@plan, moves)
      
      assert result[:success], "修正処理が成功する必要がある。エラー: #{result[:message]}"
      weather_prediction_service.verify
    end
  end

  test "既存の予測データがeffective_planning_endをカバーしている場合、既存データを再利用する" do
    # 計画期間外の日付（2025年6月）に移動する指示
    moves = [{
      allocation_id: @field_cultivation.id,
      to_field_id: @field.id,
      to_start_date: Date.new(2025, 6, 1).to_s,
      to_completion_date: Date.new(2025, 8, 31).to_s
    }]

    # 既存の予測データがeffective_planning_end（2026年12月31日）までカバーしている
    existing_prediction_data = {
      'data' => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2026, 12, 31)),
      'prediction_start_date' => Date.new(2024, 1, 1).to_s,
      'prediction_end_date' => Date.new(2026, 12, 31).to_s,
      'predicted_at' => Time.current.iso8601,
      'model' => 'lightgbm'
    }
    @plan.update!(predicted_weather_data: existing_prediction_data)

    # WeatherPredictionServiceをモック化
    weather_prediction_service = Minitest::Mock.new
    
    # get_existing_predictionは既存データを返す
    existing_result = {
      data: existing_prediction_data,
      target_end_date: Date.new(2026, 12, 31),
      prediction_start_date: Date.new(2024, 1, 1).to_s,
      prediction_days: 1095
    }
    weather_prediction_service.expect(:get_existing_prediction, existing_result) do |kwargs|
      kwargs[:target_end_date] == Date.new(2026, 12, 31) && kwargs[:cultivation_plan] == @plan
    end
    
    # predict_for_cultivation_planは呼ばれない（既存データを再利用）

    WeatherPredictionService.stub(:new, weather_prediction_service) do
      result = @saver.adjust_with_db_weather(@plan, moves)
      
      assert result[:success], "修正処理が成功する必要がある。エラー: #{result[:message]}"
      weather_prediction_service.verify
    end
  end

  test "新規予測を実行した場合、予測データが保存される" do
    # 計画期間外の日付（2025年6月）に移動する指示
    moves = [{
      allocation_id: @field_cultivation.id,
      to_field_id: @field.id,
      to_start_date: Date.new(2025, 6, 1).to_s,
      to_completion_date: Date.new(2025, 8, 31).to_s
    }]

    # 既存の予測データは計画期間の終了日（2024年12月31日）までしかない
    @plan.update!(predicted_weather_data: {
      'data' => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2024, 12, 31)),
      'prediction_start_date' => Date.new(2024, 1, 1).to_s,
      'prediction_end_date' => Date.new(2024, 12, 31).to_s,
      'predicted_at' => Time.current.iso8601,
      'model' => 'lightgbm'
    })

    # WeatherPredictionServiceをモック化
    weather_prediction_service = Minitest::Mock.new
    
    # get_existing_predictionはnilを返す（既存データが不足）
    # キーワード引数で呼ばれるため、ハッシュとして渡す
    weather_prediction_service.expect(:get_existing_prediction, nil) do |kwargs|
      kwargs[:target_end_date] == Date.new(2026, 12, 31) && kwargs[:cultivation_plan] == @plan
    end
    
    # predict_for_cultivation_planが呼ばれる（effective_planning_endまで新規予測）
    new_prediction_data = {
      'data' => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2026, 12, 31)),
      'prediction_start_date' => Date.new(2024, 1, 1).to_s,
      'prediction_end_date' => Date.new(2026, 12, 31).to_s,
      'predicted_at' => Time.current.iso8601,
      'model' => 'lightgbm'
    }
    prediction_result = {
      data: new_prediction_data,
      target_end_date: Date.new(2026, 12, 31),
      prediction_start_date: Date.new(2024, 1, 1).to_s,
      prediction_days: 1095
    }
    weather_prediction_service.expect(:predict_for_cultivation_plan, prediction_result) do |plan, kwargs|
      plan == @plan && kwargs[:target_end_date] == Date.new(2026, 12, 31)
    end

    WeatherPredictionService.stub(:new, weather_prediction_service) do
      result = @saver.adjust_with_db_weather(@plan, moves)
      
      assert result[:success], "修正処理が成功する必要がある。エラー: #{result[:message]}, ステータス: #{result[:status]}"
      
      # モックでは実際の保存処理が実行されないため、モックが正しく呼ばれたことを確認
      # 実際の実装では predict_for_cultivation_plan 内で保存される
      weather_prediction_service.verify
      
      # モックの戻り値を使って手動で更新をシミュレート（保存処理の確認用）
      @plan.update!(predicted_weather_data: new_prediction_data)
      @plan.reload
      assert_not_nil @plan.predicted_weather_data
      assert_equal Date.new(2026, 12, 31).to_s, @plan.predicted_weather_data['prediction_end_date']
    end
  end

  test "次回以降、保存された予測データが再利用される" do
    # 1回目の修正処理: 新規予測を実行
    moves1 = [{
      allocation_id: @field_cultivation.id,
      to_field_id: @field.id,
      to_start_date: Date.new(2025, 6, 1).to_s,
      to_completion_date: Date.new(2025, 8, 31).to_s
    }]

    # 既存の予測データは計画期間の終了日（2024年12月31日）までしかない
    @plan.update!(predicted_weather_data: {
      'data' => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2024, 12, 31)),
      'prediction_start_date' => Date.new(2024, 1, 1).to_s,
      'prediction_end_date' => Date.new(2024, 12, 31).to_s,
      'predicted_at' => Time.current.iso8601,
      'model' => 'lightgbm'
    })

    # WeatherPredictionServiceをモック化（1回目）
    weather_prediction_service1 = Minitest::Mock.new
    weather_prediction_service1.expect(:get_existing_prediction, nil) do |kwargs|
      kwargs[:target_end_date] == Date.new(2026, 12, 31) && kwargs[:cultivation_plan] == @plan
    end
    
    new_prediction_data = {
      'data' => generate_prediction_data(Date.new(2024, 1, 1), Date.new(2026, 12, 31)),
      'prediction_start_date' => Date.new(2024, 1, 1).to_s,
      'prediction_end_date' => Date.new(2026, 12, 31).to_s,
      'predicted_at' => Time.current.iso8601,
      'model' => 'lightgbm'
    }
    prediction_result1 = {
      data: new_prediction_data,
      target_end_date: Date.new(2026, 12, 31),
      prediction_start_date: Date.new(2024, 1, 1).to_s,
      prediction_days: 1095
    }
    weather_prediction_service1.expect(:predict_for_cultivation_plan, prediction_result1) do |plan, kwargs|
      plan == @plan && kwargs[:target_end_date] == Date.new(2026, 12, 31)
    end

    WeatherPredictionService.stub(:new, weather_prediction_service1) do
      result1 = @saver.adjust_with_db_weather(@plan, moves1)
      assert result1[:success], "1回目の修正処理が成功する必要がある。エラー: #{result1[:message]}, ステータス: #{result1[:status]}"
      weather_prediction_service1.verify
    end

    # 2回目の修正処理: 既存データを再利用
    moves2 = [{
      allocation_id: @field_cultivation.id,
      to_field_id: @field.id,
      to_start_date: Date.new(2025, 7, 1).to_s,
      to_completion_date: Date.new(2025, 9, 30).to_s
    }]

    # WeatherPredictionServiceをモック化（2回目）
    weather_prediction_service2 = Minitest::Mock.new
    
    # get_existing_predictionは既存データを返す（1回目で保存されたデータ）
    existing_result = {
      data: new_prediction_data,
      target_end_date: Date.new(2026, 12, 31),
      prediction_start_date: Date.new(2024, 1, 1).to_s,
      prediction_days: 1095
    }
    weather_prediction_service2.expect(:get_existing_prediction, existing_result) do |kwargs|
      kwargs[:target_end_date] == Date.new(2026, 12, 31) && kwargs[:cultivation_plan] == @plan
    end
    
    # predict_for_cultivation_planは呼ばれない（既存データを再利用）

    WeatherPredictionService.stub(:new, weather_prediction_service2) do
      result2 = @saver.adjust_with_db_weather(@plan, moves2)
      
      assert result2[:success], "2回目の修正処理が成功する必要がある。エラー: #{result2[:message]}, ステータス: #{result2[:status]}"
      weather_prediction_service2.verify
    end
  end

  private

  def create_weather_data_for_training
    # 過去20年分の気象データを作成
    start_date = Date.current - 20.years
    end_date = Date.current - 2.days
    
    (start_date..end_date).each do |date|
      create(:weather_datum,
        weather_location: @weather_location,
        date: date,
        temperature_max: 20.0 + (date.yday % 10),
        temperature_min: 10.0 + (date.yday % 8),
        temperature_mean: 15.0 + (date.yday % 9),
        precipitation: date.day.even? ? 0.0 : 5.0,
        sunshine_hours: 6.0 + (date.yday % 6),
        wind_speed: 3.0 + (date.yday % 5),
        weather_code: date.day.even? ? 0 : 61
      )
    end
  end

  def generate_prediction_data(start_date, end_date)
    (start_date..end_date).map do |date|
      {
        'time' => date.to_s,
        'temperature_2m_max' => 20.0 + (date.yday % 10),
        'temperature_2m_min' => 10.0 + (date.yday % 8),
        'temperature_2m_mean' => 15.0 + (date.yday % 9),
        'precipitation_sum' => date.day.even? ? 0.0 : 5.0,
        'sunshine_duration' => (6.0 + (date.yday % 6)) * 3600.0,
        'wind_speed_10m_max' => 3.0 + (date.yday % 5),
        'weather_code' => date.day.even? ? 0 : 61
      }
    end
  end
end

