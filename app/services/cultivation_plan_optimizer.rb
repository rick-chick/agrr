# frozen_string_literal: true

class CultivationPlanOptimizer
  class WeatherDataNotFoundError < StandardError; end
  
  def initialize(cultivation_plan)
    @cultivation_plan = cultivation_plan
    @prediction_gateway = Agrr::PredictionGateway.new
    @allocation_gateway = Agrr::AllocationGateway.new
  end
  
  def call
    @cultivation_plan.start_optimizing!
    @current_phase = nil
    
    begin
      weather_info = prepare_weather_data
      
      # 最適化フェーズ
      @current_phase = 'optimizing'
      @cultivation_plan.phase_optimizing!
      
      # 計画期間を設定
      planning_start = Date.current
      planning_end = weather_info[:target_end_date]
      
      # cultivation_planに計画期間を保存
      @cultivation_plan.update!(
        planning_start_date: planning_start,
        planning_end_date: planning_end
      )
      
      # 全フィールドと作物情報を収集
      fields_data, crops_data, field_cultivation_map = prepare_allocation_data(planning_end)
      
      # interaction_rulesを取得
      interaction_rules = prepare_interaction_rules
      
      # 1回のallocate呼び出しで全フィールドを最適化
      Rails.logger.info "🚀 [AGRR] Starting single allocation for #{fields_data.count} fields and #{crops_data.count} crops"
      if interaction_rules&.any?
        Rails.logger.info "📋 [AGRR] Using #{interaction_rules.count} interaction rules"
      end
      
      allocation_result = @allocation_gateway.allocate(
        fields: fields_data,
        crops: crops_data,
        weather_data: weather_info[:data],
        planning_start: planning_start,
        planning_end: planning_end,
        interaction_rules: interaction_rules
      )
      
      # 結果を各field_cultivationに分配
      distribute_allocation_results(allocation_result, field_cultivation_map)
      
      @cultivation_plan.phase_completed!
      @cultivation_plan.complete!
      Rails.logger.info "✅ CultivationPlan ##{@cultivation_plan.id} optimization completed"
      true
    rescue StandardError => e
      Rails.logger.error "❌ CultivationPlan ##{@cultivation_plan.id} optimization failed at phase: #{@current_phase || 'unknown'}"
      Rails.logger.error "Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # フェーズに応じたエラーメッセージを設定
      @cultivation_plan.phase_failed!(@current_phase || 'unknown')
      @cultivation_plan.fail!(e.message)
      false
    end
  end
  
  private
  
  def prepare_weather_data
    # フェーズ: 気象データ取得
    @current_phase = 'fetching_weather'
    @cultivation_plan.phase_fetching_weather!
    
    farm = @cultivation_plan.farm
    
    # DBから天気データを取得
    weather_location = WeatherLocation.find_by(
      latitude: farm.latitude,
      longitude: farm.longitude
    )
    
    unless weather_location
      raise WeatherDataNotFoundError, 
            "Weather location not found for coordinates: #{farm.latitude}, #{farm.longitude}. " \
            "Please run weather data import batch first."
    end
    
    # 過去1年分の実績データをLightGBMモデルのトレーニング用に取得
    # LightGBMは1年分のデータで季節性パターンを学習可能
    training_start_date = Date.current - 1.year
    training_end_date = Date.current - 1.day
    training_data = weather_location.weather_data_for_period(training_start_date, training_end_date)
    
    if training_data.empty?
      raise WeatherDataNotFoundError,
            "No training weather data found for period #{training_start_date} to #{training_end_date}. " \
            "Please run weather data import batch first."
    end
    
    # 最低限必要なデータ量をチェック（1年分 = 365日）
    # LightGBMモデルは1年分のデータで季節性パターンを学習可能
    minimum_required_days = 365
    if training_data.count < minimum_required_days
      raise WeatherDataNotFoundError,
            "Insufficient training weather data: #{training_data.count} records found, but at least #{minimum_required_days} days required. " \
            "Please run weather data import batch to fetch historical data (#{training_start_date} to #{training_end_date})."
    end
    
    Rails.logger.info "✅ [AGRR] Training data loaded from DB: #{training_data.count} records (#{training_start_date} to #{training_end_date})"
    
    # 今年1年間の実績データを取得
    current_year_start = Date.new(Date.current.year, 1, 1)
    current_year_end = Date.current - 1.day
    current_year_data = weather_location.weather_data_for_period(current_year_start, current_year_end)
    
    if current_year_data.empty?
      raise WeatherDataNotFoundError,
            "No current year weather data found for period #{current_year_start} to #{current_year_end}. " \
            "Please run weather data import batch first."
    end
    
    Rails.logger.info "✅ [AGRR] Current year data loaded from DB: #{current_year_data.count} records (#{current_year_start} to #{current_year_end})"
    
    # トレーニングデータをAGRR形式に変換
    training_formatted = format_weather_data_for_agrr(weather_location, training_data)
    
    # フェーズ: 気象データ予測
    @current_phase = 'predicting_weather'
    @cultivation_plan.phase_predicting_weather!
    
    # 次の年の12月31日までの予測データ
    next_year = Date.current.year + 1
    target_end_date = Date.new(next_year, 12, 31)
    prediction_days = (target_end_date - Date.current).to_i
    
    Rails.logger.info "🔮 [AGRR] Predicting weather until #{target_end_date} (#{prediction_days} days)"
    
    future = @prediction_gateway.predict(
      historical_data: training_formatted,
      days: prediction_days,
      model: 'lightgbm'
    )
    
    Rails.logger.info "✅ [AGRR] Prediction completed for next #{prediction_days} days (until #{target_end_date})"
    
    # 今年の実データをAGRR形式に変換
    current_year_formatted = format_weather_data_for_agrr(weather_location, current_year_data)
    
    # 今年の実データ + 来年の予測データをマージ
    merged_data = merge_weather_data(current_year_formatted, future)
    
    # 気象データの実際の範囲を計算
    # 今年の実データ + 次の年の12月31日までの予測データ
    total_weather_days = current_year_data.count + prediction_days
    
    Rails.logger.info "✅ [AGRR] Total weather data available: #{total_weather_days} days (current year: #{current_year_data.count} + prediction until #{target_end_date}: #{prediction_days})"
    
    # 気象データと計画期間の終了日を返す
    {
      data: merged_data,
      target_end_date: target_end_date
    }
  end
  
  def format_weather_data_for_agrr(weather_location, weather_data)
    {
      'latitude' => weather_location.latitude,
      'longitude' => weather_location.longitude,
      'elevation' => weather_location.elevation || 0.0,
      'timezone' => weather_location.timezone,
      'data' => weather_data.filter_map do |datum|
        # Skip records with missing temperature data
        next if datum.temperature_max.nil? || datum.temperature_min.nil?
        
        # Calculate mean from max/min if missing
        temp_mean = datum.temperature_mean
        if temp_mean.nil?
          temp_mean = (datum.temperature_max + datum.temperature_min) / 2.0
        end
        
        {
          'time' => datum.date.to_s,
          'temperature_2m_max' => datum.temperature_max,
          'temperature_2m_min' => datum.temperature_min,
          'temperature_2m_mean' => temp_mean,
          'precipitation_sum' => datum.precipitation || 0.0,
          'sunshine_duration' => datum.sunshine_hours ? datum.sunshine_hours * 3600 : 0.0, # 時間→秒
          'wind_speed_10m_max' => datum.wind_speed || 0.0,
          'weather_code' => datum.weather_code || 0
        }
      end
    }
  end
  
  def merge_weather_data(historical, future)
    {
      latitude: historical['latitude'],
      longitude: historical['longitude'],
      data: (historical['data'] || []) + (future['data'] || [])
    }
  end
  
  def prepare_interaction_rules
    # ユーザーがいる場合はユーザー所有のルールと参照ルールを取得
    # ユーザーがいない場合（匿名ユーザー）は参照ルールのみを取得
    rules = if @cultivation_plan.user_id
      InteractionRule.where(
        "(user_id = ? AND is_reference = ?) OR is_reference = ?",
        @cultivation_plan.user_id,
        false,
        true
      )
    else
      InteractionRule.reference
    end
    
    # AGRR形式の配列に変換
    rules_array = InteractionRule.to_agrr_format_array(rules)
    
    return nil if rules_array.empty?
    
    # AGRR CLIは配列を期待しているので、そのまま返す
    rules_array
  end
  
  def prepare_allocation_data(evaluation_end)
    Rails.logger.info "🗓️  [AGRR] Evaluation period: #{Date.current} to #{evaluation_end}"
    
    field_cultivations = @cultivation_plan.field_cultivations.to_a
    fields_data = []
    crops_data = []
    field_cultivation_map = {}
    crop_id_map = {}
    crops_collection = {}  # 作物の収集用（重複排除 + revenue_per_area計算用）
    
    # 第1パス: 全作物を収集し、revenue_per_areaを集計
    field_cultivations.each do |fc|
      fc.start_optimizing!
      
      crop_info = fc.crop_info
      field_info = fc.field_info
      
      # Cropモデルを検索（関連データをeager load）
      crop = Crop.includes(crop_stages: [:temperature_requirement, :thermal_requirement, :sunshine_requirement])
                 .find_by(
                   name: crop_info[:name],
                   variety: crop_info[:variety],
                   is_reference: true
                 )
      
      crop ||= Crop.includes(crop_stages: [:temperature_requirement, :thermal_requirement, :sunshine_requirement])
                   .find_by(
                     name: crop_info[:name],
                     variety: crop_info[:variety],
                     user_id: @cultivation_plan.user_id
                   )
      
      unless crop
        error_message = "Crop not found: name='#{crop_info[:name]}', variety='#{crop_info[:variety]}'. " \
                        "Please register the crop with detailed growth stages in the Crop management page before optimization."
        Rails.logger.error "❌ [AGRR] #{error_message}"
        raise StandardError, error_message
      end
      
      Rails.logger.info "📚 [AGRR] Using Crop model (id: #{crop.id}, reference: #{crop.is_reference})"
      
      # フィールドデータを作成
      field_id = "field_#{fc.id}"
      fields_data << {
        'field_id' => field_id,
        'name' => field_info[:name],
        'area' => fc.area,
        'daily_fixed_cost' => field_info[:daily_fixed_cost]
      }
      
      # 作物を収集（重複を避ける）
      crop_key = "#{crop_info[:name]}_#{crop_info[:variety]}"
      unless crops_collection[crop_key]
        crops_collection[crop_key] = crop
      end
      
      # マッピング情報を保存（crop_idは後で設定）
      field_cultivation_map[field_id] = {
        field_cultivation: fc,
        crop_key: crop_key
      }
    end
    
    # revenue_per_areaの平均を計算（均等配分の基準値）
    revenue_values = crops_collection.values.map { |crop| crop.revenue_per_area || 5000.0 }
    average_revenue_per_area = revenue_values.sum / revenue_values.size.to_f
    
    Rails.logger.info "📊 [AGRR] Revenue per area - Average: ¥#{average_revenue_per_area.round(2)}/㎡"
    
    # 第2パス: max_revenueを調整して作物データを作成
    crops_collection.each do |crop_key, crop|
      crop_requirement = crop.to_agrr_requirement
      
      # revenue_per_areaを取得（デフォルト値: 5000.0）
      revenue_per_area = crop.revenue_per_area || 5000.0
      
      # 調整係数を計算: 平均値 / 当該作物の値
      # 高収益作物は係数が小さく（max_revenueが抑えられる）
      # 低収益作物は係数が大きく（max_revenueが高くなる）
      adjustment_factor = average_revenue_per_area / revenue_per_area
      
      # 元のmax_revenueに調整係数を適用
      original_max_revenue = crop_requirement['crop']['max_revenue']
      adjusted_max_revenue = original_max_revenue * adjustment_factor
      
      # 調整後の値を設定
      crop_requirement['crop']['max_revenue'] = adjusted_max_revenue
      
      Rails.logger.info "🔧 [AGRR] Crop '#{crop.name}' - revenue_per_area: ¥#{revenue_per_area}/㎡, " \
                        "adjustment_factor: #{adjustment_factor.round(3)}, " \
                        "max_revenue: ¥#{original_max_revenue.round(0)} → ¥#{adjusted_max_revenue.round(0)}"
      
      crops_data << crop_requirement
      crop_id_map[crop_key] = crop_requirement['crop']['crop_id']
    end
    
    # field_cultivation_mapにcrop_idを設定
    field_cultivation_map.each do |field_id, map_entry|
      map_entry[:crop_id] = crop_id_map[map_entry[:crop_key]]
      map_entry.delete(:crop_key)
    end
    
    [fields_data, crops_data, field_cultivation_map]
  end
  
  def distribute_allocation_results(allocation_result, field_cultivation_map)
    field_schedules = allocation_result[:field_schedules] || []
    
    field_schedules.each do |schedule|
      field_id = schedule['field_id']
      map_entry = field_cultivation_map[field_id]
      next unless map_entry
      
      fc = map_entry[:field_cultivation]
      
      # スケジュールが空の場合
      if schedule['schedules'].blank?
        fc.fail_with_error!('No optimal schedule found')
        next
      end
      
      # 最初のスケジュールを使用（複数ある場合は最適なもの）
      best_schedule = schedule['schedules'].first
      
      result = {
        start_date: Date.parse(best_schedule['start_date']),
        completion_date: Date.parse(best_schedule['completion_date']),
        days: best_schedule['growth_days'],
        cost: best_schedule['total_cost'],
        gdd: best_schedule['gdd'],
        raw: best_schedule
      }
      
      fc.complete_with_result!(result)
      Rails.logger.info "✅ [AGRR] FieldCultivation ##{fc.id} completed: #{result[:start_date]} - #{result[:completion_date]}"
    end
  end
end

