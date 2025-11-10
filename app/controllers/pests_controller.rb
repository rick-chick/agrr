# frozen_string_literal: true

class PestsController < ApplicationController
  before_action :set_pest, only: [:show, :edit, :update, :destroy]

  # GET /pests
  def index
    # 管理者は参照害虫と自身が作成した害虫のみ表示、一般ユーザーは自分が作成した害虫のみ表示
    if admin_user?
      @pests = Pest.where("is_reference = ? OR user_id = ?", true, current_user.id).recent
    else
      # 一般ユーザー: 自分の害虫のみ表示（参照害虫は表示しない）
      @pests = Pest.where(user_id: current_user.id).recent
    end
  end

  # GET /pests/:id
  def show
    @crops = @pest.crops.recent
  end

  # GET /pests/new
  def new
    @pest = Pest.new
    @pest.build_pest_temperature_profile
    @pest.build_pest_thermal_requirement
    @pest.pest_control_methods.build
    @available_crops = available_crops_for_user
  end

  # GET /pests/:id/edit
  def edit
    @pest.pest_control_methods.build if @pest.pest_control_methods.empty?
    @available_crops = available_crops_for_user
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

    if @pest.save
      # 選択された作物との関連付けを処理
      associate_crops(@pest, params[:crop_ids])
      redirect_to pest_path(@pest), notice: I18n.t('pests.flash.created')
    else
      @available_crops = available_crops_for_user
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

    if @pest.update(pest_params)
      # 選択された作物との関連付けを更新
      update_crop_associations(@pest, params[:crop_ids])
      redirect_to pest_path(@pest), notice: I18n.t('pests.flash.updated')
    else
      @available_crops = available_crops_for_user
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /pests/:id
  def destroy
    event = DeletionUndo::Manager.schedule(
      record: @pest,
      actor: current_user,
      toast_message: I18n.t('pests.undo.toast', name: @pest.name)
    )

    render_deletion_undo_response(event, fallback_location: pests_path)
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
    render_deletion_failure(
      message: I18n.t('pests.flash.cannot_delete_in_use'),
      fallback_location: pests_path
    )
  rescue DeletionUndo::Error => e
    render_deletion_failure(
      message: I18n.t('pests.flash.delete_error', message: e.message),
      fallback_location: pests_path
    )
  rescue StandardError => e
    render_deletion_failure(
      message: I18n.t('pests.flash.delete_error', message: e.message),
      fallback_location: pests_path
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
    params.require(:pest).permit(
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
    )
  end

  # ユーザーが利用可能な作物のリストを取得
  def available_crops_for_user
    if admin_user?
      Crop.where("is_reference = ? OR user_id = ?", true, current_user.id).recent
    else
      Crop.where(user_id: current_user.id).recent
    end
  end

  # 害虫と作物を関連付ける
  def associate_crops(pest, crop_ids)
    return unless crop_ids.present?
    
    # 配列に変換（文字列または配列の両方に対応）
    ids = Array(crop_ids).compact.reject(&:blank?).map(&:to_i)
    
    ids.each do |crop_id|
      crop = Crop.find_by(id: crop_id)
      next unless crop
      
      # 権限チェック：作物へのアクセス権があるか確認
      can_access = if crop.is_reference
        true # 参照作物は誰でもアクセス可能
      else
        crop.user_id == current_user.id || admin_user?
      end
      
      if can_access && !pest.crops.include?(crop)
        pest.crops << crop
      end
    end
  end

  # 害虫と作物の関連付けを更新
  def update_crop_associations(pest, crop_ids)
    return unless crop_ids.present?
    
    # 配列に変換（文字列または配列の両方に対応）
    new_ids = Array(crop_ids).compact.reject(&:blank?).map(&:to_i).uniq
    
    # 現在の関連付けを取得
    current_ids = pest.crop_ids
    
    # 削除すべき関連付け（現在あるが選択されていない）
    to_remove = current_ids - new_ids
    to_remove.each do |crop_id|
      crop = Crop.find_by(id: crop_id)
      next unless crop
      
      # 権限チェック：作物へのアクセス権があるか確認
      can_access = if crop.is_reference
        true # 参照作物は誰でもアクセス可能
      else
        crop.user_id == current_user.id || admin_user?
      end
      
      pest.crops.delete(crop) if can_access
    end
    
    # 追加すべき関連付け（選択されているが現在ない）
    to_add = new_ids - current_ids
    associate_crops(pest, to_add)
  end
end

