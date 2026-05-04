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

    display_range = display_range_from_params
    display_start_date = display_range[:start_date]
    display_end_date = display_range[:end_date]
    if display_start_date || display_end_date
      Rails.logger.info "📅 [Add Crop] Display range from UI: start=#{display_start_date} end=#{display_end_date}"
    else
      Rails.logger.info "📅 [Add Crop] Display range from UI: not provided"
    end

    Domain::CultivationPlan::Interactors::AddCropInteractor.new(
      output: Presenters::Api::CultivationPlan::ApiAddCropPresenter.new(
        view: self,
        translation_scope: api_cultivation_plan_translation_scope
      ),
      add_crop_coordinator_gateway: cultivation_plan_rest_add_crop_coordinator_gateway
    ).call(
      auth: cultivation_plan_rest_auth,
      plan_id: params[:id].to_i,
      crop_id: params[:crop_id],
      field_id: params[:field_id],
      display_range: display_range,
      crop_resolver: cultivation_plan_rest_add_crop_crop_resolver_bridge
    )
  end

  # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/add_field
  # 新しい圃場を追加
  def add_field
    Domain::CultivationPlan::Interactors::AddFieldInteractor.new(
      output: Presenters::Api::CultivationPlan::ApiAddFieldPresenter.new(
        view: self,
        translation_scope: api_cultivation_plan_translation_scope
      ),
      field_mutation_gateway: cultivation_plan_rest_field_mutation_gateway
    ).call(
      auth: cultivation_plan_rest_auth,
      plan_id: params[:id].to_i,
      field_name: params[:field_name],
      field_area: params[:field_area],
      daily_fixed_cost: params[:daily_fixed_cost]
    )
  end

  # DELETE /api/v1/{plans|public_plans}/cultivation_plans/:id/remove_field/:field_id
  # 圃場を削除
  def remove_field
    Domain::CultivationPlan::Interactors::RemoveFieldInteractor.new(
      output: Presenters::Api::CultivationPlan::ApiRemoveFieldPresenter.new(
        view: self,
        translation_scope: api_cultivation_plan_translation_scope
      ),
      field_mutation_gateway: cultivation_plan_rest_field_mutation_gateway
    ).call(
      auth: cultivation_plan_rest_auth,
      plan_id: params[:id].to_i,
      field_id_param: params[:field_id]
    )
  end

  # GET /api/v1/{plans|public_plans}/cultivation_plans/:id/data
  # 栽培計画データを取得
  def data
    plan = begin
      find_api_cultivation_plan
    rescue ActiveRecord::RecordNotFound
      Presenters::Api::CultivationPlan::ApiPlanDataPresenter.new(
        view: self,
        translation_scope: api_cultivation_plan_translation_scope
      ).on_not_found
      return
    end

    @cultivation_plan = plan
    available_crop_rows = Array(get_available_crops).map do |c|
      { id: c.id, name: c.name, variety: c.variety, area_per_unit: c.area_per_unit }
    end

    Domain::CultivationPlan::Interactors::RetrieveCultivationPlanInteractor.new(
      output: Presenters::Api::CultivationPlan::ApiPlanDataPresenter.new(
        view: self,
        translation_scope: api_cultivation_plan_translation_scope
      ),
      workbook_payload_gateway: cultivation_plan_rest_workbook_payload_gateway
    ).call(auth: cultivation_plan_rest_auth, plan_id: params[:id].to_i, available_crop_rows: available_crop_rows)
  end

  # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/adjust
  # 手修正後の再最適化
  #
  # このメソッドはDBに保存された天気データを再利用し、
  # 不要な天気予測を実行しないことで高速化されています
  def adjust
    moves = Adapters::CultivationPlan::AdjustMovesFromRequest.normalize(params[:moves] || [])
    Domain::CultivationPlan::Interactors::ManualPlanAdjustInteractor.new(
      output: Presenters::Api::CultivationPlan::ApiPlanAdjustPresenter.new(view: self),
      adjust_gateway: cultivation_plan_rest_adjust_gateway
    ).call(
      auth: cultivation_plan_rest_auth,
      plan_id: params[:id].to_i,
      moves: moves
    )
  end

  private

  # lib/domain は具象 Gateway を知らず、Concern で組み立てて注入する
  def cultivation_plan_rest_logger
    CompositionRoot.logger
  end

  def cultivation_plan_rest_auth
    Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.for_api_controller(self)
  end

  def cultivation_plan_rest_optimization_events_gateway
    @cultivation_plan_rest_optimization_events_gateway ||= Adapters::CultivationPlan::Gateways::CultivationPlanRestOptimizationEventsActionCableGateway.new(
      logger: cultivation_plan_rest_logger
    )
  end

  def cultivation_plan_rest_field_mutation_gateway
    Adapters::CultivationPlan::Gateways::CultivationPlanRestFieldMutationActiveRecordGateway.new(
      events_gateway: cultivation_plan_rest_optimization_events_gateway,
      logger: cultivation_plan_rest_logger
    )
  end

  def cultivation_plan_rest_workbook_payload_gateway
    Adapters::CultivationPlan::Gateways::CultivationPlanRestWorkbenchPayloadActiveRecordGateway.new(
      logger: cultivation_plan_rest_logger
    )
  end

  def cultivation_plan_rest_adjust_gateway
    Adapters::CultivationPlan::Gateways::CultivationPlanRestAdjustThroughHostGateway.new(
      host_controller: self,
      logger: cultivation_plan_rest_logger
    )
  end

  def cultivation_plan_rest_add_crop_optimizer_bridge
    @cultivation_plan_rest_add_crop_optimizer_bridge ||= Adapters::CultivationPlan::RestAddCropOptimizationHostBridge.new(self)
  end

  def cultivation_plan_rest_add_crop_crop_resolver_bridge
    Adapters::CultivationPlan::RestAddCropCropResolverBridge.new(self)
  end

  def cultivation_plan_rest_add_crop_coordinator_gateway
    Adapters::CultivationPlan::Gateways::CultivationPlanRestAddCropCoordinatorActiveRecordGateway.new(
      optimization_host: cultivation_plan_rest_add_crop_optimizer_bridge,
      logger: cultivation_plan_rest_logger
    )
  end

  # Api::V1::Plans::* と PublicPlans::* で I18n スコープを切り替える
  def api_cultivation_plan_translation_scope
    self.class.name.include?("::PublicPlans::") ? "public_plans" : "plans"
  end

  def i18n_t(key)
    scope = @cultivation_plan&.plan_type == "private" ? "plans" : "public_plans"
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
      { field_cultivations: [ :cultivation_plan_field, { cultivation_plan_crop: :crop } ] }
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
    candidates_end = [ base_candidates_end, display_end_date ].compact.max
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

    weather_prediction_service = CompositionRoot.weather_prediction_interactor(weather_location: weather_location, farm: farm)

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
      cultivation_plan_weather: CompositionRoot.cultivation_plan_weather_dto_from(cultivation_plan)
    )

    weather_prediction_status = nil
    weather_data = nil

    if existing
      weather_prediction_status = "cache_hit"
      Rails.logger.info "📡 [Candidates] Domain::WeatherData::Interactors::WeatherPredictionInteractor cache hit (target_end_date=#{target_end_date || 'N/A'})"
      weather_data = existing[:data]
    else
      weather_prediction_status = "requesting_prediction"
      Rails.logger.info "📡 [Candidates] Domain::WeatherData::Interactors::WeatherPredictionInteractor cache miss - invoking prediction (target_end_date=#{target_end_date || 'N/A'})"
      weather_info = weather_prediction_service.predict_for_cultivation_plan(
        plan_weather: CompositionRoot.cultivation_plan_weather_dto_from(cultivation_plan),
        target_end_date: target_end_date
      )
      weather_data = weather_info[:data]
    end

    # 古い保存形式（ネスト構造）の場合は修正
    if weather_data.is_a?(Hash) && weather_data["data"].is_a?(Hash) && weather_data["data"]["data"].is_a?(Array)
      weather_data = weather_data["data"]
    end

    data_days = weather_data.is_a?(Hash) ? Array(weather_data["data"]).count : 0
    Rails.logger.info "📡 [Candidates] Domain::WeatherData::Interactors::WeatherPredictionInteractor result: status=#{weather_prediction_status} days=#{data_days}"

    weather_data
  rescue Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError, Domain::WeatherData::Interactors::WeatherPredictionInteractor::InsufficientPredictionDataError => e
    Rails.logger.warn "⚠️ [Candidates] Weather prediction error: #{e.message}"
    raise
  rescue => e
    Rails.logger.error "❌ [Candidates] Failed to get weather data: #{e.message}"
    nil
  end

  # candidates コマンドを実行
  def run_candidates(current_allocation, fields, crops, crop, weather_data, planning_start, planning_end, interaction_rules, field_id)
    interactor = Domain::CultivationPlan::Interactors::AgrrCandidatesInteractor.new(
      gateway: CompositionRoot.agrr_candidates_gateway,
      logger: CompositionRoot.logger
    )
    interactor.call(
      current_allocation: current_allocation,
      fields: fields,
      crops: crops,
      target_crop_id: crop.id,
      weather_data: weather_data,
      planning_start: planning_start,
      planning_end: planning_end,
      interaction_rules: interaction_rules.empty? ? nil : interaction_rules
    )
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
