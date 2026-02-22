# frozen_string_literal: true

# 栽培計画APIの共通機能を提供するConcern
#
# このConcernは以下の機能を提供します:
# - 作物の追加（add_crop）
# - 圃場の追加（add_field）
# - 圃場の削除（remove_field）
# - 計画データの取得（data）
# - 調整（adjust）
#
# 使い方:
# - find_api_cultivation_planメソッドを実装: 計画を検索する
# - get_crop_for_add_cropメソッドを実装: add_cropで使用する作物を取得する
module CultivationPlanApi
  extend ActiveSupport::Concern
  include AgrrOptimization
  
  
  # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/add_crop
  # 作物追加: candidatesで最適日付を自動決定し、adjustで追加する
  def add_crop
    Rails.logger.info "🌱 [Add Crop] ========== START =========="
    Rails.logger.info "🌱 [Add Crop] cultivation_plan_id: #{params[:id]}, crop_id: #{params[:crop_id]}, field_id: #{params[:field_id]}"
    
    @cultivation_plan = find_api_cultivation_plan
    
    # サブクラスで実装された作物取得メソッドを呼び出す
    crop = get_crop_for_add_crop(params[:crop_id])
    unless crop
      return render json: {
        success: false,
        message: i18n_t('errors.crop_not_found')
      }, status: :not_found
    end
    
    # cultivation_plan_crops に追加（スナップショット）
    plan_crop = @cultivation_plan.cultivation_plan_crops.create!(
      crop: crop,
      name: crop.name,
      variety: crop.variety,
      area_per_unit: crop.area_per_unit,
      revenue_per_area: crop.revenue_per_area
    )
    
    # candidatesで最適な開始日を取得
    display_range = display_range_from_params
    display_start_date = display_range[:start_date]
    display_end_date = display_range[:end_date]
    if display_start_date || display_end_date
      Rails.logger.info "📅 [Add Crop] Display range from UI: start=#{display_start_date} end=#{display_end_date}"
    else
      Rails.logger.info "📅 [Add Crop] Display range from UI: not provided"
    end

    begin
      best_candidate = find_best_candidate_for_crop(crop, params[:field_id], display_range: display_range)
    rescue WeatherPredictionService::WeatherDataNotFoundError, WeatherPredictionService::InsufficientPredictionDataError => e
      plan_crop.destroy! if plan_crop.persisted?
      Rails.logger.warn "⚠️ [Add Crop] Prediction data incomplete: #{e.message}"
      return render json: {
        success: false,
        message: i18n_t('errors.prediction_data_incomplete'),
        technical_details: e.message
      }, status: :service_unavailable
    end
    
    unless best_candidate
      plan_crop.destroy!
      return render json: {
        success: false,
        message: i18n_t('errors.no_candidates_found')
      }, status: :unprocessable_entity
    end
    
    Rails.logger.info "🌱 [Add Crop] Best candidate: field=#{best_candidate[:field_id]}, start=#{best_candidate[:start_date]}"
    
    # candidatesの結果を使って調整を実行
    moves = [
      {
        allocation_id: nil,
        action: 'add',
        crop_id: crop.id.to_s,
        to_field_id: best_candidate[:field_id] || params[:field_id],
        to_start_date: best_candidate[:start_date],
        to_area: crop.area_per_unit,
        variety: crop.variety
      }
    ]
    
    result = adjust_with_db_weather(@cultivation_plan, moves)
    
    if result[:success]
      render json: {
        success: true,
        message: i18n_t('messages.crop_added'),
        crop: {
          id: plan_crop.id,
          name: plan_crop.display_name
        }
      }
    else
      render json: result, status: result[:status] || :internal_server_error
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "❌ [Add Crop] Not found: #{e.message}"
    render json: { success: false, message: i18n_t('errors.not_found') }, status: :not_found
  rescue => e
    Rails.logger.error "❌ [Add Crop] Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { success: false, message: e.message }, status: :internal_server_error
  end
  
  # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/add_field
  # 新しい圃場を追加
  def add_field
    @cultivation_plan = find_api_cultivation_plan
    
    # パラメータ取得
    field_name = params[:field_name]
    field_area = params[:field_area]&.to_f
    daily_fixed_cost = params[:daily_fixed_cost]&.to_f
    
    # バリデーション
    if field_area <= 0
      return render json: {
        success: false,
        message: i18n_t('errors.invalid_field_params')
      }, status: :unprocessable_entity
    end
    
    # 圃場数の制限（最大5個まで）
    if @cultivation_plan.cultivation_plan_fields.count >= 5
      return render json: {
        success: false,
        message: i18n_t('errors.max_fields_limit')
      }, status: :bad_request
    end
    
    # cultivation_plan_fields に追加
    plan_field = @cultivation_plan.cultivation_plan_fields.create!(
      name: field_name,
      area: field_area,
      daily_fixed_cost: daily_fixed_cost
    )
    
    # total_areaを更新
    @cultivation_plan.update!(total_area: @cultivation_plan.cultivation_plan_fields.sum(:area))
    
    # ActionCable経由で圃場追加を通知
    channel_class = @cultivation_plan.plan_type == 'private' ? PlansOptimizationChannel : OptimizationChannel
    channel_class.broadcast_to(
      @cultivation_plan,
      {
        type: 'field_added',
        field: {
          id: plan_field.id,
          field_id: plan_field.id,
          name: plan_field.name,
          area: plan_field.area
        },
        total_area: @cultivation_plan.total_area
      }
    )
    
    render json: {
      success: true,
      message: i18n_t('messages.field_added'),
      field: {
        id: plan_field.id,
        field_id: plan_field.id,
        name: plan_field.name,
        area: plan_field.area
      },
      total_area: @cultivation_plan.total_area
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      success: false,
      message: i18n_t('errors.field_add_failed', message: e.message)
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "❌ [Add Field] Error: #{e.message}"
    render json: { success: false, message: e.message }, status: :internal_server_error
  end
  
  # DELETE /api/v1/{plans|public_plans}/cultivation_plans/:id/remove_field/:field_id
  # 圃場を削除
  def remove_field
    @cultivation_plan = find_api_cultivation_plan
    
    # field_idを整数に変換
    field_id = params[:field_id].to_i
    
    plan_field = @cultivation_plan.cultivation_plan_fields.find_by(id: field_id)
    
    unless plan_field
      return render json: {
        success: false,
        message: i18n_t('errors.field_not_found')
      }, status: :not_found
    end
    
    # 圃場に栽培がある場合は削除できない
    if plan_field.field_cultivations.any?
      return render json: {
        success: false,
        message: i18n_t('errors.cannot_remove_field_with_cultivations')
      }, status: :unprocessable_entity
    end
    
    # 最後の圃場は削除できない
    if @cultivation_plan.cultivation_plan_fields.count <= 1
      return render json: {
        success: false,
        message: i18n_t('errors.cannot_remove_last_field')
      }, status: :unprocessable_entity
    end
    
    # 圃場を削除
    plan_field.destroy!
    
    # total_areaを更新
    @cultivation_plan.update!(total_area: @cultivation_plan.cultivation_plan_fields.sum(:area))
    
    # ActionCable経由で圃場削除を通知
    channel_class = @cultivation_plan.plan_type == 'private' ? PlansOptimizationChannel : OptimizationChannel
    channel_class.broadcast_to(
      @cultivation_plan,
      {
        type: 'field_removed',
        field_id: field_id,
        total_area: @cultivation_plan.total_area
      }
    )
    
    render json: {
      success: true,
      message: i18n_t('messages.field_removed'),
      field_id: field_id,
      total_area: @cultivation_plan.total_area
    }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: i18n_t('errors.field_not_found') }, status: :not_found
  rescue => e
    Rails.logger.error "❌ [Remove Field] Error: #{e.message}"
    render json: { success: false, message: e.message }, status: :internal_server_error
  end
  
  # GET /api/v1/{plans|public_plans}/cultivation_plans/:id/data
  # 栽培計画データを取得
  def data
    @cultivation_plan = find_api_cultivation_plan
    
    # 計画データを構築
    # 計画データを構築
    fields_data = @cultivation_plan.cultivation_plan_fields.map do |field|
      {
        id: field.id,
        field_id: field.id,
        name: field.display_name,
        area: field.area,
        daily_fixed_cost: field.daily_fixed_cost
      }
    end

    crops_data = @cultivation_plan.cultivation_plan_crops.map do |crop|
      {
        id: crop.id,
        name: crop.display_name,
        area_per_unit: crop.area_per_unit,
        revenue_per_area: crop.revenue_per_area
      }
    end

    available_crops_data = get_available_crops.map do |crop|
      {
        id: crop.id,
        name: crop.name,
        variety: crop.variety,
        area_per_unit: crop.area_per_unit
      }
    end

    cultivations_data = @cultivation_plan.field_cultivations.map do |fc|
      {
        id: fc.id,
        field_id: fc.cultivation_plan_field_id,
        field_name: fc.field_display_name,
        crop_id: fc.cultivation_plan_crop_id,
        crop_name: fc.crop_display_name,
        area: fc.area,
        start_date: fc.start_date,
        completion_date: fc.completion_date,
        cultivation_days: fc.cultivation_days,
        estimated_cost: fc.estimated_cost,
        revenue: fc.optimization_result&.dig('revenue') || 0.0,
        profit: fc.optimization_result&.dig('profit') || 0.0,
        status: fc.status
      }
    end

    render json: {
      success: true,
      data: {
        id: @cultivation_plan.id,
        plan_year: @cultivation_plan.plan_year,
        plan_name: @cultivation_plan.plan_name,
        plan_type: @cultivation_plan.plan_type,
        status: @cultivation_plan.status,
        total_area: @cultivation_plan.total_area,
        planning_start_date: @cultivation_plan.calculated_planning_start_date,
        planning_end_date: @cultivation_plan.prediction_target_end_date,
        fields: fields_data,
        crops: crops_data,
        available_crops: available_crops_data,
        cultivations: cultivations_data
      },
      total_profit: @cultivation_plan.total_profit,
      total_revenue: @cultivation_plan.total_revenue,
      total_cost: @cultivation_plan.total_cost
    }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: i18n_t('errors.not_found') }, status: :not_found
  rescue => e
    Rails.logger.error "❌ [Data] Error: #{e.message}"
    render json: { success: false, message: e.message }, status: :internal_server_error
  end
  
  # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/adjust
  # 手修正後の再最適化
  # 
  # このメソッドはDBに保存された天気データを再利用し、
  # 不要な天気予測を実行しないことで高速化されています
  def adjust
    @cultivation_plan = find_api_cultivation_plan

    # 作物に成長段階があるかを事前チェック
    return unless validate_crops_have_growth_stages(@cultivation_plan)

    # 移動指示を受け取る
    moves_raw = params[:moves] || []
    
    Rails.logger.info "📥 [Adjust] Received moves: #{moves_raw.inspect}"
    Rails.logger.info "📥 [Adjust] Moves class: #{moves_raw.class}"
    
    # movesを適切な形式に変換
    moves = if moves_raw.is_a?(Array)
      moves_raw.map do |move|
        case move
        when ActionController::Parameters
          # permit!を使って全てのパラメータを許可してからハッシュに変換
          move.permit!.to_h.symbolize_keys
        when Hash
          move.symbolize_keys
        when String
          # JSONパース試行
          begin
            JSON.parse(move).symbolize_keys
          rescue JSON::ParserError
            Rails.logger.error "❌ [Adjust] Failed to parse move: #{move}"
            nil
          end
        else
          nil
        end
      end.compact
    else
      []
    end
    
    # 型変換を追加（AGRRとの互換性のため）
    moves = moves.map do |move|
      # allocation_idを数値に変換
      if move[:allocation_id].present?
        move[:allocation_id] = move[:allocation_id].to_i
      end
      
      # to_field_idを文字列に変換（Python optimizer expects strings）
      if move[:to_field_id].present?
        move[:to_field_id] = move[:to_field_id].to_s
      end
      
      move
    end
    
    Rails.logger.info "🔧 [Adjust] Processed moves with type conversion: #{moves.inspect}"
    
    # DBに保存された天気データを使って調整を実行
    result = adjust_with_db_weather(@cultivation_plan, moves)
    
    render json: result, status: result[:status] || :ok
  rescue => e
    Rails.logger.error "❌ [Adjust] Error: #{e.message}"
    render json: { success: false, message: e.message }, status: :internal_server_error
  end
  
  private

  # 栽培計画の作物に成長段階があるかをバリデーション
  def validate_crops_have_growth_stages(cultivation_plan)
    cultivation_plan.cultivation_plan_crops.each do |plan_crop|
      crop = plan_crop.crop
      # ログを追加してテスト時に crop の状態を可視化する
      Rails.logger.info "🔍 [Validate Growth Stages] plan_crop_id=#{plan_crop.id} crop_id=#{crop&.id} crop_stages_loaded=#{crop&.association(:crop_stages)&.loaded? rescue 'n/a'}"
      Rails.logger.info "🔍 [Validate Growth Stages] crop_stages_count=#{crop&.crop_stages&.size rescue 'n/a'}"
      if crop.crop_stages.empty?
        render json: {
          success: false,
          message: I18n.t('api.errors.cultivation_plan.crop_missing_growth_stages', crop_name: crop.name)
        }, status: :bad_request
        return false
      end
    end
    true
  end

  # I18n翻訳のヘルパーメソッド
  def i18n_t(key)
    scope = @cultivation_plan&.plan_type == 'private' ? 'plans' : 'public_plans'
    I18n.t("#{scope}.#{key}")
  end
  
  # candidatesを使って最適な作付候補を取得する
  # 候補が見つからない場合は天気予測を12ヶ月延長してリトライする
  # @param crop [Crop] 追加する作物
  # @param field_id [String, Integer] 指定されたほ場ID
  # @return [Hash, nil] 最適な候補（field_id, start_date 等）、見つからない場合はnil
  def find_best_candidate_for_crop(crop, field_id, display_range: {})
    # preloaded planを取得
    cultivation_plan = CultivationPlan.includes(
      :cultivation_plan_fields,
      { cultivation_plan_crops: :crop },
      { field_cultivations: [:cultivation_plan_field, { cultivation_plan_crop: :crop }] }
    ).find(@cultivation_plan.id)

    # 現在の割り当てを構築
    current_allocation = build_current_allocation(cultivation_plan)
    fields = build_fields_config(cultivation_plan)
    crops = build_crops_config(cultivation_plan)
    interaction_rules = build_interaction_rules(cultivation_plan)

    display_start_date = display_range[:start_date]
    display_end_date = display_range[:end_date]
    fallback_candidates_start = cultivation_plan.calculated_planning_start_date || Date.current
    candidates_start = display_start_date || fallback_candidates_start
    base_candidates_end = cultivation_plan.calculated_planning_end_date || (candidates_start + 2.years).end_of_year
    candidates_end = [base_candidates_end, display_end_date].compact.max
    target_end_date = display_end_date || candidates_end

    ui_filters = ui_filter_context
    if display_start_date || display_end_date
      Rails.logger.info "📅 [Candidates] UI表示範囲: start=#{display_start_date || 'N/A'} end=#{display_end_date || 'N/A'}"
    else
      Rails.logger.info "📅 [Candidates] UI表示範囲: not provided"
    end
    Rails.logger.info "📋 [Candidates] UI filters: #{ui_filters.present? ? ui_filters : 'none'}"
    Rails.logger.info "📅 [Candidates] Candidate window: start=#{candidates_start} (UI start=#{display_start_date || 'N/A'}) end=#{candidates_end} target_end_date=#{target_end_date}"

    # 天気データを取得
    farm = cultivation_plan.farm
    weather_location = farm&.weather_location
    unless weather_location
      Rails.logger.error "❌ [Candidates] No weather location found"
      return nil
    end

    weather_prediction_service = WeatherPredictionService.new(
      weather_location: weather_location,
      farm: farm
    )

    weather_data = get_or_predict_weather(weather_prediction_service, cultivation_plan, target_end_date)
    return nil unless weather_data

    Rails.logger.info "📅 [Candidates] Planning period: #{candidates_start} ~ #{candidates_end} (weather_target_end=#{target_end_date})"

    # 1回目: candidatesを実行
    candidates = run_candidates(
      current_allocation, fields, crops, crop, weather_data,
      candidates_start, candidates_end, interaction_rules, field_id
    )

    if candidates.present?
      return select_best_candidate(candidates, field_id)
    end

    Rails.logger.warn "⚠️ [Candidates] No candidates found for target_end_date=#{target_end_date}"
    nil
  end

  # 天気データを取得（既存予測 or 新規予測）
  def get_or_predict_weather(weather_prediction_service, cultivation_plan, target_end_date)
    Rails.logger.info "🔍 [Candidates] Weather target end date: #{target_end_date || 'N/A'}"
    existing = weather_prediction_service.get_existing_prediction(
      target_end_date: target_end_date,
      cultivation_plan: cultivation_plan
    )

    weather_prediction_status = nil
    weather_data = nil

    if existing
      weather_prediction_status = 'cache_hit'
      Rails.logger.info "📡 [Candidates] WeatherPredictionService cache hit (target_end_date=#{target_end_date || 'N/A'})"
      weather_data = existing[:data]
    else
      weather_prediction_status = 'requesting_prediction'
      Rails.logger.info "📡 [Candidates] WeatherPredictionService cache miss - invoking prediction (target_end_date=#{target_end_date || 'N/A'})"
      weather_info = weather_prediction_service.predict_for_cultivation_plan(
        cultivation_plan,
        target_end_date: target_end_date
      )
      weather_data = weather_info[:data]
    end

    # 古い保存形式（ネスト構造）の場合は修正
    if weather_data.is_a?(Hash) && weather_data['data'].is_a?(Hash) && weather_data['data']['data'].is_a?(Array)
      weather_data = weather_data['data']
    end

    data_days = weather_data.is_a?(Hash) ? Array(weather_data['data']).count : 0
    Rails.logger.info "📡 [Candidates] WeatherPredictionService result: status=#{weather_prediction_status} days=#{data_days}"

    weather_data
  rescue WeatherPredictionService::WeatherDataNotFoundError, WeatherPredictionService::InsufficientPredictionDataError => e
    Rails.logger.warn "⚠️ [Candidates] Weather prediction error: #{e.message}"
    raise
  rescue => e
    Rails.logger.error "❌ [Candidates] Failed to get weather data: #{e.message}"
    nil
  end

  # candidates コマンドを実行
  def run_candidates(current_allocation, fields, crops, crop, weather_data, planning_start, planning_end, interaction_rules, field_id)
    gateway = Agrr::CandidatesGateway.new
    gateway.candidates(
      current_allocation: current_allocation,
      fields: fields,
      crops: crops,
      target_crop: crop.id.to_s,
      weather_data: weather_data,
      planning_start: planning_start,
      planning_end: planning_end,
      interaction_rules: interaction_rules.empty? ? nil : interaction_rules
    )
  rescue Agrr::BaseGatewayV2::NoAllocationCandidatesError => e
    Rails.logger.info "ℹ️ [Candidates] No allocation candidates: #{e.message}"
    []
  rescue => e
    Rails.logger.error "❌ [Candidates] Failed to run candidates: #{e.message}"
    []
  end

  # 最適な候補を選択（指定ほ場を優先、利益最大化）
  def select_best_candidate(candidates, preferred_field_id)
    preferred_field_id = preferred_field_id.to_i if preferred_field_id.present?

    # 過去の日付の候補を除外（天気データがカバーできないため）
    today = Date.current
    future_candidates = candidates.select do |c|
      begin
        candidate_date = Date.parse(c[:start_date].to_s)
        candidate_date >= today
      rescue ArgumentError
        false
      end
    end

    Rails.logger.info "🔍 [Candidates] Total: #{candidates.length}, Future: #{future_candidates.length} (filtered past dates before #{today})"

    return nil if future_candidates.empty?

    # 指定ほ場の候補を優先
    field_candidates = if preferred_field_id
                         future_candidates.select { |c| c[:field_id].to_i == preferred_field_id }
                       else
                         []
                       end

    pool = field_candidates.present? ? field_candidates : future_candidates

    # 利益が最大の候補を選択
    pool.max_by { |c| c[:profit].to_f }
  end

  def ui_filter_context
    filter_keys = %i[display_start_date display_end_date filters ui_filters field_id crop_id]
    filter_keys.each_with_object({}) do |key, context|
      context[key] = params[key] if params.key?(key)
    end
  end

  def display_range_from_params
    range = {}
    if (start_date = parse_display_date(params[:display_start_date]))
      range[:start_date] = start_date
    end
    if (end_date = parse_display_date(params[:display_end_date]))
      range[:end_date] = end_date
    end
    range
  end

  def parse_display_date(value)
    return nil unless value.present?

    Date.iso8601(value)
  rescue ArgumentError => e
    Rails.logger.warn "⚠️ [Add Crop] 無効な表示範囲日付: #{value.inspect} (#{e.class})"
    nil
  end

  # サブクラスで実装すべきメソッド
  
  # 計画を検索する
  def find_api_cultivation_plan
    raise NotImplementedError, "#{self.class}#find_api_cultivation_plan must be implemented"
  end
  
  # add_cropで使用する作物を取得する
  # @param crop_id [String, Integer] 作物ID
  # @return [Crop, nil] 作物オブジェクト
  def get_crop_for_add_crop(crop_id)
    raise NotImplementedError, "#{self.class}#get_crop_for_add_crop must be implemented"
  end

  # dataアクションで利用可能な作物一覧を取得する
  # @return [ActiveRecord::Relation<Crop>]
  def get_available_crops
    raise NotImplementedError, "#{self.class}#get_available_crops must be implemented"
  end
end

