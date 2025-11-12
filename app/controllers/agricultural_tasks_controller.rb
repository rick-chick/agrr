# frozen_string_literal: true

class AgriculturalTasksController < ApplicationController
  before_action :set_agricultural_task, only: [:show, :edit, :update, :destroy]
  before_action :load_crop_selection_data, only: [:edit, :update]
  before_action :prepare_crop_cards_for_edit, only: [:edit]

  # GET /agricultural_tasks
  def index
    @query = params[:query].to_s.strip
    @selected_filter = resolve_filter(params[:filter])

    scope =
      if admin_user?
        agricultural_tasks_for_admin(@selected_filter)
      else
        AgriculturalTask.where(user_id: current_user.id, is_reference: false)
      end

    scope = apply_search(scope, @query)

    @agricultural_tasks = scope.recent
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
    selected_crop_ids = selected_crop_ids_from_params

    if task_attributes.key?(:is_reference)
      requested_reference = ActiveModel::Type::Boolean.new.cast(task_attributes[:is_reference]) || false
      if requested_reference != @agricultural_task.is_reference && !admin_user?
        return redirect_to agricultural_task_path(@agricultural_task), alert: I18n.t('agricultural_tasks.flash.reference_flag_admin_only')
      end
    end

    if @agricultural_task.update(task_attributes.except(:is_reference))
      @agricultural_task.crops = Crop.where(id: selected_crop_ids)
      redirect_to agricultural_task_path(@agricultural_task), notice: I18n.t('agricultural_tasks.flash.updated')
    else
      prepare_crop_cards(selected_ids: selected_crop_ids)
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

  def resolve_filter(filter_param)
    allowed_filters = %w[user reference all]
    filter = filter_param.to_s.presence

    return filter if admin_user? && allowed_filters.include?(filter)

    admin_user? ? 'all' : 'user'
  end

  def agricultural_tasks_for_admin(filter)
    case filter
    when 'reference'
      AgriculturalTask.where(is_reference: true)
    when 'all'
      AgriculturalTask.where("is_reference = ? OR user_id = ?", true, current_user.id)
    else
      AgriculturalTask.where(user_id: current_user.id, is_reference: false)
    end
  end

  def apply_search(scope, term)
    return scope if term.blank?

    sanitized = ActiveRecord::Base.sanitize_sql_like(term)
    query = "%#{sanitized}%"
    scope.where(
      "agricultural_tasks.name LIKE :query OR COALESCE(agricultural_tasks.description, '') LIKE :query",
      query: query
    )
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

  def load_crop_selection_data
    return unless action_requires_edit_permission?

    @accessible_crops = accessible_crops_for_selection.to_a
    @accessible_crop_ids = @accessible_crops.map(&:id)
  end

  def prepare_crop_cards_for_edit
    prepare_crop_cards
  end

  def prepare_crop_cards(selected_ids: nil)
    return unless defined?(@accessible_crops)

    selected_ids ||= @agricultural_task.crops.pluck(:id)
    normalized_ids = Array(selected_ids).map(&:to_i).uniq

    @selected_crop_ids = normalized_ids
    @crop_cards = @accessible_crops.map do |crop|
      {
        crop: crop,
        selected: normalized_ids.include?(crop.id)
      }
    end
  end

  def selected_crop_ids_from_params
    return [] unless defined?(@accessible_crop_ids)

    raw_ids = Array(params[:selected_crop_ids]).reject(&:blank?)
    normalized_ids = raw_ids.map(&:to_i)
    normalized_ids.select { |id| @accessible_crop_ids.include?(id) }
  end

  def accessible_crops_for_selection
    scope =
      if @agricultural_task.is_reference?
        Crop.where(is_reference: true)
      else
        owner_id = @agricultural_task.user_id
        Crop.where(is_reference: false, user_id: owner_id)
      end

    if @agricultural_task.region.present?
      scope = scope.where(region: @agricultural_task.region)
    end

    scope.order(:name)
  end
end


