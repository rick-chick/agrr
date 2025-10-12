# frozen_string_literal: true

class Admin::DefaultFarmController < ApplicationController
  before_action :authenticate_admin!
  layout 'admin'
  
  # GET /admin/default_farm
  def show
    @farm = Farm.default_farm || Farm.find_or_create_default_farm!
  end
  
  # GET /admin/default_farm/edit
  def edit
    @farm = Farm.default_farm || Farm.find_or_create_default_farm!
  end
  
  # PATCH/PUT /admin/default_farm
  def update
    @farm = Farm.default_farm
    
    unless @farm
      redirect_to admin_default_farm_path, alert: 'デフォルト農場が見つかりません。'
      return
    end
    
    if @farm.update(farm_params)
      redirect_to admin_default_farm_path, notice: 'デフォルト農場を更新しました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  private
  
  def farm_params
    params.require(:farm).permit(:name, :latitude, :longitude)
  end
end

