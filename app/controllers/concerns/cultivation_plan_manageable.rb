# frozen_string_literal: true

# PlansControllerとPublicPlansControllerの共通機能を提供するConcern
#
# 使い方:
# - plan_typeを定義: 'private' または 'public'
# - session_keyを定義: セッションで使用するキー（例: :plan_data, :public_plan）
# - redirect_pathを定義: エラー時のリダイレクト先パス
# - find_cultivation_plan_scopeを実装: 計画を検索するスコープ
module CultivationPlanManageable
  extend ActiveSupport::Concern
  
  included do
    # サブクラスで定義すべきメソッドの例外
    class_attribute :plan_type, :session_key, :redirect_path_method
  end
  
  # 栽培計画を検索
  # サブクラスでfind_cultivation_plan_scopeを実装する必要がある
  def find_cultivation_plan
    plan_id = params[:id] || session_data[:plan_id]
    
    unless plan_id
      redirect_to send(redirect_path_method), alert: I18n.t("#{i18n_scope}.errors.not_found")
      return nil
    end
    
    find_cultivation_plan_scope
      .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
      .find(plan_id)
  rescue ActiveRecord::RecordNotFound
    redirect_to send(redirect_path_method), alert: I18n.t("#{i18n_scope}.errors.not_found")
    nil
  end
  
  # セッションデータを取得
  def session_data
    (session[session_key] || {}).with_indifferent_access
  end
  
  # 選択された作物IDを取得
  def crop_ids
    Rails.logger.debug "🔍 [CultivationPlanManageable] params[:crop_ids]: #{params[:crop_ids].inspect}"
    Rails.logger.debug "🔍 [CultivationPlanManageable] params keys: #{params.keys.inspect}"
    result = params[:crop_ids].presence || []
    Rails.logger.debug "🔍 [CultivationPlanManageable] crop_ids result: #{result.inspect}"
    result
  end
  
  # I18nスコープ（plans または public_plans）
  def i18n_scope
    plan_type == 'private' ? 'plans' : 'public_plans'
  end
  
  # 最適化進捗画面の共通処理
  def handle_optimizing(force_weather_only:)
    Rails.logger.info "🔍 [CultivationPlanManageable#handle_optimizing] Finding cultivation plan"
    @cultivation_plan = find_cultivation_plan
    return unless @cultivation_plan
    
    Rails.logger.info "📊 [CultivationPlanManageable#handle_optimizing] Plan status: #{@cultivation_plan.status}"
    if @cultivation_plan.status_completed?
      Rails.logger.info "✅ [CultivationPlanManageable#handle_optimizing] Plan completed, redirecting to completion page"
      redirect_to_completion_page
    end
    # 最適化ジョブは計画作成時に既に実行されているため、ここでは何もしない
  end
  
  private
  
  def redirect_to_completion_page
    completion_path = completion_redirect_path
    redirect_to send(completion_path, @cultivation_plan)
  end
  
  
  # 計画作成の共通処理
  def create_cultivation_plan(farm:, total_area:, crops:, redirect_path:, additional_params: {})
    if crops.empty?
      redirect_to send(select_crop_redirect_path), 
                  alert: I18n.t("#{i18n_scope}.errors.select_crop")
      return
    end
    
    # セッションIDを取得
    session_id = session.id.to_s
    Rails.logger.info "🔑 [#{self.class.name}#create] Using session_id: #{session_id}"
    
    # 計画作成パラメータを構築
    creator_params = {
      farm: farm,
      total_area: total_area,
      crops: crops,
      user: current_user,
      session_id: session_id,
      plan_type: plan_type
    }.merge(additional_params)
    
    # Service で計画作成
    result = CultivationPlanCreator.new(**creator_params).call
    
    if result.success?
      Rails.logger.info "✅ [#{self.class.name}#create] CultivationPlan created: #{result.cultivation_plan.id}"
      session[session_key] = { plan_id: result.cultivation_plan.id }
      
      # 天気予測が必要な場合は実行
      if result.cultivation_plan.requires_weather_prediction?
        Rails.logger.info "🌤️ [#{self.class.name}#create] Starting weather prediction for plan ##{result.cultivation_plan.id}"
        job = WeatherPredictionJob.new
        job.cultivation_plan_id = result.cultivation_plan.id
        job.channel_class = channel_class
        job.perform_later
      end
      
      # リダイレクト先を決定
      redirect_to send(redirect_path)
    else
      redirect_to send(redirect_path_method), 
                  alert: I18n.t("#{i18n_scope}.errors.create_failed", errors: result.errors.join(', '))
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to send(redirect_path_method), alert: I18n.t("#{i18n_scope}.errors.restart")
  end
  
  private
  
  # サブクラスで実装すべきメソッド
  
  # 計画を検索するスコープ
  def find_cultivation_plan_scope
    raise NotImplementedError, "#{self.class}#find_cultivation_plan_scope must be implemented"
  end
  
  # 作物選択画面へのリダイレクトパス
  def select_crop_redirect_path
    raise NotImplementedError, "#{self.class}#select_crop_redirect_path must be implemented"
  end
  
  # 最適化中画面へのリダイレクトパス
  def optimizing_redirect_path
    raise NotImplementedError, "#{self.class}#optimizing_redirect_path must be implemented"
  end
  
  # 完了時のリダイレクトパス
  def completion_redirect_path
    raise NotImplementedError, "#{self.class}#completion_redirect_path must be implemented"
  end
end

