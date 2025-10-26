# frozen_string_literal: true

class FarmsController < ApplicationController
  before_action :set_farm, only: [:show, :edit, :update, :destroy]

  # GET /farms
  def index
    if admin_user?
      # 管理者は自分の農場と参照農場の両方を表示
      @farms = current_user.farms.recent
      @reference_farms = Farm.reference
    else
      # 通常ユーザーは自分の農場のみ
      @farms = current_user.farms.recent
      @reference_farms = []
    end
  end

  # GET /farms/:id
  def show
    @fields = @farm.fields.recent
  end

  # GET /farms/new
  def new
    @farm = current_user.farms.build
  end

  # GET /farms/:id/edit
  def edit
    # Farm is already loaded by set_farm
  end

  # POST /farms
  def create
    # 農場数の上限チェック
    unless validate_farm_count
      @farm = current_user.farms.build(farm_params)
      @farm.errors.add(:base, I18n.t('farms.flash.farm_limit'))
      Rails.logger.warn "⚠️  Farm limit reached for user ##{current_user.id}"
      render :new, status: :unprocessable_entity
      return
    end

    @farm = current_user.farms.build(farm_params)

    if @farm.save
      Rails.logger.info "🎉 Farm created: ##{@farm.id} '#{@farm.name}' by user ##{current_user.id}"
      redirect_to @farm, notice: I18n.t('farms.flash.created')
    else
      Rails.logger.warn "⚠️  Failed to create farm: #{@farm.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /farms/:id
  def update
    if @farm.update(farm_params)
      redirect_to @farm, notice: I18n.t('farms.flash.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /farms/:id
  def destroy
    if @farm.free_crop_plans.any?
      redirect_to @farm, alert: I18n.t('farms.flash.cannot_delete', count: @farm.free_crop_plans.count)
      return
    end
    
    @farm.destroy
    redirect_to farms_path, notice: I18n.t('farms.flash.destroyed')
  end

  private

  def set_farm
    if admin_user?
      # Admin can access any farm
      @farm = Farm.find(params[:id])
    else
      # Regular users can only access their own farms
      @farm = current_user.farms.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to farms_path, alert: I18n.t('farms.flash.not_found')
  end

  def farm_params
    params.require(:farm).permit(:name, :latitude, :longitude)
  end
end

