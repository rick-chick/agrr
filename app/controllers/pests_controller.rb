# frozen_string_literal: true

class PestsController < ApplicationController
  before_action :set_pest, only: [:show, :edit, :update, :destroy]

  # GET /pests
  def index
    # 管理者は参照害虫も表示、一般ユーザーは参照害虫のみ表示
    if admin_user?
      @pests = Pest.recent
    else
      @pests = Pest.reference.recent
    end
  end

  # GET /pests/:id
  def show
  end

  # GET /pests/new
  def new
    @pest = Pest.new
    @pest.build_pest_temperature_profile
    @pest.build_pest_thermal_requirement
    @pest.pest_control_methods.build
  end

  # GET /pests/:id/edit
  def edit
    @pest.pest_control_methods.build if @pest.pest_control_methods.empty?
  end

  # POST /pests
  def create
    # is_referenceをbooleanに変換（"0", "false", ""はfalseとして扱う）
    is_reference = ActiveModel::Type::Boolean.new.cast(pest_params[:is_reference]) || false
    if is_reference && !admin_user?
      return redirect_to pests_path, alert: I18n.t('pests.flash.reference_only_admin')
    end

    @pest = Pest.new(pest_params)

    if @pest.save
      redirect_to pest_path(@pest), notice: I18n.t('pests.flash.created')
    else
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
      redirect_to pest_path(@pest), notice: I18n.t('pests.flash.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /pests/:id
  def destroy
    begin
      @pest.destroy
      redirect_to pests_path, notice: I18n.t('pests.flash.destroyed')
    rescue ActiveRecord::InvalidForeignKey => e
      # 外部参照制約エラーの場合
      redirect_to pests_path, alert: I18n.t('pests.flash.cannot_delete_in_use')
    rescue ActiveRecord::DeleteRestrictionError => e
      redirect_to pests_path, alert: I18n.t('pests.flash.cannot_delete_in_use')
    rescue StandardError => e
      redirect_to pests_path, alert: I18n.t('pests.flash.delete_error', message: e.message)
    end
  end

  private

  def set_pest
    @pest = Pest.find(params[:id])
    
    # アクションに応じた権限チェック
    action = params[:action].to_sym
    
    if action.in?([:edit, :update, :destroy])
      # 編集・更新・削除は以下の場合のみ許可
      # - 管理者（すべての害虫を編集可能）
      # - 参照害虫でない場合（一般ユーザーが作成した害虫）
      unless admin_user? || !@pest.is_reference
        redirect_to pests_path, alert: I18n.t('pests.flash.no_permission')
      end
    elsif action == :show
      # 詳細表示は以下の場合に許可
      # - 参照害虫（誰でも閲覧可能）
      # - 管理者
      unless @pest.is_reference || admin_user?
        redirect_to pests_path, alert: I18n.t('pests.flash.no_permission')
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to pests_path, alert: I18n.t('pests.flash.not_found')
  end

  def pest_params
    params.require(:pest).permit(
      :pest_id,
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
end

