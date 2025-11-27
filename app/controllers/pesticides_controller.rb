# frozen_string_literal: true

class PesticidesController < ApplicationController
  include DeletionUndoFlow
  include HtmlCrudResponder
  before_action :set_pesticide, only: [:show, :edit, :update, :destroy]

  # GET /pesticides
  def index
    # 管理者は参照農薬も表示、一般ユーザーは自分の非参照農薬のみ
    @pesticides = PesticidePolicy.visible_scope(current_user).recent
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

    @pesticide = PesticidePolicy.build_for_create(current_user, pesticide_params)

    if @pesticide.save
      respond_to_create(@pesticide, notice: I18n.t('pesticides.flash.created'), redirect_path: pesticide_path(@pesticide))
    else
      load_crops_and_pests
      respond_to_create(@pesticide, notice: nil)
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

    update_result = PesticidePolicy.apply_update!(current_user, @pesticide, pesticide_params)
    if update_result
      respond_to_update(@pesticide, notice: I18n.t('pesticides.flash.updated'), redirect_path: pesticide_path(@pesticide), update_result: update_result)
    else
      load_crops_and_pests
      respond_to_update(@pesticide, notice: nil, update_result: update_result)
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
    @pesticide = PesticidePolicy.find_visible!(current_user, params[:id])
  rescue PolicyPermissionDenied
    redirect_to pesticides_path, alert: I18n.t('pesticides.flash.not_found')
  rescue ActiveRecord::RecordNotFound
    redirect_to pesticides_path, alert: I18n.t('pesticides.flash.not_found')
  end

  def load_crops_and_pests
    # 作物の選択範囲を決定（Policy経由）
    @crops = PesticideAssociationPolicy.accessible_crops_scope(current_user)
    
    # 害虫の選択範囲を決定（Policy経由）
    @pests = PesticideAssociationPolicy.accessible_pests_scope(current_user)
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

