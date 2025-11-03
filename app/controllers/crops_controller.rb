# frozen_string_literal: true

class CropsController < ApplicationController
  before_action :set_crop, only: [:show, :edit, :update, :destroy]

  # GET /crops
  def index
    # 管理者は参照作物も表示、一般ユーザーは自分の作物のみ
    if admin_user?
      @crops = Crop.where("is_reference = ? OR user_id = ?", true, current_user.id).recent
    else
      @crops = Crop.where(user_id: current_user.id).recent
    end
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
    @crop.crop_stages.each do |stage|
      stage.build_nutrient_requirement unless stage.nutrient_requirement
    end
  end

  # POST /crops
  def create
    is_reference = crop_params[:is_reference] || false
    if is_reference && !admin_user?
      return redirect_to crops_path, alert: I18n.t('crops.flash.reference_only_admin')
    end

    @crop = Crop.new(crop_params)
    @crop.user_id = nil if is_reference
    @crop.user_id ||= current_user.id

    # groupsをカンマ区切りテキストから配列に変換
    if params.dig(:crop, :groups).is_a?(String)
      @crop.groups = params[:crop][:groups].split(',').map(&:strip).reject(&:blank?)
    end

    if @crop.save
      redirect_to crop_path(@crop), notice: I18n.t('crops.flash.created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /crops/:id
  def update
    if crop_params.key?(:is_reference) && !admin_user?
      return redirect_to crop_path(@crop), alert: I18n.t('crops.flash.reference_flag_admin_only')
    end

    # groupsをカンマ区切りテキストから配列に変換
    if params.dig(:crop, :groups).is_a?(String)
      @crop.groups = params[:crop][:groups].split(',').map(&:strip).reject(&:blank?)
    end

    if @crop.update(crop_params)
      redirect_to crop_path(@crop), notice: I18n.t('crops.flash.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /crops/:id
  def destroy
    begin
      @crop.destroy
      redirect_to crops_path, notice: I18n.t('crops.flash.destroyed')
    rescue ActiveRecord::InvalidForeignKey => e
      # 外部参照制約エラーの場合
      if e.message.include?('cultivation_plan_crops')
        redirect_to crops_path, alert: I18n.t('crops.flash.cannot_delete_in_use.plan')
      elsif e.message.include?('field_cultivations')
        redirect_to crops_path, alert: I18n.t('crops.flash.cannot_delete_in_use.field')
      else
        redirect_to crops_path, alert: I18n.t('crops.flash.cannot_delete_in_use.other')
      end
    rescue ActiveRecord::DeleteRestrictionError => e
      redirect_to crops_path, alert: I18n.t('crops.flash.cannot_delete_in_use.other')
    rescue StandardError => e
      redirect_to crops_path, alert: I18n.t('crops.flash.delete_error', message: e.message)
    end
  end

  private

  def set_crop
    @crop = Crop.includes(
      crop_stages: [:temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement]
    ).find(params[:id])
    
    # アクションに応じた権限チェック
    action = params[:action].to_sym
    
    if action.in?([:edit, :update, :destroy])
      # 編集・更新・削除は以下の場合のみ許可
      # - 管理者（すべての作物を編集可能）
      # - ユーザー作物の所有者
      unless admin_user? || (!@crop.is_reference && @crop.user_id == current_user.id)
        redirect_to crops_path, alert: I18n.t('crops.flash.no_permission')
      end
    elsif action == :show
      # 詳細表示は以下の場合に許可
      # - 参照作物（誰でも閲覧可能）
      # - 自分の作物
      # - 管理者
      unless @crop.is_reference || @crop.user_id == current_user.id || admin_user?
        redirect_to crops_path, alert: I18n.t('crops.flash.no_permission')
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to crops_path, alert: I18n.t('crops.flash.not_found')
  end

  def crop_params
    params.require(:crop).permit(
      :name, 
      :variety, 
      :is_reference,
      :area_per_unit,
      :revenue_per_area,
      :groups,
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
          :max_temperature,
          :_destroy
        ],
        thermal_requirement_attributes: [
          :id,
          :required_gdd,
          :_destroy
        ],
        sunshine_requirement_attributes: [
          :id,
          :minimum_sunshine_hours,
          :target_sunshine_hours,
          :_destroy
        ],
        nutrient_requirement_attributes: [
          :id,
          :daily_uptake_n,
          :daily_uptake_p,
          :daily_uptake_k,
          :_destroy
        ]
      ]
    )
  end
end


