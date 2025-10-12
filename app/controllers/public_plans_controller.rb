# frozen_string_literal: true

class PublicPlansController < ApplicationController
  skip_before_action :authenticate_user!
  layout 'public'
  
  # 農場サイズの定数定義
  FARM_SIZES = [
    { id: 'home_garden', name: '家庭菜園', area_sqm: 30, description: '自宅の庭やベランダ' },
    { id: 'community_garden', name: '市民農園', area_sqm: 50, description: '一般的な市民農園の区画' },
    { id: 'rental_farm', name: '貸農地', area_sqm: 300, description: '本格的な農業や貸農園' }
  ].freeze
  
  # Step 1: 栽培地域（参照農場）選択
  def new
    @farms = Farm.reference.order(:name)
  end
  
  # Step 2: 農場サイズ選択
  def select_farm_size
    @farm = Farm.find(params[:farm_id])
    @farm_sizes = FARM_SIZES
    
    session[:public_plan] = { farm_id: @farm.id }
  rescue ActiveRecord::RecordNotFound
    redirect_to public_plans_path, alert: '栽培地域を選択してください。'
  end
  
  # Step 3: 作物選択
  def select_crop
    unless session_data[:farm_id]
      redirect_to public_plans_path, alert: '最初からやり直してください。' and return
    end
    
    @farm = Farm.find(session_data[:farm_id])
    @farm_size = FARM_SIZES.find { |fs| fs[:id] == params[:farm_size_id] }
    
    unless @farm_size
      redirect_to select_farm_size_public_plans_path(farm_id: @farm.id), 
                  alert: '農場サイズを選択してください。' and return
    end
    
    @crops = Crop.reference.order(:name)
    session_data[:total_area] = @farm_size[:area_sqm]
    session[:public_plan] = session_data
  rescue ActiveRecord::RecordNotFound
    redirect_to public_plans_path, alert: '最初からやり直してください。'
  end
  
  # Step 4: 作付け計画作成（計算開始）
  def create
    unless session_data[:farm_id] && session_data[:total_area]
      redirect_to public_plans_path, alert: '最初からやり直してください。' and return
    end
    
    farm = Farm.find(session_data[:farm_id])
    total_area = session_data[:total_area]
    crops = Crop.where(id: crop_ids)
    
    if crops.empty?
      redirect_to select_crop_public_plans_path, alert: '作物を1つ以上選択してください。' and return
    end
    
    # Service で計画作成
    result = CultivationPlanCreator.new(
      farm: farm,
      total_area: total_area,
      crops: crops,
      user: current_user,
      session_id: request.session_options[:id]
    ).call
    
    if result.success?
      session[:public_plan] = { plan_id: result.cultivation_plan.id }
      
      # 非同期で最適化実行
      OptimizeCultivationPlanJob.perform_later(result.cultivation_plan.id)
      
      redirect_to optimizing_public_plans_path
    else
      redirect_to public_plans_path, alert: "計画作成に失敗しました: #{result.errors.join(', ')}"
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to public_plans_path, alert: '最初からやり直してください。'
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
  
  def find_cultivation_plan
    plan_id = session_data[:plan_id]
    
    unless plan_id
      redirect_to public_plans_path, alert: '作付け計画が見つかりません。'
      return nil
    end
    
    CultivationPlan
      .includes(field_cultivations: [:field, :crop])
      .find(plan_id)
  rescue ActiveRecord::RecordNotFound
    redirect_to new_public_plan_path, alert: '作付け計画が見つかりません。'
    nil
  end
  
  def session_data
    session[:public_plan] || {}
  end
  
  def crop_ids
    params[:crop_ids].presence || []
  end
end

