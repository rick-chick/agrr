# frozen_string_literal: true

class AgriculturalTasksController < ApplicationController
  before_action :set_agricultural_task, only: [ :show, :edit, :update, :destroy ]
  before_action :load_crop_selection_data, only: [ :edit, :update ]
  before_action :prepare_crop_cards_for_edit, only: [ :edit ]

  # GET /agricultural_tasks
  def index
    filter = resolve_filter(params[:filter])
    input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskListInputDto.from_hash({
      is_admin: admin_user?,
      filter: filter,
      query: params[:query].to_s.strip
    })

    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskListHtmlPresenter.new(
      view: self,
      input_dto: input_dto
    )

    interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskListInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup)

    interactor.call(input_dto)
  end

  # GET /agricultural_tasks/:id
  def show
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskDetailHtmlPresenter.new(view: self)

    interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskDetailInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup)

    interactor.call(params[:id])
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

    @input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskCreateInputDto.from_hash({ agricultural_task: task_attributes })
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskCreateHtmlPresenter.new(view: self)

    interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskCreateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, translator: translator, user_lookup: CompositionRoot.user_lookup)

    interactor.call(@input_dto)
  end

  # PATCH/PUT /agricultural_tasks/:id
  def update
    task_attributes = build_task_attributes

    @input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInputDto.from_hash(
      {
        agricultural_task: task_attributes,
        selected_crop_ids: selected_crop_ids_from_params
      },
      params[:id]
    )
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskUpdateHtmlPresenter.new(
      view: self,
      form_resubmit: {
        dto: @input_dto,
        task_attributes: task_attributes,
        selected_crop_ids: selected_crop_ids_from_params
      }
    )

    interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, translator: translator, user_lookup: CompositionRoot.user_lookup)

    interactor.call(@input_dto)
  end

  # DELETE /agricultural_tasks/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskDestroyHtmlPresenter.new(view: self)

        interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskDestroyInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup)

        interactor.call(params[:id])
      end

      format.json do
        DeletionUndo::HtmlMasterScheduleInvoker.call(
          view: self,
          actor_id: current_user.id,
          record: @agricultural_task,
          toast_message: I18n.t("agricultural_tasks.undo.toast", name: @agricultural_task.name),
          fallback_location: agricultural_tasks_path,
          in_use_message_key: nil,
          delete_error_message_key: "agricultural_tasks.flash.delete_error"
        )
      end
    end
  end

  def after_agricultural_task_create_failure
    task_attributes = build_task_attributes
    @agricultural_task = current_user.agricultural_tasks.build(
      name: task_attributes[:name],
      description: task_attributes[:description],
      time_per_sqm: task_attributes[:time_per_sqm],
      weather_dependency: task_attributes[:weather_dependency],
      skill_level: task_attributes[:skill_level],
      is_reference: task_attributes[:is_reference],
      required_tools: task_attributes[:required_tools],
      region: task_attributes[:region]
    )
    @agricultural_task.valid?
  end

  private

  def set_agricultural_task
    if action_requires_edit_permission?
      presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskLoadForEditHtmlPresenter.new(view: self)
      interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskLoadAuthorizedModelForEditInteractor.new(output_port: presenter,
        user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup)
    else
      presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskLoadForViewHtmlPresenter.new(view: self)
      interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskLoadAuthorizedModelForViewInteractor.new(output_port: presenter,
        user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup)
    end

    interactor.call(params[:id])
  end

  def action_requires_edit_permission?
    [ :edit, :update, :destroy ].include?(params[:action].to_sym)
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

    admin_user? ? "all" : "user"
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
      if params[:action] == "update"
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

  public

  # HTML 更新失敗時に編集フォームへ送信内容を戻す（Presenter からのみ呼ぶ）
  def apply_agricultural_task_update_form_snapshot(form_resubmit)
    return unless form_resubmit

    dto = form_resubmit[:dto]
    task_attributes = form_resubmit[:task_attributes]
    selected_crop_ids = form_resubmit[:selected_crop_ids]
    return unless dto && @agricultural_task

    @agricultural_task.assign_attributes(
      name: dto.name || task_attributes[:name],
      description: dto.description || task_attributes[:description],
      time_per_sqm: dto.time_per_sqm || task_attributes[:time_per_sqm],
      weather_dependency: dto.weather_dependency || task_attributes[:weather_dependency],
      skill_level: dto.skill_level || task_attributes[:skill_level],
      is_reference: dto.is_reference.nil? ? task_attributes[:is_reference] : dto.is_reference,
      required_tools: dto.required_tools || task_attributes[:required_tools],
      region: dto.region || task_attributes[:region]
    )
    @agricultural_task.valid?
    prepare_crop_cards(selected_ids: selected_crop_ids)
  end

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

end
