# frozen_string_literal: true

class PestsController < ApplicationController
  before_action :load_pest_for_edit, only: [ :update ]

  # GET /pests
  def index
    presenter = Adapters::Pest::Presenters::PestListHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestListInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call
  end

  # GET /pests/:id
  def show
    presenter = Adapters::Pest::Presenters::PestDetailHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestDetailInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
  end

  # GET /pests/new
  def new
    payload = Domain::Pest::Dtos::PestMasterEditPayload.for_blank_new
    @pest = Forms::PestMasterForm.from_edit_payload(payload)
    load_pest_master_form_crop_selection(
      master_edit_payload: payload,
      request_crop_ids: params[:crop_ids] ? Array(params[:crop_ids]) : []
    )
  end

  # GET /pests/:id/edit
  def edit
    bundle = load_pest_for_edit
    return if bundle.nil?

    payload = bundle.pest_master_edit_payload
    @pest = Forms::PestMasterForm.from_edit_payload(payload)
    load_pest_master_form_crop_selection(master_edit_payload: payload)
  end

  # POST /pests
  def create
    input_dto = Domain::Pest::Dtos::PestCreateInput.from_hash(
      { pest: pest_params.to_h.symbolize_keys, crop_ids: params[:crop_ids] }
    )
    presenter = Adapters::Pest::Presenters::PestCreateHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestCreateInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # PATCH/PUT /pests/:id
  def update
    input_dto = Domain::Pest::Dtos::PestUpdateInput.from_hash(
      { pest: pest_params.to_h.symbolize_keys, crop_ids: params[:crop_ids] },
      params[:id]
    )
    presenter = Adapters::Pest::Presenters::PestUpdateHtmlPresenter.new(
      view: self
    )
    Domain::Pest::Interactors::PestUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.pest_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # DELETE /pests/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Adapters::Pest::Presenters::PestDestroyHtmlPresenter.new(view: self)
        Domain::Pest::Interactors::PestDestroyInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
      end

      format.json do
        Adapters::DeletionUndo::HtmlMasterScheduleInvoker.call(
          view: self,
          actor_id: current_user.id,
          resource_type: "Pest",
          resource_id: params[:id].to_i,
          toast_message: nil,
          fallback_location: pests_path,
          in_use_message_key: "pests.flash.cannot_delete_in_use",
          delete_error_message_key: "pests.flash.delete_error"
        )
      end
    end
  end

  private

  def translator
    @translator ||= CompositionRoot.translator
  end

  def load_pest_for_edit
    failure_presenter = Adapters::Pest::Presenters::PestAuthorizationFailureRedirectHtmlPresenter.new(
      view: self, permission_message_key: "pests.flash.no_permission"
    )
    interactor = Domain::Pest::Interactors::PestLoadAuthorizedModelForEditInteractor.new(
      failure_presenter: failure_presenter,
      user_id: current_user.id,
      gateway: CompositionRoot.pest_gateway,
      user_lookup: CompositionRoot.user_lookup
    )
    interactor.call(params[:id])
  end

  def pest_params
    # region / is_reference は mass-assignment 許可のみ。admin 限定の認可は
    # PestPolicy.normalize_attrs_for_* と PestCreate/UpdateInteractor が判定する。
    permitted = [
      :name,
      :name_scientific,
      :family,
      :order,
      :description,
      :occurrence_season,
      :is_reference,
      :region,
      pest_temperature_profile_attributes: [
        :id,
        :base_temperature,
        :max_temperature,
        :_destroy
      ],
      pest_thermal_requirement_attributes: [
        :id,
        :required_gdd,
        :first_generation_gdd,
        :_destroy
      ],
      pest_control_methods_attributes: [
        :id,
        :method_type,
        :method_name,
        :description,
        :timing_hint,
        :_destroy
      ]
    ]

    params.require(:pest).permit(*permitted)
  end

  public

  def render_form(action, status: :ok, locals: {})
    render(action, status: status, locals: locals)
  end

  # Interactor 経由で作物選択 UI 用インスタンス変数を設定する（new / edit 用）。
  def load_pest_master_form_crop_selection(master_edit_payload:, request_crop_ids: :use_payload_associations)
    presenter = Adapters::Pest::Presenters::PestMasterFormCropSelectionLoadHtmlPresenter.new(view: self)
    CompositionRoot.pest_master_form_crop_selection_load_interactor(output_port: presenter, user_id: current_user.id).call(
      master_edit_payload: master_edit_payload,
      request_crop_ids: request_crop_ids
    )
  end

  private
end
