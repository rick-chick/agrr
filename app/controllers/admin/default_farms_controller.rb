# frozen_string_literal: true

class Admin::DefaultFarmsController < ApplicationController
  before_action :authenticate_admin!
  layout 'admin'
  
  # GET /admin/default_farms
  def index
    # アノニマスユーザーの全農場を表示（N+1クエリ対策でuserをeager load）
    @anonymous_user = User.anonymous_user
    @farms = Farm.by_user(@anonymous_user).includes(:user).order(:name)
    @default_farms = @farms.where(is_default: true)
    @other_farms = @farms.where(is_default: false)
  end
  
  # GET /admin/default_farms/:id
  def show
    @farm = Farm.find(params[:id])
  end
  
  # GET /admin/default_farms/:id/edit
  def edit
    @farm = Farm.find(params[:id])
  end
  
  # PATCH/PUT /admin/default_farms/:id
  def update
    @farm = Farm.find(params[:id])
    
    if @farm.update(farm_params)
      redirect_to admin_default_farm_path(@farm), notice: '農場を更新しました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  # DELETE /admin/default_farms/:id
  def destroy
    @farm = Farm.find(params[:id])
    
    if @farm.destroy
      redirect_to admin_default_farms_path, notice: '農場を削除しました。'
    else
      redirect_to admin_default_farm_path(@farm), alert: '農場を削除できませんでした。'
    end
  end
  
  private
  
  def farm_params
    params.require(:farm).permit(:name, :latitude, :longitude)
  end
end

