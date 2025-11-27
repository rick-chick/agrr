# frozen_string_literal: true

class FertilizesController < ApplicationController
  include DeletionUndoFlow
  include HtmlCrudResponder
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

    @fertilize = FertilizePolicy.build_for_create(current_user, fertilize_params)

    if @fertilize.save
      respond_to_create(@fertilize, notice: I18n.t('fertilizes.flash.created'), redirect_path: fertilize_path(@fertilize))
    else
      respond_to_create(@fertilize, notice: nil)
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

    update_result = FertilizePolicy.apply_update!(current_user, @fertilize, fertilize_params)
    if update_result
      respond_to_update(@fertilize, notice: I18n.t('fertilizes.flash.updated'), redirect_path: fertilize_path(@fertilize), update_result: update_result)
    else
      respond_to_update(@fertilize, notice: nil, update_result: update_result)
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
    @fertilize = FertilizePolicy.find_visible!(current_user, params[:id])
  rescue PolicyPermissionDenied
    redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.no_permission')
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

