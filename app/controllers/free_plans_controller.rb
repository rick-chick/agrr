# frozen_string_literal: true

class FreePlansController < ApplicationController
  skip_before_action :authenticate_user!
  layout 'free_plans'
  
  before_action :set_free_crop_plan, only: %i[calculating show]
  
  # 農場サイズの定数定義（広さ順）
  FARM_SIZES = [
    { id: 'home_garden', name: '家庭菜園', area_sqm: 30, description: '自宅の庭やベランダでの菜園' },
    { id: 'community_garden', name: '市民農園', area_sqm: 50, description: '一般的な市民農園の区画' },
    { id: 'rental_farm', name: '貸農地', area_sqm: 300, description: '本格的な農業や貸農園' }
  ].freeze
  
  # Step 1: 栽培地域（参照農場）選択
  def new
    # 参照農場を一覧表示（これが栽培地域となる）
    @farms = Farm.reference
  end
  
  # Step 2: 農場サイズ選択
  def select_farm_size
    @farm = Farm.find(params[:farm_id])
    @farm_sizes = FARM_SIZES
    
    # セッションに農場IDを保存
    session[:free_plan_farm_id] = @farm.id
  rescue ActiveRecord::RecordNotFound
    redirect_to new_free_plan_path, alert: '栽培地域を選択してください。'
  end
  
  # Step 3: 作物選択
  def select_crop
    @farm = Farm.find(session[:free_plan_farm_id])
    farm_size_id = params[:farm_size_id]
    @farm_size = FARM_SIZES.find { |fs| fs[:id] == farm_size_id }
    
    unless @farm_size
      redirect_to new_free_plan_path, alert: '農場サイズを選択してください。' and return
    end
    
    @crops = Crop.reference.recent
    
    # セッションに農場サイズIDを保存
    session[:free_plan_farm_size_id] = farm_size_id
  rescue ActiveRecord::RecordNotFound
    redirect_to new_free_plan_path, alert: '最初からやり直してください。'
  end
  
  # Step 4: 作付け計画作成（計算開始）
  def create
    @farm = Farm.find(session[:free_plan_farm_id])
    farm_size_id = session[:free_plan_farm_size_id]
    @farm_size = FARM_SIZES.find { |fs| fs[:id] == farm_size_id }
    
    unless @farm_size
      redirect_to new_free_plan_path, alert: '農場サイズを選択してください。' and return
    end
    
    # 複数の作物IDを取得
    crop_ids = params[:crop_ids].presence || []
    
    if crop_ids.empty?
      redirect_to new_free_plan_path, alert: '作物を選択してください。' and return
    end
    
    # 選択された作物ごとに計画を作成
    created_plans = []
    crop_ids.each do |crop_id|
      crop = Crop.find(crop_id)
      free_crop_plan = FreeCropPlan.create(
        farm: @farm,
        area_sqm: @farm_size[:area_sqm],
        crop: crop,
        session_id: request.session_options[:id]
      )
      
      if free_crop_plan.persisted?
        created_plans << free_crop_plan
        # バックグラウンドジョブで計算を開始
        GenerateFreeCropPlanJob.perform_later(free_crop_plan.id)
      end
    end
    
    if created_plans.any?
      # セッションに作成したプランIDを保存
      session[:free_plan_ids] = created_plans.map(&:id)
      
      # セッションをクリア
      session.delete(:free_plan_farm_id)
      session.delete(:free_plan_farm_size_id)
      
      # 複数プランの計算画面へ
      redirect_to calculating_all_free_plans_path
    else
      redirect_to new_free_plan_path, alert: '作付け計画の作成に失敗しました。'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to new_free_plan_path, alert: '最初からやり直してください。'
  end
  
  # Step 5: 複数計画の計算進捗（広告表示）
  def calculating_all
    plan_ids = session[:free_plan_ids] || []
    
    if plan_ids.empty?
      redirect_to new_free_plan_path, alert: '作付け計画が見つかりません。最初からやり直してください。'
      return
    end
    
    # N+1クエリ対策: farm, cropをeager load
    @free_crop_plans = FreeCropPlan.where(id: plan_ids).includes(:farm, :crop)
    
    if @free_crop_plans.empty?
      redirect_to new_free_plan_path, alert: '作付け計画が見つかりません。最初からやり直してください。'
      return
    end
    
    # すべて完了している場合は結果画面へ
    if @free_crop_plans.all?(&:completed?)
      redirect_to results_free_plans_path
    end
  end
  
  # Step 6: 複数計画の結果表示
  def results
    plan_ids = session[:free_plan_ids] || []
    
    if plan_ids.empty?
      redirect_to new_free_plan_path, alert: '作付け計画が見つかりません。'
      return
    end
    
    # N+1クエリ対策: farm, cropをeager load
    @free_crop_plans = FreeCropPlan.where(id: plan_ids).includes(:farm, :crop)
    
    if @free_crop_plans.empty?
      redirect_to new_free_plan_path, alert: '作付け計画が見つかりません。'
      return
    end
    
    # 計算中のものがある場合は進捗画面へ
    if @free_crop_plans.any?(&:calculating?)
      redirect_to calculating_all_free_plans_path
    end
  end
  
  # Step 5: 計算進捗（広告表示）
  def calculating
    # 計算が完了している場合は結果画面へリダイレクト
    redirect_to free_plan_path(@free_crop_plan) if @free_crop_plan.completed?
  end
  
  # Step 6: 作付け計画表示
  def show
    # 計算中の場合は進捗画面へリダイレクト
    if @free_crop_plan.calculating?
      redirect_to calculating_free_plan_path(@free_crop_plan)
    elsif @free_crop_plan.failed?
      redirect_to new_free_plan_path, alert: '作付け計画の生成に失敗しました。もう一度お試しください。'
    end
  end
  
  private
  
  def set_free_crop_plan
    @free_crop_plan = FreeCropPlan.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to new_free_plan_path, alert: '作付け計画が見つかりません。'
  end
end

