# frozen_string_literal: true

class PesticidesController < ApplicationController
  include DeletionUndoFlow
  before_action :set_pesticide, only: [:show, :edit, :update, :destroy]

  # GET /pesticides
  def index
    # 管理者は自身の農薬と参照農薬のみ表示、一般ユーザーは自分の農薬のみ表示
    if admin_user?
      @pesticides = Pesticide.where("is_reference = ? OR user_id = ?", true, current_user.id).recent
    else
      @pesticides = Pesticide.where(user_id: current_user.id, is_reference: false).recent
    end
  end

  # GET /pesticides/:id
  def show
  end

  # GET /pesticides/new
  def new
    @pesticide = Pesticide.new
    @pesticide.build_pesticide_usage_constraint
    @pesticide.build_pesticide_application_detail
    load_crops_and_pests
  end

  # GET /pesticides/:id/edit
  def edit
    @pesticide.build_pesticide_usage_constraint unless @pesticide.pesticide_usage_constraint
    @pesticide.build_pesticide_application_detail unless @pesticide.pesticide_application_detail
    load_crops_and_pests
  end

  # POST /pesticides
  def create
    # is_referenceをbooleanに変換（"0", "false", ""はfalseとして扱う）
    is_reference = ActiveModel::Type::Boolean.new.cast(pesticide_params[:is_reference]) || false
    if is_reference && !admin_user?
      return redirect_to pesticides_path, alert: I18n.t('pesticides.flash.reference_only_admin')
    end

    @pesticide = Pesticide.new(pesticide_params)
    @pesticide.user_id = nil if is_reference
    @pesticide.user_id ||= current_user.id

    if @pesticide.save
      redirect_to pesticide_path(@pesticide), notice: I18n.t('pesticides.flash.created')
    else
      load_crops_and_pests
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /pesticides/:id
  def update
    # is_referenceをbooleanに変換してチェック
    if pesticide_params.key?(:is_reference)
      is_reference = ActiveModel::Type::Boolean.new.cast(pesticide_params[:is_reference]) || false
      if is_reference != @pesticide.is_reference && !admin_user?
        return redirect_to pesticide_path(@pesticide), alert: I18n.t('pesticides.flash.reference_flag_admin_only')
      end
    end

    if @pesticide.update(pesticide_params)
      redirect_to pesticide_path(@pesticide), notice: I18n.t('pesticides.flash.updated')
    else
      load_crops_and_pests
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /pesticides/:id
  def destroy
    schedule_deletion_with_undo(
      record: @pesticide,
      toast_message: I18n.t('pesticides.undo.toast', name: @pesticide.name),
      fallback_location: pesticides_path,
      in_use_message_key: 'pesticides.flash.cannot_delete_in_use',
      delete_error_message_key: 'pesticides.flash.delete_error'
    )
  end

  private

  def set_pesticide
    # 管理者は自身の農薬と参照農薬のみアクセス可能、一般ユーザーは自分の農薬のみアクセス可能
    if admin_user?
      @pesticide = Pesticide.where("is_reference = ? OR user_id = ?", true, current_user.id).find(params[:id])
    else
      @pesticide = Pesticide.where(user_id: current_user.id, is_reference: false).find(params[:id])
    end
    
    # アクションに応じた権限チェック
    action = params[:action].to_sym
    
    if action.in?([:edit, :update, :destroy])
      # 編集・更新・削除は以下の場合のみ許可
      # - 管理者（参照農薬または自身の農薬を編集可能）
      # - 参照農薬でない場合、かつ所有者である場合（一般ユーザーが作成した農薬）
      unless admin_user? || (!@pesticide.is_reference && @pesticide.user_id == current_user.id)
        redirect_to pesticides_path, alert: I18n.t('pesticides.flash.no_permission')
      end
    elsif action == :show
      # 詳細表示は以下の場合に許可
      # - 管理者（参照農薬または自身の農薬を閲覧可能）
      # - 自分の農薬（一般ユーザー）
      unless admin_user? || (@pesticide.user_id == current_user.id && !@pesticide.is_reference)
        redirect_to pesticides_path, alert: I18n.t('pesticides.flash.no_permission')
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to pesticides_path, alert: I18n.t('pesticides.flash.not_found')
  end

  def load_crops_and_pests
    # 作物の選択範囲を決定
    if admin_user?
      # 管理ユーザー: 自身の作物と参照作物のみ選択可能
      @crops = Crop.where("is_reference = ? OR user_id = ?", true, current_user.id).order(:name)
    else
      # 一般ユーザー: 自身の作物のみ選択可能
      @crops = Crop.where(user_id: current_user.id, is_reference: false).order(:name)
    end
    
    # 害虫の選択範囲を決定
    if admin_user?
      # 管理ユーザー: 自身の害虫と参照害虫のみ選択可能
      @pests = Pest.where("is_reference = ? OR user_id = ?", true, current_user.id).order(:name)
    else
      # 一般ユーザー: 自身の害虫のみ選択可能
      @pests = Pest.where(user_id: current_user.id, is_reference: false).order(:name)
    end
  end

  def pesticide_params
    permitted = [
      :name,
      :active_ingredient,
      :description,
      :crop_id,
      :pest_id,
      :is_reference,
      pesticide_usage_constraint_attributes: [
        :id,
        :min_temperature,
        :max_temperature,
        :max_wind_speed_m_s,
        :max_application_count,
        :harvest_interval_days,
        :other_constraints,
        :_destroy
      ],
      pesticide_application_detail_attributes: [
        :id,
        :dilution_ratio,
        :amount_per_m2,
        :amount_unit,
        :application_method,
        :_destroy
      ]
    ]
    
    # 管理者のみregionを許可
    permitted << :region if admin_user?
    
    params.require(:pesticide).permit(*permitted)
  end
end

