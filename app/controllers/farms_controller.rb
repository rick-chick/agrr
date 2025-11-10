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
      return render_deletion_failure(
        message: I18n.t('farms.flash.cannot_delete', count: @farm.free_crop_plans.count),
        fallback_location: farm_path(@farm)
      )
    end

    event = DeletionUndo::Manager.schedule(
      record: @farm,
      actor: current_user,
      toast_message: I18n.t('farms.undo.toast', name: @farm.display_name)
    )

    render_deletion_undo_response(
      event.reload,
      fallback_location: farms_path
    )
  rescue ActiveRecord::InvalidForeignKey => e
    message =
      if e.message.include?('cultivation_plans')
        I18n.t('farms.flash.cannot_delete_in_use.plan')
      elsif e.message.include?('fields')
        I18n.t('farms.flash.cannot_delete_in_use.field')
      else
        I18n.t('farms.flash.cannot_delete_in_use.other')
      end

    render_deletion_failure(
      message: message,
      fallback_location: farms_path
    )
  rescue ActiveRecord::DeleteRestrictionError
    render_deletion_failure(
      message: I18n.t('farms.flash.cannot_delete_in_use.other'),
      fallback_location: farms_path
    )
  rescue DeletionUndo::Error => e
    render_deletion_failure(
      message: I18n.t('farms.flash.delete_error', message: e.message),
      fallback_location: farms_path
    )
  rescue StandardError => e
    render_deletion_failure(
      message: I18n.t('farms.flash.delete_error', message: e.message),
      fallback_location: farms_path
    )
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

