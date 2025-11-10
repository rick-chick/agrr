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
      redirect_to url_for(controller: 'fields', action: 'show', farm_id: @farm.id, id: @field.id), notice: I18n.t('fields.flash.created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /farms/:farm_id/fields/:id
  def update
    if @field.update(field_params)
      redirect_to url_for(controller: 'fields', action: 'show', farm_id: @farm.id, id: @field.id), notice: I18n.t('fields.flash.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /farms/:farm_id/fields/:id
  def destroy
    event = DeletionUndo::Manager.schedule(
      record: @field,
      actor: current_user,
      toast_message: I18n.t('fields.undo.toast', name: @field.display_name)
    )

    render_deletion_undo_response(
      event.reload,
      fallback_location: farm_fields_path(@farm)
    )
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
    render_deletion_failure(
      message: I18n.t('fields.flash.cannot_delete_in_use'),
      fallback_location: farm_fields_path(@farm)
    )
  rescue DeletionUndo::Error => e
    render_deletion_failure(
      message: I18n.t('fields.flash.delete_error', message: e.message),
      fallback_location: farm_fields_path(@farm)
    )
  rescue StandardError => e
    render_deletion_failure(
      message: I18n.t('fields.flash.delete_error', message: e.message),
      fallback_location: farm_fields_path(@farm)
    )
  end

  private

  def set_farm
    if admin_user?
      # Admin can access any farm
      @farm = Farm.find(params[:farm_id])
    else
      # Regular users can only access their own farms
      @farm = current_user.farms.find(params[:farm_id])
    end
  rescue ActiveRecord::RecordNotFound
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
