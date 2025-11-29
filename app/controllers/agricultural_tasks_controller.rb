# frozen_string_literal: true

class AgriculturalTasksController < ApplicationController
  include DeletionUndoFlow
  include HtmlCrudResponder
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
        AgriculturalTaskPolicy.visible_scope(current_user)
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

    @agricultural_task = AgriculturalTaskPolicy.build_for_create(current_user, task_attributes)

    if @agricultural_task.save
      respond_to_create(@agricultural_task, notice: I18n.t('agricultural_tasks.flash.created'), redirect_path: agricultural_task_path(@agricultural_task))
    else
      respond_to_create(@agricultural_task, notice: nil)
    end
  end

  # PATCH/PUT /agricultural_tasks/:id
  def update
    task_attributes = build_task_attributes
    requested_reference = requested_reference_flag_from(task_attributes)
    reference_changed = requested_reference != @agricultural_task.is_reference?
    selected_crop_ids = selected_crop_ids_from_params

    if reference_changed && !admin_user?
      return redirect_to agricultural_task_path(@agricultural_task), alert: I18n.t('agricultural_tasks.flash.reference_flag_admin_only')
    end

    update_result = AgriculturalTaskPolicy.apply_update!(current_user, @agricultural_task, task_attributes)
    if update_result
      # 作業と作物の紐付けをCropTaskTemplateで更新
      # 現在のテンプレートを取得
      current_template_crop_ids = CropTaskTemplate.where(agricultural_task: @agricultural_task).pluck(:crop_id)
      
      # 追加する作物（selected_crop_idsにあって、current_template_crop_idsにない）
      crops_to_add = selected_crop_ids - current_template_crop_ids
      crops_to_add.each do |crop_id|
        crop = Crop.find(crop_id)
        # 既存のテンプレートがない場合のみ作成
        unless CropTaskTemplate.exists?(crop: crop, agricultural_task: @agricultural_task)
          crop.crop_task_templates.create!(
            agricultural_task: @agricultural_task,
            name: @agricultural_task.name,
            description: @agricultural_task.description,
            time_per_sqm: @agricultural_task.time_per_sqm,
            weather_dependency: @agricultural_task.weather_dependency,
            required_tools: @agricultural_task.required_tools,
            skill_level: @agricultural_task.skill_level
          )
        end
      end
      
      # 削除する作物（current_template_crop_idsにあって、selected_crop_idsにない）
      crops_to_remove = current_template_crop_ids - selected_crop_ids
      crops_to_remove.each do |crop_id|
        crop = Crop.find(crop_id)
        template = CropTaskTemplate.find_by(crop: crop, agricultural_task: @agricultural_task)
        template&.destroy
      end
      
      respond_to_update(@agricultural_task, notice: I18n.t('agricultural_tasks.flash.updated'), redirect_path: agricultural_task_path(@agricultural_task), update_result: update_result)
    else
      prepare_crop_cards(selected_ids: selected_crop_ids)
      respond_to_update(@agricultural_task, notice: nil, update_result: update_result)
    end
  end

  # DELETE /agricultural_tasks/:id
  def destroy
    schedule_deletion_with_undo(
      record: @agricultural_task,
      toast_message: I18n.t('agricultural_tasks.undo.toast', name: @agricultural_task.name),
      fallback_location: agricultural_tasks_path,
      in_use_message_key: 'agricultural_tasks.flash.cannot_delete_in_use',
      delete_error_message_key: 'agricultural_tasks.flash.delete_error'
    )
  end

  private

  def set_agricultural_task
    if action_requires_edit_permission?
      @agricultural_task = AgriculturalTaskPolicy.find_editable!(current_user, params[:id])
    else
      @agricultural_task = AgriculturalTaskPolicy.find_visible!(current_user, params[:id])
    end
  rescue PolicyPermissionDenied
    redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.no_permission')
  rescue ActiveRecord::RecordNotFound
    redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.not_found')
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
      AgriculturalTaskPolicy.visible_scope(current_user)
    else
      AgriculturalTaskPolicy.user_owned_non_reference_scope(current_user)
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
    permitted = [
      :name,
      :description,
      :time_per_sqm,
      :weather_dependency,
      :skill_level,
      :is_reference,
      :source_agricultural_task_id,
      required_tools: []
    ]
    
    # 管理者のみregionを許可
    permitted << :region if admin_user?
    
    params.require(:agricultural_task).permit(*permitted)
  end

  def load_crop_selection_data
    return unless action_requires_edit_permission?

    preview_task =
      if params[:action] == 'update'
        build_preview_task_for_selection
      else
        @agricultural_task
      end

    @accessible_crops = accessible_crops_for_selection(preview_task).to_a
    @accessible_crop_ids = @accessible_crops.map(&:id)
  end

  def prepare_crop_cards_for_edit
    prepare_crop_cards
  end

  def prepare_crop_cards(selected_ids: nil)
    return unless defined?(@accessible_crops)

    # 作物詳細画面の紐付けが正しいため、CropTaskTemplateから取得
    selected_ids ||= CropTaskTemplate.where(agricultural_task: @agricultural_task).pluck(:crop_id)
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

  def accessible_crops_for_selection(task)
    scope =
      if task.is_reference?
        Crop.where(is_reference: true)
      else
        owner_id = task.user_id
        Crop.where(is_reference: false, user_id: owner_id)
      end

    if task.region.present?
      scope = scope.where(region: task.region)
    end

    scope.order(:name)
  end

  def build_preview_task_for_selection
    preview = @agricultural_task.dup
    requested_flag = requested_reference_flag_from(params.fetch(:agricultural_task, {}))
    if requested_flag != @agricultural_task.is_reference?
      preview.is_reference = requested_flag
      preview.user_id = user_id_for(requested_flag)
    end
    preview
  end

  def user_id_for(reference_flag)
    return nil if reference_flag

    @agricultural_task.user_id.presence || current_user.id
  end

  def requested_reference_flag_from(attributes)
    return @agricultural_task.is_reference? unless attributes.respond_to?(:key?) && attributes.key?(:is_reference)

    casted = ActiveModel::Type::Boolean.new.cast(attributes[:is_reference])
    casted.nil? ? false : casted
  end
end


