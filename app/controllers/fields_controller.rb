# frozen_string_literal: true

class FieldsController < ApplicationController
  before_action :set_farm
  before_action :set_field, only: [:show, :edit, :update, :destroy]

  # GET /farms/:farm_id/fields
  def index
    @fields = @farm.fields.recent
  end

  # GET /fields/:id
  def show
    # Field is already loaded by set_field
  end

  # GET /farms/:farm_id/fields/new
  def new
    @field = @farm.fields.build
  end

  # GET /farms/:farm_id/fields/:id/edit
  def edit
    # Field is already loaded by set_field
  end

  # POST /farms/:farm_id/fields
  def create
    @field = @farm.fields.build(field_params)
    @field.user = current_user

    if @field.save
      redirect_to farm_field_path(@farm, @field), notice: '圃場が正常に作成されました。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /farms/:farm_id/fields/:id
  def update
    if @field.update(field_params)
      redirect_to farm_field_path(@farm, @field), notice: '圃場が正常に更新されました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /farms/:farm_id/fields/:id
  def destroy
    @field.destroy
    redirect_to farm_fields_path(@farm), notice: '圃場が削除されました。'
  end

  private

  def set_farm
    @farm = current_user.farms.find(params[:farm_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to farms_path, alert: '指定された農場が見つかりません。'
  end

  def set_field
    @field = @farm.fields.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to farm_fields_path(@farm), alert: '指定された圃場が見つかりません。'
  end

  def field_params
    params.require(:field).permit(:name, :latitude, :longitude, :description)
  end
end
