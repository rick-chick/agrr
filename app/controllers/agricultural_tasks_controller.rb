# frozen_string_literal: true

class AgriculturalTasksController < ApplicationController
  include DeletionUndoFlow
  include HtmlCrudResponder
  before_action :set_agricultural_task, only: [:show, :edit, :update, :destroy]
  before_action :load_crop_selection_data, only: [:edit, :update]
  before_action :prepare_crop_cards_for_edit, only: [:edit]

  # GET /agricultural_tasks
  def index
    filter = resolve_filter(params[:filter])
    input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskListInputDto.from_hash({
      is_admin: admin_user?,
      filter: filter,
      query: params[:query].to_s.strip
    })

    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskListHtmlPresenter.new(view: self, input_dto: input_dto)

    interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskListInteractor.new(
      output_port: presenter,
      gateway: agricultural_task_gateway,
      user_id: current_user.id
    )

    interactor.call(input_dto)
  rescue StandardError => e
    flash.now[:alert] = e.message
    @agricultural_tasks = []
    @reference_farms = []
  end

  # GET /agricultural_tasks/:id
  def show
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskDetailHtmlPresenter.new(view: self)

    interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskDetailInteractor.new(
      output_port: presenter,
      gateway: agricultural_task_gateway,
      user_id: current_user.id
    )

    interactor.call(params[:id])
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.not_found')
  rescue StandardError => e
    redirect_to agricultural_tasks_path, alert: e.message
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

    @input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskCreateInputDto.from_hash({ agricultural_task: task_attributes })
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskCreateHtmlPresenter.new(view: self)

    interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskCreateInteractor.new(
      output_port: presenter,
      gateway: agricultural_task_gateway,
      user_id: current_user.id
    )

    interactor.call(@input_dto)
  rescue StandardError => e
    @agricultural_task = current_user.agricultural_tasks.build(
      name: @input_dto.name,
      description: @input_dto.description,
      time_per_sqm: @input_dto.time_per_sqm,
      weather_dependency: @input_dto.weather_dependency,
      skill_level: @input_dto.skill_level,
      is_reference: @input_dto.is_reference,
      required_tools: @input_dto.required_tools,
      region: @input_dto.region
    )
    @agricultural_task.valid? # エラーをセットするためにバリデーションを実行
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
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

    @input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInputDto.from_hash({ agricultural_task: task_attributes }, params[:id])
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskUpdateHtmlPresenter.new(view: self)

    interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskUpdateInteractor.new(
      output_port: presenter,
      gateway: agricultural_task_gateway,
      user_id: current_user.id
    )

    interactor.call(@input_dto)

    # Interactor 成功後は is_reference/user_id が更新済みのため reload してから作物紐付けを行う
    @agricultural_task.reload
    update_crop_task_templates(selected_crop_ids)
  rescue StandardError => e
    @agricultural_task.assign_attributes(
      name: @input_dto&.name || task_attributes[:name],
      description: @input_dto&.description || task_attributes[:description],
      time_per_sqm: @input_dto&.time_per_sqm || task_attributes[:time_per_sqm],
      weather_dependency: @input_dto&.weather_dependency || task_attributes[:weather_dependency],
      skill_level: @input_dto&.skill_level || task_attributes[:skill_level],
      is_reference: @input_dto&.is_reference || task_attributes[:is_reference],
      required_tools: @input_dto&.required_tools || task_attributes[:required_tools],
      region: @input_dto&.region || task_attributes[:region]
    )
    @agricultural_task.valid? # エラーをセットするためにバリデーションを実行
    prepare_crop_cards(selected_ids: selected_crop_ids)
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_entity
  end

  # DELETE /agricultural_tasks/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskDestroyHtmlPresenter.new(view: self)

        interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskDestroyInteractor.new(
          output_port: presenter,
          gateway: agricultural_task_gateway,
          user_id: current_user.id
        )

        interactor.call(params[:id])
      rescue Domain::Shared::Policies::PolicyPermissionDenied
        redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.not_found')
      end

      format.json do
        schedule_deletion_with_undo(
          record: @agricultural_task,
          toast_message: I18n.t('agricultural_tasks.undo.toast', name: @agricultural_task.name),
          fallback_location: agricultural_tasks_path,
          in_use_message_key: nil,
          delete_error_message_key: 'agricultural_tasks.flash.delete_error'
        )
      rescue Domain::Shared::Policies::PolicyPermissionDenied
        redirect_to agricultural_tasks_path, alert: I18n.t('agricultural_tasks.flash.not_found')
      end
    end
  end

  private

  def set_agricultural_task
    if action_requires_edit_permission?
      @agricultural_task = Domain::Shared::Policies::AgriculturalTaskPolicy.find_editable!(AgriculturalTask, current_user, params[:id])
    else
      @agricultural_task = Domain::Shared::Policies::AgriculturalTaskPolicy.find_visible!(AgriculturalTask, current_user, params[:id])
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

  def agricultural_tasks_for_admin(filter, base_scope = nil)
    base_scope ||= AgriculturalTask.all
    case filter
    when 'reference'
      base_scope.where(is_reference: true)
    when 'all'
      base_scope.where(id: Domain::Shared::Policies::AgriculturalTaskPolicy.visible_scope(AgriculturalTask, current_user).pluck(:id))
    else
      base_scope.where(id: Domain::Shared::Policies::AgriculturalTaskPolicy.user_owned_non_reference_scope(AgriculturalTask, current_user).pluck(:id))
    end
  end

  def apply_user_filter(scope, filter)
    case filter
    when 'reference'
      scope.where(is_reference: true)
    when 'user'
      scope.where(is_reference: false)
    else
      scope
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

  def update_crop_task_templates(selected_crop_ids)
    # 現在のタスク（reload 後）に対して許可された作物のみを対象にする
    allowed_crop_ids = accessible_crops_for_selection(@agricultural_task).where(id: selected_crop_ids).pluck(:id)
    current_template_crop_ids = CropTaskTemplate.where(agricultural_task: @agricultural_task).pluck(:crop_id)

    # 追加する作物（allowed_crop_idsにあって、current_template_crop_idsにない）
    crops_to_add = allowed_crop_ids - current_template_crop_ids
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

    # 削除する作物（current_template_crop_idsにあって、allowed_crop_idsにない）
    crops_to_remove = current_template_crop_ids - allowed_crop_ids
    crops_to_remove.each do |crop_id|
      crop = Crop.find(crop_id)
      template = CropTaskTemplate.find_by(crop: crop, agricultural_task: @agricultural_task)
      template&.destroy
    end
  end

  public

  # View interface for HTML Presenters（Presenter から呼ばれるため public）
  def redirect_to(path, notice: nil, alert: nil)
    super(path, notice: notice, alert: alert)
  end

  def render_form(action, status: :ok, locals: {})
    render(action, status: status, locals: locals)
  end

  def agricultural_task_path(task)
    id = task.respond_to?(:id) ? task.id : task
    Rails.application.routes.url_helpers.agricultural_task_path(id)
  end

  def agricultural_tasks_path
    Rails.application.routes.url_helpers.agricultural_tasks_path
  end

  private

  def agricultural_task_gateway
    @agricultural_task_gateway ||= Adapters::AgriculturalTask::Gateways::AgriculturalTaskActiveRecordGateway.new
  end
end


