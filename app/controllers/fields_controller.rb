# frozen_string_literal: true

class FieldsController < ApplicationController
  include DeletionUndoFlow
  include HtmlCrudResponder
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
      redirect_path = url_for(controller: 'fields', action: 'show', farm_id: @farm.id, id: @field.id)
      respond_to_create(@field, notice: I18n.t('fields.flash.created'), redirect_path: redirect_path)
    else
      respond_to_create(@field, notice: nil)
    end
  end

  # PATCH/PUT /farms/:farm_id/fields/:id
  def update
    update_result = @field.update(field_params)
    redirect_path = url_for(controller: 'fields', action: 'show', farm_id: @farm.id, id: @field.id)
    if update_result
      respond_to_update(@field, notice: I18n.t('fields.flash.updated'), redirect_path: redirect_path, update_result: update_result)
    else
      respond_to_update(@field, notice: nil, redirect_path: redirect_path, update_result: update_result)
    end
  end

  # DELETE /farms/:farm_id/fields/:id
  def destroy
    schedule_deletion_with_undo(
      record: @field,
      toast_message: I18n.t('fields.undo.toast', name: @field.display_name),
      fallback_location: farm_fields_path(@farm),
      in_use_message_key: 'fields.flash.cannot_delete_in_use',
      delete_error_message_key: 'fields.flash.delete_error'
    )
  end

  private

  def set_farm
    if admin_user?
      # Admin can access any farm
      @farm = Farm.find(params[:farm_id])
    else
      # Regular users can only access their own farms
      @farm = FarmPolicy.find_owned!(current_user, params[:farm_id])
    end
  rescue PolicyPermissionDenied, ActiveRecord::RecordNotFound
    redirect_to farms_path, alert: I18n.t('fields.flash.farm_not_found')
  end

  def set_field
    @field = @farm.fields.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to url_for(controller: 'fields', action: 'index', farm_id: @farm.id), alert: I18n.t('fields.flash.not_found')
  end

  def field_params
    params.require(:field).permit(:name, :description, :area, :daily_fixed_cost)
  end
end
