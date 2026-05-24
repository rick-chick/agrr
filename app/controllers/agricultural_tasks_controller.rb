# frozen_string_literal: true

class AgriculturalTasksController < ApplicationController
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

  # POST /agricultural_tasks
  def create
    task_attributes = build_task_attributes

    input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskCreateInput.from_hash({ agricultural_task: task_attributes })
    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskCreateHtmlPresenter.new(view: self)

    Domain::AgriculturalTask::Interactors::AgriculturalTaskCreateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # PATCH/PUT /agricultural_tasks/:id
  def update
    task_attributes = build_task_attributes

    input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInput.from_hash(
      {
        agricultural_task: task_attributes,
        selected_crop_ids: selected_crop_ids_from_params
      },
      params[:id]
    )
    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskUpdateHtmlPresenter.new(view: self)

    Domain::AgriculturalTask::Interactors::AgriculturalTaskUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.agricultural_task_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # DELETE /agricultural_tasks/:id
  def destroy
    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskDestroyHtmlPresenter.new(view: self)

    Domain::AgriculturalTask::Interactors::AgriculturalTaskDestroyInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.agricultural_task_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
  end

  private

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

  def selected_crop_ids_from_params
    Array(params[:selected_crop_ids]).reject { |v| v.nil? || v.to_s.empty? }.map(&:to_i).uniq
  end

  public

  # View interface for HTML Presenters（Presenter から呼ばれるため public）
  def redirect_to(path, notice: nil, alert: nil)
    super(path, notice: notice, alert: alert)
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
