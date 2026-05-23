# frozen_string_literal: true

class CropsController < ApplicationController
  before_action :set_crop, only: [ :edit, :update, :generate_task_schedule_blueprints, :toggle_task_template ]
  before_action :authenticate_admin!, only: [ :generate_task_schedule_blueprints ]

  # GET /crops
  def index
    presenter = Adapters::Crop::Presenters::CropListHtmlPresenter.new(view: self)

    interactor = Domain::Crop::Interactors::CropListInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup)

    interactor.call
  end

  # GET /crops/:id
  def show
    presenter = Adapters::Crop::Presenters::CropDetailHtmlPresenter.new(view: self)
    interactor = Domain::Crop::Interactors::CropDetailInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup)
    interactor.call(params[:id])
  end

  # GET /crops/new
  def new
    presenter = Adapters::Crop::Presenters::CropHtmlNewMasterFormHtmlPresenter.new(view: self)
    Domain::Crop::Interactors::CropHtmlNewMasterFormInteractor.new(output_port: presenter,
      gateway: CompositionRoot.crop_gateway).call
  end

  # GET /crops/:id/edit
  def edit
  end

  # POST /crops
  def create
    @input_dto = Domain::Crop::Dtos::CropCreateInput.from_hash({ crop: crop_params.to_h.symbolize_keys })
    presenter = Adapters::Crop::Presenters::CropCreateHtmlPresenter.new(view: self)

    interactor = Domain::Crop::Interactors::CropCreateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.crop_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup)

    interactor.call(@input_dto)
  end

  # PATCH/PUT /crops/:id
  def update
    @input_dto = Domain::Crop::Dtos::CropUpdateInput.from_hash({ crop: crop_params.to_h.symbolize_keys }, params[:id])
    presenter = Adapters::Crop::Presenters::CropUpdateHtmlPresenter.new(view: self)

    interactor = Domain::Crop::Interactors::CropUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.crop_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup)

    interactor.call(@input_dto)
  end

  # DELETE /crops/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Adapters::Crop::Presenters::CropDestroyHtmlPresenter.new(view: self)
        interactor = Domain::Crop::Interactors::CropDestroyInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup)
        interactor.call(params[:id])
      end

      format.json do
        Adapters::DeletionUndo::HtmlMasterScheduleInvoker.call(
          view: self,
          actor_id: current_user.id,
          resource_type: "Crop",
          resource_id: params[:id].to_i,
          toast_message: nil,
          fallback_location: crops_path,
          in_use_message_key: "crops.flash.cannot_delete_in_use",
          delete_error_message_key: "crops.flash.delete_error"
        )
      end
    end
  end

  def generate_task_schedule_blueprints
    presenter = Adapters::Crop::Presenters::CropRegenerateTaskScheduleBlueprintsHtmlPresenter.new(view: self)
    Domain::Crop::Interactors::CropRegenerateTaskScheduleBlueprintsInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      crop_id: @crop.id,
      gateway: CompositionRoot.crop_gateway,
      blueprint_regeneration_gateway: CompositionRoot.crop_task_schedule_blueprint_regeneration_gateway,
      translator: CompositionRoot.translator,
      logger: CompositionRoot.logger,
      user_lookup: CompositionRoot.user_lookup
    ).call
  end

  # POST /crops/:id/toggle_task_template
  def toggle_task_template
    presenter = Adapters::Crop::Presenters::CropToggleTaskTemplateHtmlPresenter.new(view: self)
    Domain::Crop::Interactors::CropToggleTaskTemplateInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      crop_id: @crop.id,
      agricultural_task_id: params[:agricultural_task_id],
      gateway: CompositionRoot.crop_gateway,
      agricultural_task_gateway: CompositionRoot.agricultural_task_gateway,
      toggle_gateway: CompositionRoot.crop_task_template_toggle_gateway,
      translator: CompositionRoot.translator,
      logger: CompositionRoot.logger,
      user_lookup: CompositionRoot.user_lookup
    ).call
    return if performed?

    respond_to do |format|
      format.turbo_stream { render :toggle_task_template }
      format.html { redirect_to crop_path(@crop) }
    end
  end

  def render_form(action, status: :ok, locals: {})
    render(action, status: status, locals: locals)
  end

  private

  def set_crop
    action = params[:action].to_sym
    for_edit = action.in?([ :edit, :update, :generate_task_schedule_blueprints, :toggle_task_template ])
    presenter = Adapters::Crop::Presenters::CropAuthorizationFailureRedirectHtmlPresenter.new(view: self, permission_message_key: "crops.flash.no_permission")
    interactor = Domain::Crop::Interactors::CropLoadAuthorizedInteractor.new(failure_presenter: presenter,
      user_id: current_user.id, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup)
    bundle = interactor.call(params[:id], for_edit: for_edit)
    return if bundle.nil?

    @crop = Forms::CropMasterForm.from_snapshot(bundle.master_form_snapshot)
  end

  def crop_params
    # region / is_reference は mass-assignment 許可のみ。admin 限定の認可は
    # CropPolicy.normalize_attrs_for_* と CropCreate/UpdateInteractor が判定する。
    permitted = [
      :name,
      :variety,
      :is_reference,
      :area_per_unit,
      :revenue_per_area,
      :groups,
      :region,
      crop_stages_attributes: [
        :id,
        :name,
        :order,
        :_destroy,
        temperature_requirement_attributes: [
          :id,
          :base_temperature,
          :optimal_min,
          :optimal_max,
          :low_stress_threshold,
          :high_stress_threshold,
          :frost_threshold,
          :sterility_risk_threshold,
          :max_temperature,
          :_destroy
        ],
        thermal_requirement_attributes: [
          :id,
          :required_gdd,
          :_destroy
        ],
        sunshine_requirement_attributes: [
          :id,
          :minimum_sunshine_hours,
          :target_sunshine_hours,
          :_destroy
        ],
        nutrient_requirement_attributes: [
          :id,
          :daily_uptake_n,
          :daily_uptake_p,
          :daily_uptake_k,
          :_destroy
        ]
      ]
    ]

    params.require(:crop).permit(*permitted)
  end

end
