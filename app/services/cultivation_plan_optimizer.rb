# frozen_string_literal: true

class CultivationPlanOptimizer
  class WeatherDataNotFoundError < StandardError; end
  
  def initialize(cultivation_plan, channel_class)
    @cultivation_plan = cultivation_plan
    @channel_class = channel_class
    @allocation_gateway = Agrr::AllocationGateway.new
  end
  
  def call
    @cultivation_plan.start_optimizing!
    @current_phase = nil
    
    begin
      # 天気予測データを取得
      weather_location = @cultivation_plan.farm&.weather_location
      unless weather_location
        error_message = "農場にWeatherLocationが設定されていません。気象データを取得してください。"
        Rails.logger.error "❌ [Optimizer] #{error_message}"
        raise WeatherDataNotFoundError, error_message
      end

      # 計画の終了日をtarget_end_dateとして使用
      _, planning_end_date = calculate_planning_period
      weather_prediction_service = WeatherPredictionService.new(
        weather_location: weather_location,
        farm: @cultivation_plan.farm
      )
      existing_prediction = weather_prediction_service.get_existing_prediction(
        target_end_date: planning_end_date,
        cultivation_plan: @cultivation_plan
      )
      
      unless existing_prediction
        error_message = "天気予測データが存在しません。計画作成時に天気予測が実行されていません。"
        Rails.logger.error "❌ [Optimizer] #{error_message}"
        raise WeatherDataNotFoundError, error_message
      end
      
      Rails.logger.info "♻️ [Optimizer] Using existing prediction data"
      weather_info = existing_prediction
      
      # 最適化フェーズ
      @current_phase = 'optimizing'
      @cultivation_plan.phase_optimizing!(@channel_class)
      
      # 全フィールドと作物情報を収集
      fields_data, crops_data = prepare_allocation_data(weather_info[:target_end_date])
      
      # interaction_rulesを取得
      interaction_rules = prepare_interaction_rules
      
      # 1回のallocate呼び出しで全フィールドを最適化
      Rails.logger.info "🚀 [AGRR] Starting single allocation for #{fields_data.count} fields and #{crops_data.count} crops"
      if interaction_rules&.any?
        Rails.logger.info "📋 [AGRR] Using #{interaction_rules.count} interaction rules"
      end
      
      # 計画期間の計算（作付計画がある場合は作付計画の期間から計算、ない場合はデフォルト期間を使用）
      planning_start, planning_end = calculate_planning_period
      
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
      
      # 最適化完了通知（OptimizationJobで重複して呼ばれるため、ここでは呼ばない）
      # @cultivation_plan.phase_completed!(@channel_class)
      # @cultivation_plan.complete!
      Rails.logger.info "✅ CultivationPlan ##{@cultivation_plan.id} optimization completed"
      true
    rescue Agrr::BaseGatewayV2::NoAllocationCandidatesError => e
      Rails.logger.error "❌ [Optimizer] AGRR allocation failed: #{e.message}"
      Rails.logger.info "🔄 [Optimizer] Re-raising error to job level"
      raise e
    rescue Agrr::BaseGatewayV2::ExecutionError => e
      Rails.logger.error "❌ [Optimizer] AGRR execution failed: #{e.message}"
      Rails.logger.info "🔄 [Optimizer] Re-raising error to job level"
      raise e
    rescue StandardError => e
      Rails.logger.error "❌ [Optimizer] Unexpected error at phase: #{@current_phase || 'unknown'}: #{e.message}"
      Rails.logger.info "🔄 [Optimizer] Re-raising error to job level"
      raise e
    end
  end
  
  private
  
  def calculate_planning_period
    # 作付計画がある場合は作付計画の期間から計算
    if @cultivation_plan.field_cultivations.any?
      start_date = @cultivation_plan.calculated_planning_start_date
      end_date = @cultivation_plan.calculated_planning_end_date
      [start_date, end_date]
    else
      # 作付計画がない場合はデフォルト期間を使用
      # プライベート計画と公開計画で異なるデフォルト値
      if @cultivation_plan.plan_type_private?
        [
          Date.current.beginning_of_year,
          Date.new(Date.current.year + 1, 12, 31)
        ]
      else
        # 公開計画では、予測ホライズンと整合するように翌年末までを最適化対象期間とする
        end_date = if @cultivation_plan.respond_to?(:prediction_target_end_date)
          @cultivation_plan.prediction_target_end_date
        else
          Date.new(Date.current.year + 1, 12, 31)
        end

        [
          Date.current,
          end_date
        ]
      end
    end
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
    
    cultivation_plan_crops = @cultivation_plan.cultivation_plan_crops.to_a
    Rails.logger.debug "🔍 [CultivationPlanOptimizer] cultivation_plan_crops count: #{cultivation_plan_crops.count}"
    cultivation_plan_crops.each { |cpc| Rails.logger.debug "  - CultivationPlanCrop: #{cpc.name} (Crop ID: #{cpc.crop_id})" }
    
    fields_data = []
    crops_data = []
    crops_collection = {}  # 作物の収集用（重複排除 + revenue_per_area計算用）
    
    # 第1パス: 全作物を収集
    cultivation_plan_crops.each do |cpc|
      crop = cpc.crop
      
      Rails.logger.debug "🌾 [AGRR] Processing crop: #{crop.name} (ID: #{crop.id})"
      
      # 作物を収集（重複を避ける）
      crop_key = crop.id.to_s
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
      field_id = i + 1
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
    
    # 既存のCultivationPlanFieldとCultivationPlanCropは保持
    # AGRR最適化結果に基づいてFieldCultivationのみ再作成する
    Rails.logger.info "🔄 [AGRR] Keeping existing CultivationPlanFields and CultivationPlanCrops for CultivationPlan ##{@cultivation_plan.id}"
    
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
    crop_id = allocation['crop_id']
    crop_name = allocation['crop_name']
    crop_variety = allocation['variety']
    
    # field_idから圃場名を取得（"field_1" -> "1"）
    field_number = field_id.split('_').last
    field_name = field_number
    
    # 新しいFieldCultivationを作成
    field_cultivation = @cultivation_plan.field_cultivations.create!(
      cultivation_plan_field_id: create_or_find_cultivation_plan_field(field_name, allocation['area_used']),
      cultivation_plan_crop_id: find_cultivation_plan_crop_by_crop_id(crop_id, crop_name),
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
  
  def find_cultivation_plan_crop_by_crop_id(crop_id, crop_name)
    # AGRR最適化は入力された作物のみを使用するため、既存のCultivationPlanCropが必ず存在する
    existing_cpc = @cultivation_plan.cultivation_plan_crops.find_by(crop_id: crop_id)
    
    if existing_cpc
      Rails.logger.debug "♻️ [AGRR] Found existing CultivationPlanCrop: #{crop_name} (ID: #{existing_cpc.id}, Crop ID: #{existing_cpc.crop_id})"
      existing_cpc.id
    else
      # このケースは実際には発生しない（AGRRは入力された作物のみを返すため）
      # もし発生した場合は、データ整合性の問題
      Rails.logger.error "❌ [AGRR] CultivationPlanCrop not found for crop_id: #{crop_id} (#{crop_name})"
      Rails.logger.error "❌ [AGRR] Available CultivationPlanCrops: #{@cultivation_plan.cultivation_plan_crops.pluck(:crop_id, :name)}"
      raise "CultivationPlanCrop not found for crop_id: #{crop_id}. This indicates a data integrity issue."
    end
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

