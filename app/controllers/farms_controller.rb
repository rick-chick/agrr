# frozen_string_literal: true

class FarmsController < ApplicationController
  before_action :set_farm, only: [:show, :edit, :update, :destroy]

  # GET /farms
  def index
    if admin_user?
      # 管理者は自分の農場とデフォルト農場の両方を表示
      @farms = current_user.farms.recent
      @default_farms = Farm.default_farms
    else
      # 通常ユーザーは自分の農場のみ
      @farms = current_user.farms.recent
      @default_farms = []
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
    @farm = current_user.farms.build(farm_params)

    if @farm.save
      Rails.logger.info "🎉 Farm created: ##{@farm.id} '#{@farm.name}' by user ##{current_user.id}"
      redirect_to @farm, notice: '農場が正常に作成されました。'
    else
      Rails.logger.warn "⚠️  Failed to create farm: #{@farm.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /farms/:id
  def update
    if @farm.update(farm_params)
      redirect_to @farm, notice: '農場が正常に更新されました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /farms/:id
  def destroy
    @farm.destroy
    redirect_to farms_path, notice: '農場が削除されました。'
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
    redirect_to farms_path, alert: '指定された農場が見つかりません。'
  end

  def farm_params
    params.require(:farm).permit(:name, :latitude, :longitude)
  end
end

