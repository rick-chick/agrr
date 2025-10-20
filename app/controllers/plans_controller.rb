# frozen_string_literal: true

class PlansController < ApplicationController
  before_action :authenticate_user!
  layout 'application'
  
  # 計画一覧（年度別）
  def index
    @current_year = Date.current.year
    @available_years = ((@current_year - 1)..(@current_year + 5)).to_a
    
    # ユーザーの全計画を取得（年度別にグループ化）
    @plans_by_year = CultivationPlan
      .plan_type_private
      .by_user(current_user)
      .includes(:farm, field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
      .recent
      .group_by(&:plan_year)
    
    Rails.logger.debug "📅 [Plans#index] User: #{current_user.id}, Plans: #{@plans_by_year.keys.inspect}"
  end
  
  # Step 1: 年度・農場選択
  def new
    @current_year = Date.current.year
    @available_years = ((@current_year - 1)..(@current_year + 5)).to_a
    
    # ユーザーの農場を取得
    @farms = current_user.farms.user_owned.to_a
    
    # デフォルト計画名
    @default_plan_name = I18n.t('plans.default_plan_name')
    
    Rails.logger.debug "🌍 [Plans#new] User: #{current_user.id}, Farms: #{@farms.count}"
  end
  
  # Step 2: 作物選択
  def select_crop
    unless params[:plan_year].present? && params[:farm_id].present?
      redirect_to new_plan_path, alert: I18n.t('plans.errors.select_year_and_farm') and return
    end
    
    @plan_year = params[:plan_year].to_i
    @farm = current_user.farms.find(params[:farm_id])
    @plan_name = params[:plan_name].presence || I18n.t('plans.default_plan_name')
    
    # ユーザーの作物のみ取得
    @crops = current_user.crops.where(is_reference: false).order(:name)
    
    # 農場の圃場を取得
    @fields = @farm.fields.order(:name)
    
    # 総面積を計算
    @total_area = @fields.sum(:area)
    
    # セッションに保存
    session[:plan_data] = {
      plan_year: @plan_year,
      farm_id: @farm.id,
      plan_name: @plan_name,
      total_area: @total_area
    }
    
    Rails.logger.debug "✅ [Plans#select_crop] Session saved: #{session[:plan_data].inspect}"
  rescue ActiveRecord::RecordNotFound
    redirect_to new_plan_path, alert: I18n.t('plans.errors.farm_not_found')
  end
  
  # Step 3: 計画作成（最適化開始）
  def create
    unless plan_session_data[:farm_id] && plan_session_data[:plan_year]
      redirect_to new_plan_path, alert: I18n.t('plans.errors.restart') and return
    end
    
    farm = current_user.farms.find(plan_session_data[:farm_id])
    plan_year = plan_session_data[:plan_year]
    plan_name = plan_session_data[:plan_name]
    crops = current_user.crops.where(id: crop_ids, is_reference: false)
    
    if crops.empty?
      redirect_to select_crop_plans_path, alert: I18n.t('plans.errors.select_crop') and return
    end
    
    # 計画期間を計算
    planning_dates = CultivationPlan.calculate_planning_dates(plan_year)
    
    # Service で計画作成
    result = CultivationPlanCreator.new(
      farm: farm,
      total_area: plan_session_data[:total_area],
      crops: crops,
      user: current_user,
      plan_type: 'private',
      plan_year: plan_year,
      plan_name: plan_name,
      planning_start_date: planning_dates[:start_date],
      planning_end_date: planning_dates[:end_date]
    ).call
    
    if result.success?
      Rails.logger.info "✅ [Plans#create] CultivationPlan created: #{result.cultivation_plan.id}"
      session[:plan_data] = { plan_id: result.cultivation_plan.id }
      
      # 非同期で最適化実行
      OptimizeCultivationPlanJob.perform_later(result.cultivation_plan.id)
      
      redirect_to optimizing_plan_path(result.cultivation_plan)
    else
      redirect_to new_plan_path, alert: I18n.t('plans.errors.create_failed', errors: result.errors.join(', '))
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to new_plan_path, alert: I18n.t('plans.errors.restart')
  end
  
  # Step 4: 最適化進捗画面
  def optimizing
    @cultivation_plan = find_cultivation_plan
    return unless @cultivation_plan
    
    # 完了している場合は詳細画面へ
    redirect_to plan_path(@cultivation_plan) if @cultivation_plan.status_completed?
  end
  
  # Step 5: 計画詳細（結果表示）
  def show
    @cultivation_plan = find_cultivation_plan
    return unless @cultivation_plan
    
    # まだ完了していない場合は進捗画面へ
    redirect_to optimizing_plan_path(@cultivation_plan) unless @cultivation_plan.status_completed?
  end
  
  # 計画コピー（前年度の計画を新年度にコピー）
  def copy
    source_plan = current_user.cultivation_plans.plan_type_private.find(params[:id])
    
    # 新しい年度を決定（現在の計画年度 + 1）
    new_year = source_plan.plan_year + 1
    
    # 既に同じ年度の計画がある場合はエラー
    if current_user.cultivation_plans.plan_type_private.exists?(plan_year: new_year, plan_name: source_plan.plan_name)
      redirect_to plans_path, alert: I18n.t('plans.errors.plan_already_exists', year: new_year) and return
    end
    
    # PlanCopierサービスで計画をコピー
    result = PlanCopier.new(
      source_plan: source_plan,
      new_year: new_year,
      user: current_user
    ).call
    
    if result.success?
      redirect_to plan_path(result.new_plan), notice: I18n.t('plans.messages.plan_copied', year: new_year)
    else
      redirect_to plans_path, alert: I18n.t('plans.errors.copy_failed', errors: result.errors.join(', '))
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to plans_path, alert: I18n.t('plans.errors.not_found')
  end
  
  private
  
  def find_cultivation_plan
    plan_id = params[:id] || plan_session_data[:plan_id]
    
    unless plan_id
      redirect_to plans_path, alert: I18n.t('plans.errors.not_found')
      return nil
    end
    
    CultivationPlan
      .plan_type_private
      .by_user(current_user)
      .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
      .find(plan_id)
  rescue ActiveRecord::RecordNotFound
    redirect_to plans_path, alert: I18n.t('plans.errors.not_found')
    nil
  end
  
  def plan_session_data
    (session[:plan_data] || {}).with_indifferent_access
  end
  
  def crop_ids
    params[:crop_ids].presence || []
  end
end

