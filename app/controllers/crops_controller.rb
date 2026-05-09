# frozen_string_literal: true

class CropsController < ApplicationController
  before_action :set_crop, only: [ :edit, :update, :generate_task_schedule_blueprints, :toggle_task_template ]
  before_action :authenticate_admin!, only: [ :generate_task_schedule_blueprints ]

  # GET /crops
  def index
    presenter = Presenters::Html::Crop::CropListHtmlPresenter.new(view: self)

    interactor = Domain::Crop::Interactors::CropListInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup)

    interactor.call
  end

  # GET /crops/:id
  def show
    presenter = Presenters::Html::Crop::CropDetailHtmlPresenter.new(view: self)
    interactor = Domain::Crop::Interactors::CropDetailInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup)
    interactor.call(params[:id])
  end

  # GET /crops/new
  def new
    @crop = CompositionRoot.crop_gateway.build_blank_crop_for_master_form
  end

  # GET /crops/:id/edit
  def edit
    CompositionRoot.crop_gateway.prepare_crop_record_for_edit_master_form!(@crop)
  end

  # POST /crops
  def create
    @input_dto = Domain::Crop::Dtos::CropCreateInputDto.from_hash({ crop: crop_params.to_h.symbolize_keys })
    presenter = Presenters::Html::Crop::CropCreateHtmlPresenter.new(view: self)

    interactor = Domain::Crop::Interactors::CropCreateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.crop_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup)

    interactor.call(@input_dto)
  end

  # PATCH/PUT /crops/:id
  def update
    @input_dto = Domain::Crop::Dtos::CropUpdateInputDto.from_hash({ crop: crop_params.to_h.symbolize_keys }, params[:id])
    presenter = Presenters::Html::Crop::CropUpdateHtmlPresenter.new(view: self)

    interactor = Domain::Crop::Interactors::CropUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.crop_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup)

    interactor.call(@input_dto)
  end

  # DELETE /crops/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Presenters::Html::Crop::CropDestroyHtmlPresenter.new(view: self)
        interactor = Domain::Crop::Interactors::CropDestroyInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup)
        interactor.call(params[:id])
      end

      format.json do
        DeletionUndo::HtmlMasterScheduleInvoker.call(
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
    presenter = Presenters::Html::Crop::CropRegenerateTaskScheduleBlueprintsHtmlPresenter.new(view: self)
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
    presenter = Presenters::Html::Crop::CropToggleTaskTemplateHtmlPresenter.new(view: self)
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

  def after_crop_create_failure
    @crop = CompositionRoot.crop_gateway.build_new_crop_with_attributes_for_master_form(
      attributes: crop_params.to_h.symbolize_keys
    )
    @crop.valid?
  end

  def after_crop_update_failure
    user = CompositionRoot.user_lookup.find(current_user.id)
    access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
    @crop = CompositionRoot.crop_gateway.merge_edit_crop_params_for_master_form!(
      user: user,
      crop_id: params[:id].to_i,
      attributes: crop_params.to_h.symbolize_keys,
      access_filter: access_filter
    )
    @crop.valid?
  end

  def render_form(action, status: :ok, locals: {})
    render(action, status: status, locals: locals)
  end

  private

  def set_crop
    action = params[:action].to_sym
    for_edit = action.in?([ :edit, :update, :generate_task_schedule_blueprints, :toggle_task_template ])
    presenter = Presenters::Html::Crop::CropAuthorizationFailureRedirectPresenter.new(view: self, permission_message_key: "crops.flash.no_permission")
    interactor = Domain::Crop::Interactors::CropLoadAuthorizedInteractor.new(failure_presenter: presenter,
      user_id: current_user.id, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup)
    bundle = interactor.call(params[:id], for_edit: for_edit)
    return if bundle.nil?

    @crop = bundle.persisted_crop
  end

  def crop_params
    permitted = [
      :name,
      :variety,
      :is_reference,
      :area_per_unit,
      :revenue_per_area,
      :groups,
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

    # 管理者のみregionを許可
    permitted << :region if admin_user?

    params.require(:crop).permit(*permitted)
  end

end
