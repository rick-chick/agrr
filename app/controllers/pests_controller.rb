# frozen_string_literal: true

class PestsController < ApplicationController
  include DeletionUndoFlow
  include HtmlCrudResponder
  before_action :set_pest, only: [:show, :edit, :update, :destroy]

  # GET /pests
  def index
    # 管理者は参照害虫も表示、一般ユーザーは自分の非参照害虫のみ
    @pests = PestPolicy.visible_scope(current_user).recent
  end

  # GET /pests/:id
  def show
    @crops = @pest.crops.recent
  end

  # GET /pests/new
  def new
    @pest = Pest.new
    prepare_crop_selection_for(@pest, selected_ids: normalize_crop_ids_for(@pest, params[:crop_ids]))
    @pest.build_pest_temperature_profile
    @pest.build_pest_thermal_requirement
    @pest.pest_control_methods.build
  end

  # GET /pests/:id/edit
  def edit
    @pest.pest_control_methods.build if @pest.pest_control_methods.empty?
    prepare_crop_selection_for(@pest)
  end

  # POST /pests
  def create
    # is_referenceをbooleanに変換（"0", "false", ""はfalseとして扱う）
    is_reference = ActiveModel::Type::Boolean.new.cast(pest_params[:is_reference]) || false
    if is_reference && !admin_user?
      return redirect_to pests_path, alert: I18n.t('pests.flash.reference_only_admin')
    end

    @pest = PestPolicy.build_for_create(current_user, pest_params)
    crop_ids = normalize_crop_ids_for(@pest, params[:crop_ids])

    if @pest.save
      # 選択された作物との関連付けを処理
      associate_crops(@pest, crop_ids)
      respond_to_create(@pest, notice: I18n.t('pests.flash.created'), redirect_path: pest_path(@pest))
    else
      prepare_crop_selection_for(@pest, selected_ids: crop_ids)
      respond_to_create(@pest, notice: nil)
    end
  end

  # PATCH/PUT /pests/:id
  def update
    # is_referenceをbooleanに変換してチェック
    if pest_params.key?(:is_reference)
      is_reference = ActiveModel::Type::Boolean.new.cast(pest_params[:is_reference]) || false
      if is_reference != @pest.is_reference && !admin_user?
        return redirect_to pest_path(@pest), alert: I18n.t('pests.flash.reference_flag_admin_only')
      end
    end

    crop_ids = normalize_crop_ids_for(@pest, params[:crop_ids])

    update_result = PestPolicy.apply_update!(current_user, @pest, pest_params)
    if update_result
      # 選択された作物との関連付けを更新
      update_crop_associations(@pest, crop_ids)
      respond_to_update(@pest, notice: I18n.t('pests.flash.updated'), redirect_path: pest_path(@pest), update_result: update_result)
    else
      prepare_crop_selection_for(@pest, selected_ids: crop_ids)
      respond_to_update(@pest, notice: nil, update_result: update_result)
    end
  end

  # DELETE /pests/:id
  def destroy
    schedule_deletion_with_undo(
      record: @pest,
      toast_message: I18n.t('pests.undo.toast', name: @pest.name),
      fallback_location: pests_path,
      in_use_message_key: 'pests.flash.cannot_delete_in_use',
      delete_error_message_key: 'pests.flash.delete_error'
    )
  end

  private

  def set_pest
    action = params[:action].to_sym

    @pest =
      if action.in?([:edit, :update, :destroy])
        PestPolicy.find_editable!(current_user, params[:id])
      else
        PestPolicy.find_visible!(current_user, params[:id])
      end
  rescue PolicyPermissionDenied
    redirect_to pests_path, alert: I18n.t('pests.flash.no_permission')
  rescue ActiveRecord::RecordNotFound
    redirect_to pests_path, alert: I18n.t('pests.flash.not_found')
  end

  def pest_params
    permitted = [
      :name,
      :name_scientific,
      :family,
      :order,
      :description,
      :occurrence_season,
      :is_reference,
      pest_temperature_profile_attributes: [
        :id,
        :base_temperature,
        :max_temperature,
        :_destroy
      ],
      pest_thermal_requirement_attributes: [
        :id,
        :required_gdd,
        :first_generation_gdd,
        :_destroy
      ],
      pest_control_methods_attributes: [
        :id,
        :method_type,
        :method_name,
        :description,
        :timing_hint,
        :_destroy
      ]
    ]
    
    # 管理者のみregionを許可
    permitted << :region if admin_user?
    
    params.require(:pest).permit(*permitted)
  end

  # 害虫と作物を関連付ける（Service経由）
  def associate_crops(pest, crop_ids)
    PestCropAssociationService.associate_crops(pest, crop_ids, user: current_user)
  end

  # 害虫と作物の関連付けを更新（Service経由）
  def update_crop_associations(pest, crop_ids)
    PestCropAssociationService.update_crop_associations(pest, crop_ids, user: current_user)
  end

  def prepare_crop_selection_for(pest, selected_ids: nil)
    @accessible_crops = PestCropAssociationPolicy.accessible_crops_scope(pest, user: current_user).to_a
    allowed_ids = @accessible_crops.map(&:id)
    normalized_selected = Array(selected_ids || pest.crop_ids).map(&:to_i).uniq & allowed_ids

    @selected_crop_ids = normalized_selected
    @crop_cards = @accessible_crops.map do |crop|
      {
        crop: crop,
        selected: normalized_selected.include?(crop.id)
      }
    end
  end

  def normalize_crop_ids_for(pest, raw_ids)
    PestCropAssociationService.normalize_crop_ids(pest, raw_ids, user: current_user)
  end
end


