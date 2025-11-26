# frozen_string_literal: true

class FertilizesController < ApplicationController
  include DeletionUndoFlow
  before_action :set_fertilize, only: [:show, :edit, :update, :destroy]

  # GET /fertilizes
  def index
    # 管理者は参照肥料も表示、一般ユーザーは自分の非参照肥料のみ
    @fertilizes = FertilizePolicy.visible_scope(current_user).recent
  end

  # GET /fertilizes/:id
  def show
  end

  # GET /fertilizes/new
  def new
    @fertilize = Fertilize.new
  end

  # GET /fertilizes/:id/edit
  def edit
  end

  # POST /fertilizes
  def create
    # is_referenceをbooleanに変換（"0", "false", ""はfalseとして扱う）
    is_reference = ActiveModel::Type::Boolean.new.cast(fertilize_params[:is_reference]) || false
    if is_reference && !admin_user?
      return redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.reference_only_admin')
    end

    @fertilize = Fertilize.new(fertilize_params)
    if is_reference
      @fertilize.user_id = nil
      @fertilize.is_reference = true
    else
      @fertilize.user_id = current_user.id
      @fertilize.is_reference = false
    end

    if @fertilize.save
      redirect_to fertilize_path(@fertilize), notice: I18n.t('fertilizes.flash.created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /fertilizes/:id
  def update
    # is_referenceをbooleanに変換してチェック
    if fertilize_params.key?(:is_reference)
      is_reference = ActiveModel::Type::Boolean.new.cast(fertilize_params[:is_reference]) || false
      if is_reference != @fertilize.is_reference && !admin_user?
        return redirect_to fertilize_path(@fertilize), alert: I18n.t('fertilizes.flash.reference_flag_admin_only')
      end
    end

    if @fertilize.update(fertilize_params)
      redirect_to fertilize_path(@fertilize), notice: I18n.t('fertilizes.flash.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /fertilizes/:id
  def destroy
    schedule_deletion_with_undo(
      record: @fertilize,
      toast_message: I18n.t('fertilizes.undo.toast', name: @fertilize.name),
      fallback_location: fertilizes_path,
      in_use_message_key: 'fertilizes.flash.cannot_delete_in_use',
      delete_error_message_key: 'fertilizes.flash.delete_error'
    )
  end

  private

  def set_fertilize
    # 管理者は自身の肥料と参照肥料のみアクセス可能、一般ユーザーは自分の肥料のみアクセス可能
    if admin_user?
      @fertilize = Fertilize.where("is_reference = ? OR user_id = ?", true, current_user.id).find(params[:id])
    else
      @fertilize = Fertilize.where(user_id: current_user.id, is_reference: false).find(params[:id])
    end
    
    # アクションに応じた権限チェック
    action = params[:action].to_sym
    
    if action.in?([:edit, :update, :destroy])
      # 編集・更新・削除は以下の場合のみ許可
      # - 管理者（参照肥料または自身の肥料を編集可能）
      # - 参照肥料でない場合、かつ所有者である場合（一般ユーザーが作成した肥料）
      unless admin_user? || (!@fertilize.is_reference && @fertilize.user_id == current_user.id)
        redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.no_permission')
      end
    elsif action == :show
      # 詳細表示は以下の場合に許可
      # - 管理者（参照肥料または自身の肥料を閲覧可能）
      # - 自分の肥料（一般ユーザー）
      unless admin_user? || (@fertilize.user_id == current_user.id && !@fertilize.is_reference)
        redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.no_permission')
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.not_found')
  end

  def fertilize_params
    permitted = [
      :name,
      :n,
      :p,
      :k,
      :description,
      :package_size,
      :is_reference
    ]
    
    # 管理者のみregionを許可
    permitted << :region if admin_user?
    
    params.require(:fertilize).permit(*permitted)
  end
end

