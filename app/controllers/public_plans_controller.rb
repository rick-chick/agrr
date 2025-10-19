# frozen_string_literal: true

class PublicPlansController < ApplicationController
  skip_before_action :authenticate_user!
  layout 'public'
  
  # 農場サイズの定数定義
  def self.farm_sizes
    [
      { id: 'home_garden', area_sqm: 30 },
      { id: 'community_garden', area_sqm: 50 },
      { id: 'rental_farm', area_sqm: 300 }
    ]
  end
  
  def farm_sizes_with_i18n
    self.class.farm_sizes.map do |size|
      size.merge(
        name: I18n.t("public_plans.farm_sizes.#{size[:id]}.name"),
        description: I18n.t("public_plans.farm_sizes.#{size[:id]}.description")
      )
    end
  end
  
  # Step 1: 栽培地域（参照農場）選択
  def new
    # URLのlocaleから地域を自動取得（/ja → jp, /us → us）
    # デフォルト: jp
    region = locale_to_region(I18n.locale)
    
    # 選択された地域の参照農場のみ取得
    @farms = Farm.reference.where(region: region).to_a
    
    Rails.logger.debug "🌍 [PublicPlans#new] locale=#{I18n.locale}, region=#{region}, farms=#{@farms.count}"
  end
  
  # Step 2: 農場サイズ選択
  def select_farm_size
    @farm = Farm.find(params[:farm_id])
    @farm_sizes = farm_sizes_with_i18n
    
    session[:public_plan] = { farm_id: @farm.id }
    Rails.logger.debug "✅ [PublicPlans] セッション保存: #{session[:public_plan].inspect}"
  rescue ActiveRecord::RecordNotFound
    redirect_to public_plans_path, alert: I18n.t('public_plans.errors.select_region')
  end
  
  # Step 3: 作物選択
  def select_crop
    Rails.logger.debug "🔍 [PublicPlans] セッション確認: #{session[:public_plan].inspect}"
    Rails.logger.debug "🔍 [PublicPlans] session_data: #{session_data.inspect}"
    
    unless session_data[:farm_id]
      Rails.logger.warn "⚠️  [PublicPlans] farm_id がセッションにありません"
      redirect_to public_plans_path, alert: I18n.t('public_plans.errors.restart') and return
    end
    
    @farm = Farm.find(session_data[:farm_id])
    @farm_size = farm_sizes_with_i18n.find { |fs| fs[:id] == params[:farm_size_id] }
    
    unless @farm_size
      redirect_to select_farm_size_public_plans_path(farm_id: @farm.id), 
                  alert: I18n.t('public_plans.errors.select_farm_size') and return
    end
    
    # 選択された農場の地域の作物のみ取得
    @crops = Crop.reference.where(region: @farm.region).order(:name)
    session[:public_plan] = session_data.merge(
      total_area: @farm_size[:area_sqm],
      farm_size_id: @farm_size[:id]
    )
    Rails.logger.debug "✅ [PublicPlans] セッション更新: #{session[:public_plan].inspect}"
  rescue ActiveRecord::RecordNotFound
    redirect_to public_plans_path, alert: I18n.t('public_plans.errors.restart')
  end
  
  # Step 4: 作付け計画作成（計算開始）
  def create
    unless session_data[:farm_id] && session_data[:total_area]
      redirect_to public_plans_path, alert: I18n.t('public_plans.errors.restart') and return
    end
    
    farm = Farm.find(session_data[:farm_id])
    total_area = session_data[:total_area]
    crops = Crop.where(id: crop_ids)
    
    if crops.empty?
      redirect_to select_crop_public_plans_path, alert: I18n.t('public_plans.errors.select_crop') and return
    end
    
    # Service で計画作成
    session_id = session.id.to_s
    Rails.logger.info "🔑 [PublicPlans#create] Using session_id: #{session_id}"
    
    result = CultivationPlanCreator.new(
      farm: farm,
      total_area: total_area,
      crops: crops,
      user: current_user,
      session_id: session_id
    ).call
    
    if result.success?
      Rails.logger.info "✅ [PublicPlans#create] CultivationPlan created with session_id: #{result.cultivation_plan.session_id}"
      session[:public_plan] = { plan_id: result.cultivation_plan.id }
      
      # 非同期で最適化実行
      OptimizeCultivationPlanJob.perform_later(result.cultivation_plan.id)
      
      redirect_to optimizing_public_plans_path
    else
      redirect_to public_plans_path, alert: I18n.t('public_plans.errors.create_failed', errors: result.errors.join(', '))
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to public_plans_path, alert: I18n.t('public_plans.errors.restart')
  end
  
  # Step 5: 最適化進捗画面（広告表示）
  def optimizing
    @cultivation_plan = find_cultivation_plan
    return unless @cultivation_plan
    
    # 完了している場合は結果画面へ
    redirect_to results_public_plans_path if @cultivation_plan.status_completed?
  end
  
  # Step 6: 結果表示
  def results
    @cultivation_plan = find_cultivation_plan
    return unless @cultivation_plan
    
    # まだ完了していない場合は進捗画面へ
    redirect_to optimizing_public_plans_path unless @cultivation_plan.status_completed?
  end
  
  private
  
  # localeから地域コードに変換（/ja → jp, /us → us, /in → in）
  def locale_to_region(locale)
    case locale.to_s
    when 'ja'
      'jp'
    when 'us'
      'us'
    when 'in'
      'in'
    else
      'jp' # デフォルト
    end
  end
  
  def find_cultivation_plan
    # テスト用: URLパラメータでplan_idを受け取る（開発・テスト環境のみ）
    plan_id = if Rails.env.test? && params[:plan_id].present?
      params[:plan_id]
    else
      session_data[:plan_id]
    end
    
    unless plan_id
      redirect_to public_plans_path, alert: I18n.t('public_plans.errors.not_found')
      return nil
    end
    
    CultivationPlan
      .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
      .find(plan_id)
  rescue ActiveRecord::RecordNotFound
    redirect_to public_plans_path, alert: I18n.t('public_plans.errors.not_found')
    nil
  end
  
  def session_data
    (session[:public_plan] || {}).with_indifferent_access
  end
  
  def crop_ids
    params[:crop_ids].presence || []
  end
end

