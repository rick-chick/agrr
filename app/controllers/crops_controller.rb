# frozen_string_literal: true

class CropsController < ApplicationController
  before_action :set_crop, only: [:show, :edit, :update, :destroy]

  # GET /crops
  def index
    @crops = Crop.where("is_reference = ? OR user_id = ?", true, current_user.id).recent
  end

  # GET /crops/:id
  def show
  end

  # GET /crops/new
  def new
    @crop = Crop.new
  end

  # GET /crops/:id/edit
  def edit
  end

  # POST /crops
  def create
    is_reference = crop_params[:is_reference] || false
    if is_reference && !admin_user?
      return redirect_to crops_path, alert: '参照作物は管理者のみ作成できます。'
    end

    @crop = Crop.new(crop_params)
    @crop.user_id = nil if is_reference
    @crop.user_id ||= current_user.id

    if @crop.save
      redirect_to @crop, notice: '作物が正常に作成されました。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /crops/:id
  def update
    if crop_params.key?(:is_reference) && !admin_user?
      return redirect_to @crop, alert: '参照フラグは管理者のみ変更できます。'
    end

    if @crop.update(crop_params)
      redirect_to @crop, notice: '作物が正常に更新されました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /crops/:id
  def destroy
    @crop.destroy
    redirect_to crops_path, notice: '作物が削除されました。'
  end

  private

  def set_crop
    @crop = Crop.find(params[:id])
    
    # アクションに応じた権限チェック
    action = params[:action].to_sym
    
    if action.in?([:edit, :update, :destroy])
      # 編集・更新・削除は以下の場合のみ許可
      # - 管理者（すべての作物を編集可能）
      # - ユーザー作物の所有者
      unless admin_user? || (!@crop.is_reference && @crop.user_id == current_user.id)
        redirect_to crops_path, alert: '権限がありません。'
      end
    elsif action == :show
      # 詳細表示は以下の場合に許可
      # - 参照作物（誰でも閲覧可能）
      # - 自分の作物
      # - 管理者
      unless @crop.is_reference || @crop.user_id == current_user.id || admin_user?
        redirect_to crops_path, alert: '権限がありません。'
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to crops_path, alert: '指定された作物が見つかりません。'
  end

  def crop_params
    params.require(:crop).permit(
      :name, 
      :variety, 
      :is_reference,
      :area_per_unit,
      :revenue_per_area,
      :agrr_crop_id,
      crop_stages_attributes: [
        :id,
        :name,
        :order,
        :_destroy,
        temperature_requirement_attributes: [
          :id,
          :base_temperature,
          :optimal_min,
          :optimal_max,
          :low_stress_threshold,
          :high_stress_threshold,
          :frost_threshold,
          :sterility_risk_threshold,
          :_destroy
        ],
        sunshine_requirement_attributes: [
          :id,
          :minimum_sunshine_hours,
          :target_sunshine_hours,
          :_destroy
        ]
      ]
    )
  end
end


