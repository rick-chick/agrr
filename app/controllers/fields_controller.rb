# frozen_string_literal: true

class FieldsController < ApplicationController
  before_action :set_field, only: [:show, :edit, :update, :destroy]

  # GET /fields
  def index
    @fields = current_user.fields.recent
  end

  # GET /fields/:id
  def show
    # Field is already loaded by set_field
  end

  # GET /fields/new
  def new
    @field = current_user.fields.build
  end

  # GET /fields/:id/edit
  def edit
    # Field is already loaded by set_field
  end

  # POST /fields
  def create
    @field = current_user.fields.build(field_params)

    if @field.save
      redirect_to @field, notice: '圃場が正常に作成されました。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /fields/:id
  def update
    if @field.update(field_params)
      redirect_to @field, notice: '圃場が正常に更新されました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /fields/:id
  def destroy
    @field.destroy
    redirect_to fields_path, notice: '圃場が削除されました。'
  end

  private

  def set_field
    @field = current_user.fields.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to fields_path, alert: '指定された圃場が見つかりません。'
  end

  def field_params
    params.require(:field).permit(:name, :latitude, :longitude)
  end
end
