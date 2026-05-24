# frozen_string_literal: true

class AgriculturalTasksController < ApplicationController
  before_action :set_agricultural_task, only: [ :show, :edit, :update ]
  before_action :load_edit_form_crop_selection, only: [ :edit, :update ]

  # GET /agricultural_tasks
  def index
    input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskListInput.from_hash({
      is_admin: admin_user?,
      filter: params[:filter],
      query: params[:query].to_s.strip
    })

    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskListHtmlPresenter.new(
      view: self,
      input_dto: input_dto
    )

    interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskListInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, user_lookup: CompositionRoot.user_lookup)

    interactor.call(input_dto)
  end

  # GET /agricultural_tasks/:id
  def show
    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskDetailHtmlPresenter.new(view: self)

    interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskDetailInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, user_lookup: CompositionRoot.user_lookup)

    interactor.call(params[:id])
  end

  # GET /agricultural_tasks/new
  def new
    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskNewMasterFormHtmlPresenter.new(view: self)
    Domain::AgriculturalTask::Interactors::AgriculturalTaskNewMasterFormInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: CompositionRoot.agricultural_task_gateway,
      user_lookup: CompositionRoot.user_lookup
    ).call
  end

  # GET /agricultural_tasks/:id/edit
  def edit
  end

  # POST /agricultural_tasks
  def create
    task_attributes = build_task_attributes

    @input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskCreateInput.from_hash({ agricultural_task: task_attributes })
    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskCreateHtmlPresenter.new(view: self)

    interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskCreateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup)

    interactor.call(@input_dto)
  end

  # PATCH/PUT /agricultural_tasks/:id
  def update
    task_attributes = build_task_attributes

    @input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInput.from_hash(
      {
        agricultural_task: task_attributes,
        selected_crop_ids: selected_crop_ids_from_params
      },
      params[:id]
    )
    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskUpdateHtmlPresenter.new(
      view: self,
      form_resubmit: {
        dto: @input_dto,
        task_attributes: task_attributes,
        selected_crop_ids: selected_crop_ids_from_params
      }
    )

    interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup)

    interactor.call(@input_dto)
  end

  # DELETE /agricultural_tasks/:id
  def destroy
    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskDestroyHtmlPresenter.new(view: self)

    interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskDestroyInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.agricultural_task_gateway, user_lookup: CompositionRoot.user_lookup)

    interactor.call(params[:id])
  end

  def after_agricultural_task_create_failure
    task_attributes = build_task_attributes
    @agricultural_task = CompositionRoot.agricultural_task_gateway.build_after_create_failure_agricultural_task_for_master_form!(
      user: current_user,
      attributes: task_attributes
    )
  end

  private

  def set_agricultural_task
    if action_requires_edit_permission?
      presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskLoadForEditHtmlPresenter.new(view: self)
      interactor = Domain::AgriculturalTask::Interactors::AgriculturalTaskLoadAuthorizedModelForEditInteractor.new(output_port: presenter,
        user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup)
    else
      presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskLoadForViewHtmlPresenter.new(view: self)
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
    # region / is_reference は mass-assignment 許可のみ。admin 限定の認可は
    # AgriculturalTaskPolicy.normalize_attrs_for_* と
    # AgriculturalTaskCreate/UpdateInteractor が判定する。
    permitted = [
      :name,
      :description,
      :time_per_sqm,
      :weather_dependency,
      :skill_level,
      :is_reference,
      :source_agricultural_task_id,
      :region,
      required_tools: []
    ]

    params.require(:agricultural_task).permit(*permitted)
  end

  def load_edit_form_crop_selection
    return unless action_requires_edit_permission?

    preview_attrs = agricultural_task_attributes_hash_for_crop_preview
    input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskEditFormCropSelectionInput.new(
      user_id: current_user.id,
      agricultural_task_id: params[:id].to_i,
      controller_action: params[:action].to_s,
      agricultural_task_attributes_for_preview: preview_attrs,
      raw_selected_crop_ids: params[:selected_crop_ids],
      include_crop_cards: params[:action].to_s == "edit"
    )

    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskEditFormCropSelectionLoadHtmlPresenter.new(view: self)
    interactor = CompositionRoot.agricultural_task_edit_form_crop_selection_load_interactor(
      output_port: presenter,
      user_id: current_user.id
    )

    interactor.call(input_dto)
  end

  def agricultural_task_attributes_hash_for_crop_preview
    raw = params[:agricultural_task]
    return {} if raw.nil?
    return raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)

    raw.to_h
  end

  def selected_crop_ids_from_params
    Array(@filtered_selected_crop_ids_from_crop_selection_load)
  end

  public

  # HTML 更新失敗時に編集フォームへ送信内容を戻す（Presenter からのみ呼ぶ）
  def apply_agricultural_task_update_form_snapshot(form_resubmit)
    return unless form_resubmit

    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskUpdateFormSnapshotHtmlPresenter.new(view: self)
    Domain::AgriculturalTask::Interactors::AgriculturalTaskUpdateFormSnapshotInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: CompositionRoot.agricultural_task_gateway,
      user_lookup: CompositionRoot.user_lookup
    ).call(
      Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateFormSnapshotInput.new(
        form_resubmit: form_resubmit,
        accessible_crops: @accessible_crops
      )
    )
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
