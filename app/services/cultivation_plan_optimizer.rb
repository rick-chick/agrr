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
      fields_data, crops_data = prepare_allocation_data(planning_end)
      
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
      distribute_allocation_results(allocation_result)
      
      # 最適化結果をcultivation_planに反映
      update_cultivation_plan_with_results(allocation_result)
      
      @cultivation_plan.phase_completed!
      @cultivation_plan.complete!
      Rails.logger.info "✅ CultivationPlan ##{@cultivation_plan.id} optimization completed"
      true
    rescue Agrr::BaseGateway::NoAllocationCandidatesError => e
      Rails.logger.error "❌ CultivationPlan ##{@cultivation_plan.id} optimization failed: No allocation candidates"
      Rails.logger.error "Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # ユーザーフレンドリーなエラーメッセージを作成
      user_friendly_message = <<~MSG.strip
        作付け計画の候補を生成できませんでした。以下の可能性があります：
        
        1. 計画期間内に作物が成熟しない
           → 計画期間を延長するか、より短期間で収穫できる作物を選択してください
        
        2. 圃場の面積が不足している
           → 圃場の面積を増やすか、作物の数を減らしてください
        
        3. 気象条件が適していない
           → 選択した作物が気象条件に適していない可能性があります。別の作物を試してください
        
        4. 作物の収益設定が適切でない
           → 作物の収益設定（revenue_per_area）を確認してください
        
        技術的な詳細: #{e.message}
      MSG
      
      @cultivation_plan.phase_failed!(@current_phase || 'unknown')
      @cultivation_plan.fail!(user_friendly_message)
      false
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
    
    # 過去20年分の実績データをLightGBMモデルのトレーニング用に取得
    # 長期データで季節性パターンと気候変動の傾向を学習可能
    # 気象データは通常1-2日遅れで更新されるため、2日前までのデータを使用
    training_start_date = Date.current - 20.years
    training_end_date = Date.current - 2.days
    training_data = weather_location.weather_data_for_period(training_start_date, training_end_date)
    
    if training_data.empty?
      raise WeatherDataNotFoundError,
            "No training weather data found for period #{training_start_date} to #{training_end_date}. " \
            "Please run weather data import batch first."
    end
    
    # 最低限必要なデータ量をチェック（15年分 = 約5475日、閏年3-4回分を含む）
    # LightGBMモデルは長期データで季節性パターンと気候変動の傾向を学習可能
    # 気象データは通常1-2日遅れで更新されるため、実際には20年 - 2日分を取得
    # 最低15年分あれば学習可能
    minimum_required_days = 5470  # 15年 × 365日 = 5475日（閏年や日付ズレを考慮して-5日）
    if training_data.count < minimum_required_days
      raise WeatherDataNotFoundError,
            "Insufficient training weather data: #{training_data.count} records found, but at least #{minimum_required_days} days (approximately 15 years) required. " \
            "Please run weather data import batch to fetch historical data (#{training_start_date} to #{training_end_date})."
    end
    
    Rails.logger.info "✅ [AGRR] Training data loaded from DB: #{training_data.count} records (#{training_start_date} to #{training_end_date})"
    
    # 今年1年間の実績データを取得
    # 気象データは通常1-2日遅れで更新されるため、2日前までのデータを使用
    current_year_start = Date.new(Date.current.year, 1, 1)
    current_year_end = Date.current - 2.days
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
    
    # 1年後の12月31日までの予測データ
    # ナスやキュウリなど、必要GDDが高い作物も成長完了できるように期間を延長
    next_year = Date.current.year + 1
    target_end_date = Date.new(next_year, 12, 31)
    # 両端を含む日数を計算（開始日から終了日まで）
    prediction_days = (target_end_date - Date.current).to_i + 1
    
    Rails.logger.info "🔮 [AGRR] Predicting weather until #{target_end_date} (#{prediction_days} days)"
    
    # LightGBMモデルを使用（長期予測に適している）
    # 注意: 処理に時間がかかる可能性があるが、予測日数や精度を勝手に変更してはならない
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
    
    # 気象データを保存（後で気温・GDDチャート表示時に再利用）
    # merged_dataはすでに{latitude, longitude, timezone, data: [...]}の構造を持っている
    @cultivation_plan.update!(
      predicted_weather_data: merged_data.merge(
        'generated_at' => Time.current.iso8601,
        'target_end_date' => target_end_date.to_s
      )
    )
    
    Rails.logger.info "✅ [AGRR] Weather data saved to CultivationPlan for future reuse"
    
    # 気象データと計画期間の終了日を返す
    {
      data: merged_data,
      target_end_date: target_end_date
    }
  end
  
  def format_weather_data_for_agrr(weather_location, weather_data)
    {
      'latitude' => weather_location.latitude.to_f,
      'longitude' => weather_location.longitude.to_f,
      'elevation' => (weather_location.elevation || 0.0).to_f,
      'timezone' => weather_location.timezone,
      'data' => weather_data.filter_map do |datum|
        # Skip records with missing temperature data
        next if datum.temperature_max.nil? || datum.temperature_min.nil?
        
        # Calculate mean from max/min if missing
        temp_mean = datum.temperature_mean
        if temp_mean.nil?
          temp_mean = (datum.temperature_max.to_f + datum.temperature_min.to_f) / 2.0
        else
          temp_mean = temp_mean.to_f
        end
        
        {
          'time' => datum.date.to_s,
          'temperature_2m_max' => datum.temperature_max.to_f,
          'temperature_2m_min' => datum.temperature_min.to_f,
          'temperature_2m_mean' => temp_mean,
          'precipitation_sum' => (datum.precipitation || 0.0).to_f,
          'sunshine_duration' => datum.sunshine_hours ? (datum.sunshine_hours.to_f * 3600.0) : 0.0, # 時間→秒
          'wind_speed_10m_max' => (datum.wind_speed || 0.0).to_f,
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
    # 農場の地域を取得
    farm_region = @cultivation_plan.farm.region
    
    # ユーザーがいる場合はユーザー所有のルールと参照ルールを取得
    # ユーザーがいない場合（匿名ユーザー）は参照ルールのみを取得
    # さらに、農場の地域でフィルタリング
    rules = if @cultivation_plan.user_id
      InteractionRule.where(
        "((user_id = ? AND is_reference = ?) OR is_reference = ?) AND region = ?",
        @cultivation_plan.user_id,
        false,
        true,
        farm_region
      )
    else
      InteractionRule.reference.where(region: farm_region)
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
    crops_collection = {}  # 作物の収集用（重複排除 + revenue_per_area計算用）
    
    # 第1パス: 全作物を収集
    field_cultivations.each do |fc|
      fc.start_optimizing!
      
      crop_info = fc.crop_info
      
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
      
      # 作物を収集（重複を避ける）
      crop_key = "#{crop_info[:name]}_#{crop_info[:variety]}"
      unless crops_collection[crop_key]
        crops_collection[crop_key] = crop
      end
    end
    
    # 作物数を取得
    crop_count = crops_collection.size
    
    # フィールド数を作物数と同じに設定（最低1フィールド）
    # これにより、各作物が最低1つのフィールドを使用でき、
    # 休閑期間を考慮した輪作が可能になる
    field_count = [crop_count, 1].max
    
    # 農場全体の面積を取得
    total_area = @cultivation_plan.total_area
    
    # 各フィールドの面積を計算
    area_per_field = total_area / field_count.to_f
    
    Rails.logger.info "📊 [AGRR] Total area: #{total_area}㎡, Crop count: #{crop_count}, Field count: #{field_count} (1 field per crop)"
    Rails.logger.info "📊 [AGRR] Area per field: #{area_per_field.round(2)}㎡"
    
    # フィールドデータを作成（作物数と同じ数だけ）
    field_count.times do |i|
      field_id = "field_#{i + 1}"
      fields_data << {
        'field_id' => field_id,
        'name' => "圃場#{i + 1}",
        'area' => area_per_field,
        'daily_fixed_cost' => 10.0  # デフォルト値
      }
    end
    
    # 第2パス: max_revenueを各作物ごとに計算して作物データを作成
    crops_collection.each do |crop_key, crop|
      crop_requirement = crop.to_agrr_requirement
      
      # revenue_per_areaを取得（デフォルト値: 5000.0）
      revenue_per_area = crop.revenue_per_area || 5000.0
      
      # 元のmax_revenue
      original_max_revenue = crop_requirement['crop']['max_revenue']
      
      # max_revenue = (revenue_per_area × total_area × 3) ÷ crop_count
      # 3倍にすることで、各作物が平均的に (total_area ÷ crop_count) × 3 の面積（3作分）を使用可能
      adjusted_max_revenue = (revenue_per_area * total_area * 3) / crop_count.to_f
      
      # 調整後の値を設定
      crop_requirement['crop']['max_revenue'] = adjusted_max_revenue
      
      Rails.logger.info "🔧 [AGRR] Crop '#{crop.name}' - revenue_per_area: ¥#{revenue_per_area}/㎡, " \
                        "max_revenue: ¥#{original_max_revenue.round(0)} → ¥#{adjusted_max_revenue.round(0)} " \
                        "(limited to ~#{(adjusted_max_revenue / revenue_per_area).round(1)}㎡, 3 crops)"
      
      crops_data << crop_requirement
    end
    
    [fields_data, crops_data]
  end
  
  def distribute_allocation_results(allocation_result)
    # 既存のFieldCultivationを全て削除（最適化前のデータをクリア）
    @cultivation_plan.field_cultivations.destroy_all
    Rails.logger.info "🗑️  [AGRR] Cleared existing FieldCultivations for CultivationPlan ##{@cultivation_plan.id}"
    
    # 既存のCultivationPlanFieldとCultivationPlanCropも全て削除
    # AGRR最適化結果に基づいて再作成するため
    @cultivation_plan.cultivation_plan_fields.destroy_all
    @cultivation_plan.cultivation_plan_crops.destroy_all
    Rails.logger.info "🗑️  [AGRR] Cleared existing CultivationPlanFields and CultivationPlanCrops for CultivationPlan ##{@cultivation_plan.id}"
    
    field_schedules = allocation_result[:field_schedules] || []
    
    field_schedules.each do |schedule|
      field_id = schedule['field_id']
      
      # allocationsが空の場合
      if schedule['allocations'].blank?
        Rails.logger.warn "⚠️  [AGRR] No allocations for field #{field_id}"
        next
      end
      
      allocations = schedule['allocations']
      
      # 各allocationに対して新しいFieldCultivationを作成
      allocations.each_with_index do |allocation, index|
        create_field_cultivation_from_allocation(allocation, field_id, index)
      end
      
      Rails.logger.info "✅ [AGRR] Created #{allocations.size} FieldCultivations for field #{field_id}"
    end
  end
  
  def create_field_cultivation_from_allocation(allocation, field_id, index)
    # 作物情報を作成
    crop_name = allocation['crop_name']
    crop_variety = allocation['variety']
    
    # field_idから圃場名を取得（"field_1" -> "圃場1"）
    field_number = field_id.split('_').last
    field_name = "圃場#{field_number}"
    
    # 新しいFieldCultivationを作成
    field_cultivation = @cultivation_plan.field_cultivations.create!(
      cultivation_plan_field_id: create_or_find_cultivation_plan_field(field_name, allocation['area_used']),
      cultivation_plan_crop_id: create_or_find_cultivation_plan_crop(crop_name, crop_variety),
      area: allocation['area_used'],
      start_date: Date.parse(allocation['start_date']),
      completion_date: Date.parse(allocation['completion_date']),
      cultivation_days: allocation['growth_days'],
      estimated_cost: allocation['total_cost'],
      status: :completed,
      optimization_result: {
        allocation_id: allocation['allocation_id'],
        expected_revenue: allocation['expected_revenue'],
        profit: allocation['profit'],
        raw: allocation
      }
    )
    
    Rails.logger.info "🌱 [AGRR] Created FieldCultivation ##{field_cultivation.id}: #{crop_name} (#{crop_variety}) " \
                      "#{allocation['start_date']} - #{allocation['completion_date']} " \
                      "(#{allocation['area_used']}㎡, ¥#{allocation['profit']})"
    
    field_cultivation
  end
  
  def create_or_find_cultivation_plan_field(field_name, area)
    # CultivationPlanFieldを作成または検索
    field = @cultivation_plan.cultivation_plan_fields.find_or_create_by!(
      name: field_name
    ) do |f|
      f.area = area
      f.daily_fixed_cost = 10.0  # デフォルト値
    end
    field.id
  end
  
  def create_or_find_cultivation_plan_crop(crop_name, crop_variety)
    # CultivationPlanCropを作成または検索
    crop = @cultivation_plan.cultivation_plan_crops.find_or_create_by!(
      name: crop_name,
      variety: crop_variety
    ) do |c|
      c.area_per_unit = 1.0 # デフォルト値
      c.revenue_per_area = 800.0 # デフォルト値
    end
    crop.id
  end
  
  def update_cultivation_plan_with_results(allocation_result)
    # 最適化結果のサマリーをcultivation_planに保存
    @cultivation_plan.update!(
      total_profit: allocation_result[:total_profit],
      total_revenue: allocation_result[:total_revenue], 
      total_cost: allocation_result[:total_cost],
      optimization_time: allocation_result[:optimization_time],
      algorithm_used: allocation_result[:algorithm_used],
      is_optimal: allocation_result[:is_optimal],
      optimization_summary: allocation_result[:summary].to_json
    )
    
    Rails.logger.info "📊 [AGRR] CultivationPlan ##{@cultivation_plan.id} updated with optimization results: " \
                      "profit=¥#{allocation_result[:total_profit]}, revenue=¥#{allocation_result[:total_revenue]}, " \
                      "cost=¥#{allocation_result[:total_cost]}"
  end
end

