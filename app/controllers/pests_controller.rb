# frozen_string_literal: true

class PestsController < ApplicationController
  include DeletionUndoFlow
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

    # pest_paramsを取得して、user_idを追加
    pest_attributes = pest_params.to_h
    # 一般ユーザーが作成する場合は、is_referenceをfalseに強制設定し、user_idを設定
    unless admin_user?
      pest_attributes[:is_reference] = false
      pest_attributes[:user_id] = current_user.id
    else
      # 管理者が作成する場合も、参照害虫の場合はuser_idをnilに、そうでない場合は管理者のIDを設定
      is_reference = ActiveModel::Type::Boolean.new.cast(pest_attributes[:is_reference]) || false
      if is_reference
        pest_attributes[:user_id] = nil
      else
        pest_attributes[:user_id] ||= current_user.id
      end
    end
    
    @pest = Pest.new(pest_attributes)
    crop_ids = normalize_crop_ids_for(@pest, params[:crop_ids])

    if @pest.save
      # 選択された作物との関連付けを処理
      associate_crops(@pest, crop_ids)
      redirect_to pest_path(@pest), notice: I18n.t('pests.flash.created')
    else
      prepare_crop_selection_for(@pest, selected_ids: crop_ids)
      render :new, status: :unprocessable_entity
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

    if @pest.update(pest_params)
      # 選択された作物との関連付けを更新
      update_crop_associations(@pest, crop_ids)
      redirect_to pest_path(@pest), notice: I18n.t('pests.flash.updated')
    else
      prepare_crop_selection_for(@pest, selected_ids: crop_ids)
      render :edit, status: :unprocessable_entity
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
    @pest = Pest.find(params[:id])
    
    # アクションに応じた権限チェック
    action = params[:action].to_sym
    
    # アクセス権限チェック: 参照害虫または自分の害虫のみアクセス可能
    # 管理者も他人のユーザー害虫にはアクセスできない
    unless @pest.is_reference || @pest.user_id == current_user.id
      redirect_to pests_path, alert: I18n.t('pests.flash.no_permission')
    end
    
    # 編集・更新・削除は参照害虫の場合、管理者のみ許可
    if action.in?([:edit, :update, :destroy]) && @pest.is_reference && !admin_user?
      redirect_to pests_path, alert: I18n.t('pests.flash.no_permission')
    end
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

  # 害虫と作物を関連付ける
  def associate_crops(pest, crop_ids)
    Array(crop_ids).each do |crop_id|
      crop = Crop.find_by(id: crop_id)
      next unless crop && crop_accessible_for_pest?(crop, pest)
      pest.crops << crop unless pest.crops.include?(crop)
    end
  end

  # 害虫と作物の関連付けを更新
  def update_crop_associations(pest, crop_ids)
    new_ids = Array(crop_ids).map(&:to_i).uniq

    # 現在の関連付けを取得
    current_ids = pest.crop_ids
    
    # 削除すべき関連付け（現在あるが選択されていない）
    to_remove = current_ids - new_ids
    to_remove.each do |crop_id|
      crop = Crop.find_by(id: crop_id)
      next unless crop

      pest.crops.delete(crop)
    end
    
    # 追加すべき関連付け（選択されているが現在ない）
    to_add = new_ids - current_ids
    associate_crops(pest, to_add)
  end

  def prepare_crop_selection_for(pest, selected_ids: nil)
    @accessible_crops = accessible_crops_for_selection(pest).to_a
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
    allowed_ids = accessible_crops_for_selection(pest).pluck(:id)
    Array(raw_ids).compact.reject(&:blank?).map(&:to_i).uniq & allowed_ids
  end

  def accessible_crops_for_selection(pest)
    scope =
      if pest.is_reference?
        Crop.where(is_reference: true)
      else
        owner_id = pest.user_id || current_user.id
        Crop.where(is_reference: false, user_id: owner_id)
      end

    if pest.region.present?
      scope = scope.where(region: pest.region)
    end

    scope.order(:name)
  end

  def crop_accessible_for_pest?(crop, pest)
    # 地域チェック（害虫に地域が設定されている場合）
    if pest.region.present?
      return false if crop.region != pest.region
    end

    # 参照害虫は参照作物のみに関連付け可能
    if pest.is_reference?
      return crop.is_reference?
    end
    
    # ユーザー所有の害虫は、自分の作物のみに関連付け可能
    owner_id = pest.user_id || current_user.id
    crop.user_id == owner_id && !crop.is_reference?
  end
end


