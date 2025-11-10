# frozen_string_literal: true

class AgriculturalTasksController < ApplicationController
  before_action :set_agricultural_task, only: [:show, :edit, :update, :destroy]

  # GET /agricultural_tasks
  def index
    if admin_user?
      @agricultural_tasks = AgriculturalTask.where("is_reference = ? OR user_id = ?", true, current_user.id).recent
    else
      @agricultural_tasks = AgriculturalTask.where(user_id: current_user.id, is_reference: false).recent
    end
  end

  # GET /agricultural_tasks/:id
  def show
  end

  # GET /agricultural_tasks/new
  def new
    @agricultural_task = AgriculturalTask.new
  end

  # GET /agricultural_tasks/:id/edit
  def edit
  end

  # POST /agricultural_tasks
  def create
    task_attributes = build_task_attributes

    is_reference = ActiveModel::Type::Boolean.new.cast(task_attributes[:is_reference]) || false
    if is_reference && !admin_user?
      return redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.reference_only_admin')
    end

    @agricultural_task = AgriculturalTask.new(task_attributes.except(:is_reference))

    if is_reference
      @agricultural_task.is_reference = true
      @agricultural_task.user_id = nil
    else
      @agricultural_task.is_reference = false
      @agricultural_task.user_id = current_user.id
    end

    if @agricultural_task.save
      redirect_to agricultural_task_path(@agricultural_task), notice: I18n.t('agricultural_tasks.flash.created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /agricultural_tasks/:id
  def update
    task_attributes = build_task_attributes

    if task_attributes.key?(:is_reference)
      requested_reference = ActiveModel::Type::Boolean.new.cast(task_attributes[:is_reference]) || false
      if requested_reference != @agricultural_task.is_reference && !admin_user?
        return redirect_to agricultural_task_path(@agricultural_task), alert: I18n.t('agricultural_tasks.flash.reference_flag_admin_only')
      end
    end

    if @agricultural_task.update(task_attributes.except(:is_reference))
      redirect_to agricultural_task_path(@agricultural_task), notice: I18n.t('agricultural_tasks.flash.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /agricultural_tasks/:id
  def destroy
    event = DeletionUndo::Manager.schedule(
      record: @agricultural_task,
      actor: current_user,
      toast_message: I18n.t('agricultural_tasks.undo.toast', name: @agricultural_task.name)
    )

    render_deletion_undo_response(
      event,
      fallback_location: agricultural_tasks_path
    )
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
    render_deletion_failure(
      message: I18n.t('agricultural_tasks.flash.cannot_delete_in_use'),
      fallback_location: agricultural_tasks_path
    )
  rescue DeletionUndo::Error => e
    render_deletion_failure(
      message: I18n.t('agricultural_tasks.flash.delete_error', message: e.message),
      fallback_location: agricultural_tasks_path
    )
  rescue StandardError => e
    render_deletion_failure(
      message: I18n.t('agricultural_tasks.flash.delete_error', message: e.message),
      fallback_location: agricultural_tasks_path
    )
  end

  private

  def set_agricultural_task
    @agricultural_task = AgriculturalTask.find(params[:id])

    unless accessible_for_current_user?(@agricultural_task)
      redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.no_permission')
      return
    end

    if action_requires_edit_permission? && !editable_by_current_user?(@agricultural_task)
      redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.no_permission')
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.not_found')
  end

  def accessible_for_current_user?(task)
    return true if admin_user?
    task.is_reference || task.user_id == current_user.id
  end

  def editable_by_current_user?(task)
    return true if admin_user?
    !task.is_reference && task.user_id == current_user.id
  end

  def action_requires_edit_permission?
    [:edit, :update, :destroy].include?(params[:action].to_sym)
  end

  def build_task_attributes
    attributes = agricultural_task_params.to_h.symbolize_keys

    raw_required_tools = params.dig(:agricultural_task, :required_tools)
    attributes[:required_tools] = normalize_required_tools(raw_required_tools)

    attributes
  end

  def normalize_required_tools(value)
    case value
    when Array
      value.map(&:to_s).map(&:strip).reject(&:blank?)
    when String
      value.split(/\r?\n|,/).map(&:strip).reject(&:blank?)
    else
      []
    end
  end

  def agricultural_task_params
    params.require(:agricultural_task).permit(
      :name,
      :description,
      :time_per_sqm,
      :weather_dependency,
      :skill_level,
      :is_reference,
      :region,
      :source_agricultural_task_id,
      required_tools: []
    )
  end
end


