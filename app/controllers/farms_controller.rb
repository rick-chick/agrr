# frozen_string_literal: true

class FarmsController < ApplicationController
  before_action :set_farm, only: [:show, :edit, :update, :destroy]

  # GET /farms
  def index
    @farms = current_user.farms.recent
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
      redirect_to @farm, notice: '農場が正常に作成されました。'
    else
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
    @farm = current_user.farms.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to farms_path, alert: '指定された農場が見つかりません。'
  end

  def farm_params
    params.require(:farm).permit(:name, :latitude, :longitude)
  end
end

