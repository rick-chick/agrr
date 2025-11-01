# frozen_string_literal: true

class FertilizesController < ApplicationController
  before_action :set_fertilize, only: [:show, :edit, :update, :destroy]

  # GET /fertilizes
  def index
    # 管理者は参照肥料も表示、一般ユーザーは参照肥料のみ表示
    if admin_user?
      @fertilizes = Fertilize.recent
    else
      @fertilizes = Fertilize.reference.recent
    end
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
    is_reference = fertilize_params[:is_reference] || false
    if is_reference && !admin_user?
      return redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.reference_only_admin')
    end

    @fertilize = Fertilize.new(fertilize_params)

    if @fertilize.save
      redirect_to fertilize_path(@fertilize), notice: I18n.t('fertilizes.flash.created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /fertilizes/:id
  def update
    if fertilize_params.key?(:is_reference) && !admin_user?
      return redirect_to fertilize_path(@fertilize), alert: I18n.t('fertilizes.flash.reference_flag_admin_only')
    end

    if @fertilize.update(fertilize_params)
      redirect_to fertilize_path(@fertilize), notice: I18n.t('fertilizes.flash.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /fertilizes/:id
  def destroy
    begin
      @fertilize.destroy
      redirect_to fertilizes_path, notice: I18n.t('fertilizes.flash.destroyed')
    rescue ActiveRecord::InvalidForeignKey => e
      # 外部参照制約エラーの場合
      redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.cannot_delete_in_use')
    rescue ActiveRecord::DeleteRestrictionError => e
      redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.cannot_delete_in_use')
    rescue StandardError => e
      redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.delete_error', message: e.message)
    end
  end

  private

  def set_fertilize
    @fertilize = Fertilize.find(params[:id])
    
    # アクションに応じた権限チェック
    action = params[:action].to_sym
    
    if action.in?([:edit, :update, :destroy])
      # 編集・更新・削除は以下の場合のみ許可
      # - 管理者（すべての肥料を編集可能）
      # - 参照肥料でない場合（一般ユーザーが作成した肥料）
      unless admin_user? || !@fertilize.is_reference
        redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.no_permission')
      end
    elsif action == :show
      # 詳細表示は以下の場合に許可
      # - 参照肥料（誰でも閲覧可能）
      # - 管理者
      unless @fertilize.is_reference || admin_user?
        redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.no_permission')
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.not_found')
  end

  def fertilize_params
    params.require(:fertilize).permit(
      :name,
      :n,
      :p,
      :k,
      :description,
      :usage,
      :application_rate,
      :is_reference
    )
  end
end

